import { describe, it, expect } from '@ohos/hypium'
import {
  ActiveExerciseRecordGroup,
  ActiveSetRecord,
  appendSetRecord,
  countRecordedSets,
  createActiveSetRecord
} from '../../../main/ets/features/pencil/components/ActiveSetRecordModel'

/**
 * ActiveSetRecordModel 纯函数契约测试。
 *
 * 覆盖「训练记录按动作分开」的核心不变量：
 * 同一动作累加到同一分组、切换动作后新建分组、同名但不同 plannedExerciseId 不合并、
 * 追加不修改原数组。分组键若退化成动作名，会把同一天出现两次的同一动作混成一组。
 */
export default function activeSetRecordModelTest(): void {
  describe('ActiveSetRecordModel', () => {
    it('空列表追加一组后得到单个分组', 0, () => {
      const empty: ActiveExerciseRecordGroup[] = []
      const groups: ActiveExerciseRecordGroup[] = appendSetRecord(empty, 'planned_1_1', '杠铃平板卧推', 1, 40, 10)

      expect(groups.length).assertEqual(1)
      expect(groups[0].plannedExerciseId).assertEqual('planned_1_1')
      expect(groups[0].exerciseName).assertEqual('杠铃平板卧推')
      expect(groups[0].sets.length).assertEqual(1)
      expect(groups[0].sets[0].setNumber).assertEqual(1)
      expect(groups[0].sets[0].weight).assertEqual(40)
      expect(groups[0].sets[0].reps).assertEqual(10)
    })

    it('同一动作的第二组并入同一分组且组号递增', 0, () => {
      let groups: ActiveExerciseRecordGroup[] = []
      groups = appendSetRecord(groups, 'planned_1_1', '杠铃平板卧推', 1, 40, 10)
      groups = appendSetRecord(groups, 'planned_1_1', '杠铃平板卧推', 2, 42, 8)

      expect(groups.length).assertEqual(1)
      expect(groups[0].sets.length).assertEqual(2)
      expect(groups[0].sets[0].setNumber).assertEqual(1)
      expect(groups[0].sets[1].setNumber).assertEqual(2)
      expect(groups[0].sets[1].weight).assertEqual(42)
      expect(groups[0].sets[1].reps).assertEqual(8)
    })

    it('切到下一个动作时新建分组，组号从 1 重新计数', 0, () => {
      let groups: ActiveExerciseRecordGroup[] = []
      groups = appendSetRecord(groups, 'planned_1_1', '杠铃平板卧推', 1, 40, 10)
      groups = appendSetRecord(groups, 'planned_1_1', '杠铃平板卧推', 2, 40, 10)
      groups = appendSetRecord(groups, 'planned_1_2', '哑铃推举', 1, 16, 12)

      expect(groups.length).assertEqual(2)
      expect(groups[0].exerciseName).assertEqual('杠铃平板卧推')
      expect(groups[0].sets.length).assertEqual(2)
      expect(groups[1].exerciseName).assertEqual('哑铃推举')
      expect(groups[1].sets.length).assertEqual(1)
      expect(groups[1].sets[0].setNumber).assertEqual(1)
      expect(countRecordedSets(groups)).assertEqual(3)
    })

    it('同名但 plannedExerciseId 不同不合并', 0, () => {
      let groups: ActiveExerciseRecordGroup[] = []
      groups = appendSetRecord(groups, 'planned_1_1', '杠铃平板卧推', 1, 40, 10)
      groups = appendSetRecord(groups, 'planned_2_1', '杠铃平板卧推', 1, 60, 6)

      expect(groups.length).assertEqual(2)
      expect(groups[0].plannedExerciseId).assertEqual('planned_1_1')
      expect(groups[1].plannedExerciseId).assertEqual('planned_2_1')
      expect(countRecordedSets(groups)).assertEqual(2)
    })

    it('追加不修改传入的原数组与组内 sets', 0, () => {
      const firstSet: ActiveSetRecord = createActiveSetRecord(1, 40, 10)
      const originalSets: ActiveSetRecord[] = [firstSet]
      const originalGroup: ActiveExerciseRecordGroup = {
        plannedExerciseId: 'planned_1_1',
        exerciseName: '杠铃平板卧推',
        sets: originalSets
      }
      const original: ActiveExerciseRecordGroup[] = [originalGroup]

      const next: ActiveExerciseRecordGroup[] = appendSetRecord(original, 'planned_1_1', '杠铃平板卧推', 2, 40, 10)

      expect(original.length).assertEqual(1)
      expect(originalSets.length).assertEqual(1)
      expect(original[0].sets.length).assertEqual(1)
      expect(next.length).assertEqual(1)
      expect(next[0].sets.length).assertEqual(2)
    })

    it('动作名为空时保留分组已有名称', 0, () => {
      let groups: ActiveExerciseRecordGroup[] = []
      groups = appendSetRecord(groups, 'planned_1_1', '杠铃平板卧推', 1, 40, 10)
      groups = appendSetRecord(groups, 'planned_1_1', '', 2, 40, 10)

      expect(groups.length).assertEqual(1)
      expect(groups[0].exerciseName).assertEqual('杠铃平板卧推')
      expect(groups[0].sets.length).assertEqual(2)
    })
  })
}
