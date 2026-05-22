/**
 * SeedMuscles -- local muscle seed content for target-loop planning.
 *
 * Feature #2: seed content and content repository.
 */
import { MuscleGroup, createMuscleGroup } from '../shared/models/TrainingModels'

export const SEED_MUSCLES: MuscleGroup[] = [
  createMuscleGroup('muscle_chest', 'Chest', 'upper'),
  createMuscleGroup('muscle_back', 'Back', 'upper'),
  createMuscleGroup('muscle_legs', 'Legs', 'lower'),
  createMuscleGroup('muscle_shoulders', 'Shoulders', 'upper'),
  createMuscleGroup('muscle_arms', 'Arms', 'upper'),
  createMuscleGroup('muscle_core', 'Core', 'trunk')
]
