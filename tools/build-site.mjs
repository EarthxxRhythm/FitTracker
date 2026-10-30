#!/usr/bin/env node
// tools/build-site.mjs —— 站点生成器（零依赖，只用 node: 内置模块）
//
// 职责三件：
//   1) 渲染法务页：docs/legal/*.md → site/privacy.html、site/terms.html
//   2) 同步图片：docs/screenshots/*.jpg 与品牌符号 → site/assets/img/（逐条比 sha256）
//   3) --check 漂移校验：法务页正文或图片哈希与磁盘不一致时 exit 1
//
// 用法：
//   node tools/build-site.mjs            # 写盘，末行 site build done
//   node tools/build-site.mjs --check    # 只校验，通过末行 site is up to date

import { readFileSync, writeFileSync, mkdirSync, copyFileSync, existsSync } from 'node:fs'
import { createHash } from 'node:crypto'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const siteRoot = join(repoRoot, 'site')

const LEGAL = [
  {
    src: 'docs/legal/privacy-policy.md',
    out: 'site/privacy.html',
    slug: 'privacy.html',
    title: '隐私政策 · 菲特 FitTracker',
    desc: '菲特 FitTracker 隐私政策：说明训练计划、训练记录与身体数据存放在哪里、登录后如何同步，以及本应用仅申请的联网与振动两项权限。'
  },
  {
    src: 'docs/legal/user-agreement.md',
    out: 'site/terms.html',
    slug: 'terms.html',
    title: '用户协议 · 菲特 FitTracker',
    desc: '菲特 FitTracker 用户协议：服务说明、健康与安全免责声明、账号与数据责任边界，以及与隐私政策的关系。'
  }
]

// 截图与品牌符号：源在仓库已有位置，产物复制到 site/assets/img/（部署目录须自包含）
const ASSETS = [
  ['docs/screenshots/01-home.jpg', 'site/assets/img/01-home.jpg'],
  ['docs/screenshots/02-training.jpg', 'site/assets/img/02-training.jpg'],
  ['docs/screenshots/04-review.jpg', 'site/assets/img/04-review.jpg'],
  ['docs/screenshots/05-plans.jpg', 'site/assets/img/05-plans.jpg'],
  ['docs/screenshots/06-library.jpg', 'site/assets/img/06-library.jpg'],
  ['docs/screenshots/07-body.jpg', 'site/assets/img/07-body.jpg'],
  ['docs/screenshots/08-profile.jpg', 'site/assets/img/08-profile.jpg'],
  ['apps/harmony/entry/src/main/resources/rawfile/fittracker-logo-ring.svg', 'site/assets/img/logo-ring.svg']
]

// ── 行内渲染 ────────────────────────────────────────────────────────────────

/** 先转义再套行内标记：& < > 一律实体化。 */
function escapeHtml(text) {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
}

