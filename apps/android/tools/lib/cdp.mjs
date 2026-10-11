/**
 * cdp.mjs — 极简 Chrome DevTools Protocol 客户端。
 *
 * 零第三方依赖：借助 Node 22+ 内置的全局 `WebSocket` 直连 CDP，
 * 复用本机已安装的 Chrome/Edge（无需下载 Chromium）。
 *
 * 供 `render-prototype.mjs` 与 `audit-canvas.mjs` 共用。
 */

import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/** 探测本机浏览器可执行文件。 */
export function findChrome(explicit) {
  if (explicit) return explicit;
  const candidates = [
    'C:/Program Files/Google/Chrome/Application/chrome.exe',
    'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
    'C:/Program Files/Microsoft/Edge/Application/msedge.exe',
    '/usr/bin/google-chrome',
    '/usr/bin/chromium',
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  ];
  for (const c of candidates) if (existsSync(c)) return c;
  throw new Error('未找到 Chrome/Edge，请用 --chrome 指定可执行文件');
}

/** 极简 CDP 客户端（支持 flatten 会话）。 */
export class Cdp {
  constructor(ws) {
    this.ws = ws;
    this.id = 0;
    this.pending = new Map();
    this.listeners = [];
    ws.addEventListener('message', (ev) => {
      const msg = JSON.parse(ev.data);
      if (msg.id && this.pending.has(msg.id)) {
        const { resolve: res, reject } = this.pending.get(msg.id);
        this.pending.delete(msg.id);
        msg.error ? reject(new Error(JSON.stringify(msg.error))) : res(msg.result);
      } else if (msg.method) {
        for (const l of [...this.listeners]) l(msg);
      }
    });
  }

  send(method, params = {}, sessionId) {
    const id = ++this.id;
    const payload = { id, method, params };
    if (sessionId) payload.sessionId = sessionId;
    this.ws.send(JSON.stringify(payload));
    return new Promise((res, reject) => this.pending.set(id, { resolve: res, reject }));
  }

  once(method, timeoutMs = 20000) {
    return new Promise((res, reject) => {
      const t = setTimeout(() => reject(new Error(`等待 ${method} 超时`)), timeoutMs);
      const l = (msg) => {
        if (msg.method === method) {
          clearTimeout(t);
          this.listeners = this.listeners.filter((x) => x !== l);
          res(msg.params);
        }
      };
      this.listeners.push(l);
    });
  }

  async connect() {
    await new Promise((res, reject) => {
      this.ws.addEventListener('open', res, { once: true });
      this.ws.addEventListener('error', reject, { once: true });
    });
  }
}

async function waitForDevtools(url, tries = 60) {
  for (let i = 0; i < tries; i++) {
    try {
      const r = await fetch(url);
      if (r.ok) return await r.json();
    } catch {
      /* 尚未就绪 */
    }
    await sleep(250);
  }
  throw new Error('Chrome DevTools 端点未就绪');
}

/**
 * 启动无头 Chrome、建立页面会话，把会话交给 `fn`，结束后清理。
 *
 * @param {{chrome?:string, port?:number, window?:[number,number], profileDir?:string}} opts
 * @param {(ctx:{cdp:Cdp, sessionId:string, goto:(url:string)=>Promise<void>, evalJson:(expr:string)=>Promise<any>}) => Promise<void>} fn
 */
export async function withPage(opts, fn) {
  const chrome = findChrome(opts.chrome);
  const port = opts.port ?? 9333;
  const [winW, winH] = opts.window ?? [1600, 2400];
  const userDataDir = resolve(opts.profileDir ?? '.rivet/scratch/chrome-profile');

  const proc = spawn(chrome, [
    '--headless=new',
    '--disable-gpu',
    '--hide-scrollbars',
    '--no-first-run',
    '--no-default-browser-check',
    '--force-device-scale-factor=1',
    `--remote-debugging-port=${port}`,
    `--user-data-dir=${userDataDir}`,
    `--window-size=${winW},${winH}`,
    'about:blank',
  ], { stdio: ['ignore', 'ignore', 'pipe'] });

  try {
    const version = await waitForDevtools(`http://127.0.0.1:${port}/json/version`);
    const ws = new WebSocket(version.webSocketDebuggerUrl);
    const cdp = new Cdp(ws);
    await cdp.connect();

    const { targetId } = await cdp.send('Target.createTarget', { url: 'about:blank' });
    const { sessionId } = await cdp.send('Target.attachToTarget', { targetId, flatten: true });
    await cdp.send('Page.enable', {}, sessionId);

    const ctx = {
      cdp,
      sessionId,
      async goto(url) {
        const loaded = cdp.once('Page.loadEventFired');
        await cdp.send('Page.navigate', { url }, sessionId);
        await loaded;
        await sleep(350);
        // 把原型停在**稳定态**再交给调用方。
        //
        // 多个屏的入场动画是「`opacity:0` 起手 + 0.05–0.6s 的 delay + `both` 填充」
        // （典型：`fittracker-training-complete.html` 的 cf-pop / cf-rise 四连）。
        // 加载后 350ms 仍在动画中途：参照图会缺掉尚未升起的区块，
        // `proto-text` 更会整片漏收（实测 complete 屏只提取到 2 条文案，漏掉
        // 「训练连续记录」「连续 6 天」「一…日」「继续」共 11 条）。
        //
        // 关掉 animation/transition 后，元素落到各自终态——对 `both`/`forwards`
        // 填充的动画，终态即基础样式（opacity 1 / transform none），与设备侧
        // 截图时刻（深链后 4s，动画早已结束）语义一致。
        await cdp.send('Runtime.evaluate', {
          expression: `(() => {
            const s = document.createElement('style');
            s.textContent = '*,*::before,*::after{animation:none !important;transition:none !important}';
            document.head.appendChild(s);
            void document.body.offsetWidth;
            return true;
          })()`,
          returnByValue: true,
        }, sessionId);
        await sleep(120);
      },
      async evalJson(expression) {
        const r = await cdp.send('Runtime.evaluate', {
          expression,
          returnByValue: true,
          awaitPromise: true,
        }, sessionId);
        return r.result?.value;
      },
    };

    await fn(ctx);
    ws.close();
  } finally {
    proc.kill();
  }
}
