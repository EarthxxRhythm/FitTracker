// web/tools/board-data.test.mjs
// 开发看板数据管道单测。直跑：node --test web/tools/board-data.test.mjs
// （根级 tools/run-tests.mjs 不扫 web/tools/，故以 node --test 直跑为准。）
//
// 覆盖四组解析器 + 集成入口，API 以 web/tools/board-data.d.mts 的声明为准：
//   parseCommand(md) → BoardSection[]        { title, text, tables[{header, rows}] }
//   normalizePlanStatus(raw) → 五态之一
//   parsePlans() → BoardPlan[]               { file, status, statusRaw, bytes, modifiedAt, absPath }
//   parseGit() → BoardGit                    { available, head, log[], status[], error? }
//   collectBoardData() → { generatedAt, command, plans, git }
//
// 容错是本模块的第一职责：COMMAND.md 是替换式更新的半结构化 Markdown，
// plans 的 Status 标记三态混存。格式漂移时降级，绝不抛错。

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, existsSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

import {
  claimUncommittedCount,
  collectBoardData,
  computeDrift,
  countCheckboxes,
  normalizePlanStatus,
  parseCommand,
  parseGit,
  parsePlanGoals,
  parsePlans,
} from './board-data.mjs'

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..')
const REAL_PLANS_DIR = resolve(REPO_ROOT, '.rivet', 'plans')
const STATUSES = ['APPROVED', 'EXECUTED', 'REJECTED', 'DRAFT', 'UNKNOWN']

function withTempDir (fn) {
  const dir = mkdtempSync(join(tmpdir(), 'board-data-'))
  try {
    return fn(dir)
  } finally {
    rmSync(dir, { recursive: true, force: true })
  }
}

// ── fixtures ────────────────────────────────────────────────────────────

const COMMAND_FIXTURE = [
  '# FitTracker 指挥官总账',
  '',
  '> 更新：2026-11-01 · 维护者：天枢会话',
  '',
  '## 一、现在到哪了（读这一段就够）',
  '',
  '**一句话**：已全部提交。',
  '',
  '| 线 | 状态 | 证据 | 下一步 |',
  '|---|---|---|---|',
  '| 后端迁移 | ✅ 已提交 | `ce8b01f` | — |',
  '| 发布链路 | **阻塞** | 备案材料 | 用户 |',
  '',
  '## 二、无表格章节',
  '',
  '只有一句话，没有表格。',
  '',
].join('\n')

// ── parseCommand ────────────────────────────────────────────────────────

test('parseCommand: 按 ## 分节，每节保留散文(text)与表格(tables)', () => {
  const sections = parseCommand(COMMAND_FIXTURE)

  assert.equal(sections.length, 2)
  assert.equal(sections[0].title, '一、现在到哪了（读这一段就够）')
  assert.equal(sections[0].text, '**一句话**：已全部提交。')

  assert.equal(sections[0].tables.length, 1)
  const table = sections[0].tables[0]
  assert.deepEqual(table.header, ['线', '状态', '证据', '下一步'])
  assert.equal(table.rows.length, 2)
  assert.deepEqual(table.rows[0], ['后端迁移', '✅ 已提交', '`ce8b01f`', '—'])
  assert.equal(table.rows[1][1], '**阻塞**')

  // 分隔行不进 rows
  assert.ok(table.rows.every((r) => !r.every((c) => /^-+$/.test(c))))

  // 无表格章节：text 保留，tables 为空
  assert.equal(sections[1].title, '二、无表格章节')
  assert.equal(sections[1].text, '只有一句话，没有表格。')
  assert.deepEqual(sections[1].tables, [])
})

test('parseCommand: 一个章节内多张表格各自成块，CRLF 不留 \\r', () => {
  const md = [
    '## A',
    '| x | y |',
    '|---|---|',
    '| 1 | 2 |',
    '',
    '中间散文',
    '',
    '| p | q |',
    '|---|---|',
    '| 3 | 4 |',
  ].join('\r\n')

  const sections = parseCommand(md)
  assert.equal(sections.length, 1)
  assert.equal(sections[0].tables.length, 2)
  assert.deepEqual(sections[0].tables[0].rows, [['1', '2']])
  assert.deepEqual(sections[0].tables[1].header, ['p', 'q'])
  assert.ok(!sections[0].text.includes('\r'))
})

