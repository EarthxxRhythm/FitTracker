/**
 * ContentRepository -- read-only access to generated local exercise content.
 *
 * Feature #14: JSONL-backed local exercise content.
 */
import { LOCAL_EQUIPMENT, LOCAL_EXERCISES, LOCAL_MUSCLES } from '../../generated/LocalExerciseContent'
import {
  EquipmentItem,
  ExerciseContent,
  MuscleGroup
} from '../models/TrainingModels'

export interface ExerciseLibraryItem {
  exerciseId: string
  name: string
  nameEn: string
  aliases: string[]
  primaryMuscleName: string
  equipmentText: string
  difficultyText: string
  difficulty: string
  goalTags: string[]
  primaryMuscleId: string
  equipmentIds: string[]
}

export interface ExerciseDetailViewModel {
  exerciseId: string
  name: string
  nameEn: string
  difficultyText: string
  primaryMuscleNames: string[]
  equipmentNames: string[]
  steps: string[]
  cues: string[]
  commonMistakes: string[]
  safetyNotes: string[]
  alternativeNames: string[]
  videoPlaceholder: string
}

function createExerciseLibraryItem(
  exerciseId: string,
  name: string,
  nameEn: string,
  aliases: string[],
  primaryMuscleName: string,
  equipmentText: string,
  difficultyText: string,
  difficulty: string,
  goalTags: string[],
  primaryMuscleId: string,
  equipmentIds: string[]
): ExerciseLibraryItem {
  const item: ExerciseLibraryItem = {
    exerciseId: exerciseId,
    name: name,
    nameEn: nameEn,
    aliases: aliases,
    primaryMuscleName: primaryMuscleName,
    equipmentText: equipmentText,
    difficultyText: difficultyText,
    difficulty: difficulty,
    goalTags: goalTags,
    primaryMuscleId: primaryMuscleId,
    equipmentIds: equipmentIds
  }
  return item
}

function createExerciseDetailViewModel(
  exerciseId: string,
  name: string,
  nameEn: string,
  difficultyText: string,
  primaryMuscleNames: string[],
  equipmentNames: string[],
  steps: string[],
  cues: string[],
  commonMistakes: string[],
  safetyNotes: string[],
  alternativeNames: string[],
  videoPlaceholder: string
): ExerciseDetailViewModel {
  const item: ExerciseDetailViewModel = {
    exerciseId: exerciseId,
    name: name,
    nameEn: nameEn,
    difficultyText: difficultyText,
    primaryMuscleNames: primaryMuscleNames,
    equipmentNames: equipmentNames,
    steps: steps,
    cues: cues,
    commonMistakes: commonMistakes,
    safetyNotes: safetyNotes,
    alternativeNames: alternativeNames,
    videoPlaceholder: videoPlaceholder
  }
  return item
}

class ContentRepositoryImpl {
  getMuscles(): MuscleGroup[] {
    const muscles: MuscleGroup[] = []
    for (let index = 0; index < LOCAL_MUSCLES.length; index++) {
      muscles.push(this.copyMuscleGroup(LOCAL_MUSCLES[index]))
    }
    return muscles
  }

  getEquipment(): EquipmentItem[] {
    const equipmentItems: EquipmentItem[] = []
    for (let index = 0; index < LOCAL_EQUIPMENT.length; index++) {
      equipmentItems.push(this.copyEquipmentItem(LOCAL_EQUIPMENT[index]))
    }
    return equipmentItems
  }

  getExercises(): ExerciseContent[] {
    const exercises: ExerciseContent[] = []
    for (let index = 0; index < LOCAL_EXERCISES.length; index++) {
      exercises.push(this.copyExerciseContent(LOCAL_EXERCISES[index]))
    }
    return exercises
  }

  getExerciseLibraryItems(): ExerciseLibraryItem[] {
    const items: ExerciseLibraryItem[] = []
    for (let index = 0; index < LOCAL_EXERCISES.length; index++) {
      const exercise: ExerciseContent = LOCAL_EXERCISES[index]
      items.push(createExerciseLibraryItem(
        exercise.exerciseId,
        exercise.nameZh,
        exercise.nameEn,
        this.copyStringArray(exercise.aliases),
        this.getPrimaryMuscleName(exercise),
        this.getEquipmentText(exercise.equipmentIds),
        this.getDifficultyText(exercise.difficulty),
        exercise.difficulty,
        this.copyStringArray(exercise.goalTags),
        this.getPrimaryMuscleId(exercise),
        this.copyStringArray(exercise.equipmentIds)
      ))
    }
    return items
  }

  filterExerciseLibraryItems(
    goalTag: string,
    equipmentId: string,
    muscleId: string,
    difficulty: string
  ): ExerciseLibraryItem[] {
    const items: ExerciseLibraryItem[] = []
    for (let index = 0; index < LOCAL_EXERCISES.length; index++) {
      const exercise: ExerciseContent = LOCAL_EXERCISES[index]
      if (this.matchesLibraryFilter(exercise, goalTag, equipmentId, muscleId, difficulty)) {
        items.push(createExerciseLibraryItem(
          exercise.exerciseId,
          exercise.nameZh,
          exercise.nameEn,
          this.copyStringArray(exercise.aliases),
          this.getPrimaryMuscleName(exercise),
          this.getEquipmentText(exercise.equipmentIds),
          this.getDifficultyText(exercise.difficulty),
          exercise.difficulty,
          this.copyStringArray(exercise.goalTags),
          this.getPrimaryMuscleId(exercise),
          this.copyStringArray(exercise.equipmentIds)
        ))
      }
    }
    return items
  }

