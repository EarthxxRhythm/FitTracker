// sync-content-to-android.mjs 的同步逻辑回归测试。
//
// 背景：该脚本把鸿蒙端内容源（权威）同步为 Android 端内置资产。两类静默失效必须被拦住：
//   1. **nameEn 退化**——Android 独有的双语字段若被写成空串，英文界面会回落中文
//      （`ContentRepository.muscleDisplayName` 的空值回落分支），用户可见但测试若不覆盖就发现不了。
//   2. **引用悬空**——动作引用了不存在的肌群/器械时，Android 侧筛选与分组会静默漏项。
//
// 运行：node --test tools/sync-content-to-android.test.mjs

import { test } from 'node:test'
import assert from 'node:assert/strict'

import {
  NAME_EN_FALLBACK,
  parseJsonl,
  loadPreservedNameEn,
  buildAndroidBundle,
  validateBundle,
  selectJsonlFiles,
  compareTwoEnds
} from './sync-content-to-android.mjs'

// ── fixture ────────────────────────────────────────────────────────

const HARMONY_MUSCLES = [
  { muscleId: 'muscle_chest', nameZh: '胸部', region: 'upper' },
  { muscleId: 'muscle_back', nameZh: '背部', region: 'upper' }
]

const HARMONY_EQUIPMENT = [
  { equipmentId: 'eq_barbell', nameZh: '杠铃' },
  { equipmentId: 'eq_kettlebell', nameZh: '壶铃' }
]

function makeExercise(overrides = {}) {
  return {
    exerciseId: 'ex_bench',
    nameZh: '杠铃卧推',
    nameEn: 'Barbell Bench Press',
    aliases: ['bench press'],
    primaryMuscleIds: ['muscle_chest'],
    secondaryMuscleIds: ['muscle_back'],
    equipmentIds: ['eq_barbell'],
    difficulty: 'intermediate',
    goalTags: ['hypertrophy', 'strength'],
    videoUrl: '',
    coverUrl: '',
    coverSourceLabel: '',
    videoSourceLabel: '',
    mediaLicenseText: '',
    steps: ['躺下', '推起'],
    cues: ['肩胛后收'],
    commonMistakes: ['塌腰'],
    safetyNotes: ['有人保护'],
    alternativeExerciseIds: [],
    contentVersion: 1,
    ...overrides
  }
}

// ── parseJsonl ─────────────────────────────────────────────────────

test('parseJsonl 跳过空行并解析每行 JSON 对象', function () {
  const text = '{"a":1}\n\n  \n{"a":2}\n'
  assert.deepEqual(parseJsonl(text), [{ a: 1 }, { a: 2 }])
  assert.deepEqual(parseJsonl(''), [])
  assert.deepEqual(parseJsonl('\n\n'), [])
})

test('parseJsonl 兼容 CRLF 换行', function () {
  const text = '{"a":1}\r\n{"a":2}\r\n'
  assert.deepEqual(parseJsonl(text), [{ a: 1 }, { a: 2 }])
})

// ── nameEn 保留（核心逻辑） ─────────────────────────────────────────

test('buildAndroidBundle 保留既有资产中的 nameEn（不因鸿蒙侧无此字段而丢失）', function () {
  const preserved = {
    muscles: { muscle_chest: 'Chest', muscle_back: 'Back' },
    equipment: { eq_barbell: 'Barbell' }
  }
  const bundle = buildAndroidBundle(HARMONY_MUSCLES, HARMONY_EQUIPMENT, [makeExercise()], preserved)

  assert.equal(bundle.muscles[0].nameEn, 'Chest', '保留既有英名')
  assert.equal(bundle.muscles[1].nameEn, 'Back', '保留既有英名')
  assert.equal(bundle.equipment[0].nameEn, 'Barbell', '保留既有英名')
  // 中文字段与 region 仍来自鸿蒙源
  assert.equal(bundle.muscles[0].nameZh, '胸部')
  assert.equal(bundle.muscles[0].region, 'upper')
})

