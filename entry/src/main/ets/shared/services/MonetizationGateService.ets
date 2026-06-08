/**
 * MonetizationGateService -- resolves capability access from local entitlement state.
 *
 * Phase 4: centralize monetization gate checks before any page-level wiring.
 */
import { Context } from '@kit.AbilityKit'
import MonetizationCatalogService from './MonetizationCatalogService'
import MonetizationEntitlementService from './MonetizationEntitlementService'
import {
  MonetizationCapability,
  MonetizationEntitlement,
  MonetizationGateResult,
  MonetizationTier,
  ResolvedAccessState,
  createMonetizationGateResult,
  createResolvedAccessState
} from '../models/MonetizationModels'

class MonetizationGateService {
  async getGateResult(context: Context, capability: MonetizationCapability): Promise<MonetizationGateResult> {
    const state: ResolvedAccessState = await this.resolveAccessState(context)
    const requiredTier: MonetizationTier = this.getRequiredTier(capability)
    const allowed: boolean = this.isCapabilityAllowed(state, capability)
    return createMonetizationGateResult(
      capability,
      allowed,
      requiredTier,
      state.tier,
      MonetizationCatalogService.getDefaultUpgradeForCapability(capability),
      allowed ? '' : this.getBlockedReason(capability)
    )
  }

  async canUse(context: Context, capability: MonetizationCapability): Promise<boolean> {
    const result: MonetizationGateResult = await this.getGateResult(context, capability)
    return result.allowed
  }

  async resolveAccessState(context: Context): Promise<ResolvedAccessState> {
    const entitlement: MonetizationEntitlement = await MonetizationEntitlementService.resolveCurrentUserEntitlement(context)
    const tier: MonetizationTier = entitlement.tier
    const proEnabled: boolean = tier === 'pro' || tier === 'plus'
    const plusEnabled: boolean = tier === 'plus'
    return createResolvedAccessState(
      tier,
      proEnabled,
      proEnabled,
      proEnabled,
      plusEnabled,
      plusEnabled,
      proEnabled,
      '',
      Date.now()
    )
  }

  private isCapabilityAllowed(state: ResolvedAccessState, capability: MonetizationCapability): boolean {
    if (capability === 'advanced_insights') {
      return state.canUseAdvancedInsights
    }
    if (capability === 'unlimited_history') {
      return state.canUseUnlimitedHistory
    }
    if (capability === 'advanced_plans') {
      return state.canUseAdvancedPlans
    }
    if (capability === 'cloud_sync') {
      return state.canUseCloudSync
    }
    if (capability === 'premium_content') {
      return state.canUsePremiumContent
    }
    return state.canUseEnhancedGoalAdjustment
  }

  private getRequiredTier(capability: MonetizationCapability): MonetizationTier {
    if (capability === 'cloud_sync' || capability === 'premium_content') {
      return 'plus'
    }
    return 'pro'
  }

  private getBlockedReason(capability: MonetizationCapability): string {
    if (capability === 'cloud_sync') {
      return 'requires_plus_for_cloud_sync'
    }
    if (capability === 'premium_content') {
      return 'requires_plus_for_premium_content'
    }
    if (capability === 'advanced_plans') {
      return 'requires_pro_for_advanced_plans'
    }
    if (capability === 'unlimited_history') {
      return 'requires_pro_for_unlimited_history'
    }
    if (capability === 'enhanced_goal_adjustment') {
      return 'requires_pro_for_goal_adjustment'
    }
    return 'requires_pro_for_advanced_insights'
  }
}

export default new MonetizationGateService()
