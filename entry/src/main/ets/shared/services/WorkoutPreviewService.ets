/**
 * WorkoutPreviewService - transforms generated plan days into workout preview data.
 *
 * Feature #9: workout preview before active training.
 */
import {
  ExerciseContent,
  PlanDay,
  PlannedExercise,
  TrainingPlan,
  UserGoal
} from '../models/TrainingModels'
import { AppRoutes } from '../../app/AppRoutes'
import {
  ExerciseRef,
  TrainingDay,
  UserPlan
} from '../../common/services/TrainingPlanService'
import ContentRepository from './ContentRepository'

export interface WorkoutPreviewExercise {
  plannedExerciseId: string
  exerciseId: string
  name: string
  hasExerciseDetail: boolean
  targetSets: number
  targetReps: string
  intensityNote: string
  alternativeExerciseIds: string[]
  alternativeNames: string[]
  selectionNote: string
}

export interface WorkoutPreviewSummary {
  hasWorkout: boolean
  planId: string
  planName: string
  dayId: string
  title: string
  goalSummary: string
  scheduleSummary: string
  exerciseCount: number
  exercises: WorkoutPreviewExercise[]
  hasFallback: boolean
  fallbackNote: string
}

class WorkoutPreviewService {
  createPreview(plan: TrainingPlan, daySeed: number): WorkoutPreviewSummary {
    return this.createPreviewWithGoal(undefined, plan, daySeed)
  }

  createPreviewForGoal(goal: UserGoal, plan: TrainingPlan, daySeed: number): WorkoutPreviewSummary {
    return this.createPreviewWithGoal(goal, plan, daySeed)
  }

  createPreviewForCurrentPlan(
    plan: UserPlan,
    dayId: string,
    todayLabel: string,
    todayTraining: TrainingDay | null
  ): WorkoutPreviewSummary {
    let resolvedTraining: TrainingDay | null = todayTraining
    if (dayId.length > 0) {
      const matchedTraining: TrainingDay | null = this.findCurrentPlanTrainingByDayId(plan.days, dayId)
      if (matchedTraining !== null) {
        resolvedTraining = matchedTraining
      }
    }

    if (resolvedTraining === null) {
      const emptyExercises: WorkoutPreviewExercise[] = []
      const emptySummary: WorkoutPreviewSummary = {
        hasWorkout: false,
        planId: plan.id,
        planName: plan.name,
        dayId: '',
        title: '休息日',
        goalSummary: '当前已启用预置训练计划',
        scheduleSummary: todayLabel + ' | 今日休息',
        exerciseCount: 0,
        exercises: emptyExercises,
        hasFallback: false,
        fallbackNote: ''
      }
      return emptySummary
    }

    const resolvedDayId: string = this.getCurrentPlanDayId(plan.days, resolvedTraining.dayLabel)
    const exercises: WorkoutPreviewExercise[] = this.createPreviewExercisesFromRefs(
      plan.id,
      resolvedDayId,
      resolvedTraining.exercises
    )
    const summary: WorkoutPreviewSummary = {
      hasWorkout: exercises.length > 0,
      planId: plan.id,
      planName: plan.name,
      dayId: resolvedDayId,
      title: resolvedTraining.dayLabel,
      goalSummary: '当前已启用预置训练计划 | ' + plan.targetAudience,
      scheduleSummary: todayLabel + ' | ' + resolvedTraining.dayLabel + ' | ' + exercises.length.toString() + ' 个动作',
      exerciseCount: exercises.length,
      exercises: exercises,
      hasFallback: this.hasFallback(exercises),
      fallbackNote: this.createFallbackNote(exercises)
    }
    return summary
  }

  getStartWorkoutRoute(preview: WorkoutPreviewSummary): string {
    if (!preview.hasWorkout) {
      return ''
    }
    return AppRoutes.ACTIVE_WORKOUT
  }

