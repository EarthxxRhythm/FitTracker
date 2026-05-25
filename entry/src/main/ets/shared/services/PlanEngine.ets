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
const BODYWEIGHT_EQUIPMENT_ID: string = 'eq_bodyweight'
const EXACT_MATCH_NOTE: string = '精确匹配：目标、器械、肌群和难度均匹配。'
const RELAX_DIFFICULTY_NOTE: string = '已放宽难度：未找到完全匹配动作，优先保留目标、器械和肌群。'
const RELAX_EQUIPMENT_NOTE: string = '已放宽器械：未找到可用器械动作，请在执行前确认替代器械。'

class ScoredExercise {
  exercise: ExerciseContent
  score: number
  selectionNote: string

  constructor(exercise: ExerciseContent, score: number, selectionNote: string) {
    this.exercise = exercise
    this.score = score
    this.selectionNote = selectionNote
  }
}

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
    const exercises: ScoredExercise[] = this.findScoredCandidates(goal, muscleId)

    for (let index = 0; index < exercises.length; index++) {
      if (plannedExercises.length >= MAX_EXERCISES_PER_DAY) {
        return plannedExercises
      }

      const scoredExercise: ScoredExercise = exercises[index]
      const exercise: ExerciseContent = scoredExercise.exercise
      plannedExercises.push(createPlannedExercise(
        'planned_' + dayNumber.toString() + '_' + (plannedExercises.length + 1).toString(),
        exercise.exerciseId,
        rule.targetSets,
        rule.targetReps,
        rule.intensityNote,
        this.copyStringArray(exercise.alternativeExerciseIds),
        scoredExercise.selectionNote
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
    const exercises: ScoredExercise[] = this.findScoredCandidates(goal, muscleId)
    return exercises.length > 0
  }

  private findScoredCandidates(goal: UserGoal, muscleId: string): ScoredExercise[] {
    const exactMatches: ScoredExercise[] = this.collectCandidates(goal, muscleId, true, true, EXACT_MATCH_NOTE)
    if (exactMatches.length > 0) {
      return exactMatches
    }

    const relaxedDifficultyMatches: ScoredExercise[] = this.collectCandidates(goal, muscleId, true, false, RELAX_DIFFICULTY_NOTE)
    if (relaxedDifficultyMatches.length > 0) {
      return relaxedDifficultyMatches
    }

    return this.collectCandidates(goal, muscleId, false, false, RELAX_EQUIPMENT_NOTE)
  }

  private collectCandidates(
    goal: UserGoal,
    muscleId: string,
    requireEquipment: boolean,
    requireDifficulty: boolean,
    selectionNote: string
  ): ScoredExercise[] {
    const allExercises: ExerciseContent[] = ContentRepository.getExercises()
    const equipmentIds: string[] = this.normalizeEquipmentIds(goal.equipmentIds)
    const scoredExercises: ScoredExercise[] = []

    for (let index = 0; index < allExercises.length; index++) {
      const exercise: ExerciseContent = allExercises[index]
      if (!this.matchesRequiredFields(exercise, goal, muscleId, equipmentIds, requireEquipment, requireDifficulty)) {
        continue
      }

      const score: number = this.scoreExercise(exercise, goal, muscleId, equipmentIds)
      scoredExercises.push(new ScoredExercise(exercise, score, selectionNote))
    }

    return this.sortScoredExercises(scoredExercises)
  }

  private matchesRequiredFields(
    exercise: ExerciseContent,
    goal: UserGoal,
    muscleId: string,
    equipmentIds: string[],
    requireEquipment: boolean,
    requireDifficulty: boolean
  ): boolean {
    if (this.containsRestrictedMuscle(exercise, goal.restrictedMuscleIds)) {
      return false
    }
    if (!this.containsValue(exercise.goalTags, goal.goalType)) {
      return false
    }
    if (!this.containsValue(exercise.primaryMuscleIds, muscleId) && !this.containsValue(exercise.secondaryMuscleIds, muscleId)) {
      return false
    }
    if (requireEquipment && !this.hasSharedValue(exercise.equipmentIds, equipmentIds)) {
      return false
    }
    if (requireDifficulty && exercise.difficulty !== goal.level) {
      return false
    }
    return true
  }

  private scoreExercise(exercise: ExerciseContent, goal: UserGoal, muscleId: string, equipmentIds: string[]): number {
    let score: number = 0
    if (this.containsValue(exercise.goalTags, goal.goalType)) {
      score += 40
    }
    if (this.hasSharedValue(exercise.equipmentIds, equipmentIds)) {
      score += 30
    }
    if (this.containsValue(exercise.primaryMuscleIds, muscleId)) {
      score += 20
    } else if (this.containsValue(exercise.secondaryMuscleIds, muscleId)) {
      score += 10
    }
    if (exercise.difficulty === goal.level) {
      score += 8
    }
    if (exercise.alternativeExerciseIds.length > 0) {
      score += 2
    }
    return score
  }

  private sortScoredExercises(source: ScoredExercise[]): ScoredExercise[] {
    const values: ScoredExercise[] = []
    for (let index = 0; index < source.length; index++) {
      values.push(source[index])
    }

    values.sort((left: ScoredExercise, right: ScoredExercise): number => {
      if (left.score !== right.score) {
        return right.score - left.score
      }
      if (left.exercise.alternativeExerciseIds.length !== right.exercise.alternativeExerciseIds.length) {
        return right.exercise.alternativeExerciseIds.length - left.exercise.alternativeExerciseIds.length
      }
      if (left.exercise.exerciseId < right.exercise.exerciseId) {
        return -1
      }
      if (left.exercise.exerciseId > right.exercise.exerciseId) {
        return 1
      }
      return 0
    })
    return values
  }

  private normalizeEquipmentIds(equipmentIds: string[]): string[] {
    if (equipmentIds.length > 0) {
      return this.copyStringArray(equipmentIds)
    }
    const values: string[] = [BODYWEIGHT_EQUIPMENT_ID]
    return values
  }

  private containsRestrictedMuscle(exercise: ExerciseContent, restrictedMuscleIds: string[]): boolean {
    for (let index = 0; index < restrictedMuscleIds.length; index++) {
      const muscleId: string = restrictedMuscleIds[index]
      if (this.containsValue(exercise.primaryMuscleIds, muscleId) || this.containsValue(exercise.secondaryMuscleIds, muscleId)) {
        return true
      }
    }
    return false
  }

  private hasSharedValue(leftValues: string[], rightValues: string[]): boolean {
    for (let leftIndex = 0; leftIndex < leftValues.length; leftIndex++) {
      if (this.containsValue(rightValues, leftValues[leftIndex])) {
        return true
      }
    }
    return false
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
