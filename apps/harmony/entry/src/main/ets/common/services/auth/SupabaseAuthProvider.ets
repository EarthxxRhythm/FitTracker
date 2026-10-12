/**
 * SupabaseAuthProvider —— 自托管 Supabase（GoTrue）认证实现。
 *
 * 端点与请求体逐条对齐 Android 侧 apps/android/app/src/main/java/com/fittracker/app/data/cloud/
 * SupabaseAuthProvider.kt：signup / token?grant_type=password / token?grant_type=refresh_token /
 * otp / verify / logout；手机号归一（非 + 开头补 +86）、伪邮箱域 phone.fittracker.app 同源。
 *
 * 会话策略：token 组存 SupabaseSessionStore（AuthSession 无 token 字段，承载不了刷新）；
 * getCurrentSession() 是同步抽象方法，故用内存缓存（与 AgcAuthProvider 的「权威来源 + 内存镜像」
 * 模式同构），缓存在 attachContext 时由持久化会话预热、登录成功后更新。
 *
 * 第三方登录：Supabase 侧未接（与 Android 一致，wechat/qq 明确降级）；seedAccount 与
 * clearPersisted 按抽象注释的语义实现（前者返回 null、后者清本地会话）。
 */
import { Context } from '@kit.AbilityKit'
import { AuthProvider } from './AuthProvider'
import {
  AuthResult,
  AuthSession,
  VerifyCodeResult,
  createAuthSession,
  createAuthResult,
  createVerifyCodeResult
} from './AuthTypes'
import { SupabaseHttp, SupabaseHttpResult } from '../SupabaseHttp'
import SupabaseSessionStore, { SupabaseSessionData } from '../SupabaseSessionStore'

/** GoTrue 端点路径（对齐 Android 的常量表）。 */
const PATH_SIGNUP: string = 'signup'
const PATH_TOKEN_PASSWORD: string = 'token?grant_type=password'
const PATH_OTP: string = 'otp'
const PATH_VERIFY: string = 'verify'
const PATH_LOGOUT: string = 'logout'

/** 伪邮箱域（手机号 ↔ 邮箱制后端的桥接，对齐 Android INTERNAL_EMAIL_DOMAIN）。 */
const INTERNAL_EMAIL_DOMAIN: string = 'phone.fittracker.app'

const PROVIDER_ID: string = 'supabase'

/** GoTrue 会话响应（/token 与 /verify 的公共形状）。 */
interface GoTrueSessionResponse {
  access_token: string
  refresh_token: string
  expires_in: number
  user: GoTrueUser
}

interface GoTrueUser {
  id: string
  phone: string
  email: string
  user_metadata: GoTrueUserMetadata
}

interface GoTrueUserMetadata {
  nickname: string
}

/** 请求体形状（ArkTS 需显式类型，不以匿名对象字面量传入）。 */
interface PhoneOtpRequest {
  phone: string
}

interface EmailOtpRequest {
  email: string
}

interface VerifyOtpRequest {
  phone: string
  token: string
  type: string
}

interface EmailSignUpRequest {
  email: string
  password: string
  data: EmailSignUpData
}

interface EmailSignUpData {
  nickname: string
}

interface PasswordTokenRequest {
  email: string
  password: string
}

/** 手机号归一：已以 '+' 开头则透传，否则补 +86（对齐 Android normalizePhoneE164）。 */
function normalizePhoneE164(phone: string): string {
  const trimmed: string = phone.trim()
  if (trimmed.startsWith('+')) {
    return trimmed
  }
  return '+86' + trimmed
}

/** E.164 反解为本地展示号（去 +86 前缀）。 */
function phoneFromE164(e164: string): string {
  if (e164.startsWith('+86')) {
    return e164.substring(3)
  }
  return e164
}

/** 账号归一：不含 '@' 视为手机号，拼伪邮箱域（对齐 Android normalizeAccount）。 */
function normalizeAccount(account: string): string {
  const trimmed: string = account.trim()
  if (trimmed.includes('@')) {
    return trimmed
  }
  return trimmed + '@' + INTERNAL_EMAIL_DOMAIN
}

class SupabaseAuthProvider extends AuthProvider {
  private context: Context | null = null
  private cachedSession: AuthSession | null = null

  getProviderId(): string {
    return PROVIDER_ID
  }

