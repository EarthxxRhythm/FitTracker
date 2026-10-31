/**
 * 训练执行状态机——复刻 ActiveWorkoutService.ets 的推进与收缩规则。
 *
 * 为什么这些规则值得一模一样的搬：
 *  1. 「完成一组」只写**首个未录满动作**的下一组（recordSet），不依赖界面上的序号——
 *     否则第一个动作录满后组会记到错的地方。
 *  2. 「提前结束本动作」是**把 targetSets 收缩到 completedSets**（endExercise），
 *     不是加一个 endedEarly 标记；下游全部以 completedSets < targetSets 为判据，
 *     收缩后零改动跳过它。少了这个，进度胶囊会从 N 格缩成 M 格再拉宽铺满整行
 *     （真机踩过，见提交 9457c4d）。
 *  3. 展示模型从 state 派生，不做增量追加——真机曾出现「连做 4 组只显示 1 组」。
 *
 * 与产品源码的对应：apps/harmony/entry/src/main/ets/shared/services/ActiveWorkoutService.ets
 */

import { estimateOneRepMax } from './calc.ts'
import type {
  ActiveWorkoutExercise,
  ActiveWorkoutSetEntry,
  ActiveWorkoutState,
  WorkoutSession,
  WorkoutSet
} from './types'

/** 进入训练时一个动作的初始定义（来自计划日的动作清单）。 */
export interface ActiveExerciseSeed {
  plannedExerciseId: string
  exerciseId: string
  name: string
  targetSets: number
  targetReps: string
  intensityNote: string
}

// ── 组条目 ─────────────────────────────────────────────────────────────

/**
 * 建一条组记录。见 ActiveWorkoutService.ets:653-685。
 *
 * 注意 estimatedOneRepMax 用 Math.round 取**整数**——真机如此。
 * 展示文案也照抄：热身组不进 PR 与训练量。
 */
export function createSetEntry(
  setIndex: number,
  weightText: string,
  repsText: string,
  isWarmup: boolean
): ActiveWorkoutSetEntry {
  const weight = Number(weightText)
  const reps = Number(repsText)
  let estimatedOneRepMax = 0
  let oneRepMaxText = isWarmup ? '热身组不参与 PR 与训练量' : '录入重量和次数后显示 1RM'
  let isComplete = false

  if (!Number.isNaN(weight) && !Number.isNaN(reps) && weight > 0 && reps > 0) {
    estimatedOneRepMax = Math.round(estimateOneRepMax(weight, reps))
    oneRepMaxText = isWarmup
      ? '热身组已记录，不参与 PR 与训练量'
      : `参考 1RM ${estimatedOneRepMax} kg`
    isComplete = true
  }

  return { setIndex, weightText, repsText, estimatedOneRepMax, oneRepMaxText, isWarmup, isComplete }
}

function copySetEntry(entry: ActiveWorkoutSetEntry): ActiveWorkoutSetEntry {
  return { ...entry }
}

function countWorkingSets(sets: ActiveWorkoutSetEntry[]): number {
  let count = 0
  for (const entry of sets) {
    if (entry.isComplete && !entry.isWarmup) count++
  }
  return count
}

// ── 建态 ───────────────────────────────────────────────────────────────

/** 从一个计划日的动作清单建初始训练态。见 ActiveWorkoutService.ets:60-80。 */
export function createActiveState(
  planId: string,
  dayId: string,
  title: string,
  seeds: ActiveExerciseSeed[]
): ActiveWorkoutState {
  const exercises: ActiveWorkoutExercise[] = []
  let totalTargetSets = 0

  for (const seed of seeds) {
    totalTargetSets += seed.targetSets
    const sets: ActiveWorkoutSetEntry[] = []
    for (let index = 0; index < seed.targetSets; index++) {
      sets.push(createSetEntry(index, '', '', false))
    }
    exercises.push({
      plannedExerciseId: seed.plannedExerciseId,
      exerciseId: seed.exerciseId,
      name: seed.name,
      plannedTargetSets: seed.targetSets,
      targetSets: seed.targetSets,
      targetReps: seed.targetReps,
      intensityNote: seed.intensityNote,
      completedSets: 0,
      sets
    })
  }

  return deriveState({
    hasWorkout: exercises.length > 0,
    planId,
    dayId,
    title,
    totalTargetSets,
    completedSets: 0,
    currentExerciseName: '',
    currentExerciseSetProgress: '',
    exercises
  })
}

