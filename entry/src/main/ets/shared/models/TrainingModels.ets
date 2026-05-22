/**
 * TrainingModels -- shared data contracts for training features.
 *
 * Feature #1: clean ArkUI target loop skeleton.
 */

export interface UserGoal {
  id: string
  name: string
  description: string
  weeklyTarget: number
}

export interface MuscleGroup {
  id: string
  name: string
  sortOrder: number
}

export interface EquipmentItem {
  id: string
  name: string
  sortOrder: number
}

export interface ExerciseContent {
  id: string
  name: string
  description: string
  primaryMuscleGroupId: string
  equipmentItemId: string
}

export interface PlannedExercise {
  id: string
  exerciseContentId: string
  targetSets: number
  targetReps: string
  sortOrder: number
}

export interface PlanDay {
  id: string
  name: string
  dayOfWeek: number
  exercises: PlannedExercise[]
}

export interface TrainingPlan {
  id: string
  name: string
  goalId: string
  days: PlanDay[]
  createdAt: number
}

export interface WorkoutSet {
  id: string
  exerciseContentId: string
  weight: number
  reps: number
  setIndex: number
}

export interface WorkoutSession {
  id: string
  planId: string
  startedAt: number
  finishedAt: number
  sets: WorkoutSet[]
}

export interface ContentSyncStatus {
  id: string
  lastSyncedAt: number
  version: string
  isDirty: boolean
}

export function createUserGoal(id: string, name: string, description: string, weeklyTarget: number): UserGoal {
  const goal: UserGoal = {
    id: id,
    name: name,
    description: description,
    weeklyTarget: weeklyTarget
  }
  return goal
}

export function createMuscleGroup(id: string, name: string, sortOrder: number): MuscleGroup {
  const muscleGroup: MuscleGroup = {
    id: id,
    name: name,
    sortOrder: sortOrder
  }
  return muscleGroup
}

export function createEquipmentItem(id: string, name: string, sortOrder: number): EquipmentItem {
  const equipmentItem: EquipmentItem = {
    id: id,
    name: name,
    sortOrder: sortOrder
  }
  return equipmentItem
}

export function createExerciseContent(
  id: string,
  name: string,
  description: string,
  primaryMuscleGroupId: string,
  equipmentItemId: string
): ExerciseContent {
  const exerciseContent: ExerciseContent = {
    id: id,
    name: name,
    description: description,
    primaryMuscleGroupId: primaryMuscleGroupId,
    equipmentItemId: equipmentItemId
  }
  return exerciseContent
}

export function createPlannedExercise(
  id: string,
  exerciseContentId: string,
  targetSets: number,
  targetReps: string,
  sortOrder: number
): PlannedExercise {
  const plannedExercise: PlannedExercise = {
    id: id,
    exerciseContentId: exerciseContentId,
    targetSets: targetSets,
    targetReps: targetReps,
    sortOrder: sortOrder
  }
  return plannedExercise
}

export function createPlanDay(
  id: string,
  name: string,
  dayOfWeek: number,
  exercises: PlannedExercise[]
): PlanDay {
  const copiedExercises: PlannedExercise[] = exercises.slice()
  const planDay: PlanDay = {
    id: id,
    name: name,
    dayOfWeek: dayOfWeek,
    exercises: copiedExercises
  }
  return planDay
}

export function createTrainingPlan(
  id: string,
  name: string,
  goalId: string,
  days: PlanDay[],
  createdAt: number
): TrainingPlan {
  const copiedDays: PlanDay[] = days.slice()
  const trainingPlan: TrainingPlan = {
    id: id,
    name: name,
    goalId: goalId,
    days: copiedDays,
    createdAt: createdAt
  }
  return trainingPlan
}

export function createWorkoutSet(
  id: string,
  exerciseContentId: string,
  weight: number,
  reps: number,
  setIndex: number
): WorkoutSet {
  const workoutSet: WorkoutSet = {
    id: id,
    exerciseContentId: exerciseContentId,
    weight: weight,
    reps: reps,
    setIndex: setIndex
  }
  return workoutSet
}

export function createWorkoutSession(
  id: string,
  planId: string,
  startedAt: number,
  finishedAt: number,
  sets: WorkoutSet[]
): WorkoutSession {
  const copiedSets: WorkoutSet[] = sets.slice()
  const workoutSession: WorkoutSession = {
    id: id,
    planId: planId,
    startedAt: startedAt,
    finishedAt: finishedAt,
    sets: copiedSets
  }
  return workoutSession
}

export function createContentSyncStatus(
  id: string,
  lastSyncedAt: number,
  version: string,
  isDirty: boolean
): ContentSyncStatus {
  const status: ContentSyncStatus = {
    id: id,
    lastSyncedAt: lastSyncedAt,
    version: version,
    isDirty: isDirty
  }
  return status
}

export function estimateOneRepMax(weight: number, reps: number): number {
  const rawEstimate = weight * (1 + reps / 30)
  return Math.round(rawEstimate * 100) / 100
}
