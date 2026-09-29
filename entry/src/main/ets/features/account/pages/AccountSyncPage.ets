/** AccountSyncPage —— 账号与同步（账号信息 / 云同步状态 / 退出登录）。Wave 3 */
import { AppRoutes } from '../../../app/AppRoutes'
import { Context } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { MotionTokens } from '../../../common/styles/DesignTokens'
import SessionManager, { SessionSnapshot } from '../../../common/services/SessionManager'
import CloudSyncService, { SyncResult, SyncState } from '../../../shared/services/CloudSyncService'
import AccountDataLifecycle, { SignOutPreview } from '../../../shared/services/AccountDataLifecycle'

@Entry
@Component
struct AccountSyncPage {
  @State private backPressed: boolean = false
  @State private topInsetVp: number = 0
  @State private displayName: string = ''
  @State private accountText: string = ''
  @State private providerLabel: string = ''
  @State private syncStatusText: string = ''
  @State private syncDetailText: string = ''
  @State private lastSyncText: string = '尚未同步'
  @State private autoEnabled: boolean = true
  @State private syncing: boolean = false
  @State private signingOut: boolean = false
  @State private toastText: string = ''
  @State private toastVisible: boolean = false
  private toastTimer: number = -1

  private contextOrNull(): Context | null {
    const host = this.getUIContext().getHostContext()
    return host === undefined || host === null ? null : host as Context
  }

  async aboutToAppear(): Promise<void> {
    await this.resolveTopInset()
    const context = this.contextOrNull()
    if (context === null) {
      return
    }
    await this.refreshState(context)
  }

  aboutToDisappear(): void {
    if (this.toastTimer >= 0) {
      clearTimeout(this.toastTimer)
      this.toastTimer = -1
    }
  }

  private async resolveTopInset(): Promise<void> {
    // 口径同 SettingsContent：原型顶距含状态栏，设备页面区本身落在状态栏之下。
    const hostContext: Context | undefined = this.getUIContext().getHostContext()
    if (hostContext === undefined) {
      return
    }
    try {
      const mainWindow: window.Window = await window.getLastWindow(hostContext)
      const avoidArea: window.AvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      this.topInsetVp = this.getUIContext().px2vp(avoidArea.topRect.height)
    } catch (e) {
      this.topInsetVp = 0
    }
  }

  private async refreshState(context: Context): Promise<void> {
    const session: SessionSnapshot | null = await SessionManager.getSession(context)
    if (session !== null) {
      this.displayName = session.displayName.length > 0 ? session.displayName : '训练者'
      this.accountText = session.phone.length > 0 ? session.phone : (session.email.length > 0 ? session.email : '本机账号')
      this.providerLabel = this.resolveProviderLabel(session.providerId)
    } else {
      this.displayName = '未登录'
      this.accountText = ''
      this.providerLabel = ''
    }
    const state: SyncState = await CloudSyncService.getState(context)
    this.autoEnabled = state.autoEnabled
    this.lastSyncText = this.formatSyncTime(state.lastSyncAt)
    this.syncStatusText = this.resolveStatusLabel(state.status)
    this.syncDetailText = state.status === 'failed' && state.lastError.length > 0 ? state.lastError : ''
  }

  private resolveProviderLabel(providerId: string): string {
    if (providerId === 'phone_code') {
      return '手机验证码'
    }
    if (providerId === 'email_password') {
      return '邮箱密码'
    }
    if (providerId === 'huawei') {
      return '华为账号'
    }
    if (providerId === 'wechat') {
      return '微信'
    }
    if (providerId === 'qq') {
      return 'QQ'
    }
    return '本地账号'
  }

  private resolveStatusLabel(status: string): string {
    if (status === 'unauthenticated') {
      return '未登录'
    }
    if (status === 'syncing') {
      return '同步中…'
    }
    if (status === 'synced') {
      return '已同步'
    }
    if (status === 'failed') {
      return '同步失败'
    }
    return '尚未同步'
  }

  private formatSyncTime(timestamp: number): string {
    if (timestamp <= 0) {
      return '尚未同步'
    }
    const date: Date = new Date(timestamp)
    const month: number = date.getMonth() + 1
    const day: number = date.getDate()
    const hours: number = date.getHours()
    const minutes: number = date.getMinutes()
    return (month < 10 ? '0' : '') + month.toString() + '-' +
      (day < 10 ? '0' : '') + day.toString() + ' ' +
      (hours < 10 ? '0' : '') + hours.toString() + ':' +
      (minutes < 10 ? '0' : '') + minutes.toString()
  }

