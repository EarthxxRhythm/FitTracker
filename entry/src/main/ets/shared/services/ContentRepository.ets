/**
 * ContentRepository -- read-only access to local seed content.
 *
 * Feature #2: seed content and content repository.
 */
import { SEED_EQUIPMENT } from '../../mock/SeedEquipment'
import { SEED_EXERCISES } from '../../mock/SeedExercises'
import { SEED_MUSCLES } from '../../mock/SeedMuscles'
import { EquipmentItem, ExerciseContent, MuscleGroup } from '../models/TrainingModels'

class ContentRepositoryImpl {
  getMuscles(): MuscleGroup[] {
    return SEED_MUSCLES
  }

  getEquipment(): EquipmentItem[] {
    return SEED_EQUIPMENT
  }

  getExercises(): ExerciseContent[] {
    return SEED_EXERCISES
  }

  getExerciseById(exerciseId: string): ExerciseContent | undefined {
    for (let index = 0; index < SEED_EXERCISES.length; index++) {
      const exercise: ExerciseContent = SEED_EXERCISES[index]
      if (exercise.exerciseId === exerciseId) {
        return exercise
      }
    }
    return undefined
  }

  getExercisesByMuscle(muscleId: string): ExerciseContent[] {
    const exercises: ExerciseContent[] = []
    for (let index = 0; index < SEED_EXERCISES.length; index++) {
      const exercise: ExerciseContent = SEED_EXERCISES[index]
      if (this.containsValue(exercise.primaryMuscleIds, muscleId) || this.containsValue(exercise.secondaryMuscleIds, muscleId)) {
        exercises.push(exercise)
      }
    }
    return exercises
  }

  getExercisesByEquipment(equipmentId: string): ExerciseContent[] {
    const exercises: ExerciseContent[] = []
    for (let index = 0; index < SEED_EXERCISES.length; index++) {
      const exercise: ExerciseContent = SEED_EXERCISES[index]
      if (this.containsValue(exercise.equipmentIds, equipmentId)) {
        exercises.push(exercise)
      }
    }
    return exercises
  }

  searchExercises(query: string): ExerciseContent[] {
    const normalizedQuery: string = query.trim().toLowerCase()
    const exercises: ExerciseContent[] = []
    if (normalizedQuery.length === 0) {
      return exercises
    }

    for (let index = 0; index < SEED_EXERCISES.length; index++) {
      const exercise: ExerciseContent = SEED_EXERCISES[index]
      if (this.matchesExercise(exercise, normalizedQuery)) {
        exercises.push(exercise)
      }
    }
    return exercises
  }

  getAlternativeExercises(exerciseId: string): ExerciseContent[] {
    const exercise: ExerciseContent | undefined = this.getExerciseById(exerciseId)
    const alternatives: ExerciseContent[] = []
    if (exercise === undefined) {
      return alternatives
    }

    for (let index = 0; index < exercise.alternativeExerciseIds.length; index++) {
      const alternativeExerciseId: string = exercise.alternativeExerciseIds[index]
      const alternative: ExerciseContent | undefined = this.getExerciseById(alternativeExerciseId)
      if (alternative !== undefined) {
        alternatives.push(alternative)
      }
    }
    return alternatives
  }

  getLocalContentVersion(): number {
    return 1
  }

  private matchesExercise(exercise: ExerciseContent, normalizedQuery: string): boolean {
    if (exercise.exerciseId.toLowerCase().indexOf(normalizedQuery) >= 0) {
      return true
    }
    if (exercise.nameZh.toLowerCase().indexOf(normalizedQuery) >= 0) {
      return true
    }
    if (exercise.nameEn.toLowerCase().indexOf(normalizedQuery) >= 0) {
      return true
    }
    for (let index = 0; index < exercise.aliases.length; index++) {
      const aliasText: string = exercise.aliases[index]
      if (aliasText.toLowerCase().indexOf(normalizedQuery) >= 0) {
        return true
      }
    }
    return false
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

export default new ContentRepositoryImpl()
