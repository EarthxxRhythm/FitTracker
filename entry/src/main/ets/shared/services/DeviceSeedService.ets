/**
 * DeviceSeedService -- deterministic app-owned seed paths for device-side probes.
 */
import { Context } from '@kit.AbilityKit'
import SessionManager from '../../common/services/SessionManager'
import {
  WorkoutSession,
  createUserGoal,
  createWorkoutSession,
  createWorkoutSet
} from '../models/TrainingModels'
import { createMonetizationEntitlement } from '../models/MonetizationModels'
import GoalRepository from './GoalRepository'
import MonetizationEntitlementService from './MonetizationEntitlementService'
import WorkoutSessionPersistenceBridgeService from '../../features/workout/services/WorkoutSessionPersistenceBridgeService'

class DeviceSeedService {
  async applyNamedSeed(context: Context, seedKey: string): Promise<boolean> {
    if (seedKey === 'review_metrics') {
      await this.applyReviewMetricsSeed(context)
      return true
    }
    return false
  }

  private async applyReviewMetricsSeed(context: Context): Promise<void> {
    const now: number = Date.now()
    const token: string = SessionManager.generateToken('13900009999')
    await SessionManager.saveToken(context, token)
    await GoalRepository.saveGoal(
      context,
      createUserGoal(
        'goal_review_metrics',
        'hypertrophy',
        'intermediate',
        3,
        45,
        ['eq_barbell', 'eq_bench'],
        [],
        now,
        now
      )
    )
    await MonetizationEntitlementService.writeEntitlement(
      context,
      createMonetizationEntitlement(
        '13900009999',
        'pro',
        'debug_override',
        'active',
        'pro_lifetime',
        'fittracker_pro_lifetime',
        now,
        0,
        now,
        now,
        1
      )
    )

    const firstSessionStart: number = this.createCurrentWeekTimestamp(0, 8, 0)
    const secondSessionStart: number = this.createCurrentWeekTimestamp(2, 9, 30)
    const seededSessions: WorkoutSession[] = [
      createWorkoutSession(
        'session_review_metrics_1',
        'plan_review_metrics',
        'day_push',
        firstSessionStart,
        firstSessionStart + 45 * 60 * 1000,
        2700,
        4,
        1007,
        0,
        'completed_sets=4;target_sets=5',
        [
          createWorkoutSet('session_review_metrics_1_set_1', 'ex_barbell_bench_press', 90, 5, 0, false),
          createWorkoutSet('session_review_metrics_1_set_2', 'ex_barbell_bench_press', 55, 10, 0, false),
          createWorkoutSet('session_review_metrics_1_set_3', 'ex_barbell_bench_press', 1, 4, 0, false),
          createWorkoutSet('session_review_metrics_1_set_4', 'ex_barbell_bench_press', 1, 3, 0, false)
        ]
      ),
      createWorkoutSession(
        'session_review_metrics_2',
        'plan_review_metrics',
        'day_pull',
        secondSessionStart,
        secondSessionStart + 30 * 60 * 1000,
        1800,
        3,
        0,
        0,
        'completed_sets=3;target_sets=4',
        [
          createWorkoutSet('session_review_metrics_2_set_1', 'ex_barbell_row', 51, 3, 0, false),
          createWorkoutSet('session_review_metrics_2_set_2', 'ex_barbell_row', 51, 2, 0, false),
          createWorkoutSet('session_review_metrics_2_set_3', 'ex_barbell_row', 51, 2, 0, false)
        ]
      )
    ]
    await WorkoutSessionPersistenceBridgeService.replacePersistedSessions(context, seededSessions)
    await WorkoutSessionPersistenceBridgeService.syncRepositoryFromPersistence(context)
  }

  private createCurrentWeekTimestamp(offsetDays: number, hour: number, minute: number): number {
    const now: Date = new Date()
    const currentDayOfWeek: number = now.getDay()
    let mondayOffset: number = currentDayOfWeek - 1
    if (currentDayOfWeek === 0) {
      mondayOffset = 6
    }
    const monday: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate() - mondayOffset, 0, 0, 0, 0)
    return new Date(
      monday.getFullYear(),
      monday.getMonth(),
      monday.getDate() + offsetDays,
      hour,
      minute,
      0,
      0
    ).getTime()
  }
}

export default new DeviceSeedService()
