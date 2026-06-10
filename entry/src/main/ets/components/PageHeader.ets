/**
 * PageHeader —— 页面标题栏
 * 功能 #26
 */
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens, TouchTokens } from '../common/styles/DesignTokens'

@Component
export struct PageHeader {
  @Prop title: string = ''
  @Prop showBack: boolean = true
  onBackClick?: () => void

  private handleBack(): void {
    if (this.onBackClick) {
      this.onBackClick()
      return
    }
    this.getUIContext().getRouter().back()
  }

  build() {
    Row() {
      if (this.showBack) {
        Row() {
          Text('<')
            .fontSize(FontTokens.TITLE_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(ColorTokens.TEXT_PRIMARY)
        }
        .width(TouchTokens.MIN_TARGET)
        .height(TouchTokens.MIN_TARGET)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(ColorTokens.SURFACE_SECONDARY)
        .borderRadius(RadiusTokens.MD)
        .border({ width: 1, color: ColorTokens.BORDER_SUBTLE })
        .onClick(() => {
          this.handleBack()
        })
      } else {
        Blank()
          .width(TouchTokens.MIN_TARGET)
          .height(TouchTokens.MIN_TARGET)
      }

      Text(this.title)
        .fontSize(FontTokens.HEADLINE_SIZE)
        .fontWeight(FontWeight.Bold)
        .fontColor(ColorTokens.TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .margin({ left: SpacingTokens.MD, right: SpacingTokens.MD })

      Blank()
        .width(TouchTokens.MIN_TARGET)
        .height(TouchTokens.MIN_TARGET)
    }
    .width('100%')
    .backgroundColor(ColorTokens.SURFACE_HEADER)
    .padding({
      left: SpacingTokens.MD,
      right: SpacingTokens.MD,
      top: SpacingTokens.LG,
      bottom: SpacingTokens.MD
    })
    .border({
      width: 1,
      color: ColorTokens.DIVIDER
    })
  }
}
