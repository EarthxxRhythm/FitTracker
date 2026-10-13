// check-dead-refs.mjs 判据回归测试。
//
// 背景（RED 用例的来源）：脚本旧实现用 `process.cwd()` 当仓库根。本仓库是 monorepo，
// docs/AGENTS.md 在仓库根，而 tools/entry/AppScope/tasks 在 apps/harmony/ 下 ——
// 文档里的路径因此有两套相对基准。旧实现在以下两种情形各错一次：
//   - 按 AGENTS.md 约定在 apps/harmony 下运行：仓库根的 docs/ 与 AGENTS.md 根本不参与
//     扫描（apps/harmony/docs 不存在），门禁恒报「无死引用」—— 静默失效（假阴性）。
//   - 在仓库根运行：相对鸿蒙工程根的合法路径（`tools/check-gates.mjs`）全被判死引用
//     —— 假阳性。
// 修正后 repoRoot 由脚本位置推导、路径按双基准解析，两个 cwd 结果一致。
//
// 运行：node --test tools/check-dead-refs.test.mjs

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

import { findRepoRoot, existsAtAnyBase, collectFindings } from './check-dead-refs.mjs'

/** 造一个最小 monorepo fixture：仓库根有 AGENTS.md + docs/，鸿蒙工程在 apps/harmony/ 下。 */
function makeRepo() {
  const root = mkdtempSync(join(tmpdir(), 'fittracker-deadrefs-'))
  mkdirSync(join(root, 'docs'), { recursive: true })
  mkdirSync(join(root, 'apps', 'harmony', 'tools'), { recursive: true })
  writeFileSync(join(root, 'AGENTS.md'), '# fixture\n', 'utf8')
  writeFileSync(join(root, 'apps', 'harmony', 'tools', 'exists.mjs'), '', 'utf8')
  return root
}

function baseDirsOf(root) {
  return [root, join(root, 'apps', 'harmony')]
}

function cleanup(root) {
  rmSync(root, { recursive: true, force: true })
}

test('findRepoRoot 从鸿蒙工程子目录向上定位到含 AGENTS.md + docs 的仓库根', function () {
  const root = makeRepo()
  try {
    assert.equal(findRepoRoot(join(root, 'apps', 'harmony', 'tools')), root)
    assert.equal(findRepoRoot(join(root, 'apps', 'harmony')), root)
  } finally {
    cleanup(root)
  }
})

test('existsAtAnyBase：相对鸿蒙工程根的路径在双基准下判为有效', function () {
  const root = makeRepo()
  try {
    const baseDirs = baseDirsOf(root)
    assert.equal(existsAtAnyBase('tools/exists.mjs', baseDirs), true, 'appRoot 基准应命中')
    assert.equal(existsAtAnyBase('tools/missing.mjs', baseDirs), false, '两个基准都不存在应判死引用')
  } finally {
    cleanup(root)
  }
})

test('collectFindings：双基准解析不误报合法路径，只报真死引用（旧实现在仓库根基准下会误报）', function () {
  const root = makeRepo()
  try {
    const doc = join(root, 'docs', 'scan.md')
    writeFileSync(
      doc,
      [
        '引用 `tools/exists.mjs`（相对鸿蒙工程根，合法）',
        '引用 `apps/harmony/tools/exists.mjs`（相对仓库根，合法）',
        '引用 `tools/missing.mjs`（真死引用）'
      ].join('\n'),
      'utf8'
    )

    const result = collectFindings([doc], baseDirsOf(root), root)

    assert.equal(result.checked, 3, '三条反引号路径断言都应被检查')
    assert.equal(result.findings.length, 1, '只有真死引用被报出')
    assert.equal(result.findings[0].ref, 'tools/missing.mjs')
    assert.equal(result.findings[0].file, 'docs/scan.md')
    assert.equal(result.findings[0].line, 3)
  } finally {
    cleanup(root)
  }
})

test('collectFindings：同一文本在两种基准目录下解析结果一致（消除 cwd 依赖）', function () {
  const root = makeRepo()
  try {
    const doc = join(root, 'docs', 'scan.md')
    writeFileSync(doc, '引用 `tools/exists.mjs` 与 `docs/scan.md`。\n', 'utf8')

    // 无论调用方把「仓库根」理解成 repoRoot 还是 appRoot，扫描结果都必须一致。
    const fromRepoRoot = collectFindings([doc], baseDirsOf(root), root)
    const fromAppRoot = collectFindings([doc], [root, join(root, 'apps', 'harmony')], root)

    assert.deepEqual(fromRepoRoot.findings, fromAppRoot.findings)
    assert.equal(fromRepoRoot.findings.length, 0, '两条断言在双基准下都应有效')
    assert.equal(fromRepoRoot.checked, 2)
  } finally {
    cleanup(root)
  }
})

test('带失效措辞的行被豁免（澄清历史路径不算推荐）', function () {
  const root = makeRepo()
  try {
    const doc = join(root, 'docs', 'scan.md')
    writeFileSync(doc, '该脚本 `tools/missing.mjs` 已归档，不再使用。\n', 'utf8')

    const result = collectFindings([doc], baseDirsOf(root), root)

    assert.equal(result.checked, 0, '失效说明行不计入断言')
    assert.equal(result.findings.length, 0)
  } finally {
    cleanup(root)
  }
})

test('模板路径与通配符不当作断言', function () {
  const root = makeRepo()
  try {
    const doc = join(root, 'docs', 'scan.md')
    writeFileSync(doc, '页面放 `entry/src/main/ets/features/<feature>/pages/` 下。\n', 'utf8')

    const result = collectFindings([doc], baseDirsOf(root), root)

    assert.equal(result.checked, 0)
    assert.equal(result.findings.length, 0)
  } finally {
    cleanup(root)
  }
})
