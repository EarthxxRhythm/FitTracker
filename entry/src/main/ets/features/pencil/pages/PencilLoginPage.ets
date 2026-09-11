/** PencilLoginPage —— FitTracker Login 原型页。功能 #27 */
import { AppRoutes } from '../../../app/AppRoutes'
import AuthService from '../../../common/services/AuthService'
import SessionManager from '../../../common/services/SessionManager'
import { Context } from '@kit.AbilityKit'
import { ColorTokens, MotionTokens } from '../../../common/styles/DesignTokens'

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
  @State revealPassword: boolean = false
  @State focusedField: string = ''
  @State remember: boolean = false

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

  private isFocused(fieldKey: string): boolean {
    return this.focusedField === fieldKey
  }

  @Builder
  private buildLoginField(label: string, placeholder: string, fieldKey: string, isPassword: boolean) {
    Column({ space: 8 }) {
      Text(label)
        .fontFamily('Noto Sans SC')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#9EFFFFFF')
        .width('100%')
      Row({ space: 12 }) {
        TextInput({ text: isPassword ? this.password : this.account, placeholder: placeholder })
          .type(isPassword && !this.revealPassword ? InputType.Password : InputType.Normal)
          .showPasswordIcon(false)
          .layoutWeight(1)
          .fontFamily('Noto Sans SC')
          .fontSize(16)
          .fontColor('#F7FBF8')
          .placeholderColor('#66FFFFFF')
          .backgroundColor(Color.Transparent)
          .padding(0)
          .onFocus(() => {
            this.focusedField = fieldKey
          })
          .onBlur(() => {
            this.focusedField = ''
          })
          .onChange((value: string) => {
            if (isPassword) {
              this.password = value
            } else {
              this.account = value
            }
          })
        if (isPassword) {
          Stack() {
            Image($rawfile('pencil-lucide-eye.svg'))
              .width(20)
              .height(20)
              .fillColor(this.revealPassword ? ColorTokens.ACCENT_PRIMARY : '#8AFFFFFF')
              .onTouch((event: TouchEvent) => {
                if (event.type === TouchType.Down) {
                  this.eyePressed = true
                } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                  this.eyePressed = false
                }
              })
              .scale({ x: this.eyePressed ? MotionTokens.PRESS_ICON : 1, y: this.eyePressed ? MotionTokens.PRESS_ICON : 1 })
              .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
              .onClick(() => {
                this.revealPassword = !this.revealPassword
              })
          }
          .width(44)
          .height(44)
          .borderRadius(10)
          .margin({ right: -10 })
        }
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 16 })
      .backgroundColor(this.isFocused(fieldKey) ? '#0D50ECA7' : '#08FFFFFF')
      .borderRadius(18)
      .border({ width: 1, color: this.isFocused(fieldKey) ? '#7350ECA7' : '#14FFFFFF' })
      .alignItems(VerticalAlign.Center)
      .animation({ duration: MotionTokens.DURATION_COLOR_BASE, curve: Curve.EaseInOut })
    }
    .width('100%')
  }

  @Builder
  private buildAuthAux() {
    Row() {
      Row({ space: 8 }) {
        Stack({ alignContent: Alignment.Center }) {
          if (this.remember) {
            Path()
              .width(9)
              .height(5)
              .commands('M0 2 L3 5 L9 0')
              .fillOpacity(0)
              .stroke('#07100B')
              .strokeWidth(2)
          }
        }
        .width(18)
        .height(18)
        .borderRadius(6)
        .backgroundColor(this.remember ? ColorTokens.ACCENT_PRIMARY : '#0AFFFFFF')
        .border({ width: 1, color: this.remember ? ColorTokens.ACCENT_PRIMARY : '#2EFFFFFF' })
        .onClick(() => {
          this.remember = !this.remember
        })
        .animation({ duration: MotionTokens.DURATION_COLOR_FAST, curve: Curve.EaseInOut })
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
    .margin({ top: 24, bottom: 16 })
  }

  @Builder
  private buildSocialIcon(key: string) {
    if (key === 'wechat') {
      Stack() {
        Path()
          .commands('M12 3.5c-4.7 0-8.5 3.2-8.5 7.1 0 2.2 1.2 4.1 3.1 5.4l-.9 3.3 3.5-1.9c.9.2 1.8.3 2.8.3 4.7 0 8.5-3.2 8.5-7.1S16.7 3.5 12 3.5Z')
          .width(20)
          .height(20)
          .fillOpacity(0)
          .stroke('#B3FFFFFF')
          .strokeWidth(1.6)
        Path()
          .commands('M7.6 10.6a1 1 0 1 0 2 0a1 1 0 1 0 -2 0 M11 10.6a1 1 0 1 0 2 0a1 1 0 1 0 -2 0 M14.4 10.6a1 1 0 1 0 2 0a1 1 0 1 0 -2 0')
          .width(20)
          .height(20)
          .fill('#B3FFFFFF')
      }
    } else {
      Path()
        .commands('M16.7 12.9c0-2.1 1.7-3.1 1.8-3.2-1-1.4-2.5-1.6-3-1.7-1.3-.1-2.5.8-3.1.8-.6 0-1.6-.8-2.6-.7-1.4 0-2.6.8-3.3 2-1.4 2.4-.4 6 1 8 .7 1 1.5 2.1 2.5 2 1 0 1.4-.6 2.6-.6s1.5.6 2.6.6c1.1 0 1.7-1 2.4-2 .7-1.1 1-2.2 1.1-2.2-.1 0-2.1-.8-2.1-3.2zM14.2 6.1c.6-.7 1-1.6.9-2.6-.9 0-1.9.6-2.5 1.3-.5.6-1 1.6-.9 2.6 1 .1 1.9-.5 2.5-1.3z')
          .width(20)
          .height(20)
          .fill('#B3FFFFFF')
    }
  }

  @Builder
  private buildSocialButton(label: string, key: string) {
    Row({ space: 9 }) {
      this.buildSocialIcon(key)
      Text(label)
        .fontFamily('Noto Sans SC')
        .fontSize(14)
        .fontWeight(600)
        .fontColor('#F7FBF8')
    }
    .layoutWeight(1)
    .height(50)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
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
        .backgroundColor('#10171B')
      Column() {
        Row() {
          this.buildBrandHeader()
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .margin({ top: 8, bottom: 22 })
        Row() {
          this.buildAuthHead()
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .margin({ bottom: 26 })

        Scroll() {
        Column({ space: 14 }) {
          this.buildLoginField('手机号 / 邮箱', '请输入手机号或邮箱', 'account', false)
          this.buildLoginField('密码', '请输入密码', 'password', true)
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
            .backgroundColor(ColorTokens.ACCENT_PRIMARY)
            .borderRadius(18)
            .shadow({ radius: 26, color: 'rgba(0,0,0,0.38)', offsetX: 0, offsetY: 12 })
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
        .constraintSize({ minHeight: '100%' })
        .justifyContent(FlexAlign.Center)
        .margin({ top: 10, bottom: 10 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)

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