/**
 * 重算派生字段（已完成组数、当前动作名、进度文案）。
 * 见 ActiveWorkoutService.ets:84-105：**不**重算 totalTargetSets。
 */
function deriveState(state: ActiveWorkoutState): ActiveWorkoutState {
  const exercises = state.exercises.map((exercise) => ({
    ...exercise,
    completedSets: countWorkingSets(exercise.sets),
    sets: exercise.sets.map(copySetEntry)
  }))
  const current = findCurrentExercise(exercises)
  let completedSets = 0
  for (const exercise of exercises) completedSets += exercise.completedSets

  return {
    ...state,
    exercises,
    completedSets,
    currentExerciseName: current?.name ?? '',
    currentExerciseSetProgress: current
      ? `${current.completedSets}/${current.targetSets} 正式组`
      : '0/0 正式组'
  }
}

/** 首个未录满的动作；全录满时回落最后一个动作。见 ActiveWorkoutService.ets:440-455。 */
function findCurrentExercise(exercises: ActiveWorkoutExercise[]): ActiveWorkoutExercise | undefined {
  for (const exercise of exercises) {
    if (exercise.completedSets < exercise.targetSets) return exercise
  }
  return exercises.length === 0 ? undefined : exercises[exercises.length - 1]
}

// ── 推进查询 ───────────────────────────────────────────────────────────

/** 下一个待填组的动作；全部录满返回 undefined。见 ActiveWorkoutService.ets:133-141。 */
export function nextExercise(state: ActiveWorkoutState): ActiveWorkoutExercise | undefined {
  for (const exercise of state.exercises) {
    if (exercise.completedSets < exercise.targetSets) return exercise
  }
  return undefined
}

/** 首个未录满动作的下标；全录满 -1（用于区分「还有动作」与「全做完了」）。 */
export function findUnfinishedExerciseIndex(exercises: ActiveWorkoutExercise[]): number {
  for (let index = 0; index < exercises.length; index++) {
    if (exercises[index].completedSets < exercises[index].targetSets) return index
  }
  return -1
}

/** 动作内首个未填组的下标；全填完 -1。热身组按「已填」处理。见 ActiveWorkoutService.ets:226-233。 */
export function nextEmptySetIndex(exercise: ActiveWorkoutExercise): number {
  for (let index = 0; index < exercise.sets.length; index++) {
    if (!exercise.sets[index].isComplete) return index
  }
  return -1
}

/** 全场进度 0–1（收缩后的总组数为分母）。 */
export function workoutProgress(state: ActiveWorkoutState): number {
  const total = state.totalTargetSets
  if (total <= 0) return 0
  return Math.min(1, state.completedSets / total)
}

// ── 写入 ───────────────────────────────────────────────────────────────

function replaceExercise(
  exercises: ActiveWorkoutExercise[],
  plannedExerciseId: string,
  next: ActiveWorkoutExercise
): ActiveWorkoutExercise[] {
  return exercises.map((exercise) =>
    exercise.plannedExerciseId === plannedExerciseId ? next : { ...exercise, sets: exercise.sets.map(copySetEntry) }
  )
}

function withSetEntry(
  exercise: ActiveWorkoutExercise,
  setIndex: number,
  weightText: string,
  repsText: string,
  isWarmup: boolean
): ActiveWorkoutExercise {
  const sets = exercise.sets.map((entry) =>
    entry.setIndex === setIndex ? createSetEntry(setIndex, weightText, repsText, isWarmup) : copySetEntry(entry)
  )
  return { ...exercise, sets, completedSets: countWorkingSets(sets) }
}