  getExerciseById(exerciseId: string): ExerciseContent | undefined {
    for (let index = 0; index < LOCAL_EXERCISES.length; index++) {
      const exercise: ExerciseContent = LOCAL_EXERCISES[index]
      if (exercise.exerciseId === exerciseId) {
        return this.copyExerciseContent(exercise)
      }
    }
    return undefined
  }

  getExerciseDetailViewModel(exerciseId: string): ExerciseDetailViewModel | undefined {
    const exercise: ExerciseContent | undefined = this.findLocalExerciseById(exerciseId)
    if (exercise === undefined) {
      return undefined
    }
    return createExerciseDetailViewModel(
      exercise.exerciseId,
      exercise.nameZh,
      exercise.nameEn,
      this.getDifficultyText(exercise.difficulty),
      this.getMuscleNames(exercise.primaryMuscleIds),
      this.getEquipmentNames(exercise.equipmentIds),
      this.copyStringArray(exercise.steps),
      this.copyStringArray(exercise.cues),
      this.copyStringArray(exercise.commonMistakes),
      this.copyStringArray(exercise.safetyNotes),
      this.getAlternativeExerciseNames(exercise.alternativeExerciseIds),
      this.getVideoPlaceholder(exercise)
    )
  }

  getMuscleName(muscleId: string): string {
    for (let index = 0; index < LOCAL_MUSCLES.length; index++) {
      const muscle: MuscleGroup = LOCAL_MUSCLES[index]
      if (muscle.muscleId === muscleId) {
        return muscle.nameZh
      }
    }
    return muscleId
  }

  getEquipmentName(equipmentId: string): string {
    for (let index = 0; index < LOCAL_EQUIPMENT.length; index++) {
      const equipment: EquipmentItem = LOCAL_EQUIPMENT[index]
      if (equipment.equipmentId === equipmentId) {
        return equipment.nameZh
      }
    }
    return equipmentId
  }

  hasVideoAsset(exercise: ExerciseContent): boolean {
    return exercise.videoUrl.trim().length > 0
  }

  getExercisesByMuscle(muscleId: string): ExerciseContent[] {
    const exercises: ExerciseContent[] = []
    for (let index = 0; index < LOCAL_EXERCISES.length; index++) {
      const exercise: ExerciseContent = LOCAL_EXERCISES[index]
      if (this.containsValue(exercise.primaryMuscleIds, muscleId) || this.containsValue(exercise.secondaryMuscleIds, muscleId)) {
        exercises.push(this.copyExerciseContent(exercise))
      }
    }
    return exercises
  }

