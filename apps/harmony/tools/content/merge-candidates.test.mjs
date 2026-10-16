// merge-candidates.mjs 的映射与校验逻辑回归测试。
//
// 背景：该脚本把人工中文审校数据与 free-exercise-db 源元数据合并成项目 JSONL。
// 关键不变量：合并产物必须满足 build-content.mjs 的校验规则，且不得产生悬空引用
// （alternativeExerciseIds 指向不存在的动作会让构建失败）。
//
// 运行：node --test tools/content/merge-candidates.test.mjs

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

// merge-candidates.mjs 目前把纯函数内联在 main() 中，此处按其行为契约做外部验证：
// 用临时 fixture 跑一次完整合并，检查产物是否满足 build-content 的约束。
// 说明：脚本依赖固定路径（.rivet/scratch/*、content/exercises/*），因此这里验证的是
// 「已合并产物」的不变量，而不是重新跑合并（后者会修改真实数据文件）。

import { readFileSync, existsSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptDir = dirname(fileURLToPath(import.meta.url))
const harmonyRoot = resolve(scriptDir, '../..')

/** 读取项目动作 JSONL（合并产物的真实落点）。 */
function loadExercises() {
  const path = resolve(harmonyRoot, 'content/exercises/exercises.zh-CN.jsonl')
  const rows = []
  for (const line of readFileSync(path, 'utf8').split(/\r?\n/)) {
    const trimmed = line.trim()
    if (trimmed.length === 0) {
      continue
    }
    rows.push(JSON.parse(trimmed))
  }
  return rows
}

function loadEquipment() {
  const path = resolve(harmonyRoot, 'content/exercises/equipment.zh-CN.jsonl')
  return readFileSync(path, 'utf8')
    .split(/\r?\n/)
    .filter((line) => line.trim().length > 0)
    .map((line) => JSON.parse(line))
}

function loadMuscles() {
  const path = resolve(harmonyRoot, 'content/exercises/muscles.zh-CN.jsonl')
  return readFileSync(path, 'utf8')
    .split(/\r?\n/)
    .filter((line) => line.trim().length > 0)
    .map((line) => JSON.parse(line))
}

test('合并产物的动作 ID 全局唯一', function () {
  const exercises = loadExercises()
  const seen = new Set()
  const duplicates = []
  for (const exercise of exercises) {
    if (seen.has(exercise.exerciseId)) {
      duplicates.push(exercise.exerciseId)
    }
    seen.add(exercise.exerciseId)
  }
  assert.deepEqual(duplicates, [], `发现重复 exerciseId: ${duplicates.join(', ')}`)
})

test('合并产物不含待译占位符（中文名与步骤均已人工补全）', function () {
  const exercises = loadExercises()
  const untranslated = exercises.filter((e) => String(e.nameZh).includes('待译'))
  assert.deepEqual(
    untranslated.map((e) => e.exerciseId),
    [],
    '存在未翻译的动作名——合并前必须完成人工审校'
  )

  const englishOnlySteps = exercises.filter(
    (e) => (e.steps || []).length > 0 && !e.steps.some((s) => /[\u4e00-\u9fa5]/.test(s))
  )
  assert.deepEqual(
    englishOnlySteps.map((e) => e.exerciseId),
    [],
    '存在无中文步骤的动作'
  )
})

test('所有动作引用的肌群与器械 ID 都存在于对应维度表', function () {
  const exercises = loadExercises()
  const muscleIds = new Set(loadMuscles().map((m) => m.muscleId))
  const equipmentIds = new Set(loadEquipment().map((e) => e.equipmentId))

  const badMuscles = []
  const badEquipment = []
  for (const exercise of exercises) {
    for (const id of (exercise.primaryMuscleIds || []).concat(exercise.secondaryMuscleIds || [])) {
      if (!muscleIds.has(id)) {
        badMuscles.push(`${exercise.exerciseId} -> ${id}`)
      }
    }
    for (const id of exercise.equipmentIds || []) {
      if (!equipmentIds.has(id)) {
        badEquipment.push(`${exercise.exerciseId} -> ${id}`)
      }
    }
  }
  assert.deepEqual(badMuscles, [], `引用了未知肌群: ${badMuscles.join('; ')}`)
  assert.deepEqual(badEquipment, [], `引用了未知器械: ${badEquipment.join('; ')}`)
})

test('alternativeExerciseIds 无悬空引用（否则 build-content 会失败）', function () {
  const exercises = loadExercises()
  const allIds = new Set(exercises.map((e) => e.exerciseId))
  const dangling = []
  for (const exercise of exercises) {
    for (const alt of exercise.alternativeExerciseIds || []) {
      if (!allIds.has(alt)) {
        dangling.push(`${exercise.exerciseId} -> ${alt}`)
      }
    }
  }
  assert.deepEqual(dangling, [], `悬空替代引用: ${dangling.join('; ')}`)
})

test('goalTags 与 difficulty 均落在项目白名单内', function () {
  const exercises = loadExercises()
  const allowedGoalTags = ['hypertrophy', 'strength', 'fat_loss', 'posture', 'stability']
  const allowedDifficulties = ['beginner', 'intermediate', 'advanced']

  const badTags = []
  const badDifficulty = []
  for (const exercise of exercises) {
    for (const tag of exercise.goalTags || []) {
      if (!allowedGoalTags.includes(tag)) {
        badTags.push(`${exercise.exerciseId} -> ${tag}`)
      }
    }
    if (!allowedDifficulties.includes(exercise.difficulty)) {
      badDifficulty.push(`${exercise.exerciseId} -> ${exercise.difficulty}`)
    }
  }
  assert.deepEqual(badTags, [], `非法 goalTag: ${badTags.join('; ')}`)
  assert.deepEqual(badDifficulty, [], `非法 difficulty: ${badDifficulty.join('; ')}`)
})

test('媒体字段均为空或本地路径（校验器禁止远程 URL）', function () {
  const exercises = loadExercises()
  const bad = []
  for (const exercise of exercises) {
    for (const field of ['videoUrl', 'coverUrl']) {
      const value = exercise[field] || ''
      if (value.length > 0 && !value.startsWith('local://') && !value.startsWith('/')) {
        bad.push(`${exercise.exerciseId}.${field}=${value}`)
      }
    }
  }
  assert.deepEqual(bad, [], `非法媒体路径: ${bad.join('; ')}`)
})

test('新增条目 contentVersion=3 且 packageVersion 高于扩充前的 2', function () {
  const exercises = loadExercises()
  const maxContentVersion = Math.max(...exercises.map((e) => Number(e.contentVersion) || 0))
  assert.equal(maxContentVersion, 3, '最高 contentVersion 必须是 3（触发设备端重新导入）')

  const manifestPath = resolve(harmonyRoot, 'entry/src/main/ets/generated/LocalContentSyncPackage.ets')
  const manifestText = readFileSync(manifestPath, 'utf8')
  // createContentSyncManifest(1, "full", <packageVersion>, ...) —— 第 3 个参数
  const packageVersionMatch = manifestText.match(/createContentSyncManifest\(\s*1,\s*"full",\s*(\d+)/)
  assert.ok(packageVersionMatch, '无法从生成的 manifest 中解析 packageVersion')
  assert.equal(Number(packageVersionMatch[1]), 3, 'packageVersion 必须与最高 contentVersion 一致')
})

test('器械覆盖度满足校验器的「每器械至少 2 条动作」下限', function () {
  const exercises = loadExercises()
  const equipment = loadEquipment()
  const counts = new Map()
  for (const item of equipment) {
    counts.set(item.equipmentId, 0)
  }
  for (const exercise of exercises) {
    for (const id of exercise.equipmentIds || []) {
      counts.set(id, (counts.get(id) || 0) + 1)
    }
  }
  const underfilled = []
  for (const [id, count] of counts) {
    if (count < 2) {
      underfilled.push(`${id}=${count}`)
    }
  }
  // 这是本轮实际踩到的 RED：eq_kettlebell 曾只有 1 条动作导致构建失败
  assert.deepEqual(underfilled, [], `器械覆盖度不足（每项需 ≥2）: ${underfilled.join(', ')}`)
})

test('每条动作至少有 1 个主肌群、1 个器械、1 个 goalTag、1 个步骤', function () {
  const exercises = loadExercises()
  const violations = []
  for (const exercise of exercises) {
    if ((exercise.primaryMuscleIds || []).length === 0) {
      violations.push(`${exercise.exerciseId}: 无主肌群`)
    }
    if ((exercise.equipmentIds || []).length === 0) {
      violations.push(`${exercise.exerciseId}: 无器械`)
    }
    if ((exercise.goalTags || []).length === 0) {
      violations.push(`${exercise.exerciseId}: 无 goalTag`)
    }
    if ((exercise.steps || []).length === 0) {
      violations.push(`${exercise.exerciseId}: 无步骤`)
    }
  }
  assert.deepEqual(violations, [], violations.join('; '))
})
