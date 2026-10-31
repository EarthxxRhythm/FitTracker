/**
 * ActiveWorkoutDraftMapper - 训练中状态（ActiveWorkoutState）与可恢复草稿（WorkoutDraftSnapshot）的双向映射。
 *
 * 为什么需要这一层：两套结构是两个时期的口径，字段并不对齐——
 * - ActiveWorkoutExercise 有 plannedExerciseId（组记录分组键）与 intensityNote，草稿没有；
 * - 草稿有 planName / dayLabel / startedAt / updatedAt，训练态没有。
 * 直接互相赋值会静默丢字段，恢复后表现为「记录区空了」或「动作名错位」。
 *
 * 派生字段（completedSets / currentExerciseName / currentExerciseSetProgress）在恢复时
 * 一律交给 ActiveWorkoutService.createStateWithProgress 重算，不信任草稿里的冗余值——
 * 草稿是旧版本写的，重算口径永远跟随当前服务实现。
 */
import {
  WorkoutDraftSnapshot,
  WorkoutExerciseDraft,
  WorkoutSetDraft
} from '../../common/services/WorkoutDraftService'
import ActiveWorkoutService, {
  ActiveWorkoutExercise,
  ActiveWorkoutSetEntry,
  ActiveWorkoutState
} from './ActiveWorkoutService'

/**
 * 训练态 → 草稿。
 *
 * [planName] / [dayLabel] 由调用方给：训练态里没有这两个展示字段（title 是动作标题，
 * 不是计划名）。**dayLabel 槽位承载的是训练日标识（ActiveWorkoutState.dayId）**——
 * 草稿结构没有独立的 dayId 字段，借用该槽位让往返无损；首页不展示 dayLabel，
 * 所以不会把 id 显示给用户。
 * [startedAt] 用绝对时刻而不是「已过去的秒数」，这样恢复时能直接用 now - startedAt
 * 得到真实训练时长，跨进程也不会漂移。
 */
export function toWorkoutDraft(
  state: ActiveWorkoutState,
  planName: string,
  dayLabel: string,
  startedAt: number,
  now: number
): WorkoutDraftSnapshot {
  const exercises: WorkoutExerciseDraft[] = []
  for (let index = 0; index < state.exercises.length; index++) {
    exercises.push(toExerciseDraft(state.exercises[index]))
  }
  const snapshot: WorkoutDraftSnapshot = {
    planId: state.planId,
    planName: planName,
    dayLabel: dayLabel,
    startedAt: startedAt,
    totalTargetSets: ActiveWorkoutService.totalTargetSets(state),
    completedSets: state.completedSets,
    currentExerciseName: state.currentExerciseName,
    currentExerciseProgress: state.currentExerciseSetProgress,
    exercises: exercises,
    updatedAt: now
  }
  return snapshot
}

/**
 * 草稿 → 训练态。
 *
 * 两处字段缺口是结构性的，不是遗漏：
 * - `dayId`：草稿没有独立字段，由 dayLabel 槽位承载（见 toWorkoutDraft 注释），往返无损。
 *   若草稿来自其他写入方（dayLabel 存的是「周一」这类展示文本），dayId 会退化成一个展示词，
 *   仅影响会话的归属标注——PR 统计与训练量都走 exerciseId，不受影响。
 * - `intensityNote`：草稿不存。恢复后为空串，训练页当前并不展示该字段。
 */
export function fromWorkoutDraft(draft: WorkoutDraftSnapshot): ActiveWorkoutState {
  const exercises: ActiveWorkoutExercise[] = []
  for (let index = 0; index < draft.exercises.length; index++) {
    exercises.push(fromExerciseDraft(draft.exercises[index]))
  }
  const base: ActiveWorkoutState = {
    hasWorkout: exercises.length > 0,
    planId: draft.planId,
    dayId: draft.dayLabel,
    title: draft.planName,
    totalTargetSets: sumTargetSets(exercises),
    completedSets: 0,
    currentExerciseName: '',
    currentExerciseSetProgress: '0/0 正式组',
    exercises: exercises
  }
  // createStateWithProgress 不重算 totalTargetSets（见其实现注释），故上面先算好；
  // 其余派生字段（completedSets / 当前动作名 / 组进度文案）由它按当前口径统一重算。
  return ActiveWorkoutService.createStateWithProgress(base, exercises)
}

