#!/usr/bin/env node
/**
 * import-external-source.mjs —— 把 free-exercise-db（Unlicense，公共领域）的动作
 * 转换成 菲特 内容管线的候选 JSONL。
 *
 * 背景与许可依据见 `docs/cloud/外部健身数据源评估.md`。该源是实测唯一「零摩擦」数据源
 * （Unlicense，无署名/copyleft/再分发义务）。本脚本**只产出候选文件**，不直接写入
 * `content/exercises/exercises.zh-CN.jsonl` —— 中文名与中文步骤必须人工审校后再合并，
 * 因为该源为纯英文，且不含 cues / commonMistakes / safetyNotes 字段。
 *
 * 用法：
 *   node tools/content/import-external-source.mjs --limit 20               # 取 20 条候选
 *   node tools/content/import-external-source.mjs --limit 5 --dry-run      # 只打印不写盘
 *   node tools/content/import-external-source.mjs --input <file.json>      # 读本地缓存
 *   node tools/content/import-external-source.mjs --out <dir>              # 指定输出目录
 *
 * 数据获取：源站 GitHub 直连在国内网络下可能被 TLS 阻断，默认走 Gitee 镜像 API。
 *
 * 字段映射（外部 → 项目 JSONL schema）：
 *   name          → nameEn（英文名）
 *   （无）        → nameZh（**留空待人工补**，脚本只写占位标记）
 *   （无）        → aliases（用 id 转换而来的 slug 形式）
 *   primaryMuscles → primaryMuscleIds（映射表见 MUSCLE_MAP）
 *   secondaryMuscles → secondaryMuscleIds
 *   equipment     → equipmentIds（映射表见 EQUIPMENT_MAP）
 *   level         → difficulty（expert → advanced）
 *   category/mechanic/force → goalTags（推断表见 inferGoalTags）
 *   instructions  → steps（英文原文，待人工翻译）
 *   （无）        → cues / commonMistakes / safetyNotes / alternativeExerciseIds（空数组）
 *   （无）        → videoUrl / coverUrl（空串，校验器禁止远程媒体 URL）
 *   （无）        → contentVersion（统一写 3，触发设备端重新导入）
 */
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

// 导出纯函数供单测使用（tools/content/import-external-source.test.mjs）。
export {
  EQUIPMENT_MAP,
  MUSCLE_MAP,
  DIFFICULTY_MAP,
  inferGoalTags,
  toExerciseId,
  toAlias,
  mapMuscles,
  convertRecord
}

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..')
const contentDir = resolve(root, 'content/exercises')
const defaultOutDir = resolve(contentDir, 'candidates')

/** 源数据默认地址（Gitee 镜像 API；GitHub 直连在部分网络下被 TLS 阻断）。 */
const DEFAULT_SOURCE_URL =
  'https://gitee.com/api/v5/repos/kaiji1126/free-exercise-db/contents/dist/exercises.json'

/** 候选条目的 contentVersion：必须高于现有数据的最大值（当前 2），否则设备端不会重新导入。 */
const CANDIDATE_CONTENT_VERSION = 3

/**
 * 器械映射：外部 equipment（12 值）→ 项目 equipmentId。
 * 映射依据：项目现有 6 个器械 ID（见 content/exercises/equipment.zh-CN.jsonl）。
 * 值为 null 表示该动作应被排除（避免引入无法匹配现有器械库的数据）。
 */
const EQUIPMENT_MAP = {
  'body only': 'eq_bodyweight',
  dumbbell: 'eq_dumbbell',
  barbell: 'eq_barbell',
  cable: 'eq_cable',
  machine: 'eq_machine',
  bands: 'eq_band',
  // 壶铃在源数据中出现 53 次，值得作为新器械引入；合并时需同步 equipment.zh-CN.jsonl
  kettlebells: 'eq_kettlebell',
  // 曲杠在功能上等价于杠铃，归并处理
  'e-z curl bar': 'eq_barbell',
  // 以下器械在项目现有器械库中无对应项，排除整条动作
  'exercise ball': null,
  'medicine ball': null,
  'foam roll': null,
  other: null
}

