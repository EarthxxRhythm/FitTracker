/**
 * MonetizationHubPage -- read-only membership and capability planning surface.
 *
 * Phase 4: expose a real monetization destination without faking a live payment flow.
 */
import { router } from '@kit.ArkUI'
import { AppRoutes } from '../../../app/AppRoutes'
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens } from '../../../common/styles/DesignTokens'
import { AppButton } from '../../../components/AppButton'
import { AppCard } from '../../../components/AppCard'
import { PageHeader } from '../../../components/PageHeader'
import { PrimaryDestinationStrip } from '../../../components/PrimaryDestinationStrip'
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

  async aboutToAppear(): Promise<void> {
    this.readRouteContext()
    await this.reloadViewModel()
  }

  async reloadViewModel(): Promise<void> {
    this.loading = true
    try {
      this.viewModel = await MonetizationHubService.createViewModel(
        getContext(this),
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
      const params = router.getParams() as Record<string, string>
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
      const params = router.getParams() as Record<string, string>
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
      router.back()
    } catch (error) {
      router.replaceUrl({ url: AppRoutes.REVIEW_HOME })
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

  async applyPreviewTier(tier: 'free' | 'pro' | 'plus'): Promise<void> {
    if (this.previewBusy) {
      return
    }
    this.previewBusy = true
    this.previewActionStatusText = ''
    try {
      await MonetizationHubService.applyPreviewTier(getContext(this), tier)
      await this.reloadViewModel()
      this.previewActionStatusText = '已切换到 ' + this.viewModel.tierText + ' 预览态'
    } catch (error) {
      this.previewActionStatusText = '切换预览态失败'
    }
    this.previewBusy = false
  }

  build() {
    Column() {
      PageHeader({ title: '会员与权益', showBack: true, onBackClick: () => {
        this.backToReview()
      } })

      Scroll() {
        Column({ space: SpacingTokens.LG }) {
          PrimaryDestinationStrip({ currentKey: 'membership' })
          this.buildHeroSection()
          if (this.viewModel.focusContext.active) {
            this.buildFocusContextSection()
          }
          this.buildCurrentEntitlementSection()
          if (this.viewModel.previewEnabled) {
            this.buildPreviewSection()
          }
          this.buildFreeBoundarySection()
          this.buildOfferSection()
          this.buildRoadmapSection()

          AppButton({
            text: '返回训练回顾',
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

        Column({ space: SpacingTokens.SM }) {
          this.buildInfoRow('当前层级', this.viewModel.tierText)
          this.buildInfoRow('支付环境', this.viewModel.environmentText)
          this.buildInfoRow('当前说明', this.viewModel.noticeText)
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
        Text('当前权益状态')
          .fontSize(FontTokens.TITLE_SIZE)
          .fontWeight(FontTokens.TITLE_WEIGHT)
          .fontColor(ColorTokens.TEXT_PRIMARY)

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
    AppCard({ variant: 'outlined', cardPadding: 'default' }) {
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
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildPreviewSection() {
    AppCard({ variant: 'panel', cardPadding: 'default' }) {
      Column({ space: SpacingTokens.MD }) {
        Text(this.viewModel.previewTitle)
          .fontSize(FontTokens.TITLE_SIZE)
          .fontWeight(FontTokens.TITLE_WEIGHT)
          .fontColor(ColorTokens.TEXT_PRIMARY)

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
                  .fontColor(this.getPreviewButtonTextColor(option))
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

        Text(this.viewModel.previewStatusText)
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .width('100%')

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
        Text('Free 始终保留的主链')
          .fontSize(FontTokens.TITLE_SIZE)
          .fontWeight(FontTokens.TITLE_WEIGHT)
          .fontColor(ColorTokens.TEXT_PRIMARY)

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
      Text('商品结构')
        .fontSize(FontTokens.TITLE_SIZE)
        .fontWeight(FontTokens.TITLE_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)
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
        this.buildMetricTile('价格区间', offer.priceText)
        this.buildMetricTile('计费方式', offer.billingText)
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

      Text(offer.statusText)
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_TERTIARY)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildRoadmapSection() {
    Column({ space: SpacingTokens.MD }) {
      Text('能力接入顺序')
        .fontSize(FontTokens.TITLE_SIZE)
        .fontWeight(FontTokens.TITLE_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)
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
