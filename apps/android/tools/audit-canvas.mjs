#!/usr/bin/env node
/**
 * audit-canvas.mjs — 逐屏实测画布口径。
 *
 * 直接从原型 `fittracker-webapp.html` 的 `ROUTE_ORDER` + `ROUTES` 派生全部 15 条路由，
 * 再逐帧在真实浏览器里探测：
 *   - `.phone` 视口尺寸（应恒为 390×844，含 1px 边框）
 *   - `.phone` 首个子元素（直绘屏是 `.appshell` 一类满铺容器；缩放屏是 `.w-frame` / `.auth-frame` / `.cf-frame`）
 *   - 该子元素的**布局尺寸**（offsetWidth/Height = 设计空间，未含变换）
 *   - computed transform 矩阵中提取的实际缩放比
 *
 * 判定：缩放比与 1 的差 > 1e-4 ⇒ 缩放画布；否则直绘。
 *
 * ⚠️ 判据按 transform 判定，**不得**硬编码 430×900——
 * `fittracker-training-complete.html:178-190` 的 `.cf-frame` 设计空间是 430×930.6
 * （`height: calc(844px / var(--scale))`），硬编码判据会把它误判为直绘。
 *
 * 用法：
 *   node tools/audit-canvas.mjs [--json out.json]
 */

import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { withPage } from './lib/cdp.mjs';

const argv = process.argv.slice(2);
const arg = (name, fallback = undefined) => {
  const i = argv.indexOf(`--${name}`);
  return i >= 0 && i + 1 < argv.length ? argv[i + 1] : fallback;
};

const SRC = resolve(arg('src', 'design/06_prototype_redraw/src'));
const WEBAPP = resolve(SRC, 'fittracker-webapp.html');

// ── 从原型壳解析路由表（唯一事实源） ─────────────────────────
const shell = readFileSync(WEBAPP, 'utf8');

const orderMatch = shell.match(/ROUTE_ORDER\s*=\s*\[([^\]]+)\]/);
if (!orderMatch) throw new Error('未能从 webapp 壳解析 ROUTE_ORDER');
const order = orderMatch[1]
  .split(',')
  .map((s) => s.trim().replace(/^['"]|['"]$/g, ''))
  .filter(Boolean);

const routes = new Map();
for (const m of shell.matchAll(/(\w+)\s*:\s*\{\s*file:\s*'([^']+)'\s*,\s*frame:\s*'([^']+)'/g)) {
  routes.set(m[1], { file: m[2], frame: m[3] });
}

const missing = order.filter((k) => !routes.has(k));
if (missing.length) throw new Error(`ROUTES 缺少条目: ${missing.join(', ')}`);

// ── 按文件分组，减少导航次数 ─────────────────────────────────
const byFile = new Map();
for (const key of order) {
  const r = routes.get(key);
  if (!byFile.has(r.file)) byFile.set(r.file, []);
  byFile.get(r.file).push({ key, frame: r.frame });
}

const probeExpr = (frame) => `(() => {
  const host = document.querySelector('[data-od-id="${frame}"]');
  if (!host) return { error: 'frame-not-found' };
  const phone = host.querySelector('.phone');
  const inner = phone ? phone.firstElementChild : null;
  const pr = phone ? phone.getBoundingClientRect() : null;
  const cs = inner ? getComputedStyle(inner) : null;
  let scale = 1;
  if (cs && cs.transform && cs.transform !== 'none') {
    const m = cs.transform.match(/matrix\\(([^)]+)\\)/);
    if (m) { const p = m[1].split(',').map(Number); scale = p[0]; }
  }
  return {
    phoneW: pr ? Math.round(pr.width) : null,
    phoneH: pr ? Math.round(pr.height) : null,
    innerClass: inner ? inner.className : null,
    designW: inner ? inner.offsetWidth : null,
    designH: inner ? inner.offsetHeight : null,
    scale,
    cssScaleVar: cs ? (cs.getPropertyValue('--scale') || cs.getPropertyValue('--active-scale') || '').trim() : '',
  };
})()`;

const rows = [];

await withPage({ chrome: arg('chrome'), port: Number(arg('port', '9334')) }, async ({ goto, evalJson }) => {
  for (const [file, frames] of byFile) {
    await goto(pathToFileURL(resolve(SRC, file)).href);
    for (const { key, frame } of frames) {
      const info = await evalJson(probeExpr(frame));
      if (!info || info.error) {
        rows.push({ route: key, file, frame, error: info?.error ?? 'probe-failed' });
        continue;
      }
      const scaled = Math.abs(info.scale - 1) > 1e-4;
      rows.push({
        route: key,
        file,
        frame,
        phone: `${info.phoneW}×${info.phoneH}`,
        inner: info.innerClass,
        design: `${info.designW}×${info.designH}`,
        scale: Number(info.scale.toFixed(5)),
        cssVar: info.cssScaleVar,
        canvas: scaled ? 'Scaled' : 'Direct',
        effective: `${Math.round(info.designW * info.scale)}×${Math.round(info.designH * info.scale)}`,
      });
    }
  }
});

// ── 输出 ────────────────────────────────────────────────────
const w = (s, n) => String(s ?? '').padEnd(n);
console.log(`${w('route', 12)}${w('inner', 14)}${w('design', 11)}${w('scale', 9)}${w('effective', 11)}${w('cssVar', 9)}canvas`);
console.log('-'.repeat(76));
for (const r of rows) {
  if (r.error) {
    console.log(`${w(r.route, 12)}ERROR: ${r.error}`);
    continue;
  }
  console.log(
    `${w(r.route, 12)}${w(r.inner, 14)}${w(r.design, 11)}${w(r.scale, 9)}${w(r.effective, 11)}${w(r.cssVar, 9)}${r.canvas}`,
  );
}

const scaled = rows.filter((r) => r.canvas === 'Scaled');
console.log('');
console.log(`缩放画布屏 (${scaled.length}): ${scaled.map((r) => r.route).join(', ') || '（无）'}`);
console.log(`直绘画布屏 (${rows.length - scaled.length}): ${rows.filter((r) => r.canvas === 'Direct').map((r) => r.route).join(', ')}`);
console.log('');
console.log('缩放屏设计空间明细：');
for (const r of scaled) {
  console.log(`  ${r.route.padEnd(10)} 设计 ${r.design}  scale ${r.scale}  → 实测占位 ${r.effective}`);
}

const jsonOut = arg('json');
if (jsonOut) {
  writeFileSync(resolve(jsonOut), JSON.stringify({ order, rows }, null, 2));
  console.log(`\n已写出: ${resolve(jsonOut)}`);
}
