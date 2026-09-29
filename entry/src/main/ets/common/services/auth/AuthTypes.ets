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
