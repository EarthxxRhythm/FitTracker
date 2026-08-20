/** PencilLoginPage —— FitTracker Login 原型页。功能 #27 */
import { AppRoutes } from '../../app/AppRoutes'
import AuthService from '../../common/services/AuthService'
import SessionManager from '../../common/services/SessionManager'
import { Context } from '@kit.AbilityKit'
import { ColorTokens } from '../../common/styles/DesignTokens'

@Entry
@Component
struct PencilLoginPage {
  private static readonly DESIGN_WIDTH: number = 430
  private static readonly VIEWPORT_WIDTH: number = 390
  private static readonly SCALE: number = PencilLoginPage.VIEWPORT_WIDTH / PencilLoginPage.DESIGN_WIDTH

  @State account: string = ''
  @State password: string = ''
  @State message: string = ''
  @State loading: boolean = false

  private contextOrNull(): Context | null {
    const host = this.getUIContext().getHostContext()
    return host === undefined || host === null ? null : host as Context
  }

  private async login(): Promise<void> {
    if (this.account.length === 0) {
      this.message = '请输入手机号或邮箱'
      return
    }
    if (this.password.length === 0) {
      this.message = '请输入密码'
      return
    }
    const context = this.contextOrNull()
    if (context === null) {
      this.message = '当前页面不可用，请重试'
      return
    }
    this.loading = true
    const result = await AuthService.loginLocal(context, this.account, this.password)
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
        Image($rawfile('fittracker-logo-pulse.svg'))
          .width(26 * PencilLoginPage.SCALE)
          .height(26 * PencilLoginPage.SCALE)
      }
      .width(48 * PencilLoginPage.SCALE)
      .height(48 * PencilLoginPage.SCALE)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#1A50ECA7')
      .borderRadius(16 * PencilLoginPage.SCALE)
      .border({ width: 1, color: '#4D50ECA7' })
      Text('FITTRACKER')
        .fontFamily('Inter')
        .fontSize(13 * PencilLoginPage.SCALE)
        .fontWeight(FontWeight.Bold)
        .letterSpacing(2.4 * PencilLoginPage.SCALE)
        .fontColor('#F7FBF8')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildAuthHead() {
    Column({ space: 10 * PencilLoginPage.SCALE }) {
      Text('WELCOME BACK')
        .fontFamily('Geist Mono')
        .fontSize(11 * PencilLoginPage.SCALE)
        .fontWeight(600)
        .letterSpacing(1.5 * PencilLoginPage.SCALE)
        .fontColor('#50ECA7')
      Text('欢迎回来')
        .fontFamily('Noto Sans SC')
        .fontSize(35 * PencilLoginPage.SCALE)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
      Text('登录后，同步你的训练进度与身体数据')
        .fontFamily('Noto Sans SC')
        .fontSize(15 * PencilLoginPage.SCALE)
        .fontColor('#A6FFFFFF')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildLoginField(label: string, placeholder: string, iconName: string, isPassword: boolean) {
    Column({ space: 8 * PencilLoginPage.SCALE }) {
      Text(label)
        .fontFamily('Noto Sans SC')
        .fontSize(13 * PencilLoginPage.SCALE)
        .fontWeight(FontWeight.Medium)
        .fontColor('#9EFFFFFF')
        .width('100%')
      Row({ space: 12 * PencilLoginPage.SCALE }) {
        if (iconName === 'mail') {
          Image($rawfile('pencil-lucide-mail.svg'))
            .width(19 * PencilLoginPage.SCALE)
            .height(19 * PencilLoginPage.SCALE)
            .fillColor('#8FFFFFFF')
        } else {
          Image($rawfile('pencil-lucide-lock-keyhole.svg'))
            .width(19 * PencilLoginPage.SCALE)
            .height(19 * PencilLoginPage.SCALE)
            .fillColor('#8FFFFFFF')
        }
        TextInput({ text: isPassword ? this.password : this.account, placeholder: placeholder })
          .type(isPassword ? InputType.Password : InputType.Normal)
          .showPasswordIcon(false)
          .layoutWeight(1)
          .fontFamily('Noto Sans SC')
          .fontSize(16 * PencilLoginPage.SCALE)
          .fontColor('#F7FBF8')
          .placeholderColor('#66FFFFFF')
          .backgroundColor(Color.Transparent)
          .padding(0)
          .onChange((value: string) => {
            if (isPassword) {
              this.password = value
            } else {
              this.account = value
            }
          })
        if (isPassword) {
          Image($rawfile('pencil-lucide-eye.svg'))
            .width(20 * PencilLoginPage.SCALE)
            .height(20 * PencilLoginPage.SCALE)
            .fillColor('#8FFFFFFF')
        }
      }
      .width('100%')
      .height(52 * PencilLoginPage.SCALE)
      .padding({ left: 16 * PencilLoginPage.SCALE, right: 16 * PencilLoginPage.SCALE })
      .backgroundColor('#08FFFFFF')
      .borderRadius(18 * PencilLoginPage.SCALE)
      .border({ width: 1 * PencilLoginPage.SCALE, color: '#14FFFFFF' })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
  }

  @Builder
  private buildAuthAux() {
    Row() {
      Row({ space: 8 * PencilLoginPage.SCALE }) {
        Text('□')
          .fontFamily('HarmonyOS Sans')
          .fontSize(18 * PencilLoginPage.SCALE)
          .fontColor('#8FFFFFFF')
        Text('记住我')
          .fontFamily('Noto Sans SC')
          .fontSize(13 * PencilLoginPage.SCALE)
          .fontColor('#99FFFFFF')
      }
      Text('忘记密码？')
        .fontFamily('Noto Sans SC')
        .fontSize(13 * PencilLoginPage.SCALE)
        .fontWeight(FontWeight.Bold)
        .fontColor('#50ECA7')
    }
    .width('100%')
    .height(20 * PencilLoginPage.SCALE)
    .justifyContent(FlexAlign.SpaceBetween)
  }

  @Builder
  private buildAuthDivider() {
    Row({ space: 12 * PencilLoginPage.SCALE }) {
      Divider().layoutWeight(1).color('#14FFFFFF')
      Text('其他登录方式')
        .fontFamily('Noto Sans SC')
        .fontSize(12 * PencilLoginPage.SCALE)
        .fontColor('#66FFFFFF')
      Divider().layoutWeight(1).color('#14FFFFFF')
    }
    .width('100%')
    .height(18 * PencilLoginPage.SCALE)
  }

  @Builder
  private buildSocialButton(label: string) {
    Text(label)
      .layoutWeight(1)
      .height(50 * PencilLoginPage.SCALE)
      .textAlign(TextAlign.Center)
      .fontFamily('Noto Sans SC')
      .fontSize(14 * PencilLoginPage.SCALE)
      .fontWeight(FontWeight.Medium)
      .fontColor('#F7FBF8')
      .backgroundColor('#08FFFFFF')
      .borderRadius(16 * PencilLoginPage.SCALE)
      .border({ width: 1 * PencilLoginPage.SCALE, color: '#1AFFFFFF' })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 180, colors: [['#0B0F13', 0], ['#0A0D12', 1]] })
      Column() {
        Scroll() {
          Column({ space: 20 * PencilLoginPage.SCALE }) {
            this.buildBrandHeader()
            this.buildAuthHead()
            Column({ space: 14 * PencilLoginPage.SCALE }) {
              this.buildLoginField('手机号 / 邮箱', '请输入手机号或邮箱', 'mail', false)
              this.buildLoginField('密码', '请输入密码', 'lock', true)
              this.buildAuthAux()

              if (this.message.length > 0) {
                Text(this.message)
                  .fontFamily('Noto Sans SC')
                  .fontSize(13 * PencilLoginPage.SCALE)
                  .fontColor(ColorTokens.ERROR)
                  .width('100%')
                  .textAlign(TextAlign.Center)
              }

              Button(this.loading ? '登录中…' : '登录')
                .width('100%')
                .height(52 * PencilLoginPage.SCALE)
                .padding(0)
                .fontFamily('Noto Sans SC')
                .fontSize(16 * PencilLoginPage.SCALE)
                .fontWeight(FontWeight.Bold)
                .fontColor('#07100B')
                .linearGradient({ angle: 90, colors: [['#47D994', 0], ['#53E7A5', 1]] })
                .borderRadius(18 * PencilLoginPage.SCALE)
                .shadow({ radius: 24, color: '#66000000', offsetX: 0, offsetY: 10 })
                .onClick(() => {
                  this.login()
                })

              this.buildAuthDivider()

              Row({ space: 12 * PencilLoginPage.SCALE }) {
                this.buildSocialButton('微信')
                this.buildSocialButton('Apple')
              }
              .width('100%')
            }
            .width('100%')

            Row({ space: 6 * PencilLoginPage.SCALE }) {
              Text('还没有账号？')
                .fontFamily('Noto Sans SC')
                .fontSize(14 * PencilLoginPage.SCALE)
                .fontColor('#99FFFFFF')
              Text('立即注册')
                .fontFamily('Noto Sans SC')
                .fontSize(14 * PencilLoginPage.SCALE)
                .fontWeight(FontWeight.Bold)
                .fontColor('#50ECA7')
                .onClick(() => {
                  this.getUIContext().getRouter().pushUrl({ url: AppRoutes.REGISTER })
                })
            }
            .width('100%')
            .height(24 * PencilLoginPage.SCALE)
            .justifyContent(FlexAlign.Center)
          }
          .width('100%')
          .padding({
            left: 24 * PencilLoginPage.SCALE,
            right: 24 * PencilLoginPage.SCALE,
            top: 76 * PencilLoginPage.SCALE,
            bottom: 28 * PencilLoginPage.SCALE
          })
        }
        .layoutWeight(1)
        .width('100%')

      }
      .width('100%')
      .height('100%')
      .padding({ left: 24 * PencilLoginPage.SCALE, right: 24 * PencilLoginPage.SCALE })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.BG_PRIMARY)
  }
}
