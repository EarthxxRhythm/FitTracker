/**
 * RegisterPage —— 用户注册页面
 *
 * 功能 #1: 用户可输入手机号、密码、确认密码完成注册。
 * 前端校验: 手机号格式、密码长度≥6位、两次密码一致。
 * 注册成功后跳转至训练Tab首页。
 */
import { router } from '@kit.ArkUI'
import { AppButton } from '../components/AppButton'
import { AppInput } from '../components/AppInput'
import { validateRegisterForm } from '../common/utils/ValidationUtils'
import AuthService from '../common/services/AuthService'
import SessionManager from '../common/services/SessionManager'
import { ColorTokens, FontTokens, SpacingTokens } from '../common/styles/DesignTokens'
import { AppRoutes } from '../app/AppRoutes'

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
      const authResult = await AuthService.registerLocal(getContext(this), this.phone, this.password)
      this.loading = false
      if (authResult.success) {
        await SessionManager.saveToken(getContext(this), authResult.token)
        router.replaceUrl({ url: AppRoutes.STARTUP })
      } else {
        this.generalError = authResult.message
      }
    }, 500)
  }

  build() {
    // DESIGN: Register page uses centered layout with brand logo (DISPLAY_SIZE, PRIMARY color) + form inputs. No page header — brand acts as header.
    Column() {
      // 顶部区域：Logo 与标题
      Column() {
        Text('FitTracker')
          .fontSize(FontTokens.DISPLAY_SIZE)
          .lineHeight(FontTokens.DISPLAY_LINE_HEIGHT)
          .fontWeight(FontTokens.DISPLAY_WEIGHT)
          .fontColor(ColorTokens.PRIMARY)

        Text('创建你的账户，开启训练之旅')
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .margin({ top: SpacingTokens.XS })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .margin({ top: SpacingTokens.XXL, bottom: SpacingTokens.XL })

      // 中部：注册表单
      Column() {
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
          placeholder: '请输入密码（至少6位）',
          type: 'password',
          maxLength: 20,
          errorMessage: this.passwordError
        })
          .margin({ top: SpacingTokens.MD })

        AppInput({
          value: $confirmPassword,
          placeholder: '请再次输入密码',
          type: 'password',
          maxLength: 20,
          errorMessage: this.confirmError
        })
          .margin({ top: SpacingTokens.MD })

        if (this.generalError.length > 0) {
          Row() {
            Text(this.generalError)
              .fontSize(FontTokens.SMALL_SIZE)
              .fontColor(ColorTokens.ERROR)
              .width('100%')
          }
          .width('100%')
          .margin({ top: SpacingTokens.SM })
        }
      }
      .width('100%')
      .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD })

      // 下部：注册按钮 + 跳转登录链接
      Column() {
        AppButton({
          text: '注册',
          type: 'primary',
          buttonSize: 'large',
          block: true,
          loading: this.loading,
          onButtonClick: () => { this.handleRegister() }
        })
          .margin({ top: SpacingTokens.LG })

        Row() {
          Text('已有账号？')
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
          Text('登录')
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.PRIMARY)
            .fontWeight(FontWeight.Medium)
            .onClick(() => {
              router.pushUrl({ url: AppRoutes.LOGIN })
            })
        }
        .margin({ top: SpacingTokens.MD })
      }
      .width('100%')
      .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD })

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.SURFACE_SECONDARY)
  }
}
