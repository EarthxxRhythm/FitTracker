#!/usr/bin/env node
/**
 * sync-content-to-android.mjs —— 把鸿蒙端的动作库内容（权威源）同步为 Android 端的
 * 内置资产 `apps/android/app/src/main/assets/exercise-content.json`。
 *
 * ## 为什么需要这个脚本
 *
 * 鸿蒙端的内容链路是 `content/exercises/*.jsonl → build-content.mjs → LocalExerciseContent.ets`，
 * 而 Android 端的唯一内容源是打包进 APK 的资产 JSON。两端自 monorepo 合并（8f256af）以来
 * 没有任何同步机制——2026-10-16 鸿蒙动作库从 50 条扩充到 102 条后，Android 仍停留在 50 条
 * 旧快照，即本脚本要消除的漂移。
 *
 * ## 关键约束：Android 独有的 nameEn 字段
 *
 * Android 的 `MuscleGroup` / `EquipmentItem` 比鸿蒙模型多一个 `nameEn`（英文展示名，
 * 见 `apps/android/.../data/model/TrainingModels.kt:35-52`），鸿蒙侧 `TrainingModels.ets:17-26`
 * **没有**该字段。因此同步时不能简单覆盖——必须：
 *   1. 从 Android 现有资产中**保留**已知 id 的 nameEn；
 *   2. 对新增 id（如 `eq_kettlebell`）从下面的 `NAME_EN_FALLBACK` 表补值。
 * 若置空，`ContentRepository.muscleDisplayName` 会在英文区域回落中文，导致英文界面退化。
 *
 * ## 用法（从仓库根执行）
 *
 *   node tools/sync-content-to-android.mjs --dry-run   # 只打印统计，不写盘
 *   node tools/sync-content-to-android.mjs             # 写入 Android 资产
 */
import { existsSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

// 导出纯函数供单测使用（tools/sync-content-to-android.test.mjs）。
export {
  NAME_EN_FALLBACK,
  parseJsonl,
  loadPreservedNameEn,
  buildAndroidBundle,
  validateBundle,
  selectJsonlFiles,
  compareTwoEnds
}

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')

/** 鸿蒙端内容源目录（权威）。 */
const HARMONY_CONTENT_DIR = resolve(root, 'apps/harmony/content/exercises')
/** Android 端资产路径（消费方）。 */
const ANDROID_ASSET_PATH = resolve(root, 'apps/android/app/src/main/assets/exercise-content.json')

/**
 * 新增条目的英文名回退表——仅用于 Android 资产中**首次出现**的 id。
 * 命名口径：与既有条目同构（`eq_barbell`→`Barbell`、`muscle_chest`→`Chest`），
 * 即「工具名首字母大写」。
 */
const NAME_EN_FALLBACK = {
  eq_kettlebell: 'Kettlebell'
}

/** 读取 JSONL 文件为对象数组（跳过空行）。 */
function parseJsonl(text) {
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

/**
 * 从 Android 现有资产中提取 `muscles[].nameEn` / `equipment[].nameEn` 保留映射。
 * 资产不存在或字段缺失时返回空映射（首次同步场景）。
 */
function loadPreservedNameEn(assetPath) {
  const preserved = { muscles: {}, equipment: {} }
  if (!existsSync(assetPath)) {
    return preserved
  }
  let asset
  try {
    asset = JSON.parse(readFileSync(assetPath, 'utf8'))
  } catch (error) {
    // 资产损坏时不静默吞掉——交由调用方决定（此处返回空映射并在日志中说明）
    console.warn(`[warn] 现有资产解析失败，nameEn 将全部走回退表：${error.message}`)
    return preserved
  }
  for (const item of asset.muscles || []) {
    if (typeof item.nameEn === 'string' && item.nameEn.length > 0) {
      preserved.muscles[item.muscleId] = item.nameEn
    }
  }
  for (const item of asset.equipment || []) {
    if (typeof item.nameEn === 'string' && item.nameEn.length > 0) {
      preserved.equipment[item.equipmentId] = item.nameEn
    }
  }
  return preserved
}

/**
 * 解析 id 的英文名：优先沿用既有资产的保留值，其次查回退表，都没有则返回空串
 * （由 `validateBundle` 拦下，避免静默产出退化数据）。
 */
function resolveNameEn(id, preservedMap, fallbackTable) {
  if (preservedMap[id] !== undefined) {
    return preservedMap[id]
  }
  if (fallbackTable[id] !== undefined) {
    return fallbackTable[id]
  }
  return ''
}

/**
 * 组装 Android 资产包：`{muscles, equipment, exercises}`。
 *
 * - muscles/equipment 的 `nameEn` 走「保留 → 回退」两级解析
 * - exercises 逐字段直搬（两端 schema 已逐字一致），字段顺序按 Android 模型定义
 */
function buildAndroidBundle(muscles, equipment, exercises, preserved) {
  const outMuscles = muscles.map((m) => {
    const nameEn = resolveNameEn(m.muscleId, preserved.muscles, NAME_EN_FALLBACK)
    const item = {
      muscleId: m.muscleId,
      nameZh: m.nameZh,
      nameEn: nameEn,
      region: m.region
    }
    return item
  })

  const outEquipment = equipment.map((e) => {
    const nameEn = resolveNameEn(e.equipmentId, preserved.equipment, NAME_EN_FALLBACK)
    const item = {
      equipmentId: e.equipmentId,
      nameZh: e.nameZh,
      nameEn: nameEn
    }
    return item
  })

  const outExercises = exercises.map((x) => {
    const item = {
      exerciseId: x.exerciseId,
      nameZh: x.nameZh,
      nameEn: x.nameEn,
      aliases: x.aliases,
      primaryMuscleIds: x.primaryMuscleIds,
      secondaryMuscleIds: x.secondaryMuscleIds,
      equipmentIds: x.equipmentIds,
      difficulty: x.difficulty,
      goalTags: x.goalTags,
      videoUrl: x.videoUrl,
      coverUrl: x.coverUrl,
      coverSourceLabel: x.coverSourceLabel,
      videoSourceLabel: x.videoSourceLabel,
      mediaLicenseText: x.mediaLicenseText,
      steps: x.steps,
      cues: x.cues,
      commonMistakes: x.commonMistakes,
      safetyNotes: x.safetyNotes,
      alternativeExerciseIds: x.alternativeExerciseIds,
      contentVersion: x.contentVersion
    }
    return item
  })

  return { muscles: outMuscles, equipment: outEquipment, exercises: outExercises }
}

/**
 * 校验产出包的不变量：
 *   1. 动作 ID 全局唯一；
 *   2. 动作引用的肌群/器械 id 都存在于对应集合；
 *   3. 所有 nameEn 非空（否则英文界面会退化）；
 *   4. 每条动作的必填字段完整（对齐 Android `ExerciseContent` 的不可空字段）。
 *
 * 返回问题描述数组；空数组表示通过。
 */
function validateBundle(bundle) {
  const issues = []

  const muscleIds = new Set(bundle.muscles.map((m) => m.muscleId))
  const equipmentIds = new Set(bundle.equipment.map((e) => e.equipmentId))

  if (muscleIds.size !== bundle.muscles.length) {
    issues.push('muscles 存在重复 muscleId')
  }
  if (equipmentIds.size !== bundle.equipment.length) {
    issues.push('equipment 存在重复 equipmentId')
  }

  const seenExerciseIds = new Set()
  for (const exercise of bundle.exercises) {
    if (seenExerciseIds.has(exercise.exerciseId)) {
      issues.push(`动作 ID 重复：${exercise.exerciseId}`)
    }
    seenExerciseIds.add(exercise.exerciseId)

    const referencedMuscles = (exercise.primaryMuscleIds || []).concat(exercise.secondaryMuscleIds || [])
    for (const id of referencedMuscles) {
      if (!muscleIds.has(id)) {
        issues.push(`${exercise.exerciseId} 引用未知肌群 ${id}`)
      }
    }
    if ((exercise.equipmentIds || []).length === 0) {
      issues.push(`${exercise.exerciseId} 没有器械`)
    }
    for (const id of exercise.equipmentIds || []) {
      if (!equipmentIds.has(id)) {
        issues.push(`${exercise.exerciseId} 引用未知器械 ${id}`)
      }
    }
    if ((exercise.primaryMuscleIds || []).length === 0) {
      issues.push(`${exercise.exerciseId} 没有主肌群`)
    }
    if ((exercise.steps || []).length === 0) {
      issues.push(`${exercise.exerciseId} 没有步骤`)
    }
  }

  // 替代动作引用必须都能解析（否则 Android 详情页的「替代动作」区会指向不存在项）
  for (const exercise of bundle.exercises) {
    for (const alt of exercise.alternativeExerciseIds || []) {
      if (!seenExerciseIds.has(alt)) {
        issues.push(`${exercise.exerciseId} 的替代动作 ${alt} 不存在`)
      }
    }
  }

  // nameEn 非空（Android 独有的双语字段，空了英文界面会回落中文）
  for (const muscle of bundle.muscles) {
    if (typeof muscle.nameEn !== 'string' || muscle.nameEn.length === 0) {
      issues.push(`肌群 ${muscle.muscleId} 缺少 nameEn（英文界面会回落中文）`)
    }
  }
  for (const item of bundle.equipment) {
    if (typeof item.nameEn !== 'string' || item.nameEn.length === 0) {
      issues.push(`器械 ${item.equipmentId} 缺少 nameEn（英文界面会回落中文）`)
    }
  }

  return issues
}

/** 定位鸿蒙端三个内容源文件。 */
function selectJsonlFiles(contentDir) {
  return {
    muscles: resolve(contentDir, 'muscles.zh-CN.jsonl'),
    equipment: resolve(contentDir, 'equipment.zh-CN.jsonl'),
    exercises: resolve(contentDir, 'exercises.zh-CN.jsonl')
  }
}

function main() {
  const dryRun = process.argv.includes('--dry-run')
  const checkOnly = process.argv.includes('--check')
  const files = selectJsonlFiles(HARMONY_CONTENT_DIR)

  for (const key of Object.keys(files)) {
    if (!existsSync(files[key])) {
      throw new Error(`鸿蒙端内容源缺失：${files[key]}`)
    }
  }

  const muscles = parseJsonl(readFileSync(files.muscles, 'utf8'))
  const equipment = parseJsonl(readFileSync(files.equipment, 'utf8'))
  const exercises = parseJsonl(readFileSync(files.exercises, 'utf8'))

  // --check：只比对双端是否一致，不构建也不写盘（供 CI / 抽查用）
  if (checkOnly) {
    if (!existsSync(ANDROID_ASSET_PATH)) {
      console.error(`Android 资产不存在：${ANDROID_ASSET_PATH}`)
      process.exit(1)
    }
    const androidAsset = JSON.parse(readFileSync(ANDROID_ASSET_PATH, 'utf8'))
    const diff = compareTwoEnds(exercises, androidAsset)
    console.log('=== 双端一致性 ===')
    console.log(`鸿蒙动作数：${diff.harmonyCount}`)
    console.log(`Android 动作数：${diff.androidCount}`)
    if (diff.onlyInHarmony.length === 0 && diff.onlyInAndroid.length === 0) {
      console.log('两端动作集合一致。')
      return
    }
    if (diff.onlyInHarmony.length > 0) {
      console.log(`仅鸿蒙有（Android 缺失 ${diff.onlyInHarmony.length} 条）：${diff.onlyInHarmony.join(', ')}`)
    }
    if (diff.onlyInAndroid.length > 0) {
      console.log(`仅 Android 有（${diff.onlyInAndroid.length} 条）：${diff.onlyInAndroid.join(', ')}`)
    }
    console.log('建议执行：node tools/sync-content-to-android.mjs')
    process.exit(1)
  }

  const preserved = loadPreservedNameEn(ANDROID_ASSET_PATH)
  const preservedMuscleCount = Object.keys(preserved.muscles).length
  const preservedEquipmentCount = Object.keys(preserved.equipment).length

  const bundle = buildAndroidBundle(muscles, equipment, exercises, preserved)

  const issues = validateBundle(bundle)
  if (issues.length > 0) {
    console.error('校验失败，未写盘：')
    for (const issue of issues) {
      console.error(`  - ${issue}`)
    }
    process.exit(1)
  }

  const fallbackUsed = []
  for (const item of bundle.equipment) {
    if (preserved.equipment[item.equipmentId] === undefined) {
      fallbackUsed.push(`${item.equipmentId} → ${item.nameEn}`)
    }
  }
  for (const item of bundle.muscles) {
    if (preserved.muscles[item.muscleId] === undefined) {
      fallbackUsed.push(`${item.muscleId} → ${item.nameEn}`)
    }
  }

  console.log('=== 同步统计 ===')
  console.log(`muscles: ${bundle.muscles.length}`)
  console.log(`equipment: ${bundle.equipment.length}`)
  console.log(`exercises: ${bundle.exercises.length}`)
  console.log(`nameEn 保留（肌群 ${preservedMuscleCount} / 器械 ${preservedEquipmentCount}）`)
  if (fallbackUsed.length > 0) {
    console.log(`nameEn 走回退表：${fallbackUsed.join(', ')}`)
  }

  if (dryRun) {
    console.log('(dry-run：未写盘)')
    return
  }

  const text = `${JSON.stringify(bundle, null, 2)}\n`
  writeFileSync(ANDROID_ASSET_PATH, text, 'utf8')
  console.log(`已写入 ${ANDROID_ASSET_PATH}`)
}

/**
 * 双端一致性校验：比对「鸿蒙 JSONL 的动作 ID 集合」与「Android 资产的 exerciseId 集合」。
 *
 * 独立于同步流程——用于 CI/人工抽查「资产是否已被同步到最新」，不写盘。
 * 返回 `{ harmonyCount, androidCount, onlyInHarmony, onlyInAndroid }`。
 */
function compareTwoEnds(harmonyExercises, androidAsset) {
  const harmonyIds = new Set(harmonyExercises.map((e) => e.exerciseId))
  const androidIds = new Set((androidAsset.exercises || []).map((e) => e.exerciseId))
  const onlyInHarmony = []
  for (const id of harmonyIds) {
    if (!androidIds.has(id)) {
      onlyInHarmony.push(id)
    }
  }
  const onlyInAndroid = []
  for (const id of androidIds) {
    if (!harmonyIds.has(id)) {
      onlyInAndroid.push(id)
    }
  }
  return {
    harmonyCount: harmonyIds.size,
    androidCount: androidIds.size,
    onlyInHarmony: onlyInHarmony,
    onlyInAndroid: onlyInAndroid
  }
}

// 仅在直接执行本文件时运行；被 import（例如单测）时只暴露纯函数。
const isDirectRun =
  process.argv[1] !== undefined &&
  resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url))

if (isDirectRun) {
  try {
    main()
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error))
    process.exit(1)
  }
}
