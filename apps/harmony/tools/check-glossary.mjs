#!/usr/bin/env node
// 口径闸门：把 docs/glossary.md 的口径规则变成可机器检查的约束。
//
// 为什么需要它：同一件事在仓库里有多种说法时，读者无法判断哪个是真的——而错的那种通常
// 看起来更「官方」。2026-10-28 实测到的分裂：两端 Tab 文案都是「回顾」但代码注释与文档里
// 写「复盘」；AGENTS.md 已改定为自托管 Supabase 但 contracts 仍写「AGC 云后端」；
// dual-platform-parity.md 把鸿蒙凭据文件写成 agconnect-services.json。这些都不是某一行
// 写错，而是「口径」在漂移，没有闸门就会继续漂。
//
// 四条规则（rule id 与 docs/glossary.md §5 同名章节互指）：
//   GL-01  术语唯一：现行范围内出现「复盘」→ 应写「回顾」
//   GL-02  云后端事实：现行范围内同一行既有「AGC」又有云后端词（云数据库/云后端/云服务/认证服务）
//   GL-03  凭据文件名：现行范围内出现 agconnect-services.json（现行凭据是 supabase.json）
//   GL-04  登记：docs/glossary.md 必须登记在 docs/spec-registry.md 且状态为「现行」
//
// 范围模型（决定规则会不会误杀，改这里前先读 docs/glossary.md §3）：
//   现行 = 注册表中状态为「现行」的 .md ∪ {AGENTS.md, README.md, CONTRIBUTING.md, contracts/**/*.md}
//          ∪ 代码集 apps/harmony/entry/src/{main,test,ohosTest}/**/*.ets 与 apps/android/app/src/**/*.{kt,kts}
//   历史 = docs/archive/**、docs/CHANGELOG.md、docs/closeout/**、docs/superpowers/specs/**，
//          以及 node_modules/**、oh_modules/**、build/**、.git/**、.rivet/**、test_run/** —— 永不检查
//   豁免措辞 = 同一行含 已移除 / 已被取代 / 历史 / 不再启用 / 作废 → 该行放行
//           （没有这条，「解释历史」的句子会被全部误判成违规）
//   平台限定 = 同一行含 控制台 / 云调试 / 提审 / 签名 / AppGallery Connect 且不含云后端词时，
//          该行是在描述发布流程而不是后端事实（「AGC 控制台」合法，「AGC 云数据库」非法）
//
// 代码文件按**整行**扫描（不只是注释行）：GL-01 管的是「术语唯一」，用户可见文案
// （如 Tab 标签、徽章）与注释同等重要，只看注释会把「首次复盘」这类界面文案漏掉。
// 豁免措辞同样按整行判断，所以「代码 + 行尾注释」的写法一样能豁免。
//
// 规则说明见 docs/glossary.md §5，分层口径见 §3。
// 运行：node tools/check-glossary.mjs（cwd 任意，路径由本文件位置推导）

