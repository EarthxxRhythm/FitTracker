import { describe, it, expect } from '@ohos/hypium'
import { ExerciseContent, UserGoal, createUserGoal } from '../../../main/ets/shared/models/TrainingModels'
import ContentRepository, { ExerciseLibraryItem } from '../../../main/ets/shared/services/ContentRepository'
import PlanEngine from '../../../main/ets/shared/services/PlanEngine'

export default function contentRepositoryTest(): void {
  describe('ContentRepository', () => {
    it('returns Chinese labels for local exercise metadata', 0, () => {
      expect(ContentRepository.getMuscleName('muscle_chest')).assertEqual('胸部')
      expect(ContentRepository.getEquipmentName('eq_bodyweight')).assertEqual('徒手')
    })

    it('keeps local action library seeded with Chinese exercise detail', 0, () => {
      const exercise: ExerciseContent | undefined = ContentRepository.getExerciseById('ex_push_up')
      expect(exercise !== undefined).assertTrue()
      if (exercise !== undefined) {
        expect(exercise.nameZh).assertEqual('俯卧撑')
        expect(exercise.steps.length > 0).assertTrue()
        expect(ContentRepository.hasVideoAsset(exercise)).assertFalse()
      }
    })

    it('builds local exercise library display rows with key metadata', 0, () => {
      const rows: ExerciseLibraryItem[] = ContentRepository.getExerciseLibraryItems()
      expect(rows.length).assertLarger(0)
      expect(rows[0].exerciseId).assertEqual('ex_barbell_bench_press')
      expect(rows[0].name).assertEqual('杠铃卧推')
      expect(rows[0].primaryMuscleName).assertEqual('胸部')
      expect(rows[0].equipmentText).assertEqual('杠铃')
      expect(rows[0].difficultyText).assertEqual('进阶')
    })

    it('filters candidate exercises by goal equipment muscle and difficulty', 0, () => {
      const candidates: ExerciseContent[] = ContentRepository.getCandidateExercises(
        'hypertrophy',
        'beginner',
        ['eq_bodyweight'],
        'muscle_chest',
        []
      )
      expect(candidates.length).assertLarger(0)
      expect(candidates[0].exerciseId).assertEqual('ex_push_up')
    })

    it('lets plan engine select bodyweight beginner actions for hypertrophy goal', 0, () => {
      const goal: UserGoal = createUserGoal(
        'test_goal',
        'hypertrophy',
        'beginner',
        1,
        45,
        ['eq_bodyweight'],
        [],
        1,
        1
      )
      const plan = PlanEngine.generatePlan(goal)
      expect(plan.days.length).assertEqual(1)
      expect(plan.days[0].exercises.length).assertLarger(0)
      expect(plan.days[0].exercises[0].exerciseId).assertEqual('ex_push_up')
    })
  })
}
