/**
 * UserDataBackupService -- manual JSON backup and restore for local user data.
 *
 * Feature #41: export and import goal, plans, current plan pointer, and workout sessions.
 */
import { UserPlan } from '../../common/services/TrainingPlanService'
import TrainingPlanService, { ExerciseRef, TrainingDay } from '../../common/services/TrainingPlanService'
import GoalRepository from './GoalRepository'
import WorkoutRepository from './WorkoutRepository'
import WorkoutSessionPersistenceBridgeService from '../../features/workout/services/WorkoutSessionPersistenceBridgeService'
import ContentRepository from './ContentRepository'
import { UserGoal, WorkoutSession, WorkoutSet, createUserGoal, createWorkoutSession, createWorkoutSet } from '../models/TrainingModels'

const BACKUP_SCHEMA_VERSION = 1

export interface UserDataBackupContentMeta {
  contentVersion: number
}

export interface UserDataBackupPackage {
  schemaVersion: number
  exportedAt: number
  goal: UserGoal | null
  plans: UserPlan[]
  currentPlanId: string
  sessions: WorkoutSession[]
  contentMeta: UserDataBackupContentMeta
}

export interface UserDataBackupImportResult {
  success: boolean
  importedPlanCount: number
  importedSessionCount: number
  mergedSessionCount: number
  statusText: string
}

class UserDataBackupService {
  async exportPackage(context: Context): Promise<string> {
    const goal: UserGoal | undefined = await GoalRepository.loadGoal(context)
    const plans: UserPlan[] = await TrainingPlanService.getMyPlans(context)
    const currentPlanId: string = await TrainingPlanService.getCurrentPlanId(context)
    const persistedSessions: WorkoutSession[] = await WorkoutSessionPersistenceBridgeService.loadPersistedSessions(context)
    const mergedSessions: WorkoutSession[] = this.mergeSessions(persistedSessions, WorkoutRepository.getSessions())
    const backupPackage: UserDataBackupPackage = this.createPackage(
      goal === undefined ? null : goal,
      plans,
      currentPlanId,
      mergedSessions,
      Date.now()
    )
    return JSON.stringify(backupPackage, null, 2)
  }

  async importPackage(context: Context, json: string): Promise<UserDataBackupImportResult> {
    const backupPackage: UserDataBackupPackage | null = this.parsePackageJson(json)
    if (backupPackage === null) {
      return this.createImportResult(false, 0, 0, 0, '备份包格式无效，无法导入。')
    }

    if (backupPackage.goal === null) {
      await GoalRepository.clearSavedGoal(context)
    } else {
      await GoalRepository.saveGoal(context, backupPackage.goal)
    }

    await TrainingPlanService.replaceMyPlans(context, backupPackage.plans, backupPackage.currentPlanId)

    const existingSessions: WorkoutSession[] = await WorkoutSessionPersistenceBridgeService.loadPersistedSessions(context)
    const mergedSessions: WorkoutSession[] = this.mergeSessions(existingSessions, backupPackage.sessions)
    await WorkoutSessionPersistenceBridgeService.replacePersistedSessions(context, mergedSessions)
    await WorkoutSessionPersistenceBridgeService.syncRepositoryFromPersistence(context)

    return this.createImportResult(
      true,
      backupPackage.plans.length,
      backupPackage.sessions.length,
      mergedSessions.length,
      '备份已导入：' + backupPackage.plans.length.toString() + ' 个计划，' +
        mergedSessions.length.toString() + ' 条训练记录。'
    )
  }

  createPackage(
    goal: UserGoal | null,
    plans: UserPlan[],
    currentPlanId: string,
    sessions: WorkoutSession[],
    exportedAt: number
  ): UserDataBackupPackage {
    const backupPackage: UserDataBackupPackage = {
      schemaVersion: BACKUP_SCHEMA_VERSION,
      exportedAt: exportedAt,
      goal: goal === null ? null : this.copyGoal(goal),
      plans: this.copyPlans(plans),
      currentPlanId: currentPlanId,
      sessions: this.copySessions(sessions),
      contentMeta: {
        contentVersion: ContentRepository.getLocalContentVersion()
      }
    }
    return backupPackage
  }

  parsePackageJson(json: string): UserDataBackupPackage | null {
    if (json.trim().length === 0) {
      return null
    }
    try {
      const parsed = JSON.parse(json) as UserDataBackupPackage
      if (!this.isValidBackupPackage(parsed)) {
        return null
      }
      return this.createPackage(
        parsed.goal,
        parsed.plans,
        parsed.currentPlanId,
        parsed.sessions,
        parsed.exportedAt
      )
    } catch (e) {
      return null
    }
  }

