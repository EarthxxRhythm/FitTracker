import { describe, it, expect } from '@ohos/hypium'
import { UserGoal } from '../../../main/ets/shared/models/TrainingModels'
import GoalRepository from '../../../main/ets/shared/services/GoalRepository'
import GoalSetupService from '../../../main/ets/shared/services/GoalSetupService'

export default function goalSetupServiceTest(): void {
  describe('GoalSetupService', () => {
    it('creates and saves current onboarding selections with restricted muscles', 0, () => {
      GoalRepository.clearLocal()
      const equipmentIds: string[] = ['eq_dumbbell', 'eq_barbell']
      const restrictedMuscleIds: string[] = ['muscle_legs', 'muscle_shoulders']

      const goal: UserGoal = GoalSetupService.createCurrentGoalFromSelection(
        'strength',
        'intermediate',
        4,
        60,
        equipmentIds,
        restrictedMuscleIds,
        1000
      )

      GoalRepository.saveLocalGoal(goal)

      const savedGoal: UserGoal | undefined = GoalRepository.getLocalGoal()
      expect(savedGoal !== undefined).assertTrue()
      if (savedGoal !== undefined) {
        expect(savedGoal.goalId).assertEqual('goal_current')
        expect(savedGoal.goalType).assertEqual('strength')
        expect(savedGoal.level).assertEqual('intermediate')
        expect(savedGoal.weeklyDays).assertEqual(4)
        expect(savedGoal.sessionMinutes).assertEqual(60)
        expect(savedGoal.equipmentIds.length).assertEqual(2)
        expect(savedGoal.equipmentIds[0]).assertEqual('eq_dumbbell')
        expect(savedGoal.equipmentIds[1]).assertEqual('eq_barbell')
        expect(savedGoal.restrictedMuscleIds.length).assertEqual(2)
        expect(savedGoal.restrictedMuscleIds[0]).assertEqual('muscle_legs')
        expect(savedGoal.restrictedMuscleIds[1]).assertEqual('muscle_shoulders')
        expect(savedGoal.createdAt).assertEqual(1000)
        expect(savedGoal.updatedAt).assertEqual(1000)
      }
    })
  })
}
