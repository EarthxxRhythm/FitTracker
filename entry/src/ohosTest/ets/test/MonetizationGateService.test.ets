import { abilityDelegatorRegistry } from '@kit.TestKit'
import { afterAll, beforeAll, beforeEach, describe, expect, it } from '@ohos/hypium'
import SessionManager from '../../../main/ets/common/services/SessionManager'
import { MonetizationGateResult, createMonetizationEntitlement } from '../../../main/ets/shared/models/MonetizationModels'
import MonetizationEntitlementService from '../../../main/ets/shared/services/MonetizationEntitlementService'
import MonetizationGateService from '../../../main/ets/shared/services/MonetizationGateService'

function getTestContext(): Context {
  const appContext: Context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext()
  return appContext.getApplicationContext().createModuleContext('entry')
}

export default function monetizationGateServiceTest(): void {
  describe('MonetizationGateService', () => {
    beforeAll(() => {
      MonetizationEntitlementService.setEntitlementForTesting(null)
    })

    beforeEach(async () => {
      await SessionManager.clearToken(getTestContext())
      MonetizationEntitlementService.setEntitlementForTesting(null)
    })

    afterAll(async () => {
      await SessionManager.clearToken(getTestContext())
      MonetizationEntitlementService.setEntitlementForTesting(null)
    })

    it('keeps advanced insights blocked for free tier', 0, async () => {
      MonetizationEntitlementService.setEntitlementForTesting(
        createMonetizationEntitlement(
          '13600136000',
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

      const result: MonetizationGateResult = await MonetizationGateService.getGateResult(
        getTestContext(),
        'advanced_insights'
      )

      expect(result.allowed).assertFalse()
      expect(result.requiredTier).assertEqual('pro')
      expect(result.upgradeProductId).assertEqual('fittracker_pro_lifetime')
    })

    it('unlocks pro capabilities for pro tier', 0, async () => {
      MonetizationEntitlementService.setEntitlementForTesting(
        createMonetizationEntitlement(
          '13500135000',
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

      const insightsAllowed: boolean = await MonetizationGateService.canUse(getTestContext(), 'advanced_insights')
      const plansAllowed: boolean = await MonetizationGateService.canUse(getTestContext(), 'advanced_plans')
      const premiumContentAllowed: boolean = await MonetizationGateService.canUse(getTestContext(), 'premium_content')

      expect(insightsAllowed).assertTrue()
      expect(plansAllowed).assertTrue()
      expect(premiumContentAllowed).assertFalse()
    })

    it('unlocks plus-only capabilities for plus tier', 0, async () => {
      MonetizationEntitlementService.setEntitlementForTesting(
        createMonetizationEntitlement(
          '13400134000',
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

      const syncAllowed: boolean = await MonetizationGateService.canUse(getTestContext(), 'cloud_sync')
      const contentAllowed: boolean = await MonetizationGateService.canUse(getTestContext(), 'premium_content')

      expect(syncAllowed).assertTrue()
      expect(contentAllowed).assertTrue()
    })
  })
}
