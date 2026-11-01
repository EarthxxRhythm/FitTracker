/**
 * export-db-seed 的契约测试。
 *
 * 目标：锁住「seed DDL 与设备端 RDB 结构对齐」这条口径，防止再次漂移回 7 张窄表。
 * 判据（对应工单验收）：
 *   ① seed 仅含 3 张 CREATE TABLE（exercises / muscles / equipment）
 *   ② exercises 列名与 ContentDatabaseService.ets 建表语句逐列一致（顺序敏感）
 *   ③ muscles / equipment 列名 = RDB 列 + name_en 增量（不是全集相等）
 *   ④ INSERT 计数 = 对应 jsonl 行数
 *   ⑤ muscles / equipment 的 name_en 非空
 *   ⑥ build 校验失败时不产出 seed
 */
import test from 'node:test'
import assert from 'node:assert/strict'
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

import {
  EQUIPMENT_COLUMNS,
  EXERCISE_COLUMNS,
  MUSCLE_COLUMNS,
  androidAssetPath,
  contentDir,
  exportDbSeed,
  outputPath,
  readJsonl,
  renderSeedSql
} from './export-db-seed.mjs'
import { loadPreservedNameEn } from '../../../../tools/sync-content-to-android.mjs'

const here = dirname(fileURLToPath(import.meta.url))
/** 设备端真源：三张宽表的建表语句所在文件。 */
const CONTENT_DB_SERVICE = resolve(
  here,
  '../../entry/src/main/ets/shared/services/ContentDatabaseService.ets'
)

const rdbSourceText = readFileSync(CONTENT_DB_SERVICE, 'utf8')
const muscles = readJsonl(contentDir, 'muscles.zh-CN.jsonl')
const equipment = readJsonl(contentDir, 'equipment.zh-CN.jsonl')
const exercises = readJsonl(contentDir, 'exercises.zh-CN.jsonl')
const preserved = loadPreservedNameEn(androidAssetPath)
const seedText = renderSeedSql({ muscles, equipment, exercises, preserved }).join('\n')

/** 从 DDL 文本里取某表的列名数组（按出现顺序）。 */
function parseCreateTableColumns(text, table) {
  const pattern = new RegExp(`CREATE TABLE IF NOT EXISTS ${table} \\(([^)]*)\\)`)
  const match = text.match(pattern)
  assert.ok(match, `missing CREATE TABLE for ${table}`)
  return match[1]
    .split(',')
    .map((definition) => definition.trim())
    .filter((definition) => definition.length > 0)
    .map((definition) => definition.split(/\s+/)[0])
}

/** 按顶层逗号切分 SQL 值列表，正确处理单引号字符串与 '' 转义。 */
function splitSqlValues(text) {
  const values = []
  let current = ''
  let inString = false
  for (let index = 0; index < text.length; index++) {
    const char = text[index]
    if (inString) {
      current += char
      if (char === "'") {
        if (text[index + 1] === "'") {
          current += text[index + 1]
          index++
        } else {
          inString = false
        }
      }
      continue
    }
    if (char === "'") {
      inString = true
      current += char
      continue
    }
    if (char === ',') {
      values.push(current.trim())
      current = ''
      continue
    }
    current += char
  }
  if (current.trim().length > 0) {
    values.push(current.trim())
  }
  return values
}

/** 解析某表的全部 INSERT，返回 { columns, rows }。 */
function parseInsertRows(text, table) {
  const pattern = new RegExp(`INSERT INTO ${table} \\(([^)]*)\\) VALUES \\((.*)\\);$`, 'gm')
  const rows = []
  let columns = []
  let match = pattern.exec(text)
  while (match !== null) {
    columns = match[1].split(',').map((column) => column.trim())
    rows.push(splitSqlValues(match[2]))
    match = pattern.exec(text)
  }
  return { columns, rows }
}

test('① seed 仅含 3 张 CREATE TABLE，且是宽表集合', () => {
  const tables = [...seedText.matchAll(/CREATE TABLE IF NOT EXISTS (\w+)/g)].map((match) => match[1])
  assert.deepEqual(tables, ['exercises', 'muscles', 'equipment'])
  // 旧实现的 7 窄表必须彻底消失。
  for (const legacy of [
    'exercise_muscles',
    'exercise_equipment',
    'exercise_alternatives',
    'exercise_media'
  ]) {
    assert.equal(seedText.includes(`INSERT INTO ${legacy} `), false, `${legacy} should be gone`)
  }
})

