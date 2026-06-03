import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..')
const contentDir = resolve(root, 'content/exercises')
const outputPath = resolve(root, 'entry/src/main/ets/generated/LocalExerciseContent.ets')
const sourceFileKey = '__sourceFile'
const sourceLineKey = '__sourceLine'
const minimumExerciseCount = 30
const recommendedExerciseCount = 50
const allowedDifficulties = ['beginner', 'intermediate', 'advanced']
const allowedGoalTags = ['hypertrophy', 'strength', 'fat_loss', 'posture', 'stability']
const minimumCoveragePerGoal = 3
const minimumCoveragePerMuscle = 3
const minimumCoveragePerEquipment = 2
const minimumCoveragePerDifficulty = 2

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
    try {
      const record = JSON.parse(line)
      if (record === null || Array.isArray(record) || typeof record !== 'object') {
        throw new Error('line must be a JSON object')
      }
      record[sourceFileKey] = fileName
      record[sourceLineKey] = index + 1
      rows.push(record)
    } catch (error) {
      throw new Error(`${fileName}:${index + 1} is not valid JSON: ${error.message}`)
    }
  }
  return rows
}

function requireString(record, field, label) {
  if (typeof record[field] !== 'string' || record[field].trim().length === 0) {
    throw new Error(`${label}.${field} must be a non-empty string at ${sourceOf(record)}`)
  }
}

function requireOptionalString(record, field, label) {
  if (record[field] === undefined) {
    return
  }
  if (typeof record[field] !== 'string') {
    throw new Error(`${label}.${field} must be a string at ${sourceOf(record)}`)
  }
}

function requireStringArray(record, field, label) {
  if (!Array.isArray(record[field])) {
    throw new Error(`${label}.${field} must be an array at ${sourceOf(record)}`)
  }
  for (let index = 0; index < record[field].length; index++) {
    if (typeof record[field][index] !== 'string' || record[field][index].trim().length === 0) {
      throw new Error(`${label}.${field}[${index}] must be a non-empty string at ${sourceOf(record)}`)
    }
  }
}

function requirePositiveInteger(record, field, label) {
  if (!Number.isInteger(record[field]) || record[field] < 1) {
    throw new Error(`${label}.${field} must be a positive integer at ${sourceOf(record)}`)
  }
}

function assertUnique(records, field, label) {
  const seen = new Set()
  const firstSourceByValue = new Map()
  for (const record of records) {
    const value = record[field]
    if (seen.has(value)) {
      throw new Error(`${label}.${field} duplicates ${value} at ${sourceOf(record)}; first seen at ${firstSourceByValue.get(value)}`)
    }
    seen.add(value)
    firstSourceByValue.set(value, sourceOf(record))
  }
}

function sourceOf(record) {
  return `${record[sourceFileKey]}:${record[sourceLineKey]}`
}

