/**
 * HeroWorkoutCard -- dominant today-training decision card for the home page.
 */
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens } from '../common/styles/DesignTokens'
import { HomeDashboardMetric, HomeDashboardTone } from '../features/home/services/HomeDashboardService'
import { AppButton } from './AppButton'
import { AppCard } from './AppCard'
import { StatusPill } from './StatusPill'

@Component
export struct HeroWorkoutCard {
  @Prop eyebrow: string = ''
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @Prop statusText: string = ''
  @Prop statusTone: HomeDashboardTone = 'neutral'
  @Prop progressText: string = ''
  @Prop progressLabel: string = ''
  @Prop metrics: HomeDashboardMetric[] = []
  @Prop primaryActionText: string = ''
  @Prop secondaryActionText: string = ''
  @Prop primaryDisabled: boolean = false
  onPrimaryClick?: () => void
  onSecondaryClick?: () => void

  @Builder
  private buildMetric(metric: HomeDashboardMetric, index: number) {
    Column({ space: SpacingTokens.XS }) {
      Text(metric.label)
        .fontSize(FontTokens.META_LABEL_SIZE)
        .fontWeight(FontTokens.META_LABEL_WEIGHT)
        .fontColor(ColorTokens.TEXT_ON_DARK_TERTIARY)
        .maxLines(1)
        .textAlign(TextAlign.Center)

      Text(metric.value)
        .fontSize(metric.emphasize ? FontTokens.METRIC_VALUE_SIZE : FontTokens.CARD_TITLE_SIZE)
        .lineHeight(metric.emphasize ? FontTokens.METRIC_VALUE_LINE_HEIGHT : FontTokens.CARD_TITLE_LINE_HEIGHT)
        .fontWeight(metric.emphasize ? FontTokens.METRIC_VALUE_WEIGHT : FontTokens.CARD_TITLE_WEIGHT)
        .fontColor(metric.emphasize ? ColorTokens.TEXT_ON_DARK : ColorTokens.ACCENT_SOFT)
        .maxLines(2)
        .textAlign(TextAlign.Center)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(metric.note)
        .fontSize(FontTokens.MICRO_SIZE)
        .lineHeight(FontTokens.MICRO_LINE_HEIGHT)
        .fontColor(ColorTokens.TEXT_ON_DARK_FAINT)
        .maxLines(2)
        .textAlign(TextAlign.Center)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .padding({
      left: SpacingTokens.SM,
      right: SpacingTokens.SM,
      top: SpacingTokens.XS,
      bottom: 0
    })
    .border({
      width: { left: index === 0 ? 0 : 1 },
      color: ColorTokens.BORDER_GLASS
    })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildProgressStack() {
    Column({ space: SpacingTokens.SM }) {
      Stack({ alignContent: Alignment.Center }) {
        Row() {
        }
        .width(112)
        .height(112)
        .borderRadius(56)
        .backgroundColor(ColorTokens.SURFACE_GLASS_SOFT)
        .border({ width: 1, color: ColorTokens.BORDER_GLASS_STRONG })

        Row() {
        }
        .width(90)
        .height(90)
        .borderRadius(45)
        .border({ width: 1, color: ColorTokens.BORDER_GLASS })

        Row() {
        }
        .width(66)
        .height(66)
        .borderRadius(33)
        .backgroundColor(ColorTokens.BG_PRIMARY)
        .border({ width: 1, color: ColorTokens.BORDER_HAIRLINE })

        Column({ space: SpacingTokens.XXXS }) {
          Text(this.progressText)
            .fontSize(FontTokens.HEADLINE_SIZE)
            .fontWeight(FontTokens.HEADLINE_WEIGHT)
            .fontColor(ColorTokens.ACCENT_SOFT)

          Text('\u672c\u5468\u8fdb\u5ea6')
            .fontSize(FontTokens.MICRO_SIZE)
            .lineHeight(FontTokens.MICRO_LINE_HEIGHT)
            .fontColor(ColorTokens.TEXT_ON_DARK_FAINT)
        }
        .alignItems(HorizontalAlign.Center)
      }

      Text(this.progressLabel)
        .fontSize(FontTokens.MICRO_SIZE)
        .lineHeight(FontTokens.MICRO_LINE_HEIGHT)
        .fontColor(ColorTokens.TEXT_ON_DARK_TERTIARY)
        .textAlign(TextAlign.Center)
        .maxLines(2)
    }
    .width(112)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildHead() {
    Column({ space: SpacingTokens.MD }) {
      Row({ space: SpacingTokens.MD }) {
        Column({ space: SpacingTokens.SM }) {
          Text(this.eyebrow)
            .fontSize(FontTokens.SMALL_SIZE)
            .lineHeight(FontTokens.SMALL_LINE_HEIGHT)
            .fontWeight(FontTokens.CARD_TITLE_WEIGHT)
            .fontColor(ColorTokens.ACCENT_SOFT)
            .maxLines(1)

          Text(this.title)
            .fontSize(FontTokens.HERO_TITLE_SIZE)
            .lineHeight(FontTokens.HERO_TITLE_LINE_HEIGHT)
            .fontWeight(FontTokens.HERO_TITLE_WEIGHT)
            .fontColor(ColorTokens.TEXT_ON_DARK)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.subtitle)
            .fontSize(FontTokens.BODY_SIZE)
            .lineHeight(FontTokens.BODY_LINE_HEIGHT)
            .fontColor(ColorTokens.TEXT_ON_DARK_SECONDARY)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          StatusPill({ text: this.statusText, tone: this.statusTone })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        this.buildProgressStack()
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
  }

  @Builder
  private buildBody() {
    Column({ space: SpacingTokens.MD }) {
      Divider()
        .strokeWidth(1)
        .color(ColorTokens.BORDER_GLASS)

      Row() {
        ForEach(this.metrics, (metric: HomeDashboardMetric, index: number) => {
          this.buildMetric(metric, index)
        }, (metric: HomeDashboardMetric, index: number) => metric.label + index.toString())
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
  }

  @Builder
  private buildActions() {
    Column({ space: SpacingTokens.SM }) {
      AppButton({
        text: this.primaryActionText,
        type: 'primary',
        buttonSize: 'hero',
        block: true,
        disabled: this.primaryDisabled,
        onButtonClick: () => {
          this.onPrimaryClick?.()
        }
      })

      AppButton({
        text: this.secondaryActionText,
        type: 'quiet',
        buttonSize: 'medium',
        block: true,
        onButtonClick: () => {
          this.onSecondaryClick?.()
        }
      })
    }
    .width('100%')
  }

  build() {
    AppCard({ variant: 'hero', cardPadding: 'hero' }) {
      Stack({ alignContent: Alignment.TopStart }) {
        Column({ space: SpacingTokens.MD }) {
          this.buildHead()
          this.buildBody()
          this.buildActions()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Column()
          .width(136)
          .height(136)
          .backgroundColor(ColorTokens.ACCENT_GLOW)
          .borderRadius(RadiusTokens.FULL)
          .opacity(0.72)
          .position({ x: 240, y: 18 })

        Column()
          .width(88)
          .height(88)
          .backgroundColor(ColorTokens.OVERLAY_PRIMARY)
          .borderRadius(RadiusTokens.FULL)
          .opacity(0.92)
          .position({ x: 284, y: 84 })
      }
      .width('100%')
    }
  }
}