  isAvailable(): boolean {
    return SupabaseHttp.isConfigured()
  }

  /** 幂等注入 Context，并用持久化会话预热内存缓存。 */
  async attachContext(context: Context): Promise<void> {
    this.context = context
    if (this.cachedSession === null) {
      const stored: SupabaseSessionData | null = await SupabaseSessionStore.load(context)
      if (stored !== null) {
        this.cachedSession = createAuthSession(
          stored.userId,
          stored.nickname,
          stored.phone,
          stored.email,
          PROVIDER_ID,
          Date.now()
        )
      }
    }
  }

  /** 发送手机验证码：POST /auth/v1/otp {phone}。 */
  async requestPhoneCode(phone: string): Promise<VerifyCodeResult> {
    if (!this.isAvailable()) {
      return createVerifyCodeResult(false, '云服务未就绪，请稍后重试', '')
    }
    const request: PhoneOtpRequest = { phone: normalizePhoneE164(phone) }
    const response: SupabaseHttpResult =
      await SupabaseHttp.post(SupabaseHttp.authUrl(PATH_OTP), JSON.stringify(request), null)
    if (this.isOk(response)) {
      return createVerifyCodeResult(true, '验证码已发送', '')
    }
    return createVerifyCodeResult(false, this.describeError(response), '')
  }

  /** 手机验证码登录：POST /auth/v1/verify {phone, token, type:'sms'}（未注册号由 GoTrue 自动建号）。 */
  async loginWithPhoneCode(phone: string, code: string): Promise<AuthResult> {
    if (!this.isAvailable()) {
      return createAuthResult(false, '云服务未就绪，请稍后重试', null)
    }
    const e164: string = normalizePhoneE164(phone)
    const request: VerifyOtpRequest = { phone: e164, token: code.trim(), type: 'sms' }
    const response: SupabaseHttpResult =
      await SupabaseHttp.post(SupabaseHttp.authUrl(PATH_VERIFY), JSON.stringify(request), null)
    return this.persistSessionFrom(response, phoneFromE164(e164), '')
  }

  /** 发送邮箱验证码：POST /auth/v1/otp {email}。 */
  async requestEmailCode(email: string): Promise<VerifyCodeResult> {
    if (!this.isAvailable()) {
      return createVerifyCodeResult(false, '云服务未就绪，请稍后重试', '')
    }
    const request: EmailOtpRequest = { email: email.trim() }
    const response: SupabaseHttpResult =
      await SupabaseHttp.post(SupabaseHttp.authUrl(PATH_OTP), JSON.stringify(request), null)
    if (this.isOk(response)) {
      return createVerifyCodeResult(true, '验证码已发送', '')
    }
    return createVerifyCodeResult(false, this.describeError(response), '')
  }

  /**
   * 邮箱注册：POST /auth/v1/signup {email, password, data:{nickname}}。
   * 注：code 参数保留于抽象签名（沙盒/AGC 语义），Supabase 侧由服务端的邮箱确认策略承担，
   * 故不随请求上行——与 Android 实现一致。
   */
  async registerWithEmail(email: string, password: string, code: string, nickname: string): Promise<AuthResult> {
    if (!this.isAvailable()) {
      return createAuthResult(false, '云服务未就绪，请稍后重试', null)
    }
    const data: EmailSignUpData = { nickname: nickname }
    const request: EmailSignUpRequest = { email: normalizeAccount(email), password: password, data: data }
    const response: SupabaseHttpResult =
      await SupabaseHttp.post(SupabaseHttp.authUrl(PATH_SIGNUP), JSON.stringify(request), null)
    if (this.isOk(response)) {
      // 有 session 则直通登录；无（待邮箱确认）则返回明确提示
      const result: AuthResult = await this.persistSessionFrom(response, '', normalizeAccount(email))
      if (result.success) {
        return result
      }
      return createAuthResult(false, '确认邮件已发送——完成邮箱确认后再登录', null)
    }
    return createAuthResult(false, this.describeError(response), null)
  }

  /** 邮箱密码登录：POST /auth/v1/token?grant_type=password {email, password}。 */
  async loginWithEmailPassword(email: string, password: string): Promise<AuthResult> {
    if (!this.isAvailable()) {
      return createAuthResult(false, '云服务未就绪，请稍后重试', null)
    }
    const request: PasswordTokenRequest = { email: normalizeAccount(email), password: password }
    const response: SupabaseHttpResult =
      await SupabaseHttp.post(SupabaseHttp.authUrl(PATH_TOKEN_PASSWORD), JSON.stringify(request), null)
    return this.persistSessionFrom(response, '', normalizeAccount(email))
  }

