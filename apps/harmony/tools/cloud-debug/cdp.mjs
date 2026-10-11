#!/usr/bin/env node
/**
 * cdp.mjs — 轻量 Chrome DevTools Protocol 客户端（云调试自动化通道）
 *
 * 背景：browser_debug 工具通道在此环境下存在两个问题：
 *   1) 其内置浏览器为 Playwright Chromium（ms-playwright/chromium-1234），
 *      对「developer.huawei.com 页面 → svc-drcn.developer.huawei.com 跨域请求」
 *      存在稳定的 TLS 层失败（ERR_SSL_BAD_RECORD_MAC_ALERT / EMPTY_RESPONSE），
 *      会卡死 AGC 登录流的 getAccessToken 环节；换成真实 Chrome 后完全治愈。
 *   2) 工具 worker 曾整体卡死（连续多次调用 60s 超时）。
 *
 * 本脚本直连「自管真实 Chrome」的远程调试端口，提供云调试所需的最小操作集。
 * 前置：真实 Chrome 已用 --remote-debugging-port 启动（见 docs/release/cloud-debug-automation.md）。
 *
 * 用法：
 *   node tools/cloud-debug/cdp.mjs pages
 *   node tools/cloud-debug/cdp.mjs eval "<js 表达式>"        # 支持 await 的表达式（awaitPromise）
 *   node tools/cloud-debug/cdp.mjs nav <url>
 *   node tools/cloud-debug/cdp.mjs screenshot <out.png> [--full]
 *   node tools/cloud-debug/cdp.mjs click <x> <y>
 *   node tools/cloud-debug/cdp.mjs text <string>             # Input.insertText（输入文本）
 *   node tools/cloud-debug/cdp.mjs key <KeyName>             # 单个按键（Enter/Tab/Escape/ArrowDown/...）
 *
 * 环境变量：
 *   CDP_PORT  调试端口，默认 9223
 *   CDP_TAB   目标页匹配（URL 子串），默认「第一个非 about:blank 页面」
 */

import { readFileSync, writeFileSync } from 'node:fs';

const PORT = process.env.CDP_PORT ?? '9223';
const BASE = `http://127.0.0.1:${PORT}`;

async function listPages() {
  let r;
  try {
    r = await fetch(`${BASE}/json/list`);
  } catch (e) {
    throw new Error(`无法连接 CDP ${BASE}（Chrome 是否已带 --remote-debugging-port 启动？）: ${e.message}`);
  }
  if (!r.ok) throw new Error(`CDP ${BASE} 返回 ${r.status}`);
  return (await r.json()).filter((t) => t.type === 'page');
}

function pickPage(pages) {
  if (!pages.length) throw new Error('没有 page target');
  const idx = process.env.CDP_TAB_INDEX;
  if (idx !== undefined && idx !== '') {
    const p = pages[Number(idx)];
    if (!p) throw new Error(`CDP_TAB_INDEX=${idx} 越界（共 ${pages.length} 页）`);
    return p;
  }
  const filter = process.env.CDP_TAB;
  if (filter) {
    const hit = pages.find((p) => p.url.includes(filter));
    if (!hit) {
      throw new Error(`没有匹配 "${filter}" 的页面；现有页面:\n  ${pages.map((p) => p.url).join('\n  ')}`);
    }
    return hit;
  }
  return pages.find((p) => !p.url.startsWith('about:')) ?? pages[0];
}

function send(wsUrl, method, params = {}) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(wsUrl);
    const timer = setTimeout(() => {
      try { ws.close(); } catch { /* noop */ }
      reject(new Error(`CDP 调用超时（30s）: ${method}`));
    }, 30000);
    ws.onopen = () => ws.send(JSON.stringify({ id: 1, method, params }));
    ws.onerror = () => { clearTimeout(timer); reject(new Error('WebSocket 连接失败')); };
    ws.onmessage = (ev) => {
      let msg;
      try { msg = JSON.parse(ev.data); } catch { return; }
      if (msg.id !== 1) return;
      clearTimeout(timer);
      ws.close();
      if (msg.error) reject(new Error(`${method}: ${msg.error.message}`));
      else resolve(msg.result);
    };
  });
}

function sendSeq(wsUrl, calls) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(wsUrl);
    const out = [];
    let idx = 0;
    const timer = setTimeout(() => { try { ws.close(); } catch { /* noop */ } reject(new Error('sendSeq 超时（60s）')); }, 60000);
    const next = () => {
      if (idx >= calls.length) { clearTimeout(timer); ws.close(); resolve(out); return; }
      const c = calls[idx];
      let params;
      try {
        params = typeof c.params === 'function' ? c.params(out) : (c.params || {});
      } catch (e) {
        clearTimeout(timer);
        try { ws.close(); } catch { /* noop */ }
        reject(e);
        return;
      }
      ws.send(JSON.stringify({ id: idx + 1, method: c.method, params }));
    };
    ws.onopen = next;
    ws.onmessage = (ev) => {
      let m;
      try { m = JSON.parse(ev.data); } catch { return; }
      if (m.id !== idx + 1) return;
      if (m.error) {
        clearTimeout(timer);
        try { ws.close(); } catch { /* noop */ }
        reject(new Error(`${calls[idx].method}: ${m.error.message}`));
        return;
      }
      out.push(m.result);
      idx += 1;
      next();
    };
    ws.onerror = () => { clearTimeout(timer); reject(new Error('WebSocket 连接失败')); };
  });
}