/**
 * 肌群映射：外部 primaryMuscles / secondaryMuscles（17 值）→ 项目 muscleId。
 * 项目现有 6 个肌群 ID（见 content/exercises/muscles.zh-CN.jsonl）。
 */
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
  // 颈部在上背/斜方肌区域，项目中无独立肌群，归入肩部
  neck: 'muscle_shoulders',
  biceps: 'muscle_arms',
  triceps: 'muscle_arms',
  forearms: 'muscle_arms',
  abdominals: 'muscle_core'
}

/** 难度映射：外部 level（3 值）→ 项目 difficulty。 */
const DIFFICULTY_MAP = {
  beginner: 'beginner',
  intermediate: 'intermediate',
  expert: 'advanced'
}

/**
 * goalTags 推断：外部无 goalTags 字段，按 category / mechanic / force 组合推断。
 * 项目允许值：hypertrophy / strength / fat_loss / posture / stability。
 */
function inferGoalTags(record) {
  const tags = []
  const category = record.category || ''
  const mechanic = record.mechanic || ''
  const force = record.force || ''

  if (category === 'strength' || category === 'powerlifting' || category === 'olympic weightlifting') {
    tags.push('strength')
    if (mechanic === 'compound') {
      tags.push('hypertrophy')
    }
  } else if (category === 'strongman') {
    tags.push('strength')
    tags.push('stability')
  } else if (category === 'cardio' || category === 'plyometrics') {
    tags.push('fat_loss')
  } else if (category === 'stretching') {
    tags.push('posture')
    tags.push('stability')
  }

  if (force === 'static' && tags.indexOf('stability') === -1) {
    tags.push('stability')
  }

  if (tags.length === 0) {
    // 兜底：确保 goalTags 非空（校验器要求至少一个）
    tags.push('hypertrophy')
  }
  // 去重
  return Array.from(new Set(tags))
}

/** 把源数据的 id（如 "3_4_Sit-Up"）转成项目风格的 exerciseId（如 "ex_3_4_sit_up"）。 */
function toExerciseId(sourceId) {
  const slug = String(sourceId)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
  return `ex_${slug}`
}

/** 把源数据的 name 转成别名 slug。 */
function toAlias(name) {
  return String(name)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

/** 映射单个肌群数组，去重且丢弃未知值。 */
function mapMuscles(list) {
  const mapped = []
  for (const item of list || []) {
    const target = MUSCLE_MAP[item]
    if (target !== undefined && mapped.indexOf(target) === -1) {
      mapped.push(target)
    }
  }
  return mapped
}

/**
 * 把一条源记录转换为项目候选条目。
 * 返回 null 表示该条不适用（器械无法映射 / 缺少必要字段）。
 */
function convertRecord(record) {
  const equipmentId = EQUIPMENT_MAP[record.equipment]
  if (equipmentId === undefined) {
    return { skipped: true, reason: `unknown_equipment:${record.equipment}` }
  }
  if (equipmentId === null) {
    return { skipped: true, reason: `excluded_equipment:${record.equipment}` }
  }

  const primaryMuscleIds = mapMuscles(record.primaryMuscles)
  if (primaryMuscleIds.length === 0) {
    return { skipped: true, reason: 'no_mappable_primary_muscle' }
  }

  const secondaryMuscleIds = mapMuscles(record.secondaryMuscles).filter(
    (id) => primaryMuscleIds.indexOf(id) === -1
  )

  const difficulty = DIFFICULTY_MAP[record.level]
  if (difficulty === undefined) {
    return { skipped: true, reason: `unknown_level:${record.level}` }
  }

  const steps = (record.instructions || []).filter((s) => typeof s === 'string' && s.trim().length > 0)
  if (steps.length === 0) {
    return { skipped: true, reason: 'no_instructions' }
  }

  const item = {
    exerciseId: toExerciseId(record.id),
    // 中文名待人工补：脚本只写英文名并在前缀标记，合并前必须替换为中文
    nameZh: `【待译】${record.name}`,
    nameEn: record.name,
    aliases: [toAlias(record.name), toAlias(record.id)].filter(
      (v, i, arr) => v.length > 0 && arr.indexOf(v) === i
    ),
    primaryMuscleIds: primaryMuscleIds,
    secondaryMuscleIds: secondaryMuscleIds,
    equipmentIds: [equipmentId],
    difficulty: difficulty,
    goalTags: inferGoalTags(record),
    videoUrl: '',
    coverUrl: '',
    coverSourceLabel: '',
    videoSourceLabel: '',
    mediaLicenseText: '',
    // 英文步骤原文，待人工翻译为中文
    steps: steps,
    cues: [],
    commonMistakes: [],
    safetyNotes: [],
    alternativeExerciseIds: [],
    contentVersion: CANDIDATE_CONTENT_VERSION,
    // 溯源字段（不进正式 JSONL，合并时丢弃）
    __sourceId: record.id,
    __sourceName: record.name,
    __sourceEquipment: record.equipment,
    __sourceMuscles: (record.primaryMuscles || []).join('|'),
    __sourceCategory: record.category || '',
    __sourceMechanic: record.mechanic || '',
    __sourceForce: record.force || ''
  }
  return { skipped: false, item: item }
}

function parseArgs(argv) {
  const options = {
    limit: 0,
    out: defaultOutDir,
    input: '',
    dryRun: false,
    includeExistingDuplicates: false
  }
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i]
    if (arg === '--limit') {
      options.limit = Number(argv[i + 1] || 0)
      i += 1
    } else if (arg === '--out') {
      options.out = resolve(root, argv[i + 1] || '')
      i += 1
    } else if (arg === '--input') {
      options.input = resolve(root, argv[i + 1] || '')
      i += 1
    } else if (arg === '--dry-run') {
      options.dryRun = true
    } else if (arg === '--include-existing-duplicates') {
      options.includeExistingDuplicates = true
    }
  }
  return options
}

