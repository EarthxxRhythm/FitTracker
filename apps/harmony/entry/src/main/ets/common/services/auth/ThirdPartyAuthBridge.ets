/**
 * ThirdPartyAuthBridge —— 端侧第三方 SDK 桥抽象。
 *
 * 分层理由：本接口只负责「拉起第三方 App → 拿到 authCode」这一段（需要 UIAbilityContext
 * 与 Ability 回调入口）；「authCode → 本应用会话」由 SupabaseAuthProvider.loginWithThirdParty
 * 经服务端换票完成。两段分离使服务端换票可独立测试（不需要真机装微信）。
 *
 * 实现（三个 provider 各一个）：
 *  - WeChatAuthBridge：@tencent/wechat_open_sdk（SendAuthReq / SendAuthResp）
 *  - QqAuthBridge：@tencent/qq-open-sdk（IQQOpenApi.login / handleResult）
 *  - HuaweiAuthBridge：@kit.AccountKit（createLoginWithHuaweiIDRequest）
 *
 * 回调路径：第三方 App 授权后回到宿主 Ability → EntryAbility.onNewWant / onCreate
 * → ThirdPartyBridgeRegistry.dispatch → Bridge.handleWant → PendingAuthStore。
 */
import { common } from '@kit.AbilityKit'
import { Want } from '@kit.AbilityKit'
import { Context } from '@kit.AbilityKit'
import { ThirdPartyAuthCode, ThirdPartyAuthFailure, ThirdPartyId } from './AuthTypes'

export abstract class ThirdPartyAuthBridge {
  /** 通道标识。 */
  abstract getProviderId(): ThirdPartyId

  /**
   * 客户端是否可发起授权（如微信未安装 → false，UI 据此提示或置灰按钮）。
   * 实现须捕获异常并返回 false，不向上抛出。
   */
  abstract isAvailable(context: common.UIAbilityContext): Promise<boolean>

  /**
   * 发起授权：拉起第三方 App。
   *
   * @param context 宿主 UIAbilityContext（拉起外部 App 必需）
   * @param state 防 CSRF 的随机串（由 Registry 生成并回校）
   * @param sink 授权结果出口。**必须在本方法发起前注入**——因为三个 SDK 的返回时机不同：
   *             微信/QQ 异步（回调在 handleWant），华为同步（executeRequest 即返回）。
   *             统一在发起时传入，使三种时序对上层表现一致。
   *
   * resolve 时表示「授权流程已完成并已把结果交给 sink」（华为：同步返回即完成；
   * 微信/QQ：已成功拉起第三方 App，结果稍后经 handleWant 交给 sink）。
   * 未安装 / 拉起失败时 reject。
   */
  abstract sendAuthRequest(context: common.UIAbilityContext, state: string,
                           sink: ThirdPartyAuthCallbackSink): Promise<void>

  /**
   * 处理 Ability 回调 want。
   *
   * @returns true 表示本 bridge 识别并消费了该 want（回调属于本通道）。
   * 实现须自校验 state（防 CSRF），校验失败走 onAuthFailure('error') 而非静默丢弃。
   */
  abstract handleWant(context: Context, want: Want, sink: ThirdPartyAuthCallbackSink): Promise<boolean>

  /** 中止等待（页面销毁 / 超时）。 */
  abstract cancel(): void
}

/**
 * 回调结果统一出口 —— Bridge 拿到授权结果后经此落到 PendingAuthStore。
 *
 * 由 Registry 提供一个基于 Context 的默认实现（见 ThirdPartyBridgeRegistry），
 * 使三个 Bridge 实现无需各自依赖 PendingAuthStore（降低耦合，便于单测）。
 */
export interface ThirdPartyAuthCallbackSink {
  onAuthCode(code: ThirdPartyAuthCode): Promise<void>
  onAuthFailure(failure: ThirdPartyAuthFailure): Promise<void>
}