  mergeSessions(existingSessions: WorkoutSession[], importedSessions: WorkoutSession[]): WorkoutSession[] {
    const sessions: WorkoutSession[] = this.copySessions(existingSessions)
    for (let importedIndex = 0; importedIndex < importedSessions.length; importedIndex++) {
      const importedSession: WorkoutSession = importedSessions[importedIndex]
      let replaced: boolean = false
      for (let existingIndex = 0; existingIndex < sessions.length; existingIndex++) {
        if (sessions[existingIndex].sessionId === importedSession.sessionId) {
          sessions[existingIndex] = this.copySession(importedSession)
          replaced = true
          break
        }
      }
      if (!replaced) {
        sessions.push(this.copySession(importedSession))
      }
    }
    return sessions
  }

  private createImportResult(
    success: boolean,
    importedPlanCount: number,
    importedSessionCount: number,
    mergedSessionCount: number,
    statusText: string
  ): UserDataBackupImportResult {
    const result: UserDataBackupImportResult = {
      success: success,
      importedPlanCount: importedPlanCount,
      importedSessionCount: importedSessionCount,
      mergedSessionCount: mergedSessionCount,
      statusText: statusText
    }
    return result
  }

  private isValidBackupPackage(source: UserDataBackupPackage): boolean {
    if (!this.isFiniteNumberValue(source.schemaVersion) || source.schemaVersion !== BACKUP_SCHEMA_VERSION) {
      return false
    }
    if (!this.isFiniteNumberValue(source.exportedAt) || !this.isStringValue(source.currentPlanId)) {
      return false
    }
    if (!this.isValidGoal(source.goal) || !Array.isArray(source.plans) || !Array.isArray(source.sessions)) {
      return false
    }
    if (!this.isValidContentMeta(source.contentMeta)) {
      return false
    }
    for (let planIndex = 0; planIndex < source.plans.length; planIndex++) {
      if (!this.isValidPlan(source.plans[planIndex])) {
        return false
      }
    }
    for (let sessionIndex = 0; sessionIndex < source.sessions.length; sessionIndex++) {
      if (!this.isValidSession(source.sessions[sessionIndex])) {
        return false
      }
    }
    return true
  }

  private isValidContentMeta(source: UserDataBackupContentMeta): boolean {
    return this.isFiniteNumberValue(source.contentVersion)
  }

  private isValidGoal(source: UserGoal | null): boolean {
    if (source === null) {
      return true
    }
    if (!this.isStringValue(source.goalId) || !this.isStringValue(source.goalType) || !this.isStringValue(source.level)) {
      return false
    }
    if (!this.isFiniteNumberValue(source.weeklyDays) || !this.isFiniteNumberValue(source.sessionMinutes)) {
      return false
    }
    if (!this.isStringArray(source.equipmentIds) || !this.isStringArray(source.restrictedMuscleIds)) {
      return false
    }
    if (!this.isFiniteNumberValue(source.createdAt) || !this.isFiniteNumberValue(source.updatedAt)) {
      return false
    }
    return true
  }

  private isValidPlan(source: UserPlan): boolean {
    if (!this.isStringValue(source.id) || !this.isStringValue(source.name) || !this.isStringValue(source.coverColor) ||
      !this.isStringValue(source.targetAudience) || !this.isStringValue(source.weeklyFrequency)) {
      return false
    }
    if (!Array.isArray(source.days) || !this.isFiniteNumberValue(source.enabledAt)) {
      return false
    }
    for (let dayIndex = 0; dayIndex < source.days.length; dayIndex++) {
      if (!this.isValidTrainingDay(source.days[dayIndex])) {
        return false
      }
    }
    return true
  }

  private isValidTrainingDay(source: TrainingDay): boolean {
    if (!this.isStringValue(source.dayLabel) || !Array.isArray(source.exercises)) {
      return false
    }
    if (source.dayOfWeek !== undefined && !this.isNumberArray(source.dayOfWeek)) {
      return false
    }
    for (let exerciseIndex = 0; exerciseIndex < source.exercises.length; exerciseIndex++) {
      if (!this.isValidExerciseRef(source.exercises[exerciseIndex])) {
        return false
      }
    }
    return true
  }

  private isValidExerciseRef(source: ExerciseRef): boolean {
    if (!this.isStringValue(source.name) || !this.isStringValue(source.targetMuscle) || !this.isStringValue(source.reps)) {
      return false
    }
    return this.isFiniteNumberValue(source.sets)
  }

  private isValidSession(source: WorkoutSession): boolean {
    if (!this.isStringValue(source.sessionId) || !this.isStringValue(source.planId) || !this.isStringValue(source.dayId)) {
      return false
    }
    if (!this.isFiniteNumberValue(source.startedAt) || !this.isFiniteNumberValue(source.endedAt) ||
      !this.isFiniteNumberValue(source.durationSeconds) || !this.isFiniteNumberValue(source.totalSets) ||
      !this.isFiniteNumberValue(source.totalVolume) || !this.isFiniteNumberValue(source.fatigueScore) ||
      !this.isStringValue(source.notes) || !Array.isArray(source.sets)) {
      return false
    }
    for (let setIndex = 0; setIndex < source.sets.length; setIndex++) {
      if (!this.isValidWorkoutSet(source.sets[setIndex])) {
        return false
      }
    }
    return true
  }

