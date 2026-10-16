// import-external-source.mjs 映射逻辑回归测试。
//
// 背景：该脚本把 free-exercise-db（Unlicense 公共领域）的英文动作数据转换成
// 菲特 内容管线的候选 JSONL。映射错误会静默污染动作库（错误的肌群/器械导致
// PlanEngine 选不出动作），所以映射表与推断逻辑必须有测试背书。
//
// 运行：node --test tools/content/import-external-source.test.mjs

import { test } from 'node:test'
import assert from 'node:assert/strict'

import {
  EQUIPMENT_MAP,
  MUSCLE_MAP,
  DIFFICULTY_MAP,
  inferGoalTags,
  toExerciseId,
  toAlias,
  mapMuscles,
  convertRecord
} from './import-external-source.mjs'

test('器械映射覆盖项目现有 6 个器械 ID，且未知器械被排除而非误映射', function () {
  // 项目 equipment.zh-CN.jsonl 中的 6 个 ID 必须都在映射值域内
  const projectIds = ['eq_barbell', 'eq_dumbbell', 'eq_cable', 'eq_machine', 'eq_bodyweight', 'eq_band']
  const mappedValues = Object.values(EQUIPMENT_MAP).filter((v) => v !== null)
  for (const id of projectIds) {
    assert.ok(mappedValues.includes(id), `映射值域缺少项目器械 ${id}`)
  }

  // 直映关系
  assert.equal(EQUIPMENT_MAP['body only'], 'eq_bodyweight')
  assert.equal(EQUIPMENT_MAP.dumbbell, 'eq_dumbbell')
  assert.equal(EQUIPMENT_MAP.barbell, 'eq_barbell')
  assert.equal(EQUIPMENT_MAP.cable, 'eq_cable')
  assert.equal(EQUIPMENT_MAP.machine, 'eq_machine')
  assert.equal(EQUIPMENT_MAP.bands, 'eq_band')

  // 归并与新增
  assert.equal(EQUIPMENT_MAP.kettlebells, 'eq_kettlebell')
  assert.equal(EQUIPMENT_MAP['e-z curl bar'], 'eq_barbell')

  // 无法匹配项目器械库的必须显式为 null（排除整条），不能落到 undefined（静默跳过）
  assert.equal(EQUIPMENT_MAP['exercise ball'], null)
  assert.equal(EQUIPMENT_MAP['medicine ball'], null)
  assert.equal(EQUIPMENT_MAP['foam roll'], null)
  assert.equal(EQUIPMENT_MAP.other, null)

  // 未列出的器械返回 undefined，convertRecord 必须据此判定为不可映射
  assert.equal(EQUIPMENT_MAP['unknown equipment'], undefined)
})

test('肌群映射把外部 17 值收敛到项目 6 个 muscleId', function () {
  const projectIds = ['muscle_chest', 'muscle_back', 'muscle_legs', 'muscle_shoulders', 'muscle_arms', 'muscle_core']
  const values = new Set(Object.values(MUSCLE_MAP))
  for (const id of projectIds) {
    assert.ok(values.has(id), `映射值域缺少项目肌群 ${id}`)
  }
  // 映射值不能超出项目肌群集合
  for (const [source, target] of Object.entries(MUSCLE_MAP)) {
    assert.ok(projectIds.includes(target), `${source} 映射到了非项目肌群 ${target}`)
  }

  // 关键归并
  assert.equal(MUSCLE_MAP.lats, 'muscle_back')
  assert.equal(MUSCLE_MAP['middle back'], 'muscle_back')
  assert.equal(MUSCLE_MAP.traps, 'muscle_back')
  assert.equal(MUSCLE_MAP.quadriceps, 'muscle_legs')
  assert.equal(MUSCLE_MAP.hamstrings, 'muscle_legs')
  assert.equal(MUSCLE_MAP.glutes, 'muscle_legs')
  assert.equal(MUSCLE_MAP.abdominals, 'muscle_core')
  assert.equal(MUSCLE_MAP.neck, 'muscle_shoulders')
})

test('mapMuscles 去重并丢弃未知值', function () {
  const result = mapMuscles(['lats', 'middle back', 'biceps', 'unknown muscle'])
  assert.deepEqual(result, ['muscle_back', 'muscle_arms'])

  assert.deepEqual(mapMuscles([]), [])
  assert.deepEqual(mapMuscles(undefined), [])
  assert.deepEqual(mapMuscles(['not-a-muscle']), [])
})

