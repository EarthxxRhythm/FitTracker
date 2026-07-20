import { abilityDelegatorRegistry } from '@kit.TestKit'
import { afterEach, describe, expect, it } from '@ohos/hypium'
import SessionManager from '../../../main/ets/common/services/SessionManager'
import { UserGoal, WorkoutSession } from '../../../main/ets/shared/models/TrainingModels'
import GoalRepository from '../../../main/ets/shared/services/GoalRepository'
import MonetizationEntitlementService from '../../../main/ets/shared/services/MonetizationEntitlementService'
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
  await SessionManager.clearToken(context)
  await GoalRepository.clearSavedGoal(context)
  await MonetizationEntitlementService.clearEntitlementForTesting(context)
  await WorkoutSessionPersistenceBridgeService.replacePersistedSessions(context, [])
}

export default function deviceSeedServiceTest(): void {
  describe('DeviceSeedService', () => {
    afterEach(async () => {
      await resetSeededData()
    })

    it('writes deterministic review metrics seed data through app-owned services', 0, async () => {
      const context: Context = getTestContext()

      const applied: boolean = await DeviceSeedService.applyNamedSeed(context, 'review_metrics')
      const goal: UserGoal | undefined = await GoalRepository.loadGoal(context)
      const entitlement = await MonetizationEntitlementService.readEntitlement(context)
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
      expect(entitlement.userId).assertEqual('13900009999')
      expect(entitlement.tier).assertEqual('pro')
      expect(entitlement.source).assertEqual('debug_override')

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
    })

    it('rejects unsupported seed keys without mutating persisted workout data', 0, async () => {
      const context: Context = getTestContext()

      const applied: boolean = await DeviceSeedService.applyNamedSeed(context, 'unknown_seed')
      const sessions: WorkoutSession[] = await WorkoutSessionPersistenceBridgeService.loadPersistedSessions(context)

      expect(applied).assertFalse()
      expect(await SessionManager.isLoggedIn(context)).assertFalse()
      expect(sessions.length).assertEqual(0)
    })
  })
}