  private createPreviewWithGoal(goal: UserGoal | undefined, plan: TrainingPlan, daySeed: number): WorkoutPreviewSummary {
    const day: PlanDay | undefined = this.pickDay(plan, daySeed)
    if (day === undefined) {
      const emptyExercises: WorkoutPreviewExercise[] = []
      const emptySummary: WorkoutPreviewSummary = {
        hasWorkout: false,
        planId: plan.planId,
        planName: plan.name,
        dayId: '',
        title: 'Rest Day',
        goalSummary: this.createGoalSummary(goal),
        scheduleSummary: '今天为休息日',
        exerciseCount: 0,
        exercises: emptyExercises,
        hasFallback: false,
        fallbackNote: ''
      }
      return emptySummary
    }

    const exercises: WorkoutPreviewExercise[] = []
    for (let index = 0; index < day.exercises.length; index++) {
      exercises.push(this.createPreviewExercise(day.exercises[index]))
    }

    const summary: WorkoutPreviewSummary = {
      hasWorkout: exercises.length > 0,
      planId: plan.planId,
      planName: plan.name,
      dayId: day.dayId,
      title: day.title,
      goalSummary: this.createGoalSummary(goal),
      scheduleSummary: this.createScheduleSummary(day, exercises.length),
      exerciseCount: exercises.length,
      exercises: exercises,
      hasFallback: this.hasFallback(exercises),
      fallbackNote: this.createFallbackNote(exercises)
    }
    return summary
  }

  private pickDay(plan: TrainingPlan, daySeed: number): PlanDay | undefined {
    if (plan.days.length === 0) {
      return undefined
    }

    let normalizedSeed: number = daySeed
    if (normalizedSeed <= 0) {
      normalizedSeed = 1
    }
    const index: number = (normalizedSeed - 1) % plan.days.length
    return plan.days[index]
  }

  private createGoalSummary(goal: UserGoal | undefined): string {
    if (goal === undefined) {
      return '训练目标待确认'
    }
    return '目标 ' + this.getGoalTypeLabel(goal.goalType) + ' · ' + this.getLevelLabel(goal.level) +
      ' · 每周 ' + goal.weeklyDays.toString() + ' 天 · 单次 ' + goal.sessionMinutes.toString() + ' 分钟'
  }

  private createScheduleSummary(day: PlanDay, exerciseCount: number): string {
    return '训练日 ' + day.title + ' · ' + day.dayId + ' · ' + exerciseCount.toString() + ' 个动作'
  }

  private getGoalTypeLabel(goalType: string): string {
    if (goalType === 'hypertrophy') {
      return '增肌'
    }
    if (goalType === 'strength') {
      return '力量'
    }
    if (goalType === 'fat_loss') {
      return '减脂'
    }
    if (goalType === 'posture') {
      return '体态'
    }
    return goalType
  }

  private getLevelLabel(level: string): string {
    if (level === 'beginner') {
      return '初学'
    }
    if (level === 'intermediate') {
      return '进阶'
    }
    if (level === 'advanced') {
      return '高级'
    }
    return level
  }

  private createPreviewExercise(planned: PlannedExercise): WorkoutPreviewExercise {
    const content: ExerciseContent | undefined = ContentRepository.getExerciseById(planned.exerciseId)
    let name: string = planned.exerciseId
    if (content !== undefined) {
      name = content.nameZh
    }

    const alternativeIds: string[] = this.copyStringArray(planned.alternativeExerciseIds)
    const alternativeNames: string[] = this.getAlternativeNames(alternativeIds)
    const item: WorkoutPreviewExercise = {
      plannedExerciseId: planned.plannedExerciseId,
      exerciseId: planned.exerciseId,
      name: name,
      hasExerciseDetail: content !== undefined,
      targetSets: planned.targetSets,
      targetReps: planned.targetReps,
      intensityNote: planned.intensityNote,
      alternativeExerciseIds: alternativeIds,
      alternativeNames: alternativeNames,
      selectionNote: planned.selectionNote
    }
    return item
  }

  private createPreviewExercisesFromRefs(
    planId: string,
    dayId: string,
    exercises: ExerciseRef[]
  ): WorkoutPreviewExercise[] {
    const values: WorkoutPreviewExercise[] = []
    for (let index = 0; index < exercises.length; index++) {
      values.push(this.createPreviewExerciseFromRef(planId, dayId, exercises[index], index))
    }
    return values
  }