test('buildAndroidBundle 对新 id 走回退表（首次同步场景）', function () {
  const preserved = { muscles: {}, equipment: {} }
  const bundle = buildAndroidBundle(HARMONY_MUSCLES, HARMONY_EQUIPMENT, [makeExercise()], preserved)

  // eq_kettlebell 是新增器械，回退表须覆盖
  const kettlebell = bundle.equipment.find((e) => e.equipmentId === 'eq_kettlebell')
  assert.ok(kettlebell, '器械集合应含 eq_kettlebell')
  assert.equal(kettlebell.nameEn, 'Kettlebell', '新增器械应从回退表取英名')
  assert.equal(NAME_EN_FALLBACK.eq_kettlebell, 'Kettlebell')
})

test('回退表未覆盖的 id 产出空 nameEn —— 由 validateBundle 拦下而非静默通过', function () {
  const preserved = { muscles: {}, equipment: {} }
  const unknownMuscles = [{ muscleId: 'muscle_unknown_new', nameZh: '新肌群', region: 'upper' }]
  const bundle = buildAndroidBundle(unknownMuscles, HARMONY_EQUIPMENT, [makeExercise()], preserved)

  assert.equal(bundle.muscles[0].nameEn, '')

  // 必须被校验拦下（这正是本测试的意义：空 nameEn 不能静默进入 Android 资产）
  const issues = validateBundle({
    muscles: bundle.muscles.map((m) => ({ ...m, nameEn: '' })),
    equipment: bundle.equipment,
    exercises: [{ ...makeExercise(), primaryMuscleIds: ['muscle_unknown_new'], secondaryMuscleIds: [] }]
  })
  assert.ok(
    issues.some((i) => i.includes('muscle_unknown_new') && i.includes('nameEn')),
    `应报出 nameEn 缺失，实际：${JSON.stringify(issues)}`
  )
})

// ── 动作字段搬运 ────────────────────────────────────────────────────

test('buildAndroidBundle 逐字段搬运动作且字段集与 Android 模型一致', function () {
  const preserved = { muscles: { muscle_chest: 'Chest' }, equipment: { eq_barbell: 'Barbell' } }
  const bundle = buildAndroidBundle(HARMONY_MUSCLES, HARMONY_EQUIPMENT, [makeExercise()], preserved)
  const exercise = bundle.exercises[0]

  // Android ExerciseContent 的 20 个字段（data/model/TrainingModels.kt:56）
  const expectedFields = [
    'exerciseId', 'nameZh', 'nameEn', 'aliases', 'primaryMuscleIds', 'secondaryMuscleIds',
    'equipmentIds', 'difficulty', 'goalTags', 'videoUrl', 'coverUrl', 'coverSourceLabel',
    'videoSourceLabel', 'mediaLicenseText', 'steps', 'cues', 'commonMistakes', 'safetyNotes',
    'alternativeExerciseIds', 'contentVersion'
  ]
  assert.deepEqual(Object.keys(exercise).sort(), [...expectedFields].sort())

  assert.equal(exercise.exerciseId, 'ex_bench')
  assert.equal(exercise.nameZh, '杠铃卧推')
  assert.deepEqual(exercise.steps, ['躺下', '推起'])
  assert.equal(exercise.contentVersion, 1)
})

// ── validateBundle ─────────────────────────────────────────────────

test('validateBundle 通过合法包', function () {
  const preserved = {
    muscles: { muscle_chest: 'Chest', muscle_back: 'Back' },
    equipment: { eq_barbell: 'Barbell', eq_kettlebell: 'Kettlebell' }
  }
  const bundle = buildAndroidBundle(HARMONY_MUSCLES, HARMONY_EQUIPMENT, [makeExercise()], preserved)
  assert.deepEqual(validateBundle(bundle), [])
})

