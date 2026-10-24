#!/usr/bin/env node
/**
 * check-icon-assets.mjs —— 图标资产口径检查（rawfile 下的 SVG）。
 *
 * 背景：rawfile 曾并存三族图标 —— lucide 24 视框描边族、iconfont 1024 视框实心族
 * （带 #8e8e93 灰与 #3a71ca 蓝，而品牌色是 #50ECA7 / #45C9A1）、业务专用衍生族。
 * 更隐蔽的一种漂移是「改名换皮」：pencil-calendar.svg 是 日历.svg 的逐字节副本，
 * 前缀改成了 pencil-*，内容仍是 1024 视框灰图标，且零引用。只靠人眼看文件名发现不了。
 *
 * 与 check-dead-refs.mjs 的分工：那个查「docs/tasks/openspec 里反引号包裹的文档路径
 * 断言是否还存在」；本脚本查「图标资产本身的命名 / 视框 / 引用关系」。两者正交。
 *
 * 四条判据：
 *   1. 文件名 —— ^[a-z0-9][a-z0-9-]*\.svg$，ASCII kebab，禁中文 / 空格 / 大写。
 *   2. 视框   —— 禁止 1024 视框（iconfont 族指纹）。
 *      ⚠ 刻意不做「必须 24 视框」的硬断言：勾选 / 箭头 / 奖牌等小图形天然不是方形
 *      （实测 7 个例外：42×42、13×9、-1 -1 15 15、80×80 等），它们不是混族，
 *      硬断言只会制造误报。判据要抓的是「哪一族」，不是「所有图标必须同一尺寸」。
 *   3. 引用完整性 —— ets 里每个 $rawfile('x.svg') 必须真实存在。
 *   4. 孤儿 —— rawfile 里每个 .svg 必须至少被 ets 源码字面量引用一次。
 *      动态引用（如 $rawfile(this.source)）无法静态解析，需登记到 ALLOWLIST。
 *
 * 用法：node tools/check-icon-assets.mjs [--json]
 * 退出码：0 = 全部通过；1 = 有违规
 */
import { readFileSync, existsSync, readdirSync } from 'node:fs'
import { join, dirname, resolve, relative } from 'node:path'
import { fileURLToPath } from 'node:url'

import { findRepoRoot } from './check-dead-refs.mjs'

/** 合规文件名：ASCII kebab。 */
export const NAME_RE = /^[a-z0-9][a-z0-9-]*\.svg$/

/** iconfont 族视框指纹。 */
export const ICONFONT_VIEWBOX = '0 0 1024 1024'

/**
 * 孤儿检测豁免清单。
 *
 * 当前为空：43 个图标的引用全部是 ets 里的字面量 $rawfile('x.svg')，可静态解析。
 * 若将来出现 $rawfile(someVar) 这类动态引用，把该文件名登记到这里，并在这行注释
 * 写明「由哪个文件动态引用」——豁免必须带理由，否则就退化成掩盖。
 */
export const ALLOWLIST = []

/** 判断文件名是否合规。null = 合规。 */
export function checkName(fileName) {
  if (!NAME_RE.test(fileName)) {
    return '文件名须为 ASCII kebab（小写字母/数字/连字符），实际: ' + fileName
  }
  return null
}

/** 判断 SVG 源码是否含 iconfont 族视框。null = 合规。 */
export function checkViewBox(source) {
  if (source.indexOf(ICONFONT_VIEWBOX) !== -1) {
    return '含 iconfont 族视框 "' + ICONFONT_VIEWBOX + '"，须转 24 视框或删除'
  }
  return null
}

/** 从 ets 源码里提取 $rawfile('x.svg') 字面量引用的文件名。 */
export function extractRawfileSvgRefs(source) {
  const out = []
  const re = /\$rawfile\(\s*['"]([^'"]+\.svg)['"]\s*\)/g
  for (const match of source.matchAll(re)) {
    out.push(match[1])
  }
  return out
}

/**
 * 核心检查。纯函数，便于单测注入 fixture。
 *
 * @param {Array<{name: string, source: string}>} iconFiles 资产文件与其 SVG 源码
 * @param {string[]} etsSources 所有 ets 源码文本
 * @param {string[]} allowlist 孤儿检测豁免的文件名
 * @returns {{issues: Array<{file: string, rule: string, detail: string}>, iconCount: number, refCount: number}}
 */