  private createPreviewExerciseFromRef(
    planId: string,
    dayId: string,
    exercise: ExerciseRef,
    index: number
  ): WorkoutPreviewExercise {
    const content: ExerciseContent | undefined = this.findExerciseContentByName(exercise.name)
    const plannedExerciseId: string = dayId + '_exercise_' + (index + 1).toString()
    let exerciseId: string = planId + '_exercise_' + (index + 1).toString()
    let name: string = exercise.name
    let alternativeExerciseIds: string[] = []
    let alternativeNames: string[] = []
    let selectionNote: string = '预置计划动作暂未映射到动作库，将按名称记录'

    if (content !== undefined) {
      exerciseId = content.exerciseId
      name = content.nameZh
      alternativeExerciseIds = this.copyStringArray(content.alternativeExerciseIds)
      alternativeNames = this.getAlternativeNames(alternativeExerciseIds)
      selectionNote = '预置计划动作已映射到动作库，可继续查看动作详情'
    }

    const item: WorkoutPreviewExercise = {
      plannedExerciseId: plannedExerciseId,
      exerciseId: exerciseId,
      name: name,
      hasExerciseDetail: content !== undefined,
      targetSets: exercise.sets,
      targetReps: exercise.reps,
      intensityNote: '目标肌群 ' + exercise.targetMuscle,
      alternativeExerciseIds: alternativeExerciseIds,
      alternativeNames: alternativeNames,
      selectionNote: selectionNote
    }
    return item
  }

  private findExerciseContentByName(name: string): ExerciseContent | undefined {
    const exercises: ExerciseContent[] = ContentRepository.getExercises()
    for (let index = 0; index < exercises.length; index++) {
      const exercise: ExerciseContent = exercises[index]
      if (exercise.nameZh === name || exercise.nameEn === name) {
        return exercise
      }
      for (let aliasIndex = 0; aliasIndex < exercise.aliases.length; aliasIndex++) {
        if (exercise.aliases[aliasIndex] === name) {
          return exercise
        }
      }
    }
    return undefined
  }

  private findCurrentPlanTrainingByDayId(days: TrainingDay[], dayId: string): TrainingDay | null {
    for (let index = 0; index < days.length; index++) {
      if (this.getCurrentPlanDayId(days, days[index].dayLabel) === dayId) {
        return days[index]
      }
    }
    return null
  }

  private getCurrentPlanDayId(days: TrainingDay[], dayLabel: string): string {
    for (let index = 0; index < days.length; index++) {
      if (days[index].dayLabel === dayLabel) {
        return 'current_plan_day_' + (index + 1).toString()
      }
    }
    return ''
  }

  private hasFallback(exercises: WorkoutPreviewExercise[]): boolean {
    for (let index = 0; index < exercises.length; index++) {
      if (this.isFallbackNote(exercises[index].selectionNote)) {
        return true
      }
    }
    return false
  }

  private createFallbackNote(exercises: WorkoutPreviewExercise[]): string {
    for (let index = 0; index < exercises.length; index++) {
      const note: string = exercises[index].selectionNote
      if (this.isFallbackNote(note)) {
        return note
      }
    }
    return ''
  }

  private isFallbackNote(selectionNote: string): boolean {
    if (selectionNote.length === 0) {
      return false
    }
    return selectionNote.indexOf('精确匹配') !== 0
  }

  private getAlternativeNames(alternativeExerciseIds: string[]): string[] {
    const names: string[] = []
    for (let index = 0; index < alternativeExerciseIds.length; index++) {
      const exerciseId: string = alternativeExerciseIds[index]
      const content: ExerciseContent | undefined = ContentRepository.getExerciseById(exerciseId)
      if (content !== undefined) {
        names.push(content.nameZh)
      }
    }
    return names
  }

  private copyStringArray(source: string[]): string[] {
    const values: string[] = []
    for (let index = 0; index < source.length; index++) {
      values.push(source[index])
    }
    return values
  }
}

export default new WorkoutPreviewService()
