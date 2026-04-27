/**
 * TrainingPlanService 单元测试
 *
 * 测试预置训练计划服务：
 *   - 计划总数正确（5套）
 *   - 按ID查找计划
 *   - 计划结构完整性（name, coverColor, targetAudience, weeklyFrequency, days）
 *   - 每个训练日包含动作清单
 *   - e2e-lite: 模拟用户浏览预置计划卡片列表
 */
import { describe, it, expect } from '@ohos/hypium'
import TrainingPlanService, { PresetPlan } from '../main/ets/common/services/TrainingPlanService'

export default function trainingPlanServiceTest() {
  describe('TrainingPlanService — plan count', () => {

    it('should have exactly 5 preset plans', 0, () => {
      expect(TrainingPlanService.getPlanCount()).assertEqual(5)
    })

    it('should return 5 plans from getAllPresetPlans', 0, () => {
      const plans = TrainingPlanService.getAllPresetPlans()
      expect(plans.length).assertEqual(5)
    })
  })

  describe('TrainingPlanService — plan lookup by ID', () => {

    it('should find bro split plan by id', 0, () => {
      const plan = TrainingPlanService.getPresetPlanById('preset_bro_split')
      expect(plan !== undefined).assertTrue()
      expect(plan!.name).assertContain('五分化')
    })

    it('should find powerlifting plan by id', 0, () => {
      const plan = TrainingPlanService.getPresetPlanById('preset_powerlifting')
      expect(plan !== undefined).assertTrue()
      expect(plan!.name).assertContain('力量举')
    })

    it('should return undefined for unknown id', 0, () => {
      const plan = TrainingPlanService.getPresetPlanById('nonexistent')
      expect(plan === undefined).assertTrue()
    })
  })

  describe('TrainingPlanService — plan structure integrity', () => {

    it('each plan should have name and coverColor', 0, () => {
      const plans = TrainingPlanService.getAllPresetPlans()
      for (let plan of plans) {
        expect(plan.name.length).assertLarger(0)
        expect(plan.coverColor.length).assertLarger(0)
        expect(plan.targetAudience.length).assertLarger(0)
        expect(plan.weeklyFrequency.length).assertLarger(0)
      }
    })

    it('each plan should have at least one training day', 0, () => {
      const plans = TrainingPlanService.getAllPresetPlans()
      for (let plan of plans) {
        expect(plan.days.length).assertLarger(0)
      }
    })

    it('each training day should have at least one exercise', 0, () => {
      const plans = TrainingPlanService.getAllPresetPlans()
      for (let plan of plans) {
        for (let day of plan.days) {
          expect(day.dayLabel.length).assertLarger(0)
          expect(day.exercises.length).assertLarger(0)
        }
      }
    })

    it('each exercise should have name, targetMuscle, sets and reps', 0, () => {
      const plans = TrainingPlanService.getAllPresetPlans()
      for (let plan of plans) {
        for (let day of plan.days) {
          for (let ex of day.exercises) {
            expect(ex.name.length).assertLarger(0)
            expect(ex.targetMuscle.length).assertLarger(0)
            expect(ex.sets).assertLarger(0)
            expect(ex.reps.length).assertLarger(0)
          }
        }
      }
    })
  })

  describe('TrainingPlanService — all plan names', () => {

    it('should contain all five expected plan names', 0, () => {
      const plans = TrainingPlanService.getAllPresetPlans()
      const names = plans.map(p => p.name)
      expect(names.includes('五分化训练')).assertTrue()
      expect(names.includes('上下肢分化')).assertTrue()
      expect(names.includes('推拉腿分化')).assertTrue()
      expect(names.includes('全身训练 3x')).assertTrue()
      expect(names.includes('力量举基础')).assertTrue()
    })
  })

  describe('TrainingPlanService — e2e-lite: browsing preset plans', () => {

    it('should simulate user browsing preset plan card list', 0, () => {
      const plans = TrainingPlanService.getAllPresetPlans()

      // User sees 5 plan cards
      expect(plans.length).assertEqual(5)

      // User reads first plan card: name, audience, frequency
      expect(plans[0].name).assertEqual('五分化训练')
      expect(plans[0].targetAudience).assertContain('中高级')
      expect(plans[0].weeklyFrequency).assertContain('5天')

      // User taps a plan card to preview — verify valid ID
      const plan = TrainingPlanService.getPresetPlanById('preset_ppl')
      expect(plan).assertNotNull()
      expect(plan!.days.length).assertEqual(3)

      // User sees training days in the plan
      expect(plan!.days[0].dayLabel).assertContain('推')
      expect(plan!.days[1].dayLabel).assertContain('拉')
      expect(plan!.days[2].dayLabel).assertContain('腿')

      // Each day has exercises with complete info
      for (let day of plan!.days) {
        expect(day.exercises.length).assertLarger(0)
        for (let ex of day.exercises) {
          expect(ex.name.length).assertLarger(0)
          expect(ex.sets).assertLarger(0)
          expect(ex.reps.length).assertLarger(0)
        }
      }
    })
  })
}