test('parseCommand: 格式漂移（无 ## 标题 / 空串）→ 空数组，不抛', () => {
  assert.deepEqual(parseCommand('随便写点东西\n没有二级标题\n'), [])
  assert.deepEqual(parseCommand(''), [])
  // 只有一级标题也算漂移：本模块只按 ## 分节
  assert.deepEqual(parseCommand('# 只有一级标题\n正文\n'), [])
})

// ── normalizePlanStatus ─────────────────────────────────────────────────

test('normalizePlanStatus: 三态混存归一，终态优先，空值 UNKNOWN', () => {
  const cases = [
    ['> **Status: APPROVED** — 2026-10-16T13:44:18.526Z', 'APPROVED'],
    ['> Status: 待审批（DRAFT）', 'DRAFT'],
    ['> Status: 待审批', 'DRAFT'],
    ['> **Status: EXECUTED（归档——方案不实施）** — 审批时间', 'EXECUTED'],
    ['> **Status: REJECTED** — 2026-10-20', 'REJECTED'],
    // 中文同义词（真实档案里出现过 `Status: 草稿`）
    ['> **Status: 草稿** · 目标屏：welcome-home', 'DRAFT'],
    // 同一行既有终态又提到旧态：终态优先
    ['> **Status: EXECUTED（归档）** — 此前为 APPROVED', 'EXECUTED'],
    ['', 'UNKNOWN'],
    ['随便一句没有状态的话', 'UNKNOWN'],
    [null, 'UNKNOWN'],
    [undefined, 'UNKNOWN'],
  ]
  for (const [raw, want] of cases) {
    assert.equal(normalizePlanStatus(raw), want, `raw=${JSON.stringify(raw)}`)
  }
})

// ── parsePlans ──────────────────────────────────────────────────────────

test('parsePlans: 取最后一个 Status 标记行；正文提到 Status: 不干扰判定', () => {
  withTempDir((dir) => {
    writeFileSync(join(dir, 'a-两行状态.md'), [
      '# A',
      '> **Status: APPROVED** — 2026-10-16',
      '',
      '正文',
      '> **Status: EXECUTED** — 2026-10-20',
      '',
    ].join('\n'))

    writeFileSync(join(dir, 'b-无状态.md'), '# B\n\n只有正文。\n')

    writeFileSync(join(dir, 'c-正文提到Status.md'), [
      '## 一、现状',
      '> Status: 待审批（DRAFT）',
      '',
      '复查表里写着：',
      '',
      '| 计划文件 | 文件 `Status:` 行 | 实际状态 |',
      '|---|---|---|',
      '| a.md | `Status:` 行与实际完成度已漂移 | 见附件 |',
      '',
    ].join('\n'))

    writeFileSync(join(dir, 'draft-未成稿.md'), '> **Status: DRAFT**\n')
    writeFileSync(join(dir, 'notes.txt'), '> **Status: APPROVED**\n')
    mkdirSync(join(dir, 'sub'))
    writeFileSync(join(dir, 'sub', 'nested.md'), '> **Status: APPROVED**\n')

    const plans = parsePlans(dir)
    const byFile = new Map(plans.map((p) => [p.file, p]))

    // 只收目录内 .md；draft- 前缀与子目录/非 md 排除
    assert.deepEqual([...byFile.keys()].sort(), [
      'a-两行状态.md', 'b-无状态.md', 'c-正文提到Status.md',
    ])

    const a = byFile.get('a-两行状态.md')
    assert.equal(a.status, 'EXECUTED')
    assert.ok(a.statusRaw.includes('EXECUTED'))
    assert.ok(a.bytes > 0)
    assert.ok(!Number.isNaN(Date.parse(a.modifiedAt)))
    assert.ok(!a.absPath.includes('\\'), `absPath 应为 posix：${a.absPath}`)

    const b = byFile.get('b-无状态.md')
    assert.equal(b.status, 'UNKNOWN')
    assert.equal(b.statusRaw, '')

    // 正文/表格里的 `Status:` 提及不是标记行，不得覆盖真实的 DRAFT
    const c = byFile.get('c-正文提到Status.md')
    assert.equal(c.status, 'DRAFT')
    assert.equal(c.statusRaw, '> Status: 待审批（DRAFT）')
  })
})