/** 行内标记：`code`、**strong**、[text](url)。文本已转义后调用。 */
function renderInline(rawText) {
  let s = escapeHtml(rawText)
  s = s.replace(/`([^`]+)`/g, '<code>$1</code>')
  s = s.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
  s = s.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (m, text, url) => {
    const external = /^https?:\/\//i.test(url)
    const attrs = external ? ' rel="noopener noreferrer"' : ''
    return `<a href="${url}"${attrs}>${text}</a>`
  })
  return s
}

// ── 块级状态机 ──────────────────────────────────────────────────────────────

function isTableRow(line) {
  return line.trim().startsWith('|')
}

function isTableSeparator(line) {
  const t = line.trim()
  return t.includes('|') && t.includes('-') && /^[|\s:-]+$/.test(t)
}

function splitTableCells(row) {
  return row
    .trim()
    .replace(/^\|/, '')
    .replace(/\|$/, '')
    .split('|')
    .map((cell) => cell.trim())
}

/**
 * 把法务 Markdown 渲染成正文 HTML 片段。
 * 支持的块级语法：# / ## / ### 标题、"- " 列表、"1. " 有序列表、
 * 表格（含分隔行）、空行分段、其余行成段。不支持的特性按普通段落文本处理，不抛错。
 */
export function renderLegalMarkdown(md) {
  const lines = String(md).replace(/\r\n?/g, '\n').split('\n')
  const out = []
  const para = []
  let listTag = ''

  const flushPara = () => {
    if (para.length > 0) {
      out.push(`<p>${renderInline(para.join('\n'))}</p>`)
      para.length = 0
    }
  }
  const flushList = () => {
    if (listTag) {
      out.push(`</${listTag}>`)
      listTag = ''
    }
  }
  const flushAll = () => {
    flushPara()
    flushList()
  }

  let i = 0
  while (i < lines.length) {
    const line = lines[i]
    const trimmed = line.trim()

    // 空行：结束当前块
    if (trimmed === '') {
      flushAll()
      i++
      continue
    }

    // 表格：表头行 + 分隔行 + 连续数据行
    if (isTableRow(line) && i + 1 < lines.length && isTableSeparator(lines[i + 1])) {
      flushAll()
      const header = splitTableCells(lines[i])
      i += 2
      const rows = []
      while (i < lines.length && isTableRow(lines[i])) {
        rows.push(splitTableCells(lines[i]))
        i++
      }
      const headHtml = `<thead><tr>${header.map((c) => `<th>${renderInline(c)}</th>`).join('')}</tr></thead>`
      const bodyHtml = rows
        .map((cells) => `<tr>${cells.map((c) => `<td>${renderInline(c)}</td>`).join('')}</tr>`)
        .join('\n')
      out.push(
        '<div class="table-wrap">\n<table>\n' +
          headHtml +
          '\n<tbody>\n' +
          bodyHtml +
          '\n</tbody>\n</table>\n</div>'
      )
      continue
    }

    // 标题
    const heading = /^(#{1,3})\s+(.+?)\s*#*$/.exec(trimmed)
    if (heading) {
      flushAll()
      const level = heading[1].length
      out.push(`<h${level}>${renderInline(heading[2])}</h${level}>`)
      i++
      continue
    }

    // 无序列表
    if (/^[-*]\s+/.test(trimmed)) {
      flushPara()
      if (listTag !== 'ul') {
        flushList()
        out.push('<ul>')
        listTag = 'ul'
      }
      out.push(`<li>${renderInline(trimmed.replace(/^[-*]\s+/, ''))}</li>`)
      i++
      continue
    }

    // 有序列表
    if (/^\d+\.\s+/.test(trimmed)) {
      flushPara()
      if (listTag !== 'ol') {
        flushList()
        out.push('<ol>')
        listTag = 'ol'
      }
      out.push(`<li>${renderInline(trimmed.replace(/^\d+\.\s+/, ''))}</li>`)
      i++
      continue
    }

    // 其余：累积成段（连续行合并，空行/块边界处收束）
    flushList()
    para.push(trimmed)
    i++
  }
  flushAll()

  return out.join('\n') + '\n'
}

/** 提取 <article …>…</article> 内文，供 --check 比对。 */
export function extractArticle(html) {
  const match = /<article\b[^>]*>([\s\S]*?)<\/article>/.exec(String(html))
  return match ? match[1] : ''
}

// ── 页面模板 ────────────────────────────────────────────────────────────────

const BRAND_SVG =
  '<svg viewBox="0 0 24 24" aria-hidden="true">\n' +
  '          <path d="M 18.527 5.473 A 9.231 9.231 0 1 1 5.473 5.473" fill="none" stroke="#50ECA7" stroke-width="3.538" stroke-linecap="round"/>\n' +
  '          <circle cx="12" cy="2.769" r="2.154" fill="#50ECA7"/>\n' +
  '        </svg>'

export function pageShell(title, slug, bodyHtml) {
  const item = LEGAL.find((entry) => entry.slug === slug)
  const desc = item ? item.desc : title
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title}</title>
<meta name="description" content="${desc}">
<meta name="theme-color" content="#09100F">
<link rel="icon" href="assets/img/logo-ring.svg" type="image/svg+xml">
<link rel="stylesheet" href="assets/site.css">
</head>
<body class="page-legal">

<header class="topbar">
  <div class="wrap topbar-inner">
    <a class="brand" href="index.html">
      ${BRAND_SVG}
      菲特 <em>FitTracker</em>
    </a>
    <nav class="nav" aria-label="次要导航">
      <a href="index.html">返回首页</a>
    </nav>
  </div>
</header>

<main class="legal">
  <article class="legal-body">
${bodyHtml}  </article>
</main>

<footer class="site-foot">
  <div class="wrap">
    <div class="foot-grid">
      <div>
        <div class="foot-brand">
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M 18.527 5.473 A 9.231 9.231 0 1 1 5.473 5.473" fill="none" stroke="#50ECA7" stroke-width="3.538" stroke-linecap="round"/>
            <circle cx="12" cy="2.769" r="2.154" fill="#50ECA7"/>
          </svg>
          菲特 FitTracker
        </div>
        <p class="foot-desc">双端原生健身训练记录。数据默认留在本机，登录后自动同步。</p>
      </div>
      <div class="foot-col">
        <h4>文档</h4>
        <a href="index.html">首页</a>
        <a href="privacy.html">隐私政策</a>
        <a href="terms.html">用户协议</a>
      </div>
    </div>
    <div class="foot-bottom">
      <span>© 2026 EarthRhythm</span>
      <span class="spacer"></span>
    </div>
  </div>
</footer>

</body>
</html>
`
}

