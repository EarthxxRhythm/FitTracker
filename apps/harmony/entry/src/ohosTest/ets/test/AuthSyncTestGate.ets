/**
 * AuthSyncTestGate —— 认证/同步测试的跨文件串行门与存储就绪预热。
 *
 * 背景（hypium 1.0.25）：
 * 1) Spec.run / SuiteService.runHookFunc 对 async 用例与钩子为裸调用（不 await），
 *    同一测试进程内各套件的异步链会交错推进：「链首清理」会踩掉其他链「写后立即读」
 *    的断言 → 用跨文件互斥门（acquire/releaseAuthSyncGate）串行化。
 * 2) 测试进程早期 getAppContext() 可能返回尚未绑定的 context，用它访问 preferences
 *    会持续失败（实证：Parameter error. The context is invalid.）。用例被 hypium
 *    调用的时刻各不相同，最先执行的那条链会踩着这段空窗 → 预热的每次重试都重新
 *    调用 getContext() 获取，成功后把「已验证可用的 context」交给调用方
 *    （WarmupOutcome.context），使链后续操作不再依赖用例开头的一次性快照。
 *
 * 预算纪律：用例墙钟超时由运行参数控制（tools/ohos-test.ps1 默认注入 -s timeout 60000）。
 * 预热上限 20s（40 × 500ms）；预热成功后其余链共享同一 Promise（已 resolve）
 * 瞬时通过，等待成本不在链间叠加。
 */
import { preferences } from '@kit.ArkData'
import CloudEnvironment from '../../../main/ets/common/services/CloudEnvironment'

const GATE_WAIT_TIMEOUT_MS: number = 4000
const GATE_POLL_INTERVAL_MS: number = 5
const WARMUP_STORE_NAME: string = 'fit_tracker_session'
const WARMUP_MAX_ATTEMPTS: number = 40
const WARMUP_RETRY_INTERVAL_MS: number = 500

/** 预热结果：成功时为已验证可用的 context，失败时 steps = -1（context 为最近一次获取值，诊断用）。 */
export interface WarmupOutcome {
  steps: number
  context: Context
}

let gateHeld: boolean = false
let warmupPromise: Promise<WarmupOutcome> | null = null
let lastProbeError: string = ''
let sandboxModeForced: boolean = false

/**
 * 测试环境强制沙盒模式：rawfile 中即使存在 supabase.json（真实云端配置，
 * Wave 5 已放入），测试也一律走沙盒认证 / 本地沙盒快照存储，不触真实云网络。
 * 由 ensureWarmup / acquireAuthSyncGate 自动调用（幂等）。
 */
export function ensureSandboxMode(): void {
  if (sandboxModeForced) {
    return
  }
  CloudEnvironment.setModeForTesting('sandbox')
  sandboxModeForced = true
}

function delayTick(ms: number): Promise<void> {
  return new Promise<void>((resolve: () => void) => {
    setTimeout(() => {
      resolve()
    }, ms)
  })
}

async function probePreferences(getContext: () => Context): Promise<WarmupOutcome> {
  for (let attempt = 0; attempt < WARMUP_MAX_ATTEMPTS; attempt++) {
    // 每轮重新获取 context：进程早期 getAppContext() 可能返回未绑定的 context，
    // 固定快照会让探测持续失败（Parameter error. The context is invalid.）。
    const context: Context = getContext()
    try {
      const prefs = await preferences.getPreferences(context, WARMUP_STORE_NAME)
      // 写+读组合：写触发存储创建/修复路径，读验证读路径可用
      await prefs.put('warmup_probe', '1')
      await prefs.flush()
      await prefs.get('warmup_probe', '')
      const success: WarmupOutcome = { steps: attempt, context: context }
      return success
    } catch (error) {
      const err: Error = error as Error
      lastProbeError = err.message !== undefined ? err.message : String(error)
      await delayTick(WARMUP_RETRY_INTERVAL_MS)
    }
  }
  const failed: WarmupOutcome = { steps: -1, context: getContext() }
  return failed
}

/**
 * 共享单飞预热：返回 WarmupOutcome（steps = 成功前的重试步数，-1 = 上限内未就绪；
 * context = 成功时为已验证可用的 context，供链后续操作直接使用）。
 * 第一个调用者启动探测（只有它的 getContext 生效）；其余调用者等待同一 Promise。
 */
export function ensureWarmup(getContext: () => Context): Promise<WarmupOutcome> {
  ensureSandboxMode()
  if (warmupPromise === null) {
    warmupPromise = probePreferences(getContext)
  }
  return warmupPromise
}

/** 最近一次预热探测失败的原始错误消息（诊断用；空串 = 尚无失败记录）。 */
export function getLastWarmupError(): string {
  return lastProbeError
}

/** @deprecated 直接探测版本（保留兼容）；新代码请用 ensureWarmup。 */
export async function warmUpPreferences(context: Context): Promise<void> {
  await probePreferences(() => context)
}

export async function acquireAuthSyncGate(): Promise<void> {
  ensureSandboxMode()
  let waited: number = 0
  while (gateHeld && waited < GATE_WAIT_TIMEOUT_MS) {
    await delayTick(GATE_POLL_INTERVAL_MS)
    waited += GATE_POLL_INTERVAL_MS
  }
  gateHeld = true
}

export function releaseAuthSyncGate(): void {
  gateHeld = false
}
