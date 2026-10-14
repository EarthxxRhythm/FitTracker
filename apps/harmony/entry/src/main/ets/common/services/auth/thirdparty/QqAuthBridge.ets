/**
 * QqAuthBridge —— QQ 互联 HarmonyOS SDK 桥。
 *
 * SDK：@tencent/qq-open-sdk（本地实装 1.0.4；har 元数据 compatibleSdkVersion=12，
 *      byteCodeHar=true，useNormalizedOHMUrl=true —— 项目 build-profile.json5 已开启该选项 ✓）
 * 官方文档：https://wiki.connect.qq.com/harmonyos_sdk环境搭建
 *
 * ⚠ 签名消歧（官方两页冲突，以本地 d.ets 实证为准）：
 *   环境搭建页示例写 `login(uiContext, reqOptions)`，接口说明页写 `login(reqOptions)`。
 *   本地 d.d.ets 实测为：
 *     login(reqOptions: AuthReqOptions, apiCallback: ApiCallback<AuthResponse>): void
 *     login(reqOptions: AuthReqOptions): Promise<AuthResult>
 *   —— **不带 UIContext 首参**。本实现按本地实证签名编写。
 *   同理 handleResult 的本地签名为 `handleResult(routeParams: Object): void`，非 `handleResult(want)`。
 *
 * 宿主配置要求（module.json5）：
 *  - querySchemes: ['https', 'qqopenapi']
 *  - Ability.skills 增 entity.system.browsable / actions[ohos.want.action.viewData]
 *    / uris[{scheme:'qqopenapi', host:<QQ_APP_ID>, pathRegex:'\\b(auth|share)\\b'}]
 *    —— host 必须等于应用申请到的 QQ appId，填错会导致回调失败（官方明确警告）
 *
 * 授权流程：
 *   QQOpenApiFactory.createApi(appId) → api.login({scope:'all'}) → 授权 → AuthResult
 *   → 取 authResponse.authCode → PendingAuthStore
 *   → EntryAbility.onNewWant → api.handleResult(want)（实例须与 login 为同一实例）
 */
import { common, Want } from '@kit.AbilityKit'
import { Context } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { IQQOpenApi, QQOpenApiFactory, AuthResult, AuthResultType, AuthReqOptions } from '@tencent/qq-open-sdk'
import { ThirdPartyAuthBridge, ThirdPartyAuthCallbackSink } from '../ThirdPartyAuthBridge'
import { ThirdPartyAuthCode, ThirdPartyAuthFailure, ThirdPartyAuthFailureKind, ThirdPartyId } from '../AuthTypes'
import ThirdPartyConfig from '../ThirdPartyConfig'

const TAG: string = 'QqAuthBridge'
/** QQ 授权 scope（'all' 为官方示例值，覆盖基本用户信息）。 */
const AUTH_SCOPE: string = 'all'
/** 网络超时（毫秒）；0 表示不限制（官方示例值）。 */
const NETWORK_TIMEOUT_MS: number = 0
/** AuthResponse.ret 成功值。 */
const RET_SUCCESS: number = 0

class QqAuthBridge extends ThirdPartyAuthBridge {
  private api: IQQOpenApi | null = null
  private pendingState: string = ''
  /** 最近一次回调出口（handleWant 注入；Promise 形态在 sendAuthRequest 内直接使用）。 */
  private currentSink: ThirdPartyAuthCallbackSink | null = null

  getProviderId(): ThirdPartyId {
    return 'qq'
  }

