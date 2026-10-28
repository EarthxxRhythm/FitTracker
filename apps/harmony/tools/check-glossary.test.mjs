// check-glossary.mjs 判据回归测试。
//
// 背景（红用例的来源）：口径漂移不是「某一行写错」，而是同一种事出现两种说法时没人拦。
// 本测试用临时 fixture 把每条规则的「该红」「该绿」「该豁免」都点一遍，保证脚本不是
// 「恰好现在的仓库能过」，而是「判据真的会拦，且不会把解释历史的句子打死」。
//
// 全部用例只在 mkdtempSync 出来的临时目录里造文件（或注入 readFile），不读真实仓库。
// 运行：node --test tools/check-glossary.test.mjs（cwd = apps/harmony）

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'

import {
  BANNED_SYNONYM,
  EXEMPT_WORDING,
  checkFiles,
  checkRegistration,
  collectCurrentScope,
  formatFinding,
  isExcluded,
  isPlatformLimited,
  scanText,
  sortFindings
} from './check-glossary.mjs'

/** 造一份最小注册表；rows 每项形如 { level, path, status }。列顺序必须与真实注册表一致。 */
function makeRegistry(rows) {
  const head = [
    '# 注册表',
    '',
    '| 层级 | 路径 | 管辖 | 适用端 | 状态 | 会漂移 | 自动检查 |',
    '|---|---|---|---|---|---|---|'
  ]
  const body = rows.map(
    (row) => `| ${row.level} | \`${row.path}\` | 示意 | 双端 | ${row.status} | 否 | check-specs（头部） |`
  )
  return [...head, ...body].join('\n')
}

/** 造一个临时仓库根，按 files 写入文件（键为相对路径，值为全文）。 */
function makeRepo(files) {
  const root = mkdtempSync(join(tmpdir(), 'fittracker-glossary-'))
  for (const [relPath, content] of Object.entries(files)) {
    const abs = join(root, relPath)
    mkdirSync(dirname(abs), { recursive: true })
    writeFileSync(abs, content, 'utf8')
  }
  return root
}

function readFrom(root) {
  return (relPath) => {
    try {
      return readFileSync(join(root, relPath), 'utf8')
    } catch {
      return null
    }
  }
}

function rules(findings) {
  return findings.map((finding) => finding.rule)
}

// ---------------------------------------------------------------- GL-01 术语唯一

test('GL-01 正例：现行文档出现「复盘」→ finding 指到行号', function () {
  const text = ['# 标题', '', '训练完成后进入复盘页。', ''].join('\n')
  const findings = scanText('docs/process/x.md', text)

  assert.deepEqual(rules(findings), ['GL-01'])
  assert.equal(findings[0].line, 3)
  assert.match(findings[0].message, /回顾/)
  assert.equal(formatFinding(findings[0]), 'GL-01 docs/process/x.md:3  「复盘」应改为「回顾」')
})

test('GL-01 反例：历史层同文不报——docs/archive/** 不在现行范围', function () {
  const root = makeRepo({
    'docs/a.md': '# A\n\n现行文档。\n',
    'docs/archive/old.md': '# 旧文\n\n历史归档里写复盘是事实记录。\n'
  })
  try {
    const registry = makeRegistry([{ level: 'L2', path: 'docs/a.md', status: '现行' }])
    const scope = collectCurrentScope(registry, root)

    assert.ok(scope.includes('docs/a.md'), '现行文档必须进范围')
    assert.ok(!scope.includes('docs/archive/old.md'), '历史层不得进范围')
    assert.deepEqual(checkFiles(scope, readFrom(root)), [])
  } finally {
    rmSync(root, { recursive: true, force: true })
  }
})

test('GL-01 豁免：同行带失效措辞 → 无 finding', function () {
  const text = ['原「复盘」页已被取代，现名「回顾」。', '首次复盘徽章仍在校验范围（应红）。'].join('\n')
  const findings = scanText('docs/a.md', text)

  assert.deepEqual(rules(findings), ['GL-01'], '只应报第二行')
  assert.equal(findings[0].line, 2)
})

// ---------------------------------------------------------------- GL-02 云后端事实

test('GL-02 正例：「AGC 云数据库」→ finding', function () {
  const findings = scanText('contracts/README.md', '两端后端不同源（AGC / Supabase），AGC 云数据库保存快照。')

  assert.ok(rules(findings).includes('GL-02'))
  assert.equal(findings.find((f) => f.rule === 'GL-02').line, 1)
})

test('GL-02 放行：「AGC 云调试控制台」是平台语境 → 无 finding', function () {
  const line = '在 AGC 云调试控制台安装调试包。'
  assert.equal(isPlatformLimited(line), true)
  assert.deepEqual(scanText('docs/release/x.md', line), [])

  // 反向：一旦同行出现后端词，平台词就不能再当挡箭牌
  const mixed = '在 AGC 控制台开通云数据库。'
  assert.equal(isPlatformLimited(mixed), false)
  assert.deepEqual(rules(scanText('docs/release/x.md', mixed)), ['GL-02'])
})

// ---------------------------------------------------------------- GL-03 凭据文件名

test('GL-03 正例：现行层写 agconnect-services.json → finding，且提示 supabase.json', function () {
  const findings = scanText('docs/process/dual-platform-parity.md', '鸿蒙凭据为 rawfile/agconnect-services.json。')

  assert.deepEqual(rules(findings), ['GL-03'])
  assert.match(findings[0].message, /supabase\.json/)
})

