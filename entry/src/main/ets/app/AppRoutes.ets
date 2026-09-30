/**
 * AppRoutes -- MVP target training loop route constants.
 * Function #8: target-driven workout loop.
 */
export class AppRoutes {
  static readonly STARTUP: string = 'features/pencil/pages/PencilSplashPage'
  static readonly WELCOME: string = 'features/welcome/pages/PencilWelcomePage'
  static readonly LOGIN: string = 'features/pencil/pages/PencilLoginPage'
  static readonly REGISTER: string = 'features/pencil/pages/PencilRegisterPage'
  static readonly PROFILE: string = 'features/pencil/pages/PencilProfilePage'
  static readonly HOME: string = 'features/pencil/pages/PencilHomePage'
  static readonly APP_SHELL: string = 'app/PencilAppShell'
  static readonly EXERCISE_LIBRARY: string = 'features/exercise/pages/ExerciseLibraryPage'
  static readonly EXERCISE_DETAIL: string = 'features/exercise/pages/ExerciseDetailPage'
  static readonly TRAINING_PLAN_DETAIL: string = 'features/pencil/pages/PencilPlanPage'
  // 训练预览已改为 PencilAppShell 的 bindContentCover 全模态，不再是路由页（已从
  // main_pages.json 移除）。此常量保留：HomePlanService.startRoute 与相关测试把它作为
  // 「开始训练入口」标识引用，无生产代码据此 pushUrl。
  static readonly WORKOUT_PREVIEW: string = 'features/pencil/pages/PencilPreviewPage'
  static readonly ACTIVE_WORKOUT: string = 'features/pencil/pages/PencilActivePage'
  static readonly WORKOUT_COMPLETE: string = 'features/workout/pages/WorkoutCompletePage'
  static readonly REVIEW_HOME: string = 'features/pencil/pages/PencilReviewPage'
  static readonly PLANS: string = 'features/pencil/pages/PencilPlansPage'
  static readonly PLAN_GROUP_DETAIL: string = 'features/pencil/pages/PencilPlanGroupDetailPage'
  static readonly BODY_DATA: string = 'features/body/pages/BodyDataPage'
  static readonly SETTINGS: string = 'features/settings/pages/PencilSettingsPage'
  static readonly ACCOUNT_SYNC: string = 'features/account/pages/AccountSyncPage'
}