  async isAvailable(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const appId: string = ThirdPartyConfig.getQqAppId()
      if (appId.length === 0) {
        return false
      }
      const api: IQQOpenApi = this.ensureApi(appId)
      return api.isQQInstalled()
    } catch (error) {
      const err: BusinessError = error as BusinessError
      hilog.warn(0x0000, TAG, 'isAvailable failed: ' + err.message)
      return false
    }
  }

  /**
   * 发起授权。
   *
   * 用 Promise 形态（非 callback 形态）以便与两段式编排的 await 语义一致：
   * 但注意 Promise 形态在本 SDK 中直接返回授权结果（而非「已发出」），
   * 故其成功即代表拿到 authCode —— 此处直接经 sink 落盘，
   * 使 QQ 通道与微信通道对上层表现一致（上层统一读 PendingAuthStore）。
   */
  async sendAuthRequest(context: common.UIAbilityContext, state: string,
                        sink: ThirdPartyAuthCallbackSink): Promise<void> {
    const appId: string = ThirdPartyConfig.getQqAppId()
    if (appId.length === 0) {
      throw new Error('QQ 登录未配置')
    }
    this.pendingState = state
    this.currentSink = sink
    const api: IQQOpenApi = this.ensureApi(appId)
    const options: AuthReqOptions = {
      scope: AUTH_SCOPE,
      forceWebLogin: false,
      useQrCode: false,
      networkTimeout: NETWORK_TIMEOUT_MS
    }
    const result: AuthResult = await api.login(options)
    // QQ 的 Promise 形态直接返回结果，故此处分派（微信走 onResp 回调路径）
    this.consumeAuthResult(result)
  }

  async handleWant(context: Context, want: Want, sink: ThirdPartyAuthCallbackSink): Promise<boolean> {
    const appId: string = ThirdPartyConfig.getQqAppId()
    if (appId.length === 0) {
      return false
    }
    this.currentSink = sink
    const api: IQQOpenApi = this.ensureApi(appId)
    // 本地实证签名：handleResult(routeParams: Object)。want 满足 Object 约束。
    // 该方法无返回值，无法据此判断「是否消费」——按「已配置即有资格处理」返回 true。
    // 风险：若其他 SDK 的 want 误入本桥可能产生噪声日志，但不会破坏功能（handleResult 内部校验）。
    api.handleResult(want)
    const consumed: boolean = true
    return consumed
  }

  cancel(): void {
    this.pendingState = ''
  }

  /** 统一处理登录结果（Promise 与回调两条路径共用）。 */
  private consumeAuthResult(result: AuthResult): void {
    const sink: ThirdPartyAuthCallbackSink | null = this.currentSink
    const type: AuthResultType = result.type
    if (type === AuthResultType.Success) {
      const response = result.authResponse
      if (response === null || response === undefined) {
        this.reportFailure(sink, 'error', '未获取到授权信息，请重试')
        return
      }
      if (response.ret !== RET_SUCCESS) {
        this.reportFailure(sink, 'error', 'QQ 授权失败（' + response.ret.toString() + '）')
        return
      }
      const code: string = response.authCode
      if (code === undefined || code.length === 0) {
        this.reportFailure(sink, 'error', '未获取到授权码，请重试')
        return
      }
      if (sink === null) {
        // 无 sink 时（sendAuthRequest 直调路径）结果无处安放——属编程错误，记录以便排查
        hilog.error(0x0000, TAG, 'auth code received but no callback sink registered')
        return
      }
      const authCode: ThirdPartyAuthCode = {
        providerId: 'qq',
        authCode: code,
        state: this.pendingState
      }
      sink.onAuthCode(authCode).catch((err: Error) => {
        hilog.error(0x0000, TAG, 'saveCode failed: ' + err.message)
      })
      this.pendingState = ''
      return
    }
    if (type === AuthResultType.Cancel) {
      // 用户主动取消：静默
      this.reportFailure(sink, 'cancelled', '')
      this.pendingState = ''
      return
    }
    const message: string | null = result.message
    const detail: string | null = result.detail
    const text: string = message !== null && message.length > 0
      ? message
      : (detail !== null && detail.length > 0 ? detail : 'QQ 授权失败')
    this.reportFailure(sink, 'error', text)
    this.pendingState = ''
  }

  private reportFailure(sink: ThirdPartyAuthCallbackSink | null, kind: ThirdPartyAuthFailureKind,
                        message: string): void {
    if (sink === null) {
      hilog.warn(0x0000, TAG, 'auth failure without sink: kind=' + kind + ' message=' + message)
      return
    }
    const failure: ThirdPartyAuthFailure = { providerId: 'qq', message: message, kind: kind }
    sink.onAuthFailure(failure).catch((err: Error) => {
      hilog.error(0x0000, TAG, 'saveFailure failed: ' + err.message)
    })
  }

  /** 幂等创建 QQ api 实例（须与 handleResult 使用同一实例，官方明确要求）。 */
  private ensureApi(appId: string): IQQOpenApi {
    if (this.api === null) {
      // appId 为数字串，SDK 接口声明为 number
      this.api = QQOpenApiFactory.createApi(Number(appId))
    }
    return this.api
  }
}

export default new QqAuthBridge()
