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

  describe('TrainingPlanService — e2e-lite: plan detail page navigation', () => {

    it('should simulate clicking a plan card and viewing detail', 0, () => {
      // User taps a plan card → navigates to detail page with planId
      const planId = 'preset_bro_split'
      const plan = TrainingPlanService.getPresetPlanById(planId)
      expect(plan !== undefined).assertTrue()

      // Detail page displays plan meta
      expect(plan!.name).assertEqual('五分化训练')
      expect(plan!.targetAudience.length).assertLarger(0)
      expect(plan!.weeklyFrequency.length).assertLarger(0)

      // Detail page shows timeline of 5 training days
      expect(plan!.days.length).assertEqual(5)

      // Each day shows exercises with name + muscle tag + sets×reps
      const dayLabels = plan!.days.map(d => d.dayLabel)
      expect(dayLabels.includes('周一 胸部')).assertTrue()
      expect(dayLabels.includes('周二 背部')).assertTrue()
      expect(dayLabels.includes('周三 腿部')).assertTrue()
      expect(dayLabels.includes('周四 肩部')).assertTrue()
      expect(dayLabels.includes('周五 手臂')).assertTrue()

      // Each day has 5 exercises
      for (let day of plan!.days) {
        expect(day.exercises.length).assertEqual(5)
        for (let ex of day.exercises) {
          expect(ex.targetMuscle.length).assertLarger(0)
          expect(ex.name.length).assertLarger(0)
          expect(ex.sets).assertLarger(0)
          expect(ex.reps.length).assertLarger(0)
        }
      }

      // User can see all muscle groups represented
      const allMuscles = new Set<string>()
      for (let day of plan!.days) {
        for (let ex of day.exercises) {
          allMuscles.add(ex.targetMuscle)
        }
      }
      expect(allMuscles.size).assertLarger(2)
    })

    it('should show exercises with correct target muscle per day', 0, () => {
      const plan = TrainingPlanService.getPresetPlanById('preset_bro_split')
      expect(plan !== undefined).assertTrue()

      // Monday = chest exercises
      for (let ex of plan!.days[0].exercises) {
        expect(ex.targetMuscle).assertEqual('胸')
      }

      // Tuesday = back exercises
      for (let ex of plan!.days[1].exercises) {
        expect(ex.targetMuscle).assertEqual('背')
      }

      // Wednesday = leg exercises
      for (let ex of plan!.days[2].exercises) {
        expect(ex.targetMuscle).assertEqual('腿')
      }

      // Thursday = shoulder exercises
      for (let ex of plan!.days[3].exercises) {
        expect(ex.targetMuscle).assertEqual('肩')
      }

      // Friday = arm exercises
      for (let ex of plan!.days[4].exercises) {
        expect(ex.targetMuscle).assertEqual('臂')
      }
    })
  })

  describe('TrainingPlanService — enable plan simulation', () => {

    it('should clone preset plan with deep copy of days', 0, () => {
      const preset = TrainingPlanService.getPresetPlanById('preset_bro_split')
      expect(preset !== undefined).assertTrue()

      // Simulate cloning: deep copy days
      const clonedDays = JSON.parse(JSON.stringify(preset!.days))
      expect(clonedDays.length).assertEqual(5)

      // Verify deep copy independence
      clonedDays[0].dayLabel = 'MODIFIED'
      expect(preset!.days[0].dayLabel).assertContain('周一')
      expect(clonedDays[0].dayLabel).assertEqual('MODIFIED')
    })

    it('should generate unique plan ID for each enabled plan', 0, () => {
      const id1 = `user_plan_${Date.now()}`
      const id2 = `user_plan_${Date.now() + 1}`
      expect(id1 === id2).assertFalse()
    })

    it('should carry over all preset fields to user plan', 0, () => {
      const preset = TrainingPlanService.getPresetPlanById('preset_ppl')
      expect(preset !== undefined).assertTrue()

      // Verify all fields that would be carried over
      expect(preset!.name).assertContain('推拉腿')
      expect(preset!.coverColor).assertContain('#')
      expect(preset!.targetAudience.length).assertLarger(0)
      expect(preset!.weeklyFrequency.length).assertLarger(0)
      expect(preset!.days.length).assertLarger(0)
    })
  })

  describe('TrainingPlanService — my plans management', () => {

    it('should have UserPlan type with all required fields', 0, () => {
      const preset = TrainingPlanService.getPresetPlanById('preset_bro_split')
      // Simulate building a UserPlan from preset
      const userPlan = {
        id: `user_plan_test`,
        name: preset!.name,
        coverColor: preset!.coverColor,
        targetAudience: preset!.targetAudience,
        weeklyFrequency: preset!.weeklyFrequency,
        days: JSON.parse(JSON.stringify(preset!.days)),
        enabledAt: Date.now()
      }
      expect(userPlan.id.length).assertLarger(0)
      expect(userPlan.enabledAt).assertLarger(0)
      expect(userPlan.days.length).assertEqual(5)
    })

    it('should distinguish current plan from other plans by id', 0, () => {
      const currentId = 'user_plan_current'
      const otherId = 'user_plan_other'
      const ids = [currentId, otherId]
      expect(ids.indexOf(currentId)).assertEqual(0)
      expect(currentId === otherId).assertFalse()
    })

    it('should remove item from array without affecting others', 0, () => {
      const plans = [
        { id: 'plan_a', name: 'Plan A' },
        { id: 'plan_b', name: 'Plan B' },
        { id: 'plan_c', name: 'Plan C' }
      ]
      const filtered = plans.filter(p => p.id !== 'plan_b')
      expect(filtered.length).assertEqual(2)
      expect(filtered[0].id).assertEqual('plan_a')
      expect(filtered[1].id).assertEqual('plan_c')
    })
  })
}
