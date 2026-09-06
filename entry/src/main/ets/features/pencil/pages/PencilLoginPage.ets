/** PencilLoginPage —— FitTracker Login 原型页。功能 #27 */
import { AppRoutes } from '../../app/AppRoutes'
import AuthService from '../../common/services/AuthService'
import SessionManager from '../../common/services/SessionManager'
import { Context } from '@kit.AbilityKit'
import { ColorTokens, MotionTokens } from '../../common/styles/DesignTokens'

@Entry
@Component
struct PencilLoginPage {

  @State account: string = ''
  @State password: string = ''
  @State message: string = ''
  @State loading: boolean = false
  @State ctaPressed: boolean = false
  @State socialKey: string = ''
  @State linkKey: string = ''
  @State eyePressed: boolean = false

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
    Column({ space: 12 }) {
      Row() {
        Image($rawfile('fittracker-logo-pulse.svg'))
          .width(26)
          .height(26)
      }
      .width(48)
      .height(48)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#1A50ECA7')
      .borderRadius(16)
      .border({ width: 1, color: '#4D50ECA7' })
      Text('FITTRACKER')
        .fontFamily('Inter')
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .letterSpacing(2.4)
        .fontColor('#F7FBF8')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildAuthHead() {
    Column({ space: 10 }) {
      Text('WELCOME BACK')
        .fontFamily('Geist Mono')
        .fontSize(11)
        .fontWeight(600)
        .letterSpacing(1.5)
        .fontColor('#50ECA7')
      Text('欢迎回来')
        .fontFamily('Noto Sans SC')
        .fontSize(35)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
      Text('登录后，同步你的训练进度与身体数据')
        .fontFamily('Noto Sans SC')
        .fontSize(15)
        .fontColor('#A6FFFFFF')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildLoginField(label: string, placeholder: string, iconName: string, isPassword: boolean) {
    Column({ space: 8 }) {
      Text(label)
        .fontFamily('Noto Sans SC')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#9EFFFFFF')
        .width('100%')
      Row({ space: 12 }) {
        if (iconName === 'mail') {
          Image($rawfile('pencil-lucide-mail.svg'))
            .width(19)
            .height(19)
            .fillColor('#8FFFFFFF')
        } else {
          Image($rawfile('pencil-lucide-lock-keyhole.svg'))
            .width(19)
            .height(19)
            .fillColor('#8FFFFFFF')
        }
        TextInput({ text: isPassword ? this.password : this.account, placeholder: placeholder })
          .type(isPassword ? InputType.Password : InputType.Normal)
          .showPasswordIcon(false)
          .layoutWeight(1)
          .fontFamily('Noto Sans SC')
          .fontSize(16)
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
            .width(20)
            .height(20)
            .fillColor('#8FFFFFFF')
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.eyePressed = true
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.eyePressed = false
              }
            })
            .scale({ x: this.eyePressed ? MotionTokens.PRESS_ICON : 1, y: this.eyePressed ? MotionTokens.PRESS_ICON : 1 })
            .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
        }
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#08FFFFFF')
      .borderRadius(18)
      .border({ width: 1, color: '#14FFFFFF' })
      .alignItems(VerticalAlign.Center)
      .animation({ duration: MotionTokens.DURATION_COLOR_BASE, curve: Curve.EaseInOut })
    }
    .width('100%')
  }

