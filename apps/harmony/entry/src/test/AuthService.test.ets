/**
 * SandboxAuthProvider 单元测试（本地单元环境，无 Context）
 *
 * 覆盖沙盒认证核心逻辑：手机验证码（发送/校验/限流）、邮箱注册/登录、
 * 第三方登录与会话生命周期。门面级（带 Context）用例见 ohosTest/AuthService.test.ets。
 */
import { describe, it, expect, beforeEach } from '@ohos/hypium'
import SandboxAuthProvider from '../main/ets/common/services/auth/SandboxAuthProvider'

export default function authServiceTest() {
  describe('SandboxAuthProvider — phone code flow', () => {
    beforeEach(() => {
      SandboxAuthProvider.clearAllData()
    })

    it('issues the demo code and logs in with it', 0, async () => {
      const issue = await SandboxAuthProvider.requestPhoneCode('15000000001')
      expect(issue.success).assertTrue()
      expect(issue.devCodeHint).assertEqual('000000')
      expect(issue.message).assertEqual('验证码已发送')

      const login = await SandboxAuthProvider.loginWithPhoneCode('15000000001', '000000')
      expect(login.success).assertTrue()
      expect(login.message).assertEqual('登录成功')
      expect(login.session !== null).assertTrue()
      if (login.session !== null) {
        expect(login.session.phone).assertEqual('15000000001')
        expect(login.session.userId).assertEqual('sandbox:15000000001')
        expect(login.session.providerId).assertEqual('phone_code')
      }
    })

    it('rejects invalid phone format on code request', 0, async () => {
      const issue = await SandboxAuthProvider.requestPhoneCode('12345')
      expect(issue.success).assertFalse()
      expect(issue.message).assertEqual('请输入正确的手机号')
      expect(issue.devCodeHint).assertEqual('')
    })

    it('rejects login before a code has been issued', 0, async () => {
      const login = await SandboxAuthProvider.loginWithPhoneCode('15000000009', '000000')
      expect(login.success).assertFalse()
      expect(login.message).assertEqual('请先获取验证码')
      expect(login.session).assertNull()
    })

    it('rejects a wrong verification code', 0, async () => {
      await SandboxAuthProvider.requestPhoneCode('15000000002')
      const login = await SandboxAuthProvider.loginWithPhoneCode('15000000002', '111111')
      expect(login.success).assertFalse()
      expect(login.message).assertEqual('验证码错误，请重试')
    })

    it('rate limits repeated code requests', 0, async () => {
      await SandboxAuthProvider.requestPhoneCode('15000000003')
      const second = await SandboxAuthProvider.requestPhoneCode('15000000003')
      expect(second.success).assertFalse()
      expect(second.message).assertEqual('验证码已发送，请稍后再试')
    })

    it('trims the phone number before issuing and checking', 0, async () => {
      await SandboxAuthProvider.requestPhoneCode('  15000000004  ')
      const login = await SandboxAuthProvider.loginWithPhoneCode(' 15000000004 ', '000000')
      expect(login.success).assertTrue()
    })
  })

  describe('SandboxAuthProvider — email flow', () => {
    beforeEach(() => {
      SandboxAuthProvider.clearAllData()
    })

    it('registers with email and logs in with password', 0, async () => {
      await SandboxAuthProvider.requestEmailCode('athlete@example.com')
      const register = await SandboxAuthProvider.registerWithEmail('athlete@example.com', 'password1', '000000', '小明')
      expect(register.success).assertTrue()
      expect(register.message).assertEqual('登录成功')
      expect(register.session !== null).assertTrue()
      if (register.session !== null) {
        expect(register.session.displayName).assertEqual('小明')
        expect(register.session.userId).assertEqual('sandbox:athlete@example.com')
        expect(register.session.providerId).assertEqual('email_password')
      }

      const login = await SandboxAuthProvider.loginWithEmailPassword('athlete@example.com', 'password1')
      expect(login.success).assertTrue()

      const wrong = await SandboxAuthProvider.loginWithEmailPassword('athlete@example.com', 'wrongpass1')
      expect(wrong.success).assertFalse()
      expect(wrong.message).assertEqual('密码错误，请重试')
    })

    it('rejects duplicate email registration', 0, async () => {
      await SandboxAuthProvider.requestEmailCode('dupe@example.com')
      const first = await SandboxAuthProvider.registerWithEmail('dupe@example.com', 'password1', '000000', '一号')
      expect(first.success).assertTrue()
      const second = await SandboxAuthProvider.registerWithEmail('dupe@example.com', 'password2', '000000', '二号')
      expect(second.success).assertFalse()
      expect(second.message).assertEqual('该邮箱已注册')
    })

    it('rejects short password on registration', 0, async () => {
      await SandboxAuthProvider.requestEmailCode('short@example.com')
      const register = await SandboxAuthProvider.registerWithEmail('short@example.com', '1234567', '000000', '短密码')
      expect(register.success).assertFalse()
      expect(register.message).assertEqual('密码至少 8 位')
    })

    it('rejects unknown email login', 0, async () => {
      const login = await SandboxAuthProvider.loginWithEmailPassword('nobody@example.com', 'password1')
      expect(login.success).assertFalse()
      expect(login.message).assertEqual('该邮箱尚未注册，请先注册')
    })

    it('rejects invalid email format on code request', 0, async () => {
      const issue = await SandboxAuthProvider.requestEmailCode('not-an-email')
      expect(issue.success).assertFalse()
      expect(issue.message).assertEqual('请输入正确的邮箱')
    })
  })

  describe('SandboxAuthProvider — third party and sign out', () => {
    beforeEach(() => {
      SandboxAuthProvider.clearAllData()
    })

    it('creates a session for third party login', 0, async () => {
      const result = await SandboxAuthProvider.loginWithThirdParty('huawei')
      expect(result.success).assertTrue()
      expect(result.session !== null).assertTrue()
      if (result.session !== null) {
        expect(result.session.userId).assertEqual('sandbox:huawei')
        expect(result.session.providerId).assertEqual('huawei')
        expect(result.session.displayName).assertEqual('华为用户')
      }
      expect(SandboxAuthProvider.getCurrentSession() !== null).assertTrue()
    })

    it('clears the current session on sign out', 0, async () => {
      await SandboxAuthProvider.loginWithThirdParty('wechat')
      expect(SandboxAuthProvider.getCurrentSession() !== null).assertTrue()
      await SandboxAuthProvider.signOut()
      expect(SandboxAuthProvider.getCurrentSession()).assertNull()
    })

    it('clearAllData resets users codes and session', 0, async () => {
      await SandboxAuthProvider.requestPhoneCode('15000000005')
      await SandboxAuthProvider.loginWithPhoneCode('15000000005', '000000')
      SandboxAuthProvider.clearAllData()
      expect(SandboxAuthProvider.getCurrentSession()).assertNull()
      const relogin = await SandboxAuthProvider.loginWithPhoneCode('15000000005', '000000')
      expect(relogin.success).assertFalse()
      expect(relogin.message).assertEqual('请先获取验证码')
    })
  })
}
