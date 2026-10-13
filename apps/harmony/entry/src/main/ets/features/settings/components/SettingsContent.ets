/** SettingsContent —— 设置二级页界面体（对应 settings.html · screen-settings，390 直绘）。 */
import { MotionTokens } from '../../../common/styles/DesignTokens'
import { window } from '@kit.ArkUI'
import { bundleManager } from '@kit.AbilityKit'
import { i18n } from '@kit.LocalizationKit'
import { AppRoutes } from '../../../app/AppRoutes'
import SessionManager from '../../../common/services/SessionManager'
import CloudSyncService, { SyncState } from '../../../shared/services/CloudSyncService'
import UserProfileService, { UserProfile } from '../../../common/services/UserProfileService'
import SettingsService, { AppSettings, SettingsToggleKey } from '../../../common/services/SettingsService'
import WorkoutReminderService from '../../../common/services/WorkoutReminderService'
import AppNotificationService from '../../../common/services/AppNotificationService'

interface SwitchRow {
  key: string
  label: Resource
  on: boolean
}

function createSwitchRow(key: string, label: Resource, on: boolean): SwitchRow {
  return {
    key: key,
    label: label,
    on: on
  }
}

interface SegRowDef {
  key: string
  label: Resource
  options: Resource[]
  selected: number
}

function createSegRow(key: string, label: Resource, options: Resource[], selected: number): SegRowDef {
  return {
    key: key,
    label: label,
    options: options,
    selected: selected
  }
}

@Component
export struct SettingsContent {
  @State private backPressed: boolean = false
  // 系统状态栏高度（vp）。页面区本身落在状态栏之下，原型顶距须扣掉它才不会双计。
  @State private topInsetVp: number = 0

  aboutToAppear(): void {
    this.resolveTopInset()
    this.loadSyncState()
    this.loadPreferences()
    this.loadAppVersion()
  }

  private contextOrNull(): Context | null {
    const host = this.getUIContext().getHostContext()
    return host === undefined || host === null ? null : host as Context
  }

  private async loadSyncState(): Promise<void> {
    const context: Context | null = this.contextOrNull()
    if (context === null) {
      return
    }
    const state: SyncState = await CloudSyncService.getState(context)
    this.applySyncRow(state.autoEnabled)
  }

  private applySyncRow(enabled: boolean): void {
    this.switchRows = this.switchRows.map((row: SwitchRow) => {
      if (row.key === 'sync') {
        return createSwitchRow(row.key, row.label, enabled)
      }
      return row
    })
  }

  /** 读取本地偏好与资料：体重单位来自 UserProfileService，其余来自 SettingsService；读失败保持默认初值。 */
  private async loadPreferences(): Promise<void> {
    const context: Context | null = this.contextOrNull()
    if (context === null) {
      return
    }
    try {
      const profile: UserProfile = await UserProfileService.loadProfile(context)
      this.applySegSelection('weight', profile.weightUnit === 'lbs' ? 1 : 0)
      const settings: AppSettings = await SettingsService.loadSettings(context)
      this.applySegSelection('language', settings.language === 'en-US' ? 1 : 0)
      this.applySegSelection('weekStart', settings.weekStart === 'sunday' ? 1 : 0)
      this.applyToggleRows(settings)
    } catch (e) {
      // 读取失败时保持默认初值，不打断设置页展示
    }
  }

  /** 用已持久化的设置覆盖五个开关行；同步行由 loadSyncState 管理，不在覆盖范围内。 */
  private applyToggleRows(settings: AppSettings): void {
    this.switchRows = this.switchRows.map((row: SwitchRow) => {
      if (row.key === 'reminder') {
        return createSwitchRow(row.key, row.label, settings.reminder)
      }
      if (row.key === 'achievement') {
        return createSwitchRow(row.key, row.label, settings.achievement)
      }
      if (row.key === 'sound') {
        return createSwitchRow(row.key, row.label, settings.sound)
      }
      if (row.key === 'keep-on') {
        return createSwitchRow(row.key, row.label, settings.keepOn)
      }
      if (row.key === 'anonymous') {
        return createSwitchRow(row.key, row.label, settings.anonymous)
      }
      return row
    })
  }

