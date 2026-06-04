import { describe, it, expect } from '@ohos/hypium'
import { TrainingPlan, UserGoal, WorkoutSession, createUserGoal } from '../../../main/ets/shared/models/TrainingModels'
import TrainingPlanService, { PresetPlan, UserPlan } from '../../../main/ets/common/services/TrainingPlanService'
import ActiveWorkoutService, { ActiveWorkoutExercise, ActiveWorkoutState } from '../../../main/ets/shared/services/ActiveWorkoutService'
import PlanEngine from '../../../main/ets/shared/services/PlanEngine'
import WorkoutPreviewService, { WorkoutPreviewSummary } from '../../../main/ets/shared/services/WorkoutPreviewService'
import WorkoutRepository from '../../../main/ets/shared/services/WorkoutRepository'

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

    it('creates active workout state from the current enabled preset plan preview', 0, () => {
      const presetPlan: PresetPlan | undefined = TrainingPlanService.getPresetPlanById('preset_upper_lower')
      expect(presetPlan !== undefined).assertTrue()
      if (presetPlan !== undefined) {
        const currentPlan: UserPlan = {
          id: presetPlan.id,
          name: presetPlan.name,
          coverColor: presetPlan.coverColor,
          targetAudience: presetPlan.targetAudience,
          weeklyFrequency: presetPlan.weeklyFrequency,
          days: presetPlan.days,
          enabledAt: 100
        }
        const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreviewForCurrentPlan(
          currentPlan,
          'current_plan_day_1',
          '周一',
          currentPlan.days[0]
        )
        const state: ActiveWorkoutState = ActiveWorkoutService.createState(preview)

        expect(state.hasWorkout).assertTrue()
        expect(state.planId).assertEqual(currentPlan.id)
        expect(state.dayId).assertEqual('current_plan_day_1')
        expect(state.currentExerciseName).assertEqual(preview.exercises[0].name)
        expect(state.currentExerciseSetProgress).assertEqual('0/' + preview.exercises[0].targetSets.toString())
      }
    })

    it('preserves current-plan identifiers through progress updates and session creation', 0, () => {
      const presetPlan: PresetPlan | undefined = TrainingPlanService.getPresetPlanById('preset_upper_lower')
      expect(presetPlan !== undefined).assertTrue()
      if (presetPlan !== undefined) {
        const currentPlan: UserPlan = {
          id: presetPlan.id,
          name: presetPlan.name,
          coverColor: presetPlan.coverColor,
          targetAudience: presetPlan.targetAudience,
          weeklyFrequency: presetPlan.weeklyFrequency,
          days: presetPlan.days,
          enabledAt: 101
        }
        const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreviewForCurrentPlan(
          currentPlan,
          'current_plan_day_2',
          '星期四',
          currentPlan.days[0]
        )
        const state: ActiveWorkoutState = ActiveWorkoutService.createState(preview)
        const firstExercise: ActiveWorkoutExercise = state.exercises[0]
        const updatedExercises: ActiveWorkoutExercise[] = ActiveWorkoutService.updateSetEntry(
          state.exercises,
          firstExercise.plannedExerciseId,
          0,
          '50',
          '8'
        )
        const progressedState: ActiveWorkoutState = ActiveWorkoutService.createStateWithProgress(state, updatedExercises)
        const session: WorkoutSession = ActiveWorkoutService.createCompletedSession(
          'session_current_plan_state',
          progressedState,
          1000,
          61000,
          progressedState.completedSets
        )

        expect(state.planId).assertEqual(currentPlan.id)
        expect(state.dayId).assertEqual('current_plan_day_2')
        expect(state.title).assertEqual(currentPlan.days[1].dayLabel)
        expect(progressedState.planId).assertEqual(state.planId)
        expect(progressedState.dayId).assertEqual(state.dayId)
        expect(progressedState.title).assertEqual(state.title)
        expect(progressedState.completedSets).assertEqual(1)
        expect(progressedState.currentExerciseName).assertEqual(firstExercise.name)
        expect(progressedState.currentExerciseSetProgress).assertEqual('1/' + firstExercise.targetSets.toString())
        expect(session.planId).assertEqual(currentPlan.id)
        expect(session.dayId).assertEqual('current_plan_day_2')
        expect(session.totalSets).assertEqual(1)
        expect(session.sets.length).assertEqual(1)
        expect(session.sets[0].setId).assertEqual('current_plan_day_2_exercise_1_set_1')
      }
    })

    it('preserves the latest sibling field when weight and reps are entered separately', 0, () => {
      const equipmentIds: string[] = ['eq_bodyweight']
      const restrictedMuscleIds: string[] = []
      const goal: UserGoal = createUserGoal(
        'goal_active_separate_input',
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

      const weightUpdatedExercises: ActiveWorkoutExercise[] = ActiveWorkoutService.updateSetWeight(
        state.exercises,
        firstExercise.plannedExerciseId,
        0,
        '40'
      )
      const repsUpdatedExercises: ActiveWorkoutExercise[] = ActiveWorkoutService.updateSetReps(
        weightUpdatedExercises,
        firstExercise.plannedExerciseId,
        0,
        '10'
      )
      const updatedState: ActiveWorkoutState = ActiveWorkoutService.createStateWithProgress(state, repsUpdatedExercises)

      expect(updatedState.completedSets).assertEqual(1)
      expect(updatedState.exercises[0].sets[0].weightText).assertEqual('40')
      expect(updatedState.exercises[0].sets[0].repsText).assertEqual('10')
      expect(updatedState.exercises[0].sets[0].estimatedOneRepMax).assertEqual(53)
      expect(updatedState.exercises[0].sets[0].oneRepMaxText).assertEqual('1RM 参考 53 kg')
    })

    it('saves completed workout session with set entries, totals, volume and duration through local repository', 0, () => {
      WorkoutRepository.clear()
      const equipmentIds: string[] = ['eq_bodyweight']
      const restrictedMuscleIds: string[] = []
      const goal: UserGoal = createUserGoal(
        'goal_active_save',
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
      const firstUpdatedExercises: ActiveWorkoutExercise[] = ActiveWorkoutService.updateSetEntry(
        state.exercises,
        firstExercise.plannedExerciseId,
        0,
        '80',
        '5'
      )
      const secondUpdatedExercises: ActiveWorkoutExercise[] = ActiveWorkoutService.updateSetEntry(
        firstUpdatedExercises,
        firstExercise.plannedExerciseId,
        1,
        '40',
        '10'
      )
      const progressedState: ActiveWorkoutState = ActiveWorkoutService.createStateWithProgress(state, secondUpdatedExercises)

      const session: WorkoutSession = ActiveWorkoutService.createCompletedSession(
        'session_active_save',
        progressedState,
        1000,
        181000,
        progressedState.completedSets
      )
      WorkoutRepository.saveSession(session)

      const savedSession: WorkoutSession | undefined = WorkoutRepository.getSessionById('session_active_save')
      expect(savedSession !== undefined).assertTrue()
      if (savedSession !== undefined) {
        expect(savedSession.totalSets).assertEqual(2)
        expect(savedSession.totalVolume).assertEqual(800)
        expect(savedSession.durationSeconds).assertEqual(180)
        expect(savedSession.sets.length).assertEqual(2)
        expect(savedSession.sets[0].setId).assertEqual(firstExercise.plannedExerciseId + '_set_1')
        expect(savedSession.sets[0].exerciseId).assertEqual(firstExercise.exerciseId)
        expect(savedSession.sets[0].weight).assertEqual(80)
        expect(savedSession.sets[0].reps).assertEqual(5)
        expect(savedSession.sets[1].setId).assertEqual(firstExercise.plannedExerciseId + '_set_2')
        expect(savedSession.sets[1].exerciseId).assertEqual(firstExercise.exerciseId)
        expect(savedSession.sets[1].weight).assertEqual(40)
        expect(savedSession.sets[1].reps).assertEqual(10)
      }
    })
  })
}
