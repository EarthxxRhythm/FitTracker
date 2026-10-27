#!/usr/bin/env node
// 双端对等校验：把「两端要同步」从口号变成可检查的约束。
//
// 为什么需要它：鸿蒙 19 个注册页、安卓 20 个 Screen 目录，跑同一套业务，但 apps/android/
// 下此前零份 .md——「一端做了、另一端没做」类缺陷单看一端看不出来。本脚本校验四件事：
//   1. main_pages.json 的每个注册页，必须出现在 dual-platform-parity.md 的对等清单里
//   2. 安卓 screens/ 下每个目录，必须在清单里有对应行，或在豁免表里
//   3. 安卓 applicationId 必须等于鸿蒙 bundleName（上架身份统一）
//   4. 豁免表每条都要写「理由」与「复核方式」——空白豁免等于没写
//
// 规则说明见 docs/process/dual-platform-parity.md。
// 运行：node tools/check-parity.mjs（cwd 任意，路径由本文件位置推导）

import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const selfDir = dirname(fileURLToPath(import.meta.url))
const appRoot = resolve(selfDir, '..')
const repoRoot = resolve(selfDir, '..', '..', '..')

const PARITY_DOC = resolve(repoRoot, 'docs/process/dual-platform-parity.md')
const MAIN_PAGES = resolve(appRoot, 'entry/src/main/resources/base/profile/main_pages.json')
const ANDROID_SCREENS = resolve(repoRoot, 'apps/android/app/src/main/java/com/fittracker/app/ui/screens')
const ANDROID_GRADLE = resolve(repoRoot, 'apps/android/app/build.gradle.kts')
const HARMONY_APP = resolve(appRoot, 'AppScope/app.json5')

function fail(message) {
  throw new Error(`[dual-platform] ${message}`)
}

/**
 * 按 `|` 切分表格行并去首尾空白。
 * 必须处理 `\|` 转义——markdown 表格里写 grep 模式（如 `grep 'a\|b'`）是合法写法，
 * 简单 split('|') 会把整行切碎，导致该行被列数判据静默丢弃（实测漏掉过一条豁免）。
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

/** 去掉反引号与两端空白。 */
function clean(text) {
  return text.replace(/^`+|`+$/g, '').trim()
}

/**
 * 取行内第一个反引号包裹的片段；无则返回原文。
 * 表格里的路径常带中文括注（如 `app\PencilAppShell`（应用壳，非内容页）），
 * 单纯去首尾反引号取不到值。
 */
