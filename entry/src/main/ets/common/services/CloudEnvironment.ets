/**
 * CloudEnvironment —— 云环境探测与降级。
 *
 * AGC 配置（agconnect-services.json，放置于 rawfile）存在且初始化成功时进入 cloud 模式；
 * 否则进入 sandbox 模式（认证走 SandboxAuthProvider、同步走本地快照存储），
 * 保证任何环境可构建、可验证、可演示。
 *
 * Wave 5 接入 AGC SDK 时：在 detectAndInit 中追加初始化尝试，失败则回落 sandbox。
 */
import { Context } from '@kit.AbilityKit'

const AGC_CONFIG_FILE: string = 'agconnect-services.json'

class CloudEnvironment {
  private initialized: boolean = false
  private agcConfigured: boolean = false

  /** 幂等初始化：探测 AGC 配置并缓存结果。 */
  async initialize(context: Context): Promise<void> {
    if (this.initialized) {
      return
    }
    this.agcConfigured = this.detectAgcConfig(context)
    this.initialized = true
  }

  isAgcConfigured(): boolean {
    return this.agcConfigured
  }

  isInitialized(): boolean {
    return this.initialized
  }

  /** 'cloud' | 'sandbox'，供 UI 展示当前运行模式。 */
  getModeLabel(): string {
    return this.agcConfigured ? 'cloud' : 'sandbox'
  }

  private detectAgcConfig(context: Context): boolean {
    try {
      context.resourceManager.getRawFileContentSync(AGC_CONFIG_FILE)
      return true
    } catch (error) {
      return false
    }
  }
}

export default new CloudEnvironment()
