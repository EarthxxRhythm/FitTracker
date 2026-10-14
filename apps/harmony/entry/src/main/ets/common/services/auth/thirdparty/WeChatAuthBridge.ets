/**
 * WeChatAuthBridge —— 微信 OpenSDK for HarmonyOS 桥。
 *
 * SDK：@tencent/wechat_open_sdk（本地实装 1.0.23；har 元数据 compatibleSdkVersion=12，兼容项目 API 22）
 * 官方指南：https://developers.weixin.qq.com/doc/oplatform/Mobile_App/Access_Guide/ohos.html
 *
 * 宿主配置要求（har 自身不含这些声明，必须由宿主 module.json5 提供）：
 *  - querySchemes: 'weixin'（isWXAppInstalled 判定）、'wxopensdk'（跳转微信）
 *
 * 授权流程（腾讯官方 call 序列，签名以本地 d.ets 实证为准）：
 *   WXAPIFactory.createWXAPI(appId) → new SendAuthReq{scope,state} 
 *   → wxApi.sendReq(context, req) → 微信 App 内授权
 *   → EntryAbility.onCreate/onNewWant 收到回调 → wxApi.handleWant(want, handler)
 *   → handler.onResp(SendAuthResp) 取 resp.code → PendingAuthStore
 *
 * APP_ID 来源：rawfile 第三方配置（非硬编码）；未配置时 isAvailable 返回 false。
 */
import { common, Want } from '@kit.AbilityKit'
import { Context } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import * as wxopensdk from '@tencent/wechat_open_sdk'
import { ThirdPartyAuthBridge, ThirdPartyAuthCallbackSink } from '../ThirdPartyAuthBridge'
import { ThirdPartyAuthCode, ThirdPartyAuthFailure, ThirdPartyAuthFailureKind, ThirdPartyId } from '../AuthTypes'
import ThirdPartyConfig from '../ThirdPartyConfig'

const TAG: string = 'WeChatAuthBridge'
/** 微信登录 scope（官方推荐 snsapi_userinfo：可获取昵称头像）。 */
const AUTH_SCOPE: string = 'snsapi_userinfo'

/** SendAuthResp 的错误码（来自 SDK 的 ErrCode 枚举；SDK 未导出该枚举，此处按其数值声明）。 */
const ERR_OK: number = 0
const ERR_USER_CANCEL: number = -2

class WeChatAuthBridge extends ThirdPartyAuthBridge {
  private api: wxopensdk.WXApi | null = null
  /** 本次授权的 state（用于回调时防 CSRF 校验）。 */
  private pendingState: string = ''
  /** 回调出口（handleWant 时由 Registry 注入，保存供异步 onResp 使用）。 */
  private sink: ThirdPartyAuthCallbackSink | null = null

  getProviderId(): ThirdPartyId {
    return 'wechat'
  }

