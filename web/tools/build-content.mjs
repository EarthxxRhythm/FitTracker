#!/usr/bin/env node
/**
 * 内容派生：content/exercises/*.jsonl → src/app/data/content.generated.ts
 *
 * 为什么不在 web 里手抄一份 JSON：项目已把「一份 JSONL → 各端派生」定成约定
 * （鸿蒙侧生成物见 apps/harmony/entry/src/main/ets/generated/LocalExerciseContent.ets）。
 * 手工复制会在下一次内容更新时静默漂移，两端动作库对不上。
 *
 * 字段断言是刻意的：源数据一改字段名就在这里红，而不是产出半残数据让页面跑到一半崩。
 */

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const repoRoot = resolve(here, '..', '..')
const SRC_DIR = resolve(repoRoot, 'apps/harmony/content/exercises')
const OUT_FILE = resolve(here, '..', 'src/app/data/content.generated.ts')

function readJsonl(fileName) {
  const raw = readFileSync(resolve(SRC_DIR, fileName), 'utf8')
  const items = []
  const lines = raw.split('\n')
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim()
    if (line.length === 0) continue
    try {
      items.push(JSON.parse(line))
    } catch (err) {
      throw new Error(`${fileName}:${i + 1} 不是合法 JSON：${err.message}`)
    }
  }
  return items
}

const EXERCISE_REQUIRED = [
  'exerciseId',
  'nameZh',
  'nameEn',
  'aliases',
  'primaryMuscleIds',
  'secondaryMuscleIds',
  'equipmentIds',
  'difficulty',
  'goalTags',
  'videoUrl',
  'coverUrl',
  'coverSourceLabel',
  'videoSourceLabel',
  'mediaLicenseText',
  'steps',
  'cues',
  'commonMistakes',
  'safetyNotes',
  'alternativeExerciseIds',
  'contentVersion'
]

const exercises = readJsonl('exercises.zh-CN.jsonl')
const muscles = readJsonl('muscles.zh-CN.jsonl')
const equipment = readJsonl('equipment.zh-CN.jsonl')

for (const exercise of exercises) {
  for (const key of EXERCISE_REQUIRED) {
    if (!(key in exercise)) {
      throw new Error(`动作 ${exercise.exerciseId ?? '(无 id)'} 缺字段 ${key}`)
    }
  }
  if (!Array.isArray(exercise.primaryMuscleIds) || exercise.primaryMuscleIds.length === 0) {
    throw new Error(`动作 ${exercise.exerciseId} 的 primaryMuscleIds 为空——肌肉分布会把这一条算丢`)
  }
}
for (const muscle of muscles) {
  for (const key of ['muscleId', 'nameZh', 'region']) {
    if (!(key in muscle)) throw new Error(`肌群 ${muscle.muscleId ?? '(无 id)'} 缺字段 ${key}`)
  }
}
for (const item of equipment) {
  for (const key of ['equipmentId', 'nameZh']) {
    if (!(key in item)) throw new Error(`器械 ${item.equipmentId ?? '(无 id)'} 缺字段 ${key}`)
  }
}

const header = `/**
 * 自动生成，勿手改。
 *
 * 源：apps/harmony/content/exercises/{exercises,muscles,equipment}.zh-CN.jsonl
 * 生成：node web/tools/build-content.mjs（predev / prebuild 会先跑）
 */

import type { ExerciseContent, MuscleGroup, EquipmentItem } from '../types'

`

const body =
  `export const EXERCISES: ExerciseContent[] = ${JSON.stringify(exercises, null, 2)}\n\n` +
  `export const MUSCLES: MuscleGroup[] = ${JSON.stringify(muscles, null, 2)}\n\n` +
  `export const EQUIPMENT: EquipmentItem[] = ${JSON.stringify(equipment, null, 2)}\n\n` +
  `export const CONTENT_COUNT: number = ${exercises.length}\n`

mkdirSync(dirname(OUT_FILE), { recursive: true })
writeFileSync(OUT_FILE, header + body, 'utf8')

console.log(
  `content.generated.ts: ${exercises.length} 动作 / ${muscles.length} 肌群 / ${equipment.length} 器械`
)
