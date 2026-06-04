/**
 * AppRoutes -- MVP target training loop route constants.
 * Function #8: target-driven workout loop.
 */
export class AppRoutes {
  static readonly STARTUP: string = 'app/StartupPage'
  static readonly LOGIN: string = 'pages/LoginPage'
  static readonly REGISTER: string = 'pages/RegisterPage'
  static readonly GOAL_SETUP: string = 'features/onboarding/pages/GoalSetupPage'
  static readonly HOME: string = 'pages/HomePage'
  static readonly EXERCISE_LIBRARY: string = 'features/exercise/pages/ExerciseLibraryPage'
  static readonly EXERCISE_DETAIL: string = 'features/exercise/pages/ExerciseDetailPage'
  static readonly TRAINING_PLAN_DETAIL: string = 'features/workout/pages/TrainingPlanDetailPage'
  static readonly WORKOUT_PREVIEW: string = 'features/workout/pages/WorkoutPreviewPage'
  static readonly ACTIVE_WORKOUT: string = 'features/workout/pages/ActiveWorkoutPage'
  static readonly WORKOUT_SUMMARY: string = 'features/workout/pages/WorkoutSummaryPage'
  static readonly REVIEW_HOME: string = 'features/review/pages/ReviewHomePage'
}
