/**
 * WeeklyRhythmStrip -- horizontal training cadence strip for the home page.
 */
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens } from '../common/styles/DesignTokens'
import { HomeDashboardWeekItem } from '../features/home/services/HomeDashboardService'

@Component
export struct WeeklyRhythmStrip {
  @Prop items: HomeDashboardWeekItem[] = []

  private getItemBackground(item: HomeDashboardWeekItem): string {
    if (item.current) {
      return ColorTokens.SURFACE_CARD_HERO_RAISED
    }
    return 'rgba(0,0,0,0)'
  }

  private getCircleBackground(item: HomeDashboardWeekItem): string {
    if (item.completed) {
      return ColorTokens.PROGRESS_FILL
    }
    if (item.current) {
      return ColorTokens.SURFACE_GLASS
    }
    return 'rgba(0,0,0,0)'
  }

  private getCircleBorder(item: HomeDashboardWeekItem): string {
    if (item.completed) {
      return ColorTokens.PROGRESS_FILL
    }
    if (item.current) {
      return ColorTokens.BORDER_ACCENT_SOFT
    }
    return ColorTokens.BORDER_GLASS
  }

  build() {
    Row({ space: SpacingTokens.SM }) {
      ForEach(this.items, (item: HomeDashboardWeekItem) => {
        Column({ space: SpacingTokens.SM }) {
          Text(item.title)
            .fontSize(FontTokens.SMALL_SIZE)
            .fontWeight(item.current ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(item.current ? ColorTokens.TEXT_ON_DARK : ColorTokens.TEXT_ON_DARK_SECONDARY)
            .maxLines(1)

          Text(item.subtitle)
            .fontSize(FontTokens.META_LABEL_SIZE)
            .fontColor(ColorTokens.TEXT_ON_DARK_TERTIARY)
            .maxLines(1)

          Row() {
            if (item.completed) {
              Text('\u2713')
                .fontSize(FontTokens.SMALL_SIZE)
                .fontWeight(FontWeight.Medium)
                .fontColor(ColorTokens.TEXT_ON_PRIMARY)
            }
          }
          .width(24)
          .height(24)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.getCircleBackground(item))
          .border({ width: 1, color: this.getCircleBorder(item) })
          .borderRadius(RadiusTokens.FULL)
        }
        .width(72)
        .padding({
          left: SpacingTokens.SM,
          right: SpacingTokens.SM,
          top: SpacingTokens.SM,
          bottom: SpacingTokens.SM
        })
        .backgroundColor(this.getItemBackground(item))
        .borderRadius(RadiusTokens.CARD_SM)
      }, (item: HomeDashboardWeekItem) => item.itemId)
    }
    .width('100%')
  }
}