test('难度映射把 expert 折算为项目支持的 advanced', function () {
  assert.equal(DIFFICULTY_MAP.beginner, 'beginner')
  assert.equal(DIFFICULTY_MAP.intermediate, 'intermediate')
  assert.equal(DIFFICULTY_MAP.expert, 'advanced')
  assert.equal(DIFFICULTY_MAP.unknown, undefined)
})

test('inferGoalTags 对各类 category 产出项目白名单内的标签且永不为空', function () {
  const allowed = ['hypertrophy', 'strength', 'fat_loss', 'posture', 'stability']

  const cases = [
    { record: { category: 'strength', mechanic: 'compound', force: 'push' }, expect: ['strength', 'hypertrophy'] },
    { record: { category: 'strength', mechanic: 'isolation', force: 'pull' }, expect: ['strength'] },
    { record: { category: 'powerlifting', mechanic: 'compound', force: 'pull' }, expect: ['strength', 'hypertrophy'] },
    { record: { category: 'strongman', mechanic: 'compound', force: 'pull' }, expect: ['strength', 'stability'] },
    { record: { category: 'cardio', mechanic: 'compound', force: null }, expect: ['fat_loss'] },
    { record: { category: 'plyometrics', mechanic: 'compound', force: 'push' }, expect: ['fat_loss'] },
    { record: { category: 'stretching', mechanic: null, force: 'static' }, expect: ['posture', 'stability'] }
  ]

  for (const item of cases) {
    const tags = inferGoalTags(item.record)
    assert.deepEqual(tags, item.expect, `category=${item.record.category} 推断不符`)
  }

  // force=static 叠加 stability 且不重复
  const staticStrength = inferGoalTags({ category: 'strength', mechanic: 'isolation', force: 'static' })
  assert.deepEqual(staticStrength, ['strength', 'stability'])
  assert.equal(staticStrength.filter((t) => t === 'stability').length, 1, 'stability 不应重复')

  // 兜底：无任何特征时不产出空数组（校验器要求 goalTags 非空）
  const fallback = inferGoalTags({ category: 'unknown', mechanic: null, force: null })
  assert.deepEqual(fallback, ['hypertrophy'])

  // 所有输出必须落在项目白名单内
  for (const item of cases) {
    for (const tag of inferGoalTags(item.record)) {
      assert.ok(allowed.includes(tag), `推断出白名单外的标签 ${tag}`)
    }
  }
})

test('toExerciseId 与 toAlias 生成项目风格标识且处理特殊字符', function () {
  assert.equal(toExerciseId('3_4_Sit-Up'), 'ex_3_4_sit_up')
  assert.equal(toExerciseId('Barbell_Incline_Bench_Press_-_Medium_Grip'), 'ex_barbell_incline_bench_press_medium_grip')
  assert.equal(toExerciseId('Dips_-_Triceps_Version'), 'ex_dips_triceps_version')

  // 前后分隔符不应残留
  assert.equal(toExerciseId('-Leading_Dash'), 'ex_leading_dash')
  assert.equal(toExerciseId('Trailing_Dash-'), 'ex_trailing_dash')

  assert.equal(toAlias('Barbell Bench Press'), 'barbell bench press')
  assert.equal(toAlias('  Extra   Spaces  '), 'extra spaces')
})

