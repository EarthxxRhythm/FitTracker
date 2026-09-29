/**
 * AuthService 门面测试（ohosTest，带 Context）
 *
 * 覆盖：provider 解析（无 AGC 配置 → sandbox）、验证码登录全链路与会话快照持久化、
 * 邮箱注册/登录、退出清理、DeviceSeed 播种入口。
 */
import { abilityDelegatorRegistry } from '@kit.TestKit'
import { describe, beforeEach, afterEach, it, expect } from '@ohos/hypium'
import AuthService from '../../../main/ets/common/services/AuthService'
import SessionManager, { SessionSnapshot } from '../../../main/ets/common/services/SessionManager'
import { AuthResult, VerifyCodeResult } from '../../../main/ets/common/services/auth/AuthTypes'

function getTestContext(): Context {
  return abilityDelegatorRegistry.getAbilityDelegator().getAppContext()
}

export default function authServiceTest(): void {
  describe('AuthService facade', () => {
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

    it('resolves to the sandbox provider without agc config', 0, () => {
      expect(AuthService.getActiveProviderId()).assertEqual('sandbox')
      expect(AuthService.isCloudMode()).assertFalse()
    })

    it('runs phone code login and persists a session snapshot', 0, async () => {
      const context: Context = getTestContext()
      const issue: VerifyCodeResult = await AuthService.requestPhoneCode(context, '13700001111')
      expect(issue.success).assertTrue()
      expect(issue.devCodeHint).assertEqual('000000')

      const login: AuthResult = await AuthService.loginWithPhoneCode(context, '13700001111', '000000')
      expect(login.success).assertTrue()
      expect(login.session !== null).assertTrue()

      expect(await SessionManager.isLoggedIn(context)).assertTrue()
      const snapshot: SessionSnapshot | null = await SessionManager.getSession(context)
      expect(snapshot !== null).assertTrue()
      if (snapshot !== null) {
        expect(snapshot.phone).assertEqual('13700001111')
        expect(snapshot.userId).assertEqual('sandbox:13700001111')
        expect(snapshot.providerId).assertEqual('phone_code')
      }
    })

    it('rejects a wrong verification code without persisting a session', 0, async () => {
      const context: Context = getTestContext()
      await AuthService.requestPhoneCode(context, '13700002222')
      const login: AuthResult = await AuthService.loginWithPhoneCode(context, '13700002222', '999999')
      expect(login.success).assertFalse()
      expect(login.message).assertEqual('验证码错误，请重试')
      expect(await SessionManager.isLoggedIn(context)).assertFalse()
    })

    it('registers with email and can log back in after logout', 0, async () => {
      const context: Context = getTestContext()
      await AuthService.requestEmailCode(context, 'tester@example.com')
      const register: AuthResult = await AuthService.registerWithEmail(context, 'tester@example.com', 'password1', '000000', '测试者')
      expect(register.success).assertTrue()
      expect(await SessionManager.isLoggedIn(context)).assertTrue()

      await AuthService.logout(context)
      expect(await SessionManager.isLoggedIn(context)).assertFalse()
      expect(await SessionManager.getSession(context)).assertNull()

      const login: AuthResult = await AuthService.loginWithEmailPassword(context, 'tester@example.com', 'password1')
      expect(login.success).assertTrue()
      expect(await SessionManager.isLoggedIn(context)).assertTrue()
    })

    it('logs in via third party and clears state on logout', 0, async () => {
      const context: Context = getTestContext()
      const login: AuthResult = await AuthService.loginWithThirdParty(context, 'huawei')
      expect(login.success).assertTrue()
      const snapshot: SessionSnapshot | null = await SessionManager.getSession(context)
      expect(snapshot !== null).assertTrue()
      if (snapshot !== null) {
        expect(snapshot.providerId).assertEqual('huawei')
      }
      await AuthService.logout(context)
      expect(await SessionManager.isLoggedIn(context)).assertFalse()
    })

    it('seeds a sandbox session for device probes', 0, async () => {
      const context: Context = getTestContext()
      await AuthService.seedSandboxSession(context, '13700004444', '谱尼')
      expect(await SessionManager.isLoggedIn(context)).assertTrue()
      const snapshot: SessionSnapshot | null = await SessionManager.getSession(context)
      expect(snapshot !== null).assertTrue()
      if (snapshot !== null) {
        expect(snapshot.displayName).assertEqual('谱尼')
        expect(snapshot.phone).assertEqual('13700004444')
      }
    })
  })
}
