/**
 * TrainingModels - shared target-loop data contracts.
 */

export interface UserGoal {
  goalId: string
  goalType: string
  level: string
  weeklyDays: number
  sessionMinutes: number
  equipmentIds: string[]
  restrictedMuscleIds: string[]
  createdAt: number
  updatedAt: number
}

export interface MuscleGroup {
  muscleId: string
  nameZh: string
  region: string
}

export interface EquipmentItem {
  equipmentId: string
  nameZh: string
}

export interface ExerciseContent {
  exerciseId: string
  nameZh: string
  nameEn: string
  aliases: string[]
  primaryMuscleIds: string[]
  secondaryMuscleIds: string[]
  equipmentIds: string[]
  difficulty: string
  goalTags: string[]
  videoUrl: string
  coverUrl: string
  steps: string[]
  cues: string[]
  commonMistakes: string[]
  safetyNotes: string[]
  alternativeExerciseIds: string[]
  contentVersion: number
}

export interface PlannedExercise {
  plannedExerciseId: string
  exerciseId: string
  targetSets: number
  targetReps: string
  intensityNote: string
  alternativeExerciseIds: string[]
}

export interface PlanDay {
  dayId: string
  dayOfWeek: number
  title: string
  focusMuscleIds: string[]
  exercises: PlannedExercise[]
}

export interface TrainingPlan {
  planId: string
  goalId: string
  name: string
  cycleWeeks: number
  days: PlanDay[]
  generatedBy: string
  status: string
}

export interface WorkoutSet {
  setId: string
  exerciseId: string
  weight: number
  reps: number
  rpe: number
  isWarmup: boolean
}

export interface WorkoutSession {
  sessionId: string
  planId: string
  dayId: string
  startedAt: number
  endedAt: number
  durationSeconds: number
  totalSets: number
  totalVolume: number
  fatigueScore: number
  notes: string
  sets: WorkoutSet[]
}

export interface ContentSyncStatus {
  localVersion: number
  remoteVersion: number
  lastCheckedAt: number
  status: string
}

export function createUserGoal(
  goalId: string,
  goalType: string,
  level: string,
  weeklyDays: number,
  sessionMinutes: number,
  equipmentIds: string[],
  restrictedMuscleIds: string[],
  createdAt: number,
  updatedAt: number
): UserGoal {
  const item: UserGoal = {
    goalId: goalId,
    goalType: goalType,
    level: level,
    weeklyDays: weeklyDays,
    sessionMinutes: sessionMinutes,
    equipmentIds: equipmentIds,
    restrictedMuscleIds: restrictedMuscleIds,
    createdAt: createdAt,
    updatedAt: updatedAt
  }
  return item
}

export function createMuscleGroup(muscleId: string, nameZh: string, region: string): MuscleGroup {
  const item: MuscleGroup = {
    muscleId: muscleId,
    nameZh: nameZh,
    region: region
  }
  return item
}

export function createEquipmentItem(equipmentId: string, nameZh: string): EquipmentItem {
  const item: EquipmentItem = {
    equipmentId: equipmentId,
    nameZh: nameZh
  }
  return item
}

export function createExerciseContent(
  exerciseId: string,
  nameZh: string,
  nameEn: string,
  aliases: string[],
  primaryMuscleIds: string[],
  secondaryMuscleIds: string[],
  equipmentIds: string[],
  difficulty: string,
  goalTags: string[],
  videoUrl: string,
  coverUrl: string,
  steps: string[],
  cues: string[],
  commonMistakes: string[],
  safetyNotes: string[],
  alternativeExerciseIds: string[],
  contentVersion: number
): ExerciseContent {
  const item: ExerciseContent = {
    exerciseId: exerciseId,
    nameZh: nameZh,
    nameEn: nameEn,
    aliases: aliases,
    primaryMuscleIds: primaryMuscleIds,
    secondaryMuscleIds: secondaryMuscleIds,
    equipmentIds: equipmentIds,
    difficulty: difficulty,
    goalTags: goalTags,
    videoUrl: videoUrl,
    coverUrl: coverUrl,
    steps: steps,
    cues: cues,
    commonMistakes: commonMistakes,
    safetyNotes: safetyNotes,
    alternativeExerciseIds: alternativeExerciseIds,
    contentVersion: contentVersion
  }
  return item
}

export function createPlannedExercise(
  plannedExerciseId: string,
  exerciseId: string,
  targetSets: number,
  targetReps: string,
  intensityNote: string,
  alternativeExerciseIds: string[]
): PlannedExercise {
  const item: PlannedExercise = {
    plannedExerciseId: plannedExerciseId,
    exerciseId: exerciseId,
    targetSets: targetSets,
    targetReps: targetReps,
    intensityNote: intensityNote,
    alternativeExerciseIds: alternativeExerciseIds
  }
  return item
}

export function createPlanDay(
  dayId: string,
  dayOfWeek: number,
  title: string,
  focusMuscleIds: string[],
  exercises: PlannedExercise[]
): PlanDay {
  const item: PlanDay = {
    dayId: dayId,
    dayOfWeek: dayOfWeek,
    title: title,
    focusMuscleIds: focusMuscleIds,
    exercises: exercises
  }
  return item
}

export function createTrainingPlan(
  planId: string,
  goalId: string,
  name: string,
  cycleWeeks: number,
  days: PlanDay[],
  generatedBy: string,
  status: string
): TrainingPlan {
  const item: TrainingPlan = {
    planId: planId,
    goalId: goalId,
    name: name,
    cycleWeeks: cycleWeeks,
    days: days,
    generatedBy: generatedBy,
    status: status
  }
  return item
}

export function createWorkoutSet(
  setId: string,
  exerciseId: string,
  weight: number,
  reps: number,
  rpe: number,
  isWarmup: boolean
): WorkoutSet {
  const item: WorkoutSet = {
    setId: setId,
    exerciseId: exerciseId,
    weight: weight,
    reps: reps,
    rpe: rpe,
    isWarmup: isWarmup
  }
  return item
}

export function createWorkoutSession(
  sessionId: string,
  planId: string,
  dayId: string,
  startedAt: number,
  endedAt: number,
  durationSeconds: number,
  totalSets: number,
  totalVolume: number,
  fatigueScore: number,
  notes: string,
  sets: WorkoutSet[]
): WorkoutSession {
  const item: WorkoutSession = {
    sessionId: sessionId,
    planId: planId,
    dayId: dayId,
    startedAt: startedAt,
    endedAt: endedAt,
    durationSeconds: durationSeconds,
    totalSets: totalSets,
    totalVolume: totalVolume,
    fatigueScore: fatigueScore,
    notes: notes,
    sets: sets
  }
  return item
}

export function createContentSyncStatus(
  localVersion: number,
  remoteVersion: number,
  lastCheckedAt: number,
  status: string
): ContentSyncStatus {
  const item: ContentSyncStatus = {
    localVersion: localVersion,
    remoteVersion: remoteVersion,
    lastCheckedAt: lastCheckedAt,
    status: status
  }
  return item
}

export function estimateOneRepMax(weight: number, reps: number): number {
  const raw = weight * (1 + reps / 30)
  return Math.round(raw * 100) / 100
}
