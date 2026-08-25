/**
 * DeviceSeedService -- deterministic app-owned seed paths for device-side probes.
 */
import { Context } from '@kit.AbilityKit'
import AuthService from '../../common/services/AuthService'
import SessionManager from '../../common/services/SessionManager'
import TrainingPlanService from '../../common/services/TrainingPlanService'
import WorkoutDraftService from '../../common/services/WorkoutDraftService'
import UserProfileService, { UserProfile } from '../../common/services/UserProfileService'
import {
  WorkoutSession,
  WorkoutSet,
  createUserGoal,
  createWorkoutSession,
  createWorkoutSet
} from '../models/TrainingModels'
import { createMonetizationEntitlement } from '../models/MonetizationModels'
import GoalRepository from './GoalRepository'
import MonetizationEntitlementService from './MonetizationEntitlementService'
import WorkoutSessionPersistenceBridgeService from '../../features/workout/services/WorkoutSessionPersistenceBridgeService'

interface DemoSetTemplate {
  weight: number
  reps: number
}

interface DemoExerciseTemplate {
  exerciseId: string
  sets: DemoSetTemplate[]
}

interface DemoDaySchedule {
  sessionId: string
  dayId: string
  weeksAgo: number
  dayOffset: number
  durationMinutes: number
  exercises: DemoExerciseTemplate[]
}

class DeviceSeedService {
  async applyNamedSeed(context: Context, seedKey: string): Promise<boolean> {
    if (seedKey === 'review_metrics') {
      await this.applyReviewMetricsSeed(context)
      return true
    }
    if (seedKey === 'today_flow') {
      await this.applyTodayFlowSeed(context)
      return true
    }
    if (seedKey === 'demo_data') {
      await this.applyDemoDataSeed(context)
      return true
    }
    return false
  }

  private async applyTodayFlowSeed(context: Context): Promise<void> {
    const now: number = Date.now()
    const seededPhone: string = '13800138000'
    const seededPassword: string = '123456'
    const seededEquipmentIds: string[] = ['eq_bodyweight', 'eq_dumbbell']
    await AuthService.clearPersistedUsers(context)
    const registerResult = await AuthService.registerLocal(context, seededPhone, seededPassword)
    const token: string = registerResult.success ? registerResult.token : SessionManager.generateToken(seededPhone)
    await SessionManager.saveToken(context, token)
    await GoalRepository.saveGoal(
      context,
      createUserGoal(
        'goal_today_flow',
        'hypertrophy',
        'beginner',
        3,
        45,
        seededEquipmentIds,
        [],
        now,
        now
      )
    )
    await TrainingPlanService.replaceMyPlans(context, [], '')
    await WorkoutDraftService.clearDraft(context)
    await MonetizationEntitlementService.clearEntitlementForTesting(context)
    await WorkoutSessionPersistenceBridgeService.replacePersistedSessions(context, [])
    await WorkoutSessionPersistenceBridgeService.syncRepositoryFromPersistence(context)
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

  private async applyDemoDataSeed(context: Context): Promise<void> {
    const now: number = Date.now()
    const seededPhone: string = '13800138000'
    const seededPassword: string = '123456'
    const seededEquipmentIds: string[] = ['eq_dumbbell', 'eq_barbell', 'eq_bodyweight']
    await AuthService.clearPersistedUsers(context)
    const registerResult = await AuthService.registerLocal(context, seededPhone, seededPassword)
    const token: string = registerResult.success ? registerResult.token : SessionManager.generateToken(seededPhone)
    await SessionManager.saveToken(context, token)
    const demoProfile: UserProfile = {
      nickname: '谱尼',
      avatar: '谱',
      weightUnit: 'kg'
    }
    await UserProfileService.saveProfile(context, demoProfile)
    await GoalRepository.saveGoal(
      context,
      createUserGoal(
        'goal_demo_data',
        'hypertrophy',
        'beginner',
        3,
        45,
        seededEquipmentIds,
        [],
        now,
        now
      )
    )
    await TrainingPlanService.replaceMyPlans(context, [], '')
    await WorkoutDraftService.clearDraft(context)
    await MonetizationEntitlementService.clearEntitlementForTesting(context)
    const sessions: WorkoutSession[] = this.createDemoSessions()
    await WorkoutSessionPersistenceBridgeService.replacePersistedSessions(context, sessions)
    await WorkoutSessionPersistenceBridgeService.syncRepositoryFromPersistence(context)
  }

  private createDemoSessions(): WorkoutSession[] {
    const pushDay: DemoExerciseTemplate[] = this.createPushDay()
    const pullDay: DemoExerciseTemplate[] = this.createPullDay()
    const legDay: DemoExerciseTemplate[] = this.createLegDay()
    const schedule: DemoDaySchedule[] = [
      this.createDaySlot('session_demo_01', 'day_push', 3, 0, 50, pushDay),
      this.createDaySlot('session_demo_02', 'day_pull', 3, 2, 48, pullDay),
      this.createDaySlot('session_demo_03', 'day_legs', 3, 4, 55, legDay),
      this.createDaySlot('session_demo_04', 'day_push', 2, 0, 52, pushDay),
      this.createDaySlot('session_demo_05', 'day_pull', 2, 2, 50, pullDay),
      this.createDaySlot('session_demo_06', 'day_legs', 2, 4, 58, legDay),
      this.createDaySlot('session_demo_07', 'day_push', 1, 0, 50, pushDay),
      this.createDaySlot('session_demo_08', 'day_pull', 1, 2, 48, pullDay),
      this.createDaySlot('session_demo_09', 'day_legs', 1, 4, 56, legDay),
      this.createDaySlot('session_demo_10', 'day_push', 0, 0, 52, pushDay),
      this.createDaySlot('session_demo_11', 'day_pull', 0, 2, 50, pullDay)
    ]
    const sessions: WorkoutSession[] = []
    for (let index = 0; index < schedule.length; index++) {
      const slot: DemoDaySchedule = schedule[index]
      sessions.push(this.createDemoSession(slot))
    }
    return sessions
  }

  private createDaySlot(
    sessionId: string,
    dayId: string,
    weeksAgo: number,
    dayOffset: number,
    durationMinutes: number,
    exercises: DemoExerciseTemplate[]
  ): DemoDaySchedule {
    const slot: DemoDaySchedule = {
      sessionId: sessionId,
      dayId: dayId,
      weeksAgo: weeksAgo,
      dayOffset: dayOffset,
      durationMinutes: durationMinutes,
      exercises: exercises
    }
    return slot
  }

  private createDemoSession(slot: DemoDaySchedule): WorkoutSession {
    const startTime: number = this.createDemoTimestamp(slot.weeksAgo, slot.dayOffset)
    const durationSeconds: number = slot.durationMinutes * 60
    const endTime: number = startTime + durationSeconds * 1000
    const sets: WorkoutSet[] = []
    let totalSets: number = 0
    let totalVolume: number = 0
    let setIdIndex: number = 0
    for (let exerciseIndex = 0; exerciseIndex < slot.exercises.length; exerciseIndex++) {
      const template: DemoExerciseTemplate = slot.exercises[exerciseIndex]
      const templateSets: DemoSetTemplate[] = template.sets
      for (let setIndex = 0; setIndex < templateSets.length; setIndex++) {
        const setTemplate: DemoSetTemplate = templateSets[setIndex]
        sets.push(createWorkoutSet(
          slot.sessionId + '_set_' + setIdIndex.toString(),
          template.exerciseId,
          setTemplate.weight,
          setTemplate.reps,
          0,
          false
        ))
        totalSets++
        totalVolume += setTemplate.weight * setTemplate.reps
        setIdIndex++
      }
    }
    return createWorkoutSession(
      slot.sessionId,
      'plan_demo_data',
      slot.dayId,
      startTime,
      endTime,
      durationSeconds,
      totalSets,
      Math.round(totalVolume * 100) / 100,
      0,
      'completed_sets=' + totalSets.toString() + ';target_sets=' + totalSets.toString(),
      sets
    )
  }

  private createDemoTimestamp(weeksAgo: number, dayOffset: number): number {
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
      monday.getDate() - weeksAgo * 7 + dayOffset,
      19,
      30,
      0,
      0
    ).getTime()
  }

