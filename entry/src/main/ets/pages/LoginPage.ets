/**
 * LoginPage —— 用户登录页面（占位页）
 *
 * 功能 #2 & #3 将由后续 Coding Agent 实现完整登录 UI。
 * 当前提供最小骨架：标题 + 注册链接，确保 RegisterPage 的导航目标存在。
 */
import { router } from '@kit.ArkUI'
import { AppButton } from '../components/AppButton'
import { ColorTokens, FontTokens, SpacingTokens } from '../common/styles/DesignTokens'

@Entry
@Component
struct LoginPage {
  build() {
    Column() {
      // Logo
      Text('FitTracker')
        .fontSize(FontTokens.DISPLAY_SIZE)
        .fontWeight(FontWeight.Bold)
        .fontColor(ColorTokens.PRIMARY)
        .margin({ top: SpacingTokens.XXL })

      // 标题
      Text('欢迎回来')
        .fontSize(FontTokens.HEADLINE_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(ColorTokens.TEXT_PRIMARY)
        .margin({ top: SpacingTokens.MD })

      Text('登录功能即将上线')
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .margin({ top: SpacingTokens.XS })

      Blank()

      // 跳转注册
      AppButton({
        text: '没有账号？立即注册',
        type: 'ghost',
        size: 'large',
        block: true,
        onButtonClick: () => {
          router.replaceUrl({ url: 'pages/RegisterPage' })
        }
      })
        .margin({ bottom: SpacingTokens.LG })
    }
    .width('100%')
    .height('100%')
    .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD })
    .backgroundColor(ColorTokens.SURFACE_SECONDARY)
  }
}