const [, , cmd, ...args] = process.argv;

function print(obj) {
  console.log(typeof obj === 'string' ? obj : JSON.stringify(obj, null, 2));
}

async function main() {
  const KNOWN = ['pages', 'eval', 'nav', 'screenshot', 'click', 'text', 'key', 'logs', 'inject', 'hold-inject', 'frame-eval', 'set-file'];
  if (!KNOWN.includes(cmd)) {
    console.error('usage: cdp.mjs pages|eval|nav|screenshot|click|text|key|logs|inject|hold-inject ...');
    process.exitCode = 2;
    return;
  }
  const pages = await listPages();

  switch (cmd) {
    case 'pages': {
      print(pages.map((p) => ({ title: p.title, url: p.url })));
      return;
    }
    case 'eval': {
      const page = pickPage(pages);
      const r = await send(page.webSocketDebuggerUrl, 'Runtime.evaluate', {
        expression: args.join(' '),
        awaitPromise: true,
        returnByValue: true,
      });
      if (r.exceptionDetails) {
        console.error('Exception:', r.exceptionDetails.text, r.exceptionDetails.exception?.description ?? '');
        process.exitCode = 1;
      }
      print(r.result?.value);
      return;
    }
    case 'nav': {
      const page = pickPage(pages);
      const r = await send(page.webSocketDebuggerUrl, 'Page.navigate', { url: args[0] });
      print(r);
      return;
    }
    case 'screenshot': {
      const page = pickPage(pages);
      const params = {
        format: 'png',
        captureBeyondViewport: args.includes('--full'),
      };
      const clipArg = args.find((a) => a.startsWith('--clip='));
      if (clipArg) {
        const [cx, cy, cw, ch] = clipArg.slice('--clip='.length).split(',').map(Number);
        params.clip = { x: cx, y: cy, width: cw, height: ch, scale: 1 };
      }
      const r = await send(page.webSocketDebuggerUrl, 'Page.captureScreenshot', params);
      const buf = Buffer.from(r.data, 'base64');
      writeFileSync(args[0], buf);
      print(`saved ${args[0]} (${buf.length} bytes)`);
      return;
    }
    case 'click': {
      const page = pickPage(pages);
      const x = Number(args[0]);
      const y = Number(args[1]);
      for (const type of ['mousePressed', 'mouseReleased']) {
        await send(page.webSocketDebuggerUrl, 'Input.dispatchMouseEvent', {
          type, x, y, button: 'left', clickCount: 1,
        });
      }
      print(`clicked ${x},${y}`);
      return;
    }
    case 'text': {
      const page = pickPage(pages);
      await send(page.webSocketDebuggerUrl, 'Input.insertText', { text: args.join(' ') });
      print('inserted');
      return;
    }
    case 'key': {
      const page = pickPage(pages);
      const key = args[0];
      const vk = key === 'Enter' ? 13 : key === 'Tab' ? 9 : key === 'Escape' ? 27 : 0;
      await send(page.webSocketDebuggerUrl, 'Input.dispatchKeyEvent', {
        type: 'keyDown', key, code: key, windowsVirtualKeyCode: vk, nativeVirtualKeyCode: vk,
      });
      await send(page.webSocketDebuggerUrl, 'Input.dispatchKeyEvent', {
        type: 'keyUp', key, code: key, windowsVirtualKeyCode: vk, nativeVirtualKeyCode: vk,
      });
      print(`key ${key}`);
      return;
    }
    case 'inject': {
      const page = pickPage(pages);
      const src = readFileSync(args[0], 'utf8');
      const r = await send(page.webSocketDebuggerUrl, 'Page.addScriptToEvaluateOnNewDocument', { source: src });
      print({ ok: true, identifier: r.identifier, file: args[0], bytes: src.length });
      return;
    }
    case 'hold-inject': {
      const page = pickPage(pages);
      const src = readFileSync(args[0], 'utf8');
      const minutes = Number(args[1]) || 10;
      const ws = new WebSocket(page.webSocketDebuggerUrl);
      await new Promise((resolve, reject) => {
        ws.onopen = () => {
          ws.send(JSON.stringify({ id: 0, method: 'Page.enable' }));
          ws.send(JSON.stringify({ id: 1, method: 'Page.addScriptToEvaluateOnNewDocument', params: { source: src } }));
          console.log(`hold-inject: registered on ${page.url.slice(0, 90)}; holding ${minutes} min`);
          setTimeout(() => { try { ws.close(); } catch { /* noop */ } resolve(); }, minutes * 60000);
        };
        ws.onmessage = (ev) => {
          console.log('hold-inject cdp resp:', String(ev.data).slice(0, 300));
        };
        ws.onerror = () => reject(new Error('ws error'));
        ws.onclose = () => console.log('hold-inject: ws closed');
      });
      print('hold-inject: released');
      return;
    }
    case 'frame-eval': {
      const page = pickPage(pages);
      const filter = args[0];
      const expr = args.slice(1).join(' ');
      const tree = await send(page.webSocketDebuggerUrl, 'Page.getFrameTree');
      const findFrame = (node) => {
        if ((node.frame.url || '').includes(filter)) return node.frame;
        for (const c of node.childFrames || []) {
          const hit = findFrame(c);
          if (hit) return hit;
        }
        return null;
      };
      const frame = findFrame(tree.frameTree);
      if (!frame) {
        console.error(`未找到匹配 "${filter}" 的 frame`);
        process.exitCode = 1;
        return;
      }
      const world = await send(page.webSocketDebuggerUrl, 'Page.createIsolatedWorld', { frameId: frame.id, worldName: 'cdp-frame' });
      const r = await send(page.webSocketDebuggerUrl, 'Runtime.evaluate', {
        contextId: world.executionContextId,
        expression: expr,
        awaitPromise: true,
        returnByValue: true,
      });
      if (r.exceptionDetails) {
        console.error('Exception:', r.exceptionDetails.text, r.exceptionDetails.exception?.description ?? '');
        process.exitCode = 1;
      }
      print(r.result?.value);
      return;
    }
    case 'set-file': {
      const page = pickPage(pages);
      const filePath = args[0];
      const findInputNode = (node) => {
        if (node.nodeName === 'INPUT') {
          const attrs = node.attributes || [];
          for (let i = 0; i < attrs.length; i += 2) {
            if (attrs[i] === 'type' && attrs[i + 1] === 'file') return node;
          }
        }
        for (const c of node.children || []) {
          const hit = findInputNode(c);
          if (hit) return hit;
        }
        if (node.contentDocument) {
          const hit = findInputNode(node.contentDocument);
          if (hit) return hit;
        }
        return null;
      };
      await sendSeq(page.webSocketDebuggerUrl, [
        { method: 'DOM.enable' },
        { method: 'DOM.getDocument', params: { depth: -1, pierce: true } },
        {
          method: 'DOM.setFileInputFiles',
          params: (prev) => {
            const input = findInputNode(prev[1].root);
            if (!input) throw new Error('未找到 input[type=file]（含 iframe 穿透查找）');
            return { files: [filePath], nodeId: input.nodeId };
          },
        },
      ]);
      print({ ok: true, file: filePath });
      return;
    }
    case 'logs': {
      const page = pickPage(pages);
      const seconds = Number(args[0]) || 8;
      const events = [];
      const reqUrls = new Map();
      const ws = new WebSocket(page.webSocketDebuggerUrl);
      await new Promise((resolve) => {
        const timer = setTimeout(resolve, seconds * 1000);
        ws.onopen = () => {
          ws.send(JSON.stringify({ id: 1, method: 'Runtime.enable' }));
          ws.send(JSON.stringify({ id: 2, method: 'Log.enable' }));
          ws.send(JSON.stringify({ id: 3, method: 'Network.enable' }));
        };
        ws.onmessage = (ev) => {
          let m;
          try { m = JSON.parse(ev.data); } catch { return; }
          if (m.method === 'Runtime.consoleAPICalled') {
            events.push({ k: 'console.' + m.params.type, t: (m.params.args || []).map((a) => a.value ?? a.description ?? a.type).join(' ').slice(0, 400) });
          } else if (m.method === 'Runtime.exceptionThrown') {
            const d = m.params.exceptionDetails;
            events.push({ k: 'exception', t: (d && (d.exception?.description || d.text) || '').slice(0, 500) });
          } else if (m.method === 'Network.requestWillBeSent') {
            reqUrls.set(m.params.requestId, m.params.request.url);
          } else if (m.method === 'Network.loadingFailed') {
            events.push({ k: 'net.fail', t: ((m.params.errorText || '') + ' ' + (reqUrls.get(m.params.requestId) || '')).slice(0, 400) });
          } else if (m.method === 'Log.entryAdded') {
            events.push({ k: 'log.' + m.params.entry.level, t: (m.params.entry.text || '').slice(0, 400) });
          }
        };
        ws.onerror = () => { clearTimeout(timer); resolve(); };
      });
      try { ws.close(); } catch { /* noop */ }
      print(events.slice(0, 60));
      return;
    }
    default:
      console.error('usage: cdp.mjs pages|eval|nav|screenshot|click|text|key ...');
      process.exitCode = 2;
  }
}

main().catch((e) => {
  console.error('ERROR:', e.message);
  process.exitCode = 1;
});
