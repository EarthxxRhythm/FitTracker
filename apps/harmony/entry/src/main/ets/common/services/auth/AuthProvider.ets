/**
 * AuthProvider —— 认证后端抽象。
 *
 * 实现：
 *  - SandboxAuthProvider：本地沙盒（AGC 云服务未配置 / 测试环境时降级使用）
 *  - AgcAuthProvider：AGC 认证服务（agconnect-services.json 就绪后接入；Wave 5 已接线）
 *
 * 所有方法返回 Promise 以对齐云端异步语义；沙盒实现内部为同步逻辑。
 */
import { Context } from '@kit.AbilityKit'
import { AuthResult, AuthSession, VerifyCodeResult } from './AuthTypes'

export abstract class AuthProvider {
  /** 提供方标识：'sandbox' | 'agc'。 */
  abstract getProviderId(): string

  /** 当前环境是否可用（AGC 模式需初始化成功）。 */
  abstract isAvailable(): boolean

  /** 幂等注入宿主 Context（AGC 初始化 / 沙盒持久化加载）。 */
  abstract attachContext(context: Context): Promise<void>

  /** 发送手机验证码。 */
  abstract requestPhoneCode(phone: string): Promise<VerifyCodeResult>

  /** 手机验证码登录（未注册手机号自动注册）。 */
  abstract loginWithPhoneCode(phone: string, code: string): Promise<AuthResult>

  /** 发送邮箱验证码。 */
  abstract requestEmailCode(email: string): Promise<VerifyCodeResult>

  /** 邮箱注册（邮箱 + 验证码 + 密码 + 昵称）。 */
  abstract registerWithEmail(email: string, password: string, code: string, nickname: string): Promise<AuthResult>

  /** 邮箱 + 密码登录。 */
  abstract loginWithEmailPassword(email: string, password: string): Promise<AuthResult>

  /** 第三方登录（huawei / wechat / qq）。 */
  abstract loginWithThirdParty(thirdPartyId: string): Promise<AuthResult>

  /** 退出登录（清理提供方会话）。 */
  abstract signOut(): Promise<void>

  /** 提供方侧当前会话（AGC 权威来源；沙盒为内存镜像）。 */
  abstract getCurrentSession(): AuthSession | null

  /** 播种/测试专用：直接创建账号并返回会话（沙盒实现；AGC 实现返回 null）。 */
  abstract seedAccount(context: Context, phone: string, nickname: string): Promise<AuthSession | null>

  /** 清空内存状态（测试与门面清理使用）。 */
  abstract clearAllData(): void

  /** 清空持久化状态（沙盒存储清理；AGC 实现为空操作）。 */
  abstract clearPersisted(context: Context): Promise<void>
}
