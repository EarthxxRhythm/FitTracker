/** PencilLoginPage —— 登录页（手机验证码 / 邮箱密码 / 第三方登录）。功能 #27 · 云端化改造（Wave 1） */
import { AppRoutes } from '../../../app/AppRoutes'
import { StartupDecision } from '../../../app/AppState'
import AuthService from '../../../common/services/AuthService'
import CloudEnvironment from '../../../common/services/CloudEnvironment'
import GoalRepository from '../../../shared/services/GoalRepository'
import { Context } from '@kit.AbilityKit'
import { ColorTokens, MotionTokens } from '../../../common/styles/DesignTokens'

const COUNTDOWN_SECONDS: number = 60

@Entry
@Component
struct PencilLoginPage {

  @State loginMode: string = 'phone'
  @State phone: string = ''
  @State code: string = ''
  @State email: string = ''
  @State password: string = ''
  @State message: string = ''
  @State hint: string = ''
  @State loading: boolean = false
  @State sendingCode: boolean = false
  @State countdown: number = 0
  @State agreeChecked: boolean = false
  @State ctaPressed: boolean = false
  @State socialKey: string = ''
  @State linkKey: string = ''
  @State eyePressed: boolean = false
  @State revealPassword: boolean = false
  @State focusedField: string = ''
  @State sandboxMode: boolean = false
  private codeTimer: number = -1

  private contextOrNull(): Context | null {
    const host = this.getUIContext().getHostContext()
    return host === undefined || host === null ? null : host as Context
  }

  async aboutToAppear(): Promise<void> {
    const context = this.contextOrNull()
    if (context !== null) {
      await CloudEnvironment.initialize(context)
      this.sandboxMode = !CloudEnvironment.isAgcConfigured()
    }
  }

  aboutToDisappear(): void {
    if (this.codeTimer >= 0) {
      clearInterval(this.codeTimer)
      this.codeTimer = -1
    }
  }

  private startCountdown(): void {
    this.countdown = COUNTDOWN_SECONDS
    if (this.codeTimer >= 0) {
      clearInterval(this.codeTimer)
    }
    this.codeTimer = setInterval(() => {
      if (this.countdown > 0) {
        this.countdown = this.countdown - 1
      }
      if (this.countdown <= 0 && this.codeTimer >= 0) {
        clearInterval(this.codeTimer)
        this.codeTimer = -1
      }
    }, 1000)
  }

  private async sendPhoneCode(): Promise<void> {
    this.message = ''
    this.hint = ''
    if (this.phone.length === 0) {
      this.message = '请输入手机号'
      return
    }
    const context = this.contextOrNull()
    if (context === null) {
      this.message = '当前页面不可用，请重试'
      return
    }
    this.sendingCode = true
    const result = await AuthService.requestPhoneCode(context, this.phone)
    this.sendingCode = false
    if (!result.success) {
      this.message = result.message
      return
    }
    this.startCountdown()
    if (result.devCodeHint.length > 0) {
      this.hint = '验证码已发送（演示码 ' + result.devCodeHint + '）'
    } else {
      this.hint = '验证码已发送'
    }
  }

  private async login(): Promise<void> {
    this.message = ''
    this.hint = ''
    if (!this.agreeChecked) {
      this.message = '请先阅读并同意用户协议与隐私政策'
      return
    }
    const context = this.contextOrNull()
    if (context === null) {
      this.message = '当前页面不可用，请重试'
      return
    }
    if (this.loginMode === 'phone') {
      if (this.phone.length === 0) {
        this.message = '请输入手机号'
        return
      }
      if (this.code.length === 0) {
        this.message = '请输入验证码'
        return
      }
      this.loading = true
      const result = await AuthService.loginWithPhoneCode(context, this.phone, this.code)
      this.loading = false
      if (!result.success) {
        this.message = result.message
        return
      }
    } else {
      if (this.email.length === 0) {
        this.message = '请输入邮箱'
        return
      }
      if (this.password.length === 0) {
        this.message = '请输入密码'
        return
      }
      this.loading = true
      const result = await AuthService.loginWithEmailPassword(context, this.email, this.password)
      this.loading = false
      if (!result.success) {
        this.message = result.message
        return
      }
    }
    await this.routeAfterLogin(context)
  }

  private async loginWithThirdParty(thirdPartyId: string): Promise<void> {
    this.message = ''
    this.hint = ''
    if (!this.agreeChecked) {
      this.message = '请先阅读并同意用户协议与隐私政策'
      return
    }
    const context = this.contextOrNull()
    if (context === null) {
      this.message = '当前页面不可用，请重试'
      return
    }
    this.loading = true
    const result = await AuthService.loginWithThirdParty(context, thirdPartyId)
    this.loading = false
    if (!result.success) {
      this.message = result.message
      return
    }
    await this.routeAfterLogin(context)
  }

