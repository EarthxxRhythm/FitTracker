import { describe, expect, it } from '@ohos/hypium'
import { MonetizationGateResult, createMonetizationGateResult } from '../../../main/ets/shared/models/MonetizationModels'
import ReviewUpgradeEntryService from '../../../main/ets/shared/services/ReviewUpgradeEntryService'

function createGateResult(allowed: boolean, activeTier: 'free' | 'pro' | 'plus'): MonetizationGateResult {
  return createMonetizationGateResult(
    'advanced_insights',
    allowed,
    'pro',
    activeTier,
    'fittracker_pro_lifetime',
    allowed ? '' : 'requires_pro_for_advanced_insights'
  )
}

export default function reviewUpgradeEntryServiceTest(): void {
  describe('ReviewUpgradeEntryService', () => {
    it('creates a locked advanced insights presentation for free users', 0, () => {
      const presentation = ReviewUpgradeEntryService.createAdvancedInsightsPresentation(
        createGateResult(false, 'free'),
        8,
        2
      )

      expect(presentation.locked).assertTrue()
      expect(presentation.statusLabel).assertEqual('Free')
      expect(presentation.title).assertEqual('解锁高级洞察')
      expect(presentation.actionText).assertEqual('查看 Pro 方案')
      expect(presentation.featureBullets.length).assertEqual(3)
    })

    it('creates an unlocked presentation for pro users', 0, () => {
      const presentation = ReviewUpgradeEntryService.createAdvancedInsightsPresentation(
        createGateResult(true, 'pro'),
        8,
        3
      )

      expect(presentation.locked).assertFalse()
      expect(presentation.statusLabel).assertEqual('Pro 已解锁')
      expect(presentation.title).assertEqual('高级洞察已就绪')
      expect(presentation.actionText).assertEqual('查看当前权益')
      expect(presentation.featureBullets.length).assertEqual(3)
    })

    it('creates a plus-specific unlocked presentation for plus users', 0, () => {
      const presentation = ReviewUpgradeEntryService.createAdvancedInsightsPresentation(
        createGateResult(true, 'plus'),
        12,
        0
      )

      expect(presentation.locked).assertFalse()
      expect(presentation.statusLabel).assertEqual('Plus 已覆盖')
      expect(presentation.actionText).assertEqual('查看当前权益')
    })
  })
}
