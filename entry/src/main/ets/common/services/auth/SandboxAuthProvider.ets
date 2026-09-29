/**
 * SandboxAuthProvider —— 本地沙盒认证实现。
 *
 * 用途：AGC 云服务未配置（或测试环境）时的降级实现，保证登录/注册/退出全链路可用。
 * 语义对齐 AGC 认证服务：手机验证码登录（首次自动注册）、邮箱+密码注册/登录、第三方登录。
 * 注意：仅用于演示与测试；密码仅做混淆散列（非生产级安全）；验证码为固定演示码 000000。
 */
import { Context } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { AuthProvider } from './AuthProvider'
import {
  AuthResult,
  AuthSession,
  VerifyCodeResult,
  createAuthResult,
  createAuthSession,
  createVerifyCodeResult
} from './AuthTypes'

const SANDBOX_STORE_NAME: string = 'fit_tracker_sandbox_auth'
const KEY_USERS: string = 'users'
/** 沙盒固定演示验证码。 */
const SANDBOX_CODE: string = '000000'
const CODE_TTL_MS: number = 5 * 60 * 1000
const CODE_RESEND_MS: number = 60 * 1000

interface SandboxUserRecord {
  phone: string
  email: string
  nickname: string
  passwordHash: string
  createdAt: number
}

interface SandboxCodeRecord {
  code: string
  expiresAt: number
  sentAt: number
}

class SandboxAuthProvider extends AuthProvider {
  private users: SandboxUserRecord[] = []
  private codes: Map<string, SandboxCodeRecord> = new Map()
  private currentSession: AuthSession | null = null
  private hostContext: Context | null = null
  private loaded: boolean = false

  getProviderId(): string {
    return 'sandbox'
  }

  isAvailable(): boolean {
    return true
  }

  async attachContext(context: Context): Promise<void> {
    if (this.loaded) {
      return
    }
    this.hostContext = context
    await this.loadUsers()
    this.loaded = true
  }

  async requestPhoneCode(phone: string): Promise<VerifyCodeResult> {
    const trimmed: string = phone.trim()
    if (!/^1[3-9]\d{9}$/.test(trimmed)) {
      return createVerifyCodeResult(false, '请输入正确的手机号', '')
    }
    return this.issueCode('phone:' + trimmed)
  }

  async loginWithPhoneCode(phone: string, code: string): Promise<AuthResult> {
    const trimmed: string = phone.trim()
    if (!/^1[3-9]\d{9}$/.test(trimmed)) {
      return createAuthResult(false, '请输入正确的手机号', null)
    }
    const codeCheck: string = this.verifyCode('phone:' + trimmed, code)
    if (codeCheck.length > 0) {
      return createAuthResult(false, codeCheck, null)
    }
    let user: SandboxUserRecord | undefined = this.findUserByPhone(trimmed)
    if (user === undefined) {
      user = this.createUserRecord(trimmed, '', '', '')
      this.users.push(user)
      await this.persistUsers()
    }
    return this.completeSignIn(user, 'phone_code', trimmed, '')
  }

