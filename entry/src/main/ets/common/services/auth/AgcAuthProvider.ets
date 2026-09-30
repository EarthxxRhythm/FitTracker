/**
 * AgcAuthProvider —— AGC 认证服务实现（@hw-agconnect/auth）。
 *
 * 前提：CloudEnvironment.initialize 已成功执行 auth.init（agconnect-services.json 就绪）。
 * 语义对齐 SandboxAuthProvider：
 *  - 手机验证码：REGISTER_LOGIN 动作；未注册手机号自动建号（signIn.autoCreateUser）
 *  - 邮箱：验证码登录（自动建号）/ 邮箱 + 密码登录 / 注册（createUser，昵称经 updateProfile）
 *  - 华为账号：hwid 凭据；微信 / QQ 当前 SDK（1.1.0）CredentialInfo 未提供对应凭据类型，
 *    明确提示「暂未开通」降级（资质与 SDK 支持确认后再接线）
 *  - 会话权威来源为 AGC SDK（getCurrentUser）；本类仅缓存镜像供同步接口使用
 */
import { Context } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import auth from '@hw-agconnect/auth'
import {
  AuthUser,
  EmailCredentialInfo,
  EmailVerifyCode,
  HwIdCredentialInfo,
  PhoneCredentialInfo,
  PhoneVerifyCode,
  SignInParam,
  SignInResult,
  UserProfileInfo,
  VerifyCodeAction,
  VerifyCodeParam
} from '@hw-agconnect/auth'
import { AuthProvider } from './AuthProvider'
import {
  AuthResult,
  AuthSession,
  VerifyCodeResult,
  createAuthResult,
  createAuthSession,
  createVerifyCodeResult
} from './AuthTypes'

const COUNTRY_CODE: string = '86'
const LANG: string = 'zh_CN'
const SEND_INTERVAL_SECONDS: number = 60
const PHONE_PATTERN: RegExp = /^1[3-9]\d{9}$/
const EMAIL_PATTERN: RegExp = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

class AgcAuthProvider extends AuthProvider {
  private sessionCache: AuthSession | null = null

  getProviderId(): string {
    return 'agc'
  }

  isAvailable(): boolean {
    return true
  }

  /** AGC 会话由 SDK 自持（auth.init 已在 CloudEnvironment 完成），无本地状态需加载。 */
  async attachContext(context: Context): Promise<void> {
  }

  async requestPhoneCode(phone: string): Promise<VerifyCodeResult> {
    const trimmed: string = phone.trim()
    if (!PHONE_PATTERN.test(trimmed)) {
      return createVerifyCodeResult(false, '请输入正确的手机号', '')
    }
    try {
      const verifyCodeType: PhoneVerifyCode = {
        kind: 'phone',
        phoneNumber: trimmed,
        countryCode: COUNTRY_CODE
      }
      const param: VerifyCodeParam = {
        verifyCodeType: verifyCodeType,
        action: VerifyCodeAction.REGISTER_LOGIN,
        lang: LANG,
        sendInterval: SEND_INTERVAL_SECONDS
      }
      await auth.requestVerifyCode(param)
      return createVerifyCodeResult(true, '验证码已发送', '')
    } catch (error) {
      return createVerifyCodeResult(false, this.describeError(error, '验证码发送失败，请稍后重试'), '')
    }
  }

  async loginWithPhoneCode(phone: string, code: string): Promise<AuthResult> {
    const trimmed: string = phone.trim()
    if (!PHONE_PATTERN.test(trimmed)) {
      return createAuthResult(false, '请输入正确的手机号', null)
    }
    const trimmedCode: string = code.trim()
    if (trimmedCode.length === 0) {
      return createAuthResult(false, '请输入验证码', null)
    }
    try {
      const credential: PhoneCredentialInfo = {
        kind: 'phone',
        countryCode: COUNTRY_CODE,
        phoneNumber: trimmed,
        verifyCode: trimmedCode
      }
      const param: SignInParam = { credentialInfo: credential, autoCreateUser: true }
      const result: SignInResult = await auth.signIn(param)
      return this.toAuthResult(result, 'phone_code', '')
    } catch (error) {
      return createAuthResult(false, this.describeError(error, '登录失败，请稍后重试'), null)
    }
  }

  async requestEmailCode(email: string): Promise<VerifyCodeResult> {
    const trimmed: string = email.trim()
    if (!EMAIL_PATTERN.test(trimmed)) {
      return createVerifyCodeResult(false, '请输入正确的邮箱', '')
    }
    try {
      const verifyCodeType: EmailVerifyCode = { kind: 'email', email: trimmed }
      const param: VerifyCodeParam = {
        verifyCodeType: verifyCodeType,
        action: VerifyCodeAction.REGISTER_LOGIN,
        lang: LANG,
        sendInterval: SEND_INTERVAL_SECONDS
      }
      await auth.requestVerifyCode(param)
      return createVerifyCodeResult(true, '验证码已发送', '')
    } catch (error) {
      return createVerifyCodeResult(false, this.describeError(error, '验证码发送失败，请稍后重试'), '')
    }
  }

