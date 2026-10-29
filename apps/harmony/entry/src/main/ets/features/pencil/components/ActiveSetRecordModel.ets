/**
 * ActiveSetRecordModel —— 训练执行页（ActiveContent）的「按动作分组的组记录」展示模型。
 *
 * 训练页的记录不能是一条贯穿全场的扁平列表：每个动作单独成组，组号在动作内从 1 起。
 * 否则做完第二个动作后，第 5、6 条记录和第 1、2 条长得一模一样，用户无从判断哪些组属于哪个动作。
 *
 * 页面实际渲染的是「当前动作」这一组（buildCurrentRecordGroups）：训练页同一时刻只聚焦
 * 正在练的动作，上一动作的记录不再与当前动作的组混排在同一条列表里。
 *
 * 分组键用 plannedExerciseId（计划内的动作实例 id），不用动作名：同一动作在一天里
 * 出现两次时名字相同但归属不同，按名字合并会把两组记录混在一起。
 *
 * 数据来源是 activeState（唯一真源），不是「点击时增量追加的 UI 状态」：
 * 设备实测暴露过增量方案的缺陷——连做 4 组后页面只显示 1 组（@State 增量赋值被吞），
 * 而 activeState 里 4 组都在。派生方案让展示与落库数据永远同源。
 */
import {
  ActiveWorkoutExercise,
  ActiveWorkoutSetEntry
} from '../../../shared/services/ActiveWorkoutService'

/** 一组已完成记录。setNumber 是「动作内」组号（1 起）；全场进度由调用方的全局计数维护。 */
export interface ActiveSetRecord {
  setNumber: number
  weight: number
  reps: number
}

/** 一个动作的记录分组：动作名 + 该动作已完成的组，按组序。 */
export interface ActiveExerciseRecordGroup {
  plannedExerciseId: string
  exerciseName: string
  sets: ActiveSetRecord[]
}

export function createActiveSetRecord(setNumber: number, weight: number, reps: number): ActiveSetRecord {
  const record: ActiveSetRecord = {
    setNumber: setNumber,
    weight: weight,
    reps: reps
  }
  return record
}

function parsePositiveNumber(text: string): number {
  if (text.length === 0) {
    return 0
  }
  const value: number = Number(text)
  if (Number.isNaN(value) || value < 0) {
    return 0
  }
  return value
}

/**
 * 从活跃训练态派生分组记录（全部动作）。
 *
 * 只收「已录完的正式组」（isComplete 且非热身），组号用条目下标 +1——与
 * ActiveWorkoutService 的完成判定同口径，因此页面显示的组数永远等于会话落库的组数。
 * 没有已完成组的动作不产生分组（避免空分组占位）。
 */
export function buildRecordGroups(exercises: ActiveWorkoutExercise[]): ActiveExerciseRecordGroup[] {
  const groups: ActiveExerciseRecordGroup[] = []
  for (let index = 0; index < exercises.length; index++) {
    const group: ActiveExerciseRecordGroup | undefined = buildExerciseRecordGroup(exercises[index])
    if (group !== undefined) {
      groups.push(group)
    }
  }
  return groups
}

/**
 * 只派生「当前动作」的记录分组（0 或 1 个）。
 *
 * 训练页的记录区显示当前动作的记录：切到下一个动作后，上一动作的组不再留在列表里，
 * 组号与页面上「第 N 组」（动作内序号）始终属于同一个动作。
 * 当前动作还没有已完成的正式组时返回空数组，由页面显示空态提示。
 */
export function buildCurrentRecordGroups(exercises: ActiveWorkoutExercise[]): ActiveExerciseRecordGroup[] {
  const groups: ActiveExerciseRecordGroup[] = []
  const currentIndex: number = findCurrentExerciseIndex(exercises)
  if (currentIndex < 0) {
    return groups
  }
  const group: ActiveExerciseRecordGroup | undefined = buildExerciseRecordGroup(exercises[currentIndex])
  if (group !== undefined) {
    groups.push(group)
  }
  return groups
}

/**
 * 当前动作在 exercises 中的下标：首个未录满的动作。
 *
 * 与 ActiveWorkoutService.nextExercise 同口径——「完成本组」写的就是这个动作的下一组，
 * 因此记录区显示的动作永远等于用户正在填的那个动作。全部录满时取最后一个动作；
 * 没有动作返回 -1。
 */
function findCurrentExerciseIndex(exercises: ActiveWorkoutExercise[]): number {
  for (let index = 0; index < exercises.length; index++) {
    const exercise: ActiveWorkoutExercise = exercises[index]
    if (exercise.completedSets < exercise.targetSets) {
      return index
    }
  }
  return exercises.length - 1
}

/** 单个动作的记录分组；该动作没有已完成的正式组时返回 undefined。 */
/**
 * 首个未录满动作的下标；全部录满返回 -1。
 *
 * 供训练页初始化胶囊选中态，以及「当前动作刚录满 → 自动前进到下一个动作」使用。
 * 与 findCurrentExerciseIndex 的差别：后者在全部录满时回落最后一个动作，这里返回 -1
 * 让调用方能区分「还有一个动作要做」与「全部做完了」。
 */
export function findUnfinishedExerciseIndex(exercises: ActiveWorkoutExercise[]): number {
  for (let index = 0; index < exercises.length; index++) {
    if (exercises[index].completedSets < exercises[index].targetSets) {
      return index
    }
  }
  return -1
}

/**
 * 按 plannedExerciseId 派生记录分组（0 或 1 个）。
 *
 * 训练页顶部有动作切换胶囊后，「当前动作」不再只能由「首个未录满」推导——
 * 用户可能正停在第三个动作上补录。记录区必须以选中动作为准，否则会显示另一个动作的组。
 * 该动作还没有已完成的正式组时返回空数组（页面显示空态）。
 */
export function buildRecordGroupFor(
  exercises: ActiveWorkoutExercise[],
  plannedExerciseId: string
): ActiveExerciseRecordGroup[] {
  const groups: ActiveExerciseRecordGroup[] = []
  for (let index = 0; index < exercises.length; index++) {
    if (exercises[index].plannedExerciseId !== plannedExerciseId) {
      continue
    }
    const group: ActiveExerciseRecordGroup | undefined = buildExerciseRecordGroup(exercises[index])
    if (group === undefined) {
      return groups
    }
    groups.push(group)
    return groups
  }
  return groups
}

function buildExerciseRecordGroup(exercise: ActiveWorkoutExercise): ActiveExerciseRecordGroup | undefined {
  const sets: ActiveSetRecord[] = []
  for (let setIndex = 0; setIndex < exercise.sets.length; setIndex++) {
    const entry: ActiveWorkoutSetEntry = exercise.sets[setIndex]
    if (!entry.isComplete || entry.isWarmup) {
      continue
    }
    sets.push(createActiveSetRecord(
      setIndex + 1,
      parsePositiveNumber(entry.weightText),
      parsePositiveNumber(entry.repsText)
    ))
  }
  if (sets.length === 0) {
    return undefined
  }
  const group: ActiveExerciseRecordGroup = {
    plannedExerciseId: exercise.plannedExerciseId,
    exerciseName: exercise.name,
    sets: sets
  }
  return group
}

/** 全场已记录组数（跨分组求和），用于和总组数比对是否收尾。 */
export function countRecordedSets(groups: ActiveExerciseRecordGroup[]): number {
  let total: number = 0
  for (let index = 0; index < groups.length; index++) {
    total += groups[index].sets.length
  }
  return total
}
