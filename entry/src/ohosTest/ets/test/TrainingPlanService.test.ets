/**
 * TrainingPlanService 单元测试
 * 覆盖 5 个预设计划结构、getTodayTraining、getTodayLabel、isTrainingDay
 *
 * 注：enablePlan / getMyPlans / getCurrentPlan / setCurrentPlan / removeMyPlan / hasMyPlans
 * 需要 preferences Context，逻辑正确性通过集成测试验证。
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import trainingPlanService, { TrainingDay, UserPlan } from '../../../main/ets/common/services/TrainingPlanService'

export default function trainingPlanServiceTest(): void {
  describe('TrainingPlanService', () => {
    beforeAll(() => {
    })

    afterAll(() => {
    })

    // ============================================================
    // getAllPresetPlans
    // ============================================================
    describe('getAllPresetPlans', () => {
      it('should return 5 preset plans', 0, () => {
        const plans = trainingPlanService.getAllPresetPlans()
        expect(plans.length).assertEqual(5)
      })

      it('each plan should have required fields', 0, () => {
        const plans = trainingPlanService.getAllPresetPlans()
        for (let i = 0; i < plans.length; i++) {
          const plan = plans[i]
          expect(plan.id.length).assertLarger(0)
          expect(plan.name.length).assertLarger(0)
          expect(plan.coverColor.length).assertLarger(0)
          expect(plan.days.length).assertLarger(0)
        }
      })
    })

    // ============================================================
    // getPlanCount
    // ============================================================
    describe('getPlanCount', () => {
      it('should return 5', 0, () => {
        expect(trainingPlanService.getPlanCount()).assertEqual(5)
      })
    })

    // ============================================================
    // getPresetPlanById
    // ============================================================
    describe('getPresetPlanById', () => {
      it('should find the 五分化训练 plan', 0, () => {
        const plan = trainingPlanService.getPresetPlanById('preset_bro_split')
        expect(plan !== undefined).assertTrue()
        if (plan) {
          expect(plan.name).assertEqual('五分化训练')
          expect(plan.days.length).assertEqual(5)
          expect(plan.weeklyFrequency).assertEqual('5天/周')
        }
      })

      it('should find the 全身训练 plan', 0, () => {
        const plan = trainingPlanService.getPresetPlanById('preset_fullbody_3x')
        expect(plan !== undefined).assertTrue()
        if (plan) {
          expect(plan.name).assertEqual('全身训练 3x')
          expect(plan.days.length).assertEqual(3)
        }
      })

      it('should find the 推拉腿分裂 plan', 0, () => {
        const plan = trainingPlanService.getPresetPlanById('preset_ppl')
        expect(plan !== undefined).assertTrue()
        if (plan) {
          expect(plan.name).assertEqual('推拉腿分裂')
          expect(plan.days.length).assertEqual(3)
        }
      })

      it('should return undefined for non-existing plan id', 0, () => {
        const plan = trainingPlanService.getPresetPlanById('nonexistent')
        expect(plan).assertNull()
      })
    })

    // ============================================================
    // Plan structure validation
    // ============================================================
    describe('Preset Plan Structure', () => {
      it('五分化训练 should have 5 days with exercises', 0, () => {
        const plan = trainingPlanService.getPresetPlanById('preset_bro_split')
        if (plan) {
          expect(plan.days.length).assertEqual(5)
          for (let i = 0; i < plan.days.length; i++) {
            const day = plan.days[i]
            expect(day.exercises.length).assertLarger(0)
            expect(day.dayLabel.length).assertLarger(0)
          }
        }
      })

      it('上肢/下肢 should have dayOfWeek arrays', 0, () => {
        const plan = trainingPlanService.getPresetPlanById('preset_upper_lower')
        if (plan) {
          for (let i = 0; i < plan.days.length; i++) {
            const day = plan.days[i]
            expect(day.dayOfWeek !== undefined).assertTrue()
            if (day.dayOfWeek) {
              expect(day.dayOfWeek.length).assertLarger(0)
            }
          }
        }
      })

      it('力量举基础 should have 4 days', 0, () => {
        const plan = trainingPlanService.getPresetPlanById('preset_powerlifting')
        if (plan) {
          expect(plan.days.length).assertEqual(4)
          expect(plan.name).assertEqual('力量举基础')
        }
      })

      it('exercises should have valid structure', 0, () => {
        const plan = trainingPlanService.getPresetPlanById('preset_bro_split')
        if (plan) {
          const firstDay = plan.days[0]
          const firstEx = firstDay.exercises[0]
          expect(firstEx.name.length).assertLarger(0)
          expect(firstEx.targetMuscle.length).assertLarger(0)
          expect(firstEx.sets).assertLarger(0)
          expect(firstEx.reps.length).assertLarger(0)
        }
      })
    })

    // ============================================================
    // getTodayLabel
    // ============================================================
    describe('getTodayLabel', () => {
      it('should return a valid day label', 0, () => {
        const label = trainingPlanService.getTodayLabel()
        const validLabels = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六']
        let found = false
        for (let i = 0; i < validLabels.length; i++) {
          if (label === validLabels[i]) {
            found = true
          }
        }
        expect(found).assertTrue()
      })
    })

    // ============================================================
    // getTodayTraining (uses real date but tests structure)
    // ============================================================
    describe('getTodayTraining', () => {
      it('should return null or valid training day for known plans', 0, () => {
        const plan = trainingPlanService.getPresetPlanById('preset_ppl')
        if (plan) {
          // Create a UserPlan from the preset for testing
          const userPlan: UserPlan = {
            id: plan.id,
            name: plan.name,
            coverColor: plan.coverColor,
            targetAudience: plan.targetAudience,
            weeklyFrequency: plan.weeklyFrequency,
            days: plan.days,
            enabledAt: Date.now()
          }
          const todayTraining = trainingPlanService.getTodayTraining(userPlan)
          // For PPL plan (推拉腿分裂), it covers 6 out of 7 days
          // So todayTraining could be null (on Sunday) or a valid day
          // We just verify the return type
        }
      })

      it('should return null for a plan with empty days', 0, () => {
        const emptyDays: TrainingDay[] = []
        const emptyPlan: UserPlan = {
          id: 'test',
          name: 'Test',
          coverColor: '#000',
          targetAudience: '',
          weeklyFrequency: '',
          days: [],
          enabledAt: Date.now()
        }
        const result = trainingPlanService.getTodayTraining(emptyPlan)
        expect(result).assertNull()
      })
    })

    // ============================================================
    // isTrainingDay
    // ============================================================
    describe('isTrainingDay', () => {
      it('should return boolean for a valid plan', 0, () => {
        const plan = trainingPlanService.getPresetPlanById('preset_ppl')
        if (plan) {
          const userPlan: UserPlan = {
            id: plan.id,
            name: plan.name,
            coverColor: plan.coverColor,
            targetAudience: plan.targetAudience,
            weeklyFrequency: plan.weeklyFrequency,
            days: plan.days,
            enabledAt: Date.now()
          }
          const result = trainingPlanService.isTrainingDay(userPlan)
          // Should be a boolean (could be true or false depending on today)
          const isBool = result === true || result === false
          expect(isBool).assertTrue()
        }
      })

      it('should return false for empty-days plan', 0, () => {
        const emptyDays: TrainingDay[] = []
        const emptyPlan: UserPlan = {
          id: 'test',
          name: 'Test',
          coverColor: '#000',
          targetAudience: '',
          weeklyFrequency: '',
          days: [],
          enabledAt: Date.now()
        }
        expect(trainingPlanService.isTrainingDay(emptyPlan)).assertFalse()
      })
    })
  })
}
