/**
 * AuthService 门面测试（ohosTest，带 Context）
 *
 * 覆盖：provider 解析（无 AGC 配置 → sandbox）、验证码登录全链路与会话快照持久化、
 * 邮箱注册/登录、退出清理、DeviceSeed 播种入口。
 *
 * 稳定性说明：hypium 1.0.25 的 Spec.run / SuiteService.runHookFunc 对 async 用例与
 * async 钩子为裸调用（不 await，见 oh_modules/@ohos/hypium/src/main/service.js），
 * 同一进程内的异步链会交错推进，「写后立即读」的断言可能被并发清理链踩掉。
 * 因此本文件将所有异步场景串行收敛在单个 async 用例内（链内 await 保序），
 * 清理逻辑内联在用例开头，不依赖异步 beforeEach/afterEach。
 */
import { abilityDelegatorRegistry } from '@kit.TestKit'
import { describe, expect, it } from '@ohos/hypium'
import AuthService from '../../../main/ets/common/services/AuthService'
import SessionManager, { SessionSnapshot } from '../../../main/ets/common/services/SessionManager'
import { AuthResult, VerifyCodeResult } from '../../../main/ets/common/services/auth/AuthTypes'
import { acquireAuthSyncGate, ensureWarmup, getLastWarmupError, releaseAuthSyncGate, WarmupOutcome } from './AuthSyncTestGate'

function getTestContext(): Context {
  const appContext: Context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext()
  return appContext.getApplicationContext().createModuleContext('entry')
}

async function resetState(context: Context): Promise<void> {
  await SessionManager.clearSession(context)
  await SessionManager.clearToken(context)
  await AuthService.clearPersistedUsers(context)
}

export default function authServiceTest(): void {
  describe('AuthService facade', () => {
    it('runs provider resolution login email logout and seeding flows in order', 0, async () => {
      // context 从预热结果取：进程早期的一次性快照可能尚未绑定（context is invalid）
      const warmup: WarmupOutcome = await ensureWarmup(getTestContext)
      const context: Context = warmup.context
      const warmupSteps: number = warmup.steps
      await acquireAuthSyncGate()
      try {

      // 1) provider 解析（无 AGC 配置 → sandbox）
      await resetState(context)
      expect(AuthService.getActiveProviderId()).assertEqual('sandbox')
      expect(AuthService.isCloudMode()).assertFalse()

      // 2) 手机验证码登录 + 会话快照持久化
      const issue: VerifyCodeResult = await AuthService.requestPhoneCode(context, '13700001111')
      expect(issue.success).assertTrue()
      expect(issue.devCodeHint).assertEqual('000000')
      const login: AuthResult = await AuthService.loginWithPhoneCode(context, '13700001111', '000000')
      expect(login.success).assertTrue()
      expect(login.session !== null).assertTrue()
      const snapshot: SessionSnapshot | null = await SessionManager.getSession(context)
      // 诊断：失败时消息中带出预热步数、预热探测原始错误与持久化错误码（-1 = 预热上限内未就绪）
      const persistError: string = SessionManager.getLastPersistenceError()
      if (snapshot === null) {
        const warmupError: string = getLastWarmupError()
        expect('DIAG,wu:' + warmupSteps.toString() + ',wErr:' + warmupError + ',err:' + persistError)
          .assertEqual('DIAG,wu:ok,wErr:,err:')
      }
      expect('snap:' + (snapshot === null ? 'null' : 'ok') + ',err:' + persistError).assertEqual('snap:ok,err:')
      expect(await SessionManager.isLoggedIn(context)).assertTrue()
      if (snapshot !== null) {
        expect(snapshot.phone).assertEqual('13700001111')
        expect(snapshot.userId).assertEqual('sandbox:13700001111')
        expect(snapshot.providerId).assertEqual('phone_code')
      }

      // 3) 错误验证码不建立会话
      await resetState(context)
      await AuthService.requestPhoneCode(context, '13700002222')
      const wrongCode: AuthResult = await AuthService.loginWithPhoneCode(context, '13700002222', '999999')
      expect(wrongCode.success).assertFalse()
      expect(wrongCode.message).assertEqual('验证码错误，请重试')
      expect(await SessionManager.isLoggedIn(context)).assertFalse()

      // 4) 邮箱注册 → 退出 → 重新登入
      await resetState(context)
      await AuthService.requestEmailCode(context, 'tester@example.com')
      const register: AuthResult = await AuthService.registerWithEmail(
        context,
        'tester@example.com',
        'password1',
        '000000',
        '测试者'
      )
      expect(register.success).assertTrue()
      expect(await SessionManager.isLoggedIn(context)).assertTrue()
      await AuthService.logout(context)
      expect(await SessionManager.isLoggedIn(context)).assertFalse()
      expect(await SessionManager.getSession(context)).assertNull()
      const emailLogin: AuthResult = await AuthService.loginWithEmailPassword(context, 'tester@example.com', 'password1')
      expect(emailLogin.success).assertTrue()
      expect(await SessionManager.isLoggedIn(context)).assertTrue()

      // 5) 第三方登录 + 退出清理
      await resetState(context)
      const thirdParty: AuthResult = await AuthService.loginWithThirdParty(context, 'huawei')
      expect(thirdParty.success).assertTrue()
      const thirdPartySnapshot: SessionSnapshot | null = await SessionManager.getSession(context)
      expect(thirdPartySnapshot !== null).assertTrue()
      if (thirdPartySnapshot !== null) {
        expect(thirdPartySnapshot.providerId).assertEqual('huawei')
      }
      await AuthService.logout(context)
      expect(await SessionManager.isLoggedIn(context)).assertFalse()

      // 6) DeviceSeed 播种入口
      await resetState(context)
      await AuthService.seedSandboxSession(context, '13700004444', '谱尼')
      expect(await SessionManager.isLoggedIn(context)).assertTrue()
      const seededSnapshot: SessionSnapshot | null = await SessionManager.getSession(context)
      expect(seededSnapshot !== null).assertTrue()
      if (seededSnapshot !== null) {
        expect(seededSnapshot.displayName).assertEqual('谱尼')
        expect(seededSnapshot.phone).assertEqual('13700004444')
      }

      // 收尾清理
      await resetState(context)
      } finally {
        releaseAuthSyncGate()
      }
    })
  })
}
