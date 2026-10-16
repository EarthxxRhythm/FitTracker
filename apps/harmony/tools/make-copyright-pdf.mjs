#!/usr/bin/env node
/**
 * 生成软件著作权登记用的 PDF 材料（源程序 / 说明书）。
 *
 * 输入：make-copyright-source.mjs 与 make-copyright-doc.mjs 产出的纯文本材料
 *       （每页首行为「软件名称 版本 ... 第 N 页 / 共 M 页」页眉，次行为分隔线）。
 * 输出：与 txt 同目录的 PDF，页面尺寸 A4，页眉页码与 txt 保持一致。
 *
 * 为什么不是「把 txt 直接另存为 PDF」：
 *   官方对鉴别材料的硬性要求是**每页行数**（源程序 ≥50 行/页，文档 ≥30 行/页）。
 *   txt 里的分页是逻辑分页，转 PDF 时若由渲染器自行分页，长行折行会挤出额外页面，
 *   导致「第 N 页」与实际物理页错位。因此这里显式按 txt 的页边界切 section，
 *   并**实测产出 PDF 的物理页数**，不符就逐档缩小字号重排，直到两者一致。
 *
 * 用法：
 *   node tools/make-copyright-pdf.mjs
 *   node tools/make-copyright-pdf.mjs --dir ../../test_run/copyright
 *   node tools/make-copyright-pdf.mjs --name 菲特健身训练软件 --version V1.0
 */

