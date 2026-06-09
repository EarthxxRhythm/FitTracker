/**
 * MonetizationHubService -- builds the membership status page model and local preview controls.
 *
 * Phase 4: keep the monetization surface honest in disabled billing mode while
 * still providing a complete local demonstration loop for entitlement states.
 */
import { Context } from '@kit.AbilityKit'
import {
  MonetizationBillingEnvironment,
  MonetizationCapability,
  MonetizationEntitlement,
  MonetizationProduct,
  MonetizationTier,
  createMonetizationEntitlement
} from '../models/MonetizationModels'
import MonetizationCatalogService from './MonetizationCatalogService'
import MonetizationEntitlementService from './MonetizationEntitlementService'

const ENTITLEMENT_SCHEMA_VERSION: number = 1
const PLUS_PREVIEW_DURATION_MS: number = 365 * 24 * 60 * 60 * 1000

export interface MonetizationOfferCardViewModel {
  productId: string
  title: string
  badgeText: string
  priceText: string
  billingText: string
  description: string
  statusText: string
  highlighted: boolean
  current: boolean
  featureBullets: string[]
}

export interface MonetizationRoadmapItemViewModel {
  capabilityKey: string
  title: string
  tierText: string
  statusText: string
  summary: string
}

export interface MonetizationInfoRowViewModel {
  label: string
  value: string
}

export interface MonetizationPreviewOptionViewModel {
  tier: MonetizationTier
  label: string
  note: string
  selected: boolean
}

export interface MonetizationHubFocusContextViewModel {
  active: boolean
  sourceLabel: string
  title: string
  description: string
  recommendedTierText: string
}

export interface MonetizationHubViewModel {
  tierText: string
  heroTitle: string
  heroDescription: string
  environmentText: string
  noticeText: string
  focusContext: MonetizationHubFocusContextViewModel
  freeIncludedBullets: string[]
  currentEntitlementRows: MonetizationInfoRowViewModel[]
  previewEnabled: boolean
  previewTitle: string
  previewDescription: string
  previewStatusText: string
  previewOptions: MonetizationPreviewOptionViewModel[]
  offerCards: MonetizationOfferCardViewModel[]
  roadmapItems: MonetizationRoadmapItemViewModel[]
}

function copyStringArray(source: string[]): string[] {
  const values: string[] = []
  for (let index = 0; index < source.length; index++) {
    values.push(source[index])
  }
  return values
}

function createOfferCardViewModel(
  productId: string,
  title: string,
  badgeText: string,
  priceText: string,
  billingText: string,
  description: string,
  statusText: string,
  highlighted: boolean,
  current: boolean,
  featureBullets: string[]
): MonetizationOfferCardViewModel {
  const item: MonetizationOfferCardViewModel = {
    productId: productId,
    title: title,
    badgeText: badgeText,
    priceText: priceText,
    billingText: billingText,
    description: description,
    statusText: statusText,
    highlighted: highlighted,
    current: current,
    featureBullets: copyStringArray(featureBullets)
  }
  return item
}

function createRoadmapItemViewModel(
  capabilityKey: string,
  title: string,
  tierText: string,
  statusText: string,
  summary: string
): MonetizationRoadmapItemViewModel {
  const item: MonetizationRoadmapItemViewModel = {
    capabilityKey: capabilityKey,
    title: title,
    tierText: tierText,
    statusText: statusText,
    summary: summary
  }
  return item
}

function createInfoRowViewModel(label: string, value: string): MonetizationInfoRowViewModel {
  const item: MonetizationInfoRowViewModel = {
    label: label,
    value: value
  }
  return item
}

function createPreviewOptionViewModel(
  tier: MonetizationTier,
  label: string,
  note: string,
  selected: boolean
): MonetizationPreviewOptionViewModel {
  const item: MonetizationPreviewOptionViewModel = {
    tier: tier,
    label: label,
    note: note,
    selected: selected
  }
  return item
}

function copyOfferCards(source: MonetizationOfferCardViewModel[]): MonetizationOfferCardViewModel[] {
  const cards: MonetizationOfferCardViewModel[] = []
  for (let index = 0; index < source.length; index++) {
    const item: MonetizationOfferCardViewModel = source[index]
    cards.push(createOfferCardViewModel(
      item.productId,
      item.title,
      item.badgeText,
      item.priceText,
      item.billingText,
      item.description,
      item.statusText,
      item.highlighted,
      item.current,
      item.featureBullets
    ))
  }
  return cards
}

