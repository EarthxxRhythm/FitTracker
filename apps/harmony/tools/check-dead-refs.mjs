#!/usr/bin/env node
/**
 * check-dead-refs.mjs —— 检查文档/配置里对仓库内文件的路径断言是否仍然成立。
 *
 * 背景：legacy-cleanup-2026-09 归档了一批工具（`live-device-probe.ps1` 等）并把页面
 * 迁到 `features/pencil/pages/`，但 docs/、tasks/、openspec/ 里的路径断言没有同步 ——
 * 活跃文档持续推荐已经不存在的脚本。这类漂移此前没有任何机制可以发现。
 *
 * 基准修正（2026-10）：本仓库已重组为 monorepo —— 仓库根保留 `docs/`、`AGENTS.md`，
 * 而鸿蒙工程（`tools/`、`entry/`、`AppScope/`、`tasks/`、`openspec/`）位于
 * `apps/harmony/` 下。文档里的路径因此存在两种相对基准：
 *   - 相对仓库根（如 `docs/x.md`、`apps/harmony/tools/y.mjs`）
 *   - 相对鸿蒙工程根（如 `tools/y.mjs`、`entry/src/...`、`AppScope/app.json5`）
 *
 * 旧实现用 `process.cwd()` 当仓库根。但 AGENTS.md 规定构建/检查命令都在
 * `apps/harmony` 下执行，于是扫描目标被解析成 `apps/harmony/docs`（根本不存在），
 * 只扫到个位数文件、恒报「无死引用」—— 门禁静默失效（本机实测：cwd=apps/harmony
 * 只扫 7 个文件 1 条断言；cwd=仓库根扫 58 个文件 211 条断言）。反过来在仓库根跑，
 * 又会把相对鸿蒙工程的合法路径（`tools/check-gates.mjs`）全判成死引用（假阳性）。
 *
 * 现改为：
 *   1. repoRoot 由脚本自身位置推导（向上找到同时含 `AGENTS.md` 与 `docs/` 的祖先），
 *      与 cwd 无关 —— 从任何目录运行结果一致；
 *   2. 每条引用依次按「仓库根」与「apps/harmony」两个基准解析，任一存在即视为有效；
 *   3. 扫描仓库根 `docs/`、`apps/harmony/{tasks,openspec}` 与仓库根 `AGENTS.md`。
 *
 * 只识别「反引号包裹 + 以仓库内目录开头 + 有已知扩展名」的字符串，避免把模板路径
 * （`features/<feature>/pages/`）和通配符当成断言。已归档区（路径中含 archive 的目录）
 * 按预期引用旧路径，整体跳过。
 *
 * 用法：node tools/check-dead-refs.mjs [--json]
 * 退出码：0 = 无死引用；1 = 发现死引用
 */