function validate(muscles, equipment, exercises) {
  for (const muscle of muscles) {
    requireString(muscle, 'muscleId', 'muscle')
    requireString(muscle, 'nameZh', 'muscle')
    requireString(muscle, 'region', 'muscle')
  }
  for (const item of equipment) {
    requireString(item, 'equipmentId', 'equipment')
    requireString(item, 'nameZh', 'equipment')
  }
  assertUnique(muscles, 'muscleId', 'muscle')
  assertUnique(equipment, 'equipmentId', 'equipment')
  assertUnique(exercises, 'exerciseId', 'exercise')

  const muscleIds = new Set(muscles.map((item) => item.muscleId))
  const equipmentIds = new Set(equipment.map((item) => item.equipmentId))
  const exerciseIds = new Set(exercises.map((item) => item.exerciseId))
  const allowedDifficultySet = new Set(allowedDifficulties)
  const allowedGoalTagSet = new Set(allowedGoalTags)

  for (const exercise of exercises) {
    const label = `exercise ${exercise.exerciseId || '<missing>'}`
    requireString(exercise, 'exerciseId', label)
    requireString(exercise, 'nameZh', label)
    requireString(exercise, 'nameEn', label)
    requireString(exercise, 'difficulty', label)
    requireStringArray(exercise, 'aliases', label)
    requireStringArray(exercise, 'primaryMuscleIds', label)
    requireStringArray(exercise, 'secondaryMuscleIds', label)
    requireStringArray(exercise, 'equipmentIds', label)
    requireStringArray(exercise, 'goalTags', label)
    requireStringArray(exercise, 'steps', label)
    requireStringArray(exercise, 'cues', label)
    requireStringArray(exercise, 'commonMistakes', label)
    requireStringArray(exercise, 'safetyNotes', label)
    requireStringArray(exercise, 'alternativeExerciseIds', label)
    requirePositiveInteger(exercise, 'contentVersion', label)
    if (!allowedDifficultySet.has(exercise.difficulty)) {
      throw new Error(`${label}.difficulty is invalid at ${sourceOf(exercise)}; allowed values: ${allowedDifficulties.join(', ')}`)
    }
    if (exercise.primaryMuscleIds.length === 0) {
      throw new Error(`${label} must have at least one primary muscle at ${sourceOf(exercise)}`)
    }
    if (exercise.equipmentIds.length === 0) {
      throw new Error(`${label} must have at least one equipment at ${sourceOf(exercise)}`)
    }
    if (exercise.goalTags.length === 0) {
      throw new Error(`${label} must have at least one goal tag at ${sourceOf(exercise)}`)
    }
    if (exercise.steps.length === 0) {
      throw new Error(`${label} must have steps at ${sourceOf(exercise)}`)
    }
    for (const muscleId of exercise.primaryMuscleIds.concat(exercise.secondaryMuscleIds)) {
      if (!muscleIds.has(muscleId)) {
        throw new Error(`${label} references unknown muscle ${muscleId} at ${sourceOf(exercise)}`)
      }
    }
    for (const equipmentId of exercise.equipmentIds) {
      if (!equipmentIds.has(equipmentId)) {
        throw new Error(`${label} references unknown equipment ${equipmentId} at ${sourceOf(exercise)}`)
      }
    }
    for (const goalTag of exercise.goalTags) {
      if (!allowedGoalTagSet.has(goalTag)) {
        throw new Error(`${label} references unknown goal tag ${goalTag} at ${sourceOf(exercise)}; allowed values: ${allowedGoalTags.join(', ')}`)
      }
    }
    for (const alternativeId of exercise.alternativeExerciseIds) {
      if (!exerciseIds.has(alternativeId)) {
        throw new Error(`${label} references unknown alternative ${alternativeId} at ${sourceOf(exercise)}`)
      }
    }
    requireOptionalString(exercise, 'coverSourceLabel', label)
    requireOptionalString(exercise, 'videoSourceLabel', label)
    requireOptionalString(exercise, 'mediaLicenseText', label)
    validateLocalMediaField(exercise, 'videoUrl', label)
    validateLocalMediaField(exercise, 'coverUrl', label)
    validateMediaMetadata(exercise, label)
  }
  validateCoverage(muscles, equipment, exercises)
}

function validateMediaMetadata(exercise, label) {
  const videoUrl = exercise.videoUrl || ''
  const coverUrl = exercise.coverUrl || ''
  const coverSourceLabel = (exercise.coverSourceLabel || '').trim()
  const videoSourceLabel = (exercise.videoSourceLabel || '').trim()
  const mediaLicenseText = (exercise.mediaLicenseText || '').trim()

  if (coverUrl.length > 0 && coverSourceLabel.length === 0) {
    throw new Error(`${label}.coverSourceLabel must be provided when coverUrl exists at ${sourceOf(exercise)}`)
  }
  if (videoUrl.length > 0 && videoSourceLabel.length === 0) {
    throw new Error(`${label}.videoSourceLabel must be provided when videoUrl exists at ${sourceOf(exercise)}`)
  }
  if ((coverUrl.length > 0 || videoUrl.length > 0) && mediaLicenseText.length === 0) {
    throw new Error(`${label}.mediaLicenseText must be provided when media exists at ${sourceOf(exercise)}`)
  }
}

