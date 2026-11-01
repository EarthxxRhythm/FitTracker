#!/usr/bin/env node
/**
 * export-db-seed.mjs —— 把鸿蒙端动作库内容（`content/exercises/*.jsonl`）导出为
 * 自托管 Supabase 可直接执行的 seed SQL（`build/content/fittracker-content-seed.sql`）。
 *
 * ## 表结构口径（与设备端 RDB 对齐）
 *
 * 设备端真源是 `apps/harmony/entry/src/main/ets/shared/services/ContentDatabaseService.ets`
 * 的三张宽表（`muscles` / `equipment` / `exercises`）。旧版本此处导出 7 张窄表
 * （exercise_muscles / exercise_equipment / exercise_alternatives / exercise_media），
 * 与设备端实现漂移，已废弃——多值字段一律内嵌为 `*_json` 列。
 *
 * 逐列口径：
 *   - `exercises`：与 ContentDatabaseService.ets 的建表语句**逐列一致**（列名、顺序、类型）。
 *   - `muscles`：RDB 结构（muscle_id / name_zh / region）+ `name_en TEXT NOT NULL DEFAULT ''`。
 *   - `equipment`：RDB 结构（equipment_id / name_zh / category）+ `name_en TEXT NOT NULL DEFAULT ''`。
 *
 * ## 为什么 muscles/equipment 多一列 name_en
 *
 * 鸿蒙 RDB 没有 name_en（`TrainingModels.ets` 模型无该字段），但 Android 资产
 * `apps/android/app/src/main/assets/exercise-content.json` 有——云端按信息最全口径建表，
 * 不为鸿蒙侧的已知缺列而省掉。这是**刻意保留的双端差异**，不是漂移。
 * `nameEn` 取值复用 `tools/sync-content-to-android.mjs` 已有的「保留 → 回退表」两级解析，
 * 保证云端、Android、鸿蒙三处同一 id 的英文名一致。
 *
 * ## 用法（从仓库根或 apps/harmony 执行均可）
 *
 *   node apps/harmony/tools/content/export-db-seed.mjs
 *
 * 导出前先跑 `build-content.mjs` 做内容校验（字段完整性、引用完整性、覆盖率）；
 * 校验失败即中止，不产出 seed 文件。
 */
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { spawnSync } from 'node:child_process'

// 复用 Android 同步脚本已导出的英文名解析素材（同一份口径，不重复维护常量）。
import { NAME_EN_FALLBACK, loadPreservedNameEn } from '../../../../tools/sync-content-to-android.mjs'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..')
const repoRoot = resolve(root, '../..')
const contentDir = resolve(root, 'content/exercises')
const outputPath = resolve(root, 'build/content/fittracker-content-seed.sql')
const buildScriptPath = resolve(root, 'tools/content/build-content.mjs')
const androidAssetPath = resolve(repoRoot, 'apps/android/app/src/main/assets/exercise-content.json')

/** `exercises` 列集：与 ContentDatabaseService.ets 的建表语句逐列、逐序一致。 */
const EXERCISE_COLUMNS = [
  'exercise_id',
  'name_zh',
  'name_en',
  'aliases_json',
  'primary_muscle_ids_json',
  'secondary_muscle_ids_json',
  'equipment_ids_json',
  'difficulty',
  'goal_tags_json',
  'video_url',
  'cover_url',
  'cover_source_label',
  'video_source_label',
  'media_license_text',
  'steps_json',
  'cues_json',
  'common_mistakes_json',
  'safety_notes_json',
  'alternative_exercise_ids_json',
  'content_version'
]

/** `muscles` 列集：RDB 结构 + name_en 增量。 */
const MUSCLE_COLUMNS = ['muscle_id', 'name_zh', 'region', 'name_en']

/** `equipment` 列集：RDB 结构 + name_en 增量。 */
const EQUIPMENT_COLUMNS = ['equipment_id', 'name_zh', 'category', 'name_en']

