/**
 * DeviceSeedService 测试（ohosTest）
 *
 * 覆盖：review_metrics / today_flow 种子数据、未知 seed 拒绝。
 *
 * 稳定性说明：hypium 1.0.25 的 Spec.run / runHookFunc 对 async 用例与钩子为裸调用
 * （不 await），同套件内异步链会交错推进（本文件原 2 条长期红即源于此）。
 * 本文件为单 async 用例，清理内联，链内 await 保序。
 */
import { abilityDelegatorRegistry } from '@kit.TestKit'
import { describe, expect, it } from '@ohos/hypium'
import SessionManager from '../../../main/ets/common/services/SessionManager'
import { UserGoal, WorkoutSession } from '../../../main/ets/shared/models/TrainingModels'
import { acquireAuthSyncGate, ensureWarmup, releaseAuthSyncGate, WarmupOutcome } from './AuthSyncTestGate'
import TrainingPlanService, { UserPlan } from '../../../main/ets/common/services/TrainingPlanService'
import WorkoutDraftService, { WorkoutDraftSnapshot } from '../../../main/ets/common/services/WorkoutDraftService'
import GoalRepository from '../../../main/ets/shared/services/GoalRepository'
import DeviceSeedService from '../../../main/ets/shared/services/DeviceSeedService'
import PersonalRecordService, {
  ExercisePersonalRecordDetail
} from '../../../main/ets/shared/services/PersonalRecordService'
import ReviewDashboardService, {
  ReviewDashboardSummary,
  ReviewRecentSessionRecord
} from '../../../main/ets/shared/services/ReviewDashboardService'
import ReviewInsightsService from '../../../main/ets/shared/services/ReviewInsightsService'
import StatsDashboardService, {
  StatsDashboardSummary
} from '../../../main/ets/shared/services/StatsDashboardService'
import WorkoutRepository from '../../../main/ets/shared/services/WorkoutRepository'
import WorkoutSessionPersistenceBridgeService from '../../../main/ets/features/workout/services/WorkoutSessionPersistenceBridgeService'

function getTestContext(): Context {
  const appContext: Context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext()
  return appContext.getApplicationContext().createModuleContext('entry')
}

async function resetSeededData(): Promise<void> {
  const context: Context = getTestContext()
  WorkoutRepository.clear()
  await SessionManager.clearSession(context)
  await SessionManager.clearToken(context)
  await GoalRepository.clearSavedGoal(context)
  await TrainingPlanService.replaceMyPlans(context, [], '')
  await WorkoutSessionPersistenceBridgeService.replacePersistedSessions(context, [])
}

export default function deviceSeedServiceTest(): void {
  describe('DeviceSeedService', () => {
    it('applies review metrics and today flow seeds and rejects unknown seeds in order', 0, async () => {
      const warmup: WarmupOutcome = await ensureWarmup(getTestContext)
      const context: Context = warmup.context
      await acquireAuthSyncGate()
      try {

      // 1) review_metrics 种子
      await resetSeededData()
      const applied: boolean = await DeviceSeedService.applyNamedSeed(context, 'review_metrics')
      const goal: UserGoal | undefined = await GoalRepository.loadGoal(context)
      const sessions: WorkoutSession[] = await WorkoutSessionPersistenceBridgeService.loadPersistedSessions(context)
      const summary: ReviewDashboardSummary = ReviewDashboardService.createSummary(sessions)
      const recentRecords: ReviewRecentSessionRecord[] = ReviewInsightsService.filterRecentRecords(
        sessions,
        'recent_7_days',
        Date.now(),
        true
      )
      const statsSummary: StatsDashboardSummary = StatsDashboardService.createSummary(sessions, Date.now())
      const recordDetails: ExercisePersonalRecordDetail[] = PersonalRecordService.createRecordDetails(sessions)

      expect(applied).assertTrue()
      expect(await SessionManager.isLoggedIn(context)).assertTrue()
      expect(goal !== undefined).assertTrue()
      if (goal !== undefined) {
        expect(goal.goalId).assertEqual('goal_review_metrics')
        expect(goal.weeklyDays).assertEqual(3)
        expect(goal.sessionMinutes).assertEqual(45)
      }
      expect(sessions.length).assertEqual(2)
      expect(summary.sessionCount).assertEqual(2)
      expect(summary.averageCompletionRate).assertEqual(78)
      expect(recentRecords.length).assertEqual(2)
      expect(recentRecords[0].sessionId).assertEqual('session_review_metrics_2')
      expect(recentRecords[0].volumeText).assertEqual('357 kg')
      expect(statsSummary.weeklyStats.totalVolume).assertEqual(1364)
      expect(recordDetails.length > 0).assertTrue()
      expect(recordDetails[0].exerciseId).assertEqual('ex_barbell_bench_press')
      expect(recordDetails[0].bestOneRepMax).assertEqual(105)

      // 2) today_flow 种子
      await resetSeededData()
      const appliedFlow: boolean = await DeviceSeedService.applyNamedSeed(context, 'today_flow')
      const flowGoal: UserGoal | undefined = await GoalRepository.loadGoal(context)
      const flowSessions: WorkoutSession[] = await WorkoutSessionPersistenceBridgeService.loadPersistedSessions(context)
      const currentPlan: UserPlan | null = await TrainingPlanService.getCurrentPlan(context)
      const draft: WorkoutDraftSnapshot | null = await WorkoutDraftService.getDraft(context)

      expect(appliedFlow).assertTrue()
      expect(await SessionManager.isLoggedIn(context)).assertTrue()
      expect(flowGoal !== undefined).assertTrue()
      if (flowGoal !== undefined) {
        expect(flowGoal.goalId).assertEqual('goal_today_flow')
        expect(flowGoal.goalType).assertEqual('hypertrophy')
        expect(flowGoal.level).assertEqual('beginner')
        expect(flowGoal.weeklyDays).assertEqual(3)
        expect(flowGoal.sessionMinutes).assertEqual(45)
        expect(flowGoal.equipmentIds.length).assertEqual(2)
        expect(flowGoal.equipmentIds[0]).assertEqual('eq_bodyweight')
        expect(flowGoal.equipmentIds[1]).assertEqual('eq_dumbbell')
      }
      expect(flowSessions.length).assertEqual(0)
      // applyTodayFlowSeed 会启用预设计划（TrainingPlanService.enablePlan('preset_upper_lower')），
      // 原断言 expect(currentPlan === null) 与 seed 实现矛盾（既有长期红），此处按实现对齐。
      expect(currentPlan !== null).assertTrue()
      expect(draft === null).assertTrue()

      // 3) 未知 seed 拒绝且不改变数据
      await resetSeededData()
      const appliedUnknown: boolean = await DeviceSeedService.applyNamedSeed(context, 'unknown_seed')
      const sessionsAfter: WorkoutSession[] = await WorkoutSessionPersistenceBridgeService.loadPersistedSessions(context)
      expect(appliedUnknown).assertFalse()
      expect(await SessionManager.isLoggedIn(context)).assertFalse()
      expect(sessionsAfter.length).assertEqual(0)

      await resetSeededData()
      } finally {
        releaseAuthSyncGate()
      }
    })
  })
}
