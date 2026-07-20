/**
 * MonetizationHubPage -- membership comparison and local preview surface.
 *
 * Phase 4: expose a real monetization destination without faking a live payment flow.
 */
import { Context } from '@kit.AbilityKit'
import { AppRoutes } from '../../../app/AppRoutes'
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens } from '../../../common/styles/DesignTokens'
import { AppButton } from '../../../components/AppButton'
import { AppCard } from '../../../components/AppCard'
import { PageHeader } from '../../../components/PageHeader'
import { createStageRailItem, StageRail, StageRailItem } from '../../../components/StageRail'
import { MonetizationCapability } from '../../../shared/models/MonetizationModels'
import MonetizationHubService, {
  MonetizationHubViewModel,
  MonetizationInfoRowViewModel,
  MonetizationOfferCardViewModel,
  MonetizationPreviewOptionViewModel,
  MonetizationRoadmapItemViewModel
} from '../../../shared/services/MonetizationHubService'

@Entry
@Component
export struct MonetizationHubPage {
  @State loading: boolean = true
  @State previewBusy: boolean = false
  @State previewActionStatusText: string = ''
  @State viewModel: MonetizationHubViewModel = MonetizationHubService.createEmptyViewModel()
  @State focusCapability: MonetizationCapability | '' = ''
  @State focusSourceLabel: string = ''

  private getHostContextOrNull(): Context | null {
    const hostContext = this.getUIContext().getHostContext()
    if (hostContext === undefined || hostContext === null) {
      return null
    }
    return hostContext as Context
  }

  async aboutToAppear(): Promise<void> {
    this.readRouteContext()
    await this.reloadViewModel()
  }

  async reloadViewModel(): Promise<void> {
    this.loading = true
    try {
      const context: Context | null = this.getHostContextOrNull()
      if (context === null) {
        this.viewModel = MonetizationHubService.createEmptyViewModel()
        this.loading = false
        return
      }
      this.viewModel = await MonetizationHubService.createViewModel(
        context,
        this.focusCapability,
        this.focusSourceLabel
      )
    } catch (error) {
      this.viewModel = MonetizationHubService.createEmptyViewModel()
    }
    this.loading = false
  }

  readRouteContext(): void {
    this.focusCapability = this.getFocusCapabilityFromParams()
    this.focusSourceLabel = this.getFocusSourceLabelFromParams()
  }

  getFocusCapabilityFromParams(): MonetizationCapability | '' {
    try {
      const params = this.getUIContext().getRouter().getParams() as Record<string, string>
      const capability: string = params.focusCapability
      if (capability === 'advanced_insights' || capability === 'unlimited_history' ||
        capability === 'advanced_plans' || capability === 'cloud_sync' ||
        capability === 'premium_content' || capability === 'enhanced_goal_adjustment') {
        return capability
      }
    } catch (error) {
      return ''
    }
    return ''
  }

  getFocusSourceLabelFromParams(): string {
    try {
      const params = this.getUIContext().getRouter().getParams() as Record<string, string>
      if (params.focusSourceLabel !== undefined) {
        return params.focusSourceLabel
      }
    } catch (error) {
      return ''
    }
    return ''
  }

