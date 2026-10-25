/** PencilLoginPage —— 登录页（手机验证码 / 邮箱密码 / 第三方登录）。功能 #27 · 云端化改造（Wave 1） */
import { AppRoutes } from '../../../app/AppRoutes'
import { StartupDecision } from '../../../app/AppState'
import AuthService from '../../../common/services/AuthService'
import CloudEnvironment from '../../../common/services/CloudEnvironment'
import ThirdPartyBridgeBootstrap from '../../../common/services/auth/ThirdPartyBridgeBootstrap'
import ThirdPartyBridgeRegistry from '../../../common/services/auth/ThirdPartyBridgeRegistry'
import PendingAuthStore, { PendingAuthRecord } from '../../../common/services/auth/PendingAuthStore'
import GoalRepository from '../../../shared/services/GoalRepository'
import CloudSyncService from '../../../shared/services/CloudSyncService'
import { Context, common } from '@kit.AbilityKit'
import { ColorTokens, MotionTokens } from '../../../common/styles/DesignTokens'
import { currentCanvasScale } from '../../../common/utils/CanvasScale'
import { shakeField } from '../../../common/utils/FieldShake'
import { PrototypeTokens } from '../../../common/styles/PrototypeTokens'

const COUNTDOWN_SECONDS: number = 60

/** 字段错误态配色——统一取自 DesignTokens，与注册/体重/目标输入共用同一套。 */
const FIELD_ERROR_BORDER: string = ColorTokens.FIELD_ERROR_BORDER
const FIELD_ERROR_FILL: string = ColorTokens.FIELD_ERROR_FILL
const FIELD_ERROR_TEXT: string = ColorTokens.FIELD_ERROR_TEXT

@Entry
@Component
struct PencilLoginPage {

  @State loginMode: string = 'phone'
  @State phone: string = ''
  @State code: string = ''
  @State email: string = ''
  @State password: string = ''
  @State phoneError: string = ''
  @State codeError: string = ''
  @State emailError: string = ''
  @State passwordError: string = ''
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
  /** 正在抖动的字段键 + 该字段的横向偏移——只有出错字段会动。 */
  @State shakeFieldKey: string = ''
  @State shakeOffset: number = 0
  private codeTimer: number = -1

  private contextOrNull(): Context | null {
    const host = this.getUIContext().getHostContext()
    return host === undefined || host === null ? null : host as Context
  }

  /**
   * 取 UIAbilityContext（第三方 SDK 拉起外部 App 必需）。
   * 登录页宿主即 EntryAbility，其 hostContext 运行时就是 UIAbilityContext；
   * 此处做一次显式收窄以满足接口签名（ArkTS 静态检查不接受基类传入）。
   */
  private uiAbilityContextOrNull(): common.UIAbilityContext | null {
    const host = this.getUIContext().getHostContext()
    if (host === undefined || host === null) {
      return null
    }
    return host as common.UIAbilityContext
  }

  async aboutToAppear(): Promise<void> {
    const context = this.contextOrNull()
    if (context !== null) {
      await CloudEnvironment.initialize(context)
      this.sandboxMode = CloudEnvironment.getModeLabel() === 'sandbox'
      // 注册第三方桥（幂等）：登录页是第三方登录的唯一入口
      ThirdPartyBridgeBootstrap.initialize(context)
      // 续跑：微信/QQ 授权后返回本应用，页面重建但上一轮的 await 已随旧页面销毁而中断。
      // 此处消费遗留的授权结果，把第二段（换票）接上，避免「授权成功却不登录」。
      await this.resumeThirdPartyIfPending(context)
    }
  }