  async registerWithEmail(email: string, password: string, code: string, nickname: string): Promise<AuthResult> {
    const trimmedEmail: string = email.trim()
    if (!EMAIL_PATTERN.test(trimmedEmail)) {
      return createAuthResult(false, '请输入正确的邮箱', null)
    }
    if (password.length < 8) {
      return createAuthResult(false, '密码至少 8 位', null)
    }
    const trimmedCode: string = code.trim()
    if (trimmedCode.length === 0) {
      return createAuthResult(false, '请输入验证码', null)
    }
    try {
      const credential: EmailCredentialInfo = {
        kind: 'email',
        email: trimmedEmail,
        password: password,
        verifyCode: trimmedCode
      }
      const result: SignInResult = await auth.createUser(credential)
      const trimmedNickname: string = nickname.trim()
      if (trimmedNickname.length > 0) {
        try {
          const profile: UserProfileInfo = { displayName: trimmedNickname, photoUrl: '' }
          await result.getUser().updateProfile(profile)
        } catch (profileError) {
          // 昵称写入失败不阻断注册（会话展示名缺失时由 SDK 返回的显示名兜底）
          const err: BusinessError = profileError as BusinessError
          hilog.warn(0x0000, 'AgcAuthProvider', 'updateProfile failed: code=' + err.code + ' message=' + err.message)
        }
      }
      return this.toAuthResult(result, 'email_password', trimmedNickname)
    } catch (error) {
      return createAuthResult(false, this.describeError(error, '注册失败，请稍后重试'), null)
    }
  }

  async loginWithEmailPassword(email: string, password: string): Promise<AuthResult> {
    const trimmedEmail: string = email.trim()
    if (!EMAIL_PATTERN.test(trimmedEmail)) {
      return createAuthResult(false, '请输入正确的邮箱', null)
    }
    try {
      const credential: EmailCredentialInfo = { kind: 'email', email: trimmedEmail, password: password }
      const param: SignInParam = { credentialInfo: credential, autoCreateUser: false }
      const result: SignInResult = await auth.signIn(param)
      return this.toAuthResult(result, 'email_password', '')
    } catch (error) {
      return createAuthResult(false, this.describeError(error, '登录失败，请稍后重试'), null)
    }
  }

  async loginWithThirdParty(thirdPartyId: string): Promise<AuthResult> {
    if (thirdPartyId !== 'huawei') {
      return createAuthResult(false, '当前版本暂未开通该登录方式，请使用手机号或邮箱登录', null)
    }
    try {
      const credential: HwIdCredentialInfo = { kind: 'hwid' }
      const param: SignInParam = { credentialInfo: credential, autoCreateUser: true }
      const result: SignInResult = await auth.signIn(param)
      return this.toAuthResult(result, 'huawei', '')
    } catch (error) {
      return createAuthResult(false, this.describeError(error, '华为账号登录失败，请稍后重试'), null)
    }
  }

  async signOut(): Promise<void> {
    try {
      await auth.signOut()
    } catch (error) {
      // 离线时也须保证本地可退出：失败仅记录，不阻断登出流程
      const err: BusinessError = error as BusinessError
      hilog.error(0x0000, 'AgcAuthProvider', 'signOut failed: code=' + err.code + ' message=' + err.message)
    }
    this.sessionCache = null
  }

  getCurrentSession(): AuthSession | null {
    return this.sessionCache
  }

  /** AGC 不支持播种账号（沙盒/调试能力），恒返回 null。 */
  async seedAccount(context: Context, phone: string, nickname: string): Promise<AuthSession | null> {
    return null
  }

  clearAllData(): void {
    this.sessionCache = null
  }

  async clearPersisted(context: Context): Promise<void> {
    this.sessionCache = null
  }

  private toAuthResult(result: SignInResult, providerId: string, displayNameOverride: string): AuthResult {
    const user: AuthUser = result.getUser()
    const displayName: string = displayNameOverride.length > 0 ? displayNameOverride : user.getDisplayName()
    const session: AuthSession = createAuthSession(
      user.getUid(),
      displayName,
      user.getPhone(),
      user.getEmail(),
      providerId,
      Date.now()
    )
    this.sessionCache = session
    return createAuthResult(true, '登录成功', session)
  }

  /** 错误文案：保留用户可读兜底 + 附加 SDK 原始消息（便于排障）。 */
  private describeError(error: object, fallback: string): string {
    const err: BusinessError = error as BusinessError
    if (err !== undefined && err !== null && typeof err.message === 'string' && err.message.length > 0) {
      return fallback + '：' + err.message
    }
    return fallback
  }
}

export default new AgcAuthProvider()
