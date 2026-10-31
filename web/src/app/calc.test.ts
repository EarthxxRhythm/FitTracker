/**
 * 计算层与训练状态机的回归测试。
 *
 * 这些断言就是「复刻得对不对」的判据：每条对应产品源码里的一个确定行为，
 * 而不是"看起来合理"。改公式前先看注释指向的锚点。
 *
 * 运行：cd web && node --test src/app/calc.test.ts
 */

import test from 'node:test'
import assert from 'node:assert/strict'

import {
  BODY_PART_KEYS,
  calculateCompletionRate,
  calculateVolume,
  countCompletedSets,
  createDaySeedFromGoal,
  createMuscleLevels,
  createMuscleRanking,
  createMuscleVolume,
  estimateOneRepMax,
  getDayNumberFromLabel,
  pickTodayDay,
  resolveDayDistance,
  resolveTodayTrainingIndex,
  resolveWeekStart,
  takeRecent
} from './calc.ts'
import type { TrainingDay, WorkoutSession, WorkoutSet } from './types.ts'
import {
  createActiveState,
  createSessionFromState,
  endExercise,
  findUnfinishedExerciseIndex,
  nextEmptySetIndex,
  nextExercise,
  recordSet,
  writeSet
} from './workout.ts'

// ── 夹具 ───────────────────────────────────────────────────────────────

function set(weight: number, reps: number, isWarmup = false, exerciseId = 'ex_squat'): WorkoutSet {
  return { setId: `s_${weight}_${reps}_${isWarmup}`, exerciseId, weight, reps, rpe: 0, isWarmup }
}

function session(startedAt: number, sets: WorkoutSet[]): WorkoutSession {
  return {
    sessionId: `sess_${startedAt}`,
    planId: 'preset_upper_lower',
    dayId: 'day_a',
    startedAt,
    endedAt: startedAt + 3600_000,
    durationSeconds: 3600,
    totalSets: countCompletedSets(sets),
    totalVolume: calculateVolume(sets),
    fatigueScore: 0,
    notes: '',
    sets
  }
}

const DAY_MS = 86_400_000

// ── R1：Epley 1RM ──────────────────────────────────────────────────────

test('R1 1RM：100kg × 5 次 = 116.67', () => {
  assert.equal(estimateOneRepMax(100, 5), 116.67)
})

test('R1 1RM：reps=1 没有特判，返回 103.33 而不是 100', () => {
  // 真机 TrainingModels.ets:426-429 只有一行公式，没有 reps===1 → weight 的边界处理。
  // 这条断言就是防止有人"顺手修好"它——那会让 web 与真机对不上。
  assert.equal(estimateOneRepMax(100, 1), 103.33)
})

test('R1 1RM：保留两位小数', () => {
  assert.equal(estimateOneRepMax(62.5, 8), 79.17)
})

// ── R2 / R3：训练量与有效组 ────────────────────────────────────────────

test('R2 训练量：热身组不计入', () => {
  const sets = [set(40, 12, true), set(60, 10), set(60, 8)]
  assert.equal(calculateVolume(sets), 60 * 10 + 60 * 8)
})

test('R3 有效组：weight=0 / reps=0 / 热身 都不算', () => {
  const sets = [set(0, 10), set(60, 0), set(40, 12, true), set(60, 10)]
  assert.equal(countCompletedSets(sets), 1)
})

// ── R4：完成率 ─────────────────────────────────────────────────────────

test('R4 完成率：边界值', () => {
  assert.equal(calculateCompletionRate(3, 0), 0)
  assert.equal(calculateCompletionRate(0, 5), 0)
  assert.equal(calculateCompletionRate(4, 5), 80)
  assert.equal(calculateCompletionRate(5, 5), 100)
})

// ── R5 / R6 / R7：肌肉分布 ─────────────────────────────────────────────

test('R5 肌肉分布按组数计数：3 组深蹲 → 腿部 5 个部位各 +3', () => {
  const sessions = [session(Date.now(), [set(60, 10), set(60, 10), set(60, 8)])]
  const volume = createMuscleVolume(sessions, () => ['muscle_legs'], 8)
  assert.equal(volume.length, 18)
  for (const part of ['quadriceps', 'hamstring', 'gluteal', 'adductors', 'calves']) {
    const index = BODY_PART_KEYS.indexOf(part as (typeof BODY_PART_KEYS)[number])
    assert.equal(volume[index], 3, `${part} 应为 3 组`)
  }
  const chestIndex = BODY_PART_KEYS.indexOf('chest')
  assert.equal(volume[chestIndex], 0)
})

test('R5 肌肉分布与重量无关：1kg×1 与 200kg×1 计数相同', () => {
  const light = createMuscleVolume([session(1, [set(1, 1)])], () => ['muscle_chest'], 8)
  const heavy = createMuscleVolume([session(1, [set(200, 1)])], () => ['muscle_chest'], 8)
  assert.deepEqual(light, heavy)
})

