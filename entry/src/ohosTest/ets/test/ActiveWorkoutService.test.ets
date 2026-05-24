import { describe, it, expect } from '@ohos/hypium'
import { TrainingPlan, UserGoal, createUserGoal } from '../../../main/ets/shared/models/TrainingModels'
import ActiveWorkoutService, { ActiveWorkoutExercise, ActiveWorkoutState } from '../../../main/ets/shared/services/ActiveWorkoutService'
import PlanEngine from '../../../main/ets/shared/services/PlanEngine'
import WorkoutPreviewService, { WorkoutPreviewSummary } from '../../../main/ets/shared/services/WorkoutPreviewService'

export default function activeWorkoutServiceTest(): void {
  describe('ActiveWorkoutService', () => {
    it('creates active workout state with current exercise and set progress from preview flow', 0, () => {
      const equipmentIds: string[] = ['eq_bodyweight']
      const restrictedMuscleIds: string[] = []
      const goal: UserGoal = createUserGoal(
        'goal_active_flow',
        'hypertrophy',
        'beginner',
        3,
        45,
        equipmentIds,
        restrictedMuscleIds,
        100,
        100
      )
      const plan: TrainingPlan = PlanEngine.generatePlan(goal)
      const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreview(plan, 1)
      const state: ActiveWorkoutState = ActiveWorkoutService.createState(preview)

      expect(preview.hasWorkout).assertTrue()
      expect(state.hasWorkout).assertTrue()
      expect(state.currentExerciseName).assertEqual(preview.exercises[0].name)
      expect(state.currentExerciseSetProgress).assertEqual('0/' + preview.exercises[0].targetSets.toString())

      const firstExercise: ActiveWorkoutExercise = state.exercises[0]
      const progressedExercises: ActiveWorkoutExercise[] = ActiveWorkoutService.updateExerciseCompletedSets(
        state.exercises,
        firstExercise.plannedExerciseId,
        1
      )
      const progressedState: ActiveWorkoutState = ActiveWorkoutService.createStateWithProgress(state, progressedExercises)

      expect(progressedState.completedSets).assertEqual(1)
      expect(progressedState.currentExerciseName).assertEqual(firstExercise.name)
      expect(progressedState.currentExerciseSetProgress).assertEqual('1/' + firstExercise.targetSets.toString())
    })

    it('updates a set entry with weight and reps then exposes instant Epley 1RM reference', 0, () => {
      const equipmentIds: string[] = ['eq_bodyweight']
      const restrictedMuscleIds: string[] = []
      const goal: UserGoal = createUserGoal(
        'goal_active_one_rm',
        'hypertrophy',
        'beginner',
        3,
        45,
        equipmentIds,
        restrictedMuscleIds,
        100,
        100
      )
      const plan: TrainingPlan = PlanEngine.generatePlan(goal)
      const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreview(plan, 1)
      const state: ActiveWorkoutState = ActiveWorkoutService.createState(preview)
      const firstExercise: ActiveWorkoutExercise = state.exercises[0]

      const updatedExercises: ActiveWorkoutExercise[] = ActiveWorkoutService.updateSetEntry(
        state.exercises,
        firstExercise.plannedExerciseId,
        0,
        '80',
        '10'
      )
      const updatedState: ActiveWorkoutState = ActiveWorkoutService.createStateWithProgress(state, updatedExercises)

      expect(updatedState.completedSets).assertEqual(1)
      expect(updatedState.exercises[0].sets[0].weightText).assertEqual('80')
      expect(updatedState.exercises[0].sets[0].repsText).assertEqual('10')
      expect(updatedState.exercises[0].sets[0].estimatedOneRepMax).assertEqual(107)
      expect(updatedState.exercises[0].sets[0].oneRepMaxText).assertEqual('1RM 参考 107 kg')
    })
  })
}