test('convertRecord 对可映射记录产出完整项目 schema 字段', function () {
  const record = {
    id: 'Barbell_Incline_Bench_Press_-_Medium_Grip',
    name: 'Barbell Incline Bench Press - Medium Grip',
    force: 'push',
    level: 'beginner',
    mechanic: 'compound',
    equipment: 'barbell',
    primaryMuscles: ['chest'],
    secondaryMuscles: ['shoulders', 'triceps'],
    instructions: ['Lie back on an incline bench.', 'Press the bar up.'],
    category: 'strength',
    images: ['x/0.jpg']
  }

  const result = convertRecord(record)
  assert.equal(result.skipped, false)
  const item = result.item

  // 字段完整性：校验器要求的必填字段全部存在
  const requiredFields = [
    'exerciseId', 'nameZh', 'nameEn', 'aliases', 'primaryMuscleIds', 'secondaryMuscleIds',
    'equipmentIds', 'difficulty', 'goalTags', 'videoUrl', 'coverUrl', 'steps', 'cues',
    'commonMistakes', 'safetyNotes', 'alternativeExerciseIds', 'contentVersion'
  ]
  for (const field of requiredFields) {
    assert.ok(item[field] !== undefined, `缺少必填字段 ${field}`)
  }

  assert.equal(item.exerciseId, 'ex_barbell_incline_bench_press_medium_grip')
  assert.equal(item.nameEn, 'Barbell Incline Bench Press - Medium Grip')
  assert.ok(item.nameZh.startsWith('【待译】'), '源为英文，nameZh 必须标注待译')
  assert.deepEqual(item.primaryMuscleIds, ['muscle_chest'])
  assert.deepEqual(item.equipmentIds, ['eq_barbell'])
  assert.equal(item.difficulty, 'beginner')
  assert.equal(item.contentVersion, 3, '候选必须写 contentVersion=3 以触发设备重新导入')
  // 媒体字段必须为空串（校验器禁止远程 URL，此时无本地素材）
  assert.equal(item.videoUrl, '')
  assert.equal(item.coverUrl, '')
  // 源数据无这些字段，输出空数组而非缺字段
  assert.deepEqual(item.cues, [])
  assert.deepEqual(item.commonMistakes, [])
  assert.deepEqual(item.safetyNotes, [])
  assert.deepEqual(item.alternativeExerciseIds, [])
  // 溯源字段保留（合并时丢弃）
  assert.equal(item.__sourceId, 'Barbell_Incline_Bench_Press_-_Medium_Grip')
})

test('convertRecord 按不可映射原因正确跳过记录', function () {
  const base = {
    id: 'X',
    name: 'X',
    force: 'push',
    level: 'beginner',
    mechanic: 'compound',
    equipment: 'barbell',
    primaryMuscles: ['chest'],
    secondaryMuscles: [],
    instructions: ['do it'],
    category: 'strength'
  }

  // 器械显式排除（null）
  const excluded = convertRecord({ ...base, equipment: 'other' })
  assert.equal(excluded.skipped, true)
  assert.equal(excluded.reason, 'excluded_equipment:other')

  // 器械未列在映射表（undefined）
  const unknownEquip = convertRecord({ ...base, equipment: 'space suit' })
  assert.equal(unknownEquip.skipped, true)
  assert.equal(unknownEquip.reason, 'unknown_equipment:space suit')

  // 主肌群无法映射
  const noMuscle = convertRecord({ ...base, primaryMuscles: ['spleen'] })
  assert.equal(noMuscle.skipped, true)
  assert.equal(noMuscle.reason, 'no_mappable_primary_muscle')

  // 难度无法映射
  const badLevel = convertRecord({ ...base, level: 'grandmaster' })
  assert.equal(badLevel.skipped, true)
  assert.equal(badLevel.reason, 'unknown_level:grandmaster')

  // 无步骤说明
  const noSteps = convertRecord({ ...base, instructions: [] })
  assert.equal(noSteps.skipped, true)
  assert.equal(noSteps.reason, 'no_instructions')

  // 空白步骤也应视为无步骤
  const blankSteps = convertRecord({ ...base, instructions: ['  ', ''] })
  assert.equal(blankSteps.skipped, true)
  assert.equal(blankSteps.reason, 'no_instructions')
})

test('convertRecord 主肌群与次肌群不重复（次肌群剔除已出现在主肌群中的项）', function () {
  const record = {
    id: 'X',
    name: 'X',
    force: 'pull',
    level: 'intermediate',
    mechanic: 'compound',
    equipment: 'barbell',
    primaryMuscles: ['lats', 'middle back'],
    secondaryMuscles: ['lats', 'biceps'],
    instructions: ['do it'],
    category: 'strength'
  }
  const result = convertRecord(record)
  assert.equal(result.skipped, false)
  // lats 与 middle back 都映射到 muscle_back，应去重
  assert.deepEqual(result.item.primaryMuscleIds, ['muscle_back'])
  // 次肌群中的 lats 已在主肌群，应被剔除；biceps 保留
  assert.deepEqual(result.item.secondaryMuscleIds, ['muscle_arms'])
})
