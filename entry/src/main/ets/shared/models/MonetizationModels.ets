/**
 * MonetizationModels -- shared entitlement and feature-gate contracts.
 *
 * Phase 4: monetization prewire models for local entitlement and capability gating.
 */

export type MonetizationTier = 'free' | 'pro' | 'plus'
export type MonetizationSource = 'local_default' | 'iap_purchase' | 'restored_purchase' | 'debug_override'
export type MonetizationStatus = 'active' | 'expired'
export type MonetizationBillingType = 'non_consumable' | 'subscription'
export type MonetizationCapability =
  | 'advanced_insights'
  | 'unlimited_history'
  | 'advanced_plans'
  | 'cloud_sync'
  | 'premium_content'
  | 'enhanced_goal_adjustment'
export type MonetizationBillingEnvironment = 'disabled' | 'mock' | 'sandbox' | 'production'

export interface MonetizationEntitlement {
  userId: string
  tier: MonetizationTier
  source: MonetizationSource
  status: MonetizationStatus
  skuKey: string
  productId: string
  grantedAt: number
  expiresAt: number
  updatedAt: number
  lastValidatedAt: number
  schemaVersion: number
}

export interface MonetizationProduct {
  skuKey: string
  productId: string
  tier: MonetizationTier
  billingType: MonetizationBillingType
  isPrimaryOffer: boolean
}

export interface MonetizationGateResult {
  capability: MonetizationCapability
  allowed: boolean
  requiredTier: MonetizationTier
  activeTier: MonetizationTier
  upgradeProductId: string
  reason: string
}

export interface ResolvedAccessState {
  tier: MonetizationTier
  canUseAdvancedInsights: boolean
  canUseUnlimitedHistory: boolean
  canUseAdvancedPlans: boolean
  canUseCloudSync: boolean
  canUsePremiumContent: boolean
  canUseEnhancedGoalAdjustment: boolean
  blockedReason: string
  evaluatedAt: number
}

export function createMonetizationEntitlement(
  userId: string,
  tier: MonetizationTier,
  source: MonetizationSource,
  status: MonetizationStatus,
  skuKey: string,
  productId: string,
  grantedAt: number,
  expiresAt: number,
  updatedAt: number,
  lastValidatedAt: number,
  schemaVersion: number
): MonetizationEntitlement {
  const item: MonetizationEntitlement = {
    userId: userId,
    tier: tier,
    source: source,
    status: status,
    skuKey: skuKey,
    productId: productId,
    grantedAt: grantedAt,
    expiresAt: expiresAt,
    updatedAt: updatedAt,
    lastValidatedAt: lastValidatedAt,
    schemaVersion: schemaVersion
  }
  return item
}

export function createMonetizationProduct(
  skuKey: string,
  productId: string,
  tier: MonetizationTier,
  billingType: MonetizationBillingType,
  isPrimaryOffer: boolean
): MonetizationProduct {
  const item: MonetizationProduct = {
    skuKey: skuKey,
    productId: productId,
    tier: tier,
    billingType: billingType,
    isPrimaryOffer: isPrimaryOffer
  }
  return item
}

export function createMonetizationGateResult(
  capability: MonetizationCapability,
  allowed: boolean,
  requiredTier: MonetizationTier,
  activeTier: MonetizationTier,
  upgradeProductId: string,
  reason: string
): MonetizationGateResult {
  const item: MonetizationGateResult = {
    capability: capability,
    allowed: allowed,
    requiredTier: requiredTier,
    activeTier: activeTier,
    upgradeProductId: upgradeProductId,
    reason: reason
  }
  return item
}

export function createResolvedAccessState(
  tier: MonetizationTier,
  canUseAdvancedInsights: boolean,
  canUseUnlimitedHistory: boolean,
  canUseAdvancedPlans: boolean,
  canUseCloudSync: boolean,
  canUsePremiumContent: boolean,
  canUseEnhancedGoalAdjustment: boolean,
  blockedReason: string,
  evaluatedAt: number
): ResolvedAccessState {
  const item: ResolvedAccessState = {
    tier: tier,
    canUseAdvancedInsights: canUseAdvancedInsights,
    canUseUnlimitedHistory: canUseUnlimitedHistory,
    canUseAdvancedPlans: canUseAdvancedPlans,
    canUseCloudSync: canUseCloudSync,
    canUsePremiumContent: canUsePremiumContent,
    canUseEnhancedGoalAdjustment: canUseEnhancedGoalAdjustment,
    blockedReason: blockedReason,
    evaluatedAt: evaluatedAt
  }
  return item
}
