import { describe, expect, it } from '@ohos/hypium'
import { AppRoutes } from '../../../main/ets/app/AppRoutes'
import HomePlanService, { HomePlanSummary } from '../../../main/ets/shared/services/HomePlanService'
import GoalSetupService from '../../../main/ets/shared/services/GoalSetupService'
import PlanEngine from '../../../main/ets/shared/services/PlanEngine'
import HomeDashboardService from '../../../main/ets/features/home/services/HomeDashboardService'

export default function homeDashboardServiceTest(): void {
  describe('HomeDashboardService', () => {
    it('creates a goal-setup decision model when no goal is available', 0, () => {
      const model = HomeDashboardService.createNoGoalViewModel(new Date(2026, 6, 21, 9, 30, 0))

      expect(model.hasGoal).assertFalse()
      expect(model.primaryActionLabel).assertEqual('\u8bbe\u7f6e\u8bad\u7ec3\u76ee\u6807')
      expect(model.secondaryActionLabel).assertEqual('\u67e5\u770b\u52a8\u4f5c\u5e93')
      expect(model.statusText).assertEqual('\u5148\u5b8c\u6210\u8bbe\u7f6e')
      expect(model.boundaryItems.length).assertEqual(0)
      expect(model.weeklyItems.length).assertEqual(0)
    })

    it('creates a resumable training model when a draft exists', 0, () => {
      const goal = GoalSetupService.createGoalFromSelection(
        'home_dashboard_resume',
        'hypertrophy',
        'beginner',
        3,
        45,
        ['eq_bodyweight'],
        [],
        100
      )
      const plan = PlanEngine.generatePlan(goal)
      const summary: HomePlanSummary = HomePlanService.createSummary(goal, plan, 1)
      const model = HomeDashboardService.createReadyViewModel(
        summary,
        true,
        '\u7b2c 1 \u5929 | 6/18 \u7ec4\u5df2\u5b8c\u6210',
        new Date(2026, 6, 21, 19, 10, 0)
      )

      expect(model.hasGoal).assertTrue()
      expect(model.primaryActionLabel).assertEqual('\u7ee7\u7eed\u8bad\u7ec3')
      expect(model.primaryActionRoute).assertEqual(AppRoutes.ACTIVE_WORKOUT)
      expect(model.secondaryActionLabel).assertEqual('\u67e5\u770b\u9884\u89c8')
      expect(model.statusText).assertEqual('\u53ef\u7ee7\u7eed\u8bad\u7ec3')
      expect(model.metrics.length).assertEqual(3)
      expect(model.boundaryItems.length).assertEqual(3)
      expect(model.weeklyItems.length).assertLarger(0)
    })

    it('creates a trainable today model for generated plans', 0, () => {
      const goal = GoalSetupService.createGoalFromSelection(
        'home_dashboard_today',
        'hypertrophy',
        'beginner',
        3,
        45,
        ['eq_bodyweight'],
        [],
        100
      )
      const plan = PlanEngine.generatePlan(goal)
      const summary: HomePlanSummary = HomePlanService.createSummary(goal, plan, 1)
      const model = HomeDashboardService.createReadyViewModel(
        summary,
        false,
        '',
        new Date(2026, 6, 21, 8, 30, 0)
      )

      expect(model.hasGoal).assertTrue()
      expect(model.primaryActionLabel).assertEqual('\u5f00\u59cb\u8bad\u7ec3')
      expect(model.primaryActionRoute).assertEqual(AppRoutes.WORKOUT_PREVIEW)
      expect(model.secondaryActionLabel).assertEqual('\u67e5\u770b\u9884\u89c8')
      expect(model.statusText).assertEqual('\u8bad\u7ec3\u65e5 \u00b7 \u5efa\u8bae\u5b8c\u6210')
      expect(model.progressText).assertContain('/')
      expect(model.weeklyItems[0].current).assertTrue()
    })
  })
}
