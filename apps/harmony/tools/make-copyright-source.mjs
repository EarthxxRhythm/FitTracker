import { readdirSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

/**
 * 生成软件著作权登记用的「源程序鉴别材料」。
 *
 * 规则出处（中国版权保护中心《计算机软件著作权登记申请表填写说明》「4. 软件鉴别材料 · 一般交存」）：
 *   - 提交源程序连续的前 30 页和连续的后 30 页；整个程序不到 60 页的提交全部
 *   - 程序每页不少于 50 行
 *   - 鉴别材料页眉的软件版本号应与申请表填报一致（本项目统一 V1.0）
 *
 * 用法：
 *   node tools/make-copyright-source.mjs
 *   node tools/make-copyright-source.mjs --name 菲特健身训练软件 --version V1.0 --out ../../test_run/copyright
 *   node tools/make-copyright-source.mjs --strip-blank     # 去掉纯空行（每页 50 行全是实码）
 *
 * 产出默认落 test_run/copyright/（该目录被 gitignore，材料不入库）。
 */

const HERE = path.dirname(fileURLToPath(import.meta.url))
const HARMONY_ROOT = path.resolve(HERE, '..')
const DEFAULT_ETS_ROOT = path.join(HARMONY_ROOT, 'entry', 'src', 'main', 'ets')

const LINES_PER_PAGE = 50
const PAGES_PER_SIDE = 30
const SIDE_LINES = LINES_PER_PAGE * PAGES_PER_SIDE
const PAGE_WIDTH = 72

// 敏感内容哨兵：命中说明材料会把密钥/口令一起交出去，必须先处理
const SENSITIVE_PATTERNS = [
  { re: /\bsk-[A-Za-z0-9_-]{16,}/, label: 'OpenAI 风格 API key' },
  { re: /\bAKIA[0-9A-Z]{16}\b/, label: 'AWS Access Key ID' },
  { re: /-----BEGIN [A-Z ]*PRIVATE KEY-----/, label: 'PEM 私钥' },
  { re: /\bghp_[A-Za-z0-9]{20,}\b/, label: 'GitHub token' },
  {
    re: /(password|passwd|secret|token|apikey|api_key)\s*[:=]\s*['"][^'"]{8,}['"]/i,
    label: '疑似硬编码口令/令牌'
  }
]

function parseArgs(argv) {
  const opts = {
    name: '菲特健身训练软件',
    version: 'V1.0',
    stripBlank: false,
    out: path.resolve(HARMONY_ROOT, '..', '..', 'test_run', 'copyright')
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
    } else if (flag === '--out' && value !== undefined) {
      opts.out = path.resolve(process.cwd(), value)
      i += 1
    } else if (flag === '--strip-blank') {
      opts.stripBlank = true
    }
  }
  return opts
}

function collectEtsFiles(dir) {
  const out = []
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name)
    if (entry.isDirectory()) {
      out.push(...collectEtsFiles(full))
    } else if (entry.isFile() && entry.name.endsWith('.ets')) {
      out.push(full)
    }
  }
  return out
}

function padHeader(name, version, page, totalPages) {
  const left = `${name} ${version}`
  const right = `第 ${page} 页 / 共 ${totalPages} 页`
  const gap = Math.max(1, PAGE_WIDTH - left.length - right.length)
  return `${left}${' '.repeat(gap)}${right}`
}

function renderPages(lines, startPage, totalPages, opts) {
  const pages = []
  for (let p = 0; p < PAGES_PER_SIDE; p += 1) {
    const slice = lines.slice(p * LINES_PER_PAGE, (p + 1) * LINES_PER_PAGE)
    if (slice.length === 0) {
      break
    }
    pages.push({
      header: padHeader(opts.name, opts.version, startPage + p, totalPages),
      body: slice
    })
  }
  return pages
}

function renderDocument(pages) {
  return pages
    .map((page) => [page.header, '-'.repeat(PAGE_WIDTH), ...page.body].join('\n'))
    .join('\n\n')
}

function main() {
  const opts = parseArgs(process.argv.slice(2))
  const etsRoot = DEFAULT_ETS_ROOT

  const files = collectEtsFiles(etsRoot).sort()

  // 读入全部源码行（统一 LF）；--strip-blank 时剔除纯空行
  const allLines = []
  for (const file of files) {
    const text = readFileSync(file, 'utf8').replace(/^\uFEFF/, '').replace(/\r\n?/g, '\n')
    const lines = text.split('\n')
    if (lines.length > 0 && lines[lines.length - 1] === '') {
      lines.pop()
    }
    for (const line of lines) {
      if (opts.stripBlank && line.trim() === '') {
        continue
      }
      allLines.push(line)
    }
  }

  const totalLines = allLines.length
  const useAll = totalLines <= SIDE_LINES * 2

  const head = useAll ? allLines : allLines.slice(0, SIDE_LINES)
  const tail = useAll ? [] : allLines.slice(-SIDE_LINES)

  const totalPages = useAll ? Math.ceil(totalLines / LINES_PER_PAGE) : PAGES_PER_SIDE * 2
  const headPages = renderPages(head, 1, totalPages, opts)
  const tailPages = useAll ? [] : renderPages(tail, PAGES_PER_SIDE + 1, totalPages, opts)

  // 敏感内容检查（在最终取用的行上做，避免误报未提交的部分）
  const hits = []
  const usedLines = tailPages.length > 0 ? [...head, ...tail] : head
  usedLines.forEach((line, index) => {
    for (const { re, label } of SENSITIVE_PATTERNS) {
      if (re.test(line)) {
        hits.push({ line: index + 1, label, sample: line.trim().slice(0, 80) })
      }
    }
  })

  mkdirSync(opts.out, { recursive: true })

  const headText = renderDocument(headPages)
  const tailText = renderDocument(tailPages)
  const combinedText = tailPages.length > 0 ? `${headText}\n\n${tailText}` : headText

  const base = `源程序（${opts.name}${opts.version}）`
  const outputs = [
    { file: `${base}_前30页.txt`, text: headText },
    { file: `${base}_后30页.txt`, text: tailText },
    { file: `${base}_合计60页.txt`, text: combinedText }
  ].filter((entry) => entry.text.trim() !== '')

  for (const { file, text } of outputs) {
    writeFileSync(path.join(opts.out, file), `${text}\n`, 'utf8')
  }

  console.log(`[copyright] 源文件：${files.length} 个 .ets，合计 ${totalLines} 行`)
  console.log(
    `[copyright] 取法：${useAll ? '全部（不足 60 页）' : `前 ${SIDE_LINES} 行 + 后 ${SIDE_LINES} 行`}` +
      `${opts.stripBlank ? '（已剔除纯空行）' : ''}`
  )
  console.log(
    `[copyright] 页数：前 ${headPages.length} 页${tailPages.length > 0 ? ` + 后 ${tailPages.length} 页` : ''}，每页 ${LINES_PER_PAGE} 行`
  )
  console.log(`[copyright] 输出目录：${opts.out}`)
  for (const { file } of outputs) {
    console.log(`[copyright]   - ${file}`)
  }

  if (hits.length > 0) {
    console.error('[copyright] ⚠ 在取用的行中检测到疑似敏感内容，提交前必须处理：')
    for (const hit of hits.slice(0, 20)) {
      console.error(`[copyright]   L${hit.line} [${hit.label}] ${hit.sample}`)
    }
    if (hits.length > 20) {
      console.error(`[copyright]   ...另有 ${hits.length - 20} 条`)
    }
    process.exitCode = 2
  } else {
    console.log('[copyright] 敏感内容检查：未发现疑似密钥/口令字面量')
  }
}

main()
