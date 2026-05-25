import { abilityDelegatorRegistry } from '@kit.TestKit'
import { describe, beforeEach, afterEach, it, expect } from '@ohos/hypium'
import { AppRoutes } from '../../../main/ets/app/AppRoutes'
import { StartupDecision } from '../../../main/ets/app/AppState'
import AuthService, { AuthResult } from '../../../main/ets/common/services/AuthService'
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
      await SessionManager.clearToken(getTestContext())
      await AuthService.clearPersistedUsers(getTestContext())
    })

    afterEach(async () => {
      GoalRepository.clearLocal()
      await GoalRepository.clearSavedGoal(getTestContext())
      await SessionManager.clearToken(getTestContext())
      await AuthService.clearPersistedUsers(getTestContext())
    })

    it('registers logs in restores session and routes by saved goal state', 0, async () => {
      const phone: string = '13700002828'
      const password: string = 'pass2828'

      const registerResult: AuthResult = await AuthService.registerLocal(getTestContext(), phone, password)
      expect(registerResult.success).assertTrue()
      await SessionManager.saveToken(getTestContext(), registerResult.token)
      expect(await SessionManager.isLoggedIn(getTestContext())).assertTrue()

      await SessionManager.clearToken(getTestContext())
      AuthService.clearLocalUsers()

      const loginResult: AuthResult = await AuthService.loginLocal(getTestContext(), phone, password)
      expect(loginResult.success).assertTrue()
      await SessionManager.saveToken(getTestContext(), loginResult.token)

      AuthService.clearLocalUsers()
      GoalRepository.clearLocal()
      const restoredToken: string | null = await SessionManager.getToken(getTestContext())
      expect(restoredToken !== null).assertTrue()
      if (restoredToken !== null) {
        expect(SessionManager.validateToken(restoredToken)).assertTrue()
        expect(SessionManager.getUserIdFromToken(restoredToken)).assertEqual(phone)
      }

      expect(await SessionManager.isLoggedIn(getTestContext())).assertTrue()
      expect(await GoalRepository.hasSavedGoal(getTestContext())).assertFalse()
      expect(StartupDecision.getInitialRoute(await GoalRepository.hasSavedGoal(getTestContext()))).assertEqual(AppRoutes.GOAL_SETUP)

      const goal: UserGoal = GoalSetupService.createCurrentGoalFromSelection(
        'hypertrophy',
        'beginner',
        3,
        45,
        ['eq_bodyweight'],
        [],
        1000
      )
      await GoalRepository.saveGoal(getTestContext(), goal)
      GoalRepository.clearLocal()

      expect(await GoalRepository.hasSavedGoal(getTestContext())).assertTrue()
      expect(StartupDecision.getInitialRoute(await GoalRepository.hasSavedGoal(getTestContext()))).assertEqual(AppRoutes.HOME)
    })
  })
}