/** 读取源数据：--input 指定本地文件，否则走镜像 API。 */
async function loadSourceData(options) {
  if (options.input.length > 0) {
    if (!existsSync(options.input)) {
      throw new Error(`--input 指定的文件不存在：${options.input}`)
    }
    const text = readFileSync(options.input, 'utf8')
    const parsed = JSON.parse(text)
    // 支持两种形态：直接的数组，或镜像 API 的 {content: base64}
    if (Array.isArray(parsed)) {
      return parsed
    }
    if (parsed && typeof parsed.content === 'string') {
      return JSON.parse(Buffer.from(parsed.content, 'base64').toString('utf8'))
    }
    throw new Error('--input 文件既不是 JSON 数组，也不是含 content 字段的镜像 API 响应')
  }

  const response = await fetch(DEFAULT_SOURCE_URL)
  if (!response.ok) {
    throw new Error(`拉取源数据失败：HTTP ${response.status} ${DEFAULT_SOURCE_URL}`)
  }
  const payload = await response.json()
  if (payload && typeof payload.content === 'string') {
    return JSON.parse(Buffer.from(payload.content, 'base64').toString('utf8'))
  }
  if (Array.isArray(payload)) {
    return payload
  }
  throw new Error('源数据响应格式无法识别（既非数组也非镜像 API 结构）')
}

/** 读取项目现有动作，用于重复检测（按 nameEn 小写比对 + 中文名比对）。 */
function loadExistingNames() {
  const path = resolve(contentDir, 'exercises.zh-CN.jsonl')
  const names = new Set()
  if (!existsSync(path)) {
    return names
  }
  const lines = readFileSync(path, 'utf8').split(/\r?\n/)
  for (const line of lines) {
    const trimmed = line.trim()
    if (trimmed.length === 0) {
      continue
    }
    try {
      const record = JSON.parse(trimmed)
      if (typeof record.nameEn === 'string') {
        names.add(record.nameEn.toLowerCase())
      }
      if (typeof record.nameZh === 'string') {
        names.add(record.nameZh.toLowerCase())
      }
    } catch (error) {
      // 现有文件非法行由 build-content.mjs 负责报错，此处跳过
    }
  }
  return names
}

function main() {
  return run()
}