import { existsSync, readFileSync, readdirSync } from 'node:fs'
import { dirname, relative, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

import { normalizeStatus, parseRegistry } from './check-specs.mjs'

const selfDir = dirname(fileURLToPath(import.meta.url))
// 本文件位于 apps/harmony/tools/：apps → harmony → tools，故仓库根要上溯三级
const repoRoot = resolve(selfDir, '..', '..', '..')

export const REGISTRY_REL = 'docs/spec-registry.md'
export const GLOSSARY_REL = 'docs/glossary.md'

/** 标准词与禁用同义词（docs/glossary.md §2 第一行）。 */
export const STANDARD_WORD = '回顾'
export const BANNED_SYNONYM = '复盘'

/** 云后端词：和「AGC」同行出现即把 AGC 说成了后端（docs/glossary.md §1「云后端」行）。 */
export const BACKEND_WORDS = ['云数据库', '云后端', '云服务', '认证服务']

/** 平台限定词：描述发布/云调试/签名流程时，AGC 指的是平台而非后端。 */
export const PLATFORM_WORDS = ['控制台', '云调试', '提审', '签名', 'AppGallery Connect']

/** 失效措辞：写清「这段是历史」的句子放行（docs/glossary.md §3 最后一行）。 */
export const EXEMPT_WORDING = ['已移除', '已被取代', '历史', '不再启用', '作废']

/** 已失效的鸿蒙云端凭据文件名；现行是 rawfile/supabase.json。 */
export const LEGACY_CREDENTIAL = 'agconnect-services.json'
export const CURRENT_CREDENTIAL = 'supabase.json'

/** 固定纳入现行范围的根级文档（不依赖注册表登记）。 */
export const FIXED_DOCS = ['AGENTS.md', 'README.md', 'CONTRIBUTING.md']

/** 历史层与构建产物：路径前缀或任意层级目录名命中即跳过。 */
export const EXCLUDED_PREFIXES = [
  'docs/archive/',
  'docs/closeout/',
  'docs/superpowers/specs/',
  'node_modules/',
  'oh_modules/',
  'build/',
  '.git/',
  '.rivet/',
  'test_run/'
]

/** 单独排除的历史文件（层级不同但同属历史材料）。 */
export const EXCLUDED_FILES = ['docs/CHANGELOG.md']

/**
 * 规则定义处：这些文件**必须**指名禁用词才能把规则写清楚（「禁用同义词：复盘」）。
 * 豁免的是「用词」，不是「登记」——GL-04 仍然校验本表是否登记为现行。
 */
export const RULE_DEFINITION_FILES = [
  'docs/glossary.md',
  'apps/harmony/tools/check-glossary.mjs',
  'apps/harmony/tools/check-glossary.test.mjs'
]

/** 代码集：目录根 + 受检扩展名。 */
export const CODE_ROOTS = [
  { dir: 'apps/harmony/entry/src/main', exts: ['.ets'] },
  { dir: 'apps/harmony/entry/src/test', exts: ['.ets'] },
  { dir: 'apps/harmony/entry/src/ohosTest', exts: ['.ets'] },
  { dir: 'apps/android/app/src', exts: ['.kt', '.kts'] }
]

/** 反斜杠归一为斜杠并去掉前导 `./`，让注册表写 \ 或 / 都能比对。 */
export function normalizeRelPath(value) {
  return String(value).replace(/\\/g, '/').replace(/^\.\//, '').trim()
}

/**
 * 该路径是否属于永不检查的历史层/构建产物。
 * 前缀表覆盖 docs/archive/** 一类；任意层级目录名覆盖 entry/build/**、oh_modules/**。
 */
export function isExcluded(relPath) {
  const path = normalizeRelPath(relPath)
  if (path === '') return false
  if (EXCLUDED_FILES.includes(path)) return true
  if (EXCLUDED_PREFIXES.some((prefix) => path.startsWith(prefix))) return true
  // 任意层级的目录名（build/、node_modules/…）——注意必须带尾斜杠，避免误伤 build-content.mjs 这类文件名
  return EXCLUDED_PREFIXES.some((prefix) => path.includes(`/${prefix}`))
}

/** 同一行是否带失效措辞（历史材料的合法写法的唯一标志）。 */
export function hasExemptWording(line) {
  return EXEMPT_WORDING.some((word) => line.includes(word))
}

/** 同一行是否把 AGC 说成云后端。 */
export function hasBackendWord(line) {
  return BACKEND_WORDS.some((word) => line.includes(word))
}

/** 同一行是否只在描述平台（控制台/云调试/提审/签名/AppGallery Connect）。 */
export function isPlatformLimited(line) {
  const platform = PLATFORM_WORDS.some((word) => line.includes(word))
  return platform && !hasBackendWord(line)
}

/**
 * 逐行判据。所有规则共用一个入口，保证「豁免措辞优先于一切规则」只有一处实现。
 *
 * @param {string} relPath 仓库相对路径（用于报错定位，斜杠分隔）
 * @param {string} text 文件全文
 * @returns {Array<{rule: string, file: string, line: number|null, message: string}>}
 */
export function scanText(relPath, text) {
  const findings = []
  const lines = String(text).split(/\r?\n/)

  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i]
    if (line.trim() === '') continue
    if (hasExemptWording(line)) continue // 历史解释句：三条规则统一放行

    // GL-01 术语唯一
    if (line.includes(BANNED_SYNONYM)) {
      findings.push({
        rule: 'GL-01',
        file: relPath,
        line: i + 1,
        message: `「${BANNED_SYNONYM}」应改为「${STANDARD_WORD}」`
      })
    }

    // GL-02 云后端事实：AGC 可以指平台，但不能指后端
    if (line.includes('AGC') && hasBackendWord(line) && !isPlatformLimited(line)) {
      findings.push({
        rule: 'GL-02',
        file: relPath,
        line: i + 1,
        message: '「AGC」不得作云后端（2026-10-28 起为自托管 Supabase）；平台语境请写「AGC 控制台/云调试/提审」'
      })
    }

    // GL-03 凭据文件名
    if (line.includes(LEGACY_CREDENTIAL)) {
      findings.push({
        rule: 'GL-03',
        file: relPath,
        line: i + 1,
        message: `现行鸿蒙云端凭据是 ${CURRENT_CREDENTIAL}；${LEGACY_CREDENTIAL} 是已移除的 AGC 残留`
      })
    }
  }

  return findings
}

