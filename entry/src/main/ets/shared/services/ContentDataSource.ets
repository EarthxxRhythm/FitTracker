/**
 * ContentDataSource -- adapter contract for local exercise content sources.
 *
 * Next-stage task #5: JSONL seed today, local database source later.
 */
import {
  EquipmentItem,
  ExerciseContent,
  MuscleGroup
} from '../models/TrainingModels'

export interface ContentSourceInfo {
  sourceId: string
  sourceName: string
  databaseBacked: boolean
  buildValidationRequired: boolean
}

export interface ContentDataSource {
  getSourceInfo(): ContentSourceInfo
  getMuscles(): MuscleGroup[]
  getEquipment(): EquipmentItem[]
  getExercises(): ExerciseContent[]
}

export function createContentSourceInfo(
  sourceId: string,
  sourceName: string,
  databaseBacked: boolean,
  buildValidationRequired: boolean
): ContentSourceInfo {
  const item: ContentSourceInfo = {
    sourceId: sourceId,
    sourceName: sourceName,
    databaseBacked: databaseBacked,
    buildValidationRequired: buildValidationRequired
  }
  return item
}
