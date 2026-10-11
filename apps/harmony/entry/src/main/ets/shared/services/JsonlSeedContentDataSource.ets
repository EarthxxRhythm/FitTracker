/**
 * JsonlSeedContentDataSource -- generated JSONL seed content adapter.
 *
 * Next-stage task #5: keeps JSONL as the seed source before database import.
 */
import { LOCAL_EQUIPMENT, LOCAL_EXERCISES, LOCAL_MUSCLES } from '../../generated/LocalExerciseContent'
import {
  EquipmentItem,
  ExerciseContent,
  MuscleGroup
} from '../models/TrainingModels'
import {
  ContentDataSource,
  ContentSourceInfo,
  createContentSourceInfo
} from './ContentDataSource'

export class JsonlSeedContentDataSource implements ContentDataSource {
  getSourceInfo(): ContentSourceInfo {
    return createContentSourceInfo('jsonl_seed', 'JSONL seed content', false, true)
  }

  getMuscles(): MuscleGroup[] {
    return LOCAL_MUSCLES
  }

  getEquipment(): EquipmentItem[] {
    return LOCAL_EQUIPMENT
  }

  getExercises(): ExerciseContent[] {
    return LOCAL_EXERCISES
  }
}
