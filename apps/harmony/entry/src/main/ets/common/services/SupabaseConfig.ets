/**
 * SupabaseConfig —— 自托管 Supabase 运行时配置探测。
 *
 * 职责：
 *  - initialize(context)：幂等。从 rawfile 读取 supabase.json（不入库，含 url 与
 *    publishable key），解析失败或字段为空则视为「未配置」。
 *  - isConfigured() / get()：同步读探测结果，供 CloudEnvironment.getBackend() 判据使用。
 *  - setForTesting(config)：测试注入，绕过 rawfile 探测。
 *
 * 与已移除的华为 AGC 方案的对应关系：agconnect-services.json 之于 AGC，等价于 supabase.json 之于 Supabase
 * ——两者都是「rawfile 中的运行时凭据文件，不入库」，探测方式与 CloudEnvironment.detectAndInitAgc
 * 同构（getRawFileContentSync + try/catch 回落）。
 */
import { Context } from '@kit.AbilityKit'
import { buffer } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const SUPABASE_CONFIG_FILE: string = 'supabase.json'

/** Supabase 运行时配置（rawfile `supabase.json` 的字段形状）。 */
export interface SupabaseRuntimeConfig {
  url: string
  publishableKey: string
}

class SupabaseConfig {
  private config: SupabaseRuntimeConfig | null = null
  private probed: boolean = false

  /** 幂等探测 rawfile `supabase.json`；失败/字段缺失一律置 null（视为未配置）。 */
  initialize(context: Context): void {
    if (this.probed) {
      return
    }
    this.probed = true
    try {
      const file: Uint8Array = context.resourceManager.getRawFileContentSync(SUPABASE_CONFIG_FILE)
      const json: string = buffer.from(file.buffer).toString()
      const parsed: SupabaseRuntimeConfig = JSON.parse(json) as SupabaseRuntimeConfig
      if (parsed.url.length > 0 && parsed.publishableKey.length > 0) {
        this.config = parsed
      }
    } catch (error) {
      const err: BusinessError = error as BusinessError
      hilog.error(0x0000, 'SupabaseConfig', 'probe failed: code=' + err.code + ' message=' + err.message)
      this.config = null
    }
  }

  /** 是否已配置（url 与 publishableKey 均非空）。 */
  isConfigured(): boolean {
    return this.config !== null
  }

  /** 取运行时配置；未配置返回 null。 */
  get(): SupabaseRuntimeConfig | null {
    return this.config
  }

  /** 测试注入：直接置配置（null 表示未配置），并标记已探测。 */
  setForTesting(config: SupabaseRuntimeConfig | null): void {
    this.config = config
    this.probed = true
  }
}

export default new SupabaseConfig()