function copyRoadmapItems(source: MonetizationRoadmapItemViewModel[]): MonetizationRoadmapItemViewModel[] {
  const items: MonetizationRoadmapItemViewModel[] = []
  for (let index = 0; index < source.length; index++) {
    const item: MonetizationRoadmapItemViewModel = source[index]
    items.push(createRoadmapItemViewModel(
      item.capabilityKey,
      item.title,
      item.tierText,
      item.statusText,
      item.summary
    ))
  }
  return items
}

function copyInfoRows(source: MonetizationInfoRowViewModel[]): MonetizationInfoRowViewModel[] {
  const rows: MonetizationInfoRowViewModel[] = []
  for (let index = 0; index < source.length; index++) {
    rows.push(createInfoRowViewModel(source[index].label, source[index].value))
  }
  return rows
}

function copyPreviewOptions(source: MonetizationPreviewOptionViewModel[]): MonetizationPreviewOptionViewModel[] {
  const options: MonetizationPreviewOptionViewModel[] = []
  for (let index = 0; index < source.length; index++) {
    const item: MonetizationPreviewOptionViewModel = source[index]
    options.push(createPreviewOptionViewModel(item.tier, item.label, item.note, item.selected))
  }
  return options
}

function createFocusContextViewModel(
  active: boolean,
  sourceLabel: string,
  title: string,
  description: string,
  recommendedTierText: string
): MonetizationHubFocusContextViewModel {
  const item: MonetizationHubFocusContextViewModel = {
    active: active,
    sourceLabel: sourceLabel,
    title: title,
    description: description,
    recommendedTierText: recommendedTierText
  }
  return item
}

function createMonetizationHubViewModel(
  tierText: string,
  heroTitle: string,
  heroDescription: string,
  environmentText: string,
  noticeText: string,
  freeIncludedBullets: string[],
  currentEntitlementRows: MonetizationInfoRowViewModel[],
  previewEnabled: boolean,
  previewTitle: string,
  previewDescription: string,
  previewStatusText: string,
  previewOptions: MonetizationPreviewOptionViewModel[],
  offerCards: MonetizationOfferCardViewModel[],
  roadmapItems: MonetizationRoadmapItemViewModel[],
  focusContext?: MonetizationHubFocusContextViewModel
): MonetizationHubViewModel {
  let resolvedFocusContext: MonetizationHubFocusContextViewModel = createFocusContextViewModel(false, '', '', '', '')
  if (focusContext !== undefined) {
    resolvedFocusContext = focusContext
  }
  const item: MonetizationHubViewModel = {
    tierText: tierText,
    heroTitle: heroTitle,
    heroDescription: heroDescription,
    environmentText: environmentText,
    noticeText: noticeText,
    focusContext: resolvedFocusContext,
    freeIncludedBullets: copyStringArray(freeIncludedBullets),
    currentEntitlementRows: copyInfoRows(currentEntitlementRows),
    previewEnabled: previewEnabled,
    previewTitle: previewTitle,
    previewDescription: previewDescription,
    previewStatusText: previewStatusText,
    previewOptions: copyPreviewOptions(previewOptions),
    offerCards: copyOfferCards(offerCards),
    roadmapItems: copyRoadmapItems(roadmapItems)
  }
  return item
}

class MonetizationHubService {
  createEmptyViewModel(): MonetizationHubViewModel {
    return createMonetizationHubViewModel(
      'Free',
      '正在加载权益结构',
      '读取当前账号层级、商品结构与能力规划。',
      '支付环境：未接入',
      '当前页面用于说明权益边界与本地预览状态。',
      [],
      [],
      false,
      '',
      '',
      '',
      [],
      [],
      []
    )
  }

