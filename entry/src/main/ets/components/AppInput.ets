/**
 * AppInput —— 通用输入框组件
 *
 * 变体: text | number | password
 * 状态: default | error | success (通过 focused/errorMessage 派生)
 * 特性: 可选前缀（如+86）、聚焦变色、错误态边框
 *
 * 禁止: 修改聚焦边框颜色、错误态使用非 error token 颜色
 * 高度: 固定 48vp（除非特殊指定）
 */
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens, TouchTokens } from '../common/styles/DesignTokens'

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

  build() {
    Column() {
      Row() {
        if (this.prefix) {
          Text(this.prefix)
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_PRIMARY)
            .margin({ right: SpacingTokens.XS })
        }

        TextInput({ text: $$this.value, placeholder: this.placeholder })
          .type(this.type === 'number' ? InputType.Number :
                this.type === 'password' ? InputType.Password :
                InputType.Normal)
          .maxLength(this.maxLength)
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_PRIMARY)
          .placeholderColor(ColorTokens.TEXT_DISABLED)
          .backgroundColor(Color.Transparent)
          .borderRadius(0)
          .height(TouchTokens.INPUT_HEIGHT)
          .layoutWeight(1)
          .onFocus(() => { this.focused = true })
          .onBlur(() => { this.focused = false })

        if (this.showClear && this.value.length > 0) {
          Text('✕')
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.TEXT_DISABLED)
            .padding({ left: SpacingTokens.XS, right: SpacingTokens.XS })
            .onClick(() => { this.value = '' })
        }
      }
      .width('100%')
      .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD })
      .backgroundColor(ColorTokens.SURFACE_SECONDARY)
      .borderRadius(RadiusTokens.SM)
      .border({
        width: 1,
        color: this.errorMessage ? ColorTokens.ERROR :
               this.focused ? ColorTokens.PRIMARY :
               ColorTokens.NEUTRAL_100
      })
      .height(TouchTokens.INPUT_HEIGHT)

      if (this.errorMessage) {
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
