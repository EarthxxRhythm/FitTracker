import { abilityDelegatorRegistry } from '@kit.TestKit'
import { describe, beforeEach, afterEach, it, expect } from '@ohos/hypium'
import { AppRoutes } from '../../../main/ets/app/AppRoutes'
import { StartupDecision } from '../../../main/ets/app/AppState'
import AuthService from '../../../main/ets/common/services/AuthService'
import SessionManager, { SessionSnapshot } from '../../../main/ets/common/services/SessionManager'
import { AuthResult } from '../../../main/ets/common/services/auth/AuthTypes'

function getTestContext(): Context {
  return abilityDelegatorRegistry.getAbilityDelegator().getAppContext()
}

export default function authSessionFlowTest(): void {
  describe('AuthSessionFlow', () => {
    beforeEach(async () => {
      await SessionManager.clearSession(getTestContext())
      await SessionManager.clearToken(getTestContext())
      await AuthService.clearPersistedUsers(getTestContext())
    })

    afterEach(async () => {
      await SessionManager.clearSession(getTestContext())
      await SessionManager.clearToken(getTestContext())
      await AuthService.clearPersistedUsers(getTestContext())
    })

    it('logs in with phone code and restores the persisted session snapshot', 0, async () => {
      const context: Context = getTestContext()
      const phone: string = '13700002727'

      const issueResult = await AuthService.requestPhoneCode(context, phone)
      expect(issueResult.success).assertTrue()

      const loginResult: AuthResult = await AuthService.loginWithPhoneCode(context, phone, '000000')
      expect(loginResult.success).assertTrue()
      expect(loginResult.session !== null).assertTrue()

      // 会话快照持久化后可恢复，且登录态判定基于快照
      const restoredSnapshot: SessionSnapshot | null = await SessionManager.getSession(context)
      expect(SessionManager.getLastPersistenceError()).assertEqual('')
      expect(restoredSnapshot !== null).assertTrue()
      if (restoredSnapshot !== null) {
        expect(restoredSnapshot.userId).assertEqual('sandbox:' + phone)
        expect(restoredSnapshot.signedInAt > 0).assertTrue()
      }
      expect(await SessionManager.isLoggedIn(context)).assertTrue()

      // 分流矩阵：未登录 → 登录页；已登录且有目标 → 主壳
      expect(StartupDecision.getInitialRoute(false, false)).assertEqual(AppRoutes.LOGIN)
      expect(StartupDecision.getInitialRoute(true, true)).assertEqual(AppRoutes.APP_SHELL)
    })
  })
}