  async createViewModel(
    context: Context,
    focusCapability: MonetizationCapability | '' = '',
    sourceLabel: string = ''
  ): Promise<MonetizationHubViewModel> {
    const entitlement: MonetizationEntitlement = await MonetizationEntitlementService.readEntitlement(context)
    const products: MonetizationProduct[] = MonetizationCatalogService.getProducts()
    const environment: MonetizationBillingEnvironment = MonetizationCatalogService.getBillingEnvironment()
    const focusContext: MonetizationHubFocusContextViewModel = this.createFocusContext(focusCapability, sourceLabel)
    return createMonetizationHubViewModel(
      this.getTierText(entitlement.tier),
      this.getHeroTitle(entitlement.tier),
      this.getHeroDescription(entitlement.tier),
      this.getEnvironmentText(environment),
      this.getNoticeText(environment, entitlement.source),
      [
        '基础训练主流程继续保持完整可用',
        '本地备份与恢复继续保留在 Free',
        '本地内容同步基础与动作详情基础信息继续保留在 Free'
      ],
      this.createCurrentEntitlementRows(entitlement),
      this.isPreviewEnabled(environment),
      '本地权益预览',
      '当前环境未接支付，可直接切换 Free / Pro / Plus 预览态，用来验证入口文案、降级态和后续页面消费逻辑。',
      this.getPreviewStatusText(entitlement),
      this.createPreviewOptions(entitlement.tier, environment),
      this.createOfferCards(products, entitlement, focusCapability),
      this.createRoadmapItems(focusCapability),
      focusContext
    )
  }

  async applyPreviewTier(context: Context, tier: MonetizationTier): Promise<void> {
    const environment: MonetizationBillingEnvironment = MonetizationCatalogService.getBillingEnvironment()
    if (!this.isPreviewEnabled(environment)) {
      return
    }
    const current: MonetizationEntitlement = await MonetizationEntitlementService.readEntitlement(context)
    await MonetizationEntitlementService.writeEntitlement(context, this.createPreviewEntitlement(current.userId, tier))
  }

  private createPreviewEntitlement(userId: string, tier: MonetizationTier): MonetizationEntitlement {
    const now: number = Date.now()
    if (tier === 'pro') {
      return createMonetizationEntitlement(
        userId,
        'pro',
        'debug_override',
        'active',
        'pro_lifetime',
        'fittracker_pro_lifetime',
        now,
        0,
        now,
        now,
        ENTITLEMENT_SCHEMA_VERSION
      )
    }
    if (tier === 'plus') {
      return createMonetizationEntitlement(
        userId,
        'plus',
        'debug_override',
        'active',
        'plus_yearly',
        'fittracker_plus_yearly',
        now,
        now + PLUS_PREVIEW_DURATION_MS,
        now,
        now,
        ENTITLEMENT_SCHEMA_VERSION
      )
    }
    return createMonetizationEntitlement(
      userId,
      'free',
      'local_default',
      'active',
      '',
      '',
      now,
      0,
      now,
      now,
      ENTITLEMENT_SCHEMA_VERSION
    )
  }

  private createCurrentEntitlementRows(entitlement: MonetizationEntitlement): MonetizationInfoRowViewModel[] {
    const rows: MonetizationInfoRowViewModel[] = []
    rows.push(createInfoRowViewModel('当前层级', this.getTierText(entitlement.tier)))
    rows.push(createInfoRowViewModel('状态来源', this.getSourceText(entitlement.source)))
    rows.push(createInfoRowViewModel('当前商品', this.getCurrentProductText(entitlement)))
    rows.push(createInfoRowViewModel('到期时间', this.getExpiryText(entitlement)))
    return rows
  }

  private createPreviewOptions(
    selectedTier: MonetizationTier,
    environment: MonetizationBillingEnvironment
  ): MonetizationPreviewOptionViewModel[] {
    const options: MonetizationPreviewOptionViewModel[] = []
    if (!this.isPreviewEnabled(environment)) {
      return options
    }
    options.push(createPreviewOptionViewModel('free', 'Free', '完整主链', selectedTier === 'free'))
    options.push(createPreviewOptionViewModel('pro', 'Pro', '本地高级能力', selectedTier === 'pro'))
    options.push(createPreviewOptionViewModel('plus', 'Plus', '持续服务层', selectedTier === 'plus'))
    return options
  }

  private createOfferCards(
    products: MonetizationProduct[],
    entitlement: MonetizationEntitlement,
    focusCapability: MonetizationCapability | ''
  ): MonetizationOfferCardViewModel[] {
    const cards: MonetizationOfferCardViewModel[] = []
    for (let index = 0; index < products.length; index++) {
      const product: MonetizationProduct = products[index]
      cards.push(this.createOfferCard(product, entitlement, focusCapability))
    }
    return cards
  }