  private isValidWorkoutSet(source: WorkoutSet): boolean {
    if (!this.isStringValue(source.setId) || !this.isStringValue(source.exerciseId)) {
      return false
    }
    if (!this.isFiniteNumberValue(source.weight) || !this.isFiniteNumberValue(source.reps) ||
      !this.isFiniteNumberValue(source.rpe)) {
      return false
    }
    return this.isBooleanValue(source.isWarmup)
  }

  private isStringArray(source: string[]): boolean {
    if (!Array.isArray(source)) {
      return false
    }
    for (let index = 0; index < source.length; index++) {
      if (!this.isStringValue(source[index])) {
        return false
      }
    }
    return true
  }

  private isNumberArray(source: number[]): boolean {
    if (!Array.isArray(source)) {
      return false
    }
    for (let index = 0; index < source.length; index++) {
      if (!this.isFiniteNumberValue(source[index])) {
        return false
      }
    }
    return true
  }

  private isStringValue(value: string): boolean {
    if (value === null || value === undefined) {
      return false
    }
    return value.toString() === value
  }

  private isFiniteNumberValue(value: number): boolean {
    return Number.isFinite(value)
  }

  private isBooleanValue(value: boolean): boolean {
    return value === true || value === false
  }

  private copyGoal(source: UserGoal): UserGoal {
    return createUserGoal(
      source.goalId,
      source.goalType,
      source.level,
      source.weeklyDays,
      source.sessionMinutes,
      this.copyStringArray(source.equipmentIds),
      this.copyStringArray(source.restrictedMuscleIds),
      source.createdAt,
      source.updatedAt
    )
  }

  private copyPlans(source: UserPlan[]): UserPlan[] {
    const plans: UserPlan[] = []
    for (let index = 0; index < source.length; index++) {
      plans.push(this.copyPlan(source[index]))
    }
    return plans
  }

  private copyPlan(source: UserPlan): UserPlan {
    const plan: UserPlan = {
      id: source.id,
      name: source.name,
      coverColor: source.coverColor,
      targetAudience: source.targetAudience,
      weeklyFrequency: source.weeklyFrequency,
      days: this.copyPlanDays(source.days),
      enabledAt: source.enabledAt
    }
    return plan
  }

  private copyPlanDays(source: TrainingDay[]): TrainingDay[] {
    const days: TrainingDay[] = []
    for (let index = 0; index < source.length; index++) {
      const sourceDay: TrainingDay = source[index]
      const day: TrainingDay = {
        dayLabel: sourceDay.dayLabel,
        dayOfWeek: this.copyNumberArray(sourceDay.dayOfWeek),
        exercises: this.copyExerciseRefs(sourceDay.exercises)
      }
      days.push(day)
    }
    return days
  }

  private copyExerciseRefs(source: ExerciseRef[]): ExerciseRef[] {
    const exercises: ExerciseRef[] = []
    for (let index = 0; index < source.length; index++) {
      const sourceExercise: ExerciseRef = source[index]
      const exercise: ExerciseRef = {
        name: sourceExercise.name,
        targetMuscle: sourceExercise.targetMuscle,
        sets: sourceExercise.sets,
        reps: sourceExercise.reps
      }
      exercises.push(exercise)
    }
    return exercises
  }

  private copySessions(source: WorkoutSession[]): WorkoutSession[] {
    const sessions: WorkoutSession[] = []
    for (let index = 0; index < source.length; index++) {
      sessions.push(this.copySession(source[index]))
    }
    return sessions
  }

  private copySession(source: WorkoutSession): WorkoutSession {
    const sets: WorkoutSet[] = []
    for (let index = 0; index < source.sets.length; index++) {
      sets.push(this.copyWorkoutSet(source.sets[index]))
    }
    return createWorkoutSession(
      source.sessionId,
      source.planId,
      source.dayId,
      source.startedAt,
      source.endedAt,
      source.durationSeconds,
      source.totalSets,
      source.totalVolume,
      source.fatigueScore,
      source.notes,
      sets
    )
  }

  private copyWorkoutSet(source: WorkoutSet): WorkoutSet {
    return createWorkoutSet(
      source.setId,
      source.exerciseId,
      source.weight,
      source.reps,
      source.rpe,
      source.isWarmup
    )
  }

  private copyStringArray(source: string[]): string[] {
    const values: string[] = []
    for (let index = 0; index < source.length; index++) {
      values.push(source[index])
    }
    return values
  }

  private copyNumberArray(source: number[] | undefined): number[] | undefined {
    if (source === undefined) {
      return undefined
    }
    const values: number[] = []
    for (let index = 0; index < source.length; index++) {
      values.push(source[index])
    }
    return values
  }
}

export default new UserDataBackupService()