/** 记录一组到指定动作的指定组号（界面直接编辑某一组时用）。 */
export function writeSet(
  state: ActiveWorkoutState,
  plannedExerciseId: string,
  setIndex: number,
  weightText: string,
  repsText: string
): ActiveWorkoutState {
  const target = state.exercises.find((exercise) => exercise.plannedExerciseId === plannedExerciseId)
  if (!target) return state
  const entry = target.sets.find((item) => item.setIndex === setIndex)
  const next = withSetEntry(target, setIndex, weightText, repsText, entry?.isWarmup ?? false)
  return deriveState({ ...state, exercises: replaceExercise(state.exercises, plannedExerciseId, next) })
}

/** 切换热身组标记。见 ActiveWorkoutService.ets:391-410。 */
export function writeWarmup(
  state: ActiveWorkoutState,
  plannedExerciseId: string,
  setIndex: number,
  isWarmup: boolean
): ActiveWorkoutState {
  const target = state.exercises.find((exercise) => exercise.plannedExerciseId === plannedExerciseId)
  if (!target) return state
  const entry = target.sets.find((item) => item.setIndex === setIndex)
  if (!entry) return state
  const next = withSetEntry(target, setIndex, entry.weightText, entry.repsText, isWarmup)
  return deriveState({ ...state, exercises: replaceExercise(state.exercises, plannedExerciseId, next) })
}

/**
 * 记录一组：写「首个未录满动作」的第 completedSets 组，返回推进后的 state。
 * 见 ActiveWorkoutService.ets:190-207。全部录满时原样返回。
 */
export function recordSet(
  state: ActiveWorkoutState,
  weightText: string,
  repsText: string
): ActiveWorkoutState {
  const exercise = nextExercise(state)
  if (!exercise) return state
  return writeSet(state, exercise.plannedExerciseId, exercise.completedSets, weightText, repsText)
}

/**
 * 记录一组到界面选中的动作（顶部动作胶囊切换后走这条）。
 * 见 ActiveWorkoutService.ets:215-240：目标动作没有空组时原样返回。
 */
export function recordSetFor(
  state: ActiveWorkoutState,
  plannedExerciseId: string,
  weightText: string,
  repsText: string
): ActiveWorkoutState {
  const target = state.exercises.find((exercise) => exercise.plannedExerciseId === plannedExerciseId)
  if (!target) return state
  const setIndex = nextEmptySetIndex(target)
  if (setIndex < 0) return state
  return writeSet(state, plannedExerciseId, setIndex, weightText, repsText)
}

/** 给某动作追加一组空记录（「加一组」）。见 ActiveWorkoutService.ets:412-430。 */
export function addSet(state: ActiveWorkoutState, plannedExerciseId: string): ActiveWorkoutState {
  const target = state.exercises.find((exercise) => exercise.plannedExerciseId === plannedExerciseId)
  if (!target) return state
  let nextIndex = target.sets.length
  for (const entry of target.sets) {
    if (entry.setIndex >= nextIndex) nextIndex = entry.setIndex + 1
  }
  const sets = [...target.sets.map(copySetEntry), createSetEntry(nextIndex, '', '', false)]
  const next: ActiveWorkoutExercise = {
    ...target,
    sets,
    completedSets: countWorkingSets(sets)
  }
  return deriveState({ ...state, exercises: replaceExercise(state.exercises, plannedExerciseId, next) })
}

/**
 * 提前结束本动作：把 targetSets 收缩到 completedSets，sets 裁到已完成部分。
 * 见 ActiveWorkoutService.ets:243-262。已录满时原样返回同一引用。
 */
export function endExercise(state: ActiveWorkoutState, plannedExerciseId: string): ActiveWorkoutState {
  const target = state.exercises.find((exercise) => exercise.plannedExerciseId === plannedExerciseId)
  if (!target) return state
  if (target.completedSets >= target.targetSets) return state

  const kept: ActiveWorkoutSetEntry[] = []
  for (let index = 0; index < target.sets.length; index++) {
    if (index < target.completedSets) kept.push(copySetEntry(target.sets[index]))
  }
  const next: ActiveWorkoutExercise = {
    ...target,
    targetSets: target.completedSets,
    sets: kept,
    completedSets: countWorkingSets(kept)
  }
  const exercises = replaceExercise(state.exercises, plannedExerciseId, next)
  let totalTargetSets = 0
  for (const exercise of exercises) totalTargetSets += exercise.targetSets
  return deriveState({ ...state, totalTargetSets, exercises })
}