  @Builder
  private buildAuthAux() {
    Row() {
      Row({ space: 8 }) {
        Text('□')
          .fontFamily('HarmonyOS Sans')
          .fontSize(18)
          .fontColor('#8FFFFFFF')
        Text('记住我')
          .fontFamily('Noto Sans SC')
          .fontSize(13)
          .fontColor('#99FFFFFF')
      }
      Text('忘记密码？')
        .fontFamily('Noto Sans SC')
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor('#50ECA7')
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.linkKey = 'forgot'
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.linkKey = ''
          }
        })
        .scale({ x: this.linkKey === 'forgot' ? MotionTokens.PRESS_CHIP : 1, y: this.linkKey === 'forgot' ? MotionTokens.PRESS_CHIP : 1 })
        .animation({ duration: MotionTokens.DURATION_COLOR_BASE, curve: Curve.EaseInOut })
    }
    .width('100%')
    .height(20)
    .justifyContent(FlexAlign.SpaceBetween)
  }

  @Builder
  private buildAuthDivider() {
    Row({ space: 12 }) {
      Divider().layoutWeight(1).color('#14FFFFFF')
      Text('其他登录方式')
        .fontFamily('Noto Sans SC')
        .fontSize(12)
        .fontColor('#66FFFFFF')
      Divider().layoutWeight(1).color('#14FFFFFF')
    }
    .width('100%')
    .height(18)
  }

  @Builder
  private buildSocialButton(label: string, key: string) {
    Text(label)
      .layoutWeight(1)
      .height(50)
      .textAlign(TextAlign.Center)
      .fontFamily('Noto Sans SC')
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor('#F7FBF8')
      .backgroundColor('#08FFFFFF')
      .borderRadius(16)
      .border({ width: 1, color: '#1AFFFFFF' })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.socialKey = key
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.socialKey = ''
        }
      })
      .scale({ x: this.socialKey === key ? MotionTokens.PRESS_SHORTCUT : 1, y: this.socialKey === key ? MotionTokens.PRESS_SHORTCUT : 1 })
      .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 180, colors: [['#0B0F13', 0], ['#0A0D12', 1]] })
      Column() {
        Row() {
          this.buildBrandHeader()
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .margin({ top: 20 })
        Row() {
          this.buildAuthHead()
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .margin({ top: 18 })

        Column({ space: 12 }) {
          this.buildLoginField('手机号 / 邮箱', '请输入手机号或邮箱', 'mail', false)
          this.buildLoginField('密码', '请输入密码', 'lock', true)
          this.buildAuthAux()

          if (this.message.length > 0) {
            Text(this.message)
              .fontFamily('Noto Sans SC')
              .fontSize(13)
              .fontColor(ColorTokens.ERROR)
              .width('100%')
              .textAlign(TextAlign.Center)
          }

          Button(this.loading ? '登录中…' : '登录')
            .width('100%')
            .height(52)
            .padding(0)
            .fontFamily('Noto Sans SC')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#07100B')
            .linearGradient({ angle: 90, colors: [['#47D994', 0], ['#53E7A5', 1]] })
            .borderRadius(18)
            .shadow({ radius: 24, color: '#66000000', offsetX: 0, offsetY: 10 })
            .onClick(() => {
              this.login()
            })
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.ctaPressed = true
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.ctaPressed = false
              }
            })
            .scale({ x: this.ctaPressed ? MotionTokens.PRESS_PRIMARY : 1, y: this.ctaPressed ? MotionTokens.PRESS_PRIMARY : 1 })
            .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })

          this.buildAuthDivider()

          Row({ space: 12 }) {
            this.buildSocialButton('微信', 'wechat')
            this.buildSocialButton('Apple', 'apple')
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .margin({ top: 10, bottom: 10 })

        Row({ space: 6 }) {
          Text('还没有账号？')
            .fontFamily('Noto Sans SC')
            .fontSize(14)
            .fontColor('#99FFFFFF')
          Text('立即注册')
            .fontFamily('Noto Sans SC')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#50ECA7')
            .onClick(() => {
              this.getUIContext().getRouter().pushUrl({ url: AppRoutes.REGISTER })
            })
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.linkKey = 'register'
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.linkKey = ''
              }
            })
            .scale({ x: this.linkKey === 'register' ? MotionTokens.PRESS_CHIP : 1, y: this.linkKey === 'register' ? MotionTokens.PRESS_CHIP : 1 })
            .animation({ duration: MotionTokens.DURATION_COLOR_BASE, curve: Curve.EaseInOut })
        }
        .width('100%')
        .height(24)
        .justifyContent(FlexAlign.Center)
        .margin({ bottom: 16 })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 24, right: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.BG_PRIMARY)
  }
}
