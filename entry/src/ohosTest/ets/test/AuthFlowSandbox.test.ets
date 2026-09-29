/**
 * AuthFlowSandbox —— 沙盒认证流程错误分支与边界测试（ohosTest）。
 */
import { abilityDelegatorRegistry } from '@kit.TestKit'
import { describe, beforeEach, afterEach, it, expect } from '@ohos/hypium'
import AuthService from '../../../main/ets/common/services/AuthService'
import SessionManager, { SessionSnapshot } from '../../../main/ets/common/services/SessionManager'
import { AuthResult, VerifyCodeResult } from '../../../main/ets/common/services/auth/AuthTypes'

function getTestContext(): Context {
  return abilityDelegatorRegistry.getAbilityDelegator().getAppContext()
}

export default function authFlowSandboxTest(): void {
  describe('AuthFlowSandbox', () => {
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

    it('rate limits repeated phone code requests', 0, async () => {
      const context: Context = getTestContext()
      const first: VerifyCodeResult = await AuthService.requestPhoneCode(context, '13700005555')
      expect(first.success).assertTrue()
      const second: VerifyCodeResult = await AuthService.requestPhoneCode(context, '13700005555')
      expect(second.success).assertFalse()
      expect(second.message).assertEqual('验证码已发送，请稍后再试')
    })

    it('rejects duplicate email registration through the facade', 0, async () => {
      const context: Context = getTestContext()
      await AuthService.requestEmailCode(context, 'flow@example.com')
      const first: AuthResult = await AuthService.registerWithEmail(context, 'flow@example.com', 'password1', '000000', '一号')
      expect(first.success).assertTrue()
      const second: AuthResult = await AuthService.registerWithEmail(context, 'flow@example.com', 'password2', '000000', '二号')
      expect(second.success).assertFalse()
      expect(second.message).assertEqual('该邮箱已注册')
    })

    it('rejects short password and invalid email through the facade', 0, async () => {
      const context: Context = getTestContext()
      const shortPwd: AuthResult = await AuthService.registerWithEmail(context, 'shortpw@example.com', '1234567', '000000', '短密码')
      expect(shortPwd.success).assertFalse()
      expect(shortPwd.message).assertEqual('密码至少 8 位')

      const badEmail: VerifyCodeResult = await AuthService.requestEmailCode(context, 'bad-email')
      expect(badEmail.success).assertFalse()
      expect(badEmail.message).assertEqual('请输入正确的邮箱')
    })

    it('logs in via wechat third party and persists provider id', 0, async () => {
      const context: Context = getTestContext()
      const login: AuthResult = await AuthService.loginWithThirdParty(context, 'wechat')
      expect(login.success).assertTrue()
      const snapshot: SessionSnapshot | null = await SessionManager.getSession(context)
      expect(snapshot !== null).assertTrue()
      if (snapshot !== null) {
        expect(snapshot.providerId).assertEqual('wechat')
        expect(snapshot.userId).assertEqual('sandbox:wechat')
      }
    })

    it('logout clears session snapshot for the next cold start', 0, async () => {
      const context: Context = getTestContext()
      await AuthService.requestPhoneCode(context, '13700006666')
      await AuthService.loginWithPhoneCode(context, '13700006666', '000000')
      expect(await SessionManager.isLoggedIn(context)).assertTrue()

      await AuthService.logout(context)
      expect(await SessionManager.isLoggedIn(context)).assertFalse()
      expect(await SessionManager.getSession(context)).assertNull()
    })
  })
}
