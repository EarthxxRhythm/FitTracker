/**
 * ActiveSetRecordModel —— 训练执行页（ActiveContent）的「按动作分组的组记录」展示模型。
 *
 * 训练页的记录不能是一条贯穿全场的扁平列表：每个动作单独成组，组号在动作内从 1 起。
 * 否则做完第二个动作后，第 5、6 条记录和第 1、2 条长得一模一样，用户无从判断哪些组属于哪个动作。
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
 * 从活跃训练态派生分组记录。
 *
 * 只收「已录完的正式组」（isComplete 且非热身），组号用条目下标 +1——与
 * ActiveWorkoutService 的完成判定同口径，因此页面显示的组数永远等于会话落库的组数。
 * 没有已完成组的动作不产生分组（避免空分组占位）。
 */
export function buildRecordGroups(exercises: ActiveWorkoutExercise[]): ActiveExerciseRecordGroup[] {
  const groups: ActiveExerciseRecordGroup[] = []
  for (let index = 0; index < exercises.length; index++) {
    const exercise: ActiveWorkoutExercise = exercises[index]
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
    if (sets.length > 0) {
      const group: ActiveExerciseRecordGroup = {
        plannedExerciseId: exercise.plannedExerciseId,
        exerciseName: exercise.name,
        sets: sets
      }
      groups.push(group)
    }
  }
  return groups
}

/** 全场已记录组数（跨分组求和），用于和总组数比对是否收尾。 */
export function countRecordedSets(groups: ActiveExerciseRecordGroup[]): number {
  let total: number = 0
  for (let index = 0; index < groups.length; index++) {
    total += groups[index].sets.length
  }
  return total
}
