import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { spawnSync } from 'node:child_process'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..')
const contentDir = resolve(root, 'content/exercises')
const outputPath = resolve(root, 'build/content/fittracker-content-seed.sql')

function runBuildValidation() {
  const result = spawnSync(process.execPath, [resolve(root, 'tools/content/build-content.mjs')], {
    cwd: root,
    stdio: 'inherit'
  })
  if (result.status !== 0) {
    throw new Error('content build validation failed; database seed was not exported')
  }
}

function readJsonl(fileName) {
  const path = resolve(contentDir, fileName)
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

function insert(table, fields, values) {
  return `INSERT INTO ${table} (${fields.join(', ')}) VALUES (${values.map((value) => sql(value)).join(', ')});`
}

function renderSchema() {
  return [
    'CREATE TABLE IF NOT EXISTS exercises (exercise_id TEXT PRIMARY KEY, name_zh TEXT NOT NULL, name_en TEXT NOT NULL, aliases_json TEXT NOT NULL, difficulty TEXT NOT NULL, goal_tags_json TEXT NOT NULL, steps_json TEXT NOT NULL, cues_json TEXT NOT NULL, common_mistakes_json TEXT NOT NULL, safety_notes_json TEXT NOT NULL, content_version INTEGER NOT NULL, status TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);',
    'CREATE TABLE IF NOT EXISTS muscles (muscle_id TEXT PRIMARY KEY, name_zh TEXT NOT NULL, region TEXT NOT NULL);',
    'CREATE TABLE IF NOT EXISTS equipment (equipment_id TEXT PRIMARY KEY, name_zh TEXT NOT NULL, category TEXT);',
    'CREATE TABLE IF NOT EXISTS exercise_muscles (exercise_id TEXT NOT NULL, muscle_id TEXT NOT NULL, role TEXT NOT NULL, sort_order INTEGER NOT NULL, PRIMARY KEY (exercise_id, muscle_id, role));',
    'CREATE TABLE IF NOT EXISTS exercise_equipment (exercise_id TEXT NOT NULL, equipment_id TEXT NOT NULL, is_required INTEGER NOT NULL, sort_order INTEGER NOT NULL, PRIMARY KEY (exercise_id, equipment_id));',
    'CREATE TABLE IF NOT EXISTS exercise_alternatives (exercise_id TEXT NOT NULL, alternative_exercise_id TEXT NOT NULL, reason TEXT, sort_order INTEGER NOT NULL, PRIMARY KEY (exercise_id, alternative_exercise_id));',
    'CREATE TABLE IF NOT EXISTS exercise_media (media_id TEXT PRIMARY KEY, exercise_id TEXT NOT NULL, media_type TEXT NOT NULL, uri TEXT NOT NULL, thumbnail_uri TEXT, view_angle TEXT, duration_seconds INTEGER, license_type TEXT NOT NULL, source_note TEXT NOT NULL, checksum TEXT, sort_order INTEGER NOT NULL);'
  ]
}

function renderMuscles(muscles) {
  const lines = []
  for (const muscle of muscles) {
    lines.push(insert('muscles', ['muscle_id', 'name_zh', 'region'], [muscle.muscleId, muscle.nameZh, muscle.region]))
  }
  return lines
}

function renderEquipment(equipment) {
  const lines = []
  for (const item of equipment) {
    lines.push(insert('equipment', ['equipment_id', 'name_zh', 'category'], [item.equipmentId, item.nameZh, '']))
  }
  return lines
}

function renderExercises(exercises) {
  const lines = []
  for (const exercise of exercises) {
    lines.push(`INSERT INTO exercises (exercise_id, name_zh, name_en, aliases_json, difficulty, goal_tags_json, steps_json, cues_json, common_mistakes_json, safety_notes_json, content_version, status, created_at, updated_at) VALUES (${[
      sql(exercise.exerciseId),
      sql(exercise.nameZh),
      sql(exercise.nameEn),
      jsonSql(exercise.aliases),
      sql(exercise.difficulty),
      jsonSql(exercise.goalTags),
      jsonSql(exercise.steps),
      jsonSql(exercise.cues),
      jsonSql(exercise.commonMistakes),
      jsonSql(exercise.safetyNotes),
      sql(Number(exercise.contentVersion || 1)),
      sql('published'),
      sql(0),
      sql(0)
    ].join(', ')});`)
    lines.push(...renderExerciseMuscles(exercise))
    lines.push(...renderExerciseEquipment(exercise))
    lines.push(...renderExerciseAlternatives(exercise))
    lines.push(...renderExerciseMedia(exercise))
  }
  return lines
}

function renderExerciseMuscles(exercise) {
  const lines = []
  for (let index = 0; index < exercise.primaryMuscleIds.length; index++) {
    lines.push(insert('exercise_muscles', ['exercise_id', 'muscle_id', 'role', 'sort_order'], [exercise.exerciseId, exercise.primaryMuscleIds[index], 'primary', index + 1]))
  }
  for (let index = 0; index < exercise.secondaryMuscleIds.length; index++) {
    lines.push(insert('exercise_muscles', ['exercise_id', 'muscle_id', 'role', 'sort_order'], [exercise.exerciseId, exercise.secondaryMuscleIds[index], 'secondary', index + 1]))
  }
  return lines
}

function renderExerciseEquipment(exercise) {
  const lines = []
  for (let index = 0; index < exercise.equipmentIds.length; index++) {
    lines.push(insert('exercise_equipment', ['exercise_id', 'equipment_id', 'is_required', 'sort_order'], [exercise.exerciseId, exercise.equipmentIds[index], 1, index + 1]))
  }
  return lines
}

function renderExerciseAlternatives(exercise) {
  const lines = []
  for (let index = 0; index < exercise.alternativeExerciseIds.length; index++) {
    lines.push(insert('exercise_alternatives', ['exercise_id', 'alternative_exercise_id', 'reason', 'sort_order'], [exercise.exerciseId, exercise.alternativeExerciseIds[index], '', index + 1]))
  }
  return lines
}

function renderExerciseMedia(exercise) {
  const lines = []
  if ((exercise.videoUrl || '').length > 0) {
    lines.push(insert('exercise_media', ['media_id', 'exercise_id', 'media_type', 'uri', 'thumbnail_uri', 'view_angle', 'duration_seconds', 'license_type', 'source_note', 'checksum', 'sort_order'], [`${exercise.exerciseId}_video`, exercise.exerciseId, 'video', exercise.videoUrl, exercise.coverUrl || '', '', 0, 'owned', 'FitTracker local or self-hosted asset', '', 1]))
  }
  if ((exercise.coverUrl || '').length > 0) {
    lines.push(insert('exercise_media', ['media_id', 'exercise_id', 'media_type', 'uri', 'thumbnail_uri', 'view_angle', 'duration_seconds', 'license_type', 'source_note', 'checksum', 'sort_order'], [`${exercise.exerciseId}_cover`, exercise.exerciseId, 'cover', exercise.coverUrl, '', '', 0, 'owned', 'FitTracker local or self-hosted asset', '', 2]))
  }
  return lines
}

runBuildValidation()
const muscles = readJsonl('muscles.zh-CN.jsonl')
const equipment = readJsonl('equipment.zh-CN.jsonl')
const exercises = readJsonl('exercises.zh-CN.jsonl')
const lines = [
  '-- FitTracker local content database seed.',
  '-- Generated from content/exercises/*.jsonl after build validation.',
  'BEGIN TRANSACTION;',
  ...renderSchema(),
  ...renderMuscles(muscles),
  ...renderEquipment(equipment),
  ...renderExercises(exercises),
  'COMMIT;',
  ''
]

mkdirSync(dirname(outputPath), { recursive: true })
writeFileSync(outputPath, lines.join('\n'), 'utf8')
console.log(`Generated ${outputPath}`)