  getExercisesByEquipment(equipmentId: string): ExerciseContent[] {
    const exercises: ExerciseContent[] = []
    for (let index = 0; index < LOCAL_EXERCISES.length; index++) {
      const exercise: ExerciseContent = LOCAL_EXERCISES[index]
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

    for (let index = 0; index < LOCAL_EXERCISES.length; index++) {
      const exercise: ExerciseContent = LOCAL_EXERCISES[index]
      if (this.matchesExercise(exercise, normalizedQuery)) {
        exercises.push(this.copyExerciseContent(exercise))
      }
    }
    return exercises
  }

  getAlternativeExercises(exerciseId: string): ExerciseContent[] {
    const exercise: ExerciseContent | undefined = this.findLocalExerciseById(exerciseId)
    const alternatives: ExerciseContent[] = []
    if (exercise === undefined) {
      return alternatives
    }

    for (let index = 0; index < exercise.alternativeExerciseIds.length; index++) {
      const alternativeExerciseId: string = exercise.alternativeExerciseIds[index]
      const alternative: ExerciseContent | undefined = this.findLocalExerciseById(alternativeExerciseId)
      if (alternative !== undefined) {
        alternatives.push(this.copyExerciseContent(alternative))
      }
    }
    return alternatives
  }

  getCandidateExercises(
    goalType: string,
    level: string,
    equipmentIds: string[],
    muscleId: string,
    restrictedMuscleIds: string[]
  ): ExerciseContent[] {
    const candidates: ExerciseContent[] = []
    for (let index = 0; index < LOCAL_EXERCISES.length; index++) {
      const exercise: ExerciseContent = LOCAL_EXERCISES[index]
      if (this.matchesCandidate(exercise, goalType, level, equipmentIds, muscleId, restrictedMuscleIds)) {
        candidates.push(this.copyExerciseContent(exercise))
      }
    }
    return candidates
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

  private findLocalExerciseById(exerciseId: string): ExerciseContent | undefined {
    for (let index = 0; index < LOCAL_EXERCISES.length; index++) {
      const exercise: ExerciseContent = LOCAL_EXERCISES[index]
      if (exercise.exerciseId === exerciseId) {
        return exercise
      }
    }
    return undefined
  }

  private matchesCandidate(
    exercise: ExerciseContent,
    goalType: string,
    level: string,
    equipmentIds: string[],
    muscleId: string,
    restrictedMuscleIds: string[]
  ): boolean {
    if (!this.containsValue(exercise.goalTags, goalType)) {
      return false
    }
    if (!this.matchesDifficulty(level, exercise.difficulty)) {
      return false
    }
    if (!this.containsValue(exercise.primaryMuscleIds, muscleId) && !this.containsValue(exercise.secondaryMuscleIds, muscleId)) {
      return false
    }
    if (!this.matchesEquipment(equipmentIds, exercise.equipmentIds)) {
      return false
    }
    if (this.hasRestrictedMuscle(exercise, restrictedMuscleIds)) {
      return false
    }
    return true
  }

  private matchesDifficulty(level: string, difficulty: string): boolean {
    if (level === 'advanced') {
      return true
    }
    if (level === 'intermediate') {
      return difficulty === 'beginner' || difficulty === 'intermediate'
    }
    return difficulty === 'beginner'
  }

  private matchesEquipment(allowedEquipmentIds: string[], exerciseEquipmentIds: string[]): boolean {
    if (allowedEquipmentIds.length === 0) {
      return this.containsValue(exerciseEquipmentIds, 'eq_bodyweight')
    }
    for (let index = 0; index < exerciseEquipmentIds.length; index++) {
      if (this.containsValue(allowedEquipmentIds, exerciseEquipmentIds[index])) {
        return true
      }
    }
    return false
  }

  private matchesLibraryFilter(
    exercise: ExerciseContent,
    goalTag: string,
    equipmentId: string,
    muscleId: string,
    difficulty: string
  ): boolean {
    if (goalTag.length > 0 && !this.containsValue(exercise.goalTags, goalTag)) {
      return false
    }
    if (equipmentId.length > 0 && !this.containsValue(exercise.equipmentIds, equipmentId)) {
      return false
    }
    if (muscleId.length > 0 && !this.containsValue(exercise.primaryMuscleIds, muscleId) &&
      !this.containsValue(exercise.secondaryMuscleIds, muscleId)) {
      return false
    }
    if (difficulty.length > 0 && exercise.difficulty !== difficulty) {
      return false
    }
    return true
  }

  private hasRestrictedMuscle(exercise: ExerciseContent, restrictedMuscleIds: string[]): boolean {
    for (let index = 0; index < exercise.primaryMuscleIds.length; index++) {
      if (this.containsValue(restrictedMuscleIds, exercise.primaryMuscleIds[index])) {
        return true
      }
    }
    for (let index = 0; index < exercise.secondaryMuscleIds.length; index++) {
      if (this.containsValue(restrictedMuscleIds, exercise.secondaryMuscleIds[index])) {
        return true
      }
    }
    return false
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

  private getPrimaryMuscleId(exercise: ExerciseContent): string {
    if (exercise.primaryMuscleIds.length === 0) {
      return ''
    }
    return exercise.primaryMuscleIds[0]
  }

  private getPrimaryMuscleName(exercise: ExerciseContent): string {
    const muscleId: string = this.getPrimaryMuscleId(exercise)
    if (muscleId.length === 0) {
      return '未分类'
    }
    return this.getMuscleName(muscleId)
  }

  private getEquipmentText(equipmentIds: string[]): string {
    if (equipmentIds.length === 0) {
      return '无器械'
    }
    let text: string = ''
    for (let index = 0; index < equipmentIds.length; index++) {
      if (index > 0) {
        text += ' / '
      }
      text += this.getEquipmentName(equipmentIds[index])
    }
    return text
  }

  private getMuscleNames(muscleIds: string[]): string[] {
    const names: string[] = []
    for (let index = 0; index < muscleIds.length; index++) {
      names.push(this.getMuscleName(muscleIds[index]))
    }
    return names
  }

  private getEquipmentNames(equipmentIds: string[]): string[] {
    const names: string[] = []
    for (let index = 0; index < equipmentIds.length; index++) {
      names.push(this.getEquipmentName(equipmentIds[index]))
    }
    return names
  }

  private getAlternativeExerciseNames(exerciseIds: string[]): string[] {
    const names: string[] = []
    for (let index = 0; index < exerciseIds.length; index++) {
      const exercise: ExerciseContent | undefined = this.findLocalExerciseById(exerciseIds[index])
      if (exercise !== undefined) {
        names.push(exercise.nameZh)
      }
    }
    return names
  }

  private getVideoPlaceholder(exercise: ExerciseContent): string {
    if (this.hasVideoAsset(exercise)) {
      return '视频占位：本地动作库已有视频素材'
    }
    return '视频占位：本地动作库暂未接入视频素材'
  }

  private getDifficultyText(difficulty: string): string {
    if (difficulty === 'beginner') {
      return '入门'
    }
    if (difficulty === 'intermediate') {
      return '进阶'
    }
    if (difficulty === 'advanced') {
      return '高级'
    }
    return difficulty
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