test('② exercises 列名与 ContentDatabaseService.ets 建表语句逐列一致', () => {
  const rdbColumns = parseCreateTableColumns(rdbSourceText, 'exercises')
  const seedColumns = parseCreateTableColumns(seedText, 'exercises')
  assert.ok(rdbColumns.length >= 20, 'sanity: RDB exercises table must have the wide column set')
  assert.deepEqual(seedColumns, rdbColumns)
  assert.deepEqual(seedColumns, EXERCISE_COLUMNS)
})

test('③ muscles / equipment 列名 = RDB 列 + name_en 增量（非全集相等）', () => {
  const cases = [
    { table: 'muscles', columns: MUSCLE_COLUMNS },
    { table: 'equipment', columns: EQUIPMENT_COLUMNS }
  ]
  for (const item of cases) {
    const rdbColumns = parseCreateTableColumns(rdbSourceText, item.table)
    const seedColumns = parseCreateTableColumns(seedText, item.table)
    assert.deepEqual(seedColumns, [...rdbColumns, 'name_en'], `${item.table} 应为 RDB 列 + name_en`)
    assert.deepEqual(seedColumns, item.columns)
    // 明确排除「与 RDB 全集相等」这一误读。
    assert.notDeepEqual(seedColumns, rdbColumns)
    assert.equal(seedColumns.length, rdbColumns.length + 1)
  }
})

test('④ INSERT 计数 = 对应 jsonl 行数', () => {
  assert.equal(parseInsertRows(seedText, 'exercises').rows.length, exercises.length)
  assert.equal(parseInsertRows(seedText, 'muscles').rows.length, muscles.length)
  assert.equal(parseInsertRows(seedText, 'equipment').rows.length, equipment.length)
  // 内容源规模锚点（漂移时先看这里是不是内容本身变了）。
  assert.equal(exercises.length, 102)
  assert.equal(muscles.length, 6)
  assert.equal(equipment.length, 7)
})

test('⑤ muscles / equipment 的 name_en 全部非空且非 NULL', () => {
  for (const table of ['muscles', 'equipment']) {
    const { columns, rows } = parseInsertRows(seedText, table)
    const index = columns.indexOf('name_en')
    assert.ok(index >= 0, `${table} 缺少 name_en 列`)
    assert.equal(rows.length > 0, true)
    for (const row of rows) {
      assert.equal(row.length, columns.length, `${table} 行列数与列名不符`)
      const value = row[index]
      assert.notEqual(value, 'NULL', `${table} name_en 不应为 NULL`)
      assert.match(value, /^'.+'$/, `${table} name_en 不应为空串：${value}`)
    }
  }
})

test('⑥ build 校验失败时不产出 seed', () => {
  const workDir = mkdtempSync(join(tmpdir(), 'fittracker-seed-'))
  try {
    const failScript = join(workDir, 'fail-build.mjs')
    writeFileSync(failScript, 'process.exit(1)\n', 'utf8')
    const target = join(workDir, 'out', 'seed.sql')
    assert.throws(
      () => exportDbSeed({ buildScriptPath: failScript, outputPath: target }),
      /content build validation failed/
    )
    assert.equal(existsSync(target), false, '校验失败时不应写出 seed 文件')
  } finally {
    rmSync(workDir, { recursive: true, force: true })
  }
})

test('⑦ 成功路径写盘：三表齐全且行数与 jsonl 一致', () => {
  const workDir = mkdtempSync(join(tmpdir(), 'fittracker-seed-ok-'))
  try {
    const target = join(workDir, 'seed.sql')
    const result = exportDbSeed({ outputPath: target })
    assert.equal(result.outputPath, target)
    assert.equal(result.counts.exercises, exercises.length)
    assert.equal(result.counts.muscles, muscles.length)
    assert.equal(result.counts.equipment, equipment.length)
    const written = readFileSync(target, 'utf8')
    assert.equal([...written.matchAll(/CREATE TABLE IF NOT EXISTS (\w+)/g)].length, 3)
    assert.equal(parseInsertRows(written, 'exercises').rows.length, exercises.length)
  } finally {
    rmSync(workDir, { recursive: true, force: true })
  }
})

test('⑧ 默认输出路径不变', () => {
  assert.match(outputPath.replace(/\\/g, '/'), /apps\/harmony\/build\/content\/fittracker-content-seed\.sql$/)
})