// ── 收尾 ───────────────────────────────────────────────────────────────

/**
 * 训练态 → 落库 session。
 * 见 ActiveWorkoutService.ets:107-131、:726-780：
 *  - 只收 isComplete 的组（热身也落库，但训练量排除）
 *  - totalSets = 有效正式组数（不是全部组数）
 *  - notes 内嵌 completed_sets / target_sets，摘要页靠它还原计划组数
 */
export function createSessionFromState(
  sessionId: string,
  state: ActiveWorkoutState,
  startedAt: number,
  endedAt: number
): WorkoutSession {
  const sets: WorkoutSet[] = []
  for (const exercise of state.exercises) {
    for (const entry of exercise.sets) {
      if (!entry.isComplete) continue
      sets.push({
        setId: `${exercise.plannedExerciseId}_set_${entry.setIndex + 1}`,
        exerciseId: exercise.exerciseId,
        weight: parsePositiveNumber(entry.weightText),
        reps: Math.floor(parsePositiveNumber(entry.repsText)),
        rpe: 0,
        isWarmup: entry.isWarmup
      })
    }
  }

  let completedSets = 0
  for (const set of sets) {
    if (set.weight > 0 && set.reps > 0 && !set.isWarmup) completedSets++
  }

  const durationSeconds = endedAt <= startedAt ? 0 : Math.floor((endedAt - startedAt) / 1000)

  return {
    sessionId,
    planId: state.planId,
    dayId: state.dayId,
    startedAt,
    endedAt,
    durationSeconds,
    totalSets: completedSets,
    totalVolume: calculateSessionVolume(sets),
    fatigueScore: 0,
    sessionRpe: 0,
    notes: `completed_sets=${completedSets};target_sets=${state.totalTargetSets}`,
    sets
  }
}

function parsePositiveNumber(value: string): number {
  const parsed = Number(value)
  if (Number.isNaN(parsed) || parsed <= 0) return 0
  return parsed
}

/** 训练量两位小数。见 ActiveWorkoutService.ets:757-768。 */
function calculateSessionVolume(sets: WorkoutSet[]): number {
  let total = 0
  for (const set of sets) {
    if (!set.isWarmup) total += set.weight * set.reps
  }
  return Math.round(total * 100) / 100
}

// ── 展示模型 ───────────────────────────────────────────────────────────

export interface ActiveSetRecord {
  setNumber: number
  weight: number
  reps: number
}

export interface ActiveExerciseRecordGroup {
  plannedExerciseId: string
  exerciseName: string
  sets: ActiveSetRecord[]
}

/**
 * 当前动作的已完成记录（0 或 1 组）。
 * 见 ActiveSetRecordModel.ets:buildRecordGroupFor：组号是**动作内**序号，
 * 只收已完成的正式组——所以页面显示的组数永远等于落库组数。
 */
export function buildRecordGroupFor(
  exercises: ActiveWorkoutExercise[],
  plannedExerciseId: string
): ActiveExerciseRecordGroup[] {
  const target = exercises.find((exercise) => exercise.plannedExerciseId === plannedExerciseId)
  if (!target) return []
  const sets: ActiveSetRecord[] = []
  for (let index = 0; index < target.sets.length; index++) {
    const entry = target.sets[index]
    if (!entry.isComplete || entry.isWarmup) continue
    sets.push({
      setNumber: index + 1,
      weight: parsePositiveNumber(entry.weightText),
      reps: parsePositiveNumber(entry.repsText)
    })
  }
  if (sets.length === 0) return []
  return [{ plannedExerciseId, exerciseName: target.name, sets }]
}
