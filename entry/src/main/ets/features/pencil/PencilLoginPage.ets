/** PencilLoginPage —— FitTracker Login 原型页。功能 #27 */
import { AppRoutes } from '../../app/AppRoutes'
import AuthService from '../../common/services/AuthService'
import SessionManager from '../../common/services/SessionManager'
import { Context } from '@kit.AbilityKit'
import { ColorTokens, FontTokens, ShadowTokens } from '../../common/styles/DesignTokens'

@Entry
@Component
struct PencilLoginPage {
  private static readonly DESIGN_WIDTH: number = 430
  private static readonly VIEWPORT_WIDTH: number = 390
  private static readonly SCALE: number = PencilLoginPage.VIEWPORT_WIDTH / PencilLoginPage.DESIGN_WIDTH

  @State phone: string = ''
  @State password: string = ''
  @State message: string = ''
  @State loading: boolean = false

  private contextOrNull(): Context | null {
    const host = this.getUIContext().getHostContext()
    return host === undefined || host === null ? null : host as Context
  }

  private async login(): Promise<void> {
    if (this.phone.length === 0 || this.password.length === 0) {
      this.message = '请输入手机号和密码'
      return
    }
    const context = this.contextOrNull()
    if (context === null) {
      this.message = '当前页面不可用，请重试'
      return
    }
    this.loading = true
    const result = await AuthService.loginLocal(context, this.phone, this.password)
    this.loading = false
    if (!result.success) {
      this.message = result.message
      return
    }
    await SessionManager.saveToken(context, result.token)
    this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.STARTUP })
  }

  @Builder
  private buildBrandHeader() {
    Column({ space: 12 * PencilLoginPage.SCALE }) {
      Row() {
        Image($rawfile('pencil-lucide-activity.svg'))
          .width(30 * PencilLoginPage.SCALE)
          .height(30 * PencilLoginPage.SCALE)
      }
      .width(64 * PencilLoginPage.SCALE)
      .height(64 * PencilLoginPage.SCALE)
      .justifyContent(FlexAlign.Center)
      .linearGradient({ angle: 180, colors: [['#47D994', 0], ['#2EBE78', 1]] })
      .borderRadius(22 * PencilLoginPage.SCALE)
      .shadow(ShadowTokens.ACCENT)
      Text('FITTRACKER')
        .fontFamily('Geist')
        .fontSize(14 * PencilLoginPage.SCALE)
        .fontWeight(FontWeight.Bold)
        .letterSpacing(2.4 * PencilLoginPage.SCALE)
        .fontColor('#F7FBF8')
      Text('训练，从今天开始')
        .fontFamily('Inter')
        .fontSize(13 * PencilLoginPage.SCALE)
        .fontColor('#8FFFFFFF')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildLoginForm() {
    Column({ space: 14 * PencilLoginPage.SCALE }) {
      Text('欢迎回来')
        .fontFamily('Geist')
        .fontSize(28 * PencilLoginPage.SCALE)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
      Text('登录你的 FitTracker 账户，继续今天的训练。')
        .fontFamily('Inter')
        .fontSize(13 * PencilLoginPage.SCALE)
        .fontColor('#8FFFFFFF')
        .width('100%')
      Row({ space: 12 * PencilLoginPage.SCALE }) {
        Image($rawfile('pencil-lucide-mail.svg'))
          .width(19 * PencilLoginPage.SCALE)
          .height(19 * PencilLoginPage.SCALE)
        TextInput({ text: this.phone, placeholder: '手机号' })
          .type(InputType.Number)
          .layoutWeight(1)
          .fontFamily('Inter')
          .fontSize(14 * PencilLoginPage.SCALE)
          .fontColor('#F7FBF8')
          .placeholderColor('#8FFFFFFF')
          .padding(0)
          .onChange((value: string) => { this.phone = value })
      }
      .width('100%')
      .height(56 * PencilLoginPage.SCALE)
      .padding({ left: 16 * PencilLoginPage.SCALE, right: 16 * PencilLoginPage.SCALE })
      .backgroundColor(ColorTokens.SURFACE_GLASS_SOFT)
      .borderRadius(18 * PencilLoginPage.SCALE)
      .border({ width: 1 * PencilLoginPage.SCALE, color: ColorTokens.BORDER_HAIRLINE })
      .alignItems(VerticalAlign.Center)
      Row({ space: 12 * PencilLoginPage.SCALE }) {
        Image($rawfile('pencil-lucide-lock-keyhole.svg'))
          .width(19 * PencilLoginPage.SCALE)
          .height(19 * PencilLoginPage.SCALE)
        TextInput({ text: this.password, placeholder: '密码' })
          .type(InputType.Password)
          .showPasswordIcon(false)
          .layoutWeight(1)
          .fontFamily('Inter')
          .fontSize(14 * PencilLoginPage.SCALE)
          .fontColor('#F7FBF8')
          .placeholderColor('#8FFFFFFF')
          .padding(0)
          .onChange((value: string) => { this.password = value })
        Image($rawfile('pencil-lucide-eye.svg'))
          .width(19 * PencilLoginPage.SCALE)
          .height(19 * PencilLoginPage.SCALE)
      }
      .width('100%')
      .height(56 * PencilLoginPage.SCALE)
      .padding({ left: 16 * PencilLoginPage.SCALE, right: 16 * PencilLoginPage.SCALE })
      .backgroundColor(ColorTokens.SURFACE_GLASS_SOFT)
      .borderRadius(18 * PencilLoginPage.SCALE)
      .border({ width: 1 * PencilLoginPage.SCALE, color: ColorTokens.BORDER_HAIRLINE })
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.SpaceBetween)
      Row() {
        Text('忘记密码？')
          .fontFamily('Inter')
          .fontSize(12 * PencilLoginPage.SCALE)
          .fontWeight(FontWeight.Medium)
          .fontColor('#50ECA7')
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      Row() {
        Text(this.loading ? '登录中…' : '登录')
          .fontFamily('Inter')
          .fontSize(15 * PencilLoginPage.SCALE)
          .fontWeight(FontWeight.Bold)
          .fontColor('#08110D')
      }
      .width('100%')
      .height(56 * PencilLoginPage.SCALE)
      .justifyContent(FlexAlign.Center)
      .linearGradient({ angle: 180, colors: [['#47D994', 0], ['#53E7A5', 1]] })
      .borderRadius(20 * PencilLoginPage.SCALE)
      .shadow(ShadowTokens.ACCENT)
      .onClick(() => { this.login() })
      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(13 * PencilLoginPage.SCALE)
          .fontColor(ColorTokens.ERROR)
          .width('100%')
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildSocialLogin() {
    Column({ space: 14 * PencilLoginPage.SCALE }) {
      Row({ space: 12 * PencilLoginPage.SCALE }) {
        Divider().layoutWeight(1).color('#14FFFFFF')
        Text('或使用以下方式登录')
          .fontFamily('Inter')
          .fontSize(11 * PencilLoginPage.SCALE)
          .fontColor('#66FFFFFF')
        Divider().layoutWeight(1).color('#14FFFFFF')
      }
      .width('100%')
      .height(18 * PencilLoginPage.SCALE)
      Row({ space: 12 * PencilLoginPage.SCALE }) {
        this.buildSocialButton('  Apple')
        this.buildSocialButton('G  Google')
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private buildSocialButton(label: string) {
    Text(label)
      .width('50%')
      .height(52 * PencilLoginPage.SCALE)
      .textAlign(TextAlign.Center)
      .fontFamily('Inter')
      .fontSize(13 * PencilLoginPage.SCALE)
      .fontWeight(FontWeight.Medium)
      .fontColor('#F7FBF8')
      .backgroundColor(ColorTokens.SURFACE_GLASS_SOFT)
      .borderRadius(18 * PencilLoginPage.SCALE)
      .border({ width: 1 * PencilLoginPage.SCALE, color: ColorTokens.BORDER_HAIRLINE })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 180, colors: [['#0B0F13', 0], ['#0A0D12', 1]] })
      Column() {
        Column({ space: 24 * PencilLoginPage.SCALE }) {
          this.buildBrandHeader()
          Column({ space: 24 * PencilLoginPage.SCALE }) {
            this.buildLoginForm()
            this.buildSocialLogin()
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        Row({ space: 6 * PencilLoginPage.SCALE }) {
          Text('还没有账户？')
            .fontFamily('Inter')
            .fontSize(12 * PencilLoginPage.SCALE)
            .fontColor('#8FFFFFFF')
          Text('立即注册')
            .fontFamily('Inter')
            .fontSize(12 * PencilLoginPage.SCALE)
            .fontWeight(FontWeight.Bold)
            .fontColor('#50ECA7')
            .onClick(() => { this.getUIContext().getRouter().pushUrl({ url: AppRoutes.REGISTER }) })
        }
        .width('100%')
        .height(24 * PencilLoginPage.SCALE)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 18 * PencilLoginPage.SCALE, right: 18 * PencilLoginPage.SCALE, bottom: 28 * PencilLoginPage.SCALE })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.BG_PRIMARY)
  }
}
