/**
 * CloudEnvironment —— 云环境探测与降级（自托管 Supabase 后端）。
 *
 * 职责：
 *  - initialize(context)：幂等。探测 supabase.json（rawfile，自托管后端配置）。探测失败
 *    回落 sandbox（认证走 SandboxAuthProvider、同步走本地沙盒快照存储），保证任何环境
 *    可构建、可验证、可演示。
 *  - getBackend()：当前生效云后端的**单一真源**（sandbox 强制 > Supabase 显式配置 >
 *    沙盒兜底）。认证与同步两条链路的 resolve 均以它判据。
 *  - setModeForTesting('sandbox')：测试注入；ohosTest 经 AuthSyncTestGate 统一调用，
 *    确保测试始终走沙盒、不触真实网络。
 *
 * 2026-10-28：后端定稿为自托管 Supabase，华为 AGC 后端与 cloudCommon
 * 云数据库链路已整体移除（原 AgcAuthProvider / AgcCloudSnapshotStore 一并删除）。
 */
import { Context } from '@kit.AbilityKit'
import SupabaseConfig from './SupabaseConfig'

/** 当前生效的云后端。supabase 属「云端」，sandbox 为本地兜底。 */
export type CloudBackend = 'supabase' | 'sandbox'

class CloudEnvironment {
  private initialized: boolean = false
  private sandboxForced: boolean = false

  /** 幂等初始化：探测 Supabase 配置；失败回落 sandbox。 */
  async initialize(context: Context): Promise<void> {
    if (this.initialized) {
      return
    }
    if (this.sandboxForced) {
      this.initialized = true
      return
    }
    SupabaseConfig.initialize(context)
    this.initialized = true
  }

  /**
   * 当前生效的云后端（单一真源）。
   * 优先级：测试强制 sandbox > 显式配置的 Supabase > 沙盒兜底。
   */
  getBackend(): CloudBackend {
    if (this.sandboxForced) {
      return 'sandbox'
    }
    if (SupabaseConfig.isConfigured()) {
      return 'supabase'
    }
    return 'sandbox'
  }

  /** Supabase 配置是否就绪。 */
  isSupabaseConfigured(): boolean {
    return this.getBackend() === 'supabase'
  }

  isInitialized(): boolean {
    return this.initialized
  }

  /** 'cloud' | 'sandbox'，供 UI 展示当前运行模式。 */
  getModeLabel(): string {
    return this.getBackend() === 'sandbox' ? 'sandbox' : 'cloud'
  }

  /** 测试注入：强制 sandbox 模式（仅 ohosTest 使用；经 AuthSyncTestGate 统一调用）。 */
  setModeForTesting(mode: string): void {
    if (mode === 'sandbox') {
      this.sandboxForced = true
    }
  }
}

export default new CloudEnvironment()
