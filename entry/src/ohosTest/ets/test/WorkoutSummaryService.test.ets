import { describe, beforeEach, it, expect } from '@ohos/hypium'
import {
  TrainingPlan,
  UserGoal,
  WorkoutSession,
  WorkoutSet,
  createUserGoal,
  createWorkoutSet
} from '../../../main/ets/shared/models/TrainingModels'
import ActiveWorkoutService, { ActiveWorkoutState } from '../../../main/ets/shared/services/ActiveWorkoutService'
import PlanEngine from '../../../main/ets/shared/services/PlanEngine'
import WorkoutPreviewService, { WorkoutPreviewSummary } from '../../../main/ets/shared/services/WorkoutPreviewService'
import WorkoutRepository from '../../../main/ets/shared/services/WorkoutRepository'
import WorkoutSummaryService, { WorkoutSummary } from '../../../main/ets/shared/services/WorkoutSummaryService'

export default function workoutSummaryServiceTest(): void {
  describe('WorkoutSummaryService', () => {
    beforeEach(() => {
      WorkoutRepository.clear()
    })

    it('summarizes completed workout data from active workout completion', 0, () => {
      const equipmentIds: string[] = ['eq_barbell']
      const restrictedMuscleIds: string[] = []
      const goal: UserGoal = createUserGoal(
        'goal_summary_flow',
        'strength',
        'intermediate',
        1,
        60,
        equipmentIds,
        restrictedMuscleIds,
        1000,
        1000
      )
      const plan: TrainingPlan = PlanEngine.generatePlan(goal)
      const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreview(plan, 1)
      const state: ActiveWorkoutState = ActiveWorkoutService.createState(preview)
      expect(state.totalTargetSets > 0).assertTrue()
      const completedSets: number = state.totalTargetSets - 1
      const expectedCompletionRate: number = Math.round((completedSets * 100) / state.totalTargetSets)
      const session: WorkoutSession = ActiveWorkoutService.createCompletedSession(
        'session_summary_flow',
        state,
        1000,
        1501000,
        completedSets
      )

      WorkoutRepository.saveSession(session)

      const savedSession: WorkoutSession | undefined = WorkoutRepository.getLatestSession()
      expect(savedSession !== undefined).assertTrue()
      if (savedSession !== undefined) {
        const summary: WorkoutSummary = WorkoutSummaryService.createSummary(savedSession)

        expect(summary.hasSession).assertTrue()
        expect(summary.durationSeconds).assertEqual(1500)
        expect(summary.durationText).assertEqual('25 分钟')
        expect(summary.completedSets).assertEqual(completedSets)
        expect(summary.targetSets).assertEqual(state.totalTargetSets)
        expect(summary.completionRate).assertEqual(expectedCompletionRate)
        expect(summary.totalVolume).assertEqual(0)
      }
    })

    it('uses saved set data to calculate training volume when session volume is missing', 0, () => {
      const sets: WorkoutSet[] = [
        createWorkoutSet('set_summary_volume_1', 'ex_barbell_bench_press', 80, 5, 8, false),
        createWorkoutSet('set_summary_volume_2', 'ex_barbell_bench_press', 40, 10, 5, true),
        createWorkoutSet('set_summary_volume_3', 'ex_barbell_bench_press', 90, 3, 9, false)
      ]
      const session: WorkoutSession = WorkoutRepository.createSession(
        'session_summary_volume',
        'plan_summary_volume',
        'day_1',
        1000,
        181000,
        180,
        3,
        0,
        0,
        'completed_sets=3;target_sets=4',
        sets
      )

      const summary: WorkoutSummary = WorkoutSummaryService.createSummary(session)

      expect(summary.totalVolume).assertEqual(670)
    })
  })
}
