/**
 * AppCard —— 通用卡片组件
 * 功能 #26
 */
import { ColorTokens, RadiusTokens, ShadowTokens, SpacingTokens } from '../common/styles/DesignTokens'

@Component
export struct AppCard {
  @Prop variant: 'elevated' | 'outlined' | 'panel' = 'elevated'
  @Prop cardPadding: 'default' | 'compact' = 'default'
  @BuilderParam content: () => void = this.defaultContent

  private getPadding(): number {
    if (this.cardPadding === 'compact') {
      return SpacingTokens.MD
    }
    return SpacingTokens.LG
  }

  private getBackgroundColor(): string {
    if (this.variant === 'panel') {
      return ColorTokens.SURFACE_PANEL_RAISED
    }
    if (this.variant === 'outlined') {
      return ColorTokens.SURFACE_PANEL
    }
    return ColorTokens.SURFACE_PANEL_RAISED
  }

  private getBorderColor(): string {
    if (this.variant === 'panel') {
      return ColorTokens.BORDER_ACCENT
    }
    if (this.variant === 'outlined') {
      return ColorTokens.BORDER_STRONG
    }
    return ColorTokens.BORDER_SUBTLE
  }

  @Builder
  defaultContent() {
    Text('Card Content')
      .fontSize(14)
      .fontColor(ColorTokens.TEXT_SECONDARY)
  }

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .padding(this.getPadding())
    .backgroundColor(this.getBackgroundColor())
    .borderRadius(RadiusTokens.MD)
    .border({ width: 1, color: this.getBorderColor() })
    .shadow(this.variant === 'elevated' ? ShadowTokens.SM : ShadowTokens.NONE)
  }
}