test('R5 只统计最近 8 次训练', () => {
  const sessions: WorkoutSession[] = []
  for (let index = 0; index < 10; index++) {
    sessions.push(session(index * DAY_MS, [set(60, 10)]))
  }
  const volume = createMuscleVolume(sessions, () => ['muscle_chest'], 8)
  const chestIndex = BODY_PART_KEYS.indexOf('chest')
  assert.equal(volume[chestIndex], 8)
})

test('R7 无训练时返回全 0 的 18 元组', () => {
  const volume = createMuscleVolume([], () => ['muscle_chest'], 8)
  assert.equal(volume.length, 18)
  assert.equal(volume.every((value) => value === 0), true)
})

test('takeRecent：按 startedAt 升序取末尾 N 条', () => {
  const sessions = [session(3 * DAY_MS, []), session(1 * DAY_MS, []), session(2 * DAY_MS, [])]
  const recent = takeRecent(sessions, 2)
  assert.deepEqual(
    recent.map((item) => item.startedAt),
    [2 * DAY_MS, 3 * DAY_MS]
  )
})

// ── R8：热力等级 ───────────────────────────────────────────────────────

test('R8 热力等级：ratio 分档', () => {
  assert.deepEqual(createMuscleLevels([0, 1, 2, 3, 4]), [0, 1, 2, 3, 4])
})

test('R8 热力等级：全 0 输入返回全 0', () => {
  assert.deepEqual(createMuscleLevels([0, 0, 0]), [0, 0, 0])
})

test('R8 热力等级：所有部位相等时全为 4 级（相对量）', () => {
  assert.deepEqual(createMuscleLevels([10, 10, 10]), [4, 4, 4])
})

// ── R9：排行稳定性 ─────────────────────────────────────────────────────

test('R9 排行：同值时下标保持原序（稳定降序）', () => {
  const levels = [4, 4, 4, 2]
  const volume = [9, 9, 9, 1]
  assert.deepEqual(createMuscleRanking(levels, volume, 'balance'), [0, 1, 2, 3])
})

test('R9 排行：balance 用组数、fatigue 用等级', () => {
  const levels = [2, 3]
  const volume = [100, 10]
  assert.deepEqual(createMuscleRanking(levels, volume, 'balance'), [0, 1])
  assert.deepEqual(createMuscleRanking(levels, volume, 'fatigue'), [1, 0])
})

// ── R10：今日训练（预置计划路径） ──────────────────────────────────────

const UPPER_LOWER: TrainingDay[] = [
  { dayLabel: '上肢A', dayOfWeek: [1], exercises: [] },
  { dayLabel: '下肢A', dayOfWeek: [2], exercises: [] },
  { dayLabel: '上肢B', dayOfWeek: [4], exercises: [] },
  { dayLabel: '下肢B', dayOfWeek: [5], exercises: [] }
]

test('R10 今日训练：周一命中上肢A', () => {
  assert.equal(resolveTodayTrainingIndex(UPPER_LOWER, 1), 0)
})

test('R10 今日训练：周三无安排 → -1（休息日）', () => {
  assert.equal(resolveTodayTrainingIndex(UPPER_LOWER, 3), -1)
})

test('R10 今日训练：无 dayOfWeek 时按 dayLabel 的「周X」兜底', () => {
  const days: TrainingDay[] = [
    { dayLabel: '周一 胸', exercises: [] },
    { dayLabel: '周四 腿', exercises: [] }
  ]
  assert.equal(resolveTodayTrainingIndex(days, 4), 1)
})

test('R10 dayLabel 解析：周五 → 5，周日 → 0，无星期 → -1', () => {
  assert.equal(getDayNumberFromLabel('周五 手臂'), 5)
  assert.equal(getDayNumberFromLabel('周日'), 0)
  assert.equal(getDayNumberFromLabel('上肢A'), -1)
})

test('R10 resolveDayDistance：今天 0、明天 1、昨天 6', () => {
  assert.equal(resolveDayDistance(UPPER_LOWER[0], 1), 0)
  assert.equal(resolveDayDistance(UPPER_LOWER[1], 1), 1)
  assert.equal(resolveDayDistance(UPPER_LOWER[3], 1), 4)
})

// ── R11：今日训练（目标生成路径） ──────────────────────────────────────

test('R11 daySeed：创建当天为 1，第 3 天为 3', () => {
  const created = new Date(2026, 0, 1, 9, 0, 0).getTime()
  assert.equal(createDaySeedFromGoal(created, created), 1)
  assert.equal(createDaySeedFromGoal(created, created + 2 * DAY_MS), 3)
})

test('R11 pickTodayDay：按种子轮转，seed<=0 归一为 1', () => {
  const days = ['A', 'B', 'C']
  assert.equal(pickTodayDay(days, 1), 'A')
  assert.equal(pickTodayDay(days, 4), 'A')
  assert.equal(pickTodayDay(days, 0), 'A')
  assert.equal(pickTodayDay([], 1), undefined)
})

// ── R15：周起点 ────────────────────────────────────────────────────────

test('R15 周起点：monday 模式下周日要退 6 天', () => {
  const sunday = new Date(2026, 10, 1, 15, 30, 0) // 2026-11-01 是周日
  assert.equal(sunday.getDay(), 0)
  const start = new Date(resolveWeekStart(sunday.getTime(), 'monday'))
  assert.equal(start.getDay(), 1)
  assert.equal(start.getDate(), 26) // 10-26 周一
  assert.equal(start.getHours(), 0)
})

