import { describe, it, expect } from '@ohos/hypium'
import {
  ExerciseContent,
  TrainingPlan,
  UserGoal,
  createUserGoal
} from '../../../main/ets/shared/models/TrainingModels'
import ContentRepository from '../../../main/ets/shared/services/ContentRepository'
import PlanEngine from '../../../main/ets/shared/services/PlanEngine'
import WorkoutPreviewService from '../../../main/ets/shared/services/WorkoutPreviewService'

function containsValue(values: string[], targetValue: string): boolean {
  for (let index = 0; index < values.length; index++) {
    if (values[index] === targetValue) {
      return true
    }
  }
  return false
}

export default function planEngineTest(): void {
  describe('PlanEngine', () => {
    it('uses goal equipment restrictions and difficulty to generate trainable plan days', 0, () => {
      const equipmentIds: string[] = ['eq_dumbbell']
      const restrictedMuscleIds: string[] = ['muscle_chest']
      const goal: UserGoal = createUserGoal(
        'plan_engine_restricted_goal',
        'hypertrophy',
        'beginner',
        2,
        45,
        equipmentIds,
        restrictedMuscleIds,
        1,
        1
      )

      const plan: TrainingPlan = PlanEngine.generatePlan(goal)

      expect(plan.days.length).assertEqual(2)
      for (let dayIndex = 0; dayIndex < plan.days.length; dayIndex++) {
        expect(plan.days[dayIndex].focusMuscleIds.length).assertEqual(1)
        expect(plan.days[dayIndex].focusMuscleIds[0] === 'muscle_chest').assertFalse()
        expect(plan.days[dayIndex].exercises.length).assertLarger(0)

        for (let exerciseIndex = 0; exerciseIndex < plan.days[dayIndex].exercises.length; exerciseIndex++) {
          const content: ExerciseContent | undefined = ContentRepository.getExerciseById(
            plan.days[dayIndex].exercises[exerciseIndex].exerciseId
          )
          expect(content !== undefined).assertTrue()
          if (content !== undefined) {
            expect(content.difficulty).assertEqual('beginner')
            expect(containsValue(content.goalTags, 'hypertrophy')).assertTrue()
            expect(containsValue(content.equipmentIds, 'eq_dumbbell')).assertTrue()
            expect(containsValue(content.primaryMuscleIds, 'muscle_chest')).assertFalse()
            expect(containsValue(content.secondaryMuscleIds, 'muscle_chest')).assertFalse()
          }
        }
      }
    })

    it('uses local JSONL content to generate strength plan with machine equipment', 0, () => {
      const goal: UserGoal = createUserGoal(
        'plan_engine_machine_strength_goal',
        'strength',
        'beginner',
        1,
        45,
        ['eq_machine'],
        [],
        1,
        1
      )

      const plan: TrainingPlan = PlanEngine.generatePlan(goal)

      expect(plan.days.length).assertEqual(1)
      expect(plan.days[0].exercises.length).assertLarger(0)
      const exercise: ExerciseContent | undefined = ContentRepository.getExerciseById(plan.days[0].exercises[0].exerciseId)
      expect(exercise !== undefined).assertTrue()
      if (exercise !== undefined) {
        expect(containsValue(exercise.goalTags, 'strength')).assertTrue()
        expect(containsValue(exercise.equipmentIds, 'eq_machine')).assertTrue()
      }
    })

    it('limits weekly training days to the 0 to 7 range', 0, () => {
      const lowGoal: UserGoal = createUserGoal(
        'plan_engine_low_days_goal',
        'hypertrophy',
        'beginner',
        -2,
        45,
        ['eq_dumbbell'],
        [],
        1,
        1
      )
      const highGoal: UserGoal = createUserGoal(
        'plan_engine_high_days_goal',
        'hypertrophy',
        'beginner',
        9,
        45,
        ['eq_dumbbell'],
        [],
        1,
        1
      )

      const lowPlan: TrainingPlan = PlanEngine.generatePlan(lowGoal)
      const highPlan: TrainingPlan = PlanEngine.generatePlan(highGoal)

      expect(lowPlan.days.length).assertEqual(0)
      expect(highPlan.days.length).assertEqual(7)
      expect(highPlan.days[6].dayOfWeek).assertEqual(7)
    })

    it('scores candidates by goal equipment muscle difficulty and alternative completeness', 0, () => {
      const goal: UserGoal = createUserGoal(
        'plan_engine_scored_candidates_goal',
        'hypertrophy',
        'beginner',
        1,
        45,
        ['eq_bodyweight'],
        [],
        1,
        1
      )

      const plan: TrainingPlan = PlanEngine.generatePlan(goal)

      expect(plan.days.length).assertEqual(1)
      expect(plan.days[0].focusMuscleIds[0]).assertEqual('muscle_chest')
      expect(plan.days[0].exercises.length).assertLarger(0)
      expect(plan.days[0].exercises[0].exerciseId).assertEqual('ex_push_up')
      expect(plan.days[0].exercises[0].selectionNote).assertEqual('精确匹配：目标、器械、肌群和难度均匹配。')
    })

    it('falls back by relaxing difficulty when exact candidates are unavailable', 0, () => {
      const goal: UserGoal = createUserGoal(
        'plan_engine_difficulty_fallback_goal',
        'strength',
        'advanced',
        1,
        45,
        ['eq_machine'],
        [],
        1,
        1
      )

      const plan: TrainingPlan = PlanEngine.generatePlan(goal)

      expect(plan.days.length).assertEqual(1)
      expect(plan.days[0].exercises.length).assertLarger(0)
      expect(plan.days[0].exercises[0].selectionNote).assertEqual('已放宽难度：未找到完全匹配动作，优先保留目标、器械和肌群。')
    })

    it('falls back by relaxing equipment when user has no matching equipment', 0, () => {
      const goal: UserGoal = createUserGoal(
        'plan_engine_equipment_fallback_goal',
        'hypertrophy',
        'beginner',
        1,
        45,
        ['eq_unavailable'],
        [],
        1,
        1
      )

      const plan: TrainingPlan = PlanEngine.generatePlan(goal)

      expect(plan.days.length).assertEqual(1)
      expect(plan.days[0].exercises.length).assertLarger(0)
      expect(plan.days[0].exercises[0].selectionNote).assertEqual('已放宽器械：未找到可用器械动作，请在执行前确认替代器械。')
    })

    it('uses bodyweight defaults when no equipment is selected', 0, () => {
      const emptyEquipment: string[] = []
      const goal: UserGoal = createUserGoal(
        'plan_engine_no_equipment_goal',
        'hypertrophy',
        'beginner',
        1,
        45,
        emptyEquipment,
        [],
        1,
        1
      )

      const plan: TrainingPlan = PlanEngine.generatePlan(goal)

      expect(plan.days.length).assertEqual(1)
      expect(plan.days[0].exercises.length).assertLarger(0)
      const exercise: ExerciseContent | undefined = ContentRepository.getExerciseById(plan.days[0].exercises[0].exerciseId)
      expect(exercise !== undefined).assertTrue()
      if (exercise !== undefined) {
        expect(containsValue(exercise.equipmentIds, 'eq_bodyweight')).assertTrue()
      }
    })

    it('returns rest days when all focus muscles are restricted', 0, () => {
      const goal: UserGoal = createUserGoal(
        'plan_engine_all_restricted_goal',
        'hypertrophy',
        'beginner',
        3,
        45,
        ['eq_bodyweight'],
        ['muscle_chest', 'muscle_back', 'muscle_legs', 'muscle_shoulders', 'muscle_arms', 'muscle_core'],
        1,
        1
      )

      const plan: TrainingPlan = PlanEngine.generatePlan(goal)

      expect(plan.days.length).assertEqual(3)
      expect(plan.days[0].exercises.length).assertEqual(0)
      expect(plan.days[1].exercises.length).assertEqual(0)
      expect(plan.days[2].exercises.length).assertEqual(0)
    })

    it('returns planned days without exercises when goal has no candidate actions', 0, () => {
      const goal: UserGoal = createUserGoal(
        'plan_engine_no_candidate_goal',
        'mobility_unknown',
        'beginner',
        1,
        45,
        ['eq_bodyweight'],
        [],
        1,
        1
      )

      const plan: TrainingPlan = PlanEngine.generatePlan(goal)

      expect(plan.days.length).assertEqual(1)
      expect(plan.days[0].exercises.length).assertEqual(0)
    })

    it('keeps explanation when fallback is visible in workout preview', 0, () => {
      const goal: UserGoal = createUserGoal(
        'plan_engine_preview_fallback_goal',
        'strength',
        'advanced',
        1,
        45,
        ['eq_machine'],
        [],
        1,
        1
      )

      const plan: TrainingPlan = PlanEngine.generatePlan(goal)
      const preview = WorkoutPreviewService.createPreviewForGoal(goal, plan, 1)

      expect(preview.hasFallback).assertTrue()
      expect(preview.fallbackNote).assertEqual('已放宽难度：未找到完全匹配动作，优先保留目标、器械和肌群。')
    })
  })
}
