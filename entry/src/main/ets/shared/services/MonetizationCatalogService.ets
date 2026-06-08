/**
 * MonetizationCatalogService -- fixed local monetization catalog and gate defaults.
 *
 * Phase 4: prewire logical SKU catalog before real IAP integration.
 */
import {
  MonetizationBillingEnvironment,
  MonetizationCapability,
  MonetizationProduct,
  MonetizationTier,
  createMonetizationProduct
} from '../models/MonetizationModels'

const PRO_PRODUCT_ID: string = 'fittracker_pro_lifetime'
const PLUS_MONTHLY_PRODUCT_ID: string = 'fittracker_plus_monthly'
const PLUS_YEARLY_PRODUCT_ID: string = 'fittracker_plus_yearly'
const PRO_SKU_KEY: string = 'pro_lifetime'
const PLUS_MONTHLY_SKU_KEY: string = 'plus_monthly'
const PLUS_YEARLY_SKU_KEY: string = 'plus_yearly'

class MonetizationCatalogService {
  private readonly products: MonetizationProduct[] = [
    createMonetizationProduct(PRO_SKU_KEY, PRO_PRODUCT_ID, 'pro', 'non_consumable', true),
    createMonetizationProduct(PLUS_MONTHLY_SKU_KEY, PLUS_MONTHLY_PRODUCT_ID, 'plus', 'subscription', false),
    createMonetizationProduct(PLUS_YEARLY_SKU_KEY, PLUS_YEARLY_PRODUCT_ID, 'plus', 'subscription', true)
  ]

  getProducts(): MonetizationProduct[] {
    return this.copyProducts(this.products)
  }

  getProduct(productId: string): MonetizationProduct | undefined {
    for (let index = 0; index < this.products.length; index++) {
      if (this.products[index].productId === productId) {
        return this.copyProduct(this.products[index])
      }
    }
    return undefined
  }

  getProductBySkuKey(skuKey: string): MonetizationProduct | undefined {
    for (let index = 0; index < this.products.length; index++) {
      if (this.products[index].skuKey === skuKey) {
        return this.copyProduct(this.products[index])
      }
    }
    return undefined
  }

  getPrimaryUpgradeForTier(tier: MonetizationTier): string {
    if (tier === 'plus') {
      return PLUS_YEARLY_PRODUCT_ID
    }
    if (tier === 'pro') {
      return PRO_PRODUCT_ID
    }
    return PRO_PRODUCT_ID
  }

  getDefaultUpgradeForCapability(capability: MonetizationCapability): string {
    if (capability === 'cloud_sync' || capability === 'premium_content') {
      return PLUS_YEARLY_PRODUCT_ID
    }
    return PRO_PRODUCT_ID
  }

  getBillingEnvironment(): MonetizationBillingEnvironment {
    return 'disabled'
  }

  private copyProducts(source: MonetizationProduct[]): MonetizationProduct[] {
    const products: MonetizationProduct[] = []
    for (let index = 0; index < source.length; index++) {
      products.push(this.copyProduct(source[index]))
    }
    return products
  }

  private copyProduct(source: MonetizationProduct): MonetizationProduct {
    return createMonetizationProduct(
      source.skuKey,
      source.productId,
      source.tier,
      source.billingType,
      source.isPrimaryOffer
    )
  }
}

export default new MonetizationCatalogService()
