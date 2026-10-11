/**
 * CloudEnvironment —— 云环境探测、AGC 初始化与降级。
 *
 * 职责：
 *  - initialize(context)：幂等。探测 agconnect-services.json（rawfile）并执行 AGC 认证
 *    SDK 初始化；任一环节失败回落 sandbox（认证走 SandboxAuthProvider、同步走本地沙盒
 *    快照存储），保证任何环境可构建、可验证、可演示。
 *  - ensureCloudDatabaseReady()：cloudCommon 初始化（携带登录凭据 authProvider 与
 *    schema.json）。官方要求「在用户登录成功的情况下获取 authProvider」——由同步流程
 *    在已登录状态下调用；成功后幂等缓存，失败下次可重试。
 *  - setModeForTesting('sandbox')：测试注入；ohosTest 经 AuthSyncTestGate 统一调用，
 *    确保 rawfile 中存在 agconnect-services.json 时测试仍走沙盒、不触真实网络。
 */
import { Context } from '@kit.AbilityKit'
import { buffer } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { cloudCommon } from '@kit.CloudFoundationKit'
import auth from '@hw-agconnect/auth'

const AGC_CONFIG_FILE: string = 'agconnect-services.json'
const CLOUD_DB_SCHEMA_FILE: string = 'schema.json'

class CloudEnvironment {
  private initialized: boolean = false
  private agcConfigured: boolean = false
  private cloudDatabaseReady: boolean = false
  private sandboxForced: boolean = false

  /** 幂等初始化：探测 AGC 配置并完成认证 SDK 初始化；失败回落 sandbox。 */
  async initialize(context: Context): Promise<void> {
    if (this.initialized) {
      return
    }
    if (this.sandboxForced) {
      this.agcConfigured = false
      this.initialized = true
      return
    }
    this.agcConfigured = this.detectAndInitAgc(context)
    this.initialized = true
  }

  /** AGC 配置是否就绪（sandbox 测试注入时恒为 false）。 */
  isAgcConfigured(): boolean {
    if (this.sandboxForced) {
      return false
    }
    return this.agcConfigured
  }

  isInitialized(): boolean {
    return this.initialized
  }

  /** 'cloud' | 'sandbox'，供 UI 展示当前运行模式。 */
  getModeLabel(): string {
    return this.isAgcConfigured() ? 'cloud' : 'sandbox'
  }

  /**
   * 云数据库就绪：cloudCommon 初始化（authProvider 登录凭据 + schema.json）。
   * 须在用户登录成功后调用（官方获取 authProvider 的时序要求）；成功后幂等。
   */
  async ensureCloudDatabaseReady(): Promise<boolean> {
    if (!this.isAgcConfigured()) {
      return false
    }
    if (this.cloudDatabaseReady) {
      return true
    }
    try {
      const databaseOptions: cloudCommon.DatabaseOptions = { schema: CLOUD_DB_SCHEMA_FILE }
      const options: cloudCommon.CloudOptions = {
        region: cloudCommon.CloudRegion.CHINA,
        authProvider: auth.getAuthProvider(),
        databaseOptions: databaseOptions
      }
      cloudCommon.init(options)
      this.cloudDatabaseReady = true
      return true
    } catch (error) {
      const err: BusinessError = error as BusinessError
      hilog.error(0x0000, 'CloudEnvironment', 'cloudDatabase init failed: code=' + err.code + ' message=' + err.message)
      return false
    }
  }

  /** 测试注入：强制 sandbox 模式（仅 ohosTest 使用；经 AuthSyncTestGate 统一调用）。 */
  setModeForTesting(mode: string): void {
    if (mode === 'sandbox') {
      this.sandboxForced = true
    }
  }

  private detectAndInitAgc(context: Context): boolean {
    try {
      const file: Uint8Array = context.resourceManager.getRawFileContentSync(AGC_CONFIG_FILE)
      const json: string = buffer.from(file.buffer).toString()
      auth.init(context, json)
      return true
    } catch (error) {
      const err: BusinessError = error as BusinessError
      hilog.error(0x0000, 'CloudEnvironment', 'AGC init failed: code=' + err.code + ' message=' + err.message)
      return false
    }
  }
}

export default new CloudEnvironment()
