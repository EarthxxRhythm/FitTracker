import { describe, it, expect } from '@ohos/hypium'
import { AppRoutes } from '../../../main/ets/app/AppRoutes'
import { StartupDecision } from '../../../main/ets/app/AppState'
import WorkoutSessionService, {
  SessionPreferencesStore,
  WorkoutSession as LegacyWorkoutSession
} from '../../../main/ets/common/services/WorkoutSessionService'
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
import PersonalRecordService, { ExercisePersonalRecord } from '../../../main/ets/shared/services/PersonalRecordService'
import WorkoutSessionPersistenceBridgeService from '../../../main/ets/features/workout/services/WorkoutSessionPersistenceBridgeService'

class FakeTargetLoopPreferencesStore extends SessionPreferencesStore {
  private sessionsJson: string = '[]'

  async get(key: string, defaultValue: string): Promise<string> {
    if (key === 'sessions') {
      return this.sessionsJson
    }
    return defaultValue
  }

  async put(key: string, value: string): Promise<void> {
    if (key === 'sessions') {
      this.sessionsJson = value
    }
  }

  async flush(): Promise<void> {
  }

  clear(): void {
    this.sessionsJson = '[]'
  }

  readSessions(): LegacyWorkoutSession[] {
    return JSON.parse(this.sessionsJson) as LegacyWorkoutSession[]
  }
}

class ThrowingTargetLoopPreferencesStore extends SessionPreferencesStore {
  async get(key: string, defaultValue: string): Promise<string> {
    return defaultValue
  }

  async put(key: string, value: string): Promise<void> {
    throw new Error('persist_failed')
  }