async function run() {
  const options = parseArgs(process.argv.slice(2))
  const sourceData = await loadSourceData(options)
  const existingNames = loadExistingNames()

  const converted = []
  const skipped = []
  const duplicates = []
  const seenIds = new Set()

  for (const record of sourceData) {
    const result = convertRecord(record)
    if (result.skipped) {
      skipped.push({ name: record.name, reason: result.reason })
      continue
    }
    const item = result.item
    if (seenIds.has(item.exerciseId)) {
      skipped.push({ name: record.name, reason: 'duplicate_exercise_id' })
      continue
    }
    seenIds.add(item.exerciseId)
    if (!options.includeExistingDuplicates && existingNames.has(item.nameEn.toLowerCase())) {
      duplicates.push({ name: item.nameEn, exerciseId: item.exerciseId })
      continue
    }
    converted.push(item)
  }

  const limited = options.limit > 0 ? converted.slice(0, options.limit) : converted

  console.log('=== 导入统计 ===')
  console.log(`源记录总数: ${sourceData.length}`)
  console.log(`成功转换: ${converted.length}`)
  console.log(`  - 与现有动作重复(已跳过): ${duplicates.length}`)
  console.log(`  - 本次输出: ${limited.length}${options.limit > 0 ? ` (--limit ${options.limit})` : ''}`)
  console.log(`跳过(不可映射): ${skipped.length}`)
  const skipReasons = {}
  for (const item of skipped) {
    skipReasons[item.reason] = (skipReasons[item.reason] || 0) + 1
  }
  for (const reason of Object.keys(skipReasons).sort()) {
    console.log(`  - ${reason}: ${skipReasons[reason]}`)
  }

  if (duplicates.length > 0) {
    console.log('=== 与现有动作重复(按 nameEn) ===')
    for (const item of duplicates) {
      console.log(`  ${item.exerciseId}  (${item.name})`)
    }
  }

  console.log('=== 候选样本(前 5 条) ===')
  for (const item of limited.slice(0, 5)) {
    console.log(JSON.stringify({
      exerciseId: item.exerciseId,
      nameEn: item.nameEn,
      primaryMuscleIds: item.primaryMuscleIds,
      equipmentIds: item.equipmentIds,
      difficulty: item.difficulty,
      goalTags: item.goalTags,
      stepsCount: item.steps.length,
      sourceId: item.__sourceId
    }))
  }

  if (options.dryRun) {
    console.log('(dry-run：未写盘)')
    return
  }

  mkdirSync(options.out, { recursive: true })
  // 输出两类文件：完整候选（含翻译所需英文原文）与精简预览
  const candidatePath = resolve(options.out, 'candidates.jsonl')
  const itemsForFile = limited.map((item) => {
    const output = {}
    // 按项目 schema 字段顺序输出；溯源字段用 __ 前缀保留以便审校
    const schemaFields = [
      'exerciseId', 'nameZh', 'nameEn', 'aliases', 'primaryMuscleIds', 'secondaryMuscleIds',
      'equipmentIds', 'difficulty', 'goalTags', 'videoUrl', 'coverUrl', 'coverSourceLabel',
      'videoSourceLabel', 'mediaLicenseText', 'steps', 'cues', 'commonMistakes', 'safetyNotes',
      'alternativeExerciseIds', 'contentVersion'
    ]
    for (const field of schemaFields) {
      output[field] = item[field]
    }
    output.__source = {
      id: item.__sourceId,
      name: item.__sourceName,
      equipment: item.__sourceEquipment,
      muscles: item.__sourceMuscles,
      category: item.__sourceCategory,
      mechanic: item.__sourceMechanic,
      force: item.__sourceForce
    }
    return output
  })
  writeFileSync(candidatePath, itemsForFile.map((i) => JSON.stringify(i)).join('\n') + '\n', 'utf8')
  console.log(`已写出候选文件: ${candidatePath} (${itemsForFile.length} 条)`)
  console.log('注意：nameZh 带【待译】前缀、steps 为英文原文，合并前必须人工审校。')
}

// 仅在直接执行本文件时运行 CLI；被 import（例如单测）时只暴露纯函数。
// 历史教训：无守卫时 import 会触发顶层 main() —— 测试与被测脚本互相污染。
const isDirectRun =
  process.argv[1] !== undefined &&
  resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url))

if (isDirectRun) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : String(error))
    process.exit(1)
  })
}
