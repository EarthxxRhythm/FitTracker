#!/usr/bin/env node
// check-site.mjs —— 官网静态门禁（零依赖）
//
// 六条检查（site/ 为站点根）：
//   1. 每个 .html 有 <html lang="zh-CN">、非空 <title>、非空 meta description
//   2. 所有本地 href/src/srcset 指向的文件存在
//   3. 站内互链可达：每页必须链接另外两页（不要求链自身）
//   4. 无开发期占位标记（未完成注释、假文、连续 x 占位）；data-pending 元素放行
//   5. 零第三方资源：script/link/img 等资源标签不指向外部域名；<a> 外链允许
//   6. 每个 <img> 有非空 alt 与显式 width/height
//
// 用法：node tools/check-site.mjs [--root <dir>]
// 通过：打印 '[check-site] 6 项检查全部通过'，exit 0；否则逐条打印并 exit 1。

import { readFileSync, existsSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..')

function parseRoot(argv) {
  const index = argv.indexOf('--root')
  if (index === -1) return join(repoRoot, 'site')
  return resolve(argv[index + 1])
}

/** 提取 HTML 中的本地资源引用（href/src/srcset），跳过锚点与协议前缀。 */
export function localRefsOf(html) {
  const refs = []
  const attrRe = /\b(?:href|src)="([^"]+)"/g
  let match
  while ((match = attrRe.exec(html)) !== null) {
    const value = match[1]
    if (/^(?:#|https?:|mailto:|tel:|data:)/.test(value)) continue
    refs.push(value.split('#')[0])
  }
  const srcsetRe = /srcset="([^"]+)"/g
  while ((match = srcsetRe.exec(html)) !== null) {
    for (const part of match[1].split(',')) {
      const url = part.trim().split(/\s+/)[0]
      if (url && !/^(?:https?:|data:)/.test(url)) refs.push(url.split('#')[0])
    }
  }
  return [...new Set(refs.filter((r) => r !== ''))]
}

/** 检查开发期占位标记；返回命中列表（data-pending 元素内部放行）。 */
export function findPlaceholders(html) {
  const hits = []
  const stripped = html.replace(/<[^>]+?\bdata-pending[^>]*>[\s\S]*?<\/[a-zA-Z][^>]*>/g, (m) => ' '.repeat(m.length))
  if (/<!--\s*(?:todo|fixme)/i.test(stripped)) hits.push('未完成注释')
  if (/lorem\s+ipsum/i.test(stripped)) hits.push('假文段落')
  if (/x{4,}/i.test(stripped.replace(/<[^>]+>/g, ' '))) hits.push('连续 x 占位')
  return hits
}

/** 检查资源标签引用是否指向外部域名；<a> 外链允许。 */
export function externalResourceRefs(html) {
  const hits = []
  const attrRe = /<(?!a\b)[^>]+\b(?:href|src)="(https?:\/\/[^"]+)"/gi
  let match
  while ((match = attrRe.exec(html)) !== null) {
    hits.push(match[1])
  }
  const cssUrlRe = /url\(\s*(['"]?)(https?:\/\/[^)'"]+)\1\s*\)/g
  while ((match = cssUrlRe.exec(html)) !== null) {
    hits.push(match[2])
  }
  return hits
}

/** 检查 img 的 alt / width / height。 */
export function imgsMissingAttrs(html) {
  const missing = []
  const imgRe = /<img\b[^>]*>/g
  let match
  while ((match = imgRe.exec(html)) !== null) {
    const tag = match[0]
    const alt = /\balt="([^"]*)"/.exec(tag)
    if (alt === null || alt[1].trim() === '') missing.push('缺 alt')
    if (!/\bwidth="/.test(tag)) missing.push('缺 width')
    if (!/\bheight="/.test(tag)) missing.push('缺 height')
  }
  return missing
}

/** 检查头部必备项；返回缺失项列表。 */
export function headMissing(html) {
  const missing = []
  if (!/<html\s+lang="zh-CN"/.test(html)) missing.push('lang="zh-CN"')
  if (!/<title>[^<]+<\/title>/.test(html)) missing.push('非空 <title>')
  if (!/<meta\s+name="description"\s+content="[^"]+"/.test(html)) missing.push('meta description')
  return missing
}

function main() {
  const siteRoot = parseRoot(process.argv)
  const findings = []
  const pages = ['index.html', 'privacy.html', 'terms.html', '404.html']
  const navPages = ['index.html', 'privacy.html', 'terms.html']

  for (const page of pages) {
    const path = join(siteRoot, page)
    if (!existsSync(path)) {
      findings.push(`${page}: 文件不存在`)
      continue
    }
    const html = readFileSync(path, 'utf8')

    // 1. 头部
    for (const item of headMissing(html)) findings.push(`${page}: 头部缺 ${item}`)

    // 2. 本地资源存在性
    for (const ref of localRefsOf(html)) {
      if (!existsSync(join(siteRoot, ref))) findings.push(`${page}: 资源不存在 → ${ref}`)
    }

    // 3. 页脚互链：每页必须链接另外两页（不要求链自身）
    for (const link of navPages.filter((p) => p !== page)) {
      const re = new RegExp('href="' + link + '"')
      if (!re.test(html)) findings.push(`${page}: 页脚缺链 → ${link}`)
    }

    // 4. 占位标记
    for (const hit of findPlaceholders(html)) findings.push(`${page}: 占位标记 → ${hit}`)

    // 5. 第三方资源（<a> 外链允许；script/link/img 等资源外链禁止）
    for (const ext of externalResourceRefs(html)) findings.push(`${page}: 外部资源引用 → ${ext}`)

    // 6. img 属性
    for (const item of imgsMissingAttrs(html)) findings.push(`${page}: img ${item}`)
  }

  if (findings.length > 0) {
    console.error(`[check-site] ${findings.length} 处问题：`)
    for (const finding of findings) console.error('  - ' + finding)
    process.exit(1)
  }
  console.log('[check-site] 6 项检查全部通过（' + pages.length + ' 页）')
}

// 仅直接执行时跑；被 import（单测）时只暴露纯函数
const isDirectRun =
  process.argv[1] !== undefined &&
  resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url))

if (isDirectRun) main()
