/**
 * AuthTypes —— 认证域公共类型与工厂函数。
 *
 * 供 AuthService 门面、AuthProvider 实现（Sandbox / AGC）与页面层共用。
 * ArkTS 严格模式：显式类型 + 工厂函数构造（不依赖对象字面量推断）。
 */

/** 登录页模式：手机验证码 / 邮箱密码。 */
export type LoginMode = 'phone' | 'email'

/** 第三方登录通道。 */
export type ThirdPartyId = 'huawei' | 'wechat' | 'qq'

/** 会话快照 —— 登录成功后写入 SessionManager，供启动分流与 UI 展示。 */
export interface AuthSession {
  userId: string
  displayName: string
  phone: string
  email: string
  providerId: string
  signedInAt: number
}

/** 认证操作结果。session 为 null 时表示失败。 */
export interface AuthResult {
  success: boolean
  message: string
  session: AuthSession | null
}

/** 验证码请求结果。devCodeHint 仅沙盒模式回显（生产为空串）。 */
export interface VerifyCodeResult {
  success: boolean
  message: string
  devCodeHint: string
}

/**
 * 端侧 SDK 授权结果 —— 拉起第三方 App 后回传的一次性凭据。
 *
 * 与 AuthResult 的区别：本结构描述「授权」阶段的完成（尚未建立本应用会话），
 * 是两段式登录的第一段产物。第二段（authCode → 服务端换票 → 会话）见
 * SupabaseAuthProvider.loginWithThirdParty。
 */
export interface ThirdPartyAuthCode {
  providerId: ThirdPartyId
  authCode: string
  /** 防 CSRF 的 state 回显（微信 / QQ / 华为均支持）。 */
  state: string
}

/** 第三方授权阶段的失败结果（用户在对方 App 内取消、未安装客户端等）。 */
export interface ThirdPartyAuthFailure {
  providerId: ThirdPartyId
  message: string
  /** 'cancelled' = 用户主动取消（静默返回）；'unavailable' = 未安装/不可用；'error' = 其他。 */
  kind: ThirdPartyAuthFailureKind
}

/** 授权失败类别（显式联合类型，ArkTS 不使用匿名字符串字面量推断）。 */
export type ThirdPartyAuthFailureKind = 'cancelled' | 'unavailable' | 'error'

/** 换票请求体（端侧 → Edge Function thirdparty-exchange 的契约形状）。 */
export interface ThirdPartyExchangeRequest {
  provider: string
  authCode: string
  state: string
}

/** 换票响应体（Edge Function → 端侧）；token_hash 交由 /auth/v1/verify 换取正式会话。 */
export interface ThirdPartyExchangeResponse {
  token_hash: string
  type: string
  user_id: string
  is_new_user: boolean
}

export function createAuthSession(
  userId: string,
  displayName: string,
  phone: string,
  email: string,
  providerId: string,
  signedInAt: number
): AuthSession {
  const session: AuthSession = {
    userId: userId,
    displayName: displayName,
    phone: phone,
    email: email,
    providerId: providerId,
    signedInAt: signedInAt
  }
  return session
}

export function createAuthResult(
  success: boolean,
  message: string,
  session: AuthSession | null
): AuthResult {
  const result: AuthResult = {
    success: success,
    message: message,
    session: session
  }
  return result
}

export function createVerifyCodeResult(
  success: boolean,
  message: string,
  devCodeHint: string
): VerifyCodeResult {
  const result: VerifyCodeResult = {
    success: success,
    message: message,
    devCodeHint: devCodeHint
  }
  return result
}
