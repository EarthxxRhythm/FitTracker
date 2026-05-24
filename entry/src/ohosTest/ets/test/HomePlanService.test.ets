import { describe, it, expect } from '@ohos/hypium'
import { TrainingPlan, UserGoal } from '../../../main/ets/shared/models/TrainingModels'
import GoalRepository from '../../../main/ets/shared/services/GoalRepository'
import GoalSetupService from '../../../main/ets/shared/services/GoalSetupService'
import HomePlanService, { HomePlanSummary } from '../../../main/ets/shared/services/HomePlanService'
import PlanEngine from '../../../main/ets/shared/services/PlanEngine'

export default function homePlanServiceTest(): void {
  describe('HomePlanService', () => {
    it('builds a home summary from a saved goal generated plan', 0, () => {
      GoalRepository.clearLocal()
      const goal: UserGoal = GoalSetupService.createGoalFromSelection(
        'home_goal',
        'hypertrophy',
        'beginner',
        3,
        45,
        ['eq_bodyweight', 'eq_dumbbell'],
        ['muscle_legs'],
        100
      )
      GoalRepository.saveLocalGoal(goal)

      const savedGoal: UserGoal | undefined = GoalRepository.getLocalGoal()
      expect(savedGoal !== undefined).assertTrue()
      if (savedGoal !== undefined) {
        const plan: TrainingPlan = PlanEngine.generatePlan(savedGoal)
        const summary: HomePlanSummary = HomePlanService.createSummary(savedGoal, plan, 1)

        expect(summary.hasGoal).assertTrue()
        expect(summary.goalSummary).assertEqual('目标 增肌 · 初学 · 每周 3 天 · 单次 45 分钟')
        expect(summary.equipmentSummary).assertEqual('器械 徒手、哑铃')
        expect(summary.restrictionSummary).assertEqual('避开 腿部')
        expect(summary.todayTitle).assertEqual('Day 1')
        expect(summary.todayExerciseNames.length).assertLarger(0)
      }
    })
  })
}
