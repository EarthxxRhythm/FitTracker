/**
 * proto-page.mjs — 把原型 HTML 变成**可正确解析资源**的渲染入口。
 *
 * 背景（实测得出的规格缺陷）：原型 HTML 位于 `design/06_prototype_redraw/src/`，
 * 但脚本与图片用的是 `assets/...` 这种相对路径——相对 `src/` 解析会指向
 * `src/assets/...`，而 `assets/` 其实是 `src/` 的**兄弟目录**。于是这些资源一律 404：
 * - `fittracker-review.html` 的 `assets/opengym-ref/body-paths.iife.js` → 拿不到
 *   `window.BODY_PATHS` → `renderBodyMap()` 提前返回 → **体态图整块塌成 0 高**；
 * - `fittracker-exercise-library.html` / `fittracker-personal.html` 的
 *   `assets/exercise-gifs/*.gif` → 同类问题（Wave D 会用到）；
 * - 各屏的 `assets/ft-stage.js` → 同类问题（静止态无视觉影响，故一直没暴露）。
 *
 * 实测证据：探针 `.rivet/scratch/probe-bodymap.mjs` 在原型页面上量到
 * `window.BODY_PATHS === "undefined"`、`#bodymap svg` 数量 0、`.bodymap` 高度 0。
 *
 * 做法：读原 HTML，在 `<head>` 里注入一个 `<base href="<设计根>/">`，把结果写到
 * `.rivet/scratch/render/`（**不改冻结目录**），返回该副本的 file URL。
 * 注入 base 后，`assets/...` 会正确解析到设计根下的 assets/——也就是规格的**本意**。
 * 这一步只影响参照图与原型文本提取，不参与 App 侧任何逻辑。
 */

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { basename, dirname, join, resolve, sep } from 'node:path';
import { pathToFileURL } from 'node:url';

const OUT_DIR = resolve('.rivet/scratch/render');

/**
 * @param {string} htmlPath 原型 HTML 的绝对路径
 * @returns {string} 可交给 `Page.navigate` 的 file URL（指向注入 base 后的副本）
 */
export function renderableUrl(htmlPath) {
  const html = readFileSync(htmlPath, 'utf8');
  // HTML 在 `src/` 下，设计根是它的上一级（assets/ 就在那里）
  const designRoot = resolve(dirname(htmlPath), '..');
  const baseHref = pathToFileURL(designRoot + sep).href;

  const patched = html.replace(
    /<head([^>]*)>/i,
    (m, attrs) => `<head${attrs}><base href="${baseHref}">`,
  );
  if (patched === html) {
    // 没有 <head> 就原样用原文件，避免静默产生一个没注入的副本
    return pathToFileURL(htmlPath).href;
  }

  mkdirSync(OUT_DIR, { recursive: true });
  const outPath = join(OUT_DIR, basename(htmlPath));
  writeFileSync(outPath, patched);
  return pathToFileURL(outPath).href;
}