export function collectIconIssues(iconFiles, etsSources, allowlist = ALLOWLIST) {
  const issues = []
  const known = new Set()

  for (const icon of iconFiles) {
    known.add(icon.name)
    const nameIssue = checkName(icon.name)
    if (nameIssue !== null) {
      issues.push({ file: icon.name, rule: 'name', detail: nameIssue })
    }
    const viewIssue = checkViewBox(icon.source)
    if (viewIssue !== null) {
      issues.push({ file: icon.name, rule: 'viewBox', detail: viewIssue })
    }
  }

  const referenced = new Set()
  const reportedMissing = new Set()
  for (const source of etsSources) {
    for (const ref of extractRawfileSvgRefs(source)) {
      referenced.add(ref)
      if (!known.has(ref) && !reportedMissing.has(ref)) {
        reportedMissing.add(ref)
        issues.push({ file: ref, rule: 'missing', detail: 'ets 引用了不存在的图标文件' })
      }
    }
  }

  const allow = new Set(allowlist)
  for (const icon of iconFiles) {
    if (referenced.has(icon.name) || allow.has(icon.name)) {
      continue
    }
    issues.push({
      file: icon.name,
      rule: 'orphan',
      detail: '未被任何 ets 源码字面量引用（动态引用请登记 ALLOWLIST 并写明理由）'
    })
  }

  return { issues: issues, iconCount: iconFiles.length, refCount: referenced.size }
}

// ── 以下为 IO 层，不参与单测 ────────────────────────────────────────────

const SKIP_DIR_NAMES = new Set(['.git', 'node_modules', 'oh_modules', 'build', 'test_run', '.rivet'])

function walk(dir, predicate, out) {
  if (!existsSync(dir)) {
    return out
  }
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name)
    if (entry.isDirectory()) {
      if (SKIP_DIR_NAMES.has(entry.name)) {
        continue
      }
      walk(full, predicate, out)
    } else if (entry.isFile() && predicate(entry.name)) {
      out.push(full)
    }
  }
  return out
}

function main() {
  const outputJson = process.argv.includes('--json')
  const scriptDir = dirname(fileURLToPath(import.meta.url))
  const repoRoot = findRepoRoot(scriptDir) ?? process.cwd()
  const appRoot = join(repoRoot, 'apps', 'harmony')
  const rawfileDir = join(appRoot, 'entry', 'src', 'main', 'resources', 'rawfile')
  const etsRoot = join(appRoot, 'entry', 'src')

  const svgPaths = walk(rawfileDir, (name) => name.endsWith('.svg'), [])
  const iconFiles = svgPaths.map((full) => ({
    name: relative(rawfileDir, full).replace(/\\/g, '/'),
    source: readFileSync(full, 'utf8')
  }))

  const etsPaths = walk(etsRoot, (name) => name.endsWith('.ets'), [])
  const etsSources = etsPaths.map((full) => readFileSync(full, 'utf8'))

  const result = collectIconIssues(iconFiles, etsSources)

  if (outputJson) {
    console.log(JSON.stringify({
      repoRoot: repoRoot,
      rawfileDir: relative(repoRoot, rawfileDir).replace(/\\/g, '/'),
      etsFilesScanned: etsPaths.length,
      iconCount: result.iconCount,
      refCount: result.refCount,
      issueCount: result.issues.length,
      issues: result.issues
    }, null, 2))
  } else {
    console.log('资产目录: ' + relative(repoRoot, rawfileDir).replace(/\\/g, '/'))
    console.log('扫描 ' + etsPaths.length + ' 个 ets 文件，' + result.iconCount + ' 个 SVG 图标，'
      + result.refCount + ' 个被引用')
    if (result.issues.length === 0) {
      console.log('图标口径检查通过。')
    } else {
      for (const issue of result.issues) {
        console.log('  [' + issue.rule + '] ' + issue.file + ' — ' + issue.detail)
      }
    }
  }

  process.exit(result.issues.length === 0 ? 0 : 1)
}

const isDirectRun =
  process.argv[1] !== undefined &&
  resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url))

if (isDirectRun) {
  main()
}
