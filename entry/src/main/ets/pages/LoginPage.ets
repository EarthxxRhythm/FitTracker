/**
 * LoginPage —— 用户登录页面
 *
 * 功能 #2: 用户可输入已注册手机号及密码完成登录，
 *          登录成功后跳转至训练Tab首页；
 *          若未注册则提示引导至注册页。
 * 功能 #3: 页面垂直居中布局，顶部品牌Logo与标语，
 *          中部手机号输入框（带+86前缀）与密码输入框，
 *          底部全宽"登录"主按钮，下方"注册"文字链接跳转。
 */
import { router } from '@kit.ArkUI'
import { AppButton } from '../components/AppButton'
import { AppInput } from '../components/AppInput'
import { validateLoginForm } from '../common/utils/ValidationUtils'
import AuthService from '../common/services/AuthService'
import SessionManager from '../common/services/SessionManager'
import { ColorTokens, FontTokens, SpacingTokens } from '../common/styles/DesignTokens'

@Entry
@Component
struct LoginPage {
  @State phone: string = ''
  @State password: string = ''
  @State phoneError: string = ''
  @State passwordError: string = ''
  @State generalError: string = ''
  @State loading: boolean = false

  handleLogin(): void {
    this.generalError = ''
    const result = validateLoginForm(this.phone, this.password)
    this.phoneError = result.phoneError
    this.passwordError = result.passwordError

    if (!result.allValid) {
      return
    }

    this.loading = true
    const authResult = AuthService.login(this.phone, this.password)
    setTimeout(async () => {
      this.loading = false
      if (authResult.success) {
        await SessionManager.saveToken(getContext(this), authResult.token)
        router.replaceUrl({ url: 'pages/Index' })
      } else {
        this.generalError = authResult.message
      }
    }, 500)
  }

  build() {
    // DESIGN: Login page uses centered layout with brand logo + form inputs.
    Column() {
      // 顶部：Logo 与标语
      Column() {
        Text('FitTracker')
          .fontSize(FontTokens.DISPLAY_SIZE)
          .lineHeight(FontTokens.DISPLAY_LINE_HEIGHT)
          .fontWeight(FontTokens.DISPLAY_WEIGHT)
          .fontColor(ColorTokens.PRIMARY)

        Text('欢迎回来，继续你的训练')
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .margin({ top: SpacingTokens.XS })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .margin({ bottom: SpacingTokens.XL })

      // 中部：登录表单
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
          placeholder: '请输入密码',
          type: 'password',
          maxLength: 20,
          errorMessage: this.passwordError
        })
          .margin({ top: SpacingTokens.MD })

        if (this.generalError) {
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

      // 下部：登录按钮 + 跳转注册链接
      Column() {
        AppButton({
          text: '登录',
          type: 'primary',
          buttonSize: 'large',
          block: true,
          loading: this.loading,
          onButtonClick: () => { this.handleLogin() }
        })
          .margin({ top: SpacingTokens.LG })

        Row() {
          Text('没有账号？')
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
          Text('注册')
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.PRIMARY)
            .fontWeight(FontWeight.Medium)
            .onClick(() => {
              router.replaceUrl({ url: 'pages/RegisterPage' })
            })
        }
        .margin({ top: SpacingTokens.MD })
      }
      .width('100%')
      .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(ColorTokens.SURFACE_SECONDARY)
  }
}
