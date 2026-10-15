/** PencilRegisterPage —— 注册页（邮箱 + 验证码 + 密码 + 昵称）。功能 #27 · 云端化改造（Wave 1） */
import { AppRoutes } from '../../../app/AppRoutes'
import { StartupDecision } from '../../../app/AppState'
import AuthService from '../../../common/services/AuthService'
import CloudEnvironment from '../../../common/services/CloudEnvironment'
import GoalRepository from '../../../shared/services/GoalRepository'
import CloudSyncService from '../../../shared/services/CloudSyncService'
import { Context } from '@kit.AbilityKit'
import { MotionTokens } from '../../../common/styles/DesignTokens'
import { currentCanvasScale } from '../../../common/utils/CanvasScale'

const COUNTDOWN_SECONDS: number = 60

/**
 * 字段错误态配色（Pencil 主线集中声明，避免在组件内散落魔法值）。
 *
 * 原型 `fittracker-auth.html` 的错误呈现为「输入框下方独立 `.auth-error` 行 + 描边转 `--warn-border`」；
 * 本实现按需求改为「字段名位置直接显示错误提示 + 输入框描边转红」，故取更高饱和的红色。
 */
const FIELD_ERROR_BORDER: string = '#FFFF5A52'
const FIELD_ERROR_FILL: string = '#14FF5A52'
const FIELD_ERROR_TEXT: string = '#FFFF7A72'

@Entry
@Component
struct PencilRegisterPage {

  @State nickname: string = ''
  @State email: string = ''
  @State code: string = ''
  @State password: string = ''
  @State confirmPassword: string = ''
  @State nicknameError: string = ''
  @State emailError: string = ''
  @State codeError: string = ''
  @State passwordError: string = ''
  @State confirmError: string = ''
  @State message: string = ''
  @State hint: string = ''
  @State loading: boolean = false
  @State sendingCode: boolean = false
  @State countdown: number = 0
  @State agreeChecked: boolean = false
  @State agreePressed: boolean = false
  @State ctaPressed: boolean = false
  @State linkKey: string = ''
  @State eyeKey: string = ''
  @State focusedKey: string = ''
  @State revealPwd: boolean = false
  @State revealConfirm: boolean = false
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
      this.sandboxMode = CloudEnvironment.getModeLabel() === 'sandbox'
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

  private async sendEmailCode(): Promise<void> {
    this.message = ''
    this.hint = ''
    this.emailError = ''
    if (this.email.length === 0) {
      this.emailError = '请输入邮箱'
      return
    }
    const context = this.contextOrNull()
    if (context === null) {
      this.message = '当前页面不可用，请重试'
      return
    }
    this.sendingCode = true
    const result = await AuthService.requestEmailCode(context, this.email)
    this.sendingCode = false
    if (!result.success) {
      this.emailError = result.message
      return
    }
    this.startCountdown()
    if (result.devCodeHint.length > 0) {
      this.hint = '验证码已发送（演示码 ' + result.devCodeHint + '）'
    } else {
      this.hint = '验证码已发送至邮箱'
    }
  }

  private async register(): Promise<void> {
    this.nicknameError = ''
    this.emailError = ''
    this.codeError = ''
    this.passwordError = ''
    this.confirmError = ''
    this.message = ''
    this.hint = ''
    if (this.nickname.length === 0) {
      this.nicknameError = '请输入昵称'
      return
    }
    if (this.email.length === 0) {
      this.emailError = '请输入邮箱'
      return
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(this.email)) {
      this.emailError = '请输入正确的邮箱'
      return
    }
    if (this.code.length === 0) {
      this.codeError = '请输入邮箱验证码'
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
      this.message = '请先阅读并同意用户协议与隐私政策'
      return
    }
    const context = this.contextOrNull()
    if (context === null) {
      this.message = '当前页面不可用，请重试'
      return
    }
    this.loading = true
    const result = await AuthService.registerWithEmail(context, this.email, this.password, this.code, this.nickname)
    this.loading = false
    if (!result.success) {
      this.message = result.message
      return
    }
    await CloudSyncService.onSignIn(context)
    const hasGoal: boolean = await GoalRepository.hasSavedGoal(context)
    this.getUIContext().getRouter().replaceUrl({
      url: StartupDecision.getInitialRoute(true, hasGoal)
    })
  }

