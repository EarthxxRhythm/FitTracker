import { describe, it, expect } from '@ohos/hypium'
import {
  ExerciseContent,
  TrainingPlan,
  UserGoal,
  createUserGoal
} from '../../../main/ets/shared/models/TrainingModels'
import ContentRepository from '../../../main/ets/shared/services/ContentRepository'
import PlanEngine from '../../../main/ets/shared/services/PlanEngine'

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
  })
}
