/**
 * PlanEngine -- rule-based target-loop plan generation.
 *
 * Feature #3: plan engine and review calculations.
 */
import { PlanRule, SEED_PLAN_RULES } from '../../mock/SeedPlanRules'
import {
  ExerciseContent,
  PlanDay,
  PlannedExercise,
  TrainingPlan,
  UserGoal,
  createPlanDay,
  createPlannedExercise,
  createTrainingPlan
} from '../models/TrainingModels'
import ContentRepository from './ContentRepository'

const GENERATED_BY_RULE_V1: string = 'rule_v1'
const ACTIVE_STATUS: string = 'active'
const FOCUS_MUSCLE_IDS: string[] = [
  'muscle_chest',
  'muscle_back',
  'muscle_legs',
  'muscle_shoulders',
  'muscle_arms',
  'muscle_core'
]
const MAX_EXERCISES_PER_DAY: number = 3

class PlanEngineImpl {
  generatePlan(goal: UserGoal): TrainingPlan {
    const rule: PlanRule = this.findRule(goal.goalType)
    const days: PlanDay[] = []
    const weeklyDays: number = this.normalizeWeeklyDays(goal.weeklyDays)
    const availableFocusMuscleIds: string[] = this.getAvailableFocusMuscleIds(goal)

    for (let dayIndex = 0; dayIndex < weeklyDays; dayIndex++) {
      const focusMuscleId: string = this.pickFocusMuscleId(availableFocusMuscleIds, dayIndex)
      const dayNumber: number = dayIndex + 1
      const dayFocusMuscleIds: string[] = [focusMuscleId]
      const exercises: PlannedExercise[] = this.buildPlannedExercises(goal, rule, focusMuscleId, dayNumber)
      days.push(createPlanDay(
        'day_' + dayNumber.toString(),
        dayNumber,
        'Day ' + dayNumber.toString(),
        dayFocusMuscleIds,
        exercises
      ))
    }

    return createTrainingPlan(
      'plan_' + goal.goalId,
      goal.goalId,
      rule.planName,
      rule.cycleWeeks,
      days,
      GENERATED_BY_RULE_V1,
      ACTIVE_STATUS
    )
  }

  private normalizeWeeklyDays(weeklyDays: number): number {
    if (weeklyDays < 0) {
      return 0
    }
    if (weeklyDays > 7) {
      return 7
    }
    return weeklyDays
  }

  private findRule(goalType: string): PlanRule {
    for (let index = 0; index < SEED_PLAN_RULES.length; index++) {
      const rule: PlanRule = SEED_PLAN_RULES[index]
      if (rule.goalType === goalType) {
        return rule
      }
    }
    return SEED_PLAN_RULES[0]
  }

  private buildPlannedExercises(
    goal: UserGoal,
    rule: PlanRule,
    muscleId: string,
    dayNumber: number
  ): PlannedExercise[] {
    const plannedExercises: PlannedExercise[] = []
    const exercises: ExerciseContent[] = ContentRepository.getCandidateExercises(
      goal.goalType,
      goal.level,
      goal.equipmentIds,
      muscleId,
      goal.restrictedMuscleIds
    )

    for (let index = 0; index < exercises.length; index++) {
      if (plannedExercises.length >= MAX_EXERCISES_PER_DAY) {
        return plannedExercises
      }

      const exercise: ExerciseContent = exercises[index]
      plannedExercises.push(createPlannedExercise(
        'planned_' + dayNumber.toString() + '_' + (plannedExercises.length + 1).toString(),
        exercise.exerciseId,
        rule.targetSets,
        rule.targetReps,
        rule.intensityNote,
        this.copyStringArray(exercise.alternativeExerciseIds)
      ))
    }

    return plannedExercises
  }

  private getAvailableFocusMuscleIds(goal: UserGoal): string[] {
    const muscleIds: string[] = []
    for (let index = 0; index < FOCUS_MUSCLE_IDS.length; index++) {
      const muscleId: string = FOCUS_MUSCLE_IDS[index]
      if (!this.containsValue(goal.restrictedMuscleIds, muscleId) && this.hasCandidateExercise(goal, muscleId)) {
        muscleIds.push(muscleId)
      }
    }
    return muscleIds
  }

  private pickFocusMuscleId(availableFocusMuscleIds: string[], dayIndex: number): string {
    if (availableFocusMuscleIds.length > 0) {
      return availableFocusMuscleIds[dayIndex % availableFocusMuscleIds.length]
    }
    return FOCUS_MUSCLE_IDS[dayIndex % FOCUS_MUSCLE_IDS.length]
  }

  private hasCandidateExercise(goal: UserGoal, muscleId: string): boolean {
    const exercises: ExerciseContent[] = ContentRepository.getCandidateExercises(
      goal.goalType,
      goal.level,
      goal.equipmentIds,
      muscleId,
      goal.restrictedMuscleIds
    )
    return exercises.length > 0
  }

  private copyStringArray(source: string[]): string[] {
    const values: string[] = []
    for (let index = 0; index < source.length; index++) {
      values.push(source[index])
    }
    return values
  }

  private containsValue(values: string[], targetValue: string): boolean {
    for (let index = 0; index < values.length; index++) {
      if (values[index] === targetValue) {
        return true
      }
    }
    return false
  }

}

export default new PlanEngineImpl()