test('parsePlans: 围栏代码块里的 status: 不算标记行（真实档案踩过）', () => {
  withTempDir((dir) => {
    writeFileSync(join(dir, 'plan.md'), [
      '# 计划',
      '> **Status: DRAFT**（待审批）',
      '',
      '实现片段：',
      '',
      '```js',
      'const statusLines = body.split(/\\r?\\n/).filter((l) => /Status\\s*:/.test(l))',
      'status: normalizePlanStatus(last),',
      '```',
      '',
    ].join('\n'))

    const [plan] = parsePlans(dir)
    assert.equal(plan.status, 'DRAFT')
    assert.equal(plan.statusRaw, '> **Status: DRAFT**（待审批）')
  })
})

test('parsePlans: 目录不存在 / 传入 undefined → 空数组不抛', () => {
  assert.deepEqual(parsePlans(join(tmpdir(), 'board-data-no-such-dir-xyz')), [])
  assert.ok(Array.isArray(parsePlans(undefined)))
})

test('parsePlans: 真实 .rivet/plans 目录可解析（不存在则跳过）', (t) => {
  if (!existsSync(REAL_PLANS_DIR)) {
    t.skip('.rivet/plans 不存在（如 CI 无本地资产）')
    return
  }
  const plans = parsePlans()
  assert.ok(plans.length >= 1)
  for (const p of plans) {
    assert.equal(typeof p.file, 'string')
    assert.ok(p.file.endsWith('.md'), p.file)
    assert.ok(STATUSES.includes(p.status), `${p.file} → ${p.status}`)
    assert.equal(typeof p.statusRaw, 'string')
    assert.ok(p.bytes > 0)
  }
  // 至少有一个文件带真实状态标记（全 UNKNOWN 说明解析整体失效）
  assert.ok(plans.some((p) => p.status !== 'UNKNOWN'))
})

// ── parseGit ────────────────────────────────────────────────────────────

test('parseGit: 真实仓库返回 head/log/status（git 不可用则降级）', () => {
  const g = parseGit()

  assert.equal(typeof g.available, 'boolean')
  assert.ok(Array.isArray(g.log))
  assert.ok(Array.isArray(g.status))

  if (!g.available) {
    assert.equal(typeof g.error, 'string')
    assert.deepEqual(g.log, [])
    return
  }

  assert.match(g.head, /^[0-9a-f]{7,}$/)
  assert.ok(g.log.length >= 1 && g.log.length <= 50)
  // HEAD 提交时间用 ISO 8601（%cI）：COMMAND.md 的 mtime 也是 toISOString，两端能直接比大小
  assert.equal(typeof g.headCommittedAt, 'string')
  assert.ok(!Number.isNaN(Date.parse(g.headCommittedAt)), `headCommittedAt 不可解析：${g.headCommittedAt}`)
  const head = g.log[0]
  assert.match(head.hash, /^[0-9a-f]{4,}$/)
  assert.equal(typeof head.subject, 'string')
  // 日期格式不锁定（%ci 是 "YYYY-MM-DD HH:mm:ss +0800"，%cI 是 ISO 8601）：
  // 只要求是可直接喂给 Date 的日期串，前端不必为格式分支。
  assert.match(head.date, /^\d{4}-\d{2}-\d{2}[ T]/)
  assert.ok(!Number.isNaN(Date.parse(head.date)), `date 不可解析：${head.date}`)

  for (const change of g.status) {
    assert.equal(change.code.length, 2)
    assert.ok(!change.path.includes('\\'), `path 应为 posix：${change.path}`)
    assert.equal(change.forbidden, /(?:^|\/)build-profile\.json5$/.test(change.path))
  }
})

// ── collectBoardData ────────────────────────────────────────────────────

test('collectBoardData: 返回 {generatedAt, command, plans, git}', () => {
  const data = collectBoardData()

  assert.ok(!Number.isNaN(Date.parse(data.generatedAt)))
  assert.equal(typeof data.command.path, 'string')
  assert.ok(!data.command.path.includes('\\'), `command.path 应为 posix：${data.command.path}`)
  assert.ok(Array.isArray(data.command.sections))
  assert.ok(Array.isArray(data.plans))
  assert.equal(typeof data.git.available, 'boolean')
  assert.equal(typeof data.git.head, 'string')

  if (existsSync(resolve(REPO_ROOT, '.rivet', 'COMMAND.md'))) {
    // 真实 COMMAND.md 至少解析出「各线状态」这类章节
    assert.ok(data.command.sections.length >= 1)
    assert.ok(data.command.sections.some((s) => s.tables.length > 0))
  }
})

