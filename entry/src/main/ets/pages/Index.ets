/**
 * Index —— 训练Tab首页（应用主页）
 *
 * 当前为占位骨架，展示欢迎信息与底部导航栏结构。
 * 后续迭代中将替换为完整的"今日训练视图"（Feature #11）。
 */
import { router } from '@kit.ArkUI'
import { ColorTokens, FontTokens, SpacingTokens } from '../common/styles/DesignTokens'

@Entry
@Component
struct Index {
  @State message: string = 'FitTracker'

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        Text(this.message)
          .fontSize(FontTokens.HEADLINE_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ColorTokens.PRIMARY)
      }
      .width('100%')
      .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.LG })
      .backgroundColor(ColorTokens.SURFACE_PRIMARY)

      // 中间内容区
      Column() {
        Text('训练首页')
          .fontSize(FontTokens.TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(ColorTokens.TEXT_PRIMARY)
          .margin({ top: SpacingTokens.XL })

        Text('请先选择或启用训练计划')
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .margin({ top: SpacingTokens.SM })

        Text('注册功能已就绪，点击下方链接体验')
          .fontSize(FontTokens.SMALL_SIZE)
          .fontColor(ColorTokens.TEXT_DISABLED)
          .margin({ top: SpacingTokens.LG })

        Text('前往注册 →')
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.PRIMARY)
          .fontWeight(FontWeight.Medium)
          .margin({ top: SpacingTokens.MD })
          .onClick(() => {
            router.pushUrl({ url: 'pages/RegisterPage' })
          })
      }
      .width('100%')
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)

      // 底部导航栏占位
      Row() {
        Text('训练')
          .fontSize(FontTokens.SMALL_SIZE)
          .fontColor(ColorTokens.PRIMARY)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('动作库')
          .fontSize(FontTokens.SMALL_SIZE)
          .fontColor(ColorTokens.NEUTRAL_300)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('统计')
          .fontSize(FontTokens.SMALL_SIZE)
          .fontColor(ColorTokens.NEUTRAL_300)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('我的')
          .fontSize(FontTokens.SMALL_SIZE)
          .fontColor(ColorTokens.NEUTRAL_300)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            router.pushUrl({ url: 'pages/ProfilePage' })
          })
      }
      .width('100%')
      .height(56)
      .backgroundColor(ColorTokens.SURFACE_PRIMARY)
      .border({ width: { top: 0.5 }, color: ColorTokens.NEUTRAL_100 })
      .padding({ bottom: SpacingTokens.SM })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.SURFACE_SECONDARY)
  }
}