/**
 * 三张宽表的 DDL。`exercises` 的列定义逐字对齐 ContentDatabaseService.ets:212
 * （含 `TEXT NOT NULL DEFAULT ''` 三列与 `content_version INTEGER NOT NULL`）。
 */
const SCHEMA_STATEMENTS = [
  "CREATE TABLE IF NOT EXISTS exercises (exercise_id TEXT PRIMARY KEY, name_zh TEXT NOT NULL, name_en TEXT NOT NULL, aliases_json TEXT NOT NULL, primary_muscle_ids_json TEXT NOT NULL, secondary_muscle_ids_json TEXT NOT NULL, equipment_ids_json TEXT NOT NULL, difficulty TEXT NOT NULL, goal_tags_json TEXT NOT NULL, video_url TEXT NOT NULL, cover_url TEXT NOT NULL, cover_source_label TEXT NOT NULL DEFAULT '', video_source_label TEXT NOT NULL DEFAULT '', media_license_text TEXT NOT NULL DEFAULT '', steps_json TEXT NOT NULL, cues_json TEXT NOT NULL, common_mistakes_json TEXT NOT NULL, safety_notes_json TEXT NOT NULL, alternative_exercise_ids_json TEXT NOT NULL, content_version INTEGER NOT NULL);",
  "CREATE TABLE IF NOT EXISTS muscles (muscle_id TEXT PRIMARY KEY, name_zh TEXT NOT NULL, region TEXT NOT NULL, name_en TEXT NOT NULL DEFAULT '');",
  "CREATE TABLE IF NOT EXISTS equipment (equipment_id TEXT PRIMARY KEY, name_zh TEXT NOT NULL, category TEXT, name_en TEXT NOT NULL DEFAULT '');"
]

export {
  EXERCISE_COLUMNS,
  MUSCLE_COLUMNS,
  EQUIPMENT_COLUMNS,
  SCHEMA_STATEMENTS,
  androidAssetPath,
  buildScriptPath,
  contentDir,
  exportDbSeed,
  outputPath,
  readJsonl,
  renderSchema,
  renderSeedSql,
  runBuildValidation
}

function runBuildValidation(scriptPath = buildScriptPath) {
  const result = spawnSync(process.execPath, [scriptPath], {
    cwd: root,
    stdio: 'inherit'
  })
  if (result.status !== 0) {
    throw new Error('content build validation failed; database seed was not exported')
  }
}

function readJsonl(dir, fileName) {
  const path = resolve(dir, fileName)
  const text = readFileSync(path, 'utf8')
  const rows = []
  const lines = text.split(/\r?\n/)
  for (let index = 0; index < lines.length; index++) {
    const line = lines[index].trim()
    if (line.length === 0) {
      continue
    }
    rows.push(JSON.parse(line))
  }
  return rows
}

function sql(value) {
  if (value === null || value === undefined) {
    return 'NULL'
  }
  if (typeof value === 'number') {
    return String(value)
  }
  return `'${String(value).replace(/'/g, "''")}'`
}

function jsonSql(value) {
  return sql(JSON.stringify(value || []))
}

/** values 已是 SQL 字面量（由 sql()/jsonSql() 渲染），此处只做拼接。 */
function insert(table, fields, renderedValues) {
  return `INSERT INTO ${table} (${fields.join(', ')}) VALUES (${renderedValues.join(', ')});`
}

/**
 * 解析 id 的英文名：优先沿用 Android 现有资产（信息最全），其次回退表。
 * 两级都缺失视为内容链路缺口——fail closed，不留空串进云端。
 */
function resolveNameEn(id, preservedMap, fallbackTable) {
  if (preservedMap[id] !== undefined && preservedMap[id].length > 0) {
    return preservedMap[id]
  }
  if (fallbackTable[id] !== undefined && fallbackTable[id].length > 0) {
    return fallbackTable[id]
  }
  throw new Error(`nameEn missing for ${id}; run node tools/sync-content-to-android.mjs first`)
}

function renderSchema() {
  return SCHEMA_STATEMENTS.slice()
}

