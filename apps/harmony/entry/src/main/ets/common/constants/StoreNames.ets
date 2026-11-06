/**
 * StoreNames - 本机存储库名。
 *
 * 从 app/AppState 下沉，供 shared/common 层引用，消除 shared → app 反向依赖。
 */
export class FitTrackerStores {
  static readonly GOAL: string = 'fit_tracker_goal'
  static readonly CONTENT: string = 'fit_tracker_content'
  static readonly CONTENT_SYNC: string = 'fit_tracker_content_sync'
  static readonly PLANS: string = 'fit_tracker_plans'
  static readonly WORKOUTS: string = 'fit_tracker_workouts'
  static readonly RECORDS: string = 'fit_tracker_records'
  /** 体重记录库（镜像安卓 `StoreNames.BODY_RECORDS`）。 */
  static readonly BODY_RECORDS: string = 'fit_tracker_body_records'
  /** 身体测量记录库（围度 + 体成分；镜像安卓 `StoreNames.BODY_MEASUREMENTS`）。 */
  static readonly BODY_MEASUREMENTS: string = 'fit_tracker_body_measurements'
  static readonly SYNC: string = 'fit_tracker_sync'
}
