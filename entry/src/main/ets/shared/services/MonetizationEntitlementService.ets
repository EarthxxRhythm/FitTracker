/**
 * MonetizationEntitlementService -- local entitlement snapshot storage and current-user resolution.
 *
 * Phase 4: prewire entitlement cache before real IAP integration.
 */
import { Context } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { FitTrackerStores } from '../../app/AppState'
import SessionManager from '../../common/services/SessionManager'
import {
  MonetizationEntitlement,
  MonetizationTier,
  createMonetizationEntitlement
} from '../models/MonetizationModels'

const KEY_USER_ENTITLEMENTS: string = 'user_entitlements'
const ENTITLEMENT_SCHEMA_VERSION: number = 1

export abstract class MonetizationEntitlementStore {
  abstract get(key: string, defaultValue: string): Promise<string>
  abstract put(key: string, value: string): Promise<void>
  abstract flush(): Promise<void>
}

class ArkPreferencesMonetizationEntitlementStore extends MonetizationEntitlementStore {
  private readonly prefs: preferences.Preferences

  constructor(prefs: preferences.Preferences) {
    super()
    this.prefs = prefs
  }

  async get(key: string, defaultValue: string): Promise<string> {
    return await this.prefs.get(key, defaultValue) as string
  }

  async put(key: string, value: string): Promise<void> {
    await this.prefs.put(key, value)
  }

  async flush(): Promise<void> {
    await this.prefs.flush()
  }
}

class MonetizationEntitlementService {
  private testStore: MonetizationEntitlementStore | null = null
  private testEntitlement: MonetizationEntitlement | null = null

  setStoreForTesting(store: MonetizationEntitlementStore | null): void {
    this.testStore = store
  }

  setEntitlementForTesting(entitlement: MonetizationEntitlement | null): void {
    this.testEntitlement = entitlement === null ? null : this.copyEntitlement(entitlement)
  }

  async clearEntitlementForTesting(context: Context): Promise<void> {
    const store: MonetizationEntitlementStore = await this.getStore(context)
    await store.put(KEY_USER_ENTITLEMENTS, '[]')
    await store.flush()
    this.testEntitlement = null
  }

  async readEntitlement(context: Context): Promise<MonetizationEntitlement> {
    return await this.resolveCurrentUserEntitlement(context)
  }

  async resolveCurrentUserEntitlement(context: Context): Promise<MonetizationEntitlement> {
    if (this.testEntitlement !== null) {
      return this.normalizeEntitlement(this.testEntitlement)
    }
    const userId: string = await this.getCurrentUserId(context)
    const snapshots: MonetizationEntitlement[] = await this.readAllSnapshots(context)
    for (let index = 0; index < snapshots.length; index++) {
      if (snapshots[index].userId === userId) {
        return this.normalizeEntitlement(snapshots[index])
      }
    }
    return this.createDefaultEntitlement(userId)
  }

  async writeEntitlement(context: Context, entitlement: MonetizationEntitlement): Promise<void> {
    const resolvedUserId: string = entitlement.userId.length > 0 ? entitlement.userId : await this.getCurrentUserId(context)
    const snapshots: MonetizationEntitlement[] = await this.readAllSnapshots(context)
    const normalized: MonetizationEntitlement = this.normalizeEntitlement(this.copyEntitlementWithUserId(entitlement, resolvedUserId))
    let replaced: boolean = false
    for (let index = 0; index < snapshots.length; index++) {
      if (snapshots[index].userId === resolvedUserId) {
        snapshots[index] = normalized
        replaced = true
        break
      }
    }
    if (!replaced) {
      snapshots.push(normalized)
    }
    const store: MonetizationEntitlementStore = await this.getStore(context)
    await store.put(KEY_USER_ENTITLEMENTS, JSON.stringify(this.copyEntitlements(snapshots)))
    await store.flush()
  }

  async getActiveTier(context: Context): Promise<MonetizationTier> {
    const entitlement: MonetizationEntitlement = await this.resolveCurrentUserEntitlement(context)
    return entitlement.tier
  }

  async isSubscriptionActive(context: Context): Promise<boolean> {
    const entitlement: MonetizationEntitlement = await this.resolveCurrentUserEntitlement(context)
    return entitlement.tier === 'plus' && entitlement.status === 'active'
  }

