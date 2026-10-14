/**
 * ThirdPartyConfig —— 第三方登录的运行时配置探测（rawfile `thirdparty.json`）。
 *
 * 与 SupabaseConfig.ets 同构：真值文件不入库（.gitignore 排除 thirdparty.json），
 * 模板 thirdparty.example.json 入库。缺失时各 AppID 返回空串 → 对应通道视为「未开通」，
 * 保证任何环境可构建、可运行、可降级演示。
 *
 * 字段说明：
 *  - wechatAppId：微信开放平台移动应用 AppID（`wx` 开头）
 *  - qqAppId：QQ 互联应用 AppID（数字串）——同时用于 module.json5 的 skills host
 *  - huaweiClientId：AGC 项目设置的 Client ID（华为账号登录）
 *
 * 注意：**不含任何 secret**。AppSecret / AppKey / ClientSecret 只存在于服务端
 * （见 server/supabase/functions/thirdparty-exchange/）。
 */
import { Context } from '@kit.AbilityKit'
import { buffer } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG: string = 'ThirdPartyConfig'
const CONFIG_FILE: string = 'thirdparty.json'

/** rawfile `thirdparty.json` 的字段形状。 */
export interface ThirdPartyRuntimeConfig {
  wechatAppId: string
  qqAppId: string
  huaweiClientId: string
}

class ThirdPartyConfig {
  private config: ThirdPartyRuntimeConfig | null = null
  private probed: boolean = false

  /** 幂等探测 rawfile `thirdparty.json`；失败/缺失一律置 null（视为未配置）。 */
  initialize(context: Context): void {
    if (this.probed) {
      return
    }
    this.probed = true
    try {
      const file: Uint8Array = context.resourceManager.getRawFileContentSync(CONFIG_FILE)
      const json: string = buffer.from(file.buffer).toString()
      const parsed: ThirdPartyRuntimeConfig = JSON.parse(json) as ThirdPartyRuntimeConfig
      this.config = parsed
    } catch (error) {
      const err: BusinessError = error as BusinessError
      // 文件缺失属正常情况（未配置第三方登录）——不打 error 级日志
      hilog.info(0x0000, TAG, 'thirdparty.json not present or unreadable: ' + err.message)
      this.config = null
    }
  }

  /** 微信 AppID；未配置返回空串。 */
  getWeChatAppId(): string {
    const config: ThirdPartyRuntimeConfig | null = this.config
    if (config === null || config.wechatAppId === undefined) {
      return ''
    }
    return config.wechatAppId
  }

  /** QQ AppID；未配置返回空串。 */
  getQqAppId(): string {
    const config: ThirdPartyRuntimeConfig | null = this.config
    if (config === null || config.qqAppId === undefined) {
      return ''
    }
    return config.qqAppId
  }

  /** 华为 Client ID；未配置返回空串。 */
  getHuaweiClientId(): string {
    const config: ThirdPartyRuntimeConfig | null = this.config
    if (config === null || config.huaweiClientId === undefined) {
      return ''
    }
    return config.huaweiClientId
  }

  /** 测试注入：直接置配置并标记已探测。 */
  setForTesting(config: ThirdPartyRuntimeConfig | null): void {
    this.config = config
    this.probed = true
  }
}

export default new ThirdPartyConfig()
