import { describe, it, expect } from '@ohos/hypium'
import { PlanDay, TrainingPlan, UserGoal } from '../../../main/ets/shared/models/TrainingModels'
import GoalRepository from '../../../main/ets/shared/services/GoalRepository'
import GoalSetupService from '../../../main/ets/shared/services/GoalSetupService'
import HomePlanService, {
  HomePlanSummary,
  HomeRecommendedExercise
} from '../../../main/ets/shared/services/HomePlanService'
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
        expect(summary.goalSummary).assertContain('3')
        expect(summary.goalSummary).assertContain('45')
        expect(summary.equipmentSummary.length > 0).assertTrue()
        expect(summary.restrictionSummary.length > 0).assertTrue()
        expect(summary.todayTitle).assertEqual('第 1 天')
        expect(summary.todayExerciseNames.length).assertLarger(0)
      }
    })

    it('exposes generated plan days as weekly home plan rows', 0, () => {
      GoalRepository.clearLocal()
      const goal: UserGoal = GoalSetupService.createGoalFromSelection(
        'home_weekly_goal',
        'strength',
        'intermediate',
        4,
        60,
        ['eq_bodyweight', 'eq_barbell', 'eq_dumbbell'],
        [],
        200
      )
      GoalRepository.saveLocalGoal(goal)

      const savedGoal: UserGoal | undefined = GoalRepository.getLocalGoal()
      expect(savedGoal !== undefined).assertTrue()
      if (savedGoal !== undefined) {
        const plan: TrainingPlan = PlanEngine.generatePlan(savedGoal)
        const summary: HomePlanSummary = HomePlanService.createSummary(savedGoal, plan, 3)

        expect(plan.days.length).assertEqual(4)
        expect(summary.weeklyPlanDays.length).assertEqual(plan.days.length)
        for (let index = 0; index < plan.days.length; index++) {
          const planDay: PlanDay = plan.days[index]
          expect(summary.weeklyPlanDays[index].dayId).assertEqual(planDay.dayId)
          expect(summary.weeklyPlanDays[index].title).assertEqual(planDay.title)
          expect(summary.weeklyPlanDays[index].exerciseCount).assertEqual(planDay.exercises.length)
        }
        expect(summary.weeklyPlanDays[2].isToday).assertTrue()
      }
    })

    it('exposes today training day, recommended exercise details and start action from saved goal flow', 0, () => {
      GoalRepository.clearLocal()
      const goal: UserGoal = GoalSetupService.createGoalFromSelection(
        'home_today_goal',
        'hypertrophy',
        'beginner',
        3,
        45,
        ['eq_bodyweight', 'eq_dumbbell'],
        [],
        300
      )
      GoalRepository.saveLocalGoal(goal)

      const savedGoal: UserGoal | undefined = GoalRepository.getLocalGoal()
      expect(savedGoal !== undefined).assertTrue()
      if (savedGoal !== undefined) {
        const plan: TrainingPlan = PlanEngine.generatePlan(savedGoal)
        const summary: HomePlanSummary = HomePlanService.createSummary(savedGoal, plan, 2)

        expect(summary.todayLabel).assertContain('第 2 天')
        expect(summary.todayDayId).assertEqual(plan.days[1].dayId)
        expect(summary.startButtonText.length > 0).assertTrue()
        expect(summary.startRoute.length > 0).assertTrue()
        expect(summary.recommendedExercises.length).assertEqual(summary.todayExerciseCount)
        expect(summary.recommendedExercises.length > 0).assertTrue()

        const firstExercise: HomeRecommendedExercise = summary.recommendedExercises[0]
        expect(firstExercise.name.length > 0).assertTrue()
        expect(firstExercise.prescription.length > 0).assertTrue()
        expect(firstExercise.intensityNote.length > 0).assertTrue()
      }
    })
  })
}
