/**
 * 常驻 Tab 状态层基类。
 *
 * 承载「按需重读」的通用失效语义：写路径调 [invalidate] 精确置脏，
 * [needRefresh] 判定是否需要重读（从未装载 / 已置脏 / 超过保鲜期）。
 *
 * 由 PencilAppShell 以 `@State` 持有（生命周期 = 主壳，tab 切换不销毁），
 * 各 `*Content` 以 `@ObjectLink` 消费——数据在 tab 间存活，且不再每次可见都无条件重跑装载。
 */
export abstract class StateBase {
  /** 上次成功装载时间戳（ms）；0 = 从未装载。 */
  protected lastLoadedAt: number = 0
  /** 写路径显式置脏；true = 需要重读。 */
  protected invalidated: boolean = true
  /** 并发保护：装载进行中标记。 */
  protected loading: boolean = false

  /**
   * 是否需要重读：从未装载 / 被显式置脏 / 超过保鲜期。
   *
   * [maxAgeMs] 兜底超时（默认 30s）——写路径遗漏 `invalidate()` 时，数据也不会永久陈旧。
   */
  needRefresh(now: number = Date.now(), maxAgeMs: number = 30000): boolean {
    if (this.invalidated) {
      return true
    }
    if (this.lastLoadedAt === 0) {
      return true
    }
    return now - this.lastLoadedAt > maxAgeMs
  }

  /** 写路径调用：精确失效。 */
  invalidate(): void {
    this.invalidated = true
  }

  /** 子类在装载成功后调用：标记已装载、清脏、重置 loading。 */
  protected markLoaded(): void {
    this.lastLoadedAt = Date.now()
    this.invalidated = false
  }

  /** 子类在装载开始前调用：并发保护（已在进行中则跳过）。 */
  protected tryBeginLoading(): boolean {
    if (this.loading) {
      return false
    }
    this.loading = true
    return true
  }

  /** 子类在装载结束（成功或失败）后调用。 */
  protected endLoading(): void {
    this.loading = false
  }
}
