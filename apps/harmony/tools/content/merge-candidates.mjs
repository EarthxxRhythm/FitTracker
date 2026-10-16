#!/usr/bin/env node
/**
 * merge-candidates.mjs —— 把 `.rivet/scratch/new-exercises-zh.json` 中的中文审校数据
 * 与 free-exercise-db 源数据（肌群/器械/难度字段）合并，生成可追加进
 * `content/exercises/exercises.zh-CN.jsonl` 的条目。
 *
 * 这是一个**一次性审校工具**：只做人工既定的映射，不做启发式推断。
 * 中文名与中文步骤来自人工审校文件，肌群/器械/难度从源数据按映射表转换。
 *
 * 用法：
 *   node tools/content/merge-candidates.mjs --dry-run   # 预览
 *   node tools/content/merge-candidates.mjs             # 追加到 exercises.zh-CN.jsonl
 */
import { existsSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..')
const repoRoot = resolve(root, '../..')

const sourcePath = resolve(repoRoot, '.rivet/scratch/free-exercise-db.raw.json')
const zhPath = resolve(repoRoot, '.rivet/scratch/new-exercises-zh.json')
const targetPath = resolve(root, 'content/exercises/exercises.zh-CN.jsonl')
const equipmentPath = resolve(root, 'content/exercises/equipment.zh-CN.jsonl')

const EQUIPMENT_MAP = {
  'body only': 'eq_bodyweight',
  dumbbell: 'eq_dumbbell',
  barbell: 'eq_barbell',
  cable: 'eq_cable',
  machine: 'eq_machine',
  bands: 'eq_band',
  kettlebells: 'eq_kettlebell',
  'e-z curl bar': 'eq_barbell'
}

const MUSCLE_MAP = {
  chest: 'muscle_chest',
  lats: 'muscle_back',
  'middle back': 'muscle_back',
  'lower back': 'muscle_back',
  traps: 'muscle_back',
  quadriceps: 'muscle_legs',
  hamstrings: 'muscle_legs',
  glutes: 'muscle_legs',
  calves: 'muscle_legs',
  abductors: 'muscle_legs',
  adductors: 'muscle_legs',
  shoulders: 'muscle_shoulders',
  neck: 'muscle_shoulders',
  biceps: 'muscle_arms',
  triceps: 'muscle_arms',
  forearms: 'muscle_arms',
  abdominals: 'muscle_core'
}

const DIFFICULTY_MAP = { beginner: 'beginner', intermediate: 'intermediate', expert: 'advanced' }

function inferGoalTags(record) {
  const tags = []
  const category = record.category || ''
  const mechanic = record.mechanic || ''
  const force = record.force || ''
  if (category === 'strength' || category === 'powerlifting' || category === 'olympic weightlifting') {
    tags.push('strength')
    if (mechanic === 'compound') { tags.push('hypertrophy') }
  } else if (category === 'strongman') {
    tags.push('strength'); tags.push('stability')
  } else if (category === 'cardio' || category === 'plyometrics') {
    tags.push('fat_loss')
  } else if (category === 'stretching') {
    tags.push('posture'); tags.push('stability')
  }
  if (force === 'static' && tags.indexOf('stability') === -1) { tags.push('stability') }
  if (tags.length === 0) { tags.push('hypertrophy') }
  return Array.from(new Set(tags))
}

function mapMuscles(list) {
  const out = []
  for (const m of list || []) {
    const t = MUSCLE_MAP[m]
    if (t !== undefined && out.indexOf(t) === -1) { out.push(t) }
  }
  return out
}

function main() {
  const dryRun = process.argv.includes('--dry-run')

  if (!existsSync(sourcePath)) {
    throw new Error(`源数据不存在：${sourcePath}（先下载 free-exercise-db 数据）`)
  }
  const sourceData = JSON.parse(readFileSync(sourcePath, 'utf8'))
  const zhData = JSON.parse(readFileSync(zhPath, 'utf8'))

  const byName = {}
  for (const record of sourceData) {
    byName[record.name.toLowerCase()] = record
  }

  const existingText = readFileSync(targetPath, 'utf8')
  const existingIds = new Set()
  const existingEn = new Set()
  for (const line of existingText.split(/\r?\n/)) {
    const t = line.trim()
    if (t.length === 0) { continue }
    const r = JSON.parse(t)
    existingIds.add(r.exerciseId)
    existingEn.add(String(r.nameEn).toLowerCase())
  }

  const generated = []
  const problems = []
  const usedEquipment = new Set()

  for (const entry of zhData.entries) {
    const source = byName[entry.sourceName.toLowerCase()]
    if (source === undefined) {
      problems.push(`源数据中找不到：${entry.sourceName}`)
      continue
    }
    if (existingIds.has(entry.exerciseId)) {
      problems.push(`exerciseId 已存在：${entry.exerciseId}`)
      continue
    }
    if (existingEn.has(entry.nameEn.toLowerCase())) {
      problems.push(`nameEn 与现有动作重复：${entry.nameEn}`)
      continue
    }
    const equipmentId = EQUIPMENT_MAP[source.equipment]
    if (equipmentId === undefined) {
      problems.push(`器械无法映射：${entry.sourceName} (${source.equipment})`)
      continue
    }
    const primaryMuscleIds = mapMuscles(source.primaryMuscles)
    if (primaryMuscleIds.length === 0) {
      problems.push(`主肌群无法映射：${entry.sourceName}`)
      continue
    }
    const difficulty = DIFFICULTY_MAP[source.level]
    if (difficulty === undefined) {
      problems.push(`难度无法映射：${entry.sourceName} (${source.level})`)
      continue
    }
    if (!Array.isArray(entry.steps) || entry.steps.length === 0) {
      problems.push(`缺少中文步骤：${entry.sourceName}`)
      continue
    }

    const secondaryMuscleIds = mapMuscles(source.secondaryMuscles).filter(
      (id) => primaryMuscleIds.indexOf(id) === -1
    )
    usedEquipment.add(equipmentId)

    generated.push({
      exerciseId: entry.exerciseId,
      nameZh: entry.nameZh,
      nameEn: entry.nameEn,
      aliases: entry.aliases,
      primaryMuscleIds: primaryMuscleIds,
      secondaryMuscleIds: secondaryMuscleIds,
      equipmentIds: [equipmentId],
      difficulty: difficulty,
      goalTags: inferGoalTags(source),
      videoUrl: '',
      coverUrl: '',
      coverSourceLabel: '',
      videoSourceLabel: '',
      mediaLicenseText: '',
      steps: entry.steps,
      cues: entry.cues || [],
      commonMistakes: entry.commonMistakes || [],
      safetyNotes: entry.safetyNotes || [],
      alternativeExerciseIds: entry.alternativeExerciseIds || [],
      contentVersion: 3
    })
  }

  console.log(`审校条目: ${zhData.entries.length}`)
  console.log(`成功生成: ${generated.length}`)
  console.log(`用到的器械: ${Array.from(usedEquipment).sort().join(', ')}`)
  if (problems.length > 0) {
    console.log(`\n问题 (${problems.length}):`)
    for (const p of problems) { console.log('  - ' + p) }
  }

  // 校验 alternativeExerciseIds 是否都存在于「现有 + 本次新增」集合
  const allIds = new Set([...existingIds, ...generated.map((g) => g.exerciseId)])
  const danglingAlternatives = []
  for (const g of generated) {
    for (const alt of g.alternativeExerciseIds) {
      if (!allIds.has(alt)) { danglingAlternatives.push(`${g.exerciseId} -> ${alt}`) }
    }
  }
  if (danglingAlternatives.length > 0) {
    console.log(`\n悬空替代动作引用 (${danglingAlternatives.length}):`)
    for (const d of danglingAlternatives) { console.log('  - ' + d) }
  }

  if (problems.length > 0 || danglingAlternatives.length > 0) {
    console.log('\n存在阻塞问题，未写盘。')
    process.exit(1)
  }

  if (dryRun) {
    console.log('\n(dry-run：未写盘)')
    console.log('样本:', JSON.stringify(generated[0], null, 2).slice(0, 800))
    return
  }

  // 追加到 exercises.zh-CN.jsonl
  const appendText = generated.map((g) => JSON.stringify(g)).join('\n')
  const needsNewline = existingText.length > 0 && !existingText.endsWith('\n')
  writeFileSync(targetPath, existingText + (needsNewline ? '\n' : '') + appendText + '\n', 'utf8')
  console.log(`\n已追加 ${generated.length} 条到 ${targetPath}`)

  // 如用到 eq_kettlebell，检查 equipment.zh-CN.jsonl 是否需要补充
  const equipmentText = readFileSync(equipmentPath, 'utf8')
  if (usedEquipment.has('eq_kettlebell') && equipmentText.indexOf('eq_kettlebell') === -1) {
    const suffix = equipmentText.endsWith('\n') ? '' : '\n'
    writeFileSync(
      equipmentPath,
      equipmentText + suffix + JSON.stringify({ equipmentId: 'eq_kettlebell', nameZh: '壶铃' }) + '\n',
      'utf8'
    )
    console.log(`已补充器械：eq_kettlebell（壶铃）到 ${equipmentPath}`)
  }
}

// 仅在直接执行本文件时运行；被 import（例如单测）时只暴露纯函数。
const isDirectRun =
  process.argv[1] !== undefined &&
  resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url))

if (isDirectRun) {
  main()
}