function renderMuscles(muscles, preserved, fallback) {
  const lines = []
  for (const muscle of muscles) {
    lines.push(
      insert('muscles', MUSCLE_COLUMNS, [
        sql(muscle.muscleId),
        sql(muscle.nameZh),
        sql(muscle.region),
        sql(resolveNameEn(muscle.muscleId, preserved.muscles, fallback))
      ])
    )
  }
  return lines
}

function renderEquipment(equipment, preserved, fallback) {
  const lines = []
  for (const item of equipment) {
    lines.push(
      insert('equipment', EQUIPMENT_COLUMNS, [
        sql(item.equipmentId),
        sql(item.nameZh),
        sql(item.category || ''),
        sql(resolveNameEn(item.equipmentId, preserved.equipment, fallback))
      ])
    )
  }
  return lines
}

function renderExercises(exercises) {
  const lines = []
  for (const exercise of exercises) {
    lines.push(
      insert('exercises', EXERCISE_COLUMNS, [
        sql(exercise.exerciseId),
        sql(exercise.nameZh),
        sql(exercise.nameEn || ''),
        jsonSql(exercise.aliases),
        jsonSql(exercise.primaryMuscleIds),
        jsonSql(exercise.secondaryMuscleIds),
        jsonSql(exercise.equipmentIds),
        sql(exercise.difficulty),
        jsonSql(exercise.goalTags),
        sql(exercise.videoUrl || ''),
        sql(exercise.coverUrl || ''),
        sql(exercise.coverSourceLabel || ''),
        sql(exercise.videoSourceLabel || ''),
        sql(exercise.mediaLicenseText || ''),
        jsonSql(exercise.steps),
        jsonSql(exercise.cues),
        jsonSql(exercise.commonMistakes),
        jsonSql(exercise.safetyNotes),
        jsonSql(exercise.alternativeExerciseIds),
        sql(Number(exercise.contentVersion || 1))
      ])
    )
  }
  return lines
}

/** 纯渲染：给定三组行数据与英文名映射，返回完整 seed SQL 行数组。 */
function renderSeedSql(options) {
  const muscles = options.muscles || []
  const equipment = options.equipment || []
  const exercises = options.exercises || []
  const preserved = options.preserved || { muscles: {}, equipment: {} }
  const fallback = options.fallback || NAME_EN_FALLBACK
  return [
    '-- FitTracker local content database seed.',
    '-- Generated from content/exercises/*.jsonl after build validation.',
    '-- Tables: exercises / muscles / equipment (wide tables, aligned with ContentDatabaseService.ets).',
    'BEGIN TRANSACTION;',
    ...renderSchema(),
    ...renderMuscles(muscles, preserved, fallback),
    ...renderEquipment(equipment, preserved, fallback),
    ...renderExercises(exercises),
    'COMMIT;',
    ''
  ]
}

/** 读内容 + 校验 + 写盘。options 仅用于测试注入。 */
function exportDbSeed(options = {}) {
  const dir = options.contentDir || contentDir
  const target = options.outputPath || outputPath
  const asset = options.assetPath || androidAssetPath
  const buildScript = options.buildScriptPath || buildScriptPath
  runBuildValidation(buildScript)
  const muscles = readJsonl(dir, 'muscles.zh-CN.jsonl')
  const equipment = readJsonl(dir, 'equipment.zh-CN.jsonl')
  const exercises = readJsonl(dir, 'exercises.zh-CN.jsonl')
  const preserved = loadPreservedNameEn(asset)
  const lines = renderSeedSql({ muscles, equipment, exercises, preserved })
  mkdirSync(dirname(target), { recursive: true })
  writeFileSync(target, lines.join('\n'), 'utf8')
  return {
    outputPath: target,
    counts: {
      exercises: exercises.length,
      muscles: muscles.length,
      equipment: equipment.length
    }
  }
}

// 仅在直接执行本文件时运行；被 import（单测）时只暴露函数。
const isDirectRun =
  process.argv[1] !== undefined &&
  resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url))

if (isDirectRun) {
  try {
    const result = exportDbSeed()
    console.log(`Generated ${result.outputPath}`)
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error))
    process.exit(1)
  }
}