  @Builder
  private buildBrandHeader() {
    Column({ space: 13 }) {
      Row() {
        Image($rawfile('fittracker-logo-ring.svg'))
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
  private buildSandboxBanner() {
    if (this.sandboxMode) {
      Text('演示模式：云服务未配置，验证码为 000000')
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

  /**
   * 按字段名取当前错误文案。
   *
   * 为什么用方法而不是参数：ArkUI 的 `@Builder` 按值传参时，状态变量变化不会引起
   * 其内部 UI 刷新（官方语义）。错误文案必须在 `@Builder` 函数体内经 `this` 读取，
   * 才会建立依赖并在 `@State` 变化时重绘——故错误文本走本方法取，不走参数传。
   */
  private fieldError(label: string): string {
    if (label === '昵称') {
      return this.nicknameError
    }
    if (label === '邮箱') {
      return this.emailError
    }
    if (label === '密码') {
      return this.passwordError
    }
    if (label === '确认密码') {
      return this.confirmError
    }
    return ''
  }

  @Builder
  private buildField(label: string, placeholder: string, isPassword: boolean, currentValue: string, onChange: (value: string) => void) {
    Column() {
      Text(this.fieldError(label).length > 0 ? this.fieldError(label) : label)
        .fontFamily('Noto Sans SC')
        .fontSize(13)
        .fontColor(this.fieldError(label).length > 0 ? FIELD_ERROR_TEXT : '#9EFFFFFF')
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
          // TextInput 自身默认带不透明底色，且其 bounds 比外层容器小（内缩），
          // 不透明时会渲染成容器内的一个内缩色块。置透明以消除内层色层。
          .backgroundColor(Color.Transparent)
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
            .fillColor(this.isPasswordVisible(label) ? '#50ECA7' : '#8AFFFFFF')
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
      .backgroundColor(this.fieldError(label).length > 0 ? FIELD_ERROR_FILL : (this.focusedKey === label ? '#0D50ECA7' : '#08FFFFFF'))
      .borderRadius(18)
      .border({ width: 1, color: this.fieldError(label).length > 0 ? FIELD_ERROR_BORDER : (this.focusedKey === label ? '#7350ECA7' : '#14FFFFFF') })
      .alignItems(VerticalAlign.Center)
      .animation({ duration: MotionTokens.DURATION_COLOR_BASE, curve: Curve.EaseInOut })
    }
    .width('100%')
  }

  @Builder
  private buildCodeField() {
    Column() {
      Text(this.codeError.length > 0 ? this.codeError : '邮箱验证码')
        .fontFamily('Noto Sans SC')
        .fontSize(13)
        .fontColor(this.codeError.length > 0 ? FIELD_ERROR_TEXT : '#9EFFFFFF')
        .width('100%')
        .margin({ bottom: 8 })
      Row({ space: 10 }) {
        TextInput({ text: this.code, placeholder: '请输入邮箱验证码' })
          .type(InputType.Number)
          .maxLength(6)
          .showPasswordIcon(false)
          .layoutWeight(1)
          .fontFamily('Noto Sans SC')
          .fontSize(16)
          .fontColor('#F7FBF8')
          .placeholderColor('#66FFFFFF')
          // 同 buildField：TextInput 默认底色会在容器内形成内缩色块，置透明。
          .backgroundColor(Color.Transparent)
          .padding(0)
          .onFocus(() => {
            this.focusedKey = 'code'
          })
          .onBlur(() => {
            this.focusedKey = ''
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
            this.sendEmailCode()
          })
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 10 })
      .backgroundColor(this.codeError.length > 0 ? FIELD_ERROR_FILL : (this.focusedKey === 'code' ? '#0D50ECA7' : '#08FFFFFF'))
      .borderRadius(18)
      .border({ width: 1, color: this.codeError.length > 0 ? FIELD_ERROR_BORDER : (this.focusedKey === 'code' ? '#7350ECA7' : '#14FFFFFF') })
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
        Scroll() {
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
              Text('手机号用户可在登录页用验证码直接登录（自动注册）')
                .fontFamily('Noto Sans SC')
                .fontSize(12)
                .fontColor('#66FFFFFF')
                .margin({ top: 8 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .margin({ bottom: 26 })

            Column({ space: 14 }) {
              this.buildSandboxBanner()
              this.buildField('昵称', '给自己起个名字', false, this.nickname, (value: string) => {
                this.nickname = value
                if (this.nicknameError.length > 0) { this.nicknameError = '' }
              })
              this.buildField('邮箱', '请输入邮箱', false, this.email, (value: string) => {
                this.email = value
                if (this.emailError.length > 0) { this.emailError = '' }
              })
              this.buildCodeField()
              this.buildField('密码', '设置 8 位以上密码', true, this.password, (value: string) => {
                this.password = value
                if (this.passwordError.length > 0) { this.passwordError = '' }
              })
              this.buildField('确认密码', '再次输入密码', true, this.confirmPassword, (value: string) => {
                this.confirmPassword = value
                if (this.confirmError.length > 0) { this.confirmError = '' }
              })

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
                      this.getUIContext().getRouter().pushUrl({
                        url: AppRoutes.LEGAL_DOC,
                        params: { kind: 'agreement' }
                      })
                    })
                  Span('与')
                  Span('《隐私政策》')
                    .fontColor('#50ECA7')
                    .fontWeight(FontWeight.Medium)
                    .onClick(() => {
                      this.getUIContext().getRouter().pushUrl({
                        url: AppRoutes.LEGAL_DOC,
                        params: { kind: 'privacy' }
                      })
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
              .margin({ top: 4 })

              if (this.message.length > 0) {
                Text(this.message)
                  .fontFamily('Noto Sans SC')
                  .fontSize(13)
                  .fontColor('#FFD7C5')
                  .width('100%')
              }
              if (this.hint.length > 0) {
                Text(this.hint)
                  .fontFamily('Noto Sans SC')
                  .fontSize(13)
                  .fontColor('#50ECA7')
                  .width('100%')
                  .textAlign(TextAlign.Center)
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
                .margin({ top: 20 })
            }
            .width('100%')
            .margin({ top: 10, bottom: 10 })

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
          .constraintSize({ minHeight: '100%' })
          .padding({ left: 24, right: 24, top: 76, bottom: 28 })
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
      }
      .width(430)
      .height(900)
      .scale({ x: currentCanvasScale(this.getUIContext()), y: currentCanvasScale(this.getUIContext()), centerX: 0, centerY: 0 })
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .backgroundColor('#10171B')
  }
}
