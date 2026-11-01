// check-snapshot-mirror-sql.test.mjs —— 离线 SQL↔Kotlin 契约校验（node:test，零依赖）
//
// 背景：快照镜像迁移（server/supabase/migrations/20261101000001_snapshot_mirror.sql）
// 把 payload jsonb 拆成关系镜像。CI 没有 postgres，无法做 psql 语法自检——本测试用
// 正则静态断言替代，把「as 列名 = Kotlin @Serializable JSON 键名」「security definer」
// 「RLS select-only」「snapshots 零改动」等契约变成可复现的红绿。
//
// 锚定模型（JSON 键名 camelCase，逐字段来自 Kotlin data class）：
//   WorkoutSession → apps/android/.../data/model/TrainingModels.kt:130-146
//   WorkoutSet     → TrainingModels.kt:115-124
//   UserGoal       → TrainingModels.kt（goalId/goalType/level/…）
//   UserPlan       → apps/android/.../data/model/PlanModels.kt:47-55
//   WeightRecord   → BodyRecord.kt（dateMillis/kg）
//   BodyMeasurement→ BodyRecord.kt（dateMillis + 8 测量列）
//   seed 列常量    → apps/harmony/tools/content/export-db-seed.mjs（EXERCISE_COLUMNS 等）

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const mirrorSql = readFileSync(
  resolve(root, 'server/supabase/migrations/20261101000001_snapshot_mirror.sql'),
  'utf8'
)
const contentSql = readFileSync(
  resolve(root, 'server/supabase/migrations/20261101000000_content_library.sql'),
  'utf8'
)
const seedMjs = readFileSync(
  resolve(root, 'apps/harmony/tools/content/export-db-seed.mjs'),
  'utf8'
)

/** 期望的 as(...) 列名集合（= Kotlin @Serializable 输出 JSON 的键名）。 */
const EXPECTED_AS_SETS = [
  ['setId', 'exerciseId', 'weight', 'reps', 'rpe', 'isWarmup'], // WorkoutSet
  ['sessionId', 'planId', 'dayId', 'startedAt', 'endedAt', 'durationSeconds',
    'totalSets', 'totalVolume', 'fatigueScore', 'sessionRpe', 'notes', 'sets'], // WorkoutSession
  ['id', 'name', 'coverColor', 'targetAudience', 'weeklyFrequency',
    'description', 'days', 'enabledAt'], // UserPlan
  ['goalId', 'goalType', 'level', 'weeklyDays', 'sessionMinutes',
    'equipmentIds', 'restrictedMuscleIds', 'createdAt', 'updatedAt'], // UserGoal
  ['dateMillis', 'kg'], // WeightRecord
  ['dateMillis', 'chestCm', 'waistCm', 'hipCm', 'armCm', 'thighCm',
    'bodyFatPercent', 'skeletalMuscleKg', 'bodyWaterPercent'], // BodyMeasurement
]

/** 抽取 SQL 中每个 `as x(...)` 块的引号标识符集合（按标签归组，同标签多块取并集）。 */
function extractAsColumns(sqlText) {
  const groups = new Map()
  const re = /as\s+([a-z])\s*\(([^)]*)\)/g
  for (const match of sqlText.matchAll(re)) {
    const label = match[1]
    const body = match[2]
    const names = []
    // 列名 = 「标识符（可带引号）+ 空白 + 类型」模式——带引号 camelCase 与无引号
    // 小写列名（level/notes/sets/weight/reps/kg/…）都要收，类型词不误收。
    for (const nameMatch of body.matchAll(/"?([A-Za-z][A-Za-z0-9]*)"?\s+(?:text|integer|bigint|double\s+precision|boolean|jsonb)\b/g)) {
      names.push(nameMatch[1])
    }
    if (!groups.has(label)) {
      groups.set(label, new Set())
    }
    for (const name of names) {
      groups.get(label).add(name)
    }
  }
  return groups
}

/** 从 `const XXX = [ ... ]` 抽取字符串数组。 */
function extractStringArray(source, constName) {
  const re = new RegExp(
    `const\\s+${constName}\\s*=\\s*\\[([\\s\\S]*?)\\]`
  )
  const match = source.match(re)
  assert.ok(match, `${constName} 常量未找到`)
  const values = []
  for (const valueMatch of match[1].matchAll(/'([^']*)'/g)) {
    values.push(valueMatch[1])
  }
  return values
}

