/**
 * HomePlanService - home screen plan summary helpers.
 *
 * Feature #8: today training entry.
 */
import {
  ExerciseContent,
  PlanDay,
  PlannedExercise,
  TrainingPlan,
  UserGoal
} from '../models/TrainingModels'
import ContentRepository from './ContentRepository'

export interface HomePlanSummary {
  hasGoal: boolean
  planId: string
  planName: string
  weeklyDays: number
  sessionMinutes: number
  todayDayId: string
  todayTitle: string
  todayExerciseCount: number
  todayExerciseNames: string[]
}

class HomePlanService {
  createSummary(goal: UserGoal, plan: TrainingPlan, daySeed: number): HomePlanSummary {
    const today: PlanDay | undefined = this.pickTodayDay(plan, daySeed)
    if (today === undefined) {
      const emptyNames: string[] = []
      const emptySummary: HomePlanSummary = {
        hasGoal: true,
        planId: plan.planId,
        planName: plan.name,
        weeklyDays: goal.weeklyDays,
        sessionMinutes: goal.sessionMinutes,
        todayDayId: '',
        todayTitle: 'Rest Day',
        todayExerciseCount: 0,
        todayExerciseNames: emptyNames
      }
      return emptySummary
    }

    const names: string[] = this.getExerciseNames(today.exercises)
    const summary: HomePlanSummary = {
      hasGoal: true,
      planId: plan.planId,
      planName: plan.name,
      weeklyDays: goal.weeklyDays,
      sessionMinutes: goal.sessionMinutes,
      todayDayId: today.dayId,
      todayTitle: today.title,
      todayExerciseCount: today.exercises.length,
      todayExerciseNames: names
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
}

export default new HomePlanService()