  /**
   * 消费遗留的第三方授权结果并完成换票（页面重建后续跑第二段）。
   *
   * 仅在该结果由本页发起（协议已勾选）时续跑；用户主动取消或已过期（consume 返回 null）
   * 时静默返回，不打扰用户。
   */
  private async resumeThirdPartyIfPending(context: Context): Promise<void> {
    if (!this.agreeChecked) {
      return
    }
    const pending: PendingAuthRecord | null = await PendingAuthStore.consume(context)
    if (pending === null) {
      return
    }
    if (pending.kind === 'failure') {
      if (pending.message.length > 0) {
        this.message = pending.message
      }
      return
    }
    this.loading = true
    try {
      const result = await AuthService.loginWithThirdParty(context, pending.providerId, pending.authCode)
      if (!result.success) {
        this.message = result.message
        return
      }
    } finally {
      this.loading = false
    }
    await this.routeAfterLogin(context)
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
    this.phoneError = ''
    if (this.phone.length === 0) {
      this.phoneError = '请输入手机号'
      this.shake('phone')
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
    this.phoneError = ''
    this.codeError = ''
    this.emailError = ''
    this.passwordError = ''
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
        this.phoneError = '请输入手机号'
        this.shake('phone')
        return
      }
      if (this.code.length === 0) {
        this.codeError = '请输入验证码'
        this.shake('code')
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
        this.emailError = '请输入邮箱'
        this.shake('email')
        return
      }
      if (this.password.length === 0) {
        this.passwordError = '请输入密码'
        this.shake('password')
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

  /**
   * 第三方登录（两段式编排）。
   *
   * 第一段：端侧 SDK 授权（拉起第三方 App）→ 结果经 PendingAuthStore 落盘
   * 第二段：authCode → 服务端换票 → GoTrue 会话（由 AuthService 转发 Provider）
   *
   * 「用户主动取消」不报错：pending.kind === 'cancelled' 时静默返回，与超时/失败区分。
   */
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
    // 清掉可能残留的上次授权结果，避免误消费陈旧 code
    await PendingAuthStore.clear(context)
    const uiContext: common.UIAbilityContext | null = this.uiAbilityContextOrNull()
    if (uiContext === null) {
      this.message = '当前页面不可用，请重试'
      return
    }
    this.loading = true
    try {
      // 第一段：拉起第三方 App 完成授权
      try {
        await ThirdPartyBridgeRegistry.sendAuthRequest(uiContext, thirdPartyId)
      } catch (error) {
        const err: Error = error as Error
        this.message = err.message
        return
      }
      // 取授权结果（华为路径在此已可直接消费到；微信/QQ 需返回本应用后才有）
      const pending: PendingAuthRecord | null = await PendingAuthStore.consume(context)
      if (pending === null) {
        // 未拿到结果：可能用户仍在第三方 App（微信/QQ 授权后会重新进入本页并触发新流程），
        // 也可能是回调未到达。给出中性提示而非错误红字。
        this.hint = '请完成授权后返回'
        return
      }
      if (pending.kind === 'failure') {
        // 用户主动取消：静默（不显示错误）
        this.message = pending.message
        return
      }
      // 第二段：换票 + 建立会话
      const result = await AuthService.loginWithThirdParty(context, thirdPartyId, pending.authCode)
      if (!result.success) {
        this.message = result.message
        return
      }
    } finally {
      this.loading = false
    }
    await this.routeAfterLogin(context)
  }

  private async routeAfterLogin(context: Context): Promise<void> {
    await CloudSyncService.onSignIn(context)
    const hasGoal: boolean = await GoalRepository.hasSavedGoal(context)
    this.getUIContext().getRouter().replaceUrl({
      url: StartupDecision.getInitialRoute(true, hasGoal)
    })
  }

  @Builder
  private buildBrandHeader() {
    Column({ space: 12 }) {
      Row() {
        Image($rawfile('fittracker-logo-ring.svg'))
          .width(26)
          .height(26)
      }
      .width(48)
      .height(48)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(PrototypeTokens.ACCENT_A10)
      .borderRadius(16)
      .border({ width: 1, color: PrototypeTokens.ACCENT_A30 })
      Text('FITTRACKER')
        .fontFamily('Inter')
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .letterSpacing(2.4)
        .fontColor(PrototypeTokens.TEXT_HI)
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
        .fontColor(PrototypeTokens.ACCENT)
      Text('欢迎回来')
        .fontFamily('Noto Sans SC')
        .fontSize(35)
        .fontWeight(FontWeight.Bold)
        .fontColor(PrototypeTokens.TEXT_HI)
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
        .fontColor(PrototypeTokens.GOLD)
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
    .backgroundColor(PrototypeTokens.WHITE_A06)
    .border({ width: 1, color: PrototypeTokens.WHITE_A10 })
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
      .fontColor(this.loginMode === modeKey ? PrototypeTokens.TEXT_ON_ACCENT : PrototypeTokens.WHITE_A62)
      .backgroundColor(this.loginMode === modeKey ? PrototypeTokens.ACCENT : Color.Transparent)
      .borderRadius(11)
      .animation({ duration: MotionTokens.DURATION_COLOR_FAST, curve: MotionTokens.EASE_MOTION })
      .onClick(() => {
        if (this.loginMode !== modeKey) {
          this.loginMode = modeKey
          this.message = ''
          this.hint = ''
          this.phoneError = ''
          this.codeError = ''
          this.emailError = ''
          this.passwordError = ''
        }
      })
  }

  /** 触发某字段的左右抖动（校验失败时调用）。 */
  private shake(fieldKey: string): void {
    this.shakeFieldKey = fieldKey
    shakeField(this.getUIContext(), (value: number) => {
      this.shakeOffset = value
    })
  }

  /**
   * 按字段键取当前错误文案。
   *
   * 为什么用方法而不是参数：ArkUI 的 `@Builder` 按值传参时，状态变量变化不会引起
   * 其内部 UI 刷新（官方语义）。错误文案必须在 `@Builder` 函数体内经 `this` 读取，
   * 才会建立依赖并在 `@State` 变化时重绘——故错误文本走本方法取，不走参数传。
   */
  private fieldError(fieldKey: string): string {
    if (fieldKey === 'phone') {
      return this.phoneError
    }
    if (fieldKey === 'email') {
      return this.emailError
    }
    if (fieldKey === 'password') {
      return this.passwordError
    }
    return ''
  }

  @Builder
  private buildField(label: string, placeholder: string, isPassword: boolean, currentValue: string, fieldKey: string, onChange: (value: string) => void) {
    Column() {
      Text(label)
        .fontFamily('Noto Sans SC')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(PrototypeTokens.WHITE_A62)
        .width('100%')
        .margin({ bottom: 8 })
      Row({ space: 12 }) {
        TextInput({ text: currentValue, placeholder: placeholder })
          .type(isPassword && !this.revealPassword ? InputType.Password : InputType.Normal)
          .showPasswordIcon(false)
          .layoutWeight(1)
          .fontFamily('Noto Sans SC')
          .fontSize(16)
          .fontColor(PrototypeTokens.TEXT_HI)
          .placeholderColor(PrototypeTokens.WHITE_A40)
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
              .fillColor(this.revealPassword ? ColorTokens.ACCENT_PRIMARY : PrototypeTokens.WHITE_A54)
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
      .backgroundColor(this.fieldError(fieldKey).length > 0 ? FIELD_ERROR_FILL : (this.focusedField === fieldKey ? PrototypeTokens.ACCENT_A05 : PrototypeTokens.WHITE_A03))
      .borderRadius(18)
      .border({ width: 1, color: this.fieldError(fieldKey).length > 0 ? FIELD_ERROR_BORDER : (this.focusedField === fieldKey ? PrototypeTokens.ACCENT_A45 : PrototypeTokens.WHITE_A08) })
      .alignItems(VerticalAlign.Center)
      .animation({ duration: MotionTokens.DURATION_COLOR_BASE, curve: Curve.EaseInOut })
      .translate({ x: this.shakeFieldKey === fieldKey ? this.shakeOffset : 0 })
      if (this.fieldError(fieldKey).length > 0) {
        Text(this.fieldError(fieldKey))
          .fontFamily('Noto Sans SC')
          .fontSize(12)
          .lineHeight(16.8)
          .fontColor(FIELD_ERROR_TEXT)
          .width('100%')
          .margin({ top: 7 })
          .transition(
            TransitionEffect.OPACITY
              .combine(TransitionEffect.translate({ y: 6 }))
              .animation({ duration: MotionTokens.DURATION_COLOR_BASE, curve: MotionTokens.EASE_MOTION })
          )
      }
    }
    .width('100%')
  }

  @Builder
  private buildCodeField() {
    Column() {
      Text('验证码')
        .fontFamily('Noto Sans SC')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(PrototypeTokens.WHITE_A62)
        .width('100%')
        .margin({ bottom: 8 })
      Row({ space: 10 }) {
        TextInput({ text: this.code, placeholder: '请输入验证码' })
          .type(InputType.Number)
          .maxLength(6)
          .showPasswordIcon(false)
          .layoutWeight(1)
          .fontFamily('Noto Sans SC')
          .fontSize(16)
          .fontColor(PrototypeTokens.TEXT_HI)
          .placeholderColor(PrototypeTokens.WHITE_A40)
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
            if (this.codeError.length > 0) { this.codeError = '' }
          })
        Button(this.countdown > 0 ? this.countdown.toString() + 's' : '获取验证码')
          .height(36)
          .padding({ left: 14, right: 14 })
          .fontFamily('Noto Sans SC')
          .fontSize(12.5)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.countdown > 0 ? PrototypeTokens.WHITE_A40 : PrototypeTokens.TEXT_ON_ACCENT)
          .backgroundColor(this.countdown > 0 ? PrototypeTokens.WHITE_A06 : PrototypeTokens.ACCENT)
          .borderRadius(12)
          .enabled(this.countdown === 0 && !this.sendingCode)
          .onClick(() => {
            this.sendPhoneCode()
          })
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 10 })
      .backgroundColor(this.codeError.length > 0 ? FIELD_ERROR_FILL : (this.focusedField === 'code' ? PrototypeTokens.ACCENT_A05 : PrototypeTokens.WHITE_A03))
      .borderRadius(18)
      .border({ width: 1, color: this.codeError.length > 0 ? FIELD_ERROR_BORDER : (this.focusedField === 'code' ? PrototypeTokens.ACCENT_A45 : PrototypeTokens.WHITE_A08) })
      .alignItems(VerticalAlign.Center)
      .animation({ duration: MotionTokens.DURATION_COLOR_BASE, curve: Curve.EaseInOut })
      .translate({ x: this.shakeFieldKey === 'code' ? this.shakeOffset : 0 })
      if (this.codeError.length > 0) {
        Text(this.codeError)
          .fontFamily('Noto Sans SC')
          .fontSize(12)
          .lineHeight(16.8)
          .fontColor(FIELD_ERROR_TEXT)
          .width('100%')
          .margin({ top: 7 })
          .transition(
            TransitionEffect.OPACITY
              .combine(TransitionEffect.translate({ y: 6 }))
              .animation({ duration: MotionTokens.DURATION_COLOR_BASE, curve: MotionTokens.EASE_MOTION })
          )
      }
    }
    .width('100%')
  }

  @Builder
  private buildAgreementRow() {
    Row({ space: 10 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.agreeChecked) {
          Image($rawfile('pencil-auth-check-agree.svg'))
            .width(14)
            .height(14)
        }
      }
      .width(18)
      .height(18)
      .borderRadius(6)
      .backgroundColor(this.agreeChecked ? PrototypeTokens.ACCENT : '#0AFFFFFF')
      .border({ width: 1, color: this.agreeChecked ? PrototypeTokens.ACCENT : '#2EFFFFFF' })
      .margin({ top: 1 })
      .animation({ duration: MotionTokens.DURATION_COLOR_FAST, curve: Curve.EaseInOut })
      .onClick(() => {
        this.agreeChecked = !this.agreeChecked
      })
      Text() {
        Span('我已阅读并同意')
        Span('《用户协议》')
          .fontColor(PrototypeTokens.ACCENT)
          .fontWeight(FontWeight.Medium)
          .onClick(() => {
            this.getUIContext().getRouter().pushUrl({
              url: AppRoutes.LEGAL_DOC,
              params: { kind: 'agreement' }
            })
          })
        Span('与')
        Span('《隐私政策》')
          .fontColor(PrototypeTokens.ACCENT)
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
      .fontColor(PrototypeTokens.WHITE_A54)
      .lineHeight(19)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .margin({ top: 4 })
  }

  @Builder
  private buildAuthDivider() {
    Row({ space: 12 }) {
      Divider().layoutWeight(1).color(PrototypeTokens.WHITE_A08)
      Text('其他登录方式')
        .fontFamily('Noto Sans SC')
        .fontSize(12)
        .fontColor(PrototypeTokens.WHITE_A40)
      Divider().layoutWeight(1).color(PrototypeTokens.WHITE_A08)
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
        .opacity(0.9)
    } else if (key === 'wechat') {
      Image($rawfile('pencil-social-wechat.svg'))
        .width(20)
        .height(20)
        .opacity(0.9)
    } else {
      Image($rawfile('pencil-social-qq.svg'))
        .width(20)
        .height(20)
        .opacity(0.9)
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
        .fontColor(PrototypeTokens.TEXT_HI)
    }
    .layoutWeight(1)
    .height(50)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(PrototypeTokens.WHITE_A03)
    .borderRadius(16)
    .border({ width: 1, color: PrototypeTokens.WHITE_A10 })
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
        .backgroundColor(PrototypeTokens.BG_INK_WELCOME)
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
                  if (this.phoneError.length > 0) { this.phoneError = '' }
                })
                this.buildCodeField()
              } else {
                this.buildField('邮箱', '请输入邮箱', false, this.email, 'email', (value: string) => {
                  this.email = value
                  if (this.emailError.length > 0) { this.emailError = '' }
                })
                this.buildField('密码', '请输入密码', true, this.password, 'password', (value: string) => {
                  this.password = value
                  if (this.passwordError.length > 0) { this.passwordError = '' }
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
                  .fontColor(PrototypeTokens.ACCENT)
                  .width('100%')
                  .textAlign(TextAlign.Center)
              }

              Button(this.loading ? '登录中…' : '登录')
                .width('100%')
                .height(52)
                .padding(0)
                .margin({ top: 20 })
                .fontFamily('Noto Sans SC')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(PrototypeTokens.TEXT_ON_ACCENT)
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
                .fontColor(PrototypeTokens.WHITE_A60)
              Text('立即注册')
                .fontFamily('Noto Sans SC')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(PrototypeTokens.ACCENT)
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
      .scale({ x: currentCanvasScale(this.getUIContext()), y: currentCanvasScale(this.getUIContext()), centerX: 0, centerY: 0 })
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .backgroundColor(ColorTokens.BG_PRIMARY)
  }
}
