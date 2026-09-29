/**
 * AppState - app-level constants and startup helpers.
 *
 * Feature #4: local repositories and app state.
 */
import { AppRoutes } from './AppRoutes'

export class FitTrackerStores {
  static readonly GOAL: string = 'fit_tracker_goal'
  static readonly CONTENT: string = 'fit_tracker_content'
  static readonly CONTENT_SYNC: string = 'fit_tracker_content_sync'
  static readonly PLANS: string = 'fit_tracker_plans'
  static readonly WORKOUTS: string = 'fit_tracker_workouts'
  static readonly RECORDS: string = 'fit_tracker_records'
  static readonly SYNC: string = 'fit_tracker_sync'
}

export class StartupDecision {
  /**
   * 冷启动分流矩阵（强制登录，PRD 3.1 口径）：
   *  - 未登录 → 登录页
   *  - 已登录且无目标 → 目标设置
   *  - 已登录且有目标 → 主壳
   */
  static getInitialRoute(hasValidSession: boolean, hasGoal: boolean): string {
    if (!hasValidSession) {
      return AppRoutes.LOGIN
    }
    if (hasGoal) {
      return AppRoutes.APP_SHELL
    }
    return AppRoutes.GOAL_SETUP
  }
}
