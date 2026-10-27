#!/usr/bin/env node
// 规范注册表校验：把「规范文档的元数据」变成可机器检查的约束。
//
// 为什么需要它：docs/spec-registry.md 列出全部规范载体的层级与状态，但表格本身是手写的——
// 文件被删、路径被改、头部字段漏填、注册表标「现行」而文件自己标「部分失效」，这些漂移
// 都没人拦。本脚本把四类漂移变成红灯：
//   1. 注册表列出的文件必须存在
//   2. 标「check-specs（头部）」的文件，H1 之后必须有 6 行统一头部
//   3. 头部「最后核对」必须是可解析的过去日期（防写未来日期假装已核对）
//   4. 注册表「状态」列必须与文件头部「状态」一致
//
// 规则说明见 docs/process/engineering-standards.md；注册表格式约定见 docs/spec-registry.md。
// 运行：node tools/check-specs.mjs（cwd 任意，路径由本文件位置推导）

import { existsSync, readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const selfDir = dirname(fileURLToPath(import.meta.url))
// 本文件位于 apps/harmony/tools/：apps → harmony → tools，故仓库根要上溯三级
const repoRoot = resolve(selfDir, '..', '..', '..')
const appRoot = resolve(selfDir, '..')

const REGISTRY_PATH = resolve(repoRoot, 'docs/spec-registry.md')

/** 6 行统一头部必须出现的字段名，顺序即文档中的推荐顺序。 */
export const HEADER_FIELDS = ['层级', '最后核对', '上位文档', '状态', '路径基准', '适用端']

/** 允许的层级与状态取值——写错即视为格式错误，避免出现「L4」「半失效」这类自造值。 */
export const ALLOWED_LEVELS = ['L1', 'L2', 'L3']
export const ALLOWED_STATUS = ['现行', '部分失效', '已被取代']

function fail(message) {
  throw new Error(`[spec-registry] ${message}`)
}

/**
 * 解析注册表主表。
 * 只解析表头含「自动检查」的那张表——文件里另有「已删除的规范」（4 列）与
 * 「不属于规范的索引文档」（2 列）两张表，列数不同，靠表头判别不会误取。
 *
 * @param {string} text 注册表全文
 * @returns {Array<{level: string, path: string, scope: string, side: string, status: string, drift: string, check: string, line: number}>}
 */
export function parseRegistry(text) {
  const lines = text.split(/\r?\n/)
  const rows = []
  let headerIndex = -1
  let headerCols = []

  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i].trim()
    if (!line.startsWith('|')) continue
    const cells = splitRow(line)
    if (cells.includes('自动检查')) {
      headerIndex = i
      headerCols = cells
      break
    }
  }

  if (headerIndex === -1) {
    fail('注册表缺少「自动检查」列的主表；表头必须含 层级|路径|管辖|适用端|状态|会漂移|自动检查')
  }

  const expected = ['层级', '路径', '管辖', '适用端', '状态', '会漂移', '自动检查']
  if (headerCols.join('|') !== expected.join('|')) {
    fail(`主表列顺序被改动。期望 ${expected.join(' | ')}，实际 ${headerCols.join(' | ')}`)
  }

  for (let i = headerIndex + 1; i < lines.length; i += 1) {
    const raw = lines[i].trim()
    if (!raw.startsWith('|')) {
      // 表格结束：遇到空行或下一个标题都停（后续表格列数不同，不应混入）
      if (raw === '') break
      continue
    }
    const cells = splitRow(raw)
    if (cells.length !== expected.length) break
    if (cells.every((cell) => /^-+$/.test(cell.replace(/:/g, '')))) continue // 分隔行

    rows.push({
      level: cells[0],
      path: stripCode(cells[1]),
      scope: cells[2],
      side: cells[3],
      status: cells[4],
      drift: cells[5],
      check: cells[6],
      line: i + 1
    })
  }

  if (rows.length === 0) fail('主表解析出 0 行，检查表格是否被破坏')
  return rows
}

/**
 * 按 `|` 切分表格行并去首尾空白。
 * 处理 `\|` 转义——「管辖」列可能写 grep 模式，简单 split('|') 会切碎整行。
 */
function splitRow(line) {
  const cells = []
  let current = ''
  for (let i = 0; i < line.length; i += 1) {
    const char = line[i]
    if (char === '\\' && line[i + 1] === '|') {
      current += '|'
      i += 1
      continue
    }
    if (char === '|') {
      cells.push(current.trim())
      current = ''
      continue
    }
    current += char
  }
  cells.push(current.trim())
  if (cells.length > 0 && cells[0] === '') cells.shift()
  if (cells.length > 0 && cells[cells.length - 1] === '') cells.pop()
  return cells
}

/** 去掉 markdown 反引号包裹。 */
function stripCode(text) {
  return text.replace(/^`+|`+$/g, '').trim()
}

/**
 * 解析 H1 之后的统一头部。
 * 头部是连续的 `> **字段**：值` 引用块行；允许 H1 与头部之间有空行。
 *
 * @param {string} text 文档全文
 * @returns {{found: Record<string,string>, missing: string[], h1: string|null}}
 */
