import { describe, it, expect } from '@ohos/hypium'
import { AppRoutes } from '../../../main/ets/app/AppRoutes'
import { TrainingPlan, UserGoal } from '../../../main/ets/shared/models/TrainingModels'
import GoalRepository from '../../../main/ets/shared/services/GoalRepository'
import GoalSetupService from '../../../main/ets/shared/services/GoalSetupService'
import PlanEngine from '../../../main/ets/shared/services/PlanEngine'
import WorkoutPreviewService, { WorkoutPreviewSummary } from '../../../main/ets/shared/services/WorkoutPreviewService'

export default function workoutPreviewServiceTest(): void {
  describe('WorkoutPreviewService', () => {
    it('builds preview summary and action list from a saved goal generated plan', 0, () => {
      GoalRepository.clearLocal()
      const goal: UserGoal = GoalSetupService.createGoalFromSelection(
        'preview_goal',
        'hypertrophy',
        'beginner',
        3,
        45,
        ['eq_bodyweight'],
        [],
        100
      )
      GoalRepository.saveLocalGoal(goal)

      const savedGoal: UserGoal | undefined = GoalRepository.getLocalGoal()
      expect(savedGoal !== undefined).assertTrue()
      if (savedGoal !== undefined) {
        const plan: TrainingPlan = PlanEngine.generatePlan(savedGoal)
        const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreviewForGoal(savedGoal, plan, 1)

        expect(preview.hasWorkout).assertTrue()
        expect(preview.planName).assertEqual('Hypertrophy Base Plan')
        expect(preview.goalSummary).assertEqual('目标 增肌 · 初学 · 每周 3 天 · 单次 45 分钟')
        expect(preview.scheduleSummary).assertEqual('训练日 Day 1 · day_1 · 3 个动作')
        expect(preview.exercises.length).assertLarger(0)
        expect(preview.exercises[0].name).assertEqual('俯卧撑')
        expect(preview.exercises[0].targetSets).assertEqual(3)
        expect(preview.exercises[0].targetReps).assertEqual('8-12')
        expect(preview.exercises[0].intensityNote).assertEqual('Controlled reps with 1-2 reps in reserve')
      }
    })

    it('routes a start action from trainable preview to active workout page', 0, () => {
      GoalRepository.clearLocal()
      const goal: UserGoal = GoalSetupService.createGoalFromSelection(
        'preview_start_goal',
        'hypertrophy',
        'beginner',
        3,
        45,
        ['eq_bodyweight'],
        [],
        100
      )
      GoalRepository.saveLocalGoal(goal)

      const savedGoal: UserGoal | undefined = GoalRepository.getLocalGoal()
      expect(savedGoal !== undefined).assertTrue()
      if (savedGoal !== undefined) {
        const plan: TrainingPlan = PlanEngine.generatePlan(savedGoal)
        const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreviewForGoal(savedGoal, plan, 1)
        const targetRoute: string = WorkoutPreviewService.getStartWorkoutRoute(preview)

        expect(preview.hasWorkout).assertTrue()
        expect(targetRoute).assertEqual(AppRoutes.ACTIVE_WORKOUT)
      }
    })
  })
}
