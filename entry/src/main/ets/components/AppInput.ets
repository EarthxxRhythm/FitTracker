/**
 * AppInput -- common input component.
 * Function #26
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
export struct AppInput {
  @Link value: string
  @Prop placeholder: string = ''
  @Prop type: 'text' | 'number' | 'password' = 'text'
  @Prop prefix: string = ''
  @Prop errorMessage: string = ''
  @Prop maxLength: number = -1
  @Prop showClear: boolean = true
  @State focused: boolean = false

  private hasError(): boolean {
    return this.errorMessage.length > 0
  }

  private getContainerBorderColor(): string {
    if (this.hasError()) {
      return ColorTokens.ERROR
    }
    if (this.focused) {
      return ColorTokens.ACCENT_PRIMARY
    }
    return ColorTokens.BORDER_DEFAULT
  }

  private getContainerBackgroundColor(): string {
    if (this.focused) {
      return ColorTokens.BG_ELEVATED
    }
    return ColorTokens.SURFACE_INPUT
  }

  build() {
    Column() {
      Row() {
        if (this.prefix.length > 0) {
          Text(this.prefix)
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
            .margin({ right: SpacingTokens.SM })
        }

        TextInput({ text: $$this.value, placeholder: this.placeholder })
          .type(this.type === 'number' ? InputType.Number :
                this.type === 'password' ? InputType.Password :
                InputType.Normal)
          .maxLength(this.maxLength)
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_PRIMARY)
          .placeholderColor(ColorTokens.TEXT_TERTIARY)
          .backgroundColor(Color.Transparent)
          .borderRadius(0)
          .height(TouchTokens.INPUT_HEIGHT)
          .layoutWeight(1)
          .onFocus(() => { this.focused = true })
          .onBlur(() => { this.focused = false })

        if (this.showClear && this.value.length > 0) {
          Text('X')
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(ColorTokens.TEXT_SECONDARY)
            .width(24)
            .height(24)
            .textAlign(TextAlign.Center)
            .backgroundColor(ColorTokens.BG_ELEVATED)
            .borderRadius(RadiusTokens.FULL)
            .onClick(() => { this.value = '' })
        }
      }
      .width('100%')
      .padding({ left: SpacingTokens.MD, right: SpacingTokens.SM })
      .backgroundColor(this.getContainerBackgroundColor())
      .borderRadius(RadiusTokens.MD)
      .border({
        width: 1,
        color: this.getContainerBorderColor()
      })
      .shadow(this.focused && !this.hasError() ? ShadowTokens.FOCUS : ShadowTokens.NONE)
      .height(TouchTokens.INPUT_HEIGHT)

      if (this.hasError()) {
        Text(this.errorMessage)
          .fontSize(FontTokens.SMALL_SIZE)
          .fontColor(ColorTokens.ERROR)
          .margin({ top: SpacingTokens.XS, left: SpacingTokens.MD })
          .width('100%')
      }
    }
    .width('100%')
  }
}
