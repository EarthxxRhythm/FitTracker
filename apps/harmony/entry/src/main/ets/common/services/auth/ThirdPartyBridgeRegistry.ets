/**
 * ThirdPartyBridgeRegistry —— 端侧第三方桥注册表与回调分派中枢。
 *
 * 职责：
 *  - 按 ThirdPartyId 解析对应 bridge（sendAuthRequest 的入口）
 *  - 把 Ability 回调 want 分派给能识别它的 bridge（EntryAbility.onCreate/onNewWant 的入口）
 *  - 向 bridge 提供 ThirdPartyAuthCallbackSink（落到 PendingAuthStore）
 *
 * 安全与健壮性：
 *  - 分派对每个 bridge 独立 try/catch —— 任一 SDK 的 handleWant 抛错不阻断应用启动路径
 *    （与 WorkoutReminderService.calibrateFromLaunch 的「失败静默、启动不受影响」纪律一致）。
 *  - 回调结果统一经 PendingAuthStore 落盘，页面重建后 consume。
 *
 * 注意：本文件不 import 三个 bridge 的具体实现（避免循环依赖与未安装 SDK 的编译耦合），
 * 具体桥由 ThirdPartyBridgeBootstrap 在应用启动时注册。
 */
import { common, Context, Want } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { ThirdPartyAuthBridge, ThirdPartyAuthCallbackSink } from './ThirdPartyAuthBridge'
import PendingAuthStore from './PendingAuthStore'
import { ThirdPartyAuthCode, ThirdPartyAuthFailure, ThirdPartyId } from './AuthTypes'

const TAG: string = 'ThirdPartyBridgeRegistry'

class ThirdPartyBridgeRegistry {
  private bridges: ThirdPartyAuthBridge[] = []

  /** 注册一个 bridge（应用启动时调用；重复注册同一 providerId 时后者覆盖前者）。 */
  register(bridge: ThirdPartyAuthBridge): void {
    const existingIndex: number = this.indexOf(bridge.getProviderId())
    if (existingIndex >= 0) {
      this.bridges[existingIndex] = bridge
      return
    }
    this.bridges.push(bridge)
  }

  /** 是否已注册任何 bridge（未注册时调用方应给出「暂未开通」提示）。 */
  hasAnyBridge(): boolean {
    return this.bridges.length > 0
  }

  /**
   * 发起授权：解析 bridge 并拉起第三方 App。
   * 未注册该通道 / 通道不可用 / 拉起失败时抛错，由调用方转成用户可读文案。
   *
   * 收 UIAbilityContext 而非基类 Context：三个第三方 SDK 拉起外部 App 均需要
   * UIAbilityContext（微信 sendReq / QQ login / AccountKit executeRequest）。
   */
  async sendAuthRequest(context: common.UIAbilityContext, providerId: string): Promise<void> {
    const bridge: ThirdPartyAuthBridge | null = this.resolve(providerId)
    if (bridge === null) {
      throw new Error('未注册的第三方通道: ' + providerId)
    }
    const available: boolean = await bridge.isAvailable(context)
    if (!available) {
      throw new Error('未安装对应的客户端应用')
    }
    // 生成防 CSRF 的 state（时间戳 + 随机串，无需密码学强度，仅防重放错配）
    const state: string = Date.now().toString() + '_' + Math.random().toString(36).substring(2, 10)
    // sink 在发起时注入：三个 SDK 返回时机不同（华为同步、微信/QQ 异步回调），
    // 统一在发起前传入使上层消费方式一致（都读 PendingAuthStore）。
    const sink: ThirdPartyAuthCallbackSink = this.createSink(context)
    await bridge.sendAuthRequest(context, state, sink)
  }

  /**
   * 分派 Ability 回调 want 给能识别它的 bridge。
   *
   * @returns 被某个 bridge 消费的 providerId；无 bridge 识别时返回空串。
   * 任一 bridge 抛错只记录日志并继续尝试下一个——回调分派绝不阻断调用方（启动路径）。
   */
  async dispatch(context: common.UIAbilityContext, want: Want): Promise<string> {
    const sink: ThirdPartyAuthCallbackSink = this.createSink(context)
    for (const bridge of this.bridges) {
      try {
        const consumed: boolean = await bridge.handleWant(context, want, sink)
        if (consumed) {
          return bridge.getProviderId()
        }
      } catch (error) {
        const err: BusinessError = error as BusinessError
        hilog.warn(0x0000, TAG, 'bridge ' + bridge.getProviderId() + ' handleWant failed: code=' + err.code
          + ' message=' + err.message)
        // 继续尝试下一个 bridge（不中断分派循环）
      }
    }
    return ''
  }

  /** 中止全部 bridge 的等待（页面销毁 / 超时）。 */
  cancelAll(): void {
    for (const bridge of this.bridges) {
      try {
        bridge.cancel()
      } catch (error) {
        // 取消失败无害，仅记录
        const err: BusinessError = error as BusinessError
        hilog.warn(0x0000, TAG, 'bridge ' + bridge.getProviderId() + ' cancel failed: ' + err.message)
      }
    }
  }

  /** 仅供测试：清空注册表。 */
  clearForTesting(): void {
    this.bridges = []
  }

  private resolve(providerId: string): ThirdPartyAuthBridge | null {
    const index: number = this.indexOf(providerId)
    return index >= 0 ? this.bridges[index] : null
  }

  private indexOf(providerId: string): number {
    for (let i = 0; i < this.bridges.length; i++) {
      if (this.bridges[i].getProviderId() === providerId) {
        return i
      }
    }
    return -1
  }

  /** 构造落到 PendingAuthStore 的回调出口。 */
  private createSink(context: common.UIAbilityContext): ThirdPartyAuthCallbackSink {
    return new PendingAuthSink(context)
  }
}

/**
 * ThirdPartyAuthCallbackSink 的默认实现 —— 把授权结果落到 PendingAuthStore。
 *
 * 用类而非对象字面量：ArkTS 禁止「未对应显式声明类型的对象字面量」
 * （arkts-no-untyped-obj-literals），接口实现须经 class implements。
 */
class PendingAuthSink implements ThirdPartyAuthCallbackSink {
  private context: Context

  constructor(context: Context) {
    this.context = context
  }

  async onAuthCode(code: ThirdPartyAuthCode): Promise<void> {
    await PendingAuthStore.saveCode(this.context, code)
  }

  async onAuthFailure(failure: ThirdPartyAuthFailure): Promise<void> {
    await PendingAuthStore.saveFailure(this.context, failure)
  }
}

export default new ThirdPartyBridgeRegistry()
