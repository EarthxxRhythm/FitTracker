/**
 * AppButton —— 通用按钮组件
 * 功能 #26
 */
import {
  ColorTokens,
  FontTokens,
  RadiusTokens,
  ShadowConfig,
  ShadowTokens,
  SpacingTokens,
  TouchTokens
} from '../common/styles/DesignTokens'

@Component
export struct AppButton {
  @Prop text: string = ''
  @Prop type: 'primary' | 'secondary' | 'ghost' | 'quiet' = 'primary'
  @Prop buttonSize: 'hero' | 'large' | 'medium' | 'small' = 'medium'
  @Prop disabled: boolean = false
  @Prop loading: boolean = false
  @Prop block: boolean = false
  onButtonClick?: () => void

  private getHeight(): number {
    if (this.buttonSize === 'hero') {
      return TouchTokens.BUTTON_HEIGHT_HERO
    }
    if (this.buttonSize === 'large') {
      return TouchTokens.BUTTON_HEIGHT_LARGE
    }
    if (this.buttonSize === 'small') {
      return TouchTokens.BUTTON_HEIGHT_SMALL
    }
    return TouchTokens.BUTTON_HEIGHT_DEFAULT
  }

  private getHorizontalPadding(): number {
    if (this.buttonSize === 'hero') {
      return SpacingTokens.LG
    }
    if (this.buttonSize === 'small') {
      return SpacingTokens.MD
    }
    if (this.buttonSize === 'large') {
      return SpacingTokens.LG
    }
    return SpacingTokens.MD
  }

  private getFontSize(): number {
    if (this.buttonSize === 'hero') {
      return FontTokens.TITLE_SIZE
    }
    if (this.buttonSize === 'large') {
      return FontTokens.TITLE_SIZE
    }
    if (this.buttonSize === 'small') {
      return FontTokens.CAPTION_SIZE
    }
    return FontTokens.BODY_SIZE
  }

  private getTextColor(): string {
    if (this.type === 'primary') {
      return ColorTokens.TEXT_ON_PRIMARY
    }
    if (this.disabled) {
      return ColorTokens.TEXT_DISABLED
    }
    if (this.type === 'quiet') {
      return ColorTokens.TEXT_ON_DARK_SECONDARY
    }
    if (this.type === 'ghost') {
      return ColorTokens.TEXT_SECONDARY
    }
    return ColorTokens.TEXT_PRIMARY
  }

  private getIndicatorColor(): string {
    if (this.type === 'primary') {
      return ColorTokens.TEXT_ON_PRIMARY
    }
    return ColorTokens.PRIMARY
  }

  private getBackgroundColor(): string {
    if (this.type === 'primary') {
      if (this.disabled) {
        return ColorTokens.PRIMARY_DISABLED
      }
      return ColorTokens.PRIMARY
    }
    if (this.type === 'quiet') {
      if (this.disabled) {
        return ColorTokens.SURFACE_DISABLED
      }
      return ColorTokens.CTA_SECONDARY_BG
    }
    if (this.type === 'secondary') {
      if (this.disabled) {
        return ColorTokens.SURFACE_DISABLED
      }
      return ColorTokens.SURFACE_BUTTON_SECONDARY
    }
    return 'rgba(0,0,0,0)'
  }

  private getBorderWidth(): number {
    if (this.type === 'ghost') {
      return 0
    }
    return 1
  }

  private getBorderColor(): string {
    if (this.disabled) {
      return ColorTokens.BORDER_SUBTLE
    }
    if (this.type === 'ghost') {
      return 'rgba(0,0,0,0)'
    }
    if (this.type === 'quiet') {
      return ColorTokens.CTA_SECONDARY_BORDER
    }
    if (this.type === 'primary') {
      return ColorTokens.ACCENT_DEEP
    }
    return ColorTokens.BORDER_DEFAULT
  }

  private getShadow(): ShadowConfig {
    if (this.type === 'primary' && !this.disabled) {
      if (this.buttonSize === 'hero') {
        return ShadowTokens.CTA
      }
      return ShadowTokens.ACCENT
    }
    if (this.type === 'quiet' && !this.disabled) {
      return ShadowTokens.SM
    }
    if (this.type === 'secondary' && !this.disabled) {
      return ShadowTokens.SM
    }
    return ShadowTokens.NONE
  }

  build() {
    Button({ type: ButtonType.Normal }) {
      if (this.loading) {
        LoadingProgress()
          .width(20)
          .height(20)
          .color(this.getIndicatorColor())
      } else {
        Text(this.text)
          .fontSize(this.getFontSize())
          .fontColor(this.getTextColor())
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width(this.block ? '100%' : 'auto')
    .height(this.getHeight())
    .padding({ left: this.getHorizontalPadding(), right: this.getHorizontalPadding() })
    .backgroundColor(this.getBackgroundColor())
    .border({
      width: this.getBorderWidth(),
      color: this.getBorderColor()
    })
    .borderRadius(this.buttonSize === 'hero' ? RadiusTokens.CONTROL : RadiusTokens.MD)
    .shadow(this.getShadow())
    .constraintSize({ minHeight: TouchTokens.MIN_TARGET })
    .opacity(this.disabled ? 0.72 : 1)
    .enabled(!this.disabled && !this.loading)
    .onClick(() => {
      if (!this.disabled && !this.loading) {
        this.onButtonClick?.()
      }
    })
  }
}