  private showToast(text: string): void {
    this.toastText = text
    this.toastVisible = true
    if (this.toastTimer >= 0) {
      clearTimeout(this.toastTimer)
    }
    this.toastTimer = setTimeout(() => {
      this.toastVisible = false
      this.toastTimer = -1
    }, 1800)
  }

  private async syncNow(): Promise<void> {
    const context = this.contextOrNull()
    if (context === null) {
      return
    }
    if (this.syncing) {
      return
    }
    this.syncing = true
    const result: SyncResult = await CloudSyncService.syncNow(context)
    this.syncing = false
    this.showToast(result.message)
    await this.refreshState(context)
  }

  private async toggleAuto(): Promise<void> {
    const context = this.contextOrNull()
    if (context === null) {
      return
    }
    const next: boolean = !this.autoEnabled
    await CloudSyncService.setAutoEnabled(context, next)
    this.autoEnabled = next
    this.showToast(next ? '已开启自动同步' : '已关闭自动同步')
  }

  private async requestSignOut(): Promise<void> {
    const context = this.contextOrNull()
    if (context === null) {
      return
    }
    if (this.signingOut) {
      return
    }
    this.signingOut = true
    const preview: SignOutPreview = await AccountDataLifecycle.prepareSignOut(context)
    if (preview.pendingChanges) {
      this.getUIContext().showAlertDialog({
        title: '退出登录',
        message: '有数据尚未同步到云端，退出后将丢失。确认退出？',
        autoCancel: true,
        primaryButton: {
          value: '取消',
          action: () => {
            this.signingOut = false
          }
        },
        secondaryButton: {
          value: '仍要退出',
          fontColor: '#D77C78',
          action: () => {
            this.performSignOut()
          }
        }
      })
      return
    }
    this.signingOut = false
    await this.performSignOut()
  }

  private async performSignOut(): Promise<void> {
    const context = this.contextOrNull()
    if (context === null) {
      return
    }
    await AccountDataLifecycle.completeSignOut(context)
    // 清空路由栈后进入登录页：避免返回键回到已登出的设置页/主壳
    const router = this.getUIContext().getRouter()
    router.clear()
    router.pushUrl({ url: AppRoutes.LOGIN })
  }

