/**
 * SeedMuscles -- local muscle seed content for target-loop planning.
 *
 * Feature #2: seed content and content repository.
 */
import { MuscleGroup, createMuscleGroup } from '../shared/models/TrainingModels'

export const SEED_MUSCLES: MuscleGroup[] = [
  createMuscleGroup('muscle_chest', '胸部', 'upper'),
  createMuscleGroup('muscle_back', '背部', 'upper'),
  createMuscleGroup('muscle_legs', '腿部', 'lower'),
  createMuscleGroup('muscle_shoulders', '肩部', 'upper'),
  createMuscleGroup('muscle_arms', '手臂', 'upper'),
  createMuscleGroup('muscle_core', '核心', 'trunk')
]