/**
 * GL-04：本表必须登记在注册表且状态为「现行」。
 * 缺行、写成「部分失效」「已被取代」都算漂移——口径单一真源失效就没人能判定别的规则该不该执行。
 *
 * @param {string} registryText docs/spec-registry.md 全文
 * @returns {Array<{rule: string, file: string, line: number|null, message: string}>}
 */
export function checkRegistration(registryText) {
  // parseRegistry 会在主表缺失/列顺序被改动时抛出——那是 check-specs 的职责，这里照实上抛。
  const rows = parseRegistry(registryText)
  const own = rows.filter((row) => normalizeRelPath(row.path) === GLOSSARY_REL)

  if (own.length === 0) {
    return [{
      rule: 'GL-04',
      file: REGISTRY_REL,
      line: null,
      message: `${GLOSSARY_REL} 未登记（口径单一真源必须进注册表）`
    }]
  }

  const findings = []
  for (const row of own) {
    if (normalizeStatus(row.status) === '现行') continue
    findings.push({
      rule: 'GL-04',
      file: REGISTRY_REL,
      line: row.line,
      message: `${GLOSSARY_REL} 状态是「${row.status}」，应为「现行」`
    })
  }
  return findings
}

/** 递归收集受检文件，返回相对 baseRoot 的路径（斜杠分隔）。 */
function walkCode(rootDir, exts, out, baseRoot) {
  let entries
  try {
    entries = readdirSync(rootDir, { withFileTypes: true })
  } catch {
    return // 目录不存在（如没有 ohosTest）不是错误：代码集是该目录下的所有文件，空集合法
  }
  for (const entry of entries) {
    const abs = resolve(rootDir, entry.name)
    const rel = normalizeRelPath(relative(baseRoot, abs))
    if (isExcluded(rel)) continue
    if (entry.isDirectory()) {
      walkCode(abs, exts, out, baseRoot)
      continue
    }
    if (entry.isFile() && exts.some((ext) => entry.name.endsWith(ext))) out.push(rel)
  }
}

/**
 * 组装现行范围。
 *
 * @param {string} registryText 注册表全文
 * @param {string} [baseRoot] 仓库根，默认本文件推导出的根；单测注入临时目录以隔离
 * @returns {string[]} 去重排序后的相对路径
 */
