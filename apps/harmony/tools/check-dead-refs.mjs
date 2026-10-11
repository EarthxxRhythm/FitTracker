#!/usr/bin/env node
/**
 * check-dead-refs.mjs —— 检查文档/配置里对仓库内文件的路径断言是否仍然成立。
 *
 * 背景：legacy-cleanup-2026-09 归档了一批工具（`live-device-probe.ps1` 等）并把页面
 * 迁到 `features/pencil/pages/`，但 docs/、tasks/、openspec/ 里的路径断言没有同步 ——
 * 活跃文档持续推荐已经不存在的脚本。这类漂移此前没有任何机制可以发现。
 *
 * 检查范围：`docs/`、`tasks/`、`openspec/` 下的 md/json/json5，以及根 `AGENTS.md`。
 * 只识别「反引号包裹 + 以仓库内目录开头 + 有已知扩展名」的字符串，避免把模板路径
 * （`features/<feature>/pages/`）和通配符当成断言。
 * 已归档区（路径中含 archive 的目录）按预期引用旧路径，整体跳过。
 *
 * 用法：node tools/check-dead-refs.mjs [--json]
 * 退出码：0 = 无死引用；1 = 发现死引用
 */
import { readFileSync, existsSync, readdirSync } from 'node:fs'
import { join, resolve, relative } from 'node:path'

const repoRoot = process.cwd()
const outputJson = process.argv.includes('--json')

const SCAN_DIRS = ['docs', 'tasks', 'openspec']
const SCAN_ROOT_FILES = ['AGENTS.md']

const SKIP_DIR_NAMES = new Set([
  '.git', 'node_modules', 'oh_modules', 'build', 'test_run', 'cluster', 'work', 'archive', '.rivet', 'scripts'
])

const PATH_EXT_RE = /\.(ets|ts|js|mjs|cjs|json|json5|md|ps1|py|sh|cmd|bat|html|yaml|yml|txt)$/i
const PATH_PREFIX_RE = /^(entry|tools|design|docs|tasks|openspec|content|AppScope|hvigor)\//
const UNSUPPORTED_CHARS_RE = /[<>*?|"'\\\s]/

// 失效说明行会提到已经不存在的路径（那是澄清而非推荐），不应算作死引用。
const INVALIDATION_HINT_RE = /已归档|已删除|已失效|不再存在|不再适用|已移除|archived?|removed|deleted|no longer|deprecated|obsolete/i

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

const targets = []
for (const dirName of SCAN_DIRS) {
  const abs = resolve(repoRoot, dirName)
  if (existsSync(abs)) {
    walk(abs, targets)
  }
}
for (const fileName of SCAN_ROOT_FILES) {
  const abs = resolve(repoRoot, fileName)
  if (existsSync(abs)) {
    targets.push(abs)
  }
}

const findings = []
let checked = 0

for (const file of targets) {
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
      if (!existsSync(resolve(repoRoot, candidate))) {
        findings.push({
          file: relative(repoRoot, file).replace(/\\/g, '/'),
          line: index + 1,
          ref: candidate
        })
      }
    }
  }
}

if (outputJson) {
  console.log(JSON.stringify({ scannedFiles: targets.length, checked, deadRefs: findings.length, findings }, null, 2))
} else {
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
