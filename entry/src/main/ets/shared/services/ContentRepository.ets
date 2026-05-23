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
    const muscles: MuscleGroup[] = []
    for (let index = 0; index < SEED_MUSCLES.length; index++) {
      muscles.push(this.copyMuscleGroup(SEED_MUSCLES[index]))
    }
    return muscles
  }

  getEquipment(): EquipmentItem[] {
    const equipmentItems: EquipmentItem[] = []
    for (let index = 0; index < SEED_EQUIPMENT.length; index++) {
      equipmentItems.push(this.copyEquipmentItem(SEED_EQUIPMENT[index]))
    }
    return equipmentItems
  }

  getExercises(): ExerciseContent[] {
    const exercises: ExerciseContent[] = []
    for (let index = 0; index < SEED_EXERCISES.length; index++) {
      exercises.push(this.copyExerciseContent(SEED_EXERCISES[index]))
    }
    return exercises
  }

  getExerciseById(exerciseId: string): ExerciseContent | undefined {
    for (let index = 0; index < SEED_EXERCISES.length; index++) {
      const exercise: ExerciseContent = SEED_EXERCISES[index]
      if (exercise.exerciseId === exerciseId) {
        return this.copyExerciseContent(exercise)
      }
    }
    return undefined
  }

  getExercisesByMuscle(muscleId: string): ExerciseContent[] {
    const exercises: ExerciseContent[] = []
    for (let index = 0; index < SEED_EXERCISES.length; index++) {
      const exercise: ExerciseContent = SEED_EXERCISES[index]
      if (this.containsValue(exercise.primaryMuscleIds, muscleId) || this.containsValue(exercise.secondaryMuscleIds, muscleId)) {
        exercises.push(this.copyExerciseContent(exercise))
      }
    }
    return exercises
  }

  getExercisesByEquipment(equipmentId: string): ExerciseContent[] {
    const exercises: ExerciseContent[] = []
    for (let index = 0; index < SEED_EXERCISES.length; index++) {
      const exercise: ExerciseContent = SEED_EXERCISES[index]
      if (this.containsValue(exercise.equipmentIds, equipmentId)) {
        exercises.push(this.copyExerciseContent(exercise))
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
        exercises.push(this.copyExerciseContent(exercise))
      }
    }
    return exercises
  }

  getAlternativeExercises(exerciseId: string): ExerciseContent[] {
    const exercise: ExerciseContent | undefined = this.findSeedExerciseById(exerciseId)
    const alternatives: ExerciseContent[] = []
    if (exercise === undefined) {
      return alternatives
    }

    for (let index = 0; index < exercise.alternativeExerciseIds.length; index++) {
      const alternativeExerciseId: string = exercise.alternativeExerciseIds[index]
      const alternative: ExerciseContent | undefined = this.findSeedExerciseById(alternativeExerciseId)
      if (alternative !== undefined) {
        alternatives.push(this.copyExerciseContent(alternative))
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

  private findSeedExerciseById(exerciseId: string): ExerciseContent | undefined {
    for (let index = 0; index < SEED_EXERCISES.length; index++) {
      const exercise: ExerciseContent = SEED_EXERCISES[index]
      if (exercise.exerciseId === exerciseId) {
        return exercise
      }
    }
    return undefined
  }

  private copyMuscleGroup(source: MuscleGroup): MuscleGroup {
    const item: MuscleGroup = {
      muscleId: source.muscleId,
      nameZh: source.nameZh,
      region: source.region
    }
    return item
  }

  private copyEquipmentItem(source: EquipmentItem): EquipmentItem {
    const item: EquipmentItem = {
      equipmentId: source.equipmentId,
      nameZh: source.nameZh
    }
    return item
  }

  private copyExerciseContent(source: ExerciseContent): ExerciseContent {
    const item: ExerciseContent = {
      exerciseId: source.exerciseId,
      nameZh: source.nameZh,
      nameEn: source.nameEn,
      aliases: this.copyStringArray(source.aliases),
      primaryMuscleIds: this.copyStringArray(source.primaryMuscleIds),
      secondaryMuscleIds: this.copyStringArray(source.secondaryMuscleIds),
      equipmentIds: this.copyStringArray(source.equipmentIds),
      difficulty: source.difficulty,
      goalTags: this.copyStringArray(source.goalTags),
      videoUrl: source.videoUrl,
      coverUrl: source.coverUrl,
      steps: this.copyStringArray(source.steps),
      cues: this.copyStringArray(source.cues),
      commonMistakes: this.copyStringArray(source.commonMistakes),
      safetyNotes: this.copyStringArray(source.safetyNotes),
      alternativeExerciseIds: this.copyStringArray(source.alternativeExerciseIds),
      contentVersion: source.contentVersion
    }
    return item
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

export default new ContentRepositoryImpl()
