import { abilityDelegatorRegistry } from '@kit.TestKit'
import { afterAll, beforeEach, describe, expect, it } from '@ohos/hypium'
import SessionManager from '../../../main/ets/common/services/SessionManager'
import { createMonetizationEntitlement } from '../../../main/ets/shared/models/MonetizationModels'
import MonetizationEntitlementService, {
  MonetizationEntitlementStore
} from '../../../main/ets/shared/services/MonetizationEntitlementService'
import MonetizationHubService from '../../../main/ets/shared/services/MonetizationHubService'

class FakeMonetizationEntitlementStore extends MonetizationEntitlementStore {
  private entitlementJson: string = '[]'

  async get(key: string, defaultValue: string): Promise<string> {
    if (key === 'user_entitlements') {
      return this.entitlementJson
    }
    return defaultValue
  }

  async put(key: string, value: string): Promise<void> {
    if (key === 'user_entitlements') {
      this.entitlementJson = value
    }
  }

  async flush(): Promise<void> {
  }

  clear(): void {
    this.entitlementJson = '[]'
  }
}

function getTestContext(): Context {
  const appContext: Context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext()
  return appContext.getApplicationContext().createModuleContext('entry')
}

export default function monetizationHubServiceTest(): void {
  const fakeStore = new FakeMonetizationEntitlementStore()

  describe('MonetizationHubService', () => {
    beforeEach(async () => {
      await SessionManager.clearToken(getTestContext())
      fakeStore.clear()
      MonetizationEntitlementService.setEntitlementForTesting(null)
      MonetizationEntitlementService.setStoreForTesting(fakeStore)
    })

    afterAll(async () => {
      await SessionManager.clearToken(getTestContext())
      MonetizationEntitlementService.setEntitlementForTesting(null)
      MonetizationEntitlementService.setStoreForTesting(null)
    })

    it('builds a free-tier view model with pro as the highlighted first upgrade', 0, async () => {
      MonetizationEntitlementService.setEntitlementForTesting(
        createMonetizationEntitlement(
          '13800138000',
          'free',
          'local_default',
          'active',
          '',
          '',
          0,
          0,
          0,
          0,
          1
        )
      )

      const viewModel = await MonetizationHubService.createViewModel(getTestContext())

      expect(viewModel.tierText).assertEqual('Free')
      expect(viewModel.previewEnabled).assertTrue()
      expect(viewModel.offerCards.length).assertEqual(3)
      expect(viewModel.offerCards[0].productId).assertEqual('fittracker_pro_lifetime')
      expect(viewModel.offerCards[0].highlighted).assertTrue()
      expect(viewModel.roadmapItems.length).assertLarger(3)
    })

    it('marks pro ownership and recommends plus yearly for pro users', 0, async () => {
      MonetizationEntitlementService.setEntitlementForTesting(
        createMonetizationEntitlement(
          '13900139000',
          'pro',
          'iap_purchase',
          'active',
          'pro_lifetime',
          'fittracker_pro_lifetime',
          100,
          0,
          100,
          100,
          1
        )
      )

      const viewModel = await MonetizationHubService.createViewModel(getTestContext())

      expect(viewModel.tierText).assertEqual('Pro')
      expect(viewModel.offerCards[0].current).assertTrue()
      expect(viewModel.offerCards[2].productId).assertEqual('fittracker_plus_yearly')
      expect(viewModel.offerCards[2].highlighted).assertTrue()
    })

    it('shows plus tier without highlighting a lower upgrade path', 0, async () => {
      MonetizationEntitlementService.setEntitlementForTesting(
        createMonetizationEntitlement(
          '13700137000',
          'plus',
          'iap_purchase',
          'active',
          'plus_yearly',
          'fittracker_plus_yearly',
          100,
          Date.now() + 60000,
          100,
          100,
          1
        )
      )

      const viewModel = await MonetizationHubService.createViewModel(getTestContext())

      expect(viewModel.tierText).assertEqual('Plus')
      expect(viewModel.offerCards[2].current).assertTrue()
      expect(viewModel.offerCards[0].highlighted).assertFalse()
      expect(viewModel.offerCards[1].highlighted).assertFalse()
    })

    it('builds a focused premium-content upgrade context for exercise detail', 0, async () => {
      MonetizationEntitlementService.setEntitlementForTesting(
        createMonetizationEntitlement(
          '13500135000',
          'free',
          'local_default',
          'active',
          '',
          '',
          0,
          0,
          0,
          0,
          1
        )
      )

      const viewModel = await MonetizationHubService.createViewModel(
        getTestContext(),
        'premium_content',
        '动作详情'
      )

      expect(viewModel.focusContext.active).assertTrue()
      expect(viewModel.focusContext.sourceLabel).assertEqual('动作详情')
      expect(viewModel.focusContext.recommendedTierText).assertEqual('Plus')
      expect(viewModel.offerCards[1].productId).assertEqual('fittracker_plus_monthly')
      expect(viewModel.offerCards[1].highlighted).assertTrue()
      expect(viewModel.roadmapItems[0].capabilityKey).assertEqual('premium_content')
    })

    it('builds a focused pro upsell context for advanced plan variants', 0, async () => {
      MonetizationEntitlementService.setEntitlementForTesting(
        createMonetizationEntitlement(
          '13400134000',
          'free',
          'local_default',
          'active',
          '',
          '',
          0,
          0,
          0,
          0,
          1
        )
      )

      const viewModel = await MonetizationHubService.createViewModel(
        getTestContext(),
        'advanced_plans',
        '训练计划详情'
      )

      expect(viewModel.focusContext.active).assertTrue()
      expect(viewModel.focusContext.sourceLabel).assertEqual('训练计划详情')
      expect(viewModel.focusContext.recommendedTierText).assertEqual('Pro')
      expect(viewModel.offerCards[0].productId).assertEqual('fittracker_pro_lifetime')
      expect(viewModel.offerCards[0].highlighted).assertTrue()
      expect(viewModel.roadmapItems[0].capabilityKey).assertEqual('advanced_plans')
    })

    it('applies local preview tiers through entitlement storage', 0, async () => {
      const token: string = SessionManager.generateToken('13600136000')
      await SessionManager.saveToken(getTestContext(), token)

      await MonetizationHubService.applyPreviewTier(getTestContext(), 'pro')
      let viewModel = await MonetizationHubService.createViewModel(getTestContext())

      expect(viewModel.tierText).assertEqual('Pro')
      expect(viewModel.previewOptions[1].selected).assertTrue()
      expect(viewModel.currentEntitlementRows[1].value).assertEqual('本地预览态')

      await MonetizationHubService.applyPreviewTier(getTestContext(), 'free')
      viewModel = await MonetizationHubService.createViewModel(getTestContext())

      expect(viewModel.tierText).assertEqual('Free')
      expect(viewModel.previewOptions[0].selected).assertTrue()
    })
  })
}
