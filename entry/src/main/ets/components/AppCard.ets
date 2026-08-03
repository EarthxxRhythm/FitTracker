/**
 * AppCard —— 通用卡片组件
 * 功能 #26
 */
import { ColorTokens, FontTokens, RadiusTokens, ShadowTokens, SpacingTokens } from '../common/styles/DesignTokens'

@Component
export struct AppCard {
  @Prop variant: 'elevated' | 'outlined' | 'panel' | 'hero' | 'subtle' = 'elevated'
  @Prop cardPadding: 'default' | 'compact' | 'hero' = 'default'
  @BuilderParam content: () => void = this.defaultContent

  private getPadding(): number {
    if (this.cardPadding === 'hero') {
      return SpacingTokens.CARD_PADDING_MD
    }
    if (this.cardPadding === 'compact') {
      return SpacingTokens.MD
    }
    return SpacingTokens.LG
  }

  private getBackgroundColor(): string {
    if (this.variant === 'hero') {
      return ColorTokens.SURFACE_CARD_HERO
    }
    if (this.variant === 'subtle') {
      return ColorTokens.SURFACE_CARD_SUBTLE
    }
    if (this.variant === 'panel') {
      return ColorTokens.SURFACE_STRONG
    }
    if (this.variant === 'outlined') {
      return ColorTokens.SURFACE_PRIMARY
    }
    return ColorTokens.SURFACE_SECONDARY
  }

  private getBorderColor(): string {
    if (this.variant === 'hero') {
      return ColorTokens.BORDER_GLASS_STRONG
    }
    if (this.variant === 'subtle') {
      return ColorTokens.BORDER_HAIRLINE
    }
    if (this.variant === 'panel') {
      return ColorTokens.BORDER_STRONG
    }
    if (this.variant === 'outlined') {
      return ColorTokens.BORDER_SUBTLE
    }
    return ColorTokens.BORDER_DEFAULT
  }

  private getRadius(): number {
    if (this.variant === 'hero') {
      return RadiusTokens.CARD_MD
    }
    if (this.variant === 'subtle') {
      return RadiusTokens.CARD_SM
    }
    if (this.variant === 'panel') {
      return RadiusTokens.LG
    }
    return RadiusTokens.MD
  }

  @Builder
  defaultContent() {
    Text('Card Content')
      .fontSize(FontTokens.CAPTION_SIZE)
      .fontColor(ColorTokens.TEXT_SECONDARY)
  }

  private getShadowToken() {
    if (this.variant === 'hero') {
      return ShadowTokens.GLASS_STRONG
    }
    if (this.variant === 'subtle') {
      return ShadowTokens.NONE
    }
    if (this.variant === 'panel') {
      return ShadowTokens.MD
    }
    if (this.variant === 'elevated') {
      return ShadowTokens.SM
    }
    return ShadowTokens.NONE
  }

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .padding(this.getPadding())
    .backgroundColor(this.getBackgroundColor())
    .borderRadius(this.getRadius())
    .border({ width: 1, color: this.getBorderColor() })
    .shadow(this.getShadowToken())
  }
}
