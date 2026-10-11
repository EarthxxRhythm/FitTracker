/**
 * ReviewService -- workout review calculations.
 *
 * Feature #3: plan engine and review calculations.
 */
import { WorkoutSet, estimateOneRepMax } from '../models/TrainingModels'

class ReviewServiceImpl {
  calculateVolume(sets: WorkoutSet[]): number {
    let volume: number = 0
    for (let index = 0; index < sets.length; index++) {
      const set: WorkoutSet = sets[index]
      if (!set.isWarmup) {
        volume += set.weight * set.reps
      }
    }
    return volume
  }

  calculateBestEstimatedOneRepMax(sets: WorkoutSet[]): number {
    let bestEstimatedOneRepMax: number = 0
    for (let index = 0; index < sets.length; index++) {
      const set: WorkoutSet = sets[index]
      if (!set.isWarmup) {
        const estimatedOneRepMax: number = estimateOneRepMax(set.weight, set.reps)
        if (estimatedOneRepMax > bestEstimatedOneRepMax) {
          bestEstimatedOneRepMax = estimatedOneRepMax
        }
      }
    }
    return bestEstimatedOneRepMax
  }

  calculateCompletionRate(completedExercises: number, plannedExercises: number): number {
    if (plannedExercises <= 0) {
      return 0
    }
    return Math.round((completedExercises * 100) / plannedExercises)
  }
}

export default new ReviewServiceImpl()
