import { abilityDelegatorRegistry } from '@kit.TestKit'
import { afterAll, beforeAll, beforeEach, describe, expect, it } from '@ohos/hypium'
import SessionManager from '../../../main/ets/common/services/SessionManager'
import {
  MonetizationEntitlement,
  createMonetizationEntitlement
} from '../../../main/ets/shared/models/MonetizationModels'
import MonetizationEntitlementService, {
  MonetizationEntitlementStore
} from '../../../main/ets/shared/services/MonetizationEntitlementService'

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

function createActiveEntitlement(tier: 'free' | 'pro' | 'plus', userId: string): MonetizationEntitlement {
  return createMonetizationEntitlement(
    userId,
    tier,
    tier === 'free' ? 'local_default' : 'iap_purchase',
    'active',
    tier === 'pro' ? 'pro_lifetime' : tier === 'plus' ? 'plus_yearly' : '',
    tier === 'pro' ? 'fittracker_pro_lifetime' : tier === 'plus' ? 'fittracker_plus_yearly' : '',
    100,
    tier === 'plus' ? Date.now() + 60000 : 0,
    100,
    100,
    1
  )
}

export default function monetizationEntitlementServiceTest(): void {
  const fakeStore = new FakeMonetizationEntitlementStore()

  describe('MonetizationEntitlementService', () => {
    beforeAll(() => {
      MonetizationEntitlementService.setStoreForTesting(fakeStore)
    })

    beforeEach(async () => {
      fakeStore.clear()
      MonetizationEntitlementService.setEntitlementForTesting(null)
      await SessionManager.clearToken(getTestContext())
    })

    afterAll(async () => {
      await SessionManager.clearToken(getTestContext())
      MonetizationEntitlementService.setEntitlementForTesting(null)
      MonetizationEntitlementService.setStoreForTesting(null)
    })

    it('returns free local default entitlement when no snapshot exists', 0, async () => {
      const token: string = SessionManager.generateToken('13800138000')
      await SessionManager.saveToken(getTestContext(), token)

      const entitlement: MonetizationEntitlement = await MonetizationEntitlementService.readEntitlement(getTestContext())

      expect(entitlement.userId).assertEqual('13800138000')
      expect(entitlement.tier).assertEqual('free')
      expect(entitlement.source).assertEqual('local_default')
      expect(entitlement.productId).assertEqual('')
    })

    it('persists and reloads a pro entitlement for the current user', 0, async () => {
      const token: string = SessionManager.generateToken('13900139000')
      await SessionManager.saveToken(getTestContext(), token)

      await MonetizationEntitlementService.writeEntitlement(
        getTestContext(),
        createActiveEntitlement('pro', '')
      )

      const entitlement: MonetizationEntitlement = await MonetizationEntitlementService.readEntitlement(getTestContext())

      expect(entitlement.userId).assertEqual('13900139000')
      expect(entitlement.tier).assertEqual('pro')
      expect(entitlement.skuKey).assertEqual('pro_lifetime')
      expect(entitlement.productId).assertEqual('fittracker_pro_lifetime')
    })

    it('normalizes expired plus entitlement back to free', 0, async () => {
      const token: string = SessionManager.generateToken('13700137000')
      await SessionManager.saveToken(getTestContext(), token)
      await MonetizationEntitlementService.writeEntitlement(
        getTestContext(),
        createMonetizationEntitlement(
          '',
          'plus',
          'iap_purchase',
          'active',
          'plus_yearly',
          'fittracker_plus_yearly',
          100,
          Date.now() - 1000,
          100,
          100,
          1
        )
      )

      const entitlement: MonetizationEntitlement = await MonetizationEntitlementService.readEntitlement(getTestContext())

      expect(entitlement.tier).assertEqual('free')
      expect(entitlement.productId).assertEqual('')
      expect(entitlement.source).assertEqual('local_default')
    })
  })
}
