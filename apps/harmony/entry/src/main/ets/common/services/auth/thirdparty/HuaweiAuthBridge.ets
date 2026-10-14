/**
 * HuaweiAuthBridge —— 华为账号登录桥（Supabase 后端下的华为账号通道）。
 *
 * 为何需要它：AGC 后端下华为账号走 hwid 凭据（AgcAuthProvider）已可用；但本项目身份落点
 * 为自托管 Supabase，而 SupabaseAuthProvider 对华为账号同样返回「当前云端不支持第三方登录」。
 * 故 Supabase 后端下需要一条独立的华为授权链路，走 Account Kit 拿 authorizationCode。
 *
 * 依赖：@kit.AccountKit（HarmonyOS 系统能力，无需第三方 har、无需净增权限）
 * 文档（本地官方库 + SDK 类型实证）：
 *  - 指南：开发指南/Account_Kit_华为账号服务/登录/华为账号获取UnionID_OpenID/使用自定义按钮登录
 *  - 类型：sdk/default/hms/ets/api/@hms.core.authentication.d.ts
 *    · AuthenticationController(context?: common.Context)
 *    · executeRequest(request: AuthenticationRequest): Promise<AuthenticationResponse>
 *    · LoginWithHuaweiIDCredential { authorizationCode?, idToken?, openID, unionID }
 * 官方明写「此场景无需申请账号权限」——不要声明 ACCOUNT_MANAGER。
 *
 * ⚠ 契约差异（与微信/QQ 的结构性不同）：
 *   Account Kit 是**同步返回**（executeRequest 的 Promise 直接给出 credential），
 *   不经过 Ability 回调。故本桥在 sendAuthRequest 内直接经 sink 落盘，
 *   使上层看到的行为与微信/QQ 一致（统一读 PendingAuthStore）。
 *   handleWant 对本桥恒返回 false（华为不走 want 回调路径）。
 *
 * ⚠ 生命周期约束（官方原文）：「上述接口需在页面或自定义组件生命周期内调用」
 *   —— 故 executeRequest 在页面点击事件（生命周期内）触发，而非 Ability 启动阶段。
 */
import { common, Want } from '@kit.AbilityKit'
import { Context } from '@kit.AbilityKit'
import { authentication } from '@kit.AccountKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { util } from '@kit.ArkTS'
import { ThirdPartyAuthBridge, ThirdPartyAuthCallbackSink } from '../ThirdPartyAuthBridge'
import { ThirdPartyAuthCode, ThirdPartyAuthFailure, ThirdPartyAuthFailureKind, ThirdPartyId } from '../AuthTypes'
import ThirdPartyConfig from '../ThirdPartyConfig'

const TAG: string = 'HuaweiAuthBridge'

class HuaweiAuthBridge extends ThirdPartyAuthBridge {
  /** 本次授权的 state（防 CSRF；回调后校验）。 */
  private pendingState: string = ''

  getProviderId(): ThirdPartyId {
    return 'huawei'
  }

  /**
   * 是否可用。
   * Account Kit 为系统能力，无独立「安装」判定；此处以「是否配置了 Client ID」为判据
   * （未配置时服务端换票必然失败，提前拦截可给出更清晰提示）。
   */
  async isAvailable(context: common.UIAbilityContext): Promise<boolean> {
    return ThirdPartyConfig.getHuaweiClientId().length > 0
  }

  /**
   * 发起授权并直接消费结果（Account Kit 为同步返回，无 Ability 回调）。
   */
  async sendAuthRequest(context: common.UIAbilityContext, state: string,
                        sink: ThirdPartyAuthCallbackSink): Promise<void> {
    const clientId: string = ThirdPartyConfig.getHuaweiClientId()
    if (clientId.length === 0) {
      throw new Error('华为账号登录未配置')
    }
    this.pendingState = state
    // Account Kit 为同步返回（无 Ability 回调），故此处先持 sink 引用，结束前直接落盘
    this.currentSink = sink
    // 官方伪代码：provider.createLoginWithHuaweiIDRequest() → controller.executeRequest(req)
    const provider: authentication.HuaweiIDProvider = new authentication.HuaweiIDProvider()
    const loginRequest: authentication.LoginWithHuaweiIDRequest = provider.createLoginWithHuaweiIDRequest()
    // forceLogin=true 且未登录/未授权时会拉起登录或授权页面（官方说明）
    loginRequest.forceLogin = true
    // state 用于防 CSRF（官方示例用 util.generateRandomUUID()；此处复用上层传入的 state 以便回校）
    loginRequest.state = state
    const controller: authentication.AuthenticationController = new authentication.AuthenticationController(context)
    const response: authentication.AuthenticationResponse = await controller.executeRequest(loginRequest)
    this.consumeResponse(response)
  }

  /** 华为不走 want 回调路径，恒不消费。 */
  async handleWant(context: Context, want: Want, sink: ThirdPartyAuthCallbackSink): Promise<boolean> {
    const notMine: boolean = false
    return notMine
  }

  cancel(): void {
    this.pendingState = ''
  }

  private currentSink: ThirdPartyAuthCallbackSink | null = null

  /** 解析 executeRequest 响应并按结果落盘。 */
  private consumeResponse(response: authentication.AuthenticationResponse): void {
    const sink: ThirdPartyAuthCallbackSink | null = this.currentSink
    // 响应为 LoginWithHuaweiIDResponse（继承 AuthenticationResponse），data 为 credential
    const loginResponse: authentication.LoginWithHuaweiIDResponse = response as authentication.LoginWithHuaweiIDResponse
    const credential: authentication.LoginWithHuaweiIDCredential | undefined = loginResponse.data
    if (credential === undefined || credential === null) {
      this.reportFailure(sink, 'error', '未获取到华为账号授权信息，请重试')
      return
    }
    // state 回校（响应附带 state 字段，防 CSRF）
    const responseState: string | undefined = loginResponse.state
    if (this.pendingState.length > 0 && responseState !== undefined && responseState !== this.pendingState) {
      this.reportFailure(sink, 'error', '授权校验失败，请重试')
      return
    }
    const code: string | undefined = credential.authorizationCode
    if (code === undefined || code.length === 0) {
      this.reportFailure(sink, 'error', '未获取到授权码，请重试')
      return
    }
    if (sink === null) {
      hilog.error(0x0000, TAG, 'auth code received but no sink registered')
      return
    }
    const result: ThirdPartyAuthCode = {
      providerId: 'huawei',
      authCode: code,
      state: this.pendingState
    }
    sink.onAuthCode(result).catch((err: Error) => {
      hilog.error(0x0000, TAG, 'saveCode failed: ' + err.message)
    })
    this.pendingState = ''
  }

  private reportFailure(sink: ThirdPartyAuthCallbackSink | null, kind: ThirdPartyAuthFailureKind,
                        message: string): void {
    if (sink === null) {
      hilog.warn(0x0000, TAG, 'auth failure without sink: kind=' + kind + ' message=' + message)
      return
    }
    const failure: ThirdPartyAuthFailure = { providerId: 'huawei', message: message, kind: kind }
    sink.onAuthFailure(failure).catch((err: Error) => {
      hilog.error(0x0000, TAG, 'saveFailure failed: ' + err.message)
    })
  }
}

export default new HuaweiAuthBridge()
