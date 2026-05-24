/**
 * HomePlanService - home screen plan summary helpers.
 *
 * Feature #4: home goal summary.
 * Feature #5: weekly plan rows.
 * Feature #8: today training entry.
 */
import {
  ExerciseContent,
  PlanDay,
  PlannedExercise,
  TrainingPlan,
  UserGoal
} from '../models/TrainingModels'
import { AppRoutes } from '../../app/AppRoutes'
import ContentRepository from './ContentRepository'

export interface HomeWeeklyPlanDay {
  dayId: string
  title: string
  exerciseCount: number
  isToday: boolean
}

export interface HomeRecommendedExercise {
  exerciseId: string
  name: string
  prescription: string
  intensityNote: string
}

export interface HomePlanSummary {
  hasGoal: boolean
  planId: string
  planName: string
  weeklyDays: number
  sessionMinutes: number
  goalSummary: string
  equipmentSummary: string
  restrictionSummary: string
  weeklyPlanDays: HomeWeeklyPlanDay[]
  todayDayId: string
  todayTitle: string
  todayLabel: string
  todayExerciseCount: number
  todayExerciseNames: string[]
  recommendedExercises: HomeRecommendedExercise[]
  startButtonText: string
  startRoute: string
}

class HomePlanService {
  createSummary(goal: UserGoal, plan: TrainingPlan, daySeed: number): HomePlanSummary {
    const today: PlanDay | undefined = this.pickTodayDay(plan, daySeed)
    if (today === undefined) {
      const emptyNames: string[] = []
      const emptyExercises: HomeRecommendedExercise[] = []
      const emptySummary: HomePlanSummary = {
        hasGoal: true,
        planId: plan.planId,
        planName: plan.name,
        weeklyDays: goal.weeklyDays,
        sessionMinutes: goal.sessionMinutes,
        goalSummary: this.createGoalSummary(goal),
        equipmentSummary: this.createEquipmentSummary(goal.equipmentIds),
        restrictionSummary: this.createRestrictionSummary(goal.restrictedMuscleIds),
        weeklyPlanDays: this.createWeeklyPlanDays(plan.days, ''),
        todayDayId: '',
        todayTitle: '休息日',
        todayLabel: '今天为休息日',
        todayExerciseCount: 0,
        todayExerciseNames: emptyNames,
        recommendedExercises: emptyExercises,
        startButtonText: '开始训练',
        startRoute: ''
      }
      return emptySummary
    }

    const names: string[] = this.getExerciseNames(today.exercises)
    const recommendedExercises: HomeRecommendedExercise[] = this.createRecommendedExercises(today.exercises)
    const summary: HomePlanSummary = {
      hasGoal: true,
      planId: plan.planId,
      planName: plan.name,
      weeklyDays: goal.weeklyDays,
      sessionMinutes: goal.sessionMinutes,
      goalSummary: this.createGoalSummary(goal),
      equipmentSummary: this.createEquipmentSummary(goal.equipmentIds),
      restrictionSummary: this.createRestrictionSummary(goal.restrictedMuscleIds),
      weeklyPlanDays: this.createWeeklyPlanDays(plan.days, today.dayId),
      todayDayId: today.dayId,
      todayTitle: today.title,
      todayLabel: '今天该练 ' + today.title,
      todayExerciseCount: today.exercises.length,
      todayExerciseNames: names,
      recommendedExercises: recommendedExercises,
      startButtonText: '开始训练',
      startRoute: AppRoutes.WORKOUT_PREVIEW
    }
    return summary
  }

  pickTodayDay(plan: TrainingPlan, daySeed: number): PlanDay | undefined {
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

  getExerciseNames(exercises: PlannedExercise[]): string[] {
    const names: string[] = []
    for (let index = 0; index < exercises.length; index++) {
      const planned: PlannedExercise = exercises[index]
      const content: ExerciseContent | undefined = ContentRepository.getExerciseById(planned.exerciseId)
      if (content !== undefined) {
        names.push(content.nameZh)
      } else {
        names.push(planned.exerciseId)
      }
    }
    return names
  }

  createRecommendedExercises(exercises: PlannedExercise[]): HomeRecommendedExercise[] {
    const items: HomeRecommendedExercise[] = []
    for (let index = 0; index < exercises.length; index++) {
      const planned: PlannedExercise = exercises[index]
      const content: ExerciseContent | undefined = ContentRepository.getExerciseById(planned.exerciseId)
      let name: string = planned.exerciseId
      if (content !== undefined) {
        name = content.nameZh
      }

      const item: HomeRecommendedExercise = {
        exerciseId: planned.exerciseId,
        name: name,
        prescription: planned.targetSets.toString() + ' 组 x ' + planned.targetReps,
        intensityNote: planned.intensityNote
      }
      items.push(item)
    }
    return items
  }

  createWeeklyPlanDays(days: PlanDay[], todayDayId: string): HomeWeeklyPlanDay[] {
    const weeklyPlanDays: HomeWeeklyPlanDay[] = []
    for (let index = 0; index < days.length; index++) {
      const day: PlanDay = days[index]
      const item: HomeWeeklyPlanDay = {
        dayId: day.dayId,
        title: day.title,
        exerciseCount: day.exercises.length,
        isToday: day.dayId === todayDayId
      }
      weeklyPlanDays.push(item)
    }
    return weeklyPlanDays
  }

  private createGoalSummary(goal: UserGoal): string {
    return '目标 ' + this.getGoalTypeLabel(goal.goalType) + ' · ' + this.getLevelLabel(goal.level) +
      ' · 每周 ' + goal.weeklyDays.toString() + ' 天 · 单次 ' + goal.sessionMinutes.toString() + ' 分钟'
  }

  private createEquipmentSummary(equipmentIds: string[]): string {
    if (equipmentIds.length === 0) {
      return '器械 徒手'
    }
    return '器械 ' + this.createNameList(equipmentIds, true)
  }

  private createRestrictionSummary(restrictedMuscleIds: string[]): string {
    if (restrictedMuscleIds.length === 0) {
      return '避开 无'
    }
    return '避开 ' + this.createNameList(restrictedMuscleIds, false)
  }

  private createNameList(ids: string[], isEquipment: boolean): string {
    let text: string = ''
    for (let index = 0; index < ids.length; index++) {
      if (index > 0) {
        text += '、'
      }
      if (isEquipment) {
        text += ContentRepository.getEquipmentName(ids[index])
      } else {
        text += ContentRepository.getMuscleName(ids[index])
      }
    }
    return text
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
}

export default new HomePlanService()