  async isAvailable(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const appId: string = ThirdPartyConfig.getWeChatAppId()
      if (appId.length === 0) {
        // 未配置 AppID：视为不可用（UI 应提示「暂未开通」）
        return false
      }
      const api: wxopensdk.WXApi = this.ensureApi(appId)
      return api.isWXAppInstalled()
    } catch (error) {
      const err: BusinessError = error as BusinessError
      hilog.warn(0x0000, TAG, 'isAvailable failed: ' + err.message)
      return false
    }
  }

  async sendAuthRequest(context: common.UIAbilityContext, state: string,
                        sink: ThirdPartyAuthCallbackSink): Promise<void> {
    const appId: string = ThirdPartyConfig.getWeChatAppId()
    if (appId.length === 0) {
      throw new Error('微信登录未配置')
    }
    this.pendingState = state
    // 结果稍后经 handleWant 回调，故此处先把 sink 存下
    this.sink = sink
    const api: wxopensdk.WXApi = this.ensureApi(appId)
    const req: wxopensdk.SendAuthReq = new wxopensdk.SendAuthReq()
    req.scope = AUTH_SCOPE
    req.state = state
    req.isOption1 = false
    req.nonAutomatic = true
    // sendReq 返回 SendReqResultWrap（boolean | Promise<boolean>）；false 表示跳转失败（通常未装微信）
    const finished: boolean = await api.sendReq(context, req)
    if (!finished) {
      throw new Error('未安装微信或跳转失败')
    }
  }

  async handleWant(context: Context, want: Want, sink: ThirdPartyAuthCallbackSink): Promise<boolean> {
    const appId: string = ThirdPartyConfig.getWeChatAppId()
    if (appId.length === 0) {
      return false
    }
    this.sink = sink
    const handler: wxopensdk.WXApiEventHandler = this.createHandler(sink)
    const api: wxopensdk.WXApi = this.ensureApi(appId)
    // handleWant 返回 boolean：true 表示本 want 属于微信（已消费）
    return api.handleWant(want, handler)
  }

  cancel(): void {
    this.pendingState = ''
  }

  /** 创建微信回调处理器。 */
  private createHandler(sink: ThirdPartyAuthCallbackSink): wxopensdk.WXApiEventHandler {
    const handler: wxopensdk.WXApiEventHandler = {
      onReq: (req: wxopensdk.BaseReq): void => {
        // 微信主动拉起本应用（非登录回调路径）：当前无业务需求，仅记录
        hilog.info(0x0000, TAG, 'onReq: ' + req.name)
      },
      onResp: (resp: wxopensdk.BaseResp): void => {
        // 仅处理授权响应；其他响应（分享/支付）忽略
        if (!(resp instanceof wxopensdk.SendAuthResp)) {
          return
        }
        const authResp: wxopensdk.SendAuthResp = resp as wxopensdk.SendAuthResp
        const errCode: number = authResp.errCode
        if (errCode === ERR_OK) {
          const code: string = authResp.code !== undefined ? authResp.code : ''
          const respState: string = authResp.state !== undefined ? authResp.state : ''
          // CSRF 校验：state 必须与本桥发起的请求一致
          if (this.pendingState.length > 0 && respState !== this.pendingState) {
            this.reportFailure(sink, 'error', '授权校验失败，请重试')
            return
          }
          if (code.length === 0) {
            this.reportFailure(sink, 'error', '未获取到授权码，请重试')
            return
          }
          const result: ThirdPartyAuthCode = { providerId: 'wechat', authCode: code, state: respState }
          sink.onAuthCode(result).catch((err: Error) => {
            hilog.error(0x0000, TAG, 'saveCode failed: ' + err.message)
          })
          this.pendingState = ''
          return
        }
        if (errCode === ERR_USER_CANCEL) {
          // 用户主动取消：静默（UI 不显示错误红字）
          this.reportFailure(sink, 'cancelled', '')
          this.pendingState = ''
          return
        }
        const errStr: string = authResp.errStr !== undefined && authResp.errStr.length > 0
          ? authResp.errStr
          : '微信授权失败'
        this.reportFailure(sink, 'error', errStr)
        this.pendingState = ''
      }
    }
    return handler
  }

  private reportFailure(sink: ThirdPartyAuthCallbackSink, kind: ThirdPartyAuthFailureKind, message: string): void {
    const failure: ThirdPartyAuthFailure = { providerId: 'wechat', message: message, kind: kind }
    sink.onAuthFailure(failure).catch((err: Error) => {
      hilog.error(0x0000, TAG, 'saveFailure failed: ' + err.message)
    })
  }

  /** 幂等创建 WXApi 实例（createWXAPI 每次调用都会新建，须复用以免回调错配）。 */
  private ensureApi(appId: string): wxopensdk.WXApi {
    if (this.api === null) {
      this.api = wxopensdk.WXAPIFactory.createWXAPI(appId)
    }
    return this.api
  }
}

export default new WeChatAuthBridge()
