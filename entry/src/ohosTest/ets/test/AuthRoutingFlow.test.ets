import { abilityDelegatorRegistry } from '@kit.TestKit'
import { describe, beforeEach, afterEach, it, expect } from '@ohos/hypium'
import { AppRoutes } from '../../../main/ets/app/AppRoutes'
import { StartupDecision } from '../../../main/ets/app/AppState'
import AuthService from '../../../main/ets/common/services/AuthService'
import SessionManager from '../../../main/ets/common/services/SessionManager'
import { UserGoal } from '../../../main/ets/shared/models/TrainingModels'
import GoalRepository from '../../../main/ets/shared/services/GoalRepository'
import GoalSetupService from '../../../main/ets/shared/services/GoalSetupService'

function getTestContext(): Context {
  return abilityDelegatorRegistry.getAbilityDelegator().getAppContext()
}

export default function authRoutingFlowTest(): void {
  describe('AuthRoutingFlow', () => {
    beforeEach(async () => {
      GoalRepository.clearLocal()
      await GoalRepository.clearSavedGoal(getTestContext())
      await SessionManager.clearSession(getTestContext())
      await SessionManager.clearToken(getTestContext())
      await AuthService.clearPersistedUsers(getTestContext())
    })

    afterEach(async () => {
      GoalRepository.clearLocal()
      await GoalRepository.clearSavedGoal(getTestContext())
      await SessionManager.clearSession(getTestContext())
      await SessionManager.clearToken(getTestContext())
      await AuthService.clearPersistedUsers(getTestContext())
    })

    it('routes by session and saved goal state across login lifecycle', 0, async () => {
      const context: Context = getTestContext()
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
    })
  })
}