  /** 第三方登录：Supabase 侧未接（与 Android 一致）。 */
  async loginWithThirdParty(thirdPartyId: string): Promise<AuthResult> {
    return createAuthResult(false, '当前云端不支持第三方登录', null)
  }

  /** 退出登录：先请求 GoTrue 登出（失败忽略），再清本地会话与缓存。 */
  async signOut(): Promise<void> {
    const context: Context | null = this.context
    if (context !== null) {
      const stored: SupabaseSessionData | null = await SupabaseSessionStore.load(context)
      if (stored !== null) {
        await SupabaseHttp.post(SupabaseHttp.authUrl(PATH_LOGOUT), '', stored.accessToken)
      }
      await SupabaseSessionStore.clear(context)
    }
    this.cachedSession = null
  }

  /** 提供方侧当前会话（内存镜像；真源为 SupabaseSessionStore）。 */
  getCurrentSession(): AuthSession | null {
    return this.cachedSession
  }

  /** 播种账号为沙盒/测试专用语义；Supabase 实现返回 null（对齐抽象注释）。 */
  async seedAccount(context: Context, phone: string, nickname: string): Promise<AuthSession | null> {
    return null
  }

  /** 清空内存状态。 */
  clearAllData(): void {
    this.cachedSession = null
  }

  /** 清空本地持久化会话（登出/测试清理）。 */
  async clearPersisted(context: Context): Promise<void> {
    await SupabaseSessionStore.clear(context)
    this.cachedSession = null
  }

  // --- 私有辅助 -----------------------------------------------------------

  /** 2xx 视为成功。 */
  private isOk(response: SupabaseHttpResult): boolean {
    return response.status >= 200 && response.status <= 299
  }

  /** 从 GoTrue 会话响应落库并构造 AuthResult（手机号与邮箱至少其一有值）。 */
  private async persistSessionFrom(response: SupabaseHttpResult, fallbackPhone: string,
                                   fallbackEmail: string): Promise<AuthResult> {
    if (!this.isOk(response)) {
      return createAuthResult(false, this.describeError(response), null)
    }
    const context: Context | null = this.context
    if (context === null) {
      return createAuthResult(false, '认证上下文缺失，请重试', null)
    }
    try {
      const parsed: GoTrueSessionResponse = JSON.parse(response.body) as GoTrueSessionResponse
      if (parsed.access_token.length === 0) {
        return createAuthResult(false, '响应缺少访问令牌', null)
      }
      const rawPhone: string = parsed.user.phone.length > 0 ? phoneFromE164(parsed.user.phone) : fallbackPhone
      const rawEmail: string = rawPhone.length > 0 ? '' : (parsed.user.email.length > 0 ? parsed.user.email : fallbackEmail)
      const nickname: string = parsed.user.user_metadata.nickname
      const stored: SupabaseSessionData = {
        accessToken: parsed.access_token,
        refreshToken: parsed.refresh_token,
        expiresAtEpochSeconds: Math.floor(Date.now() / 1000) + parsed.expires_in,
        userId: parsed.user.id,
        phone: rawPhone,
        email: rawEmail,
        nickname: nickname
      }
      await SupabaseSessionStore.save(context, stored)
      const session: AuthSession = createAuthSession(
        parsed.user.id,
        nickname,
        rawPhone,
        rawEmail,
        PROVIDER_ID,
        Date.now()
      )
      this.cachedSession = session
      return createAuthResult(true, '登录成功', session)
    } catch (error) {
      return createAuthResult(false, '响应解析失败，请稍后重试', null)
    }
  }

  /** 失败文案：优先取服务端错误描述，取不到给通用文案。 */
  private describeError(response: SupabaseHttpResult): string {
    if (response.status === 0) {
      return '网络不可达，请检查网络后重试'
    }
    if (response.status === 400 || response.status === 401 || response.status === 422) {
      return '账号或验证码不正确'
    }
    if (response.status === 429) {
      return '请求过于频繁，请稍后再试'
    }
    return '服务暂时不可用，请稍后重试'
  }
}

export default new SupabaseAuthProvider()
