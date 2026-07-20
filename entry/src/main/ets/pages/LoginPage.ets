/**
 * LoginPage -- local login entry.
 *
 * Function #2: local login and restore startup flow.
 */
import { Context } from '@kit.AbilityKit'
import { AppRoutes } from '../app/AppRoutes'
import { AppButton } from '../components/AppButton'
import { AppCard } from '../components/AppCard'
import { AppInput } from '../components/AppInput'
import { createStageRailItem, StageRail, StageRailItem } from '../components/StageRail'
import AuthService from '../common/services/AuthService'
import SessionManager from '../common/services/SessionManager'
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens } from '../common/styles/DesignTokens'
import { validateLoginForm } from '../common/utils/ValidationUtils'

@Entry
@Component
struct LoginPage {
  @State phone: string = ''
  @State password: string = ''
  @State phoneError: string = ''
  @State passwordError: string = ''
  @State generalError: string = ''
  @State loading: boolean = false

  private getHostContextOrNull(): Context | null {
    const hostContext = this.getUIContext().getHostContext()
    if (hostContext === undefined || hostContext === null) {
      return null
    }
    return hostContext as Context
  }

  handleLogin(): void {
    this.generalError = ''
    const result = validateLoginForm(this.phone, this.password)
    this.phoneError = result.phoneError
    this.passwordError = result.passwordError

    if (!result.allValid) {
      return
    }

    this.loading = true
    setTimeout(async () => {
      const context: Context | null = this.getHostContextOrNull()
      if (context === null) {
        this.loading = false
        this.generalError = '当前页面上下文不可用，请重试。'
        return
      }
      const authResult = await AuthService.loginLocal(context, this.phone, this.password)
      this.loading = false
      if (authResult.success) {
        await SessionManager.saveToken(context, authResult.token)
        this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.STARTUP })
      } else {
        this.generalError = authResult.message
      }
    }, 500)
  }

  getStageRailItems(): StageRailItem[] {
    const items: StageRailItem[] = []
    items.push(createStageRailItem('登录', true, false))
    items.push(createStageRailItem('训练', false, false))
    items.push(createStageRailItem('回顾', false, false))
    return items
  }

  @Builder
  buildAuthMetricTile(label: string, value: string) {
    Column({ space: SpacingTokens.XS }) {
      Text(label)
        .fontSize(FontTokens.SMALL_SIZE)
        .fontColor(ColorTokens.TEXT_TERTIARY)

      Text(value)
        .fontSize(FontTokens.BODY_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(ColorTokens.TEXT_PRIMARY)
    }
    .layoutWeight(1)
    .padding(SpacingTokens.MD)
    .backgroundColor(ColorTokens.BG_ELEVATED)
    .borderRadius(RadiusTokens.MD)
    .border({ width: 1, color: ColorTokens.BORDER_SUBTLE })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll() {
      Column({ space: SpacingTokens.LG }) {
        AppCard({ variant: 'panel', cardPadding: 'default' }) {
          Column({ space: SpacingTokens.MD }) {
            Text('FitTracker')
              .fontSize(FontTokens.DISPLAY_SIZE)
              .lineHeight(FontTokens.DISPLAY_LINE_HEIGHT)
              .fontWeight(FontTokens.DISPLAY_WEIGHT)
              .fontColor(ColorTokens.PRIMARY)

            Text('欢迎回来，继续你的训练主线。')
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
              .lineHeight(FontTokens.BODY_LINE_HEIGHT)
              .width('100%')

            StageRail({ items: this.getStageRailItems() })

            Row({ space: SpacingTokens.SM }) {
              this.buildAuthMetricTile('模式', '本地优先')
              this.buildAuthMetricTile('状态', '恢复训练主线')
            }
            .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        AppCard({ variant: 'panel', cardPadding: 'default' }) {
          Column({ space: SpacingTokens.MD }) {
            Text('本地登录')
              .fontSize(FontTokens.TITLE_SIZE)
              .fontWeight(FontTokens.TITLE_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text('输入手机号和密码后，系统会直接恢复到当前本地训练流程。')
              .fontSize(FontTokens.CAPTION_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
              .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
              .width('100%')

            AppInput({
              value: $phone,
              placeholder: '请输入手机号',
              type: 'number',
              prefix: '+86',
              maxLength: 11,
              errorMessage: this.phoneError
            })

            AppInput({
              value: $password,
              placeholder: '请输入密码',
              type: 'password',
              maxLength: 20,
              errorMessage: this.passwordError
            })

            if (this.generalError.length > 0) {
              Text(this.generalError)
                .fontSize(FontTokens.SMALL_SIZE)
                .fontColor(ColorTokens.ERROR)
                .width('100%')
            }

            AppButton({
              text: '登录',
              type: 'primary',
              buttonSize: 'large',
              block: true,
              loading: this.loading,
              onButtonClick: () => {
                this.handleLogin()
              }
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        AppCard({ variant: 'panel', cardPadding: 'compact' }) {
          Column({ space: SpacingTokens.MD }) {
            Text('首次进入')
              .fontSize(FontTokens.BODY_SIZE)
              .fontWeight(FontTokens.BODY_BOLD_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text('先创建本地账号，再进入目标设置和今日训练主线。')
              .fontSize(FontTokens.CAPTION_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
              .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
              .width('100%')

            AppButton({
              text: '去注册',
              type: 'secondary',
              buttonSize: 'large',
              block: true,
              onButtonClick: () => {
                this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.REGISTER })
              }
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
      }
      .width('100%')
      .padding(SpacingTokens.LG)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.BG_PRIMARY)
  }
}