  private createOfferCard(
    product: MonetizationProduct,
    entitlement: MonetizationEntitlement,
    focusCapability: MonetizationCapability | ''
  ): MonetizationOfferCardViewModel {
    const current: boolean = entitlement.productId.length > 0 && entitlement.productId === product.productId
    const highlighted: boolean = this.isHighlightedOffer(product, entitlement.tier, focusCapability)
    return createOfferCardViewModel(
      product.productId,
      this.getOfferTitle(product.productId),
      this.getOfferBadgeText(product.productId),
      this.getOfferPriceText(product.productId),
      this.getBillingText(product.productId),
      this.getOfferDescription(product.productId),
      this.getOfferStatusText(product, entitlement, current),
      highlighted,
      current,
      this.getOfferBullets(product.productId)
    )
  }

  private createRoadmapItems(focusCapability: MonetizationCapability | ''): MonetizationRoadmapItemViewModel[] {
    const items: MonetizationRoadmapItemViewModel[] = []
    items.push(createRoadmapItemViewModel(
      'advanced_insights',
      '高级洞察入口',
      'Pro',
      '已接入入口',
      '回顾页已经可以进入权益说明，后续会在这里承接更深趋势和 PR 解释。'
    ))
    items.push(createRoadmapItemViewModel(
      'unlimited_history',
      '无限历史记录',
      'Pro',
      '策略已定义',
      '历史记录的付费边界已明确，但当前仍保持完整免费链路。'
    ))
    items.push(createRoadmapItemViewModel(
      'advanced_plans',
      '更多自定义计划',
      'Pro',
      '待接入',
      '适合承接多目标、多阶段训练用户，是最贴近本地工具价值的下一个付费点。'
    ))
    items.push(createRoadmapItemViewModel(
      'cloud_sync',
      '云同步与多设备连续性',
      'Plus',
      '后续阶段',
      '依赖远端账号与同步能力，不会在 Free 主链里强行抢入口。'
    ))
    items.push(createRoadmapItemViewModel(
      'premium_content',
      '持续内容更新与更完整媒体库',
      'Plus',
      '后续阶段',
      '适合放在持续服务层，而不是本地买断层。'
    ))
    if (focusCapability.length > 0) {
      const sortedItems: MonetizationRoadmapItemViewModel[] = []
      for (let index = 0; index < items.length; index++) {
        if (items[index].capabilityKey === focusCapability) {
          sortedItems.push(items[index])
        }
      }
      for (let index = 0; index < items.length; index++) {
        if (items[index].capabilityKey !== focusCapability) {
          sortedItems.push(items[index])
        }
      }
      return sortedItems
    }
    return items
  }

  private createFocusContext(
    focusCapability: MonetizationCapability | '',
    sourceLabel: string
  ): MonetizationHubFocusContextViewModel {
    if (focusCapability === '') {
      return createFocusContextViewModel(false, '', '', '', '')
    }
    if (focusCapability === 'advanced_plans') {
      return createFocusContextViewModel(
        true,
        this.getFocusSourceLabel(sourceLabel, '训练计划详情'),
        '继续当前计划，解锁高级变体',
        '当前预置计划已经可以直接使用；升级后可在同一套计划上切到高容量、高密度或恢复优先版本。',
        'Pro'
      )
    }
    if (focusCapability === 'premium_content') {
      return createFocusContextViewModel(
        true,
        this.getFocusSourceLabel(sourceLabel, '动作详情'),
        '在动作详情里获得更深指导',
        '基础动作说明保持免费；升级后可查看训练放置、进阶焦点、替代策略和更细的训练清单。',
        'Plus'
      )
    }
    if (focusCapability === 'unlimited_history') {
      return createFocusContextViewModel(
        true,
        this.getFocusSourceLabel(sourceLabel, '训练回顾'),
        '查看完整训练历史',
        '当前回顾页优先保留近期训练可读性；升级后可放开完整历史筛选，支持更长周期复盘。',
        'Pro'
      )
    }
    if (focusCapability === 'advanced_insights') {
      return createFocusContextViewModel(
        true,
        this.getFocusSourceLabel(sourceLabel, '训练回顾'),
        '解锁更深的训练洞察',
        '基础回顾仍然可用；升级后可继续查看更细的周趋势、动作 PR 线索和训练解释。',
        'Pro'
      )
    }
    if (focusCapability === 'cloud_sync') {
      return createFocusContextViewModel(
        true,
        this.getFocusSourceLabel(sourceLabel, '设置与同步'),
        '跨设备连续使用',
        '这部分适合放在持续服务层，用来承接云同步、多设备延续和远端内容更新。',
        'Plus'
      )
    }
    return createFocusContextViewModel(
      true,
      this.getFocusSourceLabel(sourceLabel, '会员入口'),
      '解锁更多高级能力',
      '当前训练主链保持可用；升级层只承接更深分析、更强工具和后续持续服务。',
      'Pro'
    )
  }

