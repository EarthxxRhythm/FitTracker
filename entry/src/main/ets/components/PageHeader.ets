/**
 * PageHeader —— 页面标题栏
 */
import { ColorTokens, FontTokens, SpacingTokens } from '../common/styles/DesignTokens'
import router from '@ohos.router'

@Component
export struct PageHeader {
  @Prop title: string = ''
  @Prop showBack: boolean = true
  onBackClick?: () => void

  build() {
    // DESIGN: Standard page header. Back arrow uses ← character (no icon dependency).
    // Padding top: LG (24vp) accounts for status bar clearance on HarmonyOS.
    // To add a right action button: extend with a @BuilderParam rightAction slot.
    Row() {
      if (this.showBack) {
        Text('←')
          .fontSize(FontTokens.HEADLINE_SIZE)
          .fontColor(ColorTokens.TEXT_PRIMARY)
          .padding({ right: SpacingTokens.SM })
          .onClick(() => {
            if (this.onBackClick) {
              this.onBackClick()
            } else {
              router.back()
            }
          })
      }

      Text(this.title)
        .fontSize(FontTokens.HEADLINE_SIZE)
        .fontWeight(FontWeight.Bold)
        .fontColor(ColorTokens.TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      Blank()
    }
    .width('100%')
    .backgroundColor(ColorTokens.SURFACE_PRIMARY)
    .padding({
      left: SpacingTokens.MD,
      right: SpacingTokens.MD,
      top: SpacingTokens.LG,
      bottom: SpacingTokens.MD
    })
  }
}