/** 从 `create table if not exists public.<name> (...)` 抽取列名（按出现顺序）。 */
function extractCreateTableColumns(sqlText, tableName) {
  const re = new RegExp(
    `create\\s+table\\s+if\\s+not\\s+exists\\s+public\\.${tableName}\\s*\\(([\\s\\S]*?)\\n\\);`
  )
  const match = sqlText.match(re)
  assert.ok(match, `public.${tableName} 的 CREATE TABLE 未找到`)
  const columns = []
  for (const line of match[1].split(/\n/)) {
    const colMatch = line.match(/^\s{2}([a-z_][a-z0-9_]*)\s+/)
    if (colMatch) {
      columns.push(colMatch[1])
    }
  }
  return columns
}

test('jsonb 拆分的 as 列名与 Kotlin 模型 JSON 键名一致（按类配对，并集覆盖）', () => {
  const groups = extractAsColumns(mirrorSql)
  for (const expected of EXPECTED_AS_SETS) {
    const found = Array.from(groups.values()).some(
      (set) => set.size === expected.length && expected.every((n) => set.has(n))
    )
    assert.ok(
      found,
      `未找到与期望键集完全匹配的 as(...) 块：${expected.join(', ')}。` +
      `实际块：${Array.from(groups.values()).map((s) => Array.from(s).join(',')).join(' | ')}`
    )
  }
})

test('触发器函数声明 security definer 且固定 search_path', () => {
  assert.match(mirrorSql, /create or replace function public\.rebuild_snapshot_mirror\(\)[\s\S]*?security definer/)
  assert.match(mirrorSql, /set search_path\s*=\s*pg_catalog,\s*public/)
})

test('触发器函数对 public 显式 revoke（最小化提权面）', () => {
  assert.match(mirrorSql, /revoke all on function public\.rebuild_snapshot_mirror\(\) from public/)
})

test('7 张镜像表均 enable row level security 且仅有 select 策略', () => {
  const tables = [
    'snapshot_goals', 'snapshot_plans', 'snapshot_sessions', 'snapshot_sets',
    'snapshot_body_records', 'snapshot_body_measurements', 'snapshot_meta',
  ]
  for (const table of tables) {
    assert.ok(
      new RegExp(`alter\\s+table\\s+public\\.${table}\\s+enable\\s+row\\s+level\\s+security`).test(mirrorSql),
      `${table} 缺 enable row level security`
    )
    assert.ok(
      mirrorSql.includes(`create policy "${table}_select_own"`),
      `${table} 缺 select 策略`
    )
  }
})

test('snapshots 真源零改动：无 alter/drop policy 作用于 public.snapshots', () => {
  assert.ok(!/alter\s+table\s+public\.snapshots/.test(mirrorSql), '不得 alter snapshots 表')
  assert.ok(
    !/drop\s+policy[^;]*on\s+public\.snapshots\b/.test(mirrorSql),
    '不得动 snapshots 的既有策略'
  )
})

test('镜像表无客户端写策略（不建 insert/update/delete）', () => {
  const tables = [
    'snapshot_goals', 'snapshot_plans', 'snapshot_sessions', 'snapshot_sets',
    'snapshot_body_records', 'snapshot_body_measurements', 'snapshot_meta',
  ]
  for (const table of tables) {
    assert.ok(
      !new RegExp(`for\\s+(insert|update|delete)[\\s\\S]{0,120}?${table}`).test(mirrorSql),
      `${table} 不应有客户端写策略`
    )
  }
})

test('存量回填语句存在（update public.snapshots 触发重建）', () => {
  assert.match(mirrorSql, /update public\.snapshots set updated_at = updated_at/)
})

test('content_library.sql 的 exercises 列集 === export-db-seed.mjs 的 EXERCISE_COLUMNS（跨文件一致）', () => {
  const sqlColumns = extractCreateTableColumns(contentSql, 'exercises')
  const mjsColumns = extractStringArray(seedMjs, 'EXERCISE_COLUMNS')
  assert.deepEqual(sqlColumns, mjsColumns)
})

test('content_library.sql 的 muscles/equipment 列集与 seed 常量一致（含 name_en 增量）', () => {
  assert.deepEqual(
    extractCreateTableColumns(contentSql, 'muscles'),
    extractStringArray(seedMjs, 'MUSCLE_COLUMNS')
  )
  assert.deepEqual(
    extractCreateTableColumns(contentSql, 'equipment'),
    extractStringArray(seedMjs, 'EQUIPMENT_COLUMNS')
  )
})

test('内容库三表只建公开读策略、无客户端写策略', () => {
  for (const table of ['exercises', 'muscles', 'equipment']) {
    assert.ok(
      contentSql.includes(`create policy "${table}_public_read"`),
      `${table} 缺公开读策略`
    )
    assert.ok(
      !new RegExp(`for\\s+(insert|update|delete)[\\s\\S]{0,120}?public\\.${table}`).test(contentSql),
      `${table} 不应有客户端写策略`
    )
  }
})