  async requestEmailCode(email: string): Promise<VerifyCodeResult> {
    const trimmed: string = email.trim()
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed)) {
      return createVerifyCodeResult(false, '请输入正确的邮箱', '')
    }
    return this.issueCode('email:' + trimmed)
  }

  async registerWithEmail(email: string, password: string, code: string, nickname: string): Promise<AuthResult> {
    const trimmedEmail: string = email.trim()
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmedEmail)) {
      return createAuthResult(false, '请输入正确的邮箱', null)
    }
    if (password.length < 8) {
      return createAuthResult(false, '密码至少 8 位', null)
    }
    if (this.findUserByEmail(trimmedEmail) !== undefined) {
      return createAuthResult(false, '该邮箱已注册', null)
    }
    const codeCheck: string = this.verifyCode('email:' + trimmedEmail, code)
    if (codeCheck.length > 0) {
      return createAuthResult(false, codeCheck, null)
    }
    const user: SandboxUserRecord = this.createUserRecord('', trimmedEmail, nickname.trim(), password)
    this.users.push(user)
    await this.persistUsers()
    return this.completeSignIn(user, 'email_password', '', trimmedEmail)
  }

  async loginWithEmailPassword(email: string, password: string): Promise<AuthResult> {
    const trimmedEmail: string = email.trim()
    const user: SandboxUserRecord | undefined = this.findUserByEmail(trimmedEmail)
    if (user === undefined) {
      return createAuthResult(false, '该邮箱尚未注册，请先注册', null)
    }
    if (user.passwordHash !== this.hashPassword(password)) {
      return createAuthResult(false, '密码错误，请重试', null)
    }
    return this.completeSignIn(user, 'email_password', '', trimmedEmail)
  }

  async loginWithThirdParty(thirdPartyId: string): Promise<AuthResult> {
    const session: AuthSession = createAuthSession(
      'sandbox:' + thirdPartyId,
      this.resolveThirdPartyName(thirdPartyId),
      '',
      '',
      thirdPartyId,
      Date.now()
    )
    this.currentSession = session
    return createAuthResult(true, '登录成功', session)
  }

  async signOut(): Promise<void> {
    this.currentSession = null
  }

  getCurrentSession(): AuthSession | null {
    return this.currentSession
  }

  /** 供 DeviceSeedService / 测试：直接播种一个手机账号并建立会话。 */
  async seedAccount(context: Context, phone: string, nickname: string): Promise<AuthSession | null> {
    await this.attachContext(context)
    const trimmed: string = phone.trim()
    let user: SandboxUserRecord | undefined = this.findUserByPhone(trimmed)
    if (user === undefined) {
      user = this.createUserRecord(trimmed, '', nickname, '')
      this.users.push(user)
    } else if (nickname.length > 0) {
      user.nickname = nickname
    }
    await this.persistUsers()
    const session: AuthSession = createAuthSession(
      'sandbox:' + trimmed,
      this.resolveDisplayName(user),
      trimmed,
      '',
      'phone_code',
      Date.now()
    )
    this.currentSession = session
    return session
  }

  /** 清空内存状态（测试 / 门面 clearLocalUsers 使用）。 */
  clearAllData(): void {
    this.users = []
    this.codes.clear()
    this.currentSession = null
  }

  /** 清除持久化用户目录（门面 clearPersistedUsers 使用）。 */
  async clearPersisted(context: Context): Promise<void> {
    this.clearAllData()
    // 重置加载标志：下次 attachContext 时按已清空的存储重新加载
    this.loaded = false
    try {
      const prefs = await preferences.getPreferences(context, SANDBOX_STORE_NAME)
      await prefs.delete(KEY_USERS)
      await prefs.flush()
    } catch (error) {
      // 沙盒存储不可用时不阻塞清理
    }
  }

  private issueCode(targetKey: string): VerifyCodeResult {
    const now: number = Date.now()
    const existing: SandboxCodeRecord | undefined = this.codes.get(targetKey)
    if (existing !== undefined && now - existing.sentAt < CODE_RESEND_MS) {
      return createVerifyCodeResult(false, '验证码已发送，请稍后再试', '')
    }
    const record: SandboxCodeRecord = {
      code: SANDBOX_CODE,
      expiresAt: now + CODE_TTL_MS,
      sentAt: now
    }
    this.codes.set(targetKey, record)
    return createVerifyCodeResult(true, '验证码已发送', SANDBOX_CODE)
  }

  private verifyCode(targetKey: string, code: string): string {
    const record: SandboxCodeRecord | undefined = this.codes.get(targetKey)
    if (record === undefined) {
      return '请先获取验证码'
    }
    if (Date.now() > record.expiresAt) {
      return '验证码已过期，请重新获取'
    }
    if (code.trim() !== record.code) {
      return '验证码错误，请重试'
    }
    this.codes.delete(targetKey)
    return ''
  }

  private completeSignIn(
    user: SandboxUserRecord,
    providerId: string,
    phone: string,
    email: string
  ): AuthResult {
    const accountKey: string = phone.length > 0 ? phone : email
    const session: AuthSession = createAuthSession(
      'sandbox:' + accountKey,
      this.resolveDisplayName(user),
      phone,
      email,
      providerId,
      Date.now()
    )
    this.currentSession = session
    return createAuthResult(true, '登录成功', session)
  }

  private resolveDisplayName(user: SandboxUserRecord): string {
    if (user.nickname.length > 0) {
      return user.nickname
    }
    if (user.phone.length >= 4) {
      return '用户' + user.phone.substring(user.phone.length - 4)
    }
    if (user.email.length > 0) {
      const atIndex: number = user.email.indexOf('@')
      if (atIndex > 0) {
        return user.email.substring(0, atIndex)
      }
    }
    return '训练者'
  }

  private resolveThirdPartyName(thirdPartyId: string): string {
    if (thirdPartyId === 'huawei') {
      return '华为用户'
    }
    if (thirdPartyId === 'wechat') {
      return '微信用户'
    }
    if (thirdPartyId === 'qq') {
      return 'QQ 用户'
    }
    return '第三方用户'
  }

  private createUserRecord(phone: string, email: string, nickname: string, rawPassword: string): SandboxUserRecord {
    const record: SandboxUserRecord = {
      phone: phone,
      email: email,
      nickname: nickname,
      passwordHash: rawPassword.length > 0 ? this.hashPassword(rawPassword) : '',
      createdAt: Date.now()
    }
    return record
  }

  private findUserByPhone(phone: string): SandboxUserRecord | undefined {
    for (let index = 0; index < this.users.length; index++) {
      if (this.users[index].phone.length > 0 && this.users[index].phone === phone) {
        return this.users[index]
      }
    }
    return undefined
  }

  private findUserByEmail(email: string): SandboxUserRecord | undefined {
    for (let index = 0; index < this.users.length; index++) {
      if (this.users[index].email.length > 0 && this.users[index].email === email) {
        return this.users[index]
      }
    }
    return undefined
  }

  private hashPassword(password: string): string {
    let hashValue: number = 5381
    for (let index = 0; index < password.length; index++) {
      hashValue = ((hashValue << 5) + hashValue + password.charCodeAt(index)) | 0
    }
    const unsignedValue: number = hashValue >>> 0
    return 'sb_' + unsignedValue.toString(16)
  }

  private async loadUsers(): Promise<void> {
    const context: Context | null = this.hostContext
    if (context === null) {
      return
    }
    try {
      const prefs = await preferences.getPreferences(context, SANDBOX_STORE_NAME)
      const json = await prefs.get(KEY_USERS, '[]') as string
      this.users = this.parseUsers(json)
    } catch (error) {
      this.users = []
    }
  }

  private async persistUsers(): Promise<void> {
    const context: Context | null = this.hostContext
    if (context === null) {
      return
    }
    try {
      const prefs = await preferences.getPreferences(context, SANDBOX_STORE_NAME)
      await prefs.put(KEY_USERS, JSON.stringify(this.users))
      await prefs.flush()
    } catch (error) {
      // 沙盒演示模式：持久化失败时保留内存数据，不阻塞流程
    }
  }

  private parseUsers(json: string): SandboxUserRecord[] {
    try {
      const parsed: SandboxUserRecord[] = JSON.parse(json) as SandboxUserRecord[]
      const users: SandboxUserRecord[] = []
      for (let index = 0; index < parsed.length; index++) {
        const record: SandboxUserRecord = parsed[index]
        if (this.isValidUserRecord(record)) {
          users.push(record)
        }
      }
      return users
    } catch (error) {
      return []
    }
  }

  private isValidUserRecord(record: SandboxUserRecord): boolean {
    if (record === null || record === undefined) {
      return false
    }
    if (typeof record.phone !== 'string' || typeof record.email !== 'string') {
      return false
    }
    if (typeof record.nickname !== 'string' || typeof record.passwordHash !== 'string') {
      return false
    }
    if (typeof record.createdAt !== 'number' || !Number.isFinite(record.createdAt)) {
      return false
    }
    return true
  }
}

export default new SandboxAuthProvider()