test('collectBoardData: 数据源缺失 → 降级返回，绝不抛', () => {
  withTempDir((dir) => {
    const cmdPath = join(dir, 'COMMAND.md')
    const plansDir = join(dir, 'plans')
    mkdirSync(plansDir)
    writeFileSync(cmdPath, COMMAND_FIXTURE)
    writeFileSync(join(plansDir, 'x.md'), '> **Status: APPROVED**\n')

    // 正常路径（路径可注入，便于在任意环境验证）
    const ok = collectBoardData({ commandPath: cmdPath, plansDir })
    assert.equal(ok.command.sections.length, 2)
    assert.equal(ok.plans.length, 1)
    assert.equal(ok.plans[0].status, 'APPROVED')
    assert.equal(ok.command.error, undefined)

    // 两个数据源都不存在：COMMAND.md 读失败只降级，plans 空，入口仍返回对象
    let missing
    assert.doesNotThrow(() => {
      missing = collectBoardData({
        commandPath: join(dir, 'missing.md'),
        plansDir: join(dir, 'missing-plans'),
      })
    })
    assert.deepEqual(missing.command.sections, [])
    assert.equal(typeof missing.command.error, 'string')
    assert.deepEqual(missing.plans, [])
    assert.equal(typeof missing.git.available, 'boolean')
  })
})

// ── computeDrift：状态源 vs git 真值 ────────────────────────────────────

const COMMAND_WITH_CLAIM = [
  '## 一、现在到哪了（读这一段就够）',
  '',
  '| 线 | 状态 |',
  '|---|---|',
  '| 后端迁移 | ✅ 已提交 |',
  '',
  '## 二、工作区未提交改动（2026-11-01 实测，共 2 项）',
  '',
  '| 文件 | 说明 |',
  '|---|---|',
  '| a | b |',
  '',
].join('\n')

const gitFixture = (over) => ({
  available: true,
  head: 'abc1234',
  headCommittedAt: '2026-11-01T15:18:38+08:00',
  log: [],
  status: [],
  ...over,
})

const changes = (paths) => paths.map((p) => ({ code: '??', path: p, forbidden: false }))

test('claimUncommittedCount: 只认带项数的「未提交」自述行', () => {
  assert.equal(claimUncommittedCount(COMMAND_WITH_CLAIM), 2)
  // 表格里「工作区无未提交残留」这种半句话没有项数，不得当自述
  assert.equal(claimUncommittedCount('| 后端 | ✅ 已提交 | 工作区无未提交残留 | — |'), null)
  assert.equal(claimUncommittedCount('没有这一句'), null)
  assert.equal(claimUncommittedCount(''), null)
  assert.equal(claimUncommittedCount(null), null)
})

test('computeDrift: 总账记 2 项、git status 实测 4 项 → stale，双方读数都给出', () => {
  const drift = computeDrift(
    { raw: COMMAND_WITH_CLAIM, updatedAt: '2026-11-01T20:00:00.000Z', sections: [] },
    gitFixture({ status: changes(['a', 'b', 'c', 'd']) })
  )

  assert.equal(drift.stale, true)
  assert.equal(drift.claimedUncommitted, 2)
  assert.equal(drift.actualUncommitted, 4)
  assert.ok(drift.reasons.some((r) => r.includes('2 项') && r.includes('4 项')), drift.reasons.join('|'))
  // 状态源比 HEAD 新：时间维度不得参与报警
  assert.ok(!drift.reasons.some((r) => r.includes('早于 HEAD 提交')), drift.reasons.join('|'))
})

test('computeDrift: 状态源早于 HEAD 提交 → stale；项数与时间都不落后 → 不报', () => {
  const stale = computeDrift(
    { raw: COMMAND_WITH_CLAIM, updatedAt: '2026-10-30T10:00:00.000Z' },
    gitFixture({ status: changes(['a', 'b']) })
  )
  assert.equal(stale.stale, true)
  assert.ok(stale.reasons.some((r) => r.includes('早于 HEAD 提交')), stale.reasons.join('|'))

  const clean = computeDrift(
    { raw: COMMAND_WITH_CLAIM, updatedAt: '2026-11-02T10:00:00.000Z' },
    gitFixture({ status: changes(['a', 'b']) })
  )
  assert.equal(clean.stale, false)
  assert.deepEqual(clean.reasons, [])
})