function validateLocalMediaField(exercise, field, label) {
  const value = exercise[field] || ''
  if (typeof value !== 'string') {
    throw new Error(`${label}.${field} must be a string at ${sourceOf(exercise)}`)
  }
  if (value.length === 0) {
    return
  }
  if (value.startsWith('http://') || value.startsWith('https://')) {
    throw new Error(`${label}.${field} must use a local placeholder or self-hosted asset path, not remote API/media URL, at ${sourceOf(exercise)}`)
  }
  if (!value.startsWith('local://') && !value.startsWith('/')) {
    throw new Error(`${label}.${field} must start with local:// or / at ${sourceOf(exercise)}`)
  }
}

function validateCoverage(muscles, equipment, exercises) {
  const coverage = createCoverageReport(muscles, equipment, exercises)
  const issues = []
  if (exercises.length < minimumExerciseCount) {
    issues.push(`exercise count ${exercises.length} is below minimum ${minimumExerciseCount}; target range is ${minimumExerciseCount}-${recommendedExerciseCount}`)
  }
  appendCoverageIssues(issues, coverage.goalCounts, allowedGoalTags, minimumCoveragePerGoal, 'goal tag')
  appendCoverageIssues(issues, coverage.equipmentCounts, equipment.map((item) => item.equipmentId), minimumCoveragePerEquipment, 'equipment')
  appendCoverageIssues(issues, coverage.muscleCounts, muscles.map((item) => item.muscleId), minimumCoveragePerMuscle, 'primary muscle')
  appendCoverageIssues(issues, coverage.difficultyCounts, allowedDifficulties, minimumCoveragePerDifficulty, 'difficulty')

  if (issues.length > 0) {
    throw new Error(`content coverage check failed:\n${issues.map((issue) => `- ${issue}`).join('\n')}\n${formatCoverageReport(coverage)}`)
  }
}

function appendCoverageIssues(issues, counts, ids, minimum, label) {
  for (const id of ids) {
    const count = counts.get(id) || 0
    if (count < minimum) {
      issues.push(`${label} ${id} has ${count} exercise(s), requires at least ${minimum}`)
    }
  }
}

function createCoverageReport(muscles, equipment, exercises) {
  const goalCounts = createCountMap(allowedGoalTags)
  const equipmentCounts = createCountMap(equipment.map((item) => item.equipmentId))
  const muscleCounts = createCountMap(muscles.map((item) => item.muscleId))
  const difficultyCounts = createCountMap(allowedDifficulties)

  for (const exercise of exercises) {
    incrementCount(difficultyCounts, exercise.difficulty)
    for (const goalTag of exercise.goalTags) {
      incrementCount(goalCounts, goalTag)
    }
    for (const equipmentId of exercise.equipmentIds) {
      incrementCount(equipmentCounts, equipmentId)
    }
    for (const muscleId of exercise.primaryMuscleIds) {
      incrementCount(muscleCounts, muscleId)
    }
  }

  return {
    exerciseCount: exercises.length,
    goalCounts,
    equipmentCounts,
    muscleCounts,
    difficultyCounts
  }
}

function createCountMap(ids) {
  const counts = new Map()
  for (const id of ids) {
    counts.set(id, 0)
  }
  return counts
}

function incrementCount(counts, id) {
  counts.set(id, (counts.get(id) || 0) + 1)
}

function formatCoverageReport(coverage) {
  return [
    'coverage report:',
    `- exercises: ${coverage.exerciseCount} (target ${minimumExerciseCount}-${recommendedExerciseCount})`,
    `- goals: ${formatCounts(coverage.goalCounts)}`,
    `- equipment: ${formatCounts(coverage.equipmentCounts)}`,
    `- muscles: ${formatCounts(coverage.muscleCounts)}`,
    `- difficulties: ${formatCounts(coverage.difficultyCounts)}`
  ].join('\n')
}

