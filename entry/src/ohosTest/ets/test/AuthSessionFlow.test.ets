import { abilityDelegatorRegistry } from '@kit.TestKit'
import { describe, beforeEach, afterEach, it, expect } from '@ohos/hypium'
import { AppRoutes } from '../../../main/ets/app/AppRoutes'
import { StartupDecision } from '../../../main/ets/app/AppState'
import AuthService, { AuthResult } from '../../../main/ets/common/services/AuthService'
import SessionManager from '../../../main/ets/common/services/SessionManager'

function getTestContext(): Context {
  return abilityDelegatorRegistry.getAbilityDelegator().getAppContext()
}

export default function authSessionFlowTest(): void {
  describe('AuthSessionFlow', () => {
    beforeEach(async () => {
      await SessionManager.clearToken(getTestContext())
      await AuthService.clearPersistedUsers(getTestContext())
    })

    afterEach(async () => {
      await SessionManager.clearToken(getTestContext())
      await AuthService.clearPersistedUsers(getTestContext())
    })

    it('registers logs in and restores persisted token session', 0, async () => {
      const phone: string = '13700002727'
      const password: string = 'pass2727'

      const registerResult: AuthResult = await AuthService.registerLocal(getTestContext(), phone, password)
      expect(registerResult.success).assertTrue()
      expect(registerResult.token).assertContain('.')
      expect(SessionManager.validateToken(registerResult.token)).assertTrue()
      expect(SessionManager.getUserIdFromToken(registerResult.token)).assertEqual(phone)

      await SessionManager.saveToken(getTestContext(), registerResult.token)
      const restoredRegisterToken: string | null = await SessionManager.getToken(getTestContext())
      expect(SessionManager.getLastPersistenceError()).assertEqual('')
      expect(restoredRegisterToken !== null).assertTrue()
      if (restoredRegisterToken !== null) {
        expect(restoredRegisterToken).assertEqual(registerResult.token)
        expect(SessionManager.validateToken(restoredRegisterToken)).assertTrue()
        expect(SessionManager.getUserIdFromToken(restoredRegisterToken)).assertEqual(phone)
      }
      expect(await SessionManager.isLoggedIn(getTestContext())).assertTrue()

      AuthService.clearLocalUsers()
      const loginResult: AuthResult = await AuthService.loginLocal(getTestContext(), phone, password)
      expect(loginResult.success).assertTrue()
      expect(loginResult.token).assertContain('.')
      expect(SessionManager.getUserIdFromToken(loginResult.token)).assertEqual(phone)

      await SessionManager.saveToken(getTestContext(), loginResult.token)
      const restoredLoginToken: string | null = await SessionManager.getToken(getTestContext())
      expect(restoredLoginToken !== null).assertTrue()
      if (restoredLoginToken !== null) {
        expect(restoredLoginToken).assertEqual(loginResult.token)
      }
      expect(StartupDecision.getInitialRoute(true)).assertEqual(AppRoutes.HOME)
    })
  })
}