test('computeDrift: git 不可用 / 无读数 → 不判定（不假警报）', () => {
  const unavailable = computeDrift(
    { raw: COMMAND_WITH_CLAIM, updatedAt: '2026-10-30T10:00:00.000Z' },
    { available: false, head: '', log: [], status: [], error: 'no git' }
  )
  assert.equal(unavailable.stale, false)
  assert.deepEqual(unavailable.reasons, [])

  // 无「未提交」自述且无时间读数：同样不猜
  const blind = computeDrift({ raw: '' }, gitFixture({ status: changes(['a']) }))
  assert.equal(blind.stale, false)
  assert.equal(blind.claimedUncommitted, null)
  assert.equal(blind.actualUncommitted, 1)

  // 入参缺失也不抛
  assert.doesNotThrow(() => computeDrift(undefined, undefined))
})

// ── parsePlanGoals / countCheckboxes ────────────────────────────────────
//
// 提取契约（只支持已观测到的变体集合，未命中即空；格式再漂不追求穷举）：
//   ① `**目标**：散文`        → 冒号后非空散文直接作为一条 goal
//   ② `**目标（用户原话）**：` → 空标题，后续编号列表每项一条
//   ③ `**目标**：` + `- ` 列表 / 散文段落 → 每项一条，散文段合并成一条
//   ④ `**目标**` 无冒号       → 内容在下一行，同上
//   终止：`**非目标**` 标记行 / 下一个纯 `**标签**` 行 / `#` 标题。
//   散文里的 `**加粗词**` 不终止（整行不是纯标签行就不算标记）。

function readRealPlan (name) {
  const abs = join(REAL_PLANS_DIR, name)
  return existsSync(abs) ? readFileSync(abs, 'utf8') : null
}

test('parsePlanGoals: 散文型真实样本（`**目标**：散文`）→ 一条 goal，非目标不混入', (t) => {
  const body = readRealPlan('训练页收起语义与接续态.md')
  if (body === null) return t.skip('真实样本缺失：训练页收起语义与接续态.md')

  const goals = parsePlanGoals(body)
  assert.equal(goals.length, 1)
  assert.ok(goals[0].startsWith('确定训练页左上角 chevron 按钮'), goals[0])
  assert.ok(goals[0].includes('再次进入时看到什么'))
  assert.ok(!goals[0].includes('**'), `应去掉加粗标记：${goals[0]}`)
  // `**非目标**` 之后的条目不得混入
  assert.ok(!goals[0].includes('不改训练记录主链路'))
  assert.ok(!goals[0].includes('不改 chevron 的图形与配色'))
})

test('parsePlanGoals: 列表型真实样本（`**目标（用户原话）**：` + 编号列表）→ 逐条 goal', (t) => {
  const body = readRealPlan('数据一致性收口-训练动作与完成进度统一口径-双端.md')
  if (body === null) return t.skip('真实样本缺失：数据一致性收口-训练动作与完成进度统一口径-双端.md')

  const goals = parsePlanGoals(body)
  assert.equal(goals.length, 3, JSON.stringify(goals))
  assert.ok(goals[0].startsWith('今日计划的动作和预览页'), goals[0])
  assert.ok(goals[1].includes('统一口径'), goals[1])
  assert.ok(goals[2].includes('顺带扫清双端派生'), goals[2])
  for (const g of goals) assert.ok(!g.includes('**'), `应去掉加粗标记：${g}`)
  for (const g of goals) assert.ok(!g.includes('不改训练数据落库格式'), `非目标混入：${g}`)
})

test('parsePlanGoals: `**目标**：` 空标题后跟列表与散文段（含加粗词不提前截断）', () => {
  const md = [
    '# P',
    '',
    '## 需求提炼',
    '',
    '**目标**：',
    '- 第一件事 `a`',
    '- 第二件事',
    '',
    '一段散文，含 **加粗强调** 与 `code`。',
    '',
    '**非目标**：',
    '- 不做的事',
    '',
    '## 回归清单',
    '**目标**：不该被读到',
    ''
  ].join('\n')

  assert.deepEqual(parsePlanGoals(md), [
    '第一件事 `a`',
    '第二件事',
    '一段散文，含 加粗强调 与 `code`。'
  ])
})