  private async readAllSnapshots(context: Context): Promise<MonetizationEntitlement[]> {
    const store: MonetizationEntitlementStore = await this.getStore(context)
    const json: string = await store.get(KEY_USER_ENTITLEMENTS, '[]')
    if (json.trim().length === 0) {
      return []
    }
    try {
      const parsed: MonetizationEntitlement[] = JSON.parse(json) as MonetizationEntitlement[]
      return this.copyEntitlements(parsed)
    } catch (error) {
      return []
    }
  }

  private async getCurrentUserId(context: Context): Promise<string> {
    try {
      const token: string | null = await SessionManager.getToken(context)
      if (token === null) {
        return ''
      }
      return SessionManager.getUserIdFromToken(token)
    } catch (error) {
      return ''
    }
  }

  private normalizeEntitlement(source: MonetizationEntitlement): MonetizationEntitlement {
    const now: number = Date.now()
    let status: 'active' | 'expired' = source.status
    let tier: MonetizationTier = source.tier
    if (tier === 'plus' && source.expiresAt > 0 && source.expiresAt <= now) {
      status = 'expired'
      tier = 'free'
    }
    if (status === 'expired') {
      tier = 'free'
    }
    if (tier === 'free') {
      return createMonetizationEntitlement(
        source.userId,
        'free',
        source.source === 'debug_override' ? 'debug_override' : 'local_default',
        'active',
        '',
        '',
        source.grantedAt,
        0,
        source.updatedAt,
        source.lastValidatedAt,
        ENTITLEMENT_SCHEMA_VERSION
      )
    }
    return createMonetizationEntitlement(
      source.userId,
      tier,
      source.source,
      status,
      source.skuKey,
      source.productId,
      source.grantedAt,
      source.expiresAt,
      source.updatedAt,
      source.lastValidatedAt,
      ENTITLEMENT_SCHEMA_VERSION
    )
  }

  private createDefaultEntitlement(userId: string): MonetizationEntitlement {
    return createMonetizationEntitlement(
      userId,
      'free',
      'local_default',
      'active',
      '',
      '',
      0,
      0,
      0,
      0,
      ENTITLEMENT_SCHEMA_VERSION
    )
  }

  private async getStore(context: Context): Promise<MonetizationEntitlementStore> {
    if (this.testStore !== null) {
      return this.testStore
    }
    const prefs: preferences.Preferences = await preferences.getPreferences(context, FitTrackerStores.MONETIZATION)
    return new ArkPreferencesMonetizationEntitlementStore(prefs)
  }

  private copyEntitlements(source: MonetizationEntitlement[]): MonetizationEntitlement[] {
    const values: MonetizationEntitlement[] = []
    for (let index = 0; index < source.length; index++) {
      if (this.isValidEntitlement(source[index])) {
        values.push(this.copyEntitlement(source[index]))
      }
    }
    return values
  }

  private copyEntitlement(source: MonetizationEntitlement): MonetizationEntitlement {
    return createMonetizationEntitlement(
      source.userId,
      source.tier,
      source.source,
      source.status,
      source.skuKey,
      source.productId,
      source.grantedAt,
      source.expiresAt,
      source.updatedAt,
      source.lastValidatedAt,
      source.schemaVersion
    )
  }

  private copyEntitlementWithUserId(source: MonetizationEntitlement, userId: string): MonetizationEntitlement {
    return createMonetizationEntitlement(
      userId,
      source.tier,
      source.source,
      source.status,
      source.skuKey,
      source.productId,
      source.grantedAt,
      source.expiresAt,
      source.updatedAt,
      source.lastValidatedAt,
      ENTITLEMENT_SCHEMA_VERSION
    )
  }

  private isValidEntitlement(source: MonetizationEntitlement): boolean {
    return source !== undefined &&
      source !== null &&
      typeof source.userId === 'string' &&
      typeof source.tier === 'string' &&
      typeof source.source === 'string' &&
      typeof source.status === 'string' &&
      typeof source.skuKey === 'string' &&
      typeof source.productId === 'string' &&
      Number.isFinite(source.grantedAt) &&
      Number.isFinite(source.expiresAt) &&
      Number.isFinite(source.updatedAt) &&
      Number.isFinite(source.lastValidatedAt) &&
      Number.isFinite(source.schemaVersion)
  }
}

export default new MonetizationEntitlementService()