  /** 版本号取自应用包信息；取不到时显示占位符，避免该行出现空白。 */
  private async loadAppVersion(): Promise<void> {
    try {
      const info = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT)
      this.versionText = info.versionName
    } catch (e) {
      this.versionText = '—'
    }
  }

  /**
   * 原型 .st-top 的 padding-top: 50 以屏幕顶为原点（已把状态栏含在内）；设备侧页面区本身落在
   * 状态栏之下，若原样使用 50 就与系统避让重复计数，顶栏整体下移一个状态栏高度（实测 39vp）。
   * 口径同 HomeContent / PlansContent / PlanGroupDetailContent / PlanContent / BodyDataContent。
   */
  private async resolveTopInset(): Promise<void> {
    const hostContext: Context | undefined = this.getUIContext().getHostContext()
    if (hostContext === undefined) {
      return
    }
    try {
      const mainWindow: window.Window = await window.getLastWindow(hostContext)
      const avoidArea: window.AvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      this.topInsetVp = this.getUIContext().px2vp(avoidArea.topRect.height)
    } catch (e) {
      // 取不到安全区时按 0 处理，顶距回退为原型的 50vp
      this.topInsetVp = 0
    }
  }
  @State private toastVisible: boolean = false
  @State private toastMessage: Resource = $r('app.string.settings_toast_saved')
  @State private toastTimer: number = -1
  @State private segRows: SegRowDef[] = [
    createSegRow('weight', $r('app.string.settings_row_weight_unit'),
      [$r('app.string.settings_option_kg'), $r('app.string.settings_option_lbs')], 0),
    createSegRow('language', $r('app.string.settings_row_language'),
      [$r('app.string.settings_option_zh'), $r('app.string.settings_option_en')], 0),
    createSegRow('weekStart', $r('app.string.settings_row_week_start'),
      [$r('app.string.settings_option_monday'), $r('app.string.settings_option_sunday')], 0)
  ]
  @State private versionText: string = '1.1.0'
  @State private switchRows: SwitchRow[] = [
    createSwitchRow('reminder', $r('app.string.settings_row_reminder'), true),
    createSwitchRow('achievement', $r('app.string.settings_row_achievement'), false),
    createSwitchRow('sound', $r('app.string.settings_row_sound'), true),
    createSwitchRow('keep-on', $r('app.string.settings_row_keep_on'), true),
    createSwitchRow('sync', $r('app.string.settings_row_sync'), true),
    createSwitchRow('anonymous', $r('app.string.settings_row_anonymous'), false)
  ]

  private handleBack(): void {
    this.getUIContext().getRouter().back()
  }

  private toggleSwitch(key: string): void {
    if (key === 'sync') {
      this.toggleSyncRow()
      return
    }
    const previous: boolean = this.isSwitchOn(key)
    const next: boolean = !previous
    this.switchRows = this.switchRows.map((row: SwitchRow) => {
      if (row.key === key) {
        const updated: SwitchRow = createSwitchRow(row.key, row.label, next)
        return updated
      }
      return row
    })
    this.persistToggle(key, next, previous)
  }

  /**
   * 开关行落盘：成功提示「已保存」；失败（含取不到 context）回滚内存状态并提示重试。
   * 「训练提醒」额外两条：开启前先请求通知授权（拒绝则回滚、不落库、不调度）；
   * 落盘成功后同步提醒调度（开/关都走同一幂等入口）。
   */
  private async persistToggle(key: string, next: boolean, previous: boolean): Promise<void> {
    const context: Context | null = this.contextOrNull()
    if (context === null) {
      this.applyToggleRow(key, previous)
      this.showToast($r('app.string.settings_toast_save_failed'))
      return
    }
    if (key === 'reminder' && next) {
      const granted: boolean = await AppNotificationService.requestEnable(context)
      if (!granted) {
        this.applyToggleRow(key, previous)
        this.showToast($r('app.string.settings_toast_reminder_need_permission'))
        return
      }
    }
    await SettingsService.saveToggle(context, this.toSettingsToggleKey(key), next)
    if (SettingsService.getLastPersistenceError().length > 0) {
      this.applyToggleRow(key, previous)
      this.showToast($r('app.string.settings_toast_save_failed'))
      return
    }
    if (key === 'reminder') {
      await WorkoutReminderService.syncFromSettings(context)
    }
    this.showToast($r('app.string.settings_toast_saved'))
  }

  /** 把开关行的行 key 映射为 SettingsService 的开关键（'keep-on' ↔ 'keepOn'，其余同名）。 */
  private toSettingsToggleKey(key: string): SettingsToggleKey {
    if (key === 'keep-on') {
      return 'keepOn'
    }
    if (key === 'achievement') {
      return 'achievement'
    }
    if (key === 'sound') {
      return 'sound'
    }
    if (key === 'anonymous') {
      return 'anonymous'
    }
    return 'reminder'
  }

  /** 仅回滚指定开关行的内存状态（持久化失败时用）。 */
  private applyToggleRow(key: string, on: boolean): void {
    this.switchRows = this.switchRows.map((row: SwitchRow) => {
      if (row.key === key) {
        return createSwitchRow(row.key, row.label, on)
      }
      return row
    })
  }

  private segSelected(key: string): number {
    for (let i = 0; i < this.segRows.length; i++) {
      if (this.segRows[i].key === key) {
        return this.segRows[i].selected
      }
    }
    return 0
  }

  /** 更新指定分段行的选中值（重建数组引用，驱动 ForEach 刷新）。 */
  private applySegSelection(key: string, selected: number): void {
    this.segRows = this.segRows.map((row: SegRowDef) => {
      if (row.key === key) {
        return createSegRow(row.key, row.label, row.options, selected)
      }
      return row
    })
  }

  /** 分段行点击分派（行 key → 具体保存流程）。 */
  private handleSegTap(key: string, index: number): void {
    if (key === 'weight') {
      this.handleWeightUnitChange(index)
      return
    }
    if (key === 'language') {
      this.handleLanguageChange(index)
      return
    }
    this.handleWeekStartChange(index)
  }

  /** 体重单位：先乐观更新选中态，再落盘；失败回滚并提示重试。 */
  private async handleWeightUnitChange(index: number): Promise<void> {
    const previous: number = this.segSelected('weight')
    this.applySegSelection('weight', index)
    const context: Context | null = this.contextOrNull()
    if (context === null) {
      this.applySegSelection('weight', previous)
      this.showToast($r('app.string.settings_toast_save_failed'))
      return
    }
    await UserProfileService.saveWeightUnit(context, index === 1 ? 'lbs' : 'kg')
    if (UserProfileService.getLastPersistenceError().length > 0) {
      this.applySegSelection('weight', previous)
      this.showToast($r('app.string.settings_toast_save_failed'))
      return
    }
    this.showToast($r('app.string.settings_toast_saved'))
  }

  /**
   * 语言：先乐观更新选中态，再落盘；失败回滚并提示重试。
   * 落盘成功后同步应用级语言设置（i18n per-app 偏好；下次启动生效——
   * 与 Android AppCompatDelegate per-app locale 的「存储双写」语义对齐）。
   */
  private async handleLanguageChange(index: number): Promise<void> {
    const previous: number = this.segSelected('language')
    this.applySegSelection('language', index)
    const context: Context | null = this.contextOrNull()
    if (context === null) {
      this.applySegSelection('language', previous)
      this.showToast($r('app.string.settings_toast_save_failed'))
      return
    }
    await SettingsService.saveLanguage(context, index === 1 ? 'en-US' : 'zh-CN')
    if (SettingsService.getLastPersistenceError().length > 0) {
      this.applySegSelection('language', previous)
      this.showToast($r('app.string.settings_toast_save_failed'))
      return
    }
    try {
      i18n.System.setAppPreferredLanguage(index === 1 ? 'en-US' : 'zh-Hans')
    } catch (e) {
      // 应用级语言设置失败不影响存储结果与提示
    }
    this.showToast($r('app.string.settings_toast_saved'))
  }

  /** 周开始日：先乐观更新选中态，再落盘；失败回滚并提示重试。 */
  private async handleWeekStartChange(index: number): Promise<void> {
    const previous: number = this.segSelected('weekStart')
    this.applySegSelection('weekStart', index)
    const context: Context | null = this.contextOrNull()
    if (context === null) {
      this.applySegSelection('weekStart', previous)
      this.showToast($r('app.string.settings_toast_save_failed'))
      return
    }
    await SettingsService.saveWeekStart(context, index === 1 ? 'sunday' : 'monday')
    if (SettingsService.getLastPersistenceError().length > 0) {
      this.applySegSelection('weekStart', previous)
      this.showToast($r('app.string.settings_toast_save_failed'))
      return
    }
    this.showToast($r('app.string.settings_toast_saved'))
  }

  /** 训练数据同步：接线 CloudSyncService（未登录时提示先登录）。 */
  private async toggleSyncRow(): Promise<void> {
    const context: Context | null = this.contextOrNull()
    if (context === null) {
      this.showToast($r('app.string.settings_toast_unavailable'))
      return
    }
    const loggedIn: boolean = await SessionManager.isLoggedIn(context)
    if (!loggedIn) {
      this.showToast($r('app.string.settings_toast_login_first'))
      return
    }
    const next: boolean = !this.isSwitchOn('sync')
    await CloudSyncService.setAutoEnabled(context, next)
    this.applySyncRow(next)
    this.showToast(next ? $r('app.string.settings_toast_sync_on') : $r('app.string.settings_toast_sync_off'))
  }

  private showToast(text: Resource): void {
    this.toastMessage = text
    this.toastVisible = true
    if (this.toastTimer >= 0) {
      clearTimeout(this.toastTimer)
    }
    this.toastTimer = setTimeout(() => {
      this.toastVisible = false
    }, 1600)
  }

  private isSwitchOn(key: string): boolean {
    for (let i = 0; i < this.switchRows.length; i++) {
      if (this.switchRows[i].key === key) {
        return this.switchRows[i].on
      }
    }
    return false
  }

  aboutToDisappear(): void {
    if (this.toastTimer >= 0) {
      clearTimeout(this.toastTimer)
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
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
            this.handleBack()
          })
          Text($r('app.string.settings_title'))
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
        // 原型以屏幕顶为原点；设备页面区已在状态栏下方，扣掉状态栏高度才是与原型一致的 50vp 顶距。
        .padding({ top: Math.max(50 - this.topInsetVp, 0), bottom: 12, left: 16, right: 16 })
        .alignItems(VerticalAlign.Center)

        Scroll() {
          Column({ space: 14 }) {
            this.generalCard()
            this.dataPrivacyCard()
            this.aboutCard()
            Text($r('app.string.settings_footer'))
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
        Text(this.toastMessage)
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

  @Builder
  private generalCard() {
    Column() {
      this.sectionTitle($r('app.string.settings_section_general'), '')
      ForEach(this.segRows, (row: SegRowDef, index: number) => {
        Row() {
          Text(row.label)
            .fontFamily('Noto Sans SC')
            .fontSize(14)
            .fontColor('#F7FBF8')
          Blank()
          Row({ space: 2 }) {
            ForEach(row.options, (option: Resource, optionIndex: number) => {
              Button(option)
                .height(30)
                .padding({ left: 16, right: 16 })
                .fontFamily('Noto Sans SC')
                .fontSize(12.5)
                .fontWeight(FontWeight.Bold)
                .fontColor(optionIndex === row.selected ? '#07100B' : '#9EFFFFFF')
                .backgroundColor(optionIndex === row.selected ? '#50ECA7' : Color.Transparent)
                .borderRadius(9)
                .animation({ duration: MotionTokens.DURATION_COLOR_FAST, curve: MotionTokens.EASE_MOTION })
                .onClick(() => {
                  this.handleSegTap(row.key, optionIndex)
                })
            }, (option: Resource, optionIndex: number) => row.key + ':' + optionIndex.toString())
          }
          .padding(3)
          .backgroundColor('#0FFFFFFF')
          .border({ width: 1, color: '#1AFFFFFF' })
          .borderRadius(12)
        }
        .width('100%')
        .padding({ top: 15, bottom: 15, left: 2, right: 2 })
        .border({ width: { top: index === 0 ? 0 : 1 }, color: '#0FFFFFFF' })
      }, (row: SegRowDef) => row.key + ':' + row.selected.toString())
      ForEach(this.switchRows, (row: SwitchRow, index: number) => {
        if (index < 4) {
          Row() {
            Text(row.label)
              .fontFamily('Noto Sans SC')
              .fontSize(14)
              .fontColor('#F7FBF8')
            Blank()
            Row() {
              Row()
                .width(22)
                .height(22)
                .borderRadius(11)
                .backgroundColor(row.on ? '#07100B' : '#FFFFFF')
                .translate({ x: row.on ? 18 : 0 })
                .animation({ duration: MotionTokens.DURATION_COLOR_BASE, curve: MotionTokens.EASE_MOTION })
            }
            .width(46)
            .height(28)
            .borderRadius(14)
            .backgroundColor(row.on ? '#50ECA7' : '#1FFFFFFF')
            .border({ width: 1, color: row.on ? '#50ECA7' : '#1AFFFFFF' })
            .padding({ left: 1, top: 1 })
            .justifyContent(FlexAlign.Start)
            .alignItems(VerticalAlign.Top)
            .animation({ duration: MotionTokens.DURATION_COLOR_BASE, curve: MotionTokens.EASE_MOTION })
            .onClick(() => {
              this.toggleSwitch(row.key)
            })
          }
          .width('100%')
          .padding({ top: 15, bottom: 15, left: 2, right: 2 })
          .border({ width: { top: 1 }, color: '#0FFFFFFF' })
        }
      }, (row: SwitchRow) => row.key + (row.on ? ':1' : ':0'))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor('#08FFFFFF')
    .border({ width: 1, color: '#1AFFFFFF' })
    .borderRadius(22)
  }

  @Builder
  private dataPrivacyCard() {
    Column() {
      this.sectionTitle($r('app.string.settings_section_privacy'), '')
      this.chevronRow($r('app.string.settings_row_health'), $r('app.string.settings_value_not_connected'), true, () => {
        this.showToast($r('app.string.settings_toast_health_placeholder'))
      })
      this.accountSyncRow()
      ForEach(this.switchRows, (row: SwitchRow, index: number) => {
        if (index >= 4) {
          Row() {
            Text(row.label)
              .fontFamily('Noto Sans SC')
              .fontSize(14)
              .fontColor('#F7FBF8')
            Blank()
            Row() {
              Row()
                .width(22)
                .height(22)
                .borderRadius(11)
                .backgroundColor(row.on ? '#07100B' : '#FFFFFF')
                .translate({ x: row.on ? 18 : 0 })
                .animation({ duration: MotionTokens.DURATION_COLOR_BASE, curve: MotionTokens.EASE_MOTION })
            }
            .width(46)
            .height(28)
            .borderRadius(14)
            .backgroundColor(row.on ? '#50ECA7' : '#1FFFFFFF')
            .border({ width: 1, color: row.on ? '#50ECA7' : '#1AFFFFFF' })
            .padding({ left: 1, top: 1 })
            .justifyContent(FlexAlign.Start)
            .alignItems(VerticalAlign.Top)
            .animation({ duration: MotionTokens.DURATION_COLOR_BASE, curve: MotionTokens.EASE_MOTION })
            .onClick(() => {
              this.toggleSwitch(row.key)
            })
          }
          .width('100%')
          .padding({ top: 15, bottom: 15, left: 2, right: 2 })
          .border({ width: { top: 1 }, color: '#0FFFFFFF' })
        }
      }, (row: SwitchRow) => row.key + (row.on ? ':1' : ':0'))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor('#08FFFFFF')
    .border({ width: 1, color: '#1AFFFFFF' })
    .borderRadius(22)
  }

  @Builder
  private accountSyncRow() {
    Row() {
      Text($r('app.string.settings_row_account_sync'))
        .fontFamily('Noto Sans SC')
        .fontSize(14)
        .fontColor('#F7FBF8')
      Blank()
      Image($rawfile('pencil-plan-nav-chevron-right.svg'))
        .width(18)
        .height(18)
        .opacity(0.4)
        .margin({ left: 6 })
    }
    .width('100%')
    .padding({ top: 15, bottom: 15, left: 2, right: 2 })
    .border({ width: { top: 1 }, color: '#0FFFFFFF' })
    .onClick(() => {
      this.getUIContext().getRouter().pushUrl({ url: AppRoutes.ACCOUNT_SYNC })
    })
  }

  @Builder
  private aboutCard() {
    Column() {
      Row() {
        Text($r('app.string.settings_section_about'))
          .fontFamily('Noto Sans SC')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text($r('app.string.settings_brand'))
          .fontFamily('Noto Sans SC')
          .fontSize(11)
          .fontColor('#9EFFFFFF')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .padding({ bottom: 4 })

      Row() {
        Text($r('app.string.settings_row_version'))
          .fontFamily('Noto Sans SC')
          .fontSize(14)
          .fontColor('#F7FBF8')
        Text(this.versionText)
          .fontFamily('Noto Sans SC')
          .fontSize(12.5)
          .fontColor('#8AFFFFFF')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .padding({ top: 15, bottom: 15, left: 2, right: 2 })

      this.chevronRow($r('app.string.settings_row_privacy'), null, false, () => {
        this.getUIContext().getRouter().pushUrl({
          url: AppRoutes.LEGAL_DOC,
          params: { kind: 'privacy' }
        })
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor('#08FFFFFF')
    .border({ width: 1, color: '#1AFFFFFF' })
    .borderRadius(22)
  }

  @Builder
  private sectionTitle(title: Resource, meta: string) {
    Row() {
      Text(title)
        .fontFamily('Noto Sans SC')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
      if (meta.length > 0) {
        Text(meta)
          .fontFamily('Noto Sans SC')
          .fontSize(11)
          .fontColor('#9EFFFFFF')
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .padding({ bottom: 4 })
  }

  @Builder
  private chevronRow(label: Resource, value: Resource | null, first: boolean, onTap?: () => void) {
    Row() {
      Text(label)
        .fontFamily('Noto Sans SC')
        .fontSize(14)
        .fontColor('#F7FBF8')
      Blank()
      if (value !== null) {
        Text(value)
          .fontFamily('Noto Sans SC')
          .fontSize(12.5)
          .fontColor('#8AFFFFFF')
      }
      Image($rawfile('pencil-plan-nav-chevron-right.svg'))
        .width(18)
        .height(18)
        .opacity(0.4)
        .margin({ left: 6 })
    }
    .width('100%')
    .padding({ top: 15, bottom: 15, left: 2, right: 2 })
    .border({ width: { top: first ? 0 : 1 }, color: '#0FFFFFFF' })
    .onClick(() => {
      if (onTap !== undefined) {
        onTap()
      }
    })
  }
}