function toExerciseDraft(exercise: ActiveWorkoutExercise): WorkoutExerciseDraft {
  const sets: WorkoutSetDraft[] = []
  for (let index = 0; index < exercise.sets.length; index++) {
    sets.push(toSetDraft(exercise.sets[index]))
  }
  const draft: WorkoutExerciseDraft = {
    plannedExerciseId: exercise.plannedExerciseId,
    exerciseId: exercise.exerciseId,
    name: exercise.name,
    // 训练态没有肌群字段（动作卡只显示名称与组数），草稿该字段保持空串。
    targetMuscle: '',
    // 计划组数随草稿留存：提前结束后 targetSets 已收缩，只有它能还原「放弃了组」。
    plannedTargetSets: exercise.plannedTargetSets,
    targetSets: exercise.targetSets,
    targetReps: exercise.targetReps,
    completedSets: exercise.completedSets,
    sets: sets
  }
  return draft
}

function fromExerciseDraft(draft: WorkoutExerciseDraft): ActiveWorkoutExercise {
  const sets: ActiveWorkoutSetEntry[] = []
  for (let index = 0; index < draft.sets.length; index++) {
    sets.push(fromSetDraft(draft.sets[index]))
  }
  // 兜底：即便调用方跳过了 normalizeWorkoutDraft，这里也不让分组键为空。
  const plannedExerciseId: string = draft.plannedExerciseId === undefined ||
    draft.plannedExerciseId.length === 0 ? draft.exerciseId : draft.plannedExerciseId
  const exercise: ActiveWorkoutExercise = {
    plannedExerciseId: plannedExerciseId,
    exerciseId: draft.exerciseId,
    name: draft.name,
    // 与 plannedExerciseId 同一条理由：调用方跳过 normalizeWorkoutDraft 时也不能留 undefined，
    // 否则 plannedTargetSets > targetSets 恒为 false，提前结束会静默退回完成态。
    plannedTargetSets: draft.plannedTargetSets === undefined ? draft.targetSets : draft.plannedTargetSets,
    targetSets: draft.targetSets,
    targetReps: draft.targetReps,
    intensityNote: '',
    completedSets: draft.completedSets,
    sets: sets
  }
  return exercise
}

function toSetDraft(entry: ActiveWorkoutSetEntry): WorkoutSetDraft {
  const draft: WorkoutSetDraft = {
    setIndex: entry.setIndex,
    weightText: entry.weightText,
    repsText: entry.repsText,
    estimatedOneRepMax: entry.estimatedOneRepMax,
    oneRepMaxText: entry.oneRepMaxText,
    isComplete: entry.isComplete
  }
  return draft
}

function fromSetDraft(draft: WorkoutSetDraft): ActiveWorkoutSetEntry {
  // isWarmup 草稿里没有：当前训练页不建热身组（createSetEntries 一律 false），
  // 恢复成 false 与实际状态一致。若将来支持热身组，需同步在草稿结构里加该字段。
  const entry: ActiveWorkoutSetEntry = {
    setIndex: draft.setIndex,
    weightText: draft.weightText,
    repsText: draft.repsText,
    estimatedOneRepMax: draft.estimatedOneRepMax,
    oneRepMaxText: draft.oneRepMaxText,
    isWarmup: false,
    isComplete: draft.isComplete
  }
  return entry
}

function sumTargetSets(exercises: ActiveWorkoutExercise[]): number {
  let total: number = 0
  for (let index = 0; index < exercises.length; index++) {
    total += exercises[index].targetSets
  }
  return total
}