import { readFileSync, writeFileSync, mkdirSync, existsSync, statSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { spawnSync } from 'node:child_process'
import zlib from 'node:zlib'

const HERE = path.dirname(fileURLToPath(import.meta.url))
const REPO_ROOT = path.resolve(HERE, '..', '..', '..')
const DEFAULT_DIR = path.join(REPO_ROOT, 'test_run', 'copyright')

const CHROME_CANDIDATES = [
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe'
]

// 页眉形如：`菲特健身训练软件 V1.0                    第 1 页 / 共 60 页`
const HEADER_RE = /^(.*?)\s{2,}第\s*(\d+)\s*页\s*\/\s*共\s*(\d+)\s*页\s*$/
const RULE_RE = /^-{10,}$/

export function escapeHtml(text) {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}

/**
 * 把材料 txt 切成页数组。纯函数，便于测试。
 * @returns {{header:{left:string,page:number,total:number},body:string[]}[]}
 */
export function parseMaterialPages(text) {
  const lines = text.replace(/^\uFEFF/, '').replace(/\r\n?/g, '\n').split('\n')
  const pages = []
  let current = null

  const flush = () => {
    if (current === null) {
      return
    }
    // renderDocument 用 '\n\n' 连接各页，解析回来会在页尾多出**恰好一个**连接空行——
    // 只剥这一个。源码自身的尾部空行是真实行，多删会让该页不足 50 行。
    if (current.body.length > 0 && current.body[current.body.length - 1].trim() === '') {
      current.body.pop()
    }
    pages.push(current)
  }

  for (const line of lines) {
    const m = line.match(HEADER_RE)
    if (m !== null) {
      flush()
      current = {
        header: { left: m[1].trim(), page: Number(m[2]), total: Number(m[3]) },
        body: []
      }
      continue
    }
    if (current === null) {
      continue
    }
    if (RULE_RE.test(line.trim())) {
      continue
    }
    current.body.push(line)
  }
  flush()

  return pages
}

/** 统计 PDF 物理页数（解压对象流后数 /Type /Page）。 */
export function countPdfPages(pdfPath) {
  const buf = readFileSync(pdfPath)
  const raw = buf.toString('latin1')
  const parts = [raw]

  let idx = 0
  while (true) {
    const s = raw.indexOf('stream', idx)
    if (s < 0) {
      break
    }
    let p = s + 6
    if (raw[p] === '\r') p += 1
    if (raw[p] === '\n') p += 1
    const e = raw.indexOf('endstream', p)
    if (e < 0) {
      break
    }
    try {
      parts.push(zlib.inflateSync(buf.subarray(p, e)).toString('latin1'))
    } catch {
      parts.push(buf.subarray(p, e).toString('latin1'))
    }
    idx = e + 9
  }

  const all = parts.join('\n')
  // /Type /Page 但排除 /Type /Pages
  const matches = all.match(/\/Type\s*\/Page(?![s])/g)
  return matches === null ? 0 : matches.length
}

/** 检查字体是否真嵌入（未嵌入时中文在他人机器上会变方框）。 */
function fontReport(pdfPath) {
  const buf = readFileSync(pdfPath)
  const raw = buf.toString('latin1')
  const parts = [raw]

  let idx = 0
  while (true) {
    const s = raw.indexOf('stream', idx)
    if (s < 0) {
      break
    }
    let p = s + 6
    if (raw[p] === '\r') p += 1
    if (raw[p] === '\n') p += 1
    const e = raw.indexOf('endstream', p)
    if (e < 0) {
      break
    }
    try {
      parts.push(zlib.inflateSync(buf.subarray(p, e)).toString('latin1'))
    } catch {
      parts.push(buf.subarray(p, e).toString('latin1'))
    }
    idx = e + 9
  }

  const all = parts.join('\n')
  const names = [...all.matchAll(/\/(?:BaseFont|FontName)\s*\/([A-Za-z0-9+#\-,_]+)/g)]
    .map((m) => m[1])
    .filter((n) => n.length > 2)
  return {
    fonts: [...new Set(names)],
    embedded: /FontFile[23]?/.test(all)
  }
}

function findChrome() {
  for (const candidate of CHROME_CANDIDATES) {
    if (existsSync(candidate)) {
      return candidate
    }
  }
  return null
}

function buildHtml(pages, fontSize, kind) {
  const isSource = kind === 'source'
  const fontFamily = isSource
    ? 'Consolas, "Courier New", "Microsoft YaHei", monospace'
    : '"Microsoft YaHei", "SimSun", sans-serif'

  const sections = pages
    .map((page) => {
      const body = page.body.map(escapeHtml).join('\n')
      return [
        '<section class="page">',
        `<header class="hd"><span>${escapeHtml(page.header.left)}</span>` +
          `<span>第 ${page.header.page} 页 / 共 ${page.header.total} 页</span></header>`,
        `<pre class="body">${body}</pre>`,
        '</section>'
      ].join('\n')
    })
    .join('\n')

  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<title>copyright material</title>
<style>
  @page { size: A4; margin: 14mm 15mm; }
  html, body { margin: 0; padding: 0; }
  .page { page-break-after: always; break-after: page; }
  .page:last-child { page-break-after: auto; break-after: auto; }
  .hd {
    display: flex; justify-content: space-between;
    font-family: "Microsoft YaHei", sans-serif;
    font-size: 8pt; color: #333;
    border-bottom: 0.6pt solid #999;
    padding-bottom: 1.6mm; margin-bottom: 2.6mm;
    white-space: nowrap;
  }
  pre.body {
    margin: 0;
    font-family: ${fontFamily};
    font-size: ${fontSize}pt;
    line-height: 1.3;
    white-space: pre-wrap;
    word-break: break-all;
  }
</style>
</head>
<body>
${sections}
</body>
</html>
`
}

function printPdf(chrome, htmlPath, pdfPath) {
  const result = spawnSync(
    chrome,
    [
      '--headless=new',
      '--disable-gpu',
      '--no-sandbox',
      '--no-pdf-header-footer',
      `--print-to-pdf=${pdfPath}`,
      `file:///${htmlPath.replace(/\\/g, '/')}`
    ],
    { stdio: 'pipe', timeout: 180000, windowsHide: true }
  )
  return { status: result.status, stderr: result.stderr === null ? '' : result.stderr.toString('utf8') }
}

function convertOne(chrome, opts, spec) {
  const txtPath = path.join(opts.dir, spec.txt)
  if (!existsSync(txtPath)) {
    console.error(`[copyright-pdf] ✗ 缺少输入：${spec.txt}`)
    return false
  }

  const pages = parseMaterialPages(readFileSync(txtPath, 'utf8'))
  const expectPages = pages.length
  if (expectPages === 0) {
    console.error(`[copyright-pdf] ✗ 未能从 ${spec.txt} 解析出任何页`)
    return false
  }

  const bodyLineCounts = pages.map((page) => page.body.length)
  const minLines = Math.min(...bodyLineCounts)

  mkdirSync(opts.tmpDir, { recursive: true })
  const htmlPath = path.join(opts.tmpDir, `${spec.base}.html`)
  const pdfPath = path.join(opts.dir, spec.pdf)

  let fontSize = spec.startFontSize
  let attempts = 0
  let ok = false

  while (attempts < 8) {
    attempts += 1
    writeFileSync(htmlPath, buildHtml(pages, fontSize, spec.kind), 'utf8')
    const printed = printPdf(chrome, htmlPath, pdfPath)
    if (!existsSync(pdfPath)) {
      console.error(`[copyright-pdf] ✗ Chrome 未产出 PDF（status=${printed.status}）`)
      if (printed.stderr.length > 0) {
        console.error(printed.stderr.split('\n').slice(0, 4).join('\n'))
      }
      return false
    }
    const actual = countPdfPages(pdfPath)
    if (actual === expectPages) {
      ok = true
      break
    }
    console.log(
      `[copyright-pdf]   字号 ${fontSize}pt → ${actual} 页（应为 ${expectPages}），缩小重排`
    )
    fontSize = Number((fontSize - 0.5).toFixed(2))
    if (fontSize < 5) {
      break
    }
  }

  const font = fontReport(pdfPath)
  const sizeKb = Math.round(statSync(pdfPath).size / 1024)

  console.log(`[copyright-pdf] ${spec.pdf}`)
  console.log(
    `[copyright-pdf]   页数：${expectPages} 页` +
      `${ok ? ' ✓ 与 txt 分页一致' : ' ⚠ 与 PDF 物理页数不一致'}` +
      `（尝试 ${attempts} 次，最终字号 ${fontSize}pt）`
  )
  console.log(`[copyright-pdf]   每页正文行数：${minLines} ~ ${Math.max(...bodyLineCounts)}`)
  console.log(`[copyright-pdf]   大小：${sizeKb} KB`)
  console.log(
    `[copyright-pdf]   字体：${font.fonts.join(', ') || '(未识别)'}` +
      `${font.embedded ? ' · 已嵌入 ✓' : ' · ⚠ 未检出嵌入'}`,
  )
  return ok
}

function parseArgs(argv) {
  const opts = {
    name: '菲特健身训练软件',
    version: 'V1.0',
    dir: DEFAULT_DIR
  }
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i]
    const value = argv[i + 1]
    if (flag === '--name' && value !== undefined) {
      opts.name = value
      i += 1
    } else if (flag === '--version' && value !== undefined) {
      opts.version = value
      i += 1
    } else if (flag === '--dir' && value !== undefined) {
      opts.dir = path.resolve(process.cwd(), value)
      i += 1
    }
  }
  opts.tmpDir = path.join(opts.dir, '.tmp')
  return opts
}

function main() {
  const opts = parseArgs(process.argv.slice(2))
  const chrome = findChrome()
  if (chrome === null) {
    console.error('[copyright-pdf] ✗ 未找到 Chrome / Edge，无法打印 PDF')
    process.exitCode = 3
    return
  }
  console.log(`[copyright-pdf] 渲染器：${chrome}`)
  console.log(`[copyright-pdf] 输出目录：${opts.dir}`)

  const base = `${opts.name}${opts.version}`
  const specs = [
    {
      kind: 'source',
      base: `源程序（${base}）`,
      txt: `源程序（${base}）_合计60页.txt`,
      pdf: `源程序（${base}）.pdf`,
      // 从偏大字号起步，靠「PDF 物理页数必须等于 txt 逻辑页数」这一约束自动收敛到
      // 「既装得下全部行、又尽量大」的字号——页数超出就缩半磅重排。
      startFontSize: 11
    },
    {
      kind: 'manual',
      base: `说明书（${base}）`,
      txt: `说明书（${base}）.txt`,
      pdf: `说明书（${base}）.pdf`,
      startFontSize: 13
    }
  ]

  let allOk = true
  for (const spec of specs) {
    if (!convertOne(chrome, opts, spec)) {
      allOk = false
    }
  }

  console.log('[copyright-pdf] 中间产物（HTML）保留在：' + path.relative(REPO_ROOT, opts.tmpDir))
  if (!allOk) {
    process.exitCode = 2
  }
}

const invokedDirectly =
  process.argv[1] !== undefined && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)

if (invokedDirectly) {
  main()
}
