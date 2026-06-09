import { describe, expect, it } from '@ohos/hypium'
import TrainingPlanService, { PresetPlan } from '../../../main/ets/common/services/TrainingPlanService'
import AdvancedPlanVariantsService from '../../../main/ets/shared/services/AdvancedPlanVariantsService'

function getPresetPlan(): PresetPlan {
  const plan: PresetPlan | undefined = TrainingPlanService.getPresetPlanById('preset_ppl')
  if (plan === undefined) {
    return {
      id: '',
      name: '',
      coverColor: '',
      targetAudience: '',
      weeklyFrequency: '',
      days: []
    }
  }
  return plan
}

export default function advancedPlanVariantsServiceTest(): void {
  describe('AdvancedPlanVariantsService', () => {
    it('creates a locked teaser for free users', 0, () => {
      const presentation = AdvancedPlanVariantsService.createPresentation(getPresetPlan(), true, 'free')

      expect(presentation.locked).assertTrue()
      expect(presentation.statusLabel).assertEqual('Free')
      expect(presentation.cards.length).assertEqual(3)
      expect(presentation.cards[0].actionText).assertEqual('升级解锁')
    })

    it('creates an unlocked presentation for pro users', 0, () => {
      const presentation = AdvancedPlanVariantsService.createPresentation(getPresetPlan(), false, 'pro')

      expect(presentation.locked).assertFalse()
      expect(presentation.statusLabel).assertEqual('Pro 已解锁')
      expect(presentation.cards[1].locked).assertFalse()
      expect(presentation.cards[1].actionText).assertEqual('启用高密度')
    })

    it('builds a volume variant with additional top-exercise sets', 0, () => {
      const plan: PresetPlan = getPresetPlan()
      const draft = AdvancedPlanVariantsService.createVariantDraft(plan, 'volume_boost')

      expect(draft.name).assertEqual('推拉腿分裂 · 高容量')
      expect(draft.days.length).assertEqual(plan.days.length)
      expect(draft.days[0].exercises[0].sets).assertEqual(plan.days[0].exercises[0].sets + 1)
      expect(draft.days[0].exercises[2].sets).assertEqual(plan.days[0].exercises[2].sets + 1)
    })

    it('builds a density variant with fewer exercises per day when possible', 0, () => {
      const plan: PresetPlan = getPresetPlan()
      const draft = AdvancedPlanVariantsService.createVariantDraft(plan, 'density_boost')

      expect(draft.name).assertEqual('推拉腿分裂 · 高密度')
      expect(draft.days[0].exercises.length).assertEqual(4)
      expect(draft.days[0].exercises[0].reps).assertEqual('6-10')
    })

    it('builds a recovery variant with reduced accessory load', 0, () => {
      const plan: PresetPlan = getPresetPlan()
      const draft = AdvancedPlanVariantsService.createVariantDraft(plan, 'recovery_friendly')

      expect(draft.name).assertEqual('推拉腿分裂 · 恢复优先')
      expect(draft.days[0].exercises.length).assertEqual(plan.days[0].exercises.length - 1)
      expect(draft.days[0].exercises[1].sets).assertEqual(plan.days[0].exercises[1].sets - 1)
    })
  })
}
