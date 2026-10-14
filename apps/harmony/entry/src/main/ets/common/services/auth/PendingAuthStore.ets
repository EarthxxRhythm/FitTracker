/**
 * PendingAuthStore —— 第三方授权结果的跨生命周期暂存（preferences）。
 *
 * 存在理由：微信 / QQ 授权会切到第三方 App，宿主页面可能被销毁；Ability 回调先于页面
 * 重建，结果必须落盘。消费一次即清（与 app/LaunchRequestStore.ets:26-46 的 consume
 * 语义同构）。
 *
 * 时序：
 *   页面 sendAuthRequest → 切第三方 App → 用户授权 → 回到宿主
 *   → EntryAbility.onNewWant/onCreate → Bridge.handleWant → saveCode/saveFailure
 *   → 页面重建后 consume → 换票建立会话
 */
import { Context } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { ThirdPartyAuthCode, ThirdPartyAuthFailure } from './AuthTypes'

const TAG: string = 'PendingAuthStore'
const STORE_NAME: string = 'fit_tracker_pending_auth'
const KEY_RESULT: string = 'pending_result'

/** 授权结果有效期（毫秒）：超过视为过期，避免陈旧 code 误用。 */
const PENDING_TTL_MS: number = 5 * 60 * 1000

/** 落盘形状（显式接口；ArkTS 禁止对象索引访问）。 */
export interface PendingAuthRecord {
  kind: 'code' | 'failure'
  providerId: string
  authCode: string
  state: string
  message: string
  createdAt: number
}

class PendingAuthStore {
  /** 保存授权成功的一次性凭据。 */
  async saveCode(context: Context, code: ThirdPartyAuthCode): Promise<void> {
    const record: PendingAuthRecord = {
      kind: 'code',
      providerId: code.providerId,
      authCode: code.authCode,
      state: code.state,
      message: '',
      createdAt: Date.now()
    }
    await this.write(context, record)
  }

  /** 保存授权失败（用户取消 / 未安装 / 其他错误）。 */
  async saveFailure(context: Context, failure: ThirdPartyAuthFailure): Promise<void> {
    const record: PendingAuthRecord = {
      kind: 'failure',
      providerId: failure.providerId,
      authCode: '',
      state: '',
      message: failure.message,
      createdAt: Date.now()
    }
    await this.write(context, record)
  }

  /** 消费：读取后立即清除；无记录 / 已过期 / 解析失败一律返回 null。 */
  async consume(context: Context): Promise<PendingAuthRecord | null> {
    try {
      const prefs: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME)
      const raw: string = await prefs.get(KEY_RESULT, '') as string
      if (raw.length === 0) {
        return null
      }
      // 一次性语义：无论过期与否，读到即清，避免陈旧 code 被二次消费
      await prefs.delete(KEY_RESULT)
      await prefs.flush()
      const record: PendingAuthRecord = JSON.parse(raw) as PendingAuthRecord
      if (Date.now() - record.createdAt > PENDING_TTL_MS) {
        return null
      }
      return record
    } catch (error) {
      const err: BusinessError = error as BusinessError
      hilog.error(0x0000, TAG, 'consume failed: code=' + err.code + ' message=' + err.message)
      return null
    }
  }

  /** 清理（登出 / 主动取消授权时）。 */
  async clear(context: Context): Promise<void> {
    try {
      const prefs: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME)
      await prefs.delete(KEY_RESULT)
      await prefs.flush()
    } catch (error) {
      const err: BusinessError = error as BusinessError
      hilog.warn(0x0000, TAG, 'clear failed: code=' + err.code + ' message=' + err.message)
    }
  }

  /** 写盘 + flush（preferences 异步写必须 flush 才落盘，见 AGENTS.md 约定）。 */
  private async write(context: Context, record: PendingAuthRecord): Promise<void> {
    try {
      const prefs: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME)
      await prefs.put(KEY_RESULT, JSON.stringify(record))
      await prefs.flush()
    } catch (error) {
      const err: BusinessError = error as BusinessError
      hilog.error(0x0000, TAG, 'write failed: code=' + err.code + ' message=' + err.message)
    }
  }
}

export default new PendingAuthStore()
