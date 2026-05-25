/**
 * AuthService — 用户认证模拟服务
 * 内存级用户存储，供 RegisterPage 与 LoginPage 共享。
 * 后续迭代将替换为真实后端 API。
 */
import SessionManager from './SessionManager'
import { preferences } from '@kit.ArkData'

const STORE_NAME = 'fit_tracker_auth'
const KEY_USERS = 'users'

export interface AuthResult {
  success: boolean
  message: string
  token: string
}

interface AuthUser {
  phone: string
  password: string
}

class AuthService {
  private users: Map<string, string> = new Map()

  register(phone: string, password: string): AuthResult {
    const trimmed = phone.trim()
    if (this.users.has(trimmed)) {
      return { success: false, message: '该手机号已注册', token: '' }
    }
    this.users.set(trimmed, password)
    const token = SessionManager.generateToken(trimmed)
    return { success: true, message: '注册成功', token: token }
  }

  login(phone: string, password: string): AuthResult {
    const trimmed = phone.trim()
    if (!this.users.has(trimmed)) {
      return { success: false, message: '该手机号尚未注册，请先注册', token: '' }
    }
    if (this.users.get(trimmed) !== password) {
      return { success: false, message: '密码错误，请重试', token: '' }
    }
    const token = SessionManager.generateToken(trimmed)
    return { success: true, message: '登录成功', token: token }
  }

  isRegistered(phone: string): boolean {
    return this.users.has(phone.trim())
  }

  clearLocalUsers(): void {
    this.users.clear()
  }

  async registerLocal(context: Context, phone: string, password: string): Promise<AuthResult> {
    await this.loadPersistedUsers(context)
    const result: AuthResult = this.register(phone, password)
    if (result.success) {
      await this.savePersistedUsers(context)
    }
    return result
  }

  async loginLocal(context: Context, phone: string, password: string): Promise<AuthResult> {
    await this.loadPersistedUsers(context)
    return this.login(phone, password)
  }

  async isRegisteredLocal(context: Context, phone: string): Promise<boolean> {
    await this.loadPersistedUsers(context)
    return this.isRegistered(phone)
  }

  async clearPersistedUsers(context: Context): Promise<void> {
    this.clearLocalUsers()
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      await prefs.delete(KEY_USERS)
      await prefs.flush()
    } catch (error) {
      // Keep local users cleared even if persistent storage is unavailable.
    }
  }

  private async loadPersistedUsers(context: Context): Promise<void> {
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      const json = await prefs.get(KEY_USERS, '[]') as string
      const users: AuthUser[] = this.parseUsers(json)
      this.users.clear()
      for (let index = 0; index < users.length; index++) {
        const user: AuthUser = users[index]
        if (user.phone.length > 0) {
          this.users.set(user.phone, user.password)
        }
      }
    } catch (error) {
      // Fall back to in-memory users for the current session.
    }
  }

  private async savePersistedUsers(context: Context): Promise<void> {
    const users: AuthUser[] = this.createUserList()
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      await prefs.put(KEY_USERS, JSON.stringify(users))
      await prefs.flush()
    } catch (error) {
      // Registration still works in memory if local persistence is unavailable.
    }
  }

  private parseUsers(json: string): AuthUser[] {
    try {
      return JSON.parse(json) as AuthUser[]
    } catch (error) {
      const users: AuthUser[] = []
      return users
    }
  }

  private createUserList(): AuthUser[] {
    const users: AuthUser[] = []
    this.users.forEach((password: string, phone: string) => {
      const user: AuthUser = {
        phone: phone,
        password: password
      }
      users.push(user)
    })
    return users
  }
}

export default new AuthService()