test('validateBundle 拦下重复动作 ID', function () {
  const preserved = { muscles: { muscle_chest: 'Chest' }, equipment: { eq_barbell: 'Barbell' } }
  const bundle = buildAndroidBundle(
    HARMONY_MUSCLES,
    HARMONY_EQUIPMENT,
    [makeExercise(), makeExercise()],
    preserved
  )
  const issues = validateBundle(bundle)
  assert.ok(issues.some((i) => i.includes('重复')), `应报重复 ID，实际：${JSON.stringify(issues)}`)
})

test('validateBundle 拦下悬空的肌群与器械引用', function () {
  const bundle = {
    muscles: [{ muscleId: 'muscle_chest', nameZh: '胸部', nameEn: 'Chest', region: 'upper' }],
    equipment: [{ equipmentId: 'eq_barbell', nameZh: '杠铃', nameEn: 'Barbell' }],
    exercises: [makeExercise({ primaryMuscleIds: ['muscle_missing'], equipmentIds: ['eq_missing'] })]
  }
  const issues = validateBundle(bundle)
  assert.ok(issues.some((i) => i.includes('muscle_missing')), '应报未知肌群')
  assert.ok(issues.some((i) => i.includes('eq_missing')), '应报未知器械')
})

test('validateBundle 拦下悬空的替代动作引用', function () {
  const bundle = {
    muscles: [{ muscleId: 'muscle_chest', nameZh: '胸部', nameEn: 'Chest', region: 'upper' }],
    equipment: [{ equipmentId: 'eq_barbell', nameZh: '杠铃', nameEn: 'Barbell' }],
    exercises: [makeExercise({ alternativeExerciseIds: ['ex_ghost'] })]
  }
  const issues = validateBundle(bundle)
  assert.ok(
    issues.some((i) => i.includes('ex_ghost')),
    `应报悬空替代引用，实际：${JSON.stringify(issues)}`
  )
})

test('validateBundle 拦下缺少必填结构的动作', function () {
  const base = {
    muscles: [{ muscleId: 'muscle_chest', nameZh: '胸部', nameEn: 'Chest', region: 'upper' }],
    equipment: [{ equipmentId: 'eq_barbell', nameZh: '杠铃', nameEn: 'Barbell' }]
  }
  const noSteps = validateBundle({
    ...base,
    exercises: [makeExercise({ steps: [] })]
  })
  assert.ok(noSteps.some((i) => i.includes('没有步骤')))

  const noPrimary = validateBundle({
    ...base,
    exercises: [makeExercise({ primaryMuscleIds: [] })]
  })
  assert.ok(noPrimary.some((i) => i.includes('没有主肌群')))

  const noEquipment = validateBundle({
    ...base,
    exercises: [makeExercise({ equipmentIds: [] })]
  })
  assert.ok(noEquipment.some((i) => i.includes('没有器械')))
})

test('validateBundle 拦下空 nameEn（英文界面退化的根因）', function () {
  const bundle = {
    muscles: [{ muscleId: 'muscle_chest', nameZh: '胸部', nameEn: '', region: 'upper' }],
    equipment: [{ equipmentId: 'eq_barbell', nameZh: '杠铃', nameEn: 'Barbell' }],
    exercises: [makeExercise()]
  }
  const issues = validateBundle(bundle)
  assert.ok(
    issues.some((i) => i.includes('muscle_chest') && i.includes('nameEn')),
    `应报空 nameEn，实际：${JSON.stringify(issues)}`
  )
})

// ── loadPreservedNameEn ────────────────────────────────────────────

test('loadPreservedNameEn 对不存在的资产返回空映射（首次同步不报错）', function () {
  const preserved = loadPreservedNameEn('/nonexistent/path/exercise-content.json')
  assert.deepEqual(preserved, { muscles: {}, equipment: {} })
})

// ── selectJsonlFiles ───────────────────────────────────────────────

