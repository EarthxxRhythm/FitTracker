/**
 * HomePlanService - home screen plan summary helpers.
 *
 * Feature #4: home goal summary.
 * Feature #5: weekly plan rows.
 * Feature #8: today training entry.
 * Feature #19: current preset plan today view on home.
 * Feature #20: current preset plan rest-day view on home.
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
  primaryMetaText: string
  secondaryMetaText: string
  goalSummary: string
  equipmentSummary: string
  restrictionSummary: string
  weeklyPlanDays: HomeWeeklyPlanDay[]
  todayDayId: string
  todayTitle: string
  todayLabel: string
  hasTodayWorkout: boolean
  todayRestMessage: string
  todayExerciseCount: number
  todayExerciseNames: string[]
  recommendedExercises: HomeRecommendedExercise[]
  startButtonText: string
  startRoute: string
}

class HomePlanService {
  createSummary(goal: UserGoal, plan: TrainingPlan, daySeed: number): HomePlanSummary {
    const today: PlanDay | undefined = this.pickTodayDay(plan, daySeed)
    const primaryMetaText: string = '每周 ' + goal.weeklyDays.toString() + ' 天'
    const secondaryMetaText: string = '单次 ' + goal.sessionMinutes.toString() + ' 分钟'
    if (today === undefined) {
      const emptyNames: string[] = []
      const emptyExercises: HomeRecommendedExercise[] = []
      const emptySummary: HomePlanSummary = {
        hasGoal: true,
        planId: plan.planId,
        planName: plan.name,
        weeklyDays: goal.weeklyDays,
        sessionMinutes: goal.sessionMinutes,
        primaryMetaText: primaryMetaText,
        secondaryMetaText: secondaryMetaText,
        goalSummary: this.createGoalSummary(goal),
        equipmentSummary: this.createEquipmentSummary(goal.equipmentIds),
        restrictionSummary: this.createRestrictionSummary(goal.restrictedMuscleIds),
        weeklyPlanDays: this.createWeeklyPlanDays(plan.days, ''),
        todayDayId: '',
        todayTitle: '休息日',
        todayLabel: '今天是恢复日',
        hasTodayWorkout: false,
        todayRestMessage: '当前安排没有训练动作，今天更适合恢复、散步或拉伸。',
        todayExerciseCount: 0,
        todayExerciseNames: emptyNames,
        recommendedExercises: emptyExercises,
        startButtonText: '今天休息',
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
      primaryMetaText: primaryMetaText,
      secondaryMetaText: secondaryMetaText,
      goalSummary: this.createGoalSummary(goal),
      equipmentSummary: this.createEquipmentSummary(goal.equipmentIds),
      restrictionSummary: this.createRestrictionSummary(goal.restrictedMuscleIds),
      weeklyPlanDays: this.createWeeklyPlanDays(plan.days, today.dayId),
      todayDayId: today.dayId,
      todayTitle: today.title,
      todayLabel: '今天训练 | ' + today.title,
      hasTodayWorkout: true,
      todayRestMessage: '',
      todayExerciseCount: today.exercises.length,
      todayExerciseNames: names,
      recommendedExercises: recommendedExercises,
      startButtonText: '开始训练',
      startRoute: AppRoutes.WORKOUT_PREVIEW
    }
    return summary
  }

  createSummaryFromCurrentPlan(
    plan: UserPlan,
    todayLabel: string,
    todayTraining: TrainingDay | null
  ): HomePlanSummary {
    const emptyNames: string[] = []
    const primaryMetaText: string = plan.weeklyFrequency
    const secondaryMetaText: string = plan.targetAudience
    const goalSummary: string = '当前已启用预置训练计划，首页会跟随今天的安排展示训练或恢复状态。'
    const equipmentSummary: string = '计划来源 预置训练计划'
    const restrictionSummary: string = '适用人群 ' + plan.targetAudience
    const todayDayLabel: string = todayTraining === null ? '' : todayTraining.dayLabel
    const weeklyPlanDays: HomeWeeklyPlanDay[] = this.createWeeklyPlanDaysFromCurrentPlan(plan.days, todayDayLabel)

    if (todayTraining === null) {
      const emptyExercises: HomeRecommendedExercise[] = []
      const emptySummary: HomePlanSummary = {
        hasGoal: true,
        planId: plan.id,
        planName: plan.name,
        weeklyDays: plan.days.length,
        sessionMinutes: 0,
        primaryMetaText: primaryMetaText,
        secondaryMetaText: secondaryMetaText,
        goalSummary: goalSummary,
        equipmentSummary: equipmentSummary,
        restrictionSummary: restrictionSummary,
        weeklyPlanDays: weeklyPlanDays,
        todayDayId: '',
        todayTitle: '休息日',
        todayLabel: todayLabel + ' | 休息日',
        hasTodayWorkout: false,
        todayRestMessage: '当前计划今天没有训练安排，保持恢复节奏就好。',
        todayExerciseCount: 0,
        todayExerciseNames: emptyNames,
        recommendedExercises: emptyExercises,
        startButtonText: '今天休息',
        startRoute: ''
      }
      return emptySummary
    }

    const names: string[] = this.getExerciseNamesFromRefs(todayTraining.exercises)
    const recommendedExercises: HomeRecommendedExercise[] = this.createRecommendedExercisesFromRefs(
      plan.id,
      todayTraining.exercises
    )
    const summary: HomePlanSummary = {
      hasGoal: true,
      planId: plan.id,
      planName: plan.name,
      weeklyDays: plan.days.length,
      sessionMinutes: 0,
      primaryMetaText: primaryMetaText,
      secondaryMetaText: secondaryMetaText,
      goalSummary: goalSummary,
      equipmentSummary: equipmentSummary,
      restrictionSummary: restrictionSummary,
      weeklyPlanDays: weeklyPlanDays,
      todayDayId: this.getCurrentPlanDayId(plan.days, todayTraining.dayLabel),
      todayTitle: todayTraining.dayLabel,
      todayLabel: todayLabel + ' | ' + todayTraining.dayLabel,
      hasTodayWorkout: true,
      todayRestMessage: '',
      todayExerciseCount: todayTraining.exercises.length,
      todayExerciseNames: names,
      recommendedExercises: recommendedExercises,
      startButtonText: '训练流程接入中',
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

  getExerciseNamesFromRefs(exercises: ExerciseRef[]): string[] {
    const names: string[] = []
    for (let index = 0; index < exercises.length; index++) {
      names.push(exercises[index].name)
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

  createRecommendedExercisesFromRefs(planId: string, exercises: ExerciseRef[]): HomeRecommendedExercise[] {
    const items: HomeRecommendedExercise[] = []
    for (let index = 0; index < exercises.length; index++) {
      const exercise: ExerciseRef = exercises[index]
      const item: HomeRecommendedExercise = {
        exerciseId: planId + '_exercise_' + (index + 1).toString(),
        name: exercise.name,
        prescription: exercise.sets.toString() + ' 组 x ' + exercise.reps,
        intensityNote: '目标肌群 ' + exercise.targetMuscle
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

  createWeeklyPlanDaysFromCurrentPlan(days: TrainingDay[], todayDayLabel: string): HomeWeeklyPlanDay[] {
    const weeklyPlanDays: HomeWeeklyPlanDay[] = []
    for (let index = 0; index < days.length; index++) {
      const day: TrainingDay = days[index]
      const item: HomeWeeklyPlanDay = {
        dayId: 'current_plan_day_' + (index + 1).toString(),
        title: day.dayLabel,
        exerciseCount: day.exercises.length,
        isToday: day.dayLabel === todayDayLabel
      }
      weeklyPlanDays.push(item)
    }
    return weeklyPlanDays
  }

  getCurrentPlanDayId(days: TrainingDay[], todayDayLabel: string): string {
    for (let index = 0; index < days.length; index++) {
      if (days[index].dayLabel === todayDayLabel) {
        return 'current_plan_day_' + (index + 1).toString()
      }
    }
    return ''
  }

  private createGoalSummary(goal: UserGoal): string {
    return '目标 ' + this.getGoalTypeLabel(goal.goalType) + ' | ' + this.getLevelLabel(goal.level) +
      ' | 每周 ' + goal.weeklyDays.toString() + ' 天 | 单次 ' + goal.sessionMinutes.toString() + ' 分钟'
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