test('parsePlanGoals: `**目标**` 无冒号 / 冒号后直接散文两种写法都取到内容', () => {
  const noColon = ['## 需求提炼', '**目标** 把 A 做完。', '**非目标**', '- 别的事'].join('\n')
  assert.deepEqual(parsePlanGoals(noColon), ['把 A 做完。'])

  const nextLine = [
    '## 需求提炼',
    '**目标**',
    '把 B 做完。',
    '',
    '## 下一节',
    '**目标**',
    '不应读到'
  ].join('\n')
  assert.deepEqual(parsePlanGoals(nextLine), ['把 B 做完。'])
})

test('parsePlanGoals: 无「## 需求提炼」章节 / 空串 / 非字符串 → 空数组，不抛', () => {
  assert.deepEqual(parsePlanGoals('# 标题\n**目标**：散落在章节外\n'), [])
  assert.deepEqual(parsePlanGoals(''), [])
  assert.deepEqual(parsePlanGoals(null), [])
  assert.deepEqual(parsePlanGoals(undefined), [])
})

test('countCheckboxes: 统计 `- [x]` / `- [ ]`，已勾选与总数分开', () => {
  const md = [
    '- [x] 已做',
    '- [ ] 未做',
    '- [X] 大写也算已做',
    '  - [ ] 缩进列表也算',
    '- 普通列表项',
    '* [ ] 星号列表',
    '表格 | [x] | 不算',
    '[x] 无列表前缀不算'
  ].join('\n')

  assert.deepEqual(countCheckboxes(md), { done: 2, total: 5 })
  assert.deepEqual(countCheckboxes(''), { done: 0, total: 0 })
})

test('parsePlans: 每条计划挂 goals / goalText / tasksDone / tasksTotal', () => {
  withTempDir((dir) => {
    writeFileSync(join(dir, 'plan.md'), [
      '# 计划',
      '> **Status: APPROVED**',
      '',
      '## 需求提炼',
      '',
      '**目标**：把两处口径统一。',
      '',
      '**非目标**：',
      '- 不改库',
      '',
      '## 回归清单',
      '- [x] 用例 A',
      '- [ ] 用例 B',
      '- [x] 用例 C',
      ''
    ].join('\n'))

    const [plan] = parsePlans(dir)
    assert.deepEqual(plan.goals, ['把两处口径统一。'])
    assert.equal(plan.goalText, '把两处口径统一。')
    assert.equal(plan.tasksDone, 2)
    assert.equal(plan.tasksTotal, 3)

    // 无「需求提炼」章节：空集而不是抛错
    writeFileSync(join(dir, 'plain.md'), '# 无需求提炼\n\n只有正文。\n')
    const plain = parsePlans(dir).find((p) => p.file === 'plain.md')
    assert.deepEqual(plain.goals, [])
    assert.equal(plain.goalText, '')
    assert.equal(plain.tasksDone, 0)
    assert.equal(plain.tasksTotal, 0)
  })
})

test('parsePlanGoals: 真实语料里另外三种写法（列表符前缀 / 括注在加粗后 / 无加粗）', () => {
  // `- **目标**：…` + `- **非目标**：…`（android-端-点击计划-tab…md 的实际写法）
  const bullet = [
    '## 需求提炼',
    '- **用户原话**：「点击计划tab跳转到回顾页了」',
    '- **目标**：锁定根因并修复。',
    '- **非目标**：不改底栏视觉/文案。'
  ].join('\n')
  assert.deepEqual(parsePlanGoals(bullet), ['锁定根因并修复。'])

  // `**目标**（可验收）：`：括注在关闭加粗之后
  const parenAfterBold = ['## 需求提炼', '**目标**（可验收）：', '- 口径 A', '- 口径 B', ''].join('\n')
  assert.deepEqual(parsePlanGoals(parenAfterBold), ['口径 A', '口径 B'])

  // `> 目标：散文`：无加粗 + 引用前缀
  const plain = ['## 需求提炼', '> 目标：把 #gallery 换成滚动展示。', ''].join('\n')
  assert.deepEqual(parsePlanGoals(plain), ['把 #gallery 换成滚动展示。'])

  // 「目标平台」这类不是目标标记行
  const notMarker = ['## 需求提炼', '> **目标平台**：鸿蒙 + 安卓', ''].join('\n')
  assert.deepEqual(parsePlanGoals(notMarker), [])
})