  async flush(): Promise<void> {
  }
}

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

    it('persists an active workout completion before review reloads from persistence', 0, async () => {
      const fakeStore = new FakeTargetLoopPreferencesStore()
      const testContext: Context = {} as Context
      GoalRepository.clearLocal()
      WorkoutRepository.clear()
      fakeStore.clear()
      WorkoutSessionService.setStoreForTesting(fakeStore)

      try {
        const goal: UserGoal = GoalSetupService.createCurrentGoalFromSelection(
          'hypertrophy',
          'beginner',
          3,
          45,
          ['eq_bodyweight'],
          [],
          1000
        )
        GoalRepository.saveLocalGoal(goal)
        const plan: TrainingPlan = PlanEngine.generatePlan(goal)
        const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreviewForGoal(goal, plan, 1)
        const activeState: ActiveWorkoutState = ActiveWorkoutService.createState(preview)
        const firstExercise: ActiveWorkoutExercise = activeState.exercises[0]
        const updatedExercises: ActiveWorkoutExercise[] = ActiveWorkoutService.updateSetEntry(
          activeState.exercises,
          firstExercise.plannedExerciseId,
          0,
          '60',
          '10'
        )
        const progressedState: ActiveWorkoutState = ActiveWorkoutService.createStateWithProgress(activeState, updatedExercises)
        const session: WorkoutSession = ActiveWorkoutService.createCompletedSession(
          'session_target_loop_persisted',
          progressedState,
          1000,
          121000,
          progressedState.completedSets
        )

        await WorkoutSessionPersistenceBridgeService.persistActiveWorkoutCompletion(testContext, session)
        WorkoutRepository.clear()

        const reloadedSessions: WorkoutSession[] = await WorkoutSessionPersistenceBridgeService.syncRepositoryFromPersistence(testContext)
        const review: ReviewDashboardSummary = ReviewDashboardService.createSummary(reloadedSessions)

        expect(fakeStore.readSessions().length).assertEqual(1)
        expect(reloadedSessions.length).assertEqual(1)
        expect(reloadedSessions[0].sessionId).assertEqual('session_target_loop_persisted')
        expect(review.hasSessions).assertTrue()
        expect(review.sessionCount).assertEqual(1)
        expect(review.latestSessionId).assertEqual('session_target_loop_persisted')
      } finally {
        WorkoutSessionService.setStoreForTesting(null)
        GoalRepository.clearLocal()
        WorkoutRepository.clear()
      }
    })

    it('does not duplicate repository sessions when persistence fails and caller falls back locally', 0, async () => {
      const throwingStore = new ThrowingTargetLoopPreferencesStore()
      const testContext: Context = {} as Context
      GoalRepository.clearLocal()
      WorkoutRepository.clear()
      WorkoutSessionService.setStoreForTesting(throwingStore)

      try {
        const goal: UserGoal = GoalSetupService.createCurrentGoalFromSelection(
          'hypertrophy',
          'beginner',
          3,
          45,
          ['eq_bodyweight'],
          [],
          1000
        )
        GoalRepository.saveLocalGoal(goal)
        const plan: TrainingPlan = PlanEngine.generatePlan(goal)
        const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreviewForGoal(goal, plan, 1)
        const activeState: ActiveWorkoutState = ActiveWorkoutService.createState(preview)
        const firstExercise: ActiveWorkoutExercise = activeState.exercises[0]
        const updatedExercises: ActiveWorkoutExercise[] = ActiveWorkoutService.updateSetEntry(
          activeState.exercises,
          firstExercise.plannedExerciseId,
          0,
          '60',
          '10'
        )
        const progressedState: ActiveWorkoutState = ActiveWorkoutService.createStateWithProgress(activeState, updatedExercises)
        const session: WorkoutSession = ActiveWorkoutService.createCompletedSession(
          'session_target_loop_fallback',
          progressedState,
          1000,
          121000,
          progressedState.completedSets
        )

        try {
          await WorkoutSessionPersistenceBridgeService.persistActiveWorkoutCompletion(testContext, session)
        } catch (e) {
          WorkoutRepository.saveSession(session)
        }

        const sessions: WorkoutSession[] = WorkoutRepository.getSessions()
        expect(sessions.length).assertEqual(1)
        expect(sessions[0].sessionId).assertEqual('session_target_loop_fallback')
      } finally {
        WorkoutSessionService.setStoreForTesting(null)
        GoalRepository.clearLocal()
        WorkoutRepository.clear()
      }
    })

    it('preserves warmup markers across persistence reload so personal records ignore warmup sets', 0, async () => {
      const fakeStore = new FakeTargetLoopPreferencesStore()
      const testContext: Context = {} as Context
      WorkoutRepository.clear()
      fakeStore.clear()
      WorkoutSessionService.setStoreForTesting(fakeStore)

      try {
        const warmupHeavySession: WorkoutSession = {
          sessionId: 'session_target_loop_warmup',
          planId: 'plan_target_loop_warmup',
          dayId: 'day_1',
          startedAt: 1716163200000,
          endedAt: 1716165000000,
          durationSeconds: 1800,
          totalSets: 2,
          totalVolume: 1180,
          fatigueScore: 0,
          notes: 'warmup-pr-check',
          sets: [
            {
              setId: 'set_warmup_heavy',
              exerciseId: 'ex_barbell_bench_press',
              weight: 100,
              reps: 1,
              rpe: 5,
              isWarmup: true
            },
            {
              setId: 'set_working',
              exerciseId: 'ex_barbell_bench_press',
              weight: 60,
              reps: 3,
              rpe: 8,
              isWarmup: false
            }
          ]
        }

        await WorkoutSessionPersistenceBridgeService.persistActiveWorkoutCompletion(testContext, warmupHeavySession)
        WorkoutRepository.clear()

        const reloadedSessions: WorkoutSession[] = await WorkoutSessionPersistenceBridgeService.syncRepositoryFromPersistence(testContext)
        const records: ExercisePersonalRecord[] = PersonalRecordService.createRecords(reloadedSessions)

        expect(reloadedSessions.length).assertEqual(1)
        expect(records.length).assertEqual(1)
        expect(records[0].exerciseId).assertEqual('ex_barbell_bench_press')
        expect(records[0].bestWeight).assertEqual(60)
        expect(records[0].bestOneRepMax).assertEqual(66)
      } finally {
        WorkoutSessionService.setStoreForTesting(null)
        WorkoutRepository.clear()
      }
    })
  })
}