test('R15 周起点：sunday 模式下周日就是当天 0 点', () => {
  const sunday = new Date(2026, 10, 1, 15, 30, 0)
  const start = new Date(resolveWeekStart(sunday.getTime(), 'sunday'))
  assert.equal(start.getDay(), 0)
  assert.equal(start.getDate(), 1)
  assert.equal(start.getHours(), 0)
})

// ── 训练状态机 ─────────────────────────────────────────────────────────

const SEEDS = [
  {
    plannedExerciseId: 'p1',
    exerciseId: 'ex_squat',
    name: '杠铃深蹲',
    targetSets: 2,
    targetReps: '8-12',
    intensityNote: ''
  },
  {
    plannedExerciseId: 'p2',
    exerciseId: 'ex_bench',
    name: '杠铃卧推',
    targetSets: 2,
    targetReps: '8-12',
    intensityNote: ''
  }
]

test('状态机：录满第一个动作后自动落到第二个动作的第 1 组', () => {
  let state = createActiveState('plan', 'day', '腿部', SEEDS)
  assert.equal(nextExercise(state)?.plannedExerciseId, 'p1')

  state = recordSet(state, '60', '10')
  state = recordSet(state, '60', '10')
  assert.equal(nextExercise(state)?.plannedExerciseId, 'p2')
  assert.equal(nextEmptySetIndex(state.exercises[1]), 0)
  assert.equal(state.completedSets, 2)
})

test('状态机：热身组不推进进度（isComplete 但非正式组）', () => {
  let state = createActiveState('plan', 'day', '腿部', SEEDS)
  state = recordSet(state, '40', '12')
  state = writeSet(state, 'p1', 0, '40', '12')
  state = writeSet(state, 'p1', 0, '40', '12')
  // 第 0 组录完后仍未标记热身 → 仍是正式组
  assert.equal(state.exercises[0].completedSets, 1)
})

test('状态机：提前结束动作把 targetSets 收缩到 completedSets', () => {
  let state = createActiveState('plan', 'day', '腿部', SEEDS)
  state = recordSet(state, '60', '10')
  assert.equal(state.totalTargetSets, 4)

  state = endExercise(state, 'p1')
  assert.equal(state.exercises[0].targetSets, 1)
  assert.equal(state.exercises[0].plannedTargetSets, 2, 'plannedTargetSets 不收缩')
  assert.equal(state.exercises[0].sets.length, 1, '未完成的空组被裁掉')
  assert.equal(state.totalTargetSets, 3)
  assert.equal(nextExercise(state)?.plannedExerciseId, 'p2')
})

test('状态机：已录满的动作调 endExercise 原样返回', () => {
  let state = createActiveState('plan', 'day', '腿部', SEEDS)
  state = recordSet(state, '60', '10')
  state = recordSet(state, '60', '10')
  const before = state
  const after = endExercise(state, 'p1')
  assert.equal(after, before)
})

test('状态机：findUnfinishedExerciseIndex 在全录满时返回 -1', () => {
  let state = createActiveState('plan', 'day', '腿部', SEEDS)
  for (let index = 0; index < 4; index++) state = recordSet(state, '60', '10')
  assert.equal(findUnfinishedExerciseIndex(state.exercises), -1)
  assert.equal(nextExercise(state), undefined)
})

test('状态机 → session：totalSets / totalVolume / notes 口径', () => {
  let state = createActiveState('plan', 'day', '腿部', SEEDS)
  state = recordSet(state, '60', '10')
  state = recordSet(state, '60', '8')
  state = endExercise(state, 'p1')
  state = recordSet(state, '40', '12')

  const started = 1_000_000
  const result = createSessionFromState('sess_1', state, started, started + 180_000)

  assert.equal(result.durationSeconds, 180)
  assert.equal(result.totalSets, 3)
  assert.equal(result.totalVolume, 60 * 10 + 60 * 8 + 40 * 12)
  assert.equal(result.notes, 'completed_sets=3;target_sets=4')
  // p1 已录满 2 组 → endExercise 原样返回（真机 :253 对已录满动作不收缩），
  // 所以 totalTargetSets 仍是 2+2=4，完成率 3/4=75%。这是真机口径，不是 bug。
  assert.equal(result.sets.length, 3)
  assert.equal(result.sets[0].setId, 'p1_set_1')
  assert.equal(result.sets[2].exerciseId, 'ex_bench')
})

test('状态机：1RM 展示取整数（与真机一致）', () => {
  const state = createActiveState('plan', 'day', '腿部', SEEDS)
  const next = writeSet(state, 'p1', 0, '60', '10')
  // 60 × (1 + 10/30) = 80 → 整数；换一组验证取整
  assert.equal(next.exercises[0].sets[0].estimatedOneRepMax, 80)
  const next2 = writeSet(state, 'p1', 0, '62.5', '8')
  assert.equal(next2.exercises[0].sets[0].estimatedOneRepMax, 79) // 79.17 → 79
})