test('GL-03 豁免：同行说明已移除 → 无 finding', function () {
  // 注意：豁免是字面匹配——「整体移除」不算，必须出现「已移除」这类失效措辞本身
  assert.deepEqual(scanText('docs/cloud/cloud-setup.md', '鸿蒙凭据曾是 agconnect-services.json，已随 AGC 整体移除。').map((f) => f.rule), ['GL-03'], '「整体移除」不是豁免措辞，仍应报')
  assert.deepEqual(scanText('docs/cloud/cloud-setup.md', '鸿蒙凭据曾是 agconnect-services.json，2026-10-28 已移除。'), [])
})

// ---------------------------------------------------------------- GL-04 登记

test('GL-04 缺失行 → finding；登记为现行 → 通过', function () {
  const missing = makeRegistry([{ level: 'L2', path: 'docs/other.md', status: '现行' }])
  const missingFindings = checkRegistration(missing)
  assert.deepEqual(rules(missingFindings), ['GL-04'])
  assert.equal(missingFindings[0].file, 'docs/spec-registry.md')
  assert.match(missingFindings[0].message, /docs\/glossary\.md 未登记/)

  const registered = makeRegistry([{ level: 'L2', path: 'docs\\glossary.md', status: '现行' }])
  assert.deepEqual(checkRegistration(registered), [], '反斜杠路径同样算登记为现行')
})

test('GL-04 登记了但状态不是「现行」→ finding（口径真源自称失效就没人能裁定别的规则）', function () {
  const registry = makeRegistry([{ level: 'L2', path: 'docs/glossary.md', status: '已被取代' }])
  const findings = checkRegistration(registry)

  assert.deepEqual(rules(findings), ['GL-04'])
  assert.match(findings[0].message, /应为「现行」/)
})

// ---------------------------------------------------------------- 范围模型与汇总

test('范围模型：注册表只有「现行」行进范围，固定集与代码集无条件纳入', function () {
  const root = makeRepo({
    'AGENTS.md': '# 根约束\n',
    'docs/a.md': '# A\n',
    'docs/old.md': '# 旧\n',
    'contracts/README.md': '# 契约\n',
    'apps/harmony/entry/src/main/ets/app/X.ets': '// 注释\n',
    'apps/harmony/entry/src/main/ets/app/build/Gen.ets': '// 构建产物\n',
    'apps/android/app/src/main/java/Y.kt': '// 注释\n',
    'apps/android/app/src/main/java/Z.java': '// java 不在受检集\n'
  })
  try {
    const registry = makeRegistry([
      { level: 'L2', path: 'docs/a.md', status: '现行' },
      { level: 'L3', path: 'docs/old.md', status: '已被取代' }
    ])
    const scope = collectCurrentScope(registry, root)

    assert.ok(scope.includes('docs/a.md'))
    assert.ok(!scope.includes('docs/old.md'), '「已被取代」不得进现行范围')
    assert.ok(scope.includes('AGENTS.md'), '固定集无条件纳入')
    assert.ok(scope.includes('contracts/README.md'), 'contracts/**/*.md 无条件纳入')
    assert.ok(scope.includes('apps/harmony/entry/src/main/ets/app/X.ets'))
    assert.ok(scope.includes('apps/android/app/src/main/java/Y.kt'))
    assert.ok(!scope.includes('apps/harmony/entry/src/main/ets/app/build/Gen.ets'), 'build/** 必须排除')
    assert.ok(!scope.includes('apps/android/app/src/main/java/Z.java'), '只收 .ets/.kt/.kts')
  } finally {
    rmSync(root, { recursive: true, force: true })
  }
})

test('isExcluded：历史前缀、历史文件、任意层级构建目录都排除，同名文件不误伤', function () {
  for (const excluded of [
    'docs/archive/x.md',
    'docs/CHANGELOG.md',
    'docs/closeout/y.md',
    'docs/superpowers/specs/z.md',
    'node_modules/a/b.mjs',
    'oh_modules/a/b.d.ts',
    'apps/harmony/entry/build/default/X.ets',
    '.rivet/plans/p.md',
    'test_run/wave2/n.md',
    '.git/config'
  ]) {
    assert.equal(isExcluded(excluded), true, `应排除：${excluded}`)
  }

  for (const kept of [
    'docs/glossary.md',
    'apps/harmony/entry/src/main/ets/app/X.ets',
    'apps/harmony/tools/content/build-content.mjs'
  ]) {
    assert.equal(isExcluded(kept), false, `应保留：${kept}`)
  }
})

test('汇总：全绿 fixture 无 finding；混入三类违规按文件→行→规则稳定排序', function () {
  const root = makeRepo({
    'docs/a.md': '# A\n\n训练复盘。\n',
    'docs/b.md': '# B\n\n鸿蒙凭据 agconnect-services.json，AGC 云数据库保存快照。\n'
  })
  try {
    const clean = makeRepo({
      'docs/a.md': '# A\n\n训练回顾；凭据 supabase.json；后端自托管 Supabase。\n'
    })
    try {
      assert.deepEqual(checkFiles(['docs/a.md'], readFrom(clean)), [])
    } finally {
      rmSync(clean, { recursive: true, force: true })
    }

    const findings = checkFiles(['docs/b.md', 'docs/a.md'], readFrom(root))
    assert.deepEqual(
      sortFindings(findings).map((finding) => formatFinding(finding)).map((line) => line.split('  ')[0]),
      ['GL-01 docs/a.md:3', 'GL-02 docs/b.md:3', 'GL-03 docs/b.md:3']
    )
  } finally {
    rmSync(root, { recursive: true, force: true })
  }
})

test('常量与文档一致：禁用词/失效措辞集合不为空，漏改会立刻红', function () {
  assert.equal(BANNED_SYNONYM, '复盘')
  assert.deepEqual(EXEMPT_WORDING, ['已移除', '已被取代', '历史', '不再启用', '作废'])
})
