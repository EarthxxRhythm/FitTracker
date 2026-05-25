import { describe, it, expect } from '@ohos/hypium'
import { AppRoutes } from '../../../main/ets/app/AppRoutes'
import { StartupDecision } from '../../../main/ets/app/AppState'
import {
  TrainingPlan,
  UserGoal,
  WorkoutSession
} from '../../../main/ets/shared/models/TrainingModels'
import ActiveWorkoutService, {
  ActiveWorkoutExercise,
  ActiveWorkoutState
} from '../../../main/ets/shared/services/ActiveWorkoutService'
import GoalRepository from '../../../main/ets/shared/services/GoalRepository'
import GoalSetupService from '../../../main/ets/shared/services/GoalSetupService'
import HomePlanService, { HomePlanSummary } from '../../../main/ets/shared/services/HomePlanService'
import PlanEngine from '../../../main/ets/shared/services/PlanEngine'
import ReviewDashboardService, {
  ReviewDashboardSummary,
  ReviewGoalAdjustmentAction,
  ReviewPlanRegenerationResult
} from '../../../main/ets/shared/services/ReviewDashboardService'
import WorkoutPreviewService, { WorkoutPreviewSummary } from '../../../main/ets/shared/services/WorkoutPreviewService'
import WorkoutRepository from '../../../main/ets/shared/services/WorkoutRepository'
import WorkoutSummaryService, { WorkoutSummary } from '../../../main/ets/shared/services/WorkoutSummaryService'

export default function targetLoopFlowTest(): void {
  describe('TargetLoopFlow', () => {
    it('runs startup goal home preview active summary review and goal adjustment flow', 0, () => {
      GoalRepository.clearLocal()
      WorkoutRepository.clear()

      expect(StartupDecision.getInitialRoute(GoalRepository.hasLocalGoal())).assertEqual(AppRoutes.GOAL_SETUP)

      const now: number = 1000
      const goal: UserGoal = GoalSetupService.createCurrentGoalFromSelection(
        'hypertrophy',
        'beginner',
        3,
        45,
        ['eq_bodyweight'],
        [],
        now
      )
      GoalRepository.saveLocalGoal(goal)
      expect(StartupDecision.getInitialRoute(GoalRepository.hasLocalGoal())).assertEqual(AppRoutes.HOME)

      const savedGoal: UserGoal | undefined = GoalRepository.getLocalGoal()
      expect(savedGoal !== undefined).assertTrue()
      if (savedGoal === undefined) {
        return
      }

      const plan: TrainingPlan = PlanEngine.generatePlan(savedGoal)
      const home: HomePlanSummary = HomePlanService.createSummary(savedGoal, plan, 1)
      expect(home.hasGoal).assertTrue()
      expect(home.startRoute).assertEqual(AppRoutes.WORKOUT_PREVIEW)
      expect(home.weeklyPlanDays.length).assertEqual(3)
      expect(home.todayExerciseCount).assertLarger(0)

      const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreviewForGoal(savedGoal, plan, 1)
      expect(preview.hasWorkout).assertTrue()
      expect(WorkoutPreviewService.getStartWorkoutRoute(preview)).assertEqual(AppRoutes.ACTIVE_WORKOUT)
      expect(preview.exercises.length).assertLarger(0)

      const activeState: ActiveWorkoutState = ActiveWorkoutService.createState(preview)
      expect(activeState.hasWorkout).assertTrue()
      expect(activeState.currentExerciseName).assertEqual(preview.exercises[0].name)

      const firstExercise: ActiveWorkoutExercise = activeState.exercises[0]
      const updatedExercises: ActiveWorkoutExercise[] = ActiveWorkoutService.updateSetEntry(
        activeState.exercises,
        firstExercise.plannedExerciseId,
        0,
        '60',
        '10'
      )
      const progressedState: ActiveWorkoutState = ActiveWorkoutService.createStateWithProgress(activeState, updatedExercises)
      expect(progressedState.completedSets).assertEqual(1)
      expect(progressedState.exercises[0].sets[0].oneRepMaxText).assertEqual('1RM 参考 80 kg')

      const session: WorkoutSession = ActiveWorkoutService.createCompletedSession(
        'session_target_loop',
        progressedState,
        1000,
        121000,
        progressedState.completedSets
      )
      WorkoutRepository.saveSession(session)

      const summary: WorkoutSummary = WorkoutSummaryService.createSummaryWithHistory(session, WorkoutRepository.getSessions())
      expect(summary.hasSession).assertTrue()
      expect(summary.sessionId).assertEqual('session_target_loop')
      expect(summary.completedSets).assertEqual(1)
      expect(summary.exerciseRecords.length).assertLarger(0)

      const review: ReviewDashboardSummary = ReviewDashboardService.createSummary(WorkoutRepository.getSessions())
      expect(review.hasSessions).assertTrue()
      expect(review.sessionCount).assertEqual(1)
      expect(review.latestSessionId).assertEqual('session_target_loop')

      const adjustmentAction: ReviewGoalAdjustmentAction = ReviewDashboardService.createGoalAdjustmentAction(review, savedGoal)
      const regeneration: ReviewPlanRegenerationResult = ReviewDashboardService.createPlanRegenerationResult(
        savedGoal,
        adjustmentAction,
        2000
      )
      expect(regeneration.adjustedGoal.goalId).assertEqual(savedGoal.goalId)
      expect(regeneration.regeneratedPlan.goalId).assertEqual(savedGoal.goalId)
      expect(regeneration.regeneratedPlan.days.length).assertLarger(0)
    })
  })
}
