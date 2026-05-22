/**
 * TargetLoopSkeleton -- shared training model tests.
 *
 * Feature #1: shared data models for the target loop skeleton.
 */
import { describe, it, expect } from '@ohos/hypium'
import {
  ExerciseContent,
  UserGoal,
  WorkoutSet,
  createExerciseContent,
  createUserGoal,
  createWorkoutSet,
  estimateOneRepMax
} from '../main/ets/shared/models/TrainingModels'

export default function targetLoopSkeletonTest() {
  describe('TargetLoopSkeleton -- user goals', () => {
    it('should create a user goal with explicit fields', 0, () => {
      const goal: UserGoal = createUserGoal('goal_strength', 'Strength', 'Build strength', 4)

      expect(goal.id).assertEqual('goal_strength')
      expect(goal.name).assertEqual('Strength')
      expect(goal.description).assertEqual('Build strength')
      expect(goal.weeklyTarget).assertEqual(4)
    })
  })

  describe('TargetLoopSkeleton -- exercise content', () => {
    it('should create exercise content with muscles and equipment', 0, () => {
      const content: ExerciseContent = createExerciseContent(
        'exercise_bench_press',
        'Bench Press',
        'Barbell bench press',
        'muscle_chest',
        'equipment_barbell'
      )

      expect(content.id).assertEqual('exercise_bench_press')
      expect(content.name).assertEqual('Bench Press')
      expect(content.description).assertEqual('Barbell bench press')
      expect(content.primaryMuscleGroupId).assertEqual('muscle_chest')
      expect(content.equipmentItemId).assertEqual('equipment_barbell')
    })
  })

  describe('TargetLoopSkeleton -- workout sets', () => {
    it('should create a workout set with measured load', 0, () => {
      const set: WorkoutSet = createWorkoutSet('set_1', 'exercise_bench_press', 100, 5, 1)

      expect(set.id).assertEqual('set_1')
      expect(set.exerciseContentId).assertEqual('exercise_bench_press')
      expect(set.weight).assertEqual(100)
      expect(set.reps).assertEqual(5)
      expect(set.setIndex).assertEqual(1)
    })
  })

  describe('TargetLoopSkeleton -- one rep max', () => {
    it('should estimate one rep max using Epley formula rounded to two decimals', 0, () => {
      const oneRepMax = estimateOneRepMax(82.5, 7)

      expect(oneRepMax).assertEqual(101.75)
    })
  })
}
