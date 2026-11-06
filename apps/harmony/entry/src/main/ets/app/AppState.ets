/**
 * AppState - app-level constants and startup helpers.
 *
 * Feature #4: local repositories and app state.
 */
import { AppRoutes } from './AppRoutes'

/** 本机存储库名已下沉至 common/constants/StoreNames，此处转出以保持既有引用可用。 */
export { FitTrackerStores } from '../common/constants/StoreNames'

export class StartupDecision {
  /**
   * 冷启动分流矩阵（强制登录，PRD 3.1 口径）：
   *  - 未登录 → 登录页
   *  - 已登录 → 主壳（无目标不再强制进入目标设置页：GoalSetupPage 已随产品变更
   *    整体移除，无目标场景由首页空态承接，见 HomeContent.applyEmptyState）
   *
   * hasGoal 参数保留以稳定调用方签名（登录/注册/启动三处均传真实值），当前不参与分流决策。
   */
  static getInitialRoute(hasValidSession: boolean, hasGoal: boolean): string {
    if (!hasValidSession) {
      return AppRoutes.LOGIN
    }
    return AppRoutes.APP_SHELL
  }
}
