/**
 * RegisterPage -- local register entry.
 *
 * Function #1: local register and restore startup flow.
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
import { validateRegisterForm } from '../common/utils/ValidationUtils'

@Entry
@Component
struct RegisterPage {
  @State phone: string = ''
  @State password: string = ''
  @State confirmPassword: string = ''
  @State phoneError: string = ''
  @State passwordError: string = ''
  @State confirmError: string = ''
  @State generalError: string = ''
  @State loading: boolean = false

  private getHostContextOrNull(): Context | null {
    const hostContext = this.getUIContext().getHostContext()
    if (hostContext === undefined || hostContext === null) {
      return null
    }
    return hostContext as Context
  }

  handleRegister(): void {
    this.generalError = ''
    const result = validateRegisterForm(this.phone, this.password, this.confirmPassword)
    this.phoneError = result.phoneError
    this.passwordError = result.passwordError
    this.confirmError = result.confirmError

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
      const authResult = await AuthService.registerLocal(context, this.phone, this.password)
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
    items.push(createStageRailItem('注册', true, false))
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

            Text('创建账号后，训练计划、回顾和本地记录都会接到同一条主线。')
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
              .lineHeight(FontTokens.BODY_LINE_HEIGHT)
              .width('100%')

            StageRail({ items: this.getStageRailItems() })

            Row({ space: SpacingTokens.SM }) {
              this.buildAuthMetricTile('模式', '本地优先')
              this.buildAuthMetricTile('目标', '进入训练主线')
            }
            .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        AppCard({ variant: 'panel', cardPadding: 'default' }) {
          Column({ space: SpacingTokens.MD }) {
            Text('本地注册')
              .fontSize(FontTokens.TITLE_SIZE)
              .fontWeight(FontTokens.TITLE_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text('先创建本地账号，再进入目标设置和训练流程。')
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
              placeholder: '请输入密码（至少 6 位）',
              type: 'password',
              maxLength: 20,
              errorMessage: this.passwordError
            })

            AppInput({
              value: $confirmPassword,
              placeholder: '请再次输入密码',
              type: 'password',
              maxLength: 20,
              errorMessage: this.confirmError
            })

            if (this.generalError.length > 0) {
              Text(this.generalError)
                .fontSize(FontTokens.SMALL_SIZE)
                .fontColor(ColorTokens.ERROR)
                .width('100%')
            }

            AppButton({
              text: '注册',
              type: 'primary',
              buttonSize: 'large',
              block: true,
              loading: this.loading,
              onButtonClick: () => {
                this.handleRegister()
              }
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        AppCard({ variant: 'panel', cardPadding: 'compact' }) {
          Column({ space: SpacingTokens.MD }) {
            Text('已有账号')
              .fontSize(FontTokens.BODY_SIZE)
              .fontWeight(FontTokens.BODY_BOLD_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text('如果你已经有本地账号，直接登录即可恢复到当前训练主线。')
              .fontSize(FontTokens.CAPTION_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
              .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
              .width('100%')

            AppButton({
              text: '去登录',
              type: 'secondary',
              buttonSize: 'large',
              block: true,
              onButtonClick: () => {
                this.getUIContext().getRouter().pushUrl({ url: AppRoutes.LOGIN })
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
