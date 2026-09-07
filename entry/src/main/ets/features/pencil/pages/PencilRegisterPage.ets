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
  @State message: string = ''
  @State loading: boolean = false
  @State ctaPressed: boolean = false
  @State linkKey: string = ''
  @State eyeKey: string = ''
  @State agreePressed: boolean = false
  @State focusedKey: string = ''
  @State revealPwd: boolean = false
  @State revealConfirm: boolean = false

  private contextOrNull(): Context | null {
    const host = this.getUIContext().getHostContext()
    return host === undefined || host === null ? null : host as Context
  }

  private async register(): Promise<void> {
    if (this.nickname.length === 0) {
      this.message = '请输入昵称'
      return
    }
    if (this.phone.length === 0) {
      this.message = '请输入手机号'
      return
    }
    if (this.password.length < 8) {
      this.message = '密码至少 8 位'
      return
    }
    if (this.password !== this.confirmPassword) {
      this.message = '两次输入的密码不一致'
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
  private buildField(label: string, placeholder: string, isPassword: boolean, currentValue: string, onChange: (value: string) => void) {
    Column({ space: 8 }) {
      Text(label)
        .fontFamily('Noto Sans SC')
        .fontSize(13)
        .fontColor('#9EFFFFFF')
        .width('100%')
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
      .backgroundColor(this.isFieldFocused(label) ? '#0D50ECA7' : '#05FFFFFF')
      .borderRadius(18)
      .border({ width: 1, color: this.isFieldFocused(label) ? '#7350ECA7' : '#14FFFFFF' })
      .alignItems(VerticalAlign.Center)
      .animation({ duration: MotionTokens.DURATION_COLOR_BASE, curve: Curve.EaseInOut })
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
        .margin({ top: 20 })
        Column({ space: 8 }) {
          Text('CREATE ACCOUNT')
            .fontFamily('Geist Mono')
            .fontSize(11)
            .fontColor('#50ECA7')
          Text('创建账号')
            .fontFamily('Noto Sans SC')
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F7FBF8')
          Text('开始记录每一次训练，见证看得见的进步')
            .fontFamily('Noto Sans SC')
            .fontSize(15)
            .fontColor('#A6FFFFFF')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .margin({ top: 14 })

        Scroll() {
        Column({ space: 12 }) {
          this.buildField('昵称', '给自己起个名字', false, this.nickname, (value: string) => {
            this.nickname = value
          })
          this.buildField('手机号', '请输入手机号', false, this.phone, (value: string) => {
            this.phone = value
          })
          this.buildField('密码', '设置 8 位以上密码', true, this.password, (value: string) => {
            this.password = value
          })
          this.buildField('确认密码', '再次输入密码', true, this.confirmPassword, (value: string) => {
            this.confirmPassword = value
          })
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .justifyContent(FlexAlign.Center)
        .margin({ top: 8, bottom: 8 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)

        Row({ space: 8 }) {
          Text('□')
            .fontFamily('HarmonyOS Sans')
            .fontSize(18)
            .fontColor('#8FFFFFFF')
          Text('我已阅读并同意《用户协议》与《隐私政策》')
            .fontFamily('Noto Sans SC')
            .fontSize(12)
            .fontColor('#8FFFFFFF')
        }
        .width('100%')
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.agreePressed = true
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.agreePressed = false
          }
        })
        .scale({ x: this.agreePressed ? MotionTokens.PRESS_CHIP : 1, y: this.agreePressed ? MotionTokens.PRESS_CHIP : 1 })
        .animation({ duration: MotionTokens.DURATION_COLOR_FAST, curve: Curve.EaseInOut })
        .margin({ bottom: 10 })

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
          .linearGradient({ angle: 90, colors: [['#47D994', 0], ['#53E7A5', 1]] })
          .borderRadius(18)
          .shadow({ radius: 24, color: '#66000000', offsetX: 0, offsetY: 10 })
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
