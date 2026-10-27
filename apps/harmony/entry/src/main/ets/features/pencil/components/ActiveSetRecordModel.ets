/**
 * ActiveSetRecordModel —— 训练执行页（ActiveContent）的「按动作分组的组记录」展示模型。
 *
 * 训练页的记录不能是一条贯穿全场的扁平列表：每录满一组就追加到该动作自己的分组里，
 * 动作录满切到下一个动作时，新组落到新分组。否则做完第二个动作后，第 5、6 条记录
 * 和第 1、2 条长得一模一样，用户无从判断哪些组属于哪个动作。
 *
 * 分组键用 plannedExerciseId（计划内的动作实例 id），不用动作名：同一动作在一天里
 * 出现两次时名字相同但归属不同，按名字合并会把两组记录混在一起。
 */

/** 一组已完成记录。setNumber 是「动作内」组号（1 起）；全场进度由调用方的全局计数维护。 */
export interface ActiveSetRecord {
  setNumber: number
  weight: number
  reps: number
}

/** 一个动作的记录分组：动作名 + 该动作已完成的组，按完成顺序。 */
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

/**
 * 追加一组记录：命中同一 plannedExerciseId 的分组就并入，否则在末尾新建分组。
 *
 * 返回新数组（原数组与其中的 sets 都不被修改），供 @State 整体替换触发刷新。
 * [exerciseName] 传空时保留分组已有的名字——调用方拿不到名称时不该把分组名清空。
 */
export function appendSetRecord(
  groups: ActiveExerciseRecordGroup[],
  plannedExerciseId: string,
  exerciseName: string,
  setNumber: number,
  weight: number,
  reps: number
): ActiveExerciseRecordGroup[] {
  const next: ActiveExerciseRecordGroup[] = []
  let matched: boolean = false
  for (let index = 0; index < groups.length; index++) {
    const group: ActiveExerciseRecordGroup = groups[index]
    if (group.plannedExerciseId === plannedExerciseId) {
      const sets: ActiveSetRecord[] = group.sets.slice()
      sets.push(createActiveSetRecord(setNumber, weight, reps))
      const merged: ActiveExerciseRecordGroup = {
        plannedExerciseId: group.plannedExerciseId,
        exerciseName: exerciseName.length > 0 ? exerciseName : group.exerciseName,
        sets: sets
      }
      next.push(merged)
      matched = true
    } else {
      next.push(group)
    }
  }
  if (!matched) {
    const sets: ActiveSetRecord[] = [createActiveSetRecord(setNumber, weight, reps)]
    const created: ActiveExerciseRecordGroup = {
      plannedExerciseId: plannedExerciseId,
      exerciseName: exerciseName,
      sets: sets
    }
    next.push(created)
  }
  return next
}

/** 全场已记录组数（跨分组求和），用于和总组数比对是否收尾。 */
export function countRecordedSets(groups: ActiveExerciseRecordGroup[]): number {
  let total: number = 0
  for (let index = 0; index < groups.length; index++) {
    total += groups[index].sets.length
  }
  return total
}
