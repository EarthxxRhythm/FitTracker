import { describe, beforeEach, it, expect } from '@ohos/hypium'
import {
  TrainingPlan,
  UserGoal,
  WorkoutSession,
  WorkoutSet,
  createUserGoal,
  createWorkoutSet
} from '../../../main/ets/shared/models/TrainingModels'
import ActiveWorkoutService, {
  ActiveWorkoutExercise,
  ActiveWorkoutState
} from '../../../main/ets/shared/services/ActiveWorkoutService'
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
      const firstExercise: ActiveWorkoutExercise = state.exercises[0]
      const updatedExercises: ActiveWorkoutExercise[] = ActiveWorkoutService.updateSetEntry(
        state.exercises,
        firstExercise.plannedExerciseId,
        0,
        '40',
        '10'
      )
      const progressedState: ActiveWorkoutState = ActiveWorkoutService.createStateWithProgress(state, updatedExercises)
      const completedSets: number = progressedState.completedSets
      const expectedCompletionRate: number = Math.round((completedSets * 100) / state.totalTargetSets)
      const session: WorkoutSession = ActiveWorkoutService.createCompletedSession(
        'session_summary_flow',
        progressedState,
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
        expect(summary.totalVolume).assertEqual(400)
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

    it('shows each exercise best 1RM, best weight, best reps, and date from current plus history', 0, () => {
      const historySets: WorkoutSet[] = [
        createWorkoutSet('set_summary_record_history_1', 'ex_barbell_bench_press', 80, 8, 8, false),
        createWorkoutSet('set_summary_record_history_2', 'ex_dumbbell_row', 42, 10, 8, false)
      ]
      const currentSets: WorkoutSet[] = [
        createWorkoutSet('set_summary_record_current_1', 'ex_barbell_bench_press', 90, 5, 9, false),
        createWorkoutSet('set_summary_record_current_2', 'ex_barbell_bench_press', 70, 12, 8, true),
        createWorkoutSet('set_summary_record_current_3', 'ex_dumbbell_row', 40, 12, 8, false)
      ]
      const historySession: WorkoutSession = WorkoutRepository.createSession(
        'session_summary_record_history',
        'plan_summary_record',
        'day_1',
        1714521600000,
        1714523400000,
        1800,
        2,
        0,
        0,
        'completed_sets=2;target_sets=2',
        historySets
      )
      const currentSession: WorkoutSession = WorkoutRepository.createSession(
        'session_summary_record_current',
        'plan_summary_record',
        'day_2',
        1715126400000,
        1715128800000,
        2400,
        3,
        0,
        0,
        'completed_sets=3;target_sets=3',
        currentSets
      )
      WorkoutRepository.saveSession(historySession)
      WorkoutRepository.saveSession(currentSession)

      const summary: WorkoutSummary = WorkoutSummaryService.createSummaryWithHistory(
        currentSession,
        WorkoutRepository.getSessions()
      )

      expect(summary.exerciseRecords.length).assertEqual(2)
      expect(summary.exerciseRecords[0].exerciseId).assertEqual('ex_barbell_bench_press')
      expect(summary.exerciseRecords[0].bestOneRepMax).assertEqual(105)
      expect(summary.exerciseRecords[0].bestWeight).assertEqual(90)
      expect(summary.exerciseRecords[0].bestReps).assertEqual(5)
      expect(summary.exerciseRecords[0].dateText).assertEqual('2024-05-08')
      expect(summary.exerciseRecords[1].exerciseId).assertEqual('ex_dumbbell_row')
      expect(summary.exerciseRecords[1].bestOneRepMax).assertEqual(56)
      expect(summary.exerciseRecords[1].bestWeight).assertEqual(40)
      expect(summary.exerciseRecords[1].bestReps).assertEqual(12)
      expect(summary.exerciseRecords[1].dateText).assertEqual('2024-05-08')
    })
  })
}
