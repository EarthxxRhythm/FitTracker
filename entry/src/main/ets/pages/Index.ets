/**
 * Index —— 旧首页历史壳
 * 功能 #6：页面治理后保留的兼容入口，仅用于提示已迁移。
 */
import { AppRoutes } from '../app/AppRoutes'
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens } from '../common/styles/DesignTokens'

@Entry
@Component
export struct Index {
  private openHome(): void {
    this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.HOME })
  }

  build() {
    Column() {
      Column() {
        Text('旧首页已迁移')
          .fontSize(FontTokens.HEADLINE_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ColorTokens.TEXT_PRIMARY)
          .textAlign(TextAlign.Center)
        Text('新的首页入口请使用 HomePage。这里仅保留作历史兼容。')
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .textAlign(TextAlign.Center)
          .margin({ top: SpacingTokens.SM })
      }
      .width('100%')
      .padding(SpacingTokens.LG)
      .backgroundColor(ColorTokens.SURFACE_PRIMARY)
      .borderRadius(RadiusTokens.LG)
      .margin({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.XL })

      Button('打开新首页')
        .width('100%')
        .height(56)
        .fontSize(FontTokens.BODY_SIZE)
        .fontColor(ColorTokens.TEXT_ON_PRIMARY)
        .backgroundColor(ColorTokens.PRIMARY)
        .borderRadius(RadiusTokens.MD)
        .margin({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.LG })
        .onClick(() => {
          this.openHome()
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .backgroundColor(ColorTokens.BG_PRIMARY)
  }
}
