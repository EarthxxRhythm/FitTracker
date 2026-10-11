#!/usr/bin/env node
/**
 * proto-text.mjs — 提取原型指定屏帧的**可见文本集合**。
 *
 * 用途：与设备端 uiautomator 语义树的文本做集合差，客观回答
 * 「原型里有、实现里缺失（或多出）的文案」，替代「读图目测元素是否齐全」。
 * 这是把验收判绿从「看着像」推进到「可计算」的一半。
 *
 * 用法：
 *   node tools/proto-text.mjs \
 *     --html design/06_prototype_redraw/src/fittracker-plan.html \
 *     --frame screen-plan
 *
 * 参数：
 *   --html    原型 HTML 路径（相对仓库根或绝对路径）
 *   --frame   目标屏帧的 data-od-id（如 screen-plan）
 *   --port    CDP 端口（默认 9335，与 render-prototype 的 9333 错开以免抢占）
 *   --chrome  Chrome 可执行文件路径（默认自动探测）
 *
 * 输出：stdout 一行 JSON `{ frame, count, texts: [...] }`。
 *
 * 口径（三条，都为了比对时既不假绿也不假红）：
 * 1. 只收元素**自身的直接文本节点**（`childNodes` 过滤 nodeType===3）。
 *    若用 `textContent`，父元素会把子树文本一并计入，一条缺失会被父元素掩盖 → 假绿。
 * 2. 跳过 `display:none` / `visibility:hidden` / `opacity:0` 与零尺寸元素，
 *    与「屏幕上看得见」对齐——原型正是用 `.pane{opacity:0}` 藏起未激活的 Tab 页。
 * 3. 文本 trim 后非空才算，并去重（同一文案在多处出现只留一份）。
 */

import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
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
if (!htmlArg || !frame) {
  console.error('用法: node tools/proto-text.mjs --html <file> --frame <id> [--port N]');
  process.exit(2);
}

const htmlPath = resolve(htmlArg);
if (!existsSync(htmlPath)) {
  console.error(`HTML 不存在: ${htmlPath}`);
  process.exit(2);
}

const probeExpr = `(() => {
  const host = document.querySelector('[data-od-id="${frame}"]');
  if (!host) return { error: 'frame-not-found' };
  // 与 render-prototype.mjs 同口径：只取 frame 内的 .phone。原型文档外壳的
  // .stage-label / .page-foot 不属于屏内容，纳入会与设备端产生系统性假缺失。
  const scope = host.querySelector('.phone') || host;
  const scopeBox = scope.getBoundingClientRect();
  const seen = new Set();
  const items = [];
  scope.querySelectorAll('*').forEach((el) => {
    const tag = el.tagName.toLowerCase();
    if (tag === 'script' || tag === 'style' || tag === 'svg' || tag === 'use') return;
    const own = Array.from(el.childNodes)
      .filter((n) => n.nodeType === 3)
      .map((n) => n.textContent.trim())
      .filter(Boolean)
      .join(' ')
      .trim();
    if (!own) return;
    // 关键：用 checkVisibility 走祖先链，而不是读元素自身的 computed style。
    // opacity 与 display 都**不继承**——只查自身时，父级 .deck-card{opacity:0}
    // 藏起来的远端卡片，其子元素的 computed opacity 仍是 1，会整片漏过过滤
    // （plan 屏实测：第 3/4/5 天卡片的内容被误收，造成 33 条假缺失）。
    if (el.checkVisibility && !el.checkVisibility({
      opacityProperty: true,
      visibilityProperty: true,
      contentVisibilityAuto: true,
    })) return;
    const r = el.getBoundingClientRect();
    if (r.width < 1 || r.height < 1) return;
    // 裁剪判定：元素必须在**所有会裁剪的祖先**的可见区域内留有可见部分。
    // 只比对 .phone 不够——滚动容器（如 .pgd-scroll 的 overflow-y:auto）会先一步
    // 裁掉超出部分，而 .phone 仍罩得住它（planGroup 屏实测：「推」日第 4 个动作在
    // .pgd-scroll 之外、中心点却仍在 844 视口内，被误判为可见 → 3 条假缺失）。
    let visTop = r.top, visBottom = r.bottom, visLeft = r.left, visRight = r.right;
    for (let node = el.parentElement; node && node !== scope.parentElement; node = node.parentElement) {
      const cs = getComputedStyle(node);
      if (/hidden|auto|scroll/.test(cs.overflow + cs.overflowX + cs.overflowY)) {
        const nr = node.getBoundingClientRect();
        visTop = Math.max(visTop, nr.top);
        visBottom = Math.min(visBottom, nr.bottom);
        visLeft = Math.max(visLeft, nr.left);
        visRight = Math.min(visRight, nr.right);
      }
    }
    if (visBottom - visTop < 1 || visRight - visLeft < 1) return;
    if (!seen.has(own)) {
      seen.add(own);
      // 坐标相对画布左上角（scope 即 .phone），单位与设计空间一致（CSS px），
      // 供 accept-screen.py 的位置对齐比对使用
      items.push({
        text: own,
        x: Math.round((r.left + r.right) / 2 - scopeBox.left),
        y: Math.round((r.top + r.bottom) / 2 - scopeBox.top),
      });
    }
  });
  return { texts: Array.from(seen), items };
})()`;

try {
  await withPage(
    { chrome: arg('chrome'), port: Number(arg('port', '9335')) },
    async ({ goto, evalJson }) => {
      // 与 render-prototype 同口径：注入 <base> 让 `assets/...` 正确解析（否则体态图等资源 404）
      await goto(renderableUrl(htmlPath));
      const info = await evalJson(probeExpr);
      if (!info || info.error) {
        throw new Error(`未找到帧 ${frame}（${info && info.error ? info.error : 'probe-failed'}）`);
      }
      // CLI 契约输出：accept-screen.py 消费 stdout 的最后一行 JSON。
      // 用 process.stdout.write 而非 console.log——这不是日志，是进程间数据通道，
      // console.log 会被交付门的「调试探针残留」模式误报。
      process.stdout.write(JSON.stringify({
        frame,
        count: info.texts.length,
        texts: info.texts,
        items: info.items,
      }) + '\n');
    },
  );
} catch (err) {
  console.error('提取失败:', err.message);
  process.exit(1);
}
