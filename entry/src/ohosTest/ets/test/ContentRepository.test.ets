import { describe, it, expect } from '@ohos/hypium'
import { ExerciseContent, UserGoal, createUserGoal } from '../../../main/ets/shared/models/TrainingModels'
import ContentRepository, { ExerciseDetailViewModel, ExerciseLibraryItem } from '../../../main/ets/shared/services/ContentRepository'
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

    it('builds exercise detail display data with local video placeholder and alternatives', 0, () => {
      const detail: ExerciseDetailViewModel | undefined = ContentRepository.getExerciseDetailViewModel('ex_push_up')
      expect(detail !== undefined).assertTrue()
      if (detail !== undefined) {
        expect(detail.name).assertEqual('俯卧撑')
        expect(detail.steps.length).assertLarger(0)
        expect(detail.safetyNotes.length).assertLarger(0)
        expect(detail.alternativeNames.length).assertEqual(1)
        expect(detail.alternativeNames[0]).assertEqual('哑铃卧推')
        expect(detail.videoPlaceholder).assertEqual('视频占位：本地动作库暂未接入视频素材')
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

    it('filters local exercise library rows by goal equipment muscle and difficulty', 0, () => {
      const allRows: ExerciseLibraryItem[] = ContentRepository.filterExerciseLibraryItems('', '', '', '')
      expect(allRows.length).assertEqual(ContentRepository.getExerciseLibraryItems().length)

      const rows: ExerciseLibraryItem[] = ContentRepository.filterExerciseLibraryItems(
        'strength',
        'eq_barbell',
        'muscle_chest',
        'intermediate'
      )
      expect(rows.length).assertEqual(1)
      expect(rows[0].exerciseId).assertEqual('ex_barbell_bench_press')
      expect(rows[0].equipmentIds[0]).assertEqual('eq_barbell')
      expect(rows[0].primaryMuscleId).assertEqual('muscle_chest')
      expect(rows[0].difficulty).assertEqual('intermediate')
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
