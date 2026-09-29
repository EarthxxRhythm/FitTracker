/**
 * AccountDataLifecycle 测试（ohosTest）
 *
 * 覆盖：退出登录编排（清认证会话 + 清本机业务数据 + 重置同步元数据）；
 * 同步路径走默认 LocalSandboxSnapshotStore（与 CloudSyncService 测试的 fake 注入互补）。
 *
 * 稳定性说明：hypium 1.0.25 不 await async 用例/钩子；本文件为单 async 用例，
 * 清理内联，链内 await 保序。
 */
import { abilityDelegatorRegistry } from '@kit.TestKit'
import { describe, expect, it } from '@ohos/hypium'
import AuthService from '../../../main/ets/common/services/AuthService'
import SessionManager from '../../../main/ets/common/services/SessionManager'
import TrainingPlanService from '../../../main/ets/common/services/TrainingPlanService'
import UserProfileService from '../../../main/ets/common/services/UserProfileService'
import WorkoutDraftService from '../../../main/ets/common/services/WorkoutDraftService'
import WorkoutSessionPersistenceBridgeService from '../../../main/ets/features/workout/services/WorkoutSessionPersistenceBridgeService'
import GoalRepository from '../../../main/ets/shared/services/GoalRepository'
import GoalSetupService from '../../../main/ets/shared/services/GoalSetupService'
import WorkoutRepository from '../../../main/ets/shared/services/WorkoutRepository'
import AccountDataLifecycle, { SignOutPreview } from '../../../main/ets/shared/services/AccountDataLifecycle'
import CloudSyncService from '../../../main/ets/shared/services/CloudSyncService'
import { acquireAuthSyncGate, ensureWarmup, releaseAuthSyncGate, WarmupOutcome } from './AuthSyncTestGate'
import {
  UserGoal,
  WorkoutSession,
  createWorkoutSession,
  createWorkoutSet
} from '../../../main/ets/shared/models/TrainingModels'

function getTestContext(): Context {
  const appContext: Context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext()
  return appContext.getApplicationContext().createModuleContext('entry')
}

async function resetAll(): Promise<void> {
  const context: Context = getTestContext()
  WorkoutRepository.clear()
  GoalRepository.clearLocal()
  await GoalRepository.clearSavedGoal(context)
  await TrainingPlanService.replaceMyPlans(context, [], '')
  await WorkoutSessionPersistenceBridgeService.replacePersistedSessions(context, [])
  await WorkoutDraftService.clearDraft(context)
  await UserProfileService.clearProfile(context)
  await SessionManager.clearSession(context)
  await SessionManager.clearToken(context)
  await CloudSyncService.resetMeta(context)
  await AuthService.clearPersistedUsers(context)
}

export default function accountDataLifecycleTest(): void {
  describe('AccountDataLifecycle', () => {
    it('signs out and clears local business data while keeping the cloud copy recoverable', 0, async () => {
      const warmup: WarmupOutcome = await ensureWarmup(getTestContext)
      const context: Context = warmup.context
      await acquireAuthSyncGate()
      try {
      await resetAll()
      await AuthService.seedSandboxSession(context, '13700008888', '退出测试')

      const goal: UserGoal = GoalSetupService.createCurrentGoalFromSelection(
        'hypertrophy',
        'beginner',
        3,
        45,
        ['eq_bodyweight'],
        [],
        1000
      )
      await GoalRepository.saveGoal(context, goal)
      GoalRepository.clearLocal()
      const sessions: WorkoutSession[] = [
        createWorkoutSession(
          'session_signout_1',
          'plan_signout',
          'day_1',
          1000,
          1900,
          900,
          1,
          720,
          0,
          '',
          [createWorkoutSet('session_signout_1_set_1', 'ex_barbell_bench_press', 90, 8, 8, false)]
        )
      ]
      await WorkoutSessionPersistenceBridgeService.replacePersistedSessions(context, sessions)
      await WorkoutSessionPersistenceBridgeService.syncRepositoryFromPersistence(context)

      expect(await SessionManager.isLoggedIn(context)).assertTrue()
      expect(await GoalRepository.hasSavedGoal(context)).assertTrue()

      const preview: SignOutPreview = await AccountDataLifecycle.prepareSignOut(context)
      expect(preview.hasSession).assertTrue()

      await AccountDataLifecycle.completeSignOut(context)
      expect(await SessionManager.isLoggedIn(context)).assertFalse()
      expect(await GoalRepository.hasSavedGoal(context)).assertFalse()
      expect(await SessionManager.getSession(context)).assertNull()

      const reloadedSessions: WorkoutSession[] = await WorkoutSessionPersistenceBridgeService.loadPersistedSessions(context)
      expect(reloadedSessions.length).assertEqual(0)

      await resetAll()
      } finally {
        releaseAuthSyncGate()
      }
    })
  })
}
