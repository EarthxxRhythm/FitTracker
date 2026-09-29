/**
 * AuthSessionFlow —— 会话快照持久化与分流矩阵（ohosTest）。
 *
 * 稳定性说明：hypium 1.0.25 不 await async 用例/钩子；本文件为单 async 用例，
 * 清理内联，链内 await 保序。
 */
import { abilityDelegatorRegistry } from '@kit.TestKit'
import { describe, expect, it } from '@ohos/hypium'
import { AppRoutes } from '../../../main/ets/app/AppRoutes'
import { StartupDecision } from '../../../main/ets/app/AppState'
import AuthService from '../../../main/ets/common/services/AuthService'
import SessionManager, { SessionSnapshot } from '../../../main/ets/common/services/SessionManager'
import { AuthResult } from '../../../main/ets/common/services/auth/AuthTypes'
import { acquireAuthSyncGate, ensureWarmup, releaseAuthSyncGate, WarmupOutcome } from './AuthSyncTestGate'

function getTestContext(): Context {
  const appContext: Context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext()
  return appContext.getApplicationContext().createModuleContext('entry')
}

async function resetState(context: Context): Promise<void> {
  await SessionManager.clearSession(context)
  await SessionManager.clearToken(context)
  await AuthService.clearPersistedUsers(context)
}

export default function authSessionFlowTest(): void {
  describe('AuthSessionFlow', () => {
    it('logs in with phone code and restores the persisted session snapshot', 0, async () => {
      const warmup: WarmupOutcome = await ensureWarmup(getTestContext)
      const context: Context = warmup.context
      await acquireAuthSyncGate()
      try {
      await resetState(context)

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

      await resetState(context)
      } finally {
        releaseAuthSyncGate()
      }
    })
  })
}