export function collectCurrentScope(registryText, baseRoot = repoRoot) {
  const scope = new Set()

  // a) 注册表中状态为「现行」的 .md —— 用 check-specs 已验证的解析器，不另写一套
  for (const row of parseRegistry(registryText)) {
    if (normalizeStatus(row.status) !== '现行') continue
    const path = normalizeRelPath(row.path)
    if (path.endsWith('.md')) scope.add(path)
  }

  // b) 固定集：根级约束与 contracts
  for (const doc of FIXED_DOCS) scope.add(doc)

  // c) 代码集
  const codeFiles = []
  for (const root of CODE_ROOTS) {
    walkCode(resolve(baseRoot, root.dir), root.exts, codeFiles, baseRoot)
  }
  for (const file of codeFiles) scope.add(file)

  const contracts = []
  walkCode(resolve(baseRoot, 'contracts'), ['.md'], contracts, baseRoot)
  for (const file of contracts) scope.add(file)

  return [...scope].filter((path) => !isExcluded(path)).sort()
}

/** 把 findings 排成稳定顺序：文件 → 行 → 规则。 */
export function sortFindings(findings) {
  return findings.slice().sort((a, b) => {
    if (a.file !== b.file) return a.file < b.file ? -1 : 1
    const lineA = a.line === null ? 0 : a.line
    const lineB = b.line === null ? 0 : b.line
    if (lineA !== lineB) return lineA - lineB
    return a.rule < b.rule ? -1 : a.rule > b.rule ? 1 : 0
  })
}

/** 单条 finding 的一行文本，格式与既有脚本一致（[GL-xx] 可直接被 IDE 点击定位）。 */
export function formatFinding(finding) {
  const where = finding.line === null ? finding.file : `${finding.file}:${finding.line}`
  return `${finding.rule} ${where}  ${finding.message}`
}

/**
 * 扫描给定文件集合。readFile 注入便于单测在临时目录上跑，不碰真实仓库。
 *
 * @param {string[]} files 仓库相对路径
 * @param {(relPath: string) => string|null} readFile 读文件，缺失返回 null
 * @returns {Array} findings
 */
export function checkFiles(files, readFile) {
  const findings = []
  for (const file of files) {
    if (isExcluded(file)) continue
    if (RULE_DEFINITION_FILES.includes(normalizeRelPath(file))) continue // 定义处：必须指名禁用词
    const text = readFile(file)
    if (text === null) continue // 注册表登记了但文件不存在由 check-specs 报，这里不重复
    findings.push(...scanText(file, text))
  }
  return sortFindings(findings)
}

function readRepoFile(relPath) {
  const abs = resolve(repoRoot, relPath)
  return existsSync(abs) ? readFileSync(abs, 'utf8') : null
}

function main() {
  const registryText = readRepoFile(REGISTRY_REL)
  if (registryText === null) {
    throw new Error(`[glossary] 注册表不存在：${resolve(repoRoot, REGISTRY_REL)}`)
  }

  // 只统计真实存在的文件：固定集里的 CONTRIBUTING.md 若被删，统计不能假装它被扫过
  const scope = collectCurrentScope(registryText).filter((file) => existsSync(resolve(repoRoot, file)))
  const codeCount = scope.filter((file) => !file.endsWith('.md')).length
  const docCount = scope.length - codeCount

  const findings = sortFindings([
    ...checkRegistration(registryText),
    ...checkFiles(scope, readRepoFile)
  ])

  if (findings.length > 0) {
    console.error(`[glossary] ${findings.length} 处口径不一致：`)
    for (const finding of findings) console.error(`  - ${formatFinding(finding)}`)
    console.error(
      '修法：现行层改真文；历史材料在同行补「已被取代/已移除/历史/不再启用/作废」之一；见 docs/glossary.md §3。'
    )
    process.exit(1)
  }

  console.log(
    `[glossary] 现行范围 ${scope.length} 个文件，GL-01..GL-04 全部通过` +
      `（文档 ${docCount} + 源码 ${codeCount}）`
  )
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
