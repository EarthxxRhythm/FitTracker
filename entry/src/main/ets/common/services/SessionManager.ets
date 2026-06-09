/**
 * SessionManager — Token持久化服务
 *
 * 功能 #4: JWT Token 的生成、本地安全存储、有效性校验与清除。
 * 使用 @ohos.data.preferences 实现持久化存储。
 */
import { preferences } from '@kit.ArkData'
import { util } from '@kit.ArkTS'

const STORE_NAME = 'fit_tracker_session'
const TOKEN_KEY = 'auth_token'
const TOKEN_EXPIRY_DAYS = 7

interface JwtHeader {
  alg: string
  typ: string
}

interface TokenPayload {
  userId: string
  iat: number
  exp: number
}

class SessionManager {
  private lastPersistenceError: string = ''

  private base64Encode(str: string): string {
    const textEncoder = new util.TextEncoder()
    const uint8Array = textEncoder.encodeInto(str)
    const base64 = new util.Base64Helper()
    return base64.encodeToStringSync(uint8Array)
  }

  private base64Decode(str: string): string {
    const base64 = new util.Base64Helper()
    const uint8Array = base64.decodeSync(str)
    const textDecoder = util.TextDecoder.create('utf-8')
    return textDecoder.decodeToString(uint8Array)
  }

  generateToken(phone: string): string {
    const now = Math.floor(Date.now() / 1000)
    const entropy: string = Date.now().toString() + '_' + Math.random().toString(36)
    const payload: TokenPayload = {
      userId: phone,
      iat: now,
      exp: now + TOKEN_EXPIRY_DAYS * 24 * 60 * 60
    }
    const jwtHeader: JwtHeader = { alg: 'HS256', typ: 'JWT' }
    const header = this.base64Encode(JSON.stringify(jwtHeader))
    const body = this.base64Encode(JSON.stringify(payload))
    const signature = this.base64Encode('mock_signature_' + entropy)
    return `${header}.${body}.${signature}`
  }

  validateToken(token: string): boolean {
    try {
      const parts = token.split('.')
      if (parts.length < 2) {
        return false
      }
      const payloadStr = this.base64Decode(parts[1])
      const payload = JSON.parse(payloadStr) as TokenPayload
      const now = Math.floor(Date.now() / 1000)
      return payload.exp > now
    } catch (e) {
      return false
    }
  }

  getUserIdFromToken(token: string): string {
    try {
      const parts = token.split('.')
      if (parts.length < 2) {
        return ''
      }
      const payloadStr = this.base64Decode(parts[1])
      const payload = JSON.parse(payloadStr) as TokenPayload
      return payload.userId
    } catch (e) {
      return ''
    }
  }

  getLastPersistenceError(): string {
    return this.lastPersistenceError
  }

  async saveToken(context: Context, token: string): Promise<void> {
    this.lastPersistenceError = ''
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      await prefs.put(TOKEN_KEY, token)
      await prefs.flush()
    } catch (error) {
      this.lastPersistenceError = 'save_token_failed'
    }
  }

  async getToken(context: Context): Promise<string | null> {
    this.lastPersistenceError = ''
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      const token = await prefs.get(TOKEN_KEY, '') as string
      return token || null
    } catch (error) {
      this.lastPersistenceError = 'load_token_failed'
      return null
    }
  }

  async clearToken(context: Context): Promise<void> {
    this.lastPersistenceError = ''
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      await prefs.delete(TOKEN_KEY)
      await prefs.flush()
    } catch (error) {
      this.lastPersistenceError = 'clear_token_failed'
    }
  }

  async isLoggedIn(context: Context): Promise<boolean> {
    try {
      const token = await this.getToken(context)
      if (!token) {
        return false
      }
      return this.validateToken(token)
    } catch (error) {
      this.lastPersistenceError = 'check_login_failed'
      return false
    }
  }
}

export default new SessionManager()
