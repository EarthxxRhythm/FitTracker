#!/usr/bin/env node
// 代码规则门禁：把 AGENTS.md 的硬约束变成可执行的检查。
//
// rule id 与 docs/process/engineering-standards.md 一一对应，可双向 grep 追溯。
// 七条规则的存量基线（2026-10-27 实测）：RT-01 有 1 条豁免、RT-02 为 0、SV-01 为 0、
// AR-01/03 为 0、AR-02 有 3 条豁免、DS-01 有 38 处走基线——所以上线即绿。
//
// 运行：node tools/check-code-rules.mjs [--write-baseline] [--list-rules]

import { existsSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs'
import { dirname, join, relative, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const selfDir = dirname(fileURLToPath(import.meta.url))
const appRoot = resolve(selfDir, '..')
// 可被 setEtsRoot 覆盖——单测指向临时目录，避免读真实源码
let etsRoot = resolve(appRoot, 'entry/src/main/ets')
const profilePath = resolve(appRoot, 'entry/src/main/resources/base/profile/main_pages.json')
const routesPath = resolve(etsRoot, 'app/AppRoutes.ets')
const baselinePath = resolve(selfDir, 'code-rules-baseline.json')

/** 规则表：id → 人话说明。报错输出直接引用，文档章节标题同名。 */
export const RULES = {
  'RT-01': 'main_pages 注册页与 AppRoutes 常量必须双向一致（豁免见 EXEMPTIONS）',
  'RT-02': '路由跳转必须引用 AppRoutes 常量，禁止硬编码路径字面量',
  'SV-01': '服务模块级单例，调用方禁止再次 new 同一服务',
  'AR-01': 'common/** 不得依赖 features/**',
  'AR-02': 'shared/** 不得依赖 features/**（兼容层例外见 EXEMPTIONS）',
  'AR-03': 'components/** 不得依赖 features/**',
  'DS-01': '组件内联颜色必须走 DesignTokens 或 feature 内命名常量（存量见 baseline）'
}

/**
 * 架构性豁免：必须写 reason 与 ref，否则审查时无从判断是「有意例外」还是「漏网」。
 * 每条都对应仓库内可查的证据。
 */
export const EXEMPTIONS = [
  {
    rule: 'RT-01',
    target: 'features/pencil/pages/PencilPreviewPage',
    reason: '训练预览由 PencilAppShell.build() 条件渲染成壳内覆盖层（非 bindContentCover），不是路由页',
    ref: 'app/AppRoutes.ets:17-20'
  },
  {
    rule: 'AR-02',
    target: 'shared/services/UserDataBackupService.ets',
    reason: '备份须覆盖训练兼容层数据，桥接服务归属 features/workout',
    ref: 'AGENTS.md:48-49'
  },
  {
    rule: 'AR-02',
    target: 'shared/services/AccountDataLifecycle.ets',
    reason: '账号数据生命周期须清理训练兼容层',
    ref: 'AGENTS.md:48-49'
  },
  {
    rule: 'AR-02',
    target: 'shared/services/DeviceSeedService.ets',
    reason: '设备种子数据须经兼容层写入，保证旧数据可见',
    ref: 'AGENTS.md:48-49'
  }
]

function fail(message) {
  throw new Error(`[code-rules] ${message}`)
}

/** 递归收集 etsRoot 下全部 .ets，返回 [{ path, text }]，path 为相对 etsRoot 的正斜杠路径。 */
export function collectEtsFiles(root = etsRoot) {
  const files = []
  const walk = (dir) => {
    for (const name of readdirSync(dir)) {
      const abs = join(dir, name)
      const stat = statSync(abs)
      if (stat.isDirectory()) {
        walk(abs)
        continue
      }
      if (!name.endsWith('.ets')) continue
      files.push({
        path: relative(root, abs).replace(/\\/g, '/'),
        text: readFileSync(abs, 'utf8')
      })
    }
  }
  if (existsSync(root)) walk(root)
  return files
}

function isExempt(rule, target) {
  return EXEMPTIONS.some((item) => item.rule === rule && item.target === target)
}

/** 把相对 import 说明符解析成相对 etsRoot 的正斜杠路径。 */
export function resolveImport(fromPath, spec) {
  const base = resolve(etsRootDirOf(fromPath), spec)
  return relative(etsRoot, base).replace(/\\/g, '/')
}

function etsRootDirOf(fromPath) {
  return resolve(etsRoot, dirname(fromPath))
}

/** 单测注入临时 etsRoot。 */
export function setEtsRoot(nextRoot) {
  etsRoot = nextRoot
  return etsRoot
}

export function getEtsRoot() {
  return etsRoot
}

// ── RT-01：注册页 ↔ 路由常量 双向一致 ─────────────────────────────────────

/** 解析 main_pages.json 的 src 数组。 */
export function parseMainPages(text) {
  const profile = JSON.parse(text)
  if (!Array.isArray(profile.src)) fail('main_pages.json 的 src 必须是数组')
  return profile.src.map((page) => String(page).replace(/\\/g, '/'))
}

/** 解析 AppRoutes.ets 的 `static readonly NAME: string = 'path'`。 */
export function parseRouteConstants(text) {
  const constants = []
  const lines = text.split(/\r?\n/)
  for (let i = 0; i < lines.length; i += 1) {
    const match = lines[i].match(/static\s+readonly\s+(\w+)\s*:\s*string\s*=\s*'([^']+)'/)
    if (match !== null) {
      constants.push({ name: match[1], path: match[2].replace(/\\/g, '/'), line: i + 1 })
    }
  }
  return constants
}

/**
 * RT-01：双向一致。
 * - 每个注册页必须被某个常量指向（或豁免）
 * - 每个常量指向的路径必须在 main_pages 里（或豁免）
 */
export function checkRoutes(pages, constants) {
  const pageSet = new Set(pages)
  const constantPaths = new Set(constants.map((item) => item.path))
  const findings = []

  for (const page of pages) {
    if (constantPaths.has(page)) continue
    if (isExempt('RT-01', page)) continue
    findings.push({
      rule: 'RT-01',
      file: 'app/AppRoutes.ets',
      line: 0,
      message: `${page} 注册在 main_pages.json，但没有任何 AppRoutes 常量指向它`
    })
  }

  for (const constant of constants) {
    if (pageSet.has(constant.path)) continue
    if (isExempt('RT-01', constant.path)) continue
    findings.push({
      rule: 'RT-01',
      file: 'app/AppRoutes.ets',
      line: constant.line,
      message: `常量 ${constant.name} 指向 ${constant.path}，但它未注册到 main_pages.json（若为非路由页请加入 EXEMPTIONS）`
    })
  }

  return findings
}

// ── RT-02：禁止硬编码路由字面量 ──────────────────────────────────────────

const ROUTE_LITERAL_PATTERNS = [
  /(?:pushUrl|replaceUrl)\(\s*['"][^'"]+['"]/,
  /url:\s*['"](?:app|features|pages)\//,
  /url:\s*['"][^'"]*\/(?:pages|components)\//
]

/** RT-02：扫描文件内的路由字面量。含 AppRoutes. 的行放行。 */
export function checkRouteLiterals(files) {
  const findings = []
  for (const file of files) {
    const lines = file.text.split(/\r?\n/)
    for (let i = 0; i < lines.length; i += 1) {
      const line = lines[i]
      if (line.includes('AppRoutes.')) continue
      if (line.trim().startsWith('//') || line.trim().startsWith('*')) continue
      if (!ROUTE_LITERAL_PATTERNS.some((pattern) => pattern.test(line))) continue
      findings.push({
        rule: 'RT-02',
        file: file.path,
        line: i + 1,
        message: `硬编码路由字面量，改用 AppRoutes 常量：${line.trim()}`
      })
    }
  }
  return findings
}

// ── SV-01：服务单例禁止重复实例化 ────────────────────────────────────────

/**
 * SV-01：只拦「import 默认导出后又 new 同名」。
 * 放过工厂模式——`return new ArkPreferencesSessionStore(prefs)` 构造的是本文件内的实现类，
 * 不是导入的单例（实测 SyncService.ets:383 / WorkoutSessionService.ets:228 属这类）。
 */
export function checkServiceSingles(files) {
  const findings = []
  for (const file of files) {
    const lines = file.text.split(/\r?\n/)
    const importedDefaults = new Set()
    const localClasses = new Set()

    for (const line of lines) {
      const imported = line.match(/^\s*import\s+(\w+)\s+from\s+['"][^'"]+['"]/)
      if (imported !== null) importedDefaults.add(imported[1])
      const declared = line.match(/^\s*(?:export\s+)?(?:default\s+)?(?:abstract\s+)?class\s+(\w+)/)
      if (declared !== null) localClasses.add(declared[1])
    }

    for (let i = 0; i < lines.length; i += 1) {
      const line = lines[i]
      if (line.includes('export default')) continue
      if (line.trim().startsWith('//') || line.trim().startsWith('*')) continue
      for (const name of importedDefaults) {
        if (localClasses.has(name)) continue
        if (!new RegExp(`new\\s+${name}\\s*\\(`).test(line)) continue
        findings.push({
          rule: 'SV-01',
          file: file.path,
          line: i + 1,
          message: `${name} 是导入的单例，禁止再次 new（会造成两份状态）`
        })
      }
    }
  }
  return findings
}

// ── AR-01/02/03：分层依赖方向 ────────────────────────────────────────────

const LAYER_RULES = [
  { rule: 'AR-01', from: 'common/', forbidden: 'features/' },
  { rule: 'AR-02', from: 'shared/', forbidden: 'features/' },
  { rule: 'AR-03', from: 'components/', forbidden: 'features/' }
]

/** AR-01/02/03：common / shared / components 不得依赖 features。 */
export function checkLayering(files) {
  const findings = []
  for (const file of files) {
    const sourceLayer = LAYER_RULES.find((item) => file.path.startsWith(item.from))
    if (sourceLayer === undefined) continue

    const lines = file.text.split(/\r?\n/)
    for (let i = 0; i < lines.length; i += 1) {
      const match = lines[i].match(/from\s+'(\.[^']*)'/)
      if (match === null) continue
      const target = resolveImport(file.path, match[1])
      if (!target.startsWith(sourceLayer.forbidden)) continue
      if (isExempt(sourceLayer.rule, file.path)) continue
      findings.push({
        rule: sourceLayer.rule,
        file: file.path,
        line: i + 1,
        message: `${sourceLayer.from} 不得依赖 ${sourceLayer.forbidden}，实际 import 了 ${target}`
      })
    }
  }
  return findings
}

// ── DS-01：内联魔法色值 ─────────────────────────────────────────────────

const INLINE_COLOR =
  /\.(?:backgroundColor|fontColor|borderColor|fillColor|strokeColor|linearGradient)\(\s*'(#[0-9A-Fa-f]{6,8})'/

/** DS-01：只抓属性方法实参位置的裸字面量；`const X: string = '#...'` 命名常量放行。 */
export function collectInlineColors(files) {
  const hits = []
  for (const file of files) {
    const lines = file.text.split(/\r?\n/)
    for (let i = 0; i < lines.length; i += 1) {
      const match = lines[i].match(INLINE_COLOR)
      if (match === null) continue
      hits.push({ file: file.path, line: i + 1, snippet: match[1] })
    }
  }
  return hits
}

/** 把命中与基线按 `file|snippet` 计数比对，只报超出基线的部分。 */
export function diffAgainstBaseline(hits, baselineEntries) {
  const baselineCount = new Map()
  for (const entry of baselineEntries) {
    const key = `${entry.file}|${entry.snippet}`
    baselineCount.set(key, (baselineCount.get(key) ?? 0) + 1)
  }

  const findings = []
  const seen = new Map()
  for (const hit of hits) {
    const key = `${hit.file}|${hit.snippet}`
    const used = (seen.get(key) ?? 0) + 1
    seen.set(key, used)
    const allowed = baselineCount.get(key) ?? 0
    if (used <= allowed) continue
    findings.push({
      rule: 'DS-01',
      file: hit.file,
      line: hit.line,
      message: `内联色值 ${hit.snippet}，改用 DesignTokens 或 feature 内命名常量`
    })
  }
  return findings
}

/** 生成基线条目（file / snippet / line），按 file 排序保证 diff 稳定。 */
export function toBaselineEntries(hits) {
  return hits
    .map((hit) => ({ rule: 'DS-01', file: hit.file, snippet: hit.snippet, line: hit.line }))
    .sort((a, b) => (a.file === b.file ? a.line - b.line : a.file < b.file ? -1 : 1))
}

function loadBaseline() {
  if (!existsSync(baselinePath)) return []
  const parsed = JSON.parse(readFileSync(baselinePath, 'utf8'))
  return Array.isArray(parsed.entries) ? parsed.entries : []
}

function formatFinding(finding) {
  const location = finding.line > 0 ? `${finding.file}:${finding.line}` : finding.file
  return `[${finding.rule}] ${location}  ${finding.message}`
}

function main() {
  const argv = process.argv.slice(2)

  if (argv.includes('--list-rules')) {
    for (const [id, text] of Object.entries(RULES)) console.log(`${id}  ${text}`)
    return
  }

  if (!existsSync(routesPath)) fail(`路由常量文件不存在：${routesPath}`)
  if (!existsSync(profilePath)) fail(`页面注册表不存在：${profilePath}`)

  const pages = parseMainPages(readFileSync(profilePath, 'utf8'))
  const constants = parseRouteConstants(readFileSync(routesPath, 'utf8'))
  const files = collectEtsFiles()

  const findings = [
    ...checkRoutes(pages, constants),
    ...checkRouteLiterals(files),
    ...checkServiceSingles(files),
    ...checkLayering(files)
  ]

  const hits = collectInlineColors(files)

  if (argv.includes('--write-baseline')) {
    const entries = toBaselineEntries(hits)
    const payload = {
      generatedBy: 'check-code-rules.mjs --write-baseline',
      note: '存量技术债台账：只允许缩小。新增违规不得写入本文件。',
      entries
    }
    writeFileSync(baselinePath, `${JSON.stringify(payload, null, 2)}\n`, 'utf8')
    console.log(`[code-rules] 基线已写入 ${relative(process.cwd(), baselinePath) || baselinePath}（${entries.length} 条）`)
    return
  }

  findings.push(...diffAgainstBaseline(hits, loadBaseline()))

  if (findings.length > 0) {
    console.error(`[code-rules] ${findings.length} 处违规：`)
    for (const finding of findings) console.error(`  ${formatFinding(finding)}`)
    console.error('修法见 docs/process/engineering-standards.md 的同名 rule 章节。')
    process.exit(1)
  }

  const exemptCount = EXEMPTIONS.length
  console.log(
    `[code-rules] ${Object.keys(RULES).length} 条规则、${pages.length} 个注册页、` +
      `${constants.length} 个路由常量、${files.length} 个 .ets 文件、${exemptCount} 条豁免、` +
      `${hits.length} 处色值在基线内 —— 全部通过`
  )
  for (const exemption of EXEMPTIONS) {
    console.log(`  exempt [${exemption.rule}] ${exemption.target}`)
  }
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
