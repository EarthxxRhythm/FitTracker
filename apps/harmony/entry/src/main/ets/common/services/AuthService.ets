/**
 * AuthService —— 认证门面（singleton）。
 *
 * 统一入口：探测云环境（cloud / sandbox）并转发到对应 AuthProvider；
 * 登录/注册成功后自动写入 SessionManager 会话快照，供启动分流与 UI 展示。
 * AGC 配置（agconnect-services.json）就绪时云端分支自动切换为 AgcAuthProvider，调用面不变。
 */
import { Context } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { AuthProvider } from './auth/AuthProvider'
import AgcAuthProvider from './auth/AgcAuthProvider'
import SandboxAuthProvider from './auth/SandboxAuthProvider'
import SupabaseAuthProvider from './auth/SupabaseAuthProvider'
import CloudEnvironment, { CloudBackend } from './CloudEnvironment'
import SessionManager from './SessionManager'
import { AuthResult, AuthSession, VerifyCodeResult } from './auth/AuthTypes'

/** 历史 mock 存储（旧版明文用户目录），仅用于清理残留。 */
const LEGACY_STORE_NAME: string = 'fit_tracker_auth'
const LEGACY_KEY_USERS: string = 'users'

class AuthService {
  private provider: AuthProvider | null = null
  private testingProvider: AuthProvider | null = null

  /** 当前生效的认证提供方标识（'sandbox' | 'agc'）。 */
  getActiveProviderId(): string {
    return this.resolveProvider().getProviderId()
  }

  /** 是否运行在 AGC 云认证模式。 */
  isCloudMode(): boolean {
    return this.getActiveProviderId() === 'agc'
  }

  /** 测试注入：替换提供方；传 null 恢复默认解析。 */
  setProviderForTesting(provider: AuthProvider | null): void {
    this.testingProvider = provider
  }

  async requestPhoneCode(context: Context, phone: string): Promise<VerifyCodeResult> {
    const provider: AuthProvider = await this.prepare(context)
    return provider.requestPhoneCode(phone)
  }

  async loginWithPhoneCode(context: Context, phone: string, code: string): Promise<AuthResult> {
    const provider: AuthProvider = await this.prepare(context)
    const result: AuthResult = await provider.loginWithPhoneCode(phone, code)
    await this.persistSessionIfNeeded(context, result)
    return result
  }

  async requestEmailCode(context: Context, email: string): Promise<VerifyCodeResult> {
    const provider: AuthProvider = await this.prepare(context)
    return provider.requestEmailCode(email)
  }

  async registerWithEmail(
    context: Context,
    email: string,
    password: string,
    code: string,
    nickname: string
  ): Promise<AuthResult> {
    const provider: AuthProvider = await this.prepare(context)
    const result: AuthResult = await provider.registerWithEmail(email, password, code, nickname)
    await this.persistSessionIfNeeded(context, result)
    return result
  }

  async loginWithEmailPassword(context: Context, email: string, password: string): Promise<AuthResult> {
    const provider: AuthProvider = await this.prepare(context)
    const result: AuthResult = await provider.loginWithEmailPassword(email, password)
    await this.persistSessionIfNeeded(context, result)
    return result
  }

  async loginWithThirdParty(context: Context, thirdPartyId: string): Promise<AuthResult> {
    const provider: AuthProvider = await this.prepare(context)
    const result: AuthResult = await provider.loginWithThirdParty(thirdPartyId)
    await this.persistSessionIfNeeded(context, result)
    return result
  }

  /** 退出登录：清理提供方会话 + 本地会话快照/token。业务数据清理见 AccountDataLifecycle（Wave 3）。 */
  async logout(context: Context): Promise<void> {
    const provider: AuthProvider = await this.prepare(context)
    await provider.signOut()
    await SessionManager.clearSession(context)
    await SessionManager.clearToken(context)
  }

  /** 供 DeviceSeedService / 测试：在沙盒模式直接播种账号并建立会话快照（AGC 实现不支持时返回 null）。 */
  async seedSandboxSession(context: Context, phone: string, nickname: string): Promise<void> {
    await CloudEnvironment.initialize(context)
    const provider: AuthProvider = this.resolveProvider()
    const session: AuthSession | null = await provider.seedAccount(context, phone, nickname)
    if (session !== null) {
      await SessionManager.saveSession(context, session)
    }
  }

  /** 清空内存用户目录（测试 beforeEach 与门面清理使用）。 */
  clearLocalUsers(): void {
    this.resolveProvider().clearAllData()
  }

  /** 清除持久化用户目录（沙盒存储 + 历史 mock 存储残留）。 */
  async clearPersistedUsers(context: Context): Promise<void> {
    const provider: AuthProvider = await this.prepare(context)
    await provider.clearPersisted(context)
    try {
      const prefs = await preferences.getPreferences(context, LEGACY_STORE_NAME)
      await prefs.delete(LEGACY_KEY_USERS)
      await prefs.flush()
    } catch (error) {
      // 历史存储不存在时无需处理
    }
  }

  private async persistSessionIfNeeded(context: Context, result: AuthResult): Promise<void> {
    if (result.success && result.session !== null) {
      await SessionManager.saveSession(context, result.session)
    }
  }

  private resolveProvider(): AuthProvider {
    if (this.testingProvider !== null) {
      return this.testingProvider
    }
    const backend: CloudBackend = CloudEnvironment.getBackend()
    if (backend === 'supabase') {
      // 自托管 Supabase 配置就绪（rawfile supabase.json 探测通过）时认证走该后端
      return SupabaseAuthProvider
    }
    if (backend === 'agc') {
      // Wave 5 接线：AGC 配置就绪时认证走云端（agconnect-services.json 探测通过）
      return AgcAuthProvider
    }
    if (this.provider === null) {
      this.provider = SandboxAuthProvider
    }
    return this.provider
  }

  private async prepare(context: Context): Promise<AuthProvider> {
    await CloudEnvironment.initialize(context)
    const provider: AuthProvider = this.resolveProvider()
    await provider.attachContext(context)
    return provider
  }
}

export default new AuthService()
