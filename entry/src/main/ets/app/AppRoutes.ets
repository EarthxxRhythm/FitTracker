/**
 * AppRoutes -- MVP target training loop route constants.
 * Function #8: target-driven workout loop.
 */
export class AppRoutes {
  static readonly STARTUP: string = 'features/pencil/PencilSplashPage'
  static readonly WELCOME: string = 'features/welcome/pages/PencilWelcomePage'
  static readonly LOGIN: string = 'features/pencil/PencilLoginPage'
  static readonly REGISTER: string = 'features/pencil/PencilRegisterPage'
  static readonly PROFILE: string = 'features/pencil/PencilProfilePage'
  static readonly GOAL_SETUP: string = 'features/onboarding/pages/GoalSetupPage'
  static readonly HOME: string = 'features/pencil/PencilHomePage'
  static readonly APP_SHELL: string = 'app/PencilAppShell'
  static readonly EXERCISE_LIBRARY: string = 'features/exercise/pages/ExerciseLibraryPage'
  static readonly EXERCISE_DETAIL: string = 'features/exercise/pages/ExerciseDetailPage'
  static readonly MONETIZATION_HUB: string = 'features/monetization/pages/MonetizationHubPage'
  static readonly TRAINING_PLAN_DETAIL: string = 'features/pencil/PencilPlanPage'
  static readonly WORKOUT_PREVIEW: string = 'features/pencil/PencilPreviewPage'
  static readonly ACTIVE_WORKOUT: string = 'features/pencil/PencilActivePage'
  static readonly WORKOUT_COMPLETE: string = 'features/workout/pages/WorkoutCompletePage'
  static readonly REVIEW_HOME: string = 'features/pencil/PencilReviewPage'
}