  @Builder
  private buildTopBar() {
    Row({ space: 10 }) {
      Row() {
        Image($rawfile('pencil-plan-nav-chevron-left.svg'))
          .width(20)
          .height(20)
          .opacity(0.7)
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .backgroundColor('#0CFFFFFF')
      .border({ width: 1, color: '#14FFFFFF' })
      .justifyContent(FlexAlign.Center)
      .scale({ x: this.backPressed ? MotionTokens.PRESS_BACK : 1, y: this.backPressed ? MotionTokens.PRESS_BACK : 1 })
      .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.backPressed = true
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.backPressed = false
        }
      })
      .onClick(() => {
        this.getUIContext().getRouter().back()
      })
      Text('账号与同步')
        .fontFamily('Noto Sans SC')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Row()
        .width(44)
        .height(44)
    }
    .width('100%')
    .padding({ top: Math.max(50 - this.topInsetVp, 0), bottom: 12, left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildAccountCard() {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Stack() {
          Column()
            .width(52)
            .height(52)
            .borderRadius(26)
            .backgroundColor('#1A50ECA7')
            .border({ width: 1, color: '#4D50ECA7' })
          Text(this.displayName.length > 0 ? this.displayName.substring(0, 1) : '训')
            .fontFamily('Inter')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#50ECA7')
        }
        .width(52)
        .height(52)
        Column({ space: 5 }) {
          Text(this.displayName)
            .fontFamily('Noto Sans SC')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F7FBF8')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.accountText)
            .fontFamily('Noto Sans SC')
            .fontSize(12.5)
            .fontColor('#9EFFFFFF')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        if (this.providerLabel.length > 0) {
          Text(this.providerLabel)
            .fontFamily('Noto Sans SC')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor('#50ECA7')
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor('#1A50ECA7')
            .borderRadius(999)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor('#08FFFFFF')
    .border({ width: 1, color: '#1AFFFFFF' })
    .borderRadius(22)
  }

  @Builder
  private buildSyncCard() {
    Column({ space: 0 }) {
      Row() {
        Text('同步状态')
          .fontFamily('Noto Sans SC')
          .fontSize(14)
          .fontColor('#F7FBF8')
        Blank()
        Text(this.syncStatusText)
          .fontFamily('Noto Sans SC')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.syncStatusText === '同步失败' ? '#D77C78' : '#50ECA7')
      }
      .width('100%')
      .padding({ top: 15, bottom: 15, left: 2, right: 2 })

      if (this.syncDetailText.length > 0) {
        Text(this.syncDetailText)
          .fontFamily('Noto Sans SC')
          .fontSize(11.5)
          .fontColor('#D77C78')
          .width('100%')
          .padding({ left: 2, right: 2, bottom: 12 })
      }

      Row() {
        Text('上次同步')
          .fontFamily('Noto Sans SC')
          .fontSize(14)
          .fontColor('#F7FBF8')
        Blank()
        Text(this.lastSyncText)
          .fontFamily('Noto Sans SC')
          .fontSize(12.5)
          .fontColor('#8AFFFFFF')
      }
      .width('100%')
      .padding({ top: 15, bottom: 15, left: 2, right: 2 })
      .border({ width: { top: 1 }, color: '#0FFFFFFF' })

      Row() {
        Text('自动同步')
          .fontFamily('Noto Sans SC')
          .fontSize(14)
          .fontColor('#F7FBF8')
        Blank()
        Row() {
          Row()
            .width(22)
            .height(22)
            .borderRadius(11)
            .backgroundColor(this.autoEnabled ? '#07100B' : '#FFFFFF')
            .translate({ x: this.autoEnabled ? 18 : 0 })
            .animation({ duration: MotionTokens.DURATION_COLOR_BASE, curve: MotionTokens.EASE_MOTION })
        }
        .width(46)
        .height(28)
        .borderRadius(14)
        .backgroundColor(this.autoEnabled ? '#50ECA7' : '#1FFFFFFF')
        .border({ width: 1, color: this.autoEnabled ? '#50ECA7' : '#1AFFFFFF' })
        .padding({ left: 1, top: 1 })
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Top)
        .animation({ duration: MotionTokens.DURATION_COLOR_BASE, curve: MotionTokens.EASE_MOTION })
        .onClick(() => {
          this.toggleAuto()
        })
      }
      .width('100%')
      .padding({ top: 15, bottom: 15, left: 2, right: 2 })
      .border({ width: { top: 1 }, color: '#0FFFFFFF' })

      Button(this.syncing ? '同步中…' : '立即同步')
        .width('100%')
        .height(46)
        .padding(0)
        .margin({ top: 4 })
        .fontFamily('Noto Sans SC')
        .fontSize(14.5)
        .fontWeight(FontWeight.Bold)
        .fontColor('#07100B')
        .backgroundColor('#50ECA7')
        .borderRadius(14)
        .enabled(!this.syncing)
        .onClick(() => {
          this.syncNow()
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 16 })
    .backgroundColor('#08FFFFFF')
    .border({ width: 1, color: '#1AFFFFFF' })
    .borderRadius(22)
  }

  @Builder
  private buildSignOutButton() {
    Button(this.signingOut ? '处理中…' : '退出登录')
      .width('100%')
      .height(50)
      .padding(0)
      .fontFamily('Noto Sans SC')
      .fontSize(15)
      .fontWeight(FontWeight.Bold)
      .fontColor('#D77C78')
      .backgroundColor('#14D77C78')
      .border({ width: 1, color: '#4DD77C78' })
      .borderRadius(16)
      .onClick(() => {
        this.requestSignOut()
      })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        this.buildTopBar()
        Scroll() {
          Column({ space: 14 }) {
            this.buildAccountCard()
            this.buildSyncCard()
            this.buildSignOutButton()
            Text('同步内容：训练目标、计划、训练记录与个人资料。退出登录将清除本机业务数据，云端数据在下次登录后恢复。')
              .fontFamily('Noto Sans SC')
              .fontSize(11)
              .fontColor('#8AFFFFFF')
              .lineHeight(18)
              .padding({ left: 6, right: 6, top: 2 })
          }
          .width('100%')
          .padding({ top: 8, left: 16, right: 16, bottom: 30 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')

      if (this.toastVisible) {
        Text(this.toastText)
          .fontFamily('Noto Sans SC')
          .fontSize(13)
          .fontColor('#F7FBF8')
          .lineHeight(18)
          .textAlign(TextAlign.Center)
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .constraintSize({ maxWidth: 320 })
          .backgroundColor('#F00D1117')
          .border({ width: 1, color: '#1AFFFFFF' })
          .borderRadius(999)
          .margin({ bottom: 30 })
          .transition(TransitionEffect.OPACITY
            .combine(TransitionEffect.translate({ y: 10 }))
            .animation({ duration: MotionTokens.DURATION_COLOR_BASE, curve: MotionTokens.EASE_MOTION }))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0B0F13')
  }
}
