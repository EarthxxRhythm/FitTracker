#!/usr/bin/env node
/**
 * extract-body-paths.mjs — 从原型资产里抽出体态图所需的路径数据，写成 App 资产。
 *
 * 规格源：`design/06_prototype_redraw/assets/opengym-ref/body-paths.js`
 * （原型是 minified JS：`var e={male:{front:{vb,p},back:{vb,p}},female:{...}}`）。
 * 复刻它的脚本是 `fittracker-review.html` 的 `renderBodyMap()`：
 * 只取 `BODY_PATHS.male`，只渲染 `front` 与 `back` 两个视图——所以这里也只抽这两份，
 * 不把 female 与其它视图带进 APK。
 *
 * 用法：
 *   node tools/extract-body-paths.mjs
 * 输出：
 *   app/src/main/assets/body-paths.json  （{ front: { vb, p }, back: { vb, p } }）
 *
 * 为什么要抽成资产而不是手抄进 Kotlin：路径数据约 90KB，手抄必错且不可复核；
 * 资产 + 本脚本让「数据从哪来」可复现（重跑本脚本即得同一份 JSON）。
 */

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const SRC = resolve(ROOT, 'design/06_prototype_redraw/assets/opengym-ref/body-paths.js');
const OUT = resolve(ROOT, 'app/src/main/assets/body-paths.json');

/** 原型脚本里用到的两个视图（`renderBodyMap()` 只 append front 与 back）。 */
const VIEWS = ['front', 'back'];

// 该文件是 **ES module**（末尾 `export{e as default}`，且全文件无换行），
// 不是 `var e=…` 脚本——必须走动态 import 取 default，用 eval/Function 会报
// `Unexpected token 'export'`。
const mod = await import(pathToFileURL(SRC).href);
const male = mod.default && mod.default.male;
if (!male) {
  console.error('未在 body-paths.js 里找到 male 数据，格式可能变了');
  process.exit(1);
}

const out = {};
for (const v of VIEWS) {
  const view = male[v];
  if (!view || !view.vb || !view.p) {
    console.error(`缺少 male.${v}`);
    process.exit(1);
  }
  out[v] = { vb: view.vb, p: view.p };
}

mkdirSync(dirname(OUT), { recursive: true });
writeFileSync(OUT, JSON.stringify(out));

const stats = VIEWS.map((v) => {
  const keys = Object.keys(out[v].p);
  const n = keys.reduce((a, k) => a + out[v].p[k].length, 0);
  return `${v}: ${keys.length} 组 / ${n} 条路径`;
});
console.log(`已写出 ${OUT}`);
console.log(stats.join(' · '));
