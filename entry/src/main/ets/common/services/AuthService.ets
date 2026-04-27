/**
 * AuthService — 用户认证模拟服务
 * 内存级用户存储，供 RegisterPage 与 LoginPage 共享。
 * 后续迭代将替换为真实后端 API。
 */
import SessionManager from './SessionManager'

interface AuthResult {
  success: boolean
  message: string
  token: string
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
}

export default new AuthService()
