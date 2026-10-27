// check-specs.mjs 判据回归测试。
//
// 背景（红用例的来源）：注册表是手写的 markdown 表格，文件被删、路径被改、头部字段漏填、
// 注册表与文件状态不一致——这四类漂移都没有人拦。本测试用临时 fixture 把每一类都点成红，
// 保证脚本不是「恰好现在的仓库能过」而是「判据真的会拦」。
//
// 运行：node --test tools/check-specs.test.mjs（cwd = apps/harmony）

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, dirname } from 'node:path'

import {
  parseRegistry,
  parseHeader,
  isPastDate,
  normalizeLevel,
  normalizeStatus,
  checkRegistryConsistency,
  HEADER_FIELDS
} from './check-specs.mjs'

const HEADER = [
  '> **层级**：L2 展开',
  '> **最后核对**：2026-10-27',
  '> **上位文档**：AGENTS.md（L1）',
  '> **状态**：现行',
  '> **路径基准**：文中路径相对仓库根',
  '> **适用端**：双端'
].join('\n')

/** 造一份最小注册表；rows 每项形如 { level, path, status, check }。 */
function makeRegistry(rows) {
  const head = [
    '# 注册表',
    '',
    '| 层级 | 路径 | 管辖 | 适用端 | 状态 | 会漂移 | 自动检查 |',
    '|---|---|---|---|---|---|---|'
  ]
  const body = rows.map((row) =>
    `| ${row.level} | \`${row.path}\` | 示意 | 双端 | ${row.status} | 否 | ${row.check} |`
  )
  return [...head, ...body].join('\n')
}

/** 造一个临时仓库根，按 files 写入文件（键为相对路径，值为全文）。 */
function makeRepo(files) {
  const root = mkdtempSync(join(tmpdir(), 'fittracker-specs-'))
  for (const [relPath, content] of Object.entries(files)) {
    const abs = join(root, relPath)
    mkdirSync(dirname(abs), { recursive: true })
    writeFileSync(abs, content, 'utf8')
  }
  return root
}

function readFrom(root) {
  return (absPath) => {
    try {
      return readFileSync(absPath, 'utf8')
    } catch {
      return null
    }
  }
}

test('parseRegistry：只解析含「自动检查」的主表，另两张表列数不同被跳过', function () {
  const text = [
    makeRegistry([{ level: 'L2', path: 'docs/a.md', status: '现行', check: 'check-specs（头部）' }]),
    '',
    '## 已删除的规范',
    '',
    '| 路径 | 删除日期 | 去因 | 内容去向 |',
    '|---|---|---|---|',
    '| `docs/gone.md` | 2026-10-27 | 失效 | 并入别处 |',
    '',
    '## 索引文档',
    '',
    '| 路径 | 作用 |',
    '|---|---|',
    '| `README.md` | 总览 |'
  ].join('\n')

  const rows = parseRegistry(text)

  assert.equal(rows.length, 1, '只应解析主表一行，不混入已删除表与索引表')
  assert.equal(rows[0].path, 'docs/a.md', '反引号应被剥掉')
  assert.equal(rows[0].level, 'L2')
})

test('parseRegistry：主表列顺序被改动时大声失败', function () {
  const text = [
    '| 层级 | 路径 | 管辖 | 状态 | 适用端 | 会漂移 | 自动检查 |',
    '|---|---|---|---|---|---|---|',
    '| L2 | `docs/a.md` | x | 现行 | 双端 | 否 | 头部 |'
  ].join('\n')

  assert.throws(() => parseRegistry(text), /列顺序被改动/)
})

test('parseHeader：6 字段齐全时 missing 为空', function () {
  const doc = `# 标题\n\n${HEADER}\n\n正文\n`
  const { found, missing, h1 } = parseHeader(doc)

  assert.equal(h1, '# 标题')
  assert.deepEqual(missing, [])
  assert.equal(found['层级'], 'L2 展开')
  assert.equal(found['适用端'], '双端')
  assert.equal(HEADER_FIELDS.length, 6)
})

test('parseHeader：缺字段时逐个列出（红用例）', function () {
  const doc = [
    '# 标题',
    '',
    '> **层级**：L2 展开',
    '> **最后核对**：2026-10-27',
    '',
    '正文'
  ].join('\n')

  const { missing } = parseHeader(doc)

  assert.deepEqual(missing, ['上位文档', '状态', '路径基准', '适用端'])
})