  private isPreviewEnabled(environment: MonetizationBillingEnvironment): boolean {
    return environment === 'disabled' || environment === 'mock'
  }

  private getTierText(tier: MonetizationTier): string {
    if (tier === 'pro') {
      return 'Pro'
    }
    if (tier === 'plus') {
      return 'Plus'
    }
    return 'Free'
  }

  private getHeroTitle(tier: MonetizationTier): string {
    if (tier === 'pro') {
      return '你已经解锁本地高级能力层'
    }
    if (tier === 'plus') {
      return '你当前位于持续服务层'
    }
    return '先保持完整训练闭环，再决定是否升级'
  }

  private getHeroDescription(tier: MonetizationTier): string {
    if (tier === 'pro') {
      return '当前层级适合承接更深分析、更长历史和更强本地工具能力。'
    }
    if (tier === 'plus') {
      return '当前层级用于承接云同步、远端内容更新与后续持续服务能力。'
    }
    return '基础训练、回顾、备份和本地内容能力继续可用；升级只负责更深分析和后续持续服务。'
  }

  private getEnvironmentText(environment: MonetizationBillingEnvironment): string {
    if (environment === 'production') {
      return '支付环境：正式'
    }
    if (environment === 'sandbox') {
      return '支付环境：沙箱'
    }
    if (environment === 'mock') {
      return '支付环境：模拟'
    }
    return '支付环境：未接入'
  }

  private getNoticeText(environment: MonetizationBillingEnvironment, source: string): string {
    if (this.isPreviewEnabled(environment) && source === 'debug_override') {
      return '当前正在使用本地预览态；它只用于验证会员入口和功能降级，不代表真实支付结果。'
    }
    if (this.isPreviewEnabled(environment)) {
      return '正式支付入口尚未接入；当前页面用于明确免费主链、商品结构和本地预览状态。'
    }
    return '正式支付入口尚未接入；当前页面用于明确免费主链与已规划商品结构。'
  }

  private getSourceText(source: string): string {
    if (source === 'iap_purchase') {
      return '正式购买快照'
    }
    if (source === 'restored_purchase') {
      return '恢复购买快照'
    }
    if (source === 'debug_override') {
      return '本地预览态'
    }
    return '默认免费态'
  }

  private getCurrentProductText(entitlement: MonetizationEntitlement): string {
    if (entitlement.productId.length === 0) {
      return '未绑定商品'
    }
    if (entitlement.productId === 'fittracker_pro_lifetime') {
      return 'Pro 一次买断'
    }
    if (entitlement.productId === 'fittracker_plus_monthly') {
      return 'Plus 月度订阅'
    }
    if (entitlement.productId === 'fittracker_plus_yearly') {
      return 'Plus 年度订阅'
    }
    return entitlement.productId
  }

  private getExpiryText(entitlement: MonetizationEntitlement): string {
    if (entitlement.expiresAt <= 0) {
      return '无到期限制'
    }
    const date: Date = new Date(entitlement.expiresAt)
    return date.getFullYear().toString() + '-' +
      this.pad2(date.getMonth() + 1) + '-' +
      this.pad2(date.getDate())
  }

  private getPreviewStatusText(entitlement: MonetizationEntitlement): string {
    if (entitlement.source === 'debug_override') {
      return '当前预览层级：' + this.getTierText(entitlement.tier)
    }
    return '当前显示真实默认态；切换后只影响本地预览，不改变免费主链边界。'
  }

