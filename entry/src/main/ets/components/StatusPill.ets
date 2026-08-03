/**
 * StatusPill -- semantic status chip for the new home surfaces.
 */
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens, TouchTokens } from '../common/styles/DesignTokens'
import { HomeDashboardTone } from '../features/home/services/HomeDashboardService'

@Component
export struct StatusPill {
  @Prop text: string = ''
  @Prop tone: HomeDashboardTone = 'neutral'

  private getBackgroundColor(): string {
    if (this.tone === 'success') {
      return ColorTokens.SUCCESS_BG
    }
    if (this.tone === 'warning') {
      return ColorTokens.WARNING_BG
    }
    if (this.tone === 'info') {
      return ColorTokens.OVERLAY_PRIMARY
    }
    return ColorTokens.SURFACE_GLASS
  }

  private getBorderColor(): string {
    if (this.tone === 'success') {
      return ColorTokens.STATE_SUCCESS_BORDER
    }
    if (this.tone === 'warning') {
      return ColorTokens.STATE_WARN_BORDER
    }
    if (this.tone === 'info') {
      return ColorTokens.BORDER_ACCENT_SOFT
    }
    return ColorTokens.BORDER_GLASS
  }

  build() {
    Text(this.text)
      .fontSize(FontTokens.STATUS_PILL_SIZE)
      .lineHeight(FontTokens.STATUS_PILL_LINE_HEIGHT)
      .fontWeight(FontTokens.STATUS_PILL_WEIGHT)
      .fontColor(ColorTokens.TEXT_ON_DARK)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .padding({
        left: SpacingTokens.SM,
        right: SpacingTokens.SM,
        top: SpacingTokens.XS,
        bottom: SpacingTokens.XS
      })
      .constraintSize({ minHeight: TouchTokens.STATUS_PILL_HEIGHT })
      .backgroundColor(this.getBackgroundColor())
      .border({ width: 1, color: this.getBorderColor() })
      .borderRadius(RadiusTokens.STATUS_PILL)
  }
}