import { readFileSync, existsSync, readdirSync } from 'node:fs'
import { join, resolve, relative, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const outputJson = process.argv.includes('--json')

/**
 * 从 startDir 向上定位仓库根：最近的同时含 `AGENTS.md` 与 `docs/` 的祖先。
 * 找不到返回 null，调用方回退到 cwd。
 */
export function findRepoRoot(startDir) {
  let dir = resolve(startDir)
  for (let depth = 0; depth < 8; depth += 1) {
    if (existsSync(join(dir, 'AGENTS.md')) && existsSync(join(dir, 'docs'))) {
      return dir
    }
    const parent = dirname(dir)
    if (parent === dir) {
      break
    }
    dir = parent
  }
  return null
}

const scriptDir = dirname(fileURLToPath(import.meta.url))
const repoRoot = findRepoRoot(scriptDir) ?? process.cwd()
const appRoot = join(repoRoot, 'apps', 'harmony')

/** 路径断言的解析基准：先仓库根，再鸿蒙工程根（monorepo 两套相对路径并存）。 */
export const BASE_DIRS = existsSync(appRoot) ? [repoRoot, appRoot] : [repoRoot]

const SKIP_DIR_NAMES = new Set([
  '.git', 'node_modules', 'oh_modules', 'build', 'test_run', 'cluster', 'work', 'archive', '.rivet', 'scripts'
])

const PATH_EXT_RE = /\.(ets|ts|js|mjs|cjs|json|json5|md|ps1|py|sh|cmd|bat|html|yaml|yml|txt)$/i
const PATH_PREFIX_RE = /^(apps|entry|tools|design|docs|tasks|openspec|content|AppScope|hvigor|server|contracts)\//
const UNSUPPORTED_CHARS_RE = /[<>*?|"'\\\s]/

// 失效说明行会提到已经不存在的路径（那是澄清而非推荐），不应算作死引用。
const INVALIDATION_HINT_RE = /已归档|已删除|已失效|不再存在|不再适用|已移除|archived?|removed|deleted|no longer|deprecated|obsolete/i

/** 一条相对路径断言是否在任一基准下真实存在。 */
export function existsAtAnyBase(candidate, baseDirs = BASE_DIRS) {
  return baseDirs.some((base) => existsSync(resolve(base, candidate)))
}

/** 扫描给定文件列表，返回 { findings, checked }。纯函数，便于单测注入 fixture。 */
export function collectFindings(targetFiles, baseDirs = BASE_DIRS, rootForRelative = repoRoot) {
  const findings = []
  let checked = 0

  for (const file of targetFiles) {
    const lines = readFileSync(file, 'utf8').split(/\r?\n/)
    for (let index = 0; index < lines.length; index++) {
      for (const match of lines[index].matchAll(/`([^`\n]+)`/g)) {
        const candidate = match[1].trim().replace(/[:#]\d+(?:-\d+)?$/, '')
        if (candidate === '') {
          continue
        }
        if (UNSUPPORTED_CHARS_RE.test(candidate)) {
          continue
        }
        if (!PATH_PREFIX_RE.test(candidate)) {
          continue
        }
        if (!PATH_EXT_RE.test(candidate)) {
          continue
        }
        if (INVALIDATION_HINT_RE.test(lines[index])) {
          continue
        }
        checked += 1
        if (!existsAtAnyBase(candidate, baseDirs)) {
          findings.push({
            file: relative(rootForRelative, file).replace(/\\/g, '/'),
            line: index + 1,
            ref: candidate
          })
        }
      }
    }
  }

  return { findings, checked }
}

function walk(dir, out) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.name.startsWith('.')) {
      continue
    }
    const full = join(dir, entry.name)
    if (entry.isDirectory()) {
      if (SKIP_DIR_NAMES.has(entry.name)) {
        continue
      }
      walk(full, out)
    } else if (entry.isFile() && /\.(md|json|json5)$/i.test(entry.name)) {
      out.push(full)
    }
  }
  return out
}

function collectTargets() {
  const targets = []
  const scanDirs = [
    join(repoRoot, 'docs'),
    join(appRoot, 'tasks'),
    join(appRoot, 'openspec')
  ]
  for (const dir of scanDirs) {
    if (existsSync(dir)) {
      walk(dir, targets)
    }
  }
  const agentsFile = join(repoRoot, 'AGENTS.md')
  if (existsSync(agentsFile)) {
    targets.push(agentsFile)
  }
  return targets
}

function main() {
  const targets = collectTargets()
  const { findings, checked } = collectFindings(targets, BASE_DIRS, repoRoot)

  if (outputJson) {
    console.log(JSON.stringify({
      repoRoot,
      baseDirs: BASE_DIRS,
      scannedFiles: targets.length,
      checked,
      deadRefs: findings.length,
      findings
    }, null, 2))
  } else {
    console.log(`仓库根: ${repoRoot}`)
    console.log(`检查 ${targets.length} 个文件中的 ${checked} 条路径断言`)
    if (findings.length === 0) {
      console.log('无死引用。')
    } else {
      for (const item of findings) {
        console.log(`  ${item.file}:${item.line}  ->  ${item.ref}`)
      }
    }
  }

  process.exit(findings.length === 0 ? 0 : 1)
}

// 仅在直接执行本文件时运行扫描；被 import（例如单测）时只暴露纯函数。
const isDirectRun =
  process.argv[1] !== undefined &&
  resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url))

if (isDirectRun) {
  main()
}
