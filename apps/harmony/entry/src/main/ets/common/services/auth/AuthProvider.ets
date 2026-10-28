/**
 * AuthProvider —— 认证后端抽象。
 *
 * 实现：
 *  - SandboxAuthProvider：本地沙盒（云端配置缺失 / 测试环境时降级使用）
 *  - SupabaseAuthProvider：自建服务器认证服务（supabase.json 就绪后接入）
 *
 * 所有方法返回 Promise 以对齐云端异步语义；沙盒实现内部为同步逻辑。
 */
import { Context } from '@kit.AbilityKit'
import { AuthResult, AuthSession, VerifyCodeResult } from './AuthTypes'

export abstract class AuthProvider {
  /** 提供方标识：'sandbox' | 'supabase'。 */
  abstract getProviderId(): string

  /** 当前环境是否可用（云端模式需初始化成功）。 */
  abstract isAvailable(): boolean

  /** 幂等注入宿主 Context（云端配置装载 / 沙盒持久化加载）。 */
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

  /**
   * 第三方登录（两段式第二段）。
   *
   * @param thirdPartyId 通道标识：'huawei' | 'wechat' | 'qq'
   * @param authCode 端侧 SDK 授权码。空串表示「由 Provider 自行拉起授权」——
   *                 仅华为账号通道适用（其凭据由 Account Kit 内部完成用户交互）；
   *                 Supabase 后端要求非空 authCode（走服务端换票）。
   */
  abstract loginWithThirdParty(thirdPartyId: string, authCode: string): Promise<AuthResult>

  /** 退出登录（清理提供方会话）。 */
  abstract signOut(): Promise<void>

  /** 提供方侧当前会话（云端为权威来源；沙盒为内存镜像）。 */
  abstract getCurrentSession(): AuthSession | null

  /** 播种/测试专用：直接创建账号并返回会话（沙盒实现；云端实现返回 null）。 */
  abstract seedAccount(context: Context, phone: string, nickname: string): Promise<AuthSession | null>

  /** 清空内存状态（测试与门面清理使用）。 */
  abstract clearAllData(): void

  /** 清空持久化状态（沙盒存储清理；云端实现为空操作）。 */
  abstract clearPersisted(context: Context): Promise<void>
}
