#!/usr/bin/env node
/**
 * render-prototype.mjs — 把原型 HTML 中的**指定屏帧**渲染为 PNG。
 *
 * 用途：为「Compose 还原 vs 原型」的视觉比对提供参照图。
 *
 * 用法：
 *   node tools/render-prototype.mjs \
 *     --html design/06_prototype_redraw/src/fittracker-welcome-home.html \
 *     --frame screen-welcome \
 *     --out .rivet/scratch/ref-welcome.png
 *
 * 参数：
 *   --html   原型 HTML 路径（相对仓库根或绝对路径）
 *   --frame  目标屏帧的 data-od-id（如 screen-home）
 *   --out    输出 PNG 路径
 *   --pad    围绕截取区域的外扩像素（默认 0）
 *   --chrome Chrome 可执行文件路径（默认自动探测）
 *   --port   CDP 端口（默认 9333）
 *
 * 截取目标：帧元素内的 `.phone`（原型里那个 390×844 的 App 视口）；
 * 若不存在 `.phone`，退化为帧元素自身。
 */

import { writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { pathToFileURL } from 'node:url';
import { withPage } from './lib/cdp.mjs';
import { renderableUrl } from './lib/proto-page.mjs';

const argv = process.argv.slice(2);
const arg = (name, fallback = undefined) => {
  const i = argv.indexOf(`--${name}`);
  return i >= 0 && i + 1 < argv.length ? argv[i + 1] : fallback;
};

const htmlArg = arg('html');
const frame = arg('frame');
const outArg = arg('out');
if (!htmlArg || !frame || !outArg) {
  console.error('用法: node tools/render-prototype.mjs --html <file> --frame <id> --out <png> [--pad N]');
  process.exit(2);
}

const htmlPath = resolve(htmlArg);
if (!existsSync(htmlPath)) {
  console.error(`HTML 不存在: ${htmlPath}`);
  process.exit(2);
}
const outPath = resolve(outArg);
mkdirSync(dirname(outPath), { recursive: true });

const pad = Number(arg('pad', '0'));

try {
  await withPage(
    { chrome: arg('chrome'), port: Number(arg('port', '9333')) },
    async ({ cdp, sessionId, goto, evalJson }) => {
      // 走 renderableUrl：原型里 `assets/...` 相对 src/ 解析会 404，注入 <base> 后才是规格本意
      await goto(renderableUrl(htmlPath));

      const info = await evalJson(`(() => {
        const host = document.querySelector('[data-od-id="${frame}"]');
        if (!host) return { error: 'frame-not-found' };
        const phone = host.querySelector('.phone');
        const el = phone || host;
        const r = el.getBoundingClientRect();
        return {
          usedPhone: !!phone,
          x: r.x + window.scrollX, y: r.y + window.scrollY,
          w: r.width, h: r.height,
          borderRadius: getComputedStyle(el).borderTopLeftRadius,
        };
      })()`);

      if (!info || info.error) throw new Error(`未找到帧 ${frame}`);

      const clip = {
        x: Math.max(0, info.x - pad),
        y: Math.max(0, info.y - pad),
        width: info.w + pad * 2,
        height: info.h + pad * 2,
        scale: 1,
      };

      const shot = await cdp.send('Page.captureScreenshot', {
        format: 'png',
        clip,
        captureBeyondViewport: true,
      }, sessionId);

      writeFileSync(outPath, Buffer.from(shot.data, 'base64'));

      console.log(JSON.stringify({
        frame,
        device: info.usedPhone ? '.phone' : 'frame-element',
        rect: clip,
        borderRadius: info.borderRadius,
        out: outPath,
      }, null, 2));
    },
  );
} catch (err) {
  console.error('渲染失败:', err.message);
  process.exit(1);
}