test('isPastDate：今天算通过、明天算失败、非法格式算失败', function () {
  const today = new Date(2026, 9, 27, 1, 20, 0) // 本地 2026-10-27 凌晨

  assert.equal(isPastDate('2026-10-27', today), true, '当天必须通过（本地口径）')
  assert.equal(isPastDate('2026-10-26', today), true)
  assert.equal(isPastDate('2026-10-28', today), false, '未来日期必须失败')
  assert.equal(isPastDate('2026-13-01', today), false, '月份越界必须失败')
  assert.equal(isPastDate('2026-02-31', today), false, '不存在的日期必须失败')
  assert.equal(isPastDate('2026/10/27', today), false, '格式必须为 YYYY-MM-DD')
})

test('normalizeLevel / normalizeStatus：只认受控取值', function () {
  assert.equal(normalizeLevel('L1 权威'), 'L1')
  assert.equal(normalizeLevel('L4 自造'), null)
  assert.equal(normalizeStatus('现行（3 项待裁决）'), '现行')
  assert.equal(normalizeStatus('部分失效'), '部分失效')
  assert.equal(normalizeStatus('半失效'), null)
})

test('checkRegistryConsistency：完整 fixture 全绿', function () {
  const root = makeRepo({
    'docs/a.md': `# A\n\n${HEADER}\n\n正文\n`,
    'AGENTS.md': `# 根约束\n\n${HEADER.replace('L2 展开', 'L1 权威')}\n\n正文\n`
  })
  try {
    const rows = parseRegistry(
      makeRegistry([
        { level: 'L2', path: 'docs/a.md', status: '现行', check: 'check-specs（头部）' },
        { level: 'L1', path: 'AGENTS.md', status: '现行', check: 'check-specs（头部）' }
      ])
    )
    const findings = checkRegistryConsistency(rows, readFrom(root), new Date(2026, 9, 27), root)
    assert.deepEqual(findings, [], `应无 finding，实际：${findings.join(' / ')}`)
  } finally {
    rmSync(root, { recursive: true, force: true })
  }
})

test('checkRegistryConsistency：文件缺失 → 红', function () {
  const root = makeRepo({})
  try {
    const rows = parseRegistry(
      makeRegistry([{ level: 'L2', path: 'docs/missing.md', status: '现行', check: 'check-specs（头部）' }])
    )
    const findings = checkRegistryConsistency(rows, readFrom(root), new Date(2026, 9, 27), root)
    assert.equal(findings.length, 1)
    assert.match(findings[0], /文件不存在/)
  } finally {
    rmSync(root, { recursive: true, force: true })
  }
})

test('checkRegistryConsistency：注册表「现行」而文件头部「部分失效」→ 红', function () {
  const root = makeRepo({
    'docs/a.md': `# A\n\n${HEADER.replace('**状态**：现行', '**状态**：部分失效')}\n\n正文\n`
  })
  try {
    const rows = parseRegistry(
      makeRegistry([{ level: 'L2', path: 'docs/a.md', status: '现行', check: 'check-specs（头部）' }])
    )
    const findings = checkRegistryConsistency(rows, readFrom(root), new Date(2026, 9, 27), root)
    assert.equal(findings.length, 1)
    assert.match(findings[0], /状态不一致/)
  } finally {
    rmSync(root, { recursive: true, force: true })
  }
})

test('checkRegistryConsistency：标「仅存在」的文件不校验头部（绿）', function () {
  const root = makeRepo({ 'docs/raw.md': '# 裸文档\n\n没有统一头部。\n' })
  try {
    const rows = parseRegistry(
      makeRegistry([{ level: 'L3', path: 'docs/raw.md', status: '现行', check: 'check-specs（仅存在）' }])
    )
    const findings = checkRegistryConsistency(rows, readFrom(root), new Date(2026, 9, 27), root)
    assert.deepEqual(findings, [])
  } finally {
    rmSync(root, { recursive: true, force: true })
  }
})

test('checkRegistryConsistency：未来日期 → 红（防写未来假装已核对）', function () {
  const root = makeRepo({
    'docs/a.md': `# A\n\n${HEADER.replace('2026-10-27', '2026-12-31')}\n\n正文\n`
  })
  try {
    const rows = parseRegistry(
      makeRegistry([{ level: 'L2', path: 'docs/a.md', status: '现行', check: 'check-specs（头部）' }])
    )
    const findings = checkRegistryConsistency(rows, readFrom(root), new Date(2026, 9, 27), root)
    assert.equal(findings.length, 1)
    assert.match(findings[0], /最后核对/)
  } finally {
    rmSync(root, { recursive: true, force: true })
  }
})
