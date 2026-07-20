/**
 * StageRail -- compact workflow stage indicators.
 */
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens } from '../common/styles/DesignTokens'

export interface StageRailItem {
  label: string
  active: boolean
  completed: boolean
}

export function createStageRailItem(label: string, active: boolean, completed: boolean): StageRailItem {
  const item: StageRailItem = {
    label: label,
    active: active,
    completed: completed
  }
  return item
}

@Component
export struct StageRail {
  @Prop items: StageRailItem[] = []

  private isHighlighted(item: StageRailItem): boolean {
    return item.active || item.completed
  }

  private getBackgroundColor(item: StageRailItem): string {
    if (item.active) {
      return ColorTokens.SURFACE_ELEVATED
    }
    if (item.completed) {
      return ColorTokens.OVERLAY_PRIMARY
    }
    return ColorTokens.SURFACE_SECONDARY
  }

  private getBorderColor(item: StageRailItem): string {
    if (this.isHighlighted(item)) {
      return ColorTokens.BORDER_ACCENT
    }
    return ColorTokens.BORDER_SUBTLE
  }

  private getFontColor(item: StageRailItem): string {
    if (this.isHighlighted(item)) {
      return ColorTokens.TEXT_PRIMARY
    }
    return ColorTokens.TEXT_TERTIARY
  }

  private getFontWeight(item: StageRailItem): number {
    if (item.active) {
      return FontWeight.Medium
    }
    return FontTokens.SMALL_WEIGHT
  }

  build() {
    Row({ space: SpacingTokens.SM }) {
      ForEach(this.items, (item: StageRailItem) => {
        Text(item.label)
          .fontSize(FontTokens.SMALL_SIZE)
          .fontWeight(this.getFontWeight(item))
          .fontColor(this.getFontColor(item))
          .padding({
            top: SpacingTokens.XS,
            bottom: SpacingTokens.XS,
            left: SpacingTokens.SM,
            right: SpacingTokens.SM
          })
          .backgroundColor(this.getBackgroundColor(item))
          .borderRadius(RadiusTokens.FULL)
          .border({
            width: 1,
            color: this.getBorderColor(item)
          })
      }, (item: StageRailItem) => item.label)
    }
    .width('100%')
  }
}