  private createDemoExercise(exerciseId: string, weights: number[], reps: number[]): DemoExerciseTemplate {
    const sets: DemoSetTemplate[] = []
    const count: number = weights.length < reps.length ? weights.length : reps.length
    for (let index = 0; index < count; index++) {
      const set: DemoSetTemplate = {
        weight: weights[index],
        reps: reps[index]
      }
      sets.push(set)
    }
    const template: DemoExerciseTemplate = {
      exerciseId: exerciseId,
      sets: sets
    }
    return template
  }

  private createPushDay(): DemoExerciseTemplate[] {
    const templates: DemoExerciseTemplate[] = []
    templates.push(this.createDemoExercise('ex_barbell_bench_press', [40, 50, 55, 55], [10, 8, 8, 6]))
    templates.push(this.createDemoExercise('ex_incline_dumbbell_press', [16, 18, 18], [12, 10, 10]))
    templates.push(this.createDemoExercise('ex_dumbbell_shoulder_press', [14, 14, 14], [10, 10, 8]))
    templates.push(this.createDemoExercise('ex_cable_triceps_pressdown', [20, 20, 20], [15, 12, 12]))
    return templates
  }

  private createPullDay(): DemoExerciseTemplate[] {
    const templates: DemoExerciseTemplate[] = []
    templates.push(this.createDemoExercise('ex_lat_pulldown', [40, 45, 45], [12, 10, 10]))
    templates.push(this.createDemoExercise('ex_dumbbell_row', [22, 24, 24], [10, 10, 8]))
    templates.push(this.createDemoExercise('ex_seated_cable_row', [35, 40, 40], [12, 10, 10]))
    templates.push(this.createDemoExercise('ex_dumbbell_curl', [12, 12, 12], [12, 10, 8]))
    return templates
  }

  private createLegDay(): DemoExerciseTemplate[] {
    const templates: DemoExerciseTemplate[] = []
    templates.push(this.createDemoExercise('ex_barbell_squat', [50, 60, 65, 65], [10, 8, 8, 6]))
    templates.push(this.createDemoExercise('ex_romanian_deadlift', [45, 50, 50], [10, 8, 8]))
    templates.push(this.createDemoExercise('ex_walking_lunge', [16, 16], [12, 12]))
    return templates
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
