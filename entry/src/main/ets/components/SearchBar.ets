/**
 * SearchBar —— 搜索栏组件
 */
import { ColorTokens, FontTokens, TouchTokens, SpacingTokens } from '../common/styles/DesignTokens'

@Component
export struct SearchBar {
  @Link query: string
  @Prop placeholder: string = '搜索...'

  build() {
    // DESIGN: Search bar with bottom border style, no container box.
    // Height: 44vp (slightly shorter than INPUT_HEIGHT 48 — designed for toolbar placement).
    // To change to rounded box style: replace border with backgroundColor + borderRadius.
    Row() {
      TextInput({ text: this.query, placeholder: this.placeholder })
        .fontSize(FontTokens.BODY_SIZE)
        .fontColor(ColorTokens.TEXT_PRIMARY)
        .placeholderColor(ColorTokens.TEXT_DISABLED)
        .backgroundColor(Color.Transparent)
        .height('100%')
        .layoutWeight(1)
        .onChange((value: string) => {
          this.query = value
        })
    }
    .width('100%')
    .height(44)
    .backgroundColor(ColorTokens.SURFACE_PRIMARY)
    .border({
      width: { bottom: 1 },
      color: ColorTokens.SURFACE_ELEVATED
    })
    .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD })
  }
}
