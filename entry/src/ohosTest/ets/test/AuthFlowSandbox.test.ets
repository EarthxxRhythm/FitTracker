/**
 * AuthFlowSandbox —— 沙盒认证流程错误分支与边界测试（ohosTest）。
 *
 * 稳定性说明：hypium 1.0.25 的 Spec.run / runHookFunc 对 async 用例与钩子为裸调用
 * （不 await），同套件内异步链会交错推进。本文件将所有场景收敛在单个 async 用例内
 * 串行断言，清理内联，不依赖异步 beforeEach/afterEach。
 */
import { abilityDelegatorRegistry } from '@kit.TestKit'
import { describe, expect, it } from '@ohos/hypium'
import AuthService from '../../../main/ets/common/services/AuthService'
import SessionManager, { SessionSnapshot } from '../../../main/ets/common/services/SessionManager'
import { AuthResult, VerifyCodeResult } from '../../../main/ets/common/services/auth/AuthTypes'
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

export default function authFlowSandboxTest(): void {
  describe('AuthFlowSandbox', () => {
    it('covers rate limiting duplicate email short password third party and logout in order', 0, async () => {
      const warmup: WarmupOutcome = await ensureWarmup(getTestContext)
      const context: Context = warmup.context
      await acquireAuthSyncGate()
      try {

      // 1) 验证码重复请求限流
      await resetState(context)
      const first: VerifyCodeResult = await AuthService.requestPhoneCode(context, '13700005555')
      expect(first.success).assertTrue()
      const second: VerifyCodeResult = await AuthService.requestPhoneCode(context, '13700005555')
      expect(second.success).assertFalse()
      expect(second.message).assertEqual('验证码已发送，请稍后再试')

      // 2) 邮箱重复注册
      await resetState(context)
      await AuthService.requestEmailCode(context, 'flow@example.com')
      const regFirst: AuthResult = await AuthService.registerWithEmail(context, 'flow@example.com', 'password1', '000000', '一号')
      expect(regFirst.success).assertTrue()
      const regSecond: AuthResult = await AuthService.registerWithEmail(context, 'flow@example.com', 'password2', '000000', '二号')
      expect(regSecond.success).assertFalse()
      expect(regSecond.message).assertEqual('该邮箱已注册')

      // 3) 短密码与非法邮箱
      await resetState(context)
      const shortPwd: AuthResult = await AuthService.registerWithEmail(context, 'shortpw@example.com', '1234567', '000000', '短密码')
      expect(shortPwd.success).assertFalse()
      expect(shortPwd.message).assertEqual('密码至少 8 位')
      const badEmail: VerifyCodeResult = await AuthService.requestEmailCode(context, 'bad-email')
      expect(badEmail.success).assertFalse()
      expect(badEmail.message).assertEqual('请输入正确的邮箱')

      // 4) 微信第三方登录 + 会话快照
      await resetState(context)
      const thirdParty: AuthResult = await AuthService.loginWithThirdParty(context, 'wechat')
      expect(thirdParty.success).assertTrue()
      const snapshot: SessionSnapshot | null = await SessionManager.getSession(context)
      expect(snapshot !== null).assertTrue()
      if (snapshot !== null) {
        expect(snapshot.providerId).assertEqual('wechat')
        expect(snapshot.userId).assertEqual('sandbox:wechat')
      }

      // 5) 退出清除会话
      await AuthService.logout(context)
      expect(await SessionManager.isLoggedIn(context)).assertFalse()
      expect(await SessionManager.getSession(context)).assertNull()

      await resetState(context)
      } finally {
        releaseAuthSyncGate()
      }
    })
  })
}