  backToReview(): void {
    try {
      this.getUIContext().getRouter().back()
    } catch (error) {
      try {
        this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.REVIEW_HOME })
      } catch (innerError) {
      }
    }
  }

  getTierBadgeBackgroundColor(): string {
    if (this.viewModel.tierText === 'Plus') {
      return ColorTokens.OVERLAY_ACCENT
    }
    if (this.viewModel.tierText === 'Pro') {
      return ColorTokens.OVERLAY_PRIMARY
    }
    return ColorTokens.SURFACE_ELEVATED
  }

  getTierBadgeTextColor(): string {
    if (this.viewModel.tierText === 'Plus') {
      return ColorTokens.ACCENT
    }
    if (this.viewModel.tierText === 'Pro') {
      return ColorTokens.PRIMARY
    }
    return ColorTokens.TEXT_SECONDARY
  }

  getOfferBadgeBackgroundColor(offer: MonetizationOfferCardViewModel): string {
    if (offer.current) {
      return ColorTokens.SUCCESS_BG
    }
    if (offer.highlighted) {
      return ColorTokens.OVERLAY_PRIMARY
    }
    return ColorTokens.SURFACE_ELEVATED
  }

  getOfferBadgeTextColor(offer: MonetizationOfferCardViewModel): string {
    if (offer.current) {
      return ColorTokens.SUCCESS
    }
    if (offer.highlighted) {
      return ColorTokens.PRIMARY
    }
    return ColorTokens.TEXT_SECONDARY
  }

  getOfferStatusBackgroundColor(offer: MonetizationOfferCardViewModel): string {
    if (offer.current) {
      return ColorTokens.SUCCESS_BG
    }
    if (offer.highlighted) {
      return ColorTokens.OVERLAY_PRIMARY
    }
    return ColorTokens.SURFACE_SECONDARY
  }

  getOfferStatusTextColor(offer: MonetizationOfferCardViewModel): string {
    if (offer.current) {
      return ColorTokens.SUCCESS
    }
    if (offer.highlighted) {
      return ColorTokens.PRIMARY
    }
    return ColorTokens.TEXT_SECONDARY
  }

  getRoadmapTierTextColor(item: MonetizationRoadmapItemViewModel): string {
    if (item.tierText === 'Plus') {
      return ColorTokens.ACCENT
    }
    return ColorTokens.PRIMARY
  }

  getRoadmapStatusTextColor(item: MonetizationRoadmapItemViewModel): string {
    if (item.statusText === '已接入入口') {
      return ColorTokens.SUCCESS
    }
    if (item.statusText === '策略已定义') {
      return ColorTokens.INFO
    }
    return ColorTokens.TEXT_SECONDARY
  }

  getPreviewButtonBackgroundColor(option: MonetizationPreviewOptionViewModel): string {
    if (option.selected) {
      return ColorTokens.PRIMARY
    }
    return ColorTokens.SURFACE_ELEVATED
  }

  getPreviewButtonTextColor(option: MonetizationPreviewOptionViewModel): string {
    if (option.selected) {
      return ColorTokens.TEXT_ON_PRIMARY
    }
    return ColorTokens.TEXT_PRIMARY
  }

  getPreviewButtonNoteColor(option: MonetizationPreviewOptionViewModel): string {
    if (option.selected) {
      return ColorTokens.TEXT_ON_PRIMARY
    }
    return ColorTokens.TEXT_SECONDARY
  }

  getFocusTierBadgeBackgroundColor(): string {
    if (this.viewModel.focusContext.recommendedTierText === 'Plus') {
      return ColorTokens.OVERLAY_ACCENT
    }
    return ColorTokens.OVERLAY_PRIMARY
  }

  getFocusTierBadgeTextColor(): string {
    if (this.viewModel.focusContext.recommendedTierText === 'Plus') {
      return ColorTokens.ACCENT
    }
    return ColorTokens.PRIMARY
  }

  getHeroGuideText(): string {
    if (this.loading) {
      return '先确认当前层级和本次入口对应的能力，再决定是否继续查看升级方案。'
    }
    if (this.viewModel.focusContext.active) {
      return '你是从' + this.viewModel.focusContext.sourceLabel +
        '进入的。先看当前权益是否已经覆盖这项能力，再决定是否继续比较升级方案。'
    }
    if (this.viewModel.previewEnabled) {
      return '先确认当前权益和本地预览状态，再决定是否继续比较不同层级。'
    }
    return '先确认当前层级覆盖范围，再决定是否继续查看后续升级方案。'
  }

  getReturnActionText(): string {
    if (this.focusSourceLabel.length > 0) {
      return '返回' + this.focusSourceLabel
    }
    return '返回上一页'
  }

  async applyPreviewTier(tier: 'free' | 'pro' | 'plus'): Promise<void> {
    if (this.previewBusy) {
      return
    }
    this.previewBusy = true
    this.previewActionStatusText = ''
    try {
      const context: Context | null = this.getHostContextOrNull()
      if (context === null) {
        this.previewActionStatusText = '当前页面上下文不可用，请重试。'
        this.previewBusy = false
        return
      }
      await MonetizationHubService.applyPreviewTier(context, tier)
      await this.reloadViewModel()
      this.previewActionStatusText = '已切换到 ' + this.viewModel.tierText + ' 预览态'
    } catch (error) {
      this.previewActionStatusText = '切换预览态失败'
    }
    this.previewBusy = false
  }

  getOfferPreviewTier(offer: MonetizationOfferCardViewModel): 'pro' | 'plus' {
    if (offer.productId === 'fittracker_plus_monthly' || offer.productId === 'fittracker_plus_yearly') {
      return 'plus'
    }
    return 'pro'
  }

  getOfferPreviewActionText(offer: MonetizationOfferCardViewModel): string {
    if (this.getOfferPreviewTier(offer) === 'plus') {
      return '启用 Plus 本地预览'
    }
    return '启用 Pro 本地预览'
  }

  shouldShowOfferResetAction(offer: MonetizationOfferCardViewModel): boolean {
    return this.viewModel.previewEnabled && this.viewModel.previewActive && offer.current
  }

  shouldShowOfferPreviewAction(offer: MonetizationOfferCardViewModel): boolean {
    return this.viewModel.previewEnabled && !offer.current
  }

  getStageRailItems(): StageRailItem[] {
    const items: StageRailItem[] = []
    items.push(createStageRailItem('回顾', false, false))
    items.push(createStageRailItem('权益', true, false))
    items.push(createStageRailItem('比较', false, false))
    return items
  }

  @Builder
  buildLaneHeader(eyebrow: string, title: string, description: string) {
    Column({ space: SpacingTokens.XS }) {
      Text(eyebrow)
        .fontSize(FontTokens.MICRO_SIZE)
        .fontWeight(FontTokens.MICRO_WEIGHT)
        .fontColor(ColorTokens.TEXT_TERTIARY)

      Text(title)
        .fontSize(FontTokens.TITLE_SIZE)
        .fontWeight(FontTokens.TITLE_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)

      Text(description)
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildLabMetricTile(label: string, value: string, emphasize: boolean = false) {
    Column({ space: SpacingTokens.XS }) {
      Text(label)
        .fontSize(FontTokens.MICRO_SIZE)
        .fontWeight(FontTokens.MICRO_WEIGHT)
        .fontColor(ColorTokens.TEXT_TERTIARY)

      Text(value)
        .fontSize(FontTokens.BODY_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(emphasize ? ColorTokens.PRIMARY : ColorTokens.TEXT_PRIMARY)
        .maxLines(2)
    }
    .layoutWeight(1)
    .padding(SpacingTokens.SM)
    .backgroundColor(ColorTokens.SURFACE_PRIMARY)
    .borderRadius(RadiusTokens.SM)
    .border({ width: 1, color: emphasize ? ColorTokens.BORDER_ACCENT : ColorTokens.BORDER_SUBTLE })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      PageHeader({ title: '会员与权益', showBack: true, onBackClick: () => {
        this.backToReview()
      } })

      Scroll() {
        Column({ space: SpacingTokens.LG }) {
          StageRail({ items: this.getStageRailItems() })
          this.buildHeroSection()
          if (this.viewModel.focusContext.active) {
            this.buildLaneHeader('入口上下文', '当前入口', '先确认你是从哪条能力入口进入的，再决定是否要看更高层级的覆盖范围。')
            this.buildFocusContextSection()
          }
          this.buildLaneHeader('当前状态', '当前权益', '把当前层级、商品归属和本地预览状态放在同一层，避免误把预览态当成真实生效。')
          this.buildCurrentEntitlementSection()
          if (this.viewModel.previewEnabled) {
            this.buildLaneHeader('本地模拟', '本地预览', '这里只切换本地演示态，不会触发真实支付或修改正式会员状态。')
            this.buildPreviewSection()
          }
          this.buildLaneHeader('方案比较', '升级方案', '先看当前最相关的升级方案，再往下比较不同层级的定价和能力边界。')
          this.buildOfferSection()
          this.buildLaneHeader('免费主链', 'Free 边界', '明确哪些能力始终留在免费主链里，避免把训练主流程和会员增量能力混在一起。')
          this.buildFreeBoundarySection()
          this.buildLaneHeader('落地顺序', '接入顺序', '这里记录会员能力按什么顺序落地，方便判断哪些是已接入入口，哪些仍只是规划。')
          this.buildRoadmapSection()

          AppButton({
            text: this.getReturnActionText(),
            type: 'secondary',
            buttonSize: 'large',
            block: true,
            onButtonClick: () => {
              this.backToReview()
            }
          })
        }
        .width('100%')
        .padding(SpacingTokens.LG)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.BG_PRIMARY)
  }

  @Builder
  buildHeroSection() {
    AppCard({ variant: 'panel', cardPadding: 'default' }) {
      Column({ space: SpacingTokens.MD }) {
        Row() {
          Column({ space: SpacingTokens.XS }) {
            Text('商业化结构')
              .fontSize(FontTokens.MICRO_SIZE)
              .fontWeight(FontTokens.MICRO_WEIGHT)
              .fontColor(ColorTokens.TEXT_TERTIARY)

            Text(this.viewModel.heroTitle)
              .fontSize(FontTokens.DISPLAY_SIZE)
              .fontWeight(FontTokens.DISPLAY_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)
              .maxLines(2)

            Text(this.viewModel.heroDescription)
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
              .lineHeight(FontTokens.BODY_LINE_HEIGHT)
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text(this.viewModel.tierText)
            .fontSize(FontTokens.SMALL_SIZE)
            .fontColor(this.getTierBadgeTextColor())
            .padding({
              top: SpacingTokens.XS,
              bottom: SpacingTokens.XS,
              left: SpacingTokens.SM,
              right: SpacingTokens.SM
            })
            .backgroundColor(this.getTierBadgeBackgroundColor())
            .borderRadius(RadiusTokens.FULL)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Text(this.getHeroGuideText())
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(ColorTokens.TEXT_TERTIARY)
          .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
          .width('100%')

        Row({ space: SpacingTokens.SM }) {
          this.buildLabMetricTile('当前层级', this.viewModel.tierText, true)
          this.buildLabMetricTile('支付环境', this.viewModel.environmentText)
        }
        .width('100%')

        Column({ space: SpacingTokens.XS }) {
          Text('当前说明')
            .fontSize(FontTokens.MICRO_SIZE)
            .fontWeight(FontTokens.MICRO_WEIGHT)
            .fontColor(ColorTokens.TEXT_TERTIARY)

          Text(this.viewModel.noticeText)
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
            .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
            .width('100%')
        }
        .width('100%')
        .padding(SpacingTokens.MD)
        .borderRadius(RadiusTokens.SM)
        .backgroundColor(ColorTokens.SURFACE_PRIMARY)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildCurrentEntitlementSection() {
    AppCard({ variant: 'outlined', cardPadding: 'default' }) {
      Column({ space: SpacingTokens.MD }) {
        ForEach(this.viewModel.currentEntitlementRows, (item: MonetizationInfoRowViewModel) => {
          this.buildInfoRow(item.label, item.value)
        }, (item: MonetizationInfoRowViewModel) => item.label)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildFocusContextSection() {
    AppCard({ variant: 'panel', cardPadding: 'default' }) {
      Column({ space: SpacingTokens.MD }) {
        Row() {
          Column({ space: SpacingTokens.XS }) {
            Text(this.viewModel.focusContext.sourceLabel)
              .fontSize(FontTokens.MICRO_SIZE)
              .fontWeight(FontTokens.MICRO_WEIGHT)
              .fontColor(ColorTokens.TEXT_TERTIARY)

            Text(this.viewModel.focusContext.title)
              .fontSize(FontTokens.TITLE_SIZE)
              .fontWeight(FontTokens.TITLE_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text(this.viewModel.focusContext.recommendedTierText)
            .fontSize(FontTokens.SMALL_SIZE)
            .fontColor(this.getFocusTierBadgeTextColor())
            .padding({
              top: SpacingTokens.XS,
              bottom: SpacingTokens.XS,
              left: SpacingTokens.SM,
              right: SpacingTokens.SM
            })
            .backgroundColor(this.getFocusTierBadgeBackgroundColor())
            .borderRadius(RadiusTokens.FULL)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Text(this.viewModel.focusContext.description)
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .lineHeight(FontTokens.BODY_LINE_HEIGHT)
          .width('100%')

        Row({ space: SpacingTokens.SM }) {
          this.buildLabMetricTile('来源入口', this.viewModel.focusContext.sourceLabel, true)
          this.buildLabMetricTile('建议层级', this.viewModel.focusContext.recommendedTierText)
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildPreviewSection() {
    AppCard({ variant: 'outlined', cardPadding: 'default' }) {
      Column({ space: SpacingTokens.MD }) {
        Text(this.viewModel.previewDescription)
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .lineHeight(FontTokens.BODY_LINE_HEIGHT)
          .width('100%')

        Row({ space: SpacingTokens.SM }) {
          ForEach(this.viewModel.previewOptions, (option: MonetizationPreviewOptionViewModel) => {
            Button({ type: ButtonType.Normal }) {
              Column({ space: SpacingTokens.XS }) {
                Text(option.label)
                  .fontSize(FontTokens.BODY_SIZE)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.getPreviewButtonTextColor(option))

                Text(option.note)
                  .fontSize(FontTokens.SMALL_SIZE)
                  .fontColor(this.getPreviewButtonNoteColor(option))
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }
            .layoutWeight(1)
            .height(60)
            .padding({
              left: SpacingTokens.SM,
              right: SpacingTokens.SM,
              top: SpacingTokens.SM,
              bottom: SpacingTokens.SM
            })
            .backgroundColor(this.getPreviewButtonBackgroundColor(option))
            .border({
              width: 1,
              color: option.selected ? ColorTokens.PRIMARY : ColorTokens.BORDER_SUBTLE
            })
            .borderRadius(RadiusTokens.MD)
            .enabled(!this.previewBusy)
            .onClick(() => {
              this.applyPreviewTier(option.tier)
            })
          }, (option: MonetizationPreviewOptionViewModel) => option.tier)
        }
        .width('100%')

        Column({ space: SpacingTokens.XS }) {
          Text('当前预览状态')
            .fontSize(FontTokens.SMALL_SIZE)
            .fontColor(ColorTokens.TEXT_TERTIARY)

          Text(this.viewModel.previewStatusText)
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
            .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
            .width('100%')
        }
        .width('100%')
        .padding(SpacingTokens.MD)
        .borderRadius(RadiusTokens.SM)
        .backgroundColor(ColorTokens.SURFACE_PRIMARY)
        .alignItems(HorizontalAlign.Start)

        if (this.previewActionStatusText.length > 0) {
          Text(this.previewActionStatusText)
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.INFO)
            .width('100%')
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildFreeBoundarySection() {
    AppCard({ variant: 'outlined', cardPadding: 'default' }) {
      Column({ space: SpacingTokens.MD }) {
        Text('免费边界')
          .fontSize(FontTokens.MICRO_SIZE)
          .fontWeight(FontTokens.MICRO_WEIGHT)
          .fontColor(ColorTokens.TEXT_TERTIARY)

        Text('Free 始终保留的主链')
          .fontSize(FontTokens.TITLE_SIZE)
          .fontWeight(FontTokens.TITLE_WEIGHT)
          .fontColor(ColorTokens.TEXT_PRIMARY)

        Text('这些能力默认保留在免费主链里，不会因为会员化接入而被挪走。')
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
          .width('100%')

        ForEach(this.viewModel.freeIncludedBullets, (item: string) => {
          Row({ space: SpacingTokens.SM }) {
            Text('·')
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.SUCCESS)

            Text(item)
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
              .lineHeight(FontTokens.BODY_LINE_HEIGHT)
              .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }, (item: string) => item)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildOfferSection() {
    Column({ space: SpacingTokens.MD }) {
      Text('推荐方案')
        .fontSize(FontTokens.MICRO_SIZE)
        .fontWeight(FontTokens.MICRO_WEIGHT)
        .fontColor(ColorTokens.TEXT_TERTIARY)
        .width('100%')

      Text('商品矩阵')
        .fontSize(FontTokens.TITLE_SIZE)
        .fontWeight(FontTokens.TITLE_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)
        .width('100%')

      Text('先看当前最相关的升级方案，再往下比较其他层级。')
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
        .width('100%')

      ForEach(this.viewModel.offerCards, (offer: MonetizationOfferCardViewModel) => {
        this.buildOfferCard(offer)
      }, (offer: MonetizationOfferCardViewModel) => offer.productId)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildOfferCard(offer: MonetizationOfferCardViewModel) {
    if (offer.current) {
      AppCard({ variant: 'panel', cardPadding: 'default' }) {
        this.buildOfferCardContent(offer)
      }
    } else if (offer.highlighted) {
      AppCard({ variant: 'elevated', cardPadding: 'default' }) {
        this.buildOfferCardContent(offer)
      }
    } else {
      AppCard({ variant: 'outlined', cardPadding: 'default' }) {
        this.buildOfferCardContent(offer)
      }
    }
  }

  @Builder
  buildOfferCardContent(offer: MonetizationOfferCardViewModel) {
    Column({ space: SpacingTokens.MD }) {
      if (offer.current || offer.highlighted) {
        Row() {
          Text(offer.current ? '当前层级' : '推荐入口')
            .fontSize(FontTokens.SMALL_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.getOfferStatusTextColor(offer))

          Blank()

          Text(offer.current ? '已生效' : '优先查看')
            .fontSize(FontTokens.SMALL_SIZE)
            .fontColor(this.getOfferStatusTextColor(offer))
        }
        .width('100%')
        .padding(SpacingTokens.SM)
        .borderRadius(RadiusTokens.SM)
        .backgroundColor(this.getOfferStatusBackgroundColor(offer))
      }

      Row() {
        Column({ space: SpacingTokens.XS }) {
          Text(offer.title)
            .fontSize(FontTokens.TITLE_SIZE)
            .fontWeight(FontTokens.TITLE_WEIGHT)
            .fontColor(ColorTokens.TEXT_PRIMARY)

          Text(offer.description)
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
            .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(offer.badgeText)
          .fontSize(FontTokens.SMALL_SIZE)
          .fontColor(this.getOfferBadgeTextColor(offer))
          .padding({
            top: SpacingTokens.XS,
            bottom: SpacingTokens.XS,
            left: SpacingTokens.SM,
            right: SpacingTokens.SM
          })
          .backgroundColor(this.getOfferBadgeBackgroundColor(offer))
          .borderRadius(RadiusTokens.FULL)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Row({ space: SpacingTokens.SM }) {
        this.buildLabMetricTile('价格区间', offer.priceText, offer.highlighted)
        this.buildLabMetricTile('计费方式', offer.billingText)
      }
      .width('100%')

      Column({ space: SpacingTokens.SM }) {
        ForEach(offer.featureBullets, (item: string) => {
          Row({ space: SpacingTokens.SM }) {
            Text('·')
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.PRIMARY)

            Text(item)
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
              .layoutWeight(1)
              .lineHeight(FontTokens.BODY_LINE_HEIGHT)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }, (item: string) => offer.productId + '_' + item)
      }
      .width('100%')
      .padding(SpacingTokens.MD)
      .borderRadius(RadiusTokens.SM)
      .backgroundColor(ColorTokens.SURFACE_PRIMARY)
      .border({
        width: 1,
        color: offer.highlighted ? ColorTokens.BORDER_ACCENT : ColorTokens.BORDER_SUBTLE
      })

      Text(offer.statusText)
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(offer.current ? ColorTokens.SUCCESS : ColorTokens.TEXT_TERTIARY)
        .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
        .width('100%')

      if (this.shouldShowOfferPreviewAction(offer)) {
        AppButton({
          text: this.getOfferPreviewActionText(offer),
          type: offer.highlighted ? 'primary' : 'secondary',
          buttonSize: 'medium',
          block: true,
          disabled: this.previewBusy,
          onButtonClick: () => {
            this.applyPreviewTier(this.getOfferPreviewTier(offer))
          }
        })
      }

      if (this.shouldShowOfferResetAction(offer)) {
        AppButton({
          text: '恢复 Free 预览',
          type: 'secondary',
          buttonSize: 'medium',
          block: true,
          disabled: this.previewBusy,
          onButtonClick: () => {
            this.applyPreviewTier('free')
          }
        })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildRoadmapSection() {
    Column({ space: SpacingTokens.MD }) {
      Text('能力接入矩阵')
        .fontSize(FontTokens.TITLE_SIZE)
        .fontWeight(FontTokens.TITLE_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)
        .width('100%')

      Text('这里说明会员能力按什么顺序落地，避免把 Free 主链和后续增量能力混在一起。')
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
        .width('100%')

      ForEach(this.viewModel.roadmapItems, (item: MonetizationRoadmapItemViewModel) => {
        AppCard({ variant: 'outlined', cardPadding: 'default' }) {
          Column({ space: SpacingTokens.SM }) {
            Row() {
              Column({ space: SpacingTokens.XS }) {
                Text(item.title)
                  .fontSize(FontTokens.BODY_SIZE)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(ColorTokens.TEXT_PRIMARY)

                Text(item.summary)
                  .fontSize(FontTokens.CAPTION_SIZE)
                  .fontColor(ColorTokens.TEXT_SECONDARY)
                  .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
                  .width('100%')
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Column({ space: SpacingTokens.XS }) {
                Text(item.tierText)
                  .fontSize(FontTokens.SMALL_SIZE)
                  .fontColor(this.getRoadmapTierTextColor(item))
                  .padding({
                    top: SpacingTokens.XS,
                    bottom: SpacingTokens.XS,
                    left: SpacingTokens.SM,
                    right: SpacingTokens.SM
                  })
                  .backgroundColor(ColorTokens.SURFACE_ELEVATED)
                  .borderRadius(RadiusTokens.FULL)

                Text(item.statusText)
                  .fontSize(FontTokens.SMALL_SIZE)
                  .fontColor(this.getRoadmapStatusTextColor(item))
              }
              .alignItems(HorizontalAlign.End)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
      }, (item: MonetizationRoadmapItemViewModel) => item.capabilityKey)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildMetricTile(label: string, value: string) {
    Column({ space: SpacingTokens.XS }) {
      Text(label)
        .fontSize(FontTokens.SMALL_SIZE)
        .fontColor(ColorTokens.TEXT_TERTIARY)

      Text(value)
        .fontSize(FontTokens.BODY_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(ColorTokens.TEXT_PRIMARY)
        .maxLines(2)
    }
    .layoutWeight(1)
    .padding(SpacingTokens.MD)
    .backgroundColor(ColorTokens.SURFACE_PRIMARY)
    .borderRadius(RadiusTokens.SM)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildInfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(FontTokens.SMALL_SIZE)
        .fontColor(ColorTokens.TEXT_TERTIARY)
        .width(72)

      Text(value)
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }
}