// ── 主流程 ──────────────────────────────────────────────────────────────────

function sha256Of(buffer) {
  return createHash('sha256').update(buffer).digest('hex')
}

function sha256OfFile(absPath) {
  return sha256Of(readFileSync(absPath))
}

function countLines(text) {
  return text.split('\n').length
}

function byteLength(text) {
  return Buffer.byteLength(text, 'utf8')
}

function main() {
  const checkMode = process.argv.includes('--check')
  const drifts = []

  // 1) 法务页
  for (const item of LEGAL) {
    const mdPath = join(repoRoot, item.src)
    if (!existsSync(mdPath)) {
      drifts.push(`${item.out}: 源文件缺失 ${item.src}`)
      continue
    }
    const md = readFileSync(mdPath, 'utf8')
    const html = pageShell(item.title, item.slug, renderLegalMarkdown(md))
    const outPath = join(repoRoot, item.out)
    const onDisk = existsSync(outPath) ? readFileSync(outPath, 'utf8') : ''

    if (checkMode) {
      if (onDisk === '') {
        drifts.push(`${item.out}: 未生成`)
      } else if (extractArticle(onDisk).trim() !== extractArticle(html).trim()) {
        drifts.push(`${item.out}: 正文与 ${item.src} 不一致`)
      } else {
        console.log(`${item.out}  ${countLines(onDisk)} lines  ${byteLength(onDisk)} bytes  ok`)
      }
      continue
    }

    mkdirSync(dirname(outPath), { recursive: true })
    writeFileSync(outPath, html)
    console.log(`${item.out}  ${countLines(html)} lines  ${byteLength(html)} bytes  written`)
  }

  // 2) 图片：逐条比 sha256，不一致才写
  for (const [srcRel, outRel] of ASSETS) {
    const srcPath = join(repoRoot, srcRel)
    const outPath = join(repoRoot, outRel)
    if (!existsSync(srcPath)) {
      drifts.push(`${outRel}: 源文件缺失 ${srcRel}`)
      continue
    }
    const srcHash = sha256OfFile(srcPath)
    const outHash = existsSync(outPath) ? sha256OfFile(outPath) : ''
    const same = srcHash === outHash
    const size = byteLength(readFileSync(srcPath, 'utf8'))
    const bytes = existsSync(srcPath) ? readFileSync(srcPath).length : size

    if (checkMode) {
      if (!same) {
        drifts.push(`${outRel}: 与 ${srcRel} 哈希不一致`)
      } else {
        console.log(`${outRel}  ${bytes} bytes  ok`)
      }
      continue
    }

    if (!same) {
      mkdirSync(dirname(outPath), { recursive: true })
      copyFileSync(srcPath, outPath)
      console.log(`${outRel}  ${bytes} bytes  copied`)
    } else {
      console.log(`${outRel}  ${bytes} bytes  ${existsSync(outPath) ? 'unchanged' : 'copied'}`)
    }
  }

  // 3) 结论
  if (checkMode) {
    if (drifts.length > 0) {
      console.error('site drift detected:')
      for (const drift of drifts) console.error(`  - ${drift}`)
      process.exit(1)
    }
    console.log('site is up to date')
    return
  }

  if (drifts.length > 0) {
    console.error('site build incomplete:')
    for (const drift of drifts) console.error(`  - ${drift}`)
    process.exit(1)
  }
  console.log('site build done')
}

main()
