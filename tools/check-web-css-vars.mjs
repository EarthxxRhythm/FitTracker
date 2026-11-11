#!/usr/bin/env node
/**
 * 门禁：web 站点的 CSS 变量完整性。
 *
 * 为什么需要：357b9d5 的「死类清理」把 legacy.css 顶部的 :root 令牌块整段删除，
 * 而全文仍在引用这些旧名。detector 只按类名判断死代码，看不见变量定义；
 * 八条既有门禁也没有一条能发现「CSS 引用了未定义的变量」，于是圆角、过渡、
 * 间距在无人察觉的情况下全部回退到初始值，直到首次部署才暴露。
 *
 * 判据：
 *   - 只报**裸引用** var(--x)：它没有兜底，未定义即失效。
 *   - var(--x, ...) 带 fallback，自动豁免。
 *   - Tailwind v4 注入的内部变量（--tw-* / --default-*）豁免。
 *   - JS 运行时写入的 --i/--mx/--my/--rx/--ry 豁免。
 *
 * 退出码：0 = 全部有定义；1 = 存在裸引用但无定义。
 *
 * 用法：node tools/check-web-css-vars.mjs [--json]
 */
import { readdirSync, readFileSync, statSync } from 'node:fs'
import { dirname, join, relative, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptDir = dirname(fileURLToPath(import.meta.url))
const repoRoot = resolve(scriptDir, '..')

/** Tailwind v4 在构建期注入，源码里不出现定义。 */
const INTERNAL_PREFIX = /^--(tw-|default-)/
/** 由 JS 运行时写入的元素上变量，不由 CSS 定义。 */
const RUNTIME_VARS = new Set(['--i', '--mx', '--my', '--rx', '--ry'])

/** 递归收集 .css 文件。 */
export function collectCss(dir, out = []) {
  let entries
  try {
    entries = readdirSync(dir)
  } catch {
    return out
  }
  for (const name of entries) {
    if (name === 'node_modules') continue
    const full = join(dir, name)
    const st = statSync(full)
    if (st.isDirectory()) {
      collectCss(full, out)
    } else if (name.endsWith('.css')) {
      out.push(full)
    }
  }
  return out
}

/**
 * 扫描一组 CSS 文件，返回 { defined, bareRefs }。
 * bareRefs 只包含 var(--x) 这种没有逗号兜底的引用。
 * 传入的 textById 允许测试注入内存 fixture，不必落盘。
 */
export function scanCss(files, root = repoRoot, textById = null) {
  const defined = new Set()
  const bareRefs = []

  for (const file of files) {
    const text = textById ? textById(file) : readFileSync(file, 'utf8')
    const lines = text.split(/\r?\n/)
    lines.forEach((line, index) => {
      // 定义：--name: value
      for (const m of line.matchAll(/(?:^|[;{\s])(--[a-z0-9-]+)\s*:/gi)) {
        defined.add(m[1])
      }
      // 裸引用：var(--name) —— 括号内没有逗号
      for (const m of line.matchAll(/var\(\s*(--[a-z0-9-]+)\s*\)/gi)) {
        bareRefs.push({ name: m[1], file: relative(root, file), line: index + 1 })
      }
    })
  }

  return { defined, bareRefs }
}

/** 过滤出真正失效的引用。纯函数，便于单测注入。 */
export function findUndefined(bareRefs, defined) {
  return bareRefs.filter(
    (ref) => !defined.has(ref.name) && !RUNTIME_VARS.has(ref.name) && !INTERNAL_PREFIX.test(ref.name)
  )
}

function main() {
  const webSrc = join(repoRoot, 'web', 'src')
  const files = collectCss(webSrc)
  if (files.length === 0) {
    console.error(`[css-vars] 未找到任何 CSS 文件：${webSrc}`)
    process.exit(1)
  }

  const { defined, bareRefs } = scanCss(files)
  const missing = findUndefined(bareRefs, defined)

  if (process.argv.includes('--json')) {
    console.log(JSON.stringify({ files: files.length, defined: defined.size, missing }, null, 2))
    return
  }

  if (missing.length > 0) {
    console.error(`[css-vars] ${files.length} 个 CSS 文件，定义 ${defined.size} 个变量，${missing.length} 处裸引用没有定义：`)
    const byName = new Map()
    for (const item of missing) {
      if (!byName.has(item.name)) byName.set(item.name, [])
      byName.get(item.name).push(`${item.file}:${item.line}`)
    }
    for (const [name, where] of byName) {
      console.error(`  ${name}  <-  ${where.slice(0, 3).join(', ')}${where.length > 3 ? ` 等 ${where.length} 处` : ''}`)
    }
    console.error('')
    console.error('修法二选一：')
    console.error('  1) 在 web/src/index.css 的 :root 兼容层补上定义（颜色指向 @theme，例如 --bg: var(--color-ink)）；')
    console.error('  2) 若该引用本就允许缺失，写成 var(--name, 兜底值) 自带 fallback。')
    process.exit(1)
  }

  console.log(`[css-vars] ${files.length} 个 CSS 文件，${bareRefs.length} 处裸引用全部有定义 ✔`)
}

const invokedDirectly =
  process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)
if (invokedDirectly) {
  main()
}
