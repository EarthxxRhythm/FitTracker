import { readFileSync, writeFileSync, mkdirSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

/**
 * 生成软件著作权登记用的「文档鉴别材料」（用户说明书）。
 *
 * 规则出处（中国版权保护中心《计算机软件著作权登记申请表填写说明》「4. 软件鉴别材料 · 一般交存」）：
 *   - 提交文档连续的前 30 页和连续的后 30 页；整个文档不到 60 页的提交全部
 *   - 文档每页不少于 30 行
 *   - 鉴别材料页眉的软件版本号应与申请表填报一致
 *
 * 本说明书不足 60 页，按官方口径「不到 60 页的提交全部」整体提交，不做前后截取。
 *
 * 用法：
 *   node tools/make-copyright-doc.mjs
 *   node tools/make-copyright-doc.mjs --in ../../docs/release/software-copyright-manual.md --out ../../test_run/copyright
 */

const HERE = path.dirname(fileURLToPath(import.meta.url))
const REPO_ROOT = path.resolve(HERE, '..', '..', '..')

const DEFAULT_INPUT = path.join(REPO_ROOT, 'docs', 'release', 'software-copyright-manual.md')

const MIN_LINES_PER_PAGE = 30
const MAX_LINES_PER_PAGE = 40
const PAGE_WIDTH = 72

function parseArgs(argv) {
  const opts = {
    name: '菲特健身训练软件',
    version: 'V1.0',
    input: DEFAULT_INPUT,
    out: path.join(REPO_ROOT, 'test_run', 'copyright')
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
    } else if (flag === '--in' && value !== undefined) {
      opts.input = path.resolve(process.cwd(), value)
      i += 1
    } else if (flag === '--out' && value !== undefined) {
      opts.out = path.resolve(process.cwd(), value)
      i += 1
    }
  }
  return opts
}

/** Markdown → 纯文本：去掉标记符号，表格数据行转为空格分隔 */
function toPlainLines(markdown) {
  const out = []
  for (const raw of markdown.replace(/\r\n?/g, '\n').split('\n')) {
    let line = raw

    // 表格分隔行（| --- | --- |）整行丢弃
    if (/^\s*\|[\s\-:|]+\|\s*$/.test(line)) {
      continue
    }

    // 表格数据行 → 单元格用两个空格连接
    const tableMatch = line.match(/^\s*\|(.+)\|\s*$/)
    if (tableMatch !== null) {
      const cells = tableMatch[1].split('|').map((cell) => cell.trim())
      line = cells.join('  ')
    }

    // 标题：# 去掉，保留文本
    line = line.replace(/^#{1,6}\s+/, '')

    // 强调与行内代码
    line = line.replace(/\*\*(.+?)\*\*/g, '$1').replace(/`(.+?)`/g, '$1')

    // 列表项统一为普通缩进文本
    line = line.replace(/^\s*[-*]\s+/, '  · ')

    out.push(line.replace(/\s+$/, ''))
  }

  // 压掉连续 3 行以上的空行（保留至多 2 行，维持段落感）
  const compact = []
  let blanks = 0
  for (const line of out) {
    if (line.trim() === '') {
      blanks += 1
      if (blanks > 2) {
        continue
      }
    } else {
      blanks = 0
    }
    compact.push(line)
  }

  // 去掉首尾空行
  while (compact.length > 0 && compact[0].trim() === '') {
    compact.shift()
  }
  while (compact.length > 0 && compact[compact.length - 1].trim() === '') {
    compact.pop()
  }

  return compact
}

/** 按每页 30-40 行的区间均匀分页 */
function paginate(lines) {
  const total = lines.length
  const pageCount = Math.max(1, Math.ceil(total / MAX_LINES_PER_PAGE))
  const perPage = Math.ceil(total / pageCount)

  const pages = []
  for (let start = 0; start < total; start += perPage) {
    pages.push(lines.slice(start, start + perPage))
  }
  return { pages, perPage }
}

function padHeader(name, version, page, totalPages) {
  const left = `${name} ${version}`
  const right = `第 ${page} 页 / 共 ${totalPages} 页`
  const gap = Math.max(1, PAGE_WIDTH - left.length - right.length)
  return `${left}${' '.repeat(gap)}${right}`
}

function main() {
  const opts = parseArgs(process.argv.slice(2))

  const markdown = readFileSync(opts.input, 'utf8')
  const lines = toPlainLines(markdown)
  const { pages, perPage } = paginate(lines)

  mkdirSync(opts.out, { recursive: true })

  const text = pages
    .map((body, index) => {
      const header = padHeader(opts.name, opts.version, index + 1, pages.length)
      return [header, '-'.repeat(PAGE_WIDTH), ...body].join('\n')
    })
    .join('\n\n')

  const file = `说明书（${opts.name}${opts.version}）.txt`
  writeFileSync(path.join(opts.out, file), `${text}\n`, 'utf8')

  const minPageLines = Math.min(...pages.map((page) => page.length))

  console.log(`[copyright] 输入：${path.relative(REPO_ROOT, opts.input)}`)
  console.log(`[copyright] 正文 ${lines.length} 行 → ${pages.length} 页（每页 ${perPage} 行）`)
  console.log(
    `[copyright] 单页最少行数：${minPageLines}（官方下限 ${MIN_LINES_PER_PAGE}）` +
      `${minPageLines < MIN_LINES_PER_PAGE ? ' ⚠ 低于下限，建议补充内容' : ' ✓'}`
  )
  console.log(`[copyright] 输出：${path.join(opts.out, file)}`)

  if (pages.length >= 60) {
    console.log('[copyright] 注意：文档已达 60 页及以上，须按「前 30 页 + 后 30 页」截取后再提交。')
  } else {
    console.log('[copyright] 文档不足 60 页，按官方口径「不到 60 页的提交全部」整体提交。')
  }
}

main()