test('selectJsonlFiles 返回鸿蒙端三个内容源路径', function () {
  const files = selectJsonlFiles('/tmp/content')
  assert.ok(files.muscles.endsWith('muscles.zh-CN.jsonl'))
  assert.ok(files.equipment.endsWith('equipment.zh-CN.jsonl'))
  assert.ok(files.exercises.endsWith('exercises.zh-CN.jsonl'))
})

// ── 幂等性（产物稳定性） ───────────────────────────────────────────

test('同一输入重复构建产出字节相同的包（幂等）', function () {
  const preserved = {
    muscles: { muscle_chest: 'Chest', muscle_back: 'Back' },
    equipment: { eq_barbell: 'Barbell', eq_kettlebell: 'Kettlebell' }
  }
  const first = buildAndroidBundle(HARMONY_MUSCLES, HARMONY_EQUIPMENT, [makeExercise()], preserved)
  const second = buildAndroidBundle(HARMONY_MUSCLES, HARMONY_EQUIPMENT, [makeExercise()], preserved)
  assert.equal(JSON.stringify(first), JSON.stringify(second))
})

// ── compareTwoEnds（双端一致性） ────────────────────────────────────

test('compareTwoEnds 对一致的双端返回空差异', function () {
  const harmony = [makeExercise({ exerciseId: 'ex_a' }), makeExercise({ exerciseId: 'ex_b' })]
  const android = { exercises: [{ exerciseId: 'ex_a' }, { exerciseId: 'ex_b' }] }
  const diff = compareTwoEnds(harmony, android)
  assert.equal(diff.harmonyCount, 2)
  assert.equal(diff.androidCount, 2)
  assert.deepEqual(diff.onlyInHarmony, [])
  assert.deepEqual(diff.onlyInAndroid, [])
})

test('compareTwoEnds 报出 Android 缺失的动作（漂移方向）', function () {
  const harmony = [makeExercise({ exerciseId: 'ex_a' }), makeExercise({ exerciseId: 'ex_new' })]
  const android = { exercises: [{ exerciseId: 'ex_a' }] }
  const diff = compareTwoEnds(harmony, android)
  assert.deepEqual(diff.onlyInHarmony, ['ex_new'])
  assert.deepEqual(diff.onlyInAndroid, [])
})

test('compareTwoEnds 报出 Android 侧的陈旧多余动作', function () {
  const harmony = [makeExercise({ exerciseId: 'ex_a' })]
  const android = { exercises: [{ exerciseId: 'ex_a' }, { exerciseId: 'ex_stale' }] }
  const diff = compareTwoEnds(harmony, android)
  assert.deepEqual(diff.onlyInHarmony, [])
  assert.deepEqual(diff.onlyInAndroid, ['ex_stale'])
})

test('compareTwoEnds 容错缺少 exercises 字段的资产', function () {
  const diff = compareTwoEnds([makeExercise({ exerciseId: 'ex_a' })], {})
  assert.equal(diff.androidCount, 0)
  assert.deepEqual(diff.onlyInHarmony, ['ex_a'])
})

test('第二次同步时保留的是第一次产出的 nameEn（可重复执行）', function () {
  // 模拟：第一次同步把回退值写入资产，第二次同步应把它当既有值保留
  const first = buildAndroidBundle(
    HARMONY_MUSCLES,
    HARMONY_EQUIPMENT,
    [makeExercise()],
    { muscles: {}, equipment: {} }
  )
  const preservedFromFirst = {
    muscles: Object.fromEntries(first.muscles.map((m) => [m.muscleId, m.nameEn])),
    equipment: Object.fromEntries(first.equipment.map((e) => [e.equipmentId, e.nameEn]))
  }
  const second = buildAndroidBundle(
    HARMONY_MUSCLES,
    HARMONY_EQUIPMENT,
    [makeExercise()],
    preservedFromFirst
  )
  assert.equal(JSON.stringify(second), JSON.stringify(first))
})
