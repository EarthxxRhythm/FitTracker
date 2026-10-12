/**
 * SupabaseHttp —— 自托管 Supabase 的端点构造、请求头口径与传输层。
 *
 * 逐条对齐 Android 侧 apps/android/app/src/main/java/com/fittracker/app/data/cloud/SupabaseHttp.kt：
 *  - auth(path) = `${url}/auth/v1/${path}`                      （kt 端点构造段）
 *  - rest(path) = `${url}/rest/v1/${path}`                      （同上）
 *  - 头：apikey = publishableKey 恒；                            （kt 头口径段）
 *        Authorization = 'Bearer ' + (accessToken ?? publishableKey)
 *        Content-Type: application/json
 *  - 超时：连接 15s / 读 20s                                      （kt UrlConnectionTransport）
 *
 * 传输层用 @kit.NetworkKit；ohos.permission.INTERNET 已在 entry/src/main/module.json5:13-17 声明。
 *
 * ArkTS 约束：本文件不使用对象索引访问（AGENTS.md 明列禁止），故额外头以显式参数传递，
 * 不以 Record 动态合并。
 */
import { http } from '@kit.NetworkKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import SupabaseConfig, { SupabaseRuntimeConfig } from './SupabaseConfig'

const TAG: string = 'SupabaseHttp'
const CONNECT_TIMEOUT_MS: number = 15000
const READ_TIMEOUT_MS: number = 20000

/** HTTP 调用结果：status 为 0 表示未取得响应（网络层失败或未配置），body 为响应体原文。 */
export interface SupabaseHttpResult {
  status: number
  body: string
}

export class SupabaseHttp {
  /** 配置是否就绪（url 与 publishableKey 均非空）。 */
  static isConfigured(): boolean {
    return SupabaseConfig.isConfigured()
  }

  /** `{url}/auth/v1/{path}`；未配置返回空串。 */
  static authUrl(path: string): string {
    const config: SupabaseRuntimeConfig | null = SupabaseConfig.get()
    if (config === null) {
      return ''
    }
    return config.url + '/auth/v1/' + path
  }

  /** `{url}/rest/v1/{path}`；未配置返回空串。 */
  static restUrl(path: string): string {
    const config: SupabaseRuntimeConfig | null = SupabaseConfig.get()
    if (config === null) {
      return ''
    }
    return config.url + '/rest/v1/' + path
  }

  /**
   * 头口径（与 Android SupabaseHttp.kt 的同名函数逐字段一致）：
   * apikey 恒为 publishable key；Authorization 在无 access token 时亦为 publishable key
   * ——即匿名请求，可见性由 RLS 决定。
   */
  static headers(accessToken: string | null): Record<string, string> {
    const config: SupabaseRuntimeConfig | null = SupabaseConfig.get()
    const key: string = config === null ? '' : config.publishableKey
    const bearer: string = accessToken === null || accessToken.length === 0 ? key : accessToken
    const headers: Record<string, string> = {
      'apikey': key,
      'Authorization': 'Bearer ' + bearer,
      'Content-Type': 'application/json'
    }
    return headers
  }

  /** GET（无请求体）。 */
  static async get(url: string, accessToken: string | null): Promise<SupabaseHttpResult> {
    return SupabaseHttp.send(url, http.RequestMethod.GET, '', accessToken, '')
  }

  /** POST（bodyJson 为已序列化的 JSON 字符串）。 */
  static async post(url: string, bodyJson: string, accessToken: string | null): Promise<SupabaseHttpResult> {
    return SupabaseHttp.send(url, http.RequestMethod.POST, bodyJson, accessToken, '')
  }

  /**
   * POST 并附加 `Prefer` 头（快照 push 需要 `resolution=merge-duplicates,return=minimal`）。
   * 单列参数而非通用头映射，以避开 ArkTS 的对象索引访问禁令。
   */
  static async postWithPrefer(url: string, bodyJson: string, accessToken: string | null,
                              prefer: string): Promise<SupabaseHttpResult> {
    return SupabaseHttp.send(url, http.RequestMethod.POST, bodyJson, accessToken, prefer)
  }

  /** 统一发送：任一异常一律返回 status=0（调用方据 0 / 非 2xx 分流失败语义）。 */
  private static async send(url: string, method: http.RequestMethod, bodyJson: string,
                            accessToken: string | null, prefer: string): Promise<SupabaseHttpResult> {
    if (url.length === 0) {
      return { status: 0, body: '' }
    }
    const request: http.HttpRequest = http.createHttp()
    try {
      const header: Record<string, string> = prefer.length === 0
        ? SupabaseHttp.headers(accessToken)
        : SupabaseHttp.headersWithPrefer(accessToken, prefer)
      const options: http.HttpRequestOptions = {
        method: method,
        header: header,
        extraData: bodyJson,
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS
      }
      const response: http.HttpResponse = await request.request(url, options)
      const status: number = response.responseCode
      let body: string = ''
      const raw: string | Object | ArrayBuffer = response.result
      if (typeof raw === 'string') {
        body = raw as string
      } else {
        body = JSON.stringify(raw)
      }
      return { status: status, body: body }
    } catch (error) {
      const err: BusinessError = error as BusinessError
      hilog.error(0x0000, TAG, 'request failed: code=' + err.code + ' message=' + err.message)
      return { status: 0, body: '' }
    } finally {
      request.destroy()
    }
  }

  /** 带 Prefer 的头构造（独立函数以保证返回对象的字段静态可知）。 */
  private static headersWithPrefer(accessToken: string | null, prefer: string): Record<string, string> {
    const config: SupabaseRuntimeConfig | null = SupabaseConfig.get()
    const key: string = config === null ? '' : config.publishableKey
    const bearer: string = accessToken === null || accessToken.length === 0 ? key : accessToken
    const headers: Record<string, string> = {
      'apikey': key,
      'Authorization': 'Bearer ' + bearer,
      'Content-Type': 'application/json',
      'Prefer': prefer
    }
    return headers
  }
}
