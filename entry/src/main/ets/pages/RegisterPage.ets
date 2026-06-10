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

  @Builder
  buildStageRail() {
    Row({ space: SpacingTokens.SM }) {
      this.buildStageChip('注册', true)
      this.buildStageChip('训练', false)
      this.buildStageChip('回顾', false)
    }
    .width('100%')
  }

  @Builder
  buildStageChip(label: string, active: boolean) {
    Text(label)
      .fontSize(FontTokens.SMALL_SIZE)
      .fontWeight(active ? FontWeight.Medium : FontTokens.SMALL_WEIGHT)
      .fontColor(active ? ColorTokens.TEXT_PRIMARY : ColorTokens.TEXT_TERTIARY)
      .padding({
        top: SpacingTokens.XS,
        bottom: SpacingTokens.XS,
        left: SpacingTokens.SM,
        right: SpacingTokens.SM
      })
      .backgroundColor(active ? ColorTokens.SURFACE_ELEVATED : ColorTokens.SURFACE_SECONDARY)
      .borderRadius(RadiusTokens.FULL)
      .border({
        width: 1,
        color: active ? ColorTokens.BORDER_ACCENT : ColorTokens.BORDER_SUBTLE
      })
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

            this.buildStageRail()
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        AppCard({ variant: 'outlined', cardPadding: 'default' }) {
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

        AppCard({ variant: 'outlined', cardPadding: 'compact' }) {
          Column({ space: SpacingTokens.SM }) {
            Text('已有账号')
              .fontSize(FontTokens.BODY_SIZE)
              .fontWeight(FontTokens.BODY_BOLD_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Row() {
              Text('已经注册过？')
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)

              Text('登录')
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.PRIMARY)
                .fontWeight(FontWeight.Medium)
                .margin({ left: SpacingTokens.XS })
                .onClick(() => {
                  this.getUIContext().getRouter().pushUrl({ url: AppRoutes.LOGIN })
                })
            }
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