export function parseHeader(text) {
  const lines = text.split(/\r?\n/)
  const h1Index = lines.findIndex((line) => /^# \S/.test(line.trim()))
  const found = {}
  if (h1Index === -1) {
    return { found, missing: HEADER_FIELDS.slice(), h1: null }
  }
  const h1 = lines[h1Index].trim()

  // 从 H1 之后往下扫，遇到首个非空且非 `>` 的正文即停止（头部必须紧贴标题区）
  let scanned = 0
  for (let i = h1Index + 1; i < lines.length && scanned < 20; i += 1) {
    const line = lines[i].trim()
    scanned += 1
    if (line === '') continue
    if (!line.startsWith('>')) break
    for (const field of HEADER_FIELDS) {
      const match = line.match(new RegExp(`^>\\s*\\*\\*${field}\\*\\*\\s*[：:]\\s*(.*)$`))
      if (match !== null && found[field] === undefined) {
        found[field] = match[1].trim()
      }
    }
  }

  const missing = HEADER_FIELDS.filter((field) => found[field] === undefined || found[field] === '')
  return { found, missing, h1 }
}

/** 判断日期字符串是否为合法 ISO 日期且不晚于今天。 */
export function isPastDate(value, today = new Date()) {
  const match = String(value).match(/^(\d{4})-(\d{2})-(\d{2})/)
  if (match === null) return false
  const year = Number(match[1])
  const month = Number(match[2])
  const day = Number(match[3])
  const date = new Date(Date.UTC(year, month - 1, day))
  if (Number.isNaN(date.getTime())) return false
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) {
    return false
  }
  // 「最后核对」是人按本地日历写的，比较也必须用本地日期。
  // 用 UTC 会在本地跨日后的凌晨把当天的记录判成「未来」（实测：本地 2026-10-27 01:20、UTC 仍是 10-26）。
  const todayLocal = Date.UTC(today.getFullYear(), today.getMonth(), today.getDate())
  return date.getTime() <= todayLocal
}

/** 从头部「层级：L2 展开」里取出 L1/L2/L3 记号。 */
export function normalizeLevel(value) {
  const match = String(value).match(/\bL([123])\b/)
  return match === null ? null : `L${match[1]}`
}

/** 从头部「状态：现行（3 项待裁决）」里取出受控状态词。 */
export function normalizeStatus(value) {
  const text = String(value)
  if (text.includes('已被取代')) return '已被取代'
  if (text.includes('部分失效')) return '部分失效'
  if (text.includes('现行')) return '现行'
  return null
}

/**
 * 核心校验：注册表 ↔ 磁盘文件 ↔ 文件头部 三方一致。
 *
 * @param {ReturnType<typeof parseRegistry>} rows 注册表行
 * @param {(absPath: string) => string|null} readFile 读文件，缺失返回 null
 * @param {Date} [today] 注入「今天」便于测试
 * @param {string} [baseDir] 解析相对路径的基准目录，默认仓库根；单测注入临时目录以隔离
 * @returns {string[]} findings，空数组即通过
 */
export function checkRegistryConsistency(rows, readFile, today = new Date(), baseDir = repoRoot) {
  const findings = []

  for (const row of rows) {
    const absPath = resolve(baseDir, row.path)
    const level = normalizeLevel(row.level)
    if (level === null) {
      findings.push(`第 ${row.line} 行：层级「${row.level}」不是 L1/L2/L3`)
      continue
    }
    const status = normalizeStatus(row.status)
    if (status === null) {
      findings.push(`第 ${row.line} 行（${row.path}）：状态「${row.status}」不是 现行/部分失效/已被取代`)
      continue
    }

    const text = readFile(absPath)
    if (text === null) {
      findings.push(`第 ${row.line} 行：注册表列出的文件不存在 —— ${row.path}`)
      continue
    }

    if (!row.check.includes('头部')) continue // 「仅存在」类只校验存在性

    const { found, missing, h1 } = parseHeader(text)
    if (h1 === null) {
      findings.push(`${row.path}：缺少 H1 标题，无法定位头部区`)
      continue
    }
    if (missing.length > 0) {
      findings.push(`${row.path}：头部缺字段 —— ${missing.join(' / ')}（应有 ${HEADER_FIELDS.length} 项）`)
      continue
    }

    const headerLevel = normalizeLevel(found['层级'])
    if (headerLevel !== level) {
      findings.push(`${row.path}：层级不一致 —— 注册表 ${level}，头部 ${found['层级']}`)
    }

    const headerStatus = normalizeStatus(found['状态'])
    if (headerStatus !== status) {
      findings.push(`${row.path}：状态不一致 —— 注册表「${row.status}」，头部「${found['状态']}」`)
    }

    if (!isPastDate(found['最后核对'], today)) {
      findings.push(`${row.path}：最后核对「${found['最后核对']}」不是不晚于今天的 YYYY-MM-DD 日期`)
    }
  }

  return findings
}

function main() {
  if (!existsSync(REGISTRY_PATH)) {
    fail(`注册表不存在：${REGISTRY_PATH}`)
  }
  const rows = parseRegistry(readFileSync(REGISTRY_PATH, 'utf8'))
  const findings = checkRegistryConsistency(rows, (absPath) => {
    if (!existsSync(absPath)) return null
    return readFileSync(absPath, 'utf8')
  })

  if (findings.length > 0) {
    console.error(`[spec-registry] ${findings.length} 处不一致：`)
    for (const finding of findings) console.error(`  - ${finding}`)
    console.error('修法：文件不存在改注册表路径；缺头部补 6 行；状态不一致统一两处。')
    process.exit(1)
  }

  const withHeader = rows.filter((row) => row.check.includes('头部')).length
  console.log(`[spec-registry] ${rows.length} 条登记，${withHeader} 条校验头部，全部一致`)
}

// 仅在直接执行时跑校验；被 import（单测）时只暴露纯函数
const isDirectRun =
  process.argv[1] !== undefined &&
  resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url))

if (isDirectRun) {
  try {
    main()
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error))
    process.exit(1)
  }
}
