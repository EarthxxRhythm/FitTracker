/**
 * SearchBar -- common search input for filter surfaces.
 */
import {
  ColorTokens,
  FontTokens,
  RadiusTokens,
  ShadowTokens,
  SpacingTokens,
  TouchTokens
} from '../common/styles/DesignTokens'

@Component
export struct SearchBar {
  @Link query: string
  @Prop placeholder: string = '搜索...'
  @State focused: boolean = false

  private getBorderColor(): string {
    if (this.focused) {
      return ColorTokens.ACCENT_PRIMARY
    }
    return ColorTokens.BORDER_DEFAULT
  }

  private getBackgroundColor(): string {
    if (this.focused) {
      return ColorTokens.BG_ELEVATED
    }
    return ColorTokens.SURFACE_INPUT
  }

  build() {
    Row({ space: SpacingTokens.SM }) {
      TextInput({ text: this.query, placeholder: this.placeholder })
        .fontSize(FontTokens.BODY_SIZE)
        .fontColor(ColorTokens.TEXT_PRIMARY)
        .placeholderColor(ColorTokens.TEXT_TERTIARY)
        .backgroundColor(Color.Transparent)
        .height(TouchTokens.INPUT_HEIGHT)
        .layoutWeight(1)
        .onFocus(() => {
          this.focused = true
        })
        .onBlur(() => {
          this.focused = false
        })
        .onChange((value: string) => {
          this.query = value
        })

      if (this.query.length > 0) {
        Text('X')
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .width(24)
          .height(24)
          .textAlign(TextAlign.Center)
          .backgroundColor(ColorTokens.BG_ELEVATED)
          .borderRadius(RadiusTokens.FULL)
          .onClick(() => {
            this.query = ''
          })
      }
    }
    .width('100%')
    .height(TouchTokens.INPUT_HEIGHT)
    .backgroundColor(this.getBackgroundColor())
    .border({
      width: 1,
      color: this.getBorderColor()
    })
    .borderRadius(RadiusTokens.MD)
    .padding({ left: SpacingTokens.MD, right: SpacingTokens.SM })
    .shadow(this.focused ? ShadowTokens.FOCUS : ShadowTokens.NONE)
  }
}