function extractCode(text) {
  const match = String(text).match(/`([^`]+)`/)
  return match === null ? String(text).trim() : match[1].trim()
}

/** 把 `features\pencil\pages\PencilHomePage` 归一成 `features/pencil/pages/PencilHomePage`。 */
function normalizePath(text) {
  return extractCode(text).replace(/\\/g, '/').replace(/\.ets$/, '')
}

/**
 * 解析对等清单与豁免表。
 *
 * 文档里共有三张表，靠表头关键词区分：
 *   - 对等清单：表头含「鸿蒙页」（4 列：序号 / 鸿蒙页 / 安卓屏 / 对等）
 *   - 已知不对称（豁免）：表头含「复核方式」（5 列：序号 / 项 / 不对称内容 / 理由 / 复核方式）
 *   - 待裁决项：表头含「问题」（跳过，不是约束）
 *
 * @param {string} text
 * @returns {{parity: Array<{harmony: string, android: string, line: number}>, exemptions: Array<{item: string, reason: string, verify: string, line: number}>}}
 */
export function parseParityDoc(text) {
  const lines = text.split(/\r?\n/)
  const parity = []
  const exemptions = []
  let mode = null

  for (let i = 0; i < lines.length; i += 1) {
    const raw = lines[i].trim()
    if (!raw.startsWith('|')) {
      if (raw === '' || raw.startsWith('#')) mode = null
      continue
    }
    const cells = splitRow(raw)

    if (cells.includes('鸿蒙页')) {
      mode = 'parity'
      continue
    }
    if (cells.includes('复核方式')) {
      mode = 'exempt'
      continue
    }
    if (cells.includes('问题')) {
      mode = 'pending'
      continue
    }
    if (cells.every((cell) => /^[-:]+$/.test(cell))) continue // 分隔行

    if (mode === 'parity' && cells.length === 4) {
      parity.push({
        harmony: normalizePath(cells[1]),
        android: extractCode(cells[2]),
        line: i + 1
      })
    } else if (mode === 'exempt' && cells.length === 5) {
      exemptions.push({
        item: clean(cells[1]),
        content: clean(cells[2]),
        reason: clean(cells[3]),
        verify: clean(cells[4]),
        line: i + 1
      })
    }
  }

  if (parity.length === 0) fail('对等清单解析出 0 行；表头必须含「鸿蒙页」且 4 列')
  if (exemptions.length === 0) fail('豁免表解析出 0 行；表头必须含「复核方式」且 5 列')
  return { parity, exemptions }
}

/** 从安卓 gradle 读 applicationId。 */
export function parseApplicationId(gradleText) {
  const match = gradleText.match(/applicationId\s*=\s*"([^"]+)"/)
  return match === null ? null : match[1]
}

/** 从鸿蒙 app.json5 读 bundleName。 */
export function parseBundleName(appJson5Text) {
  const match = appJson5Text.match(/"bundleName"\s*:\s*"([^"]+)"/)
  return match === null ? null : match[1]
}

/**
 * 核心校验。
 *
 * @param {{parity: Array, exemptions: Array}} parsed 解析结果
 * @param {{pages: string[], screenDirs: string[], applicationId: string|null, bundleName: string|null}} facts 磁盘事实
 * @returns {string[]} findings
 */
export function checkParity(parsed, facts) {
  const findings = []
  const harmonyListed = new Set(parsed.parity.map((row) => row.harmony))

  // 1. 每个注册页都要在清单里（豁免行用 `—` 开头表示「无对应」，不算覆盖）
  for (const page of facts.pages) {
    const normalized = normalizePath(page)
    if (!harmonyListed.has(normalized)) {
      findings.push(`鸿蒙注册页未登记对等关系：${normalized}（加到 dual-platform-parity.md 的对等清单，或说明为单端独有）`)
    }
  }

  // 2. 每个安卓屏目录都要在清单里出现，或在豁免表里
  const androidDirs = new Set()
  for (const row of parsed.parity) {
    const dir = row.android.split(/[\\/]/)[0].trim()
    if (dir !== '' && dir !== '—' && dir !== '**（无对应）**') androidDirs.add(dir)
  }
  const exemptText = parsed.exemptions.map((row) => `${row.item} ${row.reason}`).join(' ')

  for (const dir of facts.screenDirs) {
    if (androidDirs.has(dir)) continue
    if (exemptText.includes(dir)) continue
    findings.push(`安卓屏目录未登记：${dir}（加到对等清单，或在已知不对称表里给理由）`)
  }

  // 3. 上架身份必须双端一致
  if (facts.applicationId === null) {
    findings.push('无法从 apps/android/app/build.gradle.kts 读到 applicationId')
  } else if (facts.bundleName === null) {
    findings.push('无法从 apps/harmony/AppScope/app.json5 读到 bundleName')
  } else if (facts.applicationId !== facts.bundleName) {
    findings.push(`上架身份不一致：安卓 applicationId「${facts.applicationId}」≠ 鸿蒙 bundleName「${facts.bundleName}」`)
  }

  // 4. 豁免必须写清理由与复核方式
  for (const row of parsed.exemptions) {
    if (row.reason === '' || row.reason === '—') {
      findings.push(`第 ${row.line} 行豁免「${row.item}」缺理由（空白豁免等于没写）`)
    }
    if (row.verify === '' || row.verify === '—') {
      findings.push(`第 ${row.line} 行豁免「${row.item}」缺复核方式`)
    }
  }

  return findings
}

function readOrNull(absPath) {
  return existsSync(absPath) ? readFileSync(absPath, 'utf8') : null
}

function main() {
  if (!existsSync(PARITY_DOC)) fail(`对等文档不存在：${PARITY_DOC}`)

  const parsed = parseParityDoc(readFileSync(PARITY_DOC, 'utf8'))

  const mainPagesText = readOrNull(MAIN_PAGES)
  if (mainPagesText === null) fail(`页面注册表不存在：${MAIN_PAGES}`)
  const profile = JSON.parse(mainPagesText)
  if (!Array.isArray(profile.src)) fail('main_pages.json 的 src 必须是数组')

  if (!existsSync(ANDROID_SCREENS)) fail(`安卓 screens 目录不存在：${ANDROID_SCREENS}`)
  const screenDirs = readdirSync(ANDROID_SCREENS).filter((name) =>
    statSync(resolve(ANDROID_SCREENS, name)).isDirectory()
  )

  const gradleText = readOrNull(ANDROID_GRADLE)
  const appText = readOrNull(HARMONY_APP)

  const findings = checkParity(parsed, {
    pages: profile.src,
    screenDirs,
    applicationId: gradleText === null ? null : parseApplicationId(gradleText),
    bundleName: appText === null ? null : parseBundleName(appText)
  })

  if (findings.length > 0) {
    console.error(`[dual-platform] ${findings.length} 处不一致：`)
    for (const finding of findings) console.error(`  - ${finding}`)
    process.exit(1)
  }

  console.log(
    `[dual-platform] ${parsed.parity.length} 条对等关系、${parsed.exemptions.length} 条豁免、` +
      `${screenDirs.length} 个安卓屏目录、身份 ${profile.src.length}/${screenDirs.length} 双向覆盖一致`
  )
}

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