  private async routeAfterLogin(context: Context): Promise<void> {
    const hasGoal: boolean = await GoalRepository.hasSavedGoal(context)
    this.getUIContext().getRouter().replaceUrl({
      url: StartupDecision.getInitialRoute(true, hasGoal)
    })
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
  private buildSandboxBanner() {
    if (this.sandboxMode) {
      Text('演示模式：云服务未配置，手机验证码为 000000')
        .fontFamily('Noto Sans SC')
        .fontSize(12)
        .fontColor('#D3B487')
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 9, bottom: 9 })
        .backgroundColor('#14D3B487')
        .borderRadius(12)
        .border({ width: 1, color: '#26D3B487' })
    }
  }

  @Builder
  private buildModeSwitch() {
    Row({ space: 2 }) {
      this.buildModeButton('手机验证码', 'phone')
      this.buildModeButton('邮箱密码', 'email')
    }
    .width('100%')
    .height(44)
    .padding(3)
    .backgroundColor('#0FFFFFFF')
    .border({ width: 1, color: '#1AFFFFFF' })
    .borderRadius(14)
  }

  @Builder
  private buildModeButton(label: string, modeKey: string) {
    Text(label)
      .layoutWeight(1)
      .height('100%')
      .textAlign(TextAlign.Center)
      .fontFamily('Noto Sans SC')
      .fontSize(13.5)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.loginMode === modeKey ? '#07100B' : '#9EFFFFFF')
      .backgroundColor(this.loginMode === modeKey ? '#50ECA7' : Color.Transparent)
      .borderRadius(11)
      .animation({ duration: MotionTokens.DURATION_COLOR_FAST, curve: MotionTokens.EASE_MOTION })
      .onClick(() => {
        if (this.loginMode !== modeKey) {
          this.loginMode = modeKey
          this.message = ''
          this.hint = ''
        }
      })
  }

  @Builder
  private buildField(label: string, placeholder: string, isPassword: boolean, currentValue: string, fieldKey: string, onChange: (value: string) => void) {
    Column({ space: 8 }) {
      Text(label)
        .fontFamily('Noto Sans SC')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#9EFFFFFF')
        .width('100%')
      Row({ space: 12 }) {
        TextInput({ text: currentValue, placeholder: placeholder })
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
            onChange(value)
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
      .backgroundColor(this.focusedField === fieldKey ? '#0D50ECA7' : '#08FFFFFF')
      .borderRadius(18)
      .border({ width: 1, color: this.focusedField === fieldKey ? '#7350ECA7' : '#14FFFFFF' })
      .alignItems(VerticalAlign.Center)
      .animation({ duration: MotionTokens.DURATION_COLOR_BASE, curve: Curve.EaseInOut })
    }
    .width('100%')
  }

  @Builder
  private buildCodeField() {
    Column({ space: 8 }) {
      Text('验证码')
        .fontFamily('Noto Sans SC')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#9EFFFFFF')
        .width('100%')
      Row({ space: 10 }) {
        TextInput({ text: this.code, placeholder: '请输入验证码' })
          .type(InputType.Number)
          .maxLength(6)
          .showPasswordIcon(false)
          .layoutWeight(1)
          .fontFamily('Noto Sans SC')
          .fontSize(16)
          .fontColor('#F7FBF8')
          .placeholderColor('#66FFFFFF')
          .backgroundColor(Color.Transparent)
          .padding(0)
          .onFocus(() => {
            this.focusedField = 'code'
          })
          .onBlur(() => {
            this.focusedField = ''
          })
          .onChange((value: string) => {
            this.code = value
          })
        Button(this.countdown > 0 ? this.countdown.toString() + 's' : '获取验证码')
          .height(36)
          .padding({ left: 14, right: 14 })
          .fontFamily('Noto Sans SC')
          .fontSize(12.5)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.countdown > 0 ? '#66FFFFFF' : '#07100B')
          .backgroundColor(this.countdown > 0 ? '#0FFFFFFF' : '#50ECA7')
          .borderRadius(12)
          .enabled(this.countdown === 0 && !this.sendingCode)
          .onClick(() => {
            this.sendPhoneCode()
          })
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 10 })
      .backgroundColor(this.focusedField === 'code' ? '#0D50ECA7' : '#08FFFFFF')
      .borderRadius(18)
      .border({ width: 1, color: this.focusedField === 'code' ? '#7350ECA7' : '#14FFFFFF' })
      .alignItems(VerticalAlign.Center)
      .animation({ duration: MotionTokens.DURATION_COLOR_BASE, curve: Curve.EaseInOut })
    }
    .width('100%')
  }

  @Builder
  private buildAgreementRow() {
    Row({ space: 10 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.agreeChecked) {
          Image($rawfile('pencil-auth-check-agree.svg'))
            .width(13)
            .height(8)
        }
      }
      .width(18)
      .height(18)
      .borderRadius(6)
      .backgroundColor(this.agreeChecked ? '#50ECA7' : '#0AFFFFFF')
      .border({ width: 1, color: this.agreeChecked ? '#50ECA7' : '#2EFFFFFF' })
      .margin({ top: 1 })
      .animation({ duration: MotionTokens.DURATION_COLOR_FAST, curve: Curve.EaseInOut })
      .onClick(() => {
        this.agreeChecked = !this.agreeChecked
      })
      Text() {
        Span('我已阅读并同意')
        Span('《用户协议》')
          .fontColor('#50ECA7')
          .fontWeight(FontWeight.Medium)
          .onClick(() => {
            this.hint = '查看协议（原型）'
          })
        Span('与')
        Span('《隐私政策》')
          .fontColor('#50ECA7')
          .fontWeight(FontWeight.Medium)
          .onClick(() => {
            this.hint = '查看协议（原型）'
          })
      }
      .fontFamily('Noto Sans SC')
      .fontSize(12.5)
      .fontColor('#8AFFFFFF')
      .lineHeight(19)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .margin({ top: 4 })
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
    .margin({ top: 20, bottom: 14 })
  }

  @Builder
  private buildSocialIcon(key: string) {
    if (key === 'huawei') {
      Image($rawfile('pencil-social-huawei.svg'))
        .width(20)
        .height(20)
        .opacity(0.7)
    } else if (key === 'wechat') {
      Image($rawfile('pencil-social-wechat.svg'))
        .width(20)
        .height(20)
        .opacity(0.7)
    } else {
      Image($rawfile('pencil-social-qq.svg'))
        .width(20)
        .height(20)
        .opacity(0.7)
    }
  }

  @Builder
  private buildSocialButton(label: string, key: string) {
    Row({ space: 7 }) {
      this.buildSocialIcon(key)
      Text(label)
        .fontFamily('Noto Sans SC')
        .fontSize(13.5)
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
    .onClick(() => {
      this.loginWithThirdParty(key)
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#10171B')
      Column() {
        Scroll() {
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
            .margin({ bottom: 24 })

            Column({ space: 14 }) {
              this.buildSandboxBanner()
              this.buildModeSwitch()

              if (this.loginMode === 'phone') {
                this.buildField('手机号', '请输入手机号', false, this.phone, 'phone', (value: string) => {
                  this.phone = value
                })
                this.buildCodeField()
              } else {
                this.buildField('邮箱', '请输入邮箱', false, this.email, 'email', (value: string) => {
                  this.email = value
                })
                this.buildField('密码', '请输入密码', true, this.password, 'password', (value: string) => {
                  this.password = value
                })
              }

              this.buildAgreementRow()

              if (this.message.length > 0) {
                Text(this.message)
                  .fontFamily('Noto Sans SC')
                  .fontSize(13)
                  .fontColor(ColorTokens.ERROR)
                  .width('100%')
                  .textAlign(TextAlign.Center)
              }
              if (this.hint.length > 0) {
                Text(this.hint)
                  .fontFamily('Noto Sans SC')
                  .fontSize(13)
                  .fontColor('#50ECA7')
                  .width('100%')
                  .textAlign(TextAlign.Center)
              }

              Button(this.loading ? '登录中…' : '登录')
                .width('100%')
                .height(52)
                .padding(0)
                .margin({ top: 14 })
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

              Row({ space: 10 }) {
                this.buildSocialButton('华为', 'huawei')
                this.buildSocialButton('微信', 'wechat')
                this.buildSocialButton('QQ', 'qq')
              }
              .width('100%')
            }
            .width('100%')
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
          .constraintSize({ minHeight: '100%' })
          .padding({ left: 24, right: 24, top: 76, bottom: 28 })
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
      }
      .width(430)
      .height(900)
      .scale({ x: 0.90698, y: 0.90698, centerX: 0, centerY: 0 })
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .backgroundColor(ColorTokens.BG_PRIMARY)
  }
}
