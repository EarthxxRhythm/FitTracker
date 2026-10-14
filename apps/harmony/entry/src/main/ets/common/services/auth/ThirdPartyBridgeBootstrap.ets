/**
 * ThirdPartyBridgeBootstrap —— 第三方桥的注册入口。
 *
 * 存在理由：Registry 不直接 import 三个具体 bridge（避免「未安装 SDK 时编译失败」的强耦合，
 * 以及 bridge ↔ Registry 的循环依赖）。由本文件集中注册，应用启动时调用一次。
 *
 * 调用点：PencilLoginPage.aboutToAppear（登录页是第三方登录的唯一入口）
 * 与 EntryAbility.onCreate（冷启动即由回调拉起时，需要 bridge 已在册才能分派）。
 * 注册是幂等的（Registry.register 按 providerId 覆盖）。
 */
import { Context } from '@kit.AbilityKit'
import ThirdPartyConfig from './ThirdPartyConfig'
import ThirdPartyBridgeRegistry from './ThirdPartyBridgeRegistry'
import WeChatAuthBridge from './thirdparty/WeChatAuthBridge'
import QqAuthBridge from './thirdparty/QqAuthBridge'
import HuaweiAuthBridge from './thirdparty/HuaweiAuthBridge'

class ThirdPartyBridgeBootstrap {
  private initialized: boolean = false

  /**
   * 幂等初始化：探测第三方配置并注册三个 bridge。
   * 即使未配置任何 AppID 也注册——bridge 内部按配置判 isAvailable，
   * 使 UI 能区分「通道未配置」与「通道不可用」。
   */
  initialize(context: Context): void {
    if (this.initialized) {
      return
    }
    ThirdPartyConfig.initialize(context)
    ThirdPartyBridgeRegistry.register(WeChatAuthBridge)
    ThirdPartyBridgeRegistry.register(QqAuthBridge)
    ThirdPartyBridgeRegistry.register(HuaweiAuthBridge)
    this.initialized = true
  }

  /** 仅供测试：复位初始化标志。 */
  resetForTesting(): void {
    this.initialized = false
  }
}

export default new ThirdPartyBridgeBootstrap()
