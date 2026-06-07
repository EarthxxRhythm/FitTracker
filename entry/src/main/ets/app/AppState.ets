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
}

export class StartupDecision {
  static getInitialRoute(hasGoal: boolean): string {
    if (hasGoal) {
      return AppRoutes.HOME
    }
    return AppRoutes.GOAL_SETUP
  }
}