  private isHighlightedOffer(
    product: MonetizationProduct,
    tier: MonetizationTier,
    focusCapability: MonetizationCapability | ''
  ): boolean {
    const focusedProductId: string = this.getFocusedProductId(focusCapability, tier)
    if (focusedProductId.length > 0) {
      return product.productId === focusedProductId
    }
    if (tier === 'free') {
      return product.productId === 'fittracker_pro_lifetime'
    }
    if (tier === 'pro') {
      return product.productId === 'fittracker_plus_yearly'
    }
    return false
  }

  private getFocusedProductId(focusCapability: MonetizationCapability | '', tier: MonetizationTier): string {
    if (tier === 'plus') {
      return ''
    }
    if (focusCapability === 'premium_content' || focusCapability === 'cloud_sync') {
      if (tier === 'free') {
        return 'fittracker_plus_monthly'
      }
      return 'fittracker_plus_yearly'
    }
    if (
      focusCapability === 'advanced_plans' ||
      focusCapability === 'advanced_insights' ||
      focusCapability === 'unlimited_history' ||
      focusCapability === 'enhanced_goal_adjustment'
    ) {
      if (tier === 'free') {
        return 'fittracker_pro_lifetime'
      }
      return 'fittracker_plus_yearly'
    }
    return ''
  }

  private getFocusSourceLabel(sourceLabel: string, fallbackLabel: string): string {
    if (sourceLabel.length > 0) {
      return sourceLabel
    }
    return fallbackLabel
  }

  private getOfferTitle(productId: string): string {
    if (productId === 'fittracker_plus_monthly') {
      return 'Plus 月度订阅'
    }
    if (productId === 'fittracker_plus_yearly') {
      return 'Plus 年度订阅'
    }
    return 'Pro 一次买断'
  }

  private getOfferBadgeText(productId: string): string {
    if (productId === 'fittracker_plus_yearly') {
      return '主推'
    }
    if (productId === 'fittracker_plus_monthly') {
      return '轻量入口'
    }
    return '首个付费点'
  }

  private getOfferPriceText(productId: string): string {
    if (productId === 'fittracker_plus_monthly') {
      return '¥15 - ¥22'
    }
    if (productId === 'fittracker_plus_yearly') {
      return '¥128 - ¥168'
    }
    return '¥68 - ¥98'
  }

  private getBillingText(productId: string): string {
    if (productId === 'fittracker_plus_monthly') {
      return '按月自动续费'
    }
    if (productId === 'fittracker_plus_yearly') {
      return '按年自动续费'
    }
    return '一次购买，长期保留'
  }

  private getOfferDescription(productId: string): string {
    if (productId === 'fittracker_plus_monthly') {
      return '适合先体验持续服务能力的轻量订阅入口。'
    }
    if (productId === 'fittracker_plus_yearly') {
      return '用于承接云同步、远端内容更新和跨设备连续使用。'
    }
    return '优先卖更强的本地工具能力，先把高级洞察和历史价值做扎实。'
  }

  private getOfferStatusText(
    product: MonetizationProduct,
    entitlement: MonetizationEntitlement,
    current: boolean
  ): string {
    if (current) {
      return '当前账号已拥有这一层级'
    }
    if (entitlement.tier === 'plus' && product.tier === 'pro') {
      return '当前 Plus 权益已覆盖这部分能力'
    }
    if (entitlement.tier === 'pro' && product.tier === 'plus') {
      return '适合作为下一步升级方向'
    }
    if (entitlement.tier === 'free' && product.productId === 'fittracker_pro_lifetime') {
      return '最适合先落地的首个付费商品'
    }
    return '支付入口待接入，当前先展示权益结构'
  }

  private getOfferBullets(productId: string): string[] {
    if (productId === 'fittracker_plus_monthly') {
      return [
        '适合先体验持续服务能力',
        '后续承接云同步与内容更新',
        '不改变免费训练主链'
      ]
    }
    if (productId === 'fittracker_plus_yearly') {
      return [
        '主推持续服务方案',
        '承接多设备连续性与远端更新',
        '适合作为长期订阅层'
      ]
    }
    return [
      '更深趋势与 PR 细节',
      '更长历史价值与本地高级能力',
      '更适合作为第一笔付费转化'
    ]
  }

  private pad2(value: number): string {
    if (value < 10) {
      return '0' + value.toString()
    }
    return value.toString()
  }
}

export default new MonetizationHubService()
