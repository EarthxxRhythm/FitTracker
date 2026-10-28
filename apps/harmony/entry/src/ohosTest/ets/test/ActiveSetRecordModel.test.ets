import { describe, it, expect } from '@ohos/hypium'
import {
  ActiveExerciseRecordGroup,
  buildRecordGroups,
  countRecordedSets
} from '../../../main/ets/features/pencil/components/ActiveSetRecordModel'
import {
  ActiveWorkoutExercise,
  ActiveWorkoutSetEntry
} from '../../../main/ets/shared/services/ActiveWorkoutService'

/**
 * ActiveSetRecordModel 纯函数契约测试。
 *
 * 覆盖「训练记录按动作分开」的核心不变量：
 * 只收已录完的正式组、组号在动作内从 1 起、跨动作各自成组、热身组不计入、
 * 没有完成组的动作不产生空分组。
 *
 * 诞生背景：增量维护 UI 状态的写法在设备上连做 4 组只显示 1 组（activeState 里 4 组都在），
 * 改为从 activeState 派生后，展示与落库同源。
 */

function mkSet(setIndex: number, weightText: string, repsText: string,
  isComplete: boolean, isWarmup: boolean): ActiveWorkoutSetEntry {
  const entry: ActiveWorkoutSetEntry = {
    setIndex: setIndex,
    weightText: weightText,
    repsText: repsText,
    estimatedOneRepMax: 0,
    oneRepMaxText: '',
    isWarmup: isWarmup,
    isComplete: isComplete
  }
  return entry
}

function mkExercise(plannedExerciseId: string, name: string,
  sets: ActiveWorkoutSetEntry[]): ActiveWorkoutExercise {
  const exercise: ActiveWorkoutExercise = {
    plannedExerciseId: plannedExerciseId,
    exerciseId: 'ex_' + plannedExerciseId,
    name: name,
    targetSets: sets.length,
    targetReps: '8-12',
    intensityNote: '',
    completedSets: 0,
    sets: sets
  }
  return exercise
}

export default function activeSetRecordModelTest(): void {
  describe('ActiveSetRecordModel', () => {
    it('空训练态返回空分组', 0, () => {
      const groups: ActiveExerciseRecordGroup[] = buildRecordGroups([])
      expect(groups.length).assertEqual(0)
      expect(countRecordedSets(groups)).assertEqual(0)
    })

    it('只收已录完的正式组，组号从 1 起', 0, () => {
      const sets: ActiveWorkoutSetEntry[] = [
        mkSet(0, '40', '10', true, false),
        mkSet(1, '42', '8', true, false),
        mkSet(2, '', '', false, false)
      ]
      const groups: ActiveExerciseRecordGroup[] = buildRecordGroups([mkExercise('planned_1_1', '杠铃平板卧推', sets)])

      expect(groups.length).assertEqual(1)
      expect(groups[0].plannedExerciseId).assertEqual('planned_1_1')
      expect(groups[0].exerciseName).assertEqual('杠铃平板卧推')
      expect(groups[0].sets.length).assertEqual(2)
      expect(groups[0].sets[0].setNumber).assertEqual(1)
      expect(groups[0].sets[0].weight).assertEqual(40)
      expect(groups[0].sets[1].setNumber).assertEqual(2)
      expect(groups[0].sets[1].reps).assertEqual(8)
    })

    it('连做多组全部计入（回归：曾只显示 1 组）', 0, () => {
      const sets: ActiveWorkoutSetEntry[] = [
        mkSet(0, '20', '8', true, false),
        mkSet(1, '20', '8', true, false),
        mkSet(2, '20', '8', true, false),
        mkSet(3, '20', '8', true, false)
      ]
      const groups: ActiveExerciseRecordGroup[] = buildRecordGroups([mkExercise('planned_1_1', '杠铃深蹲', sets)])

      expect(groups.length).assertEqual(1)
      expect(groups[0].sets.length).assertEqual(4)
      expect(countRecordedSets(groups)).assertEqual(4)
      expect(groups[0].sets[3].setNumber).assertEqual(4)
    })

    it('跨动作各自成组，组号从 1 重新计数', 0, () => {
      const first: ActiveWorkoutExercise = mkExercise('planned_1_1', '杠铃深蹲', [
        mkSet(0, '40', '10', true, false),
        mkSet(1, '40', '10', true, false)
      ])
      const second: ActiveWorkoutExercise = mkExercise('planned_1_2', '罗马尼亚硬拉', [
        mkSet(0, '60', '8', true, false)
      ])
      const groups: ActiveExerciseRecordGroup[] = buildRecordGroups([first, second])

      expect(groups.length).assertEqual(2)
      expect(groups[0].exerciseName).assertEqual('杠铃深蹲')
      expect(groups[0].sets.length).assertEqual(2)
      expect(groups[1].exerciseName).assertEqual('罗马尼亚硬拉')
      expect(groups[1].sets.length).assertEqual(1)
      expect(groups[1].sets[0].setNumber).assertEqual(1)
      expect(countRecordedSets(groups)).assertEqual(3)
    })

    it('热身组不计入记录', 0, () => {
      const sets: ActiveWorkoutSetEntry[] = [
        mkSet(0, '20', '15', true, true),
        mkSet(1, '40', '10', true, false)
      ]
      const groups: ActiveExerciseRecordGroup[] = buildRecordGroups([mkExercise('planned_1_1', '杠铃深蹲', sets)])

      expect(groups[0].sets.length).assertEqual(1)
      expect(groups[0].sets[0].setNumber).assertEqual(2)
      expect(groups[0].sets[0].weight).assertEqual(40)
    })

    it('尚无完成组的动作不产生空分组', 0, () => {
      const done: ActiveWorkoutExercise = mkExercise('planned_1_1', '杠铃深蹲', [
        mkSet(0, '40', '10', true, false)
      ])
      const pending: ActiveWorkoutExercise = mkExercise('planned_1_2', '罗马尼亚硬拉', [
        mkSet(0, '', '', false, false)
      ])
      const groups: ActiveExerciseRecordGroup[] = buildRecordGroups([done, pending])

      expect(groups.length).assertEqual(1)
      expect(groups[0].plannedExerciseId).assertEqual('planned_1_1')
    })
  })
}
