import { describe, it, expect } from '@ohos/hypium'
import { AppRoutes } from '../../../main/ets/app/AppRoutes'
import { TrainingPlan, UserGoal } from '../../../main/ets/shared/models/TrainingModels'
import TrainingPlanService, {
  ExerciseRef,
  PresetPlan,
  TrainingDay,
  UserPlan
} from '../../../main/ets/common/services/TrainingPlanService'
import GoalRepository from '../../../main/ets/shared/services/GoalRepository'
import GoalSetupService from '../../../main/ets/shared/services/GoalSetupService'
import PlanEngine from '../../../main/ets/shared/services/PlanEngine'
import WorkoutPreviewService, { WorkoutPreviewSummary } from '../../../main/ets/shared/services/WorkoutPreviewService'

export default function workoutPreviewServiceTest(): void {
  describe('WorkoutPreviewService', () => {
    it('builds preview summary and action list from a saved goal generated plan', 0, () => {
      GoalRepository.clearLocal()
      const goal: UserGoal = GoalSetupService.createGoalFromSelection(
        'preview_goal',
        'hypertrophy',
        'beginner',
        3,
        45,
        ['eq_bodyweight'],
        [],
        100
      )
      GoalRepository.saveLocalGoal(goal)

      const savedGoal: UserGoal | undefined = GoalRepository.getLocalGoal()
      expect(savedGoal !== undefined).assertTrue()
      if (savedGoal !== undefined) {
        const plan: TrainingPlan = PlanEngine.generatePlan(savedGoal)
        const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreviewForGoal(savedGoal, plan, 1)

        expect(preview.hasWorkout).assertTrue()
        expect(preview.planName).assertEqual('增肌基础计划')
        expect(preview.goalSummary).assertContain('3')
        expect(preview.goalSummary).assertContain('45')
        expect(preview.scheduleSummary).assertContain('第 1 天')
        expect(preview.scheduleSummary.indexOf('day_1')).assertEqual(-1)
        expect(preview.exercises.length).assertEqual(preview.exerciseCount)
        expect(preview.exercises.length).assertLarger(0)
        expect(preview.exercises[0].targetSets).assertEqual(3)
        expect(preview.exercises[0].targetReps).assertEqual('8-12')
        expect(preview.exercises[0].intensityNote.length > 0).assertTrue()
        expect(preview.exercises[0].selectionNote.length > 0).assertTrue()
      }
    })

    it('routes a start action from trainable preview to active workout page', 0, () => {
      GoalRepository.clearLocal()
      const goal: UserGoal = GoalSetupService.createGoalFromSelection(
        'preview_start_goal',
        'hypertrophy',
        'beginner',
        3,
        45,
        ['eq_bodyweight'],
        [],
        100
      )
      GoalRepository.saveLocalGoal(goal)

      const savedGoal: UserGoal | undefined = GoalRepository.getLocalGoal()
      expect(savedGoal !== undefined).assertTrue()
      if (savedGoal !== undefined) {
        const plan: TrainingPlan = PlanEngine.generatePlan(savedGoal)
        const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreviewForGoal(savedGoal, plan, 1)
        const targetRoute: string = WorkoutPreviewService.getStartWorkoutRoute(preview)

        expect(preview.hasWorkout).assertTrue()
        expect(targetRoute).assertEqual(AppRoutes.ACTIVE_WORKOUT)
      }
    })

    it('builds preview summary from the current enabled preset plan', 0, () => {
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
          enabledAt: 123
        }
        const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreviewForCurrentPlan(
          currentPlan,
          'current_plan_day_1',
          '鍛ㄤ竴',
          currentPlan.days[0]
        )

        expect(preview.hasWorkout).assertTrue()
        expect(preview.planId).assertEqual(currentPlan.id)
        expect(preview.planName).assertEqual(currentPlan.name)
        expect(preview.dayId).assertEqual('current_plan_day_1')
        expect(preview.title).assertEqual(currentPlan.days[0].dayLabel)
        expect(preview.exercises.length).assertEqual(currentPlan.days[0].exercises.length)
        expect(preview.exercises[0].plannedExerciseId).assertEqual('current_plan_day_1_exercise_1')
        expect(WorkoutPreviewService.getStartWorkoutRoute(preview)).assertEqual(AppRoutes.ACTIVE_WORKOUT)
      }
    })

    it('resolves current-plan preview by route day id and keeps the schedule summary user-facing', 0, () => {
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
          enabledAt: 456
        }
        const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreviewForCurrentPlan(
          currentPlan,
          'current_plan_day_2',
          '鏄熸湡鍥?',
          currentPlan.days[0]
        )

        expect(preview.hasWorkout).assertTrue()
        expect(preview.dayId).assertEqual('current_plan_day_2')
        expect(preview.title).assertEqual(currentPlan.days[1].dayLabel)
        expect(preview.exerciseCount).assertEqual(currentPlan.days[1].exercises.length)
        expect(preview.scheduleSummary).assertContain(currentPlan.days[1].dayLabel)
        expect(preview.scheduleSummary.indexOf('current_plan_day_2')).assertEqual(-1)
        expect(preview.exercises[0].plannedExerciseId).assertEqual('current_plan_day_2_exercise_1')
      }
    })

    it('recovers current-plan day id and fallback metadata when only today training is available', 0, () => {
      const fallbackExercise: ExerciseRef = {
        name: 'preview_service_unmapped_exercise',
        targetMuscle: 'core',
        sets: 4,
        reps: '6-8'
      }
      const fallbackDay: TrainingDay = {
        dayLabel: 'Plan Day Alpha',
        exercises: [fallbackExercise]
      }
      const currentPlan: UserPlan = {
        id: 'custom_current_plan_preview',
        name: 'Custom Current Plan Preview',
        coverColor: '#123456',
        targetAudience: 'Test Audience',
        weeklyFrequency: '1 day/week',
        days: [fallbackDay],
        enabledAt: 789
      }
      const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreviewForCurrentPlan(
        currentPlan,
        '',
        '鏄熸湡鏃?',
        fallbackDay
      )

      expect(preview.hasWorkout).assertTrue()
      expect(preview.dayId).assertEqual('current_plan_day_1')
      expect(preview.title).assertEqual(fallbackDay.dayLabel)
      expect(preview.scheduleSummary).assertContain(fallbackDay.dayLabel)
      expect(preview.scheduleSummary.indexOf('current_plan_day_1')).assertEqual(-1)
      expect(preview.hasFallback).assertTrue()
      expect(preview.fallbackNote).assertEqual(preview.exercises[0].selectionNote)
      expect(preview.exercises[0].plannedExerciseId).assertEqual('current_plan_day_1_exercise_1')
      expect(preview.exercises[0].exerciseId).assertEqual('custom_current_plan_preview_exercise_1')
    })
  })
}
