/**
 * AuthRoutingFlow —— 登录生命周期与目标状态驱动的分流矩阵（ohosTest）。
 *
 * 稳定性说明：hypium 1.0.25 不 await async 用例/钩子；本文件为单 async 用例，
 * 清理内联，链内 await 保序。
 */
import { abilityDelegatorRegistry } from '@kit.TestKit'
import { describe, expect, it } from '@ohos/hypium'
import { AppRoutes } from '../../../main/ets/app/AppRoutes'
import { StartupDecision } from '../../../main/ets/app/AppState'
import AuthService from '../../../main/ets/common/services/AuthService'
import SessionManager from '../../../main/ets/common/services/SessionManager'
import { UserGoal } from '../../../main/ets/shared/models/TrainingModels'
import GoalRepository from '../../../main/ets/shared/services/GoalRepository'
import GoalSetupService from '../../../main/ets/shared/services/GoalSetupService'
import { acquireAuthSyncGate, ensureWarmup, releaseAuthSyncGate, WarmupOutcome } from './AuthSyncTestGate'

function getTestContext(): Context {
  const appContext: Context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext()
  return appContext.getApplicationContext().createModuleContext('entry')
}

async function resetState(context: Context): Promise<void> {
  GoalRepository.clearLocal()
  await GoalRepository.clearSavedGoal(context)
  await SessionManager.clearSession(context)
  await SessionManager.clearToken(context)
  await AuthService.clearPersistedUsers(context)
}

export default function authRoutingFlowTest(): void {
  describe('AuthRoutingFlow', () => {
    it('routes by session and saved goal state across login lifecycle', 0, async () => {
      const warmup: WarmupOutcome = await ensureWarmup(getTestContext)
      const context: Context = warmup.context
      await acquireAuthSyncGate()
      try {
      await resetState(context)
      const phone: string = '13700002828'

      // 未登录 → 登录页
      expect(await SessionManager.isLoggedIn(context)).assertFalse()
      expect(StartupDecision.getInitialRoute(await SessionManager.isLoggedIn(context), false)).assertEqual(AppRoutes.LOGIN)

      // 手机验证码登录（未注册自动注册）
      await AuthService.requestPhoneCode(context, phone)
      const loginResult = await AuthService.loginWithPhoneCode(context, phone, '000000')
      expect(loginResult.success).assertTrue()
      expect(await SessionManager.isLoggedIn(context)).assertTrue()

      // 已登录且无目标 → 目标设置
      expect(await GoalRepository.hasSavedGoal(context)).assertFalse()
      expect(StartupDecision.getInitialRoute(await SessionManager.isLoggedIn(context), await GoalRepository.hasSavedGoal(context))).assertEqual(AppRoutes.GOAL_SETUP)

      // 保存目标后 → 主壳
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

      expect(await GoalRepository.hasSavedGoal(context)).assertTrue()
      expect(StartupDecision.getInitialRoute(await SessionManager.isLoggedIn(context), await GoalRepository.hasSavedGoal(context))).assertEqual(AppRoutes.APP_SHELL)

      await resetState(context)
      } finally {
        releaseAuthSyncGate()
      }
    })
  })
}
