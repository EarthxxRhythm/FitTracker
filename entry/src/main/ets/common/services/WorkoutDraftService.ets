/**
 * WorkoutDraftService - unfinished workout draft persistence service.
 *
 * Function #40: persist in-progress workouts and restore them on re-entry.
 */
import { preferences } from '@kit.ArkData'

export interface WorkoutSetDraft {
  setIndex: number
  weightText: string
  repsText: string
  estimatedOneRepMax: number
  oneRepMaxText: string
  isComplete: boolean
}

export interface WorkoutExerciseDraft {
  exerciseId: string
  name: string
  targetMuscle: string
  targetSets: number
  targetReps: string
  completedSets: number
  sets: WorkoutSetDraft[]
}

export interface WorkoutDraftSnapshot {
  planId: string
  planName: string
  dayLabel: string
  startedAt: number
  totalTargetSets: number
  completedSets: number
  currentExerciseName: string
  currentExerciseProgress: string
  exercises: WorkoutExerciseDraft[]
  updatedAt: number
}

const STORE_NAME = 'fit_tracker_active_workout'
const KEY_WORKOUT_DRAFT = 'workout_draft'

export function copyWorkoutSetDraft(source: WorkoutSetDraft): WorkoutSetDraft {
  const draft: WorkoutSetDraft = {
    setIndex: source.setIndex,
    weightText: source.weightText,
    repsText: source.repsText,
    estimatedOneRepMax: source.estimatedOneRepMax,
    oneRepMaxText: source.oneRepMaxText,
    isComplete: source.isComplete
  }
  return draft
}

export function copyWorkoutExerciseDraft(source: WorkoutExerciseDraft): WorkoutExerciseDraft {
  const sets: WorkoutSetDraft[] = []
  for (let index = 0; index < source.sets.length; index++) {
    sets.push(copyWorkoutSetDraft(source.sets[index]))
  }
  const draft: WorkoutExerciseDraft = {
    exerciseId: source.exerciseId,
    name: source.name,
    targetMuscle: source.targetMuscle,
    targetSets: source.targetSets,
    targetReps: source.targetReps,
    completedSets: source.completedSets,
    sets: sets
  }
  return draft
}

export function copyWorkoutDraftSnapshot(source: WorkoutDraftSnapshot): WorkoutDraftSnapshot {
  const exercises: WorkoutExerciseDraft[] = []
  for (let index = 0; index < source.exercises.length; index++) {
    exercises.push(copyWorkoutExerciseDraft(source.exercises[index]))
  }
  const snapshot: WorkoutDraftSnapshot = {
    planId: source.planId,
    planName: source.planName,
    dayLabel: source.dayLabel,
    startedAt: source.startedAt,
    totalTargetSets: source.totalTargetSets,
    completedSets: source.completedSets,
    currentExerciseName: source.currentExerciseName,
    currentExerciseProgress: source.currentExerciseProgress,
    exercises: exercises,
    updatedAt: source.updatedAt
  }
  return snapshot
}

export function hasWorkoutDraftProgress(source: WorkoutDraftSnapshot): boolean {
  if (source.completedSets > 0) {
    return true
  }
  for (let exerciseIndex = 0; exerciseIndex < source.exercises.length; exerciseIndex++) {
    const exercise: WorkoutExerciseDraft = source.exercises[exerciseIndex]
    for (let setIndex = 0; setIndex < exercise.sets.length; setIndex++) {
      const setDraft: WorkoutSetDraft = exercise.sets[setIndex]
      if (setDraft.isComplete || setDraft.weightText.length > 0 || setDraft.repsText.length > 0) {
        return true
      }
    }
  }
  return false
}

export function createEmptyWorkoutDraftSnapshot(now: number): WorkoutDraftSnapshot {
  const snapshot: WorkoutDraftSnapshot = {
    planId: '',
    planName: '',
    dayLabel: '',
    startedAt: now,
    totalTargetSets: 0,
    completedSets: 0,
    currentExerciseName: '',
    currentExerciseProgress: '0/0',
    exercises: [],
    updatedAt: now
  }
  return snapshot
}

export function isValidWorkoutDraftSnapshot(source: WorkoutDraftSnapshot): boolean {
  if (!isStringValue(source.planId) || !isStringValue(source.planName) || !isStringValue(source.dayLabel)) {
    return false
  }
  if (!isFiniteNumberValue(source.startedAt) || !isFiniteNumberValue(source.totalTargetSets) ||
    !isFiniteNumberValue(source.completedSets) || !isStringValue(source.currentExerciseName) ||
    !isStringValue(source.currentExerciseProgress) || !isFiniteNumberValue(source.updatedAt)) {
    return false
  }
  if (!Array.isArray(source.exercises)) {
    return false
  }
  for (let index = 0; index < source.exercises.length; index++) {
    if (!isValidWorkoutExerciseDraft(source.exercises[index])) {
      return false
    }
  }
  return true
}

function isValidWorkoutExerciseDraft(source: WorkoutExerciseDraft): boolean {
  if (!isStringValue(source.exerciseId) || !isStringValue(source.name) || !isStringValue(source.targetMuscle)) {
    return false
  }
  if (!isFiniteNumberValue(source.targetSets) || !isStringValue(source.targetReps) ||
    !isFiniteNumberValue(source.completedSets) || !Array.isArray(source.sets)) {
    return false
  }
  for (let index = 0; index < source.sets.length; index++) {
    if (!isValidWorkoutSetDraft(source.sets[index])) {
      return false
    }
  }
  return true
}

function isValidWorkoutSetDraft(source: WorkoutSetDraft): boolean {
  if (!isFiniteNumberValue(source.setIndex) || !isStringValue(source.weightText) ||
    !isStringValue(source.repsText) || !isFiniteNumberValue(source.estimatedOneRepMax) ||
    !isStringValue(source.oneRepMaxText) || !isBooleanValue(source.isComplete)) {
    return false
  }
  return true
}

function isStringValue(value: string): boolean {
  if (value === null || value === undefined) {
    return false
  }
  return value.toString() === value
}

function isFiniteNumberValue(value: number): boolean {
  return Number.isFinite(value)
}

function isBooleanValue(value: boolean): boolean {
  return value === true || value === false
}

class WorkoutDraftService {
  async saveDraft(context: Context, snapshot: WorkoutDraftSnapshot): Promise<void> {
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      await prefs.put(KEY_WORKOUT_DRAFT, JSON.stringify(copyWorkoutDraftSnapshot(snapshot)))
      await prefs.flush()
    } catch (e) {
      // Keep the in-progress workout usable in memory even if persistence fails.
    }
  }

  async getDraft(context: Context): Promise<WorkoutDraftSnapshot | null> {
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      const json = await prefs.get(KEY_WORKOUT_DRAFT, '') as string
      return this.parseDraft(json)
    } catch (e) {
      return null
    }
  }

  async clearDraft(context: Context): Promise<void> {
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      await prefs.put(KEY_WORKOUT_DRAFT, '')
      await prefs.flush()
    } catch (e) {
      // Keep the previous draft untouched when clearing fails.
    }
  }

  private parseDraft(json: string): WorkoutDraftSnapshot | null {
    if (json.length === 0) {
      return null
    }
    try {
      const parsed = JSON.parse(json) as WorkoutDraftSnapshot
      if (!isValidWorkoutDraftSnapshot(parsed)) {
        return null
      }
      return copyWorkoutDraftSnapshot(parsed)
    } catch (e) {
      return null
    }
  }
}

export default new WorkoutDraftService()
