/**
 * DatabaseContentDataSource -- local database content source adapter.
 *
 * Next-stage task #5: repository can switch from JSONL seed to imported local data.
 */
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

export class DatabaseContentDataSource implements ContentDataSource {
  private muscles: MuscleGroup[]
  private equipment: EquipmentItem[]
  private exercises: ExerciseContent[]

  constructor(muscles: MuscleGroup[], equipment: EquipmentItem[], exercises: ExerciseContent[]) {
    this.muscles = muscles
    this.equipment = equipment
    this.exercises = exercises
  }

  getSourceInfo(): ContentSourceInfo {
    return createContentSourceInfo('local_database', 'Local database content', true, true)
  }

  getMuscles(): MuscleGroup[] {
    return this.muscles
  }

  getEquipment(): EquipmentItem[] {
    return this.equipment
  }

  getExercises(): ExerciseContent[] {
    return this.exercises
  }
}
