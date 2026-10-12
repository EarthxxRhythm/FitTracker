/**
 * SupabaseSessionStore —— 自托管 Supabase 的会话（token 组）持久化。
 *
 * 为什么独立于 SessionManager：后者持久化的是 AuthSession
 * {userId, displayName, phone, email, providerId, signedInAt}——**不含 token**；
 * 而 Supabase REST 需要 access token（RLS 的 auth.uid() 依据），刷新需要 refresh token
 * 与过期时间。故独立一库，数据结构对齐 Android 侧 CloudSession
 * （apps/android/app/src/main/java/com/fittracker/app/data/cloud/SupabaseSession.kt）。
 *
 * 与 SessionManager 的分工：SessionManager 仍是「谁登录了」的权威（启动分流读它），
 * 本存储是「用什么凭据访问 Supabase」的权威（同步链路读它）。
 */
import { preferences } from '@kit.ArkData'
import { Context } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG: string = 'SupabaseSessionStore'
const STORE_NAME: string = 'fit_tracker_supabase_session'
const SESSION_KEY: string = 'session'

/** 刷新窗口（秒）：距过期不足此值即视为需刷新——对齐 Android 的同名常量。 */
const REFRESH_WINDOW_SECONDS: number = 60

/** Supabase 会话数据（单键 JSON 持久化）。 */
export interface SupabaseSessionData {
  accessToken: string
  refreshToken: string
  expiresAtEpochSeconds: number
  userId: string
  phone: string
  email: string
  nickname: string
}

class SupabaseSessionStore {
  /** 保存会话（整块 JSON）。 */
  async save(context: Context, session: SupabaseSessionData): Promise<boolean> {
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      await prefs.put(SESSION_KEY, JSON.stringify(session))
      await prefs.flush()
      return true
    } catch (error) {
      const err: BusinessError = error as BusinessError
      hilog.error(0x0000, TAG, 'save failed: code=' + err.code + ' message=' + err.message)
      return false
    }
  }

  /** 读取会话；无会话或解析失败返回 null。 */
  async load(context: Context): Promise<SupabaseSessionData | null> {
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      const raw = await prefs.get(SESSION_KEY, '') as string
      if (raw.length === 0) {
        return null
      }
      const parsed: SupabaseSessionData = JSON.parse(raw) as SupabaseSessionData
      if (parsed.accessToken.length === 0 || parsed.refreshToken.length === 0) {
        return null
      }
      return parsed
    } catch (error) {
      const err: BusinessError = error as BusinessError
      hilog.error(0x0000, TAG, 'load failed: code=' + err.code + ' message=' + err.message)
      return null
    }
  }

  /** 清空会话（登出用）。 */
  async clear(context: Context): Promise<void> {
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      await prefs.delete(SESSION_KEY)
      await prefs.flush()
    } catch (error) {
      const err: BusinessError = error as BusinessError
      hilog.error(0x0000, TAG, 'clear failed: code=' + err.code + ' message=' + err.message)
    }
  }

  /**
   * 现有 access token 是否仍新鲜（距过期 > 刷新窗口）。
   * 无会话或已进入刷新窗口返回 null——调用方据此决定是否先刷新。
   */
  async validAccessToken(context: Context): Promise<string | null> {
    const session: SupabaseSessionData | null = await this.load(context)
    if (session === null) {
      return null
    }
    const nowSeconds: number = Math.floor(Date.now() / 1000)
    if (session.expiresAtEpochSeconds - nowSeconds <= REFRESH_WINDOW_SECONDS) {
      return null
    }
    return session.accessToken
  }

  /** 是否已持久化会话（不触网）——供启动判登录用。 */
  async hasSession(context: Context): Promise<boolean> {
    const session: SupabaseSessionData | null = await this.load(context)
    return session !== null
  }
}

export default new SupabaseSessionStore()