function formatCounts(counts) {
  return Array.from(counts.entries()).map(([id, count]) => `${id}=${count}`).join(', ')
}

function q(value) {
  return JSON.stringify(value)
}

function arrayLiteral(values) {
  return `[${values.map((value) => q(value)).join(', ')}]`
}

function render(muscles, equipment, exercises) {
  const lines = []
  lines.push('/**')
  lines.push(' * LocalExerciseContent -- generated from content/exercises JSONL files.')
  lines.push(' * Run: node tools/content/build-content.mjs')
  lines.push(' */')
  lines.push("import { EquipmentItem, ExerciseContent, MuscleGroup, createEquipmentItem, createExerciseContent, createMuscleGroup } from '../shared/models/TrainingModels'")
  lines.push('')
  lines.push('export const LOCAL_MUSCLES: MuscleGroup[] = [')
  for (const muscle of muscles) {
    lines.push(`  createMuscleGroup(${q(muscle.muscleId)}, ${q(muscle.nameZh)}, ${q(muscle.region)}),`)
  }
  lines.push(']')
  lines.push('')
  lines.push('export const LOCAL_EQUIPMENT: EquipmentItem[] = [')
  for (const item of equipment) {
    lines.push(`  createEquipmentItem(${q(item.equipmentId)}, ${q(item.nameZh)}),`)
  }
  lines.push(']')
  lines.push('')
  lines.push('export const LOCAL_EXERCISES: ExerciseContent[] = [')
  for (const exercise of exercises) {
    lines.push('  createExerciseContent(')
    lines.push(`    ${q(exercise.exerciseId)},`)
    lines.push(`    ${q(exercise.nameZh)},`)
    lines.push(`    ${q(exercise.nameEn)},`)
    lines.push(`    ${arrayLiteral(exercise.aliases)},`)
    lines.push(`    ${arrayLiteral(exercise.primaryMuscleIds)},`)
    lines.push(`    ${arrayLiteral(exercise.secondaryMuscleIds)},`)
    lines.push(`    ${arrayLiteral(exercise.equipmentIds)},`)
    lines.push(`    ${q(exercise.difficulty)},`)
    lines.push(`    ${arrayLiteral(exercise.goalTags)},`)
    lines.push(`    ${q(exercise.videoUrl || '')},`)
    lines.push(`    ${q(exercise.coverUrl || '')},`)
    lines.push(`    ${q(exercise.coverSourceLabel || '')},`)
    lines.push(`    ${q(exercise.videoSourceLabel || '')},`)
    lines.push(`    ${q(exercise.mediaLicenseText || '')},`)
    lines.push(`    ${arrayLiteral(exercise.steps)},`)
    lines.push(`    ${arrayLiteral(exercise.cues)},`)
    lines.push(`    ${arrayLiteral(exercise.commonMistakes)},`)
    lines.push(`    ${arrayLiteral(exercise.safetyNotes)},`)
    lines.push(`    ${arrayLiteral(exercise.alternativeExerciseIds)},`)
    lines.push(`    ${Number(exercise.contentVersion || 1)}`)
    lines.push('  ),')
  }
  lines.push(']')
  lines.push('')
  return lines.join('\n')
}

const muscles = readJsonl('muscles.zh-CN.jsonl')
const equipment = readJsonl('equipment.zh-CN.jsonl')
const exercises = readJsonl('exercises.zh-CN.jsonl')
validate(muscles, equipment, exercises)
mkdirSync(dirname(outputPath), { recursive: true })
writeFileSync(outputPath, render(muscles, equipment, exercises), 'utf8')
console.log(formatCoverageReport(createCoverageReport(muscles, equipment, exercises)))
console.log(`Generated ${outputPath}`)
