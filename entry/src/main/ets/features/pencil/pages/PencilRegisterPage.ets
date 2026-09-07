/** PencilRegisterPage - FitTracker Register prototype page. */
import { AppRoutes } from '../../../app/AppRoutes'
import AuthService from '../../../common/services/AuthService'
import { Context } from '@kit.AbilityKit'
import { ColorTokens, MotionTokens } from '../../../common/styles/DesignTokens'

@Entry
@Component
struct PencilRegisterPage {

  @State nickname: string = ''
  @State phone: string = ''
  @State password: string = ''
  @State confirmPassword: string = ''
  @State nicknameError: string = ''
  @State phoneError: string = ''
  @State passwordError: string = ''
  @State confirmError: string = ''
  @State message: string = ''
  @State loading: boolean = false
  @State ctaPressed: boolean = false
  @State linkKey: string = ''
  @State eyeKey: string = ''
  @State agreePressed: boolean = false
  @State agreeChecked: boolean = false
  @State focusedKey: string = ''
  @State revealPwd: boolean = false
  @State revealConfirm: boolean = false

  private contextOrNull(): Context | null {
    const host = this.getUIContext().getHostContext()
    return host === undefined || host === null ? null : host as Context
  }

  private async register(): Promise<void> {
    this.nicknameError = ''
    this.phoneError = ''
    this.passwordError = ''
    this.confirmError = ''
    this.message = ''
    if (this.nickname.length === 0) {
      this.nicknameError = '请输入昵称'
      return
    }
    if (this.phone.length === 0) {
      this.phoneError = '请输入手机号'
      return
    }
    if (!/^1[3-9]\d{9}$/.test(this.phone)) {
      this.phoneError = '请输入正确的手机号'
      return
    }
    if (this.password.length === 0) {
      this.passwordError = '请输入密码'
      return
    }
    if (this.password.length < 8) {
      this.passwordError = '密码至少 8 位'
      return
    }
    if (this.confirmPassword.length === 0) {
      this.confirmError = '请再次输入密码'
      return
    }
    if (this.password !== this.confirmPassword) {
      this.confirmError = '两次输入的密码不一致'
      return
    }
    if (!this.agreeChecked) {
      this.message = '请先阅读并同意用户协议'
      return
    }
    const context = this.contextOrNull()
    if (context === null) {
      this.message = '当前页面不可用，请重试'
      return
    }
    this.loading = true
    const result = await AuthService.registerLocal(context, this.phone, this.password)
    this.loading = false
    if (!result.success) {
      this.message = result.message
      return
    }
    this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.LOGIN })
  }

  @Builder
  private buildBrandHeader() {
    Column({ space: 13 }) {
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

  private isFieldFocused(label: string): boolean {
    return this.focusedKey === label
  }

  private isPasswordVisible(label: string): boolean {
    if (label === '密码') {
      return this.revealPwd
    }
    if (label === '确认密码') {
      return this.revealConfirm
    }
    return false
  }

  private togglePasswordVisible(label: string): void {
    if (label === '密码') {
      this.revealPwd = !this.revealPwd
    } else if (label === '确认密码') {
      this.revealConfirm = !this.revealConfirm
    }
  }

  @Builder
  private buildField(label: string, placeholder: string, isPassword: boolean, currentValue: string, errorMessage: string, onChange: (value: string) => void) {
    Column() {
      Text(label)
        .fontFamily('Noto Sans SC')
        .fontSize(13)
        .fontColor('#9EFFFFFF')
        .width('100%')
        .margin({ bottom: 8 })
      Row({ space: 12 }) {
        TextInput({ text: currentValue, placeholder: placeholder })
          .type(isPassword && !this.isPasswordVisible(label) ? InputType.Password : InputType.Normal)
          .showPasswordIcon(false)
          .layoutWeight(1)
          .fontFamily('Noto Sans SC')
          .fontSize(16)
          .fontColor('#F7FBF8')
          .placeholderColor('#66FFFFFF')
          .padding(0)
          .onFocus(() => {
            this.focusedKey = label
          })
          .onBlur(() => {
            this.focusedKey = ''
          })
          .onChange((value: string) => {
            onChange(value)
          })
        if (isPassword) {
          Image($rawfile('pencil-lucide-eye.svg'))
            .width(20)
            .height(20)
            .fillColor(this.isPasswordVisible(label) ? ColorTokens.ACCENT_PRIMARY : '#8AFFFFFF')
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.eyeKey = label
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.eyeKey = ''
              }
            })
            .scale({ x: this.eyeKey === label ? MotionTokens.PRESS_ICON : 1, y: this.eyeKey === label ? MotionTokens.PRESS_ICON : 1 })
            .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
            .onClick(() => {
              this.togglePasswordVisible(label)
            })
        }
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 16 })
      .backgroundColor(errorMessage.length > 0 ? '#0AFFB096' : (this.isFieldFocused(label) ? '#0D50ECA7' : '#08FFFFFF'))
      .borderRadius(18)
      .border({ width: 1, color: errorMessage.length > 0 ? '#8CFFB096' : (this.isFieldFocused(label) ? '#7350ECA7' : '#14FFFFFF') })
      .alignItems(VerticalAlign.Center)
      .animation({ duration: MotionTokens.DURATION_COLOR_BASE, curve: Curve.EaseInOut })
      if (errorMessage.length > 0) {
        Text(errorMessage)
          .fontFamily('Noto Sans SC')
          .fontSize(12)
          .fontColor('#FFD7C5')
          .width('100%')
          .margin({ top: 7 })
      }
    }
    .width('100%')
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
        .margin({ top: 8, bottom: 22 })
        Column({ space: 0 }) {
          Text('CREATE ACCOUNT')
            .fontFamily('Geist Mono')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1.5)
            .fontColor('#50ECA7')
            .margin({ bottom: 11 })
          Text('创建账号')
            .fontFamily('Noto Sans SC')
            .fontSize(35)
            .fontWeight(FontWeight.Bold)
            .lineHeight(41.3)
            .letterSpacing(-0.35)
            .fontColor('#F7FBF8')
          Text('开始记录每一次训练，见证看得见的进步')
            .fontFamily('Noto Sans SC')
            .fontSize(15)
            .fontColor('#A6FFFFFF')
            .margin({ top: 11 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)

        Scroll() {
        Column({ space: 14 }) {
          this.buildField('昵称', '给自己起个名字', false, this.nickname, this.nicknameError, (value: string) => {
            this.nickname = value
            if (this.nicknameError.length > 0) { this.nicknameError = '' }
          })
          this.buildField('手机号', '请输入手机号', false, this.phone, this.phoneError, (value: string) => {
            this.phone = value
            if (this.phoneError.length > 0) { this.phoneError = '' }
          })
          this.buildField('密码', '设置 8 位以上密码', true, this.password, this.passwordError, (value: string) => {
            this.password = value
            if (this.passwordError.length > 0) { this.passwordError = '' }
          })
          this.buildField('确认密码', '再次输入密码', true, this.confirmPassword, this.confirmError, (value: string) => {
            this.confirmPassword = value
            if (this.confirmError.length > 0) { this.confirmError = '' }
          })
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .justifyContent(FlexAlign.Center)
        .margin({ top: 8, bottom: 8 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)

        Row({ space: 10 }) {
          Stack({ alignContent: Alignment.Center }) {
            if (this.agreeChecked) {
              Path()
                .width(11)
                .height(6)
                .commands('M0 3 L4 6 L11 0')
                .fillOpacity(0)
                .stroke('#07100B')
                .strokeWidth(2)
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
                this.message = '查看协议（原型）'
              })
            Span('与')
            Span('《隐私政策》')
              .fontColor('#50ECA7')
              .fontWeight(FontWeight.Medium)
              .onClick(() => {
                this.message = '查看协议（原型）'
              })
          }
          .fontFamily('Noto Sans SC')
          .fontSize(12.5)
          .fontColor('#8AFFFFFF')
          .lineHeight(19)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.agreePressed = true
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.agreePressed = false
          }
        })
        .scale({ x: this.agreePressed ? MotionTokens.PRESS_CHIP : 1, y: this.agreePressed ? MotionTokens.PRESS_CHIP : 1 })
        .animation({ duration: MotionTokens.DURATION_COLOR_FAST, curve: Curve.EaseInOut })
        .margin({ top: 4, bottom: 10 })

        if (this.message.length > 0) {
          Text(this.message)
            .fontFamily('Noto Sans SC')
            .fontSize(13)
            .fontColor('#FFD7C5')
            .width('100%')
            .margin({ bottom: 10 })
        }

        Button(this.loading ? '注册中…' : '注册')
          .width('100%')
          .height(52)
          .padding(0)
          .fontFamily('Noto Sans SC')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#07100B')
          .backgroundColor('#50ECA7')
          .borderRadius(18)
          .shadow({ radius: 26, color: '#61000000', offsetX: 0, offsetY: 12 })
          .onClick(() => {
            this.register()
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
          .margin({ bottom: 10 })

        Row({ space: 6 }) {
          Text('已有账号？')
            .fontFamily('Noto Sans SC')
            .fontSize(14)
            .fontColor('#99FFFFFF')
          Text('直接登录')
            .fontFamily('Noto Sans SC')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#50ECA7')
            .onClick(() => {
              this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.LOGIN })
            })
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.linkKey = 'login'
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.linkKey = ''
              }
            })
            .scale({ x: this.linkKey === 'login' ? MotionTokens.PRESS_CHIP : 1, y: this.linkKey === 'login' ? MotionTokens.PRESS_CHIP : 1 })
            .animation({ duration: MotionTokens.DURATION_COLOR_BASE, curve: Curve.EaseInOut })
        }
        .width('100%')
        .height(24)
        .justifyContent(FlexAlign.Center)
        .margin({ bottom: 12 })
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
