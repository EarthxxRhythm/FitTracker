/** ProfileContent - 我的 Tab 界面体（供 PencilAppShell 与独立注册页复用）。 */
import { MotionTokens } from '../../../common/styles/DesignTokens'
import { AppRoutes } from '../../../app/AppRoutes'
import { Context } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { ProfileState, AchievementRow } from './states/ProfileState'
import { PrototypeTokens } from '../../../common/styles/PrototypeTokens'

@Component
export struct ProfileContent {
  @State private settingsPressed: boolean = false
  @State private shortcutKey: string = ''
  @State private topInsetVp: number = 0
  // 状态层：由 PencilAppShell 传入。数据态与装载已迁入 ProfileState，
  // 此处只留 UI 交互态（settingsPressed/shortcutKey/topInsetVp）。
  @ObjectLink state: ProfileState

  private contextOrNull(): Context | null {
    const host = this.getUIContext().getHostContext()
    return host === undefined || host === null ? null : host as Context
  }

  private async resolveTopInset(): Promise<void> {
    // 原型 .profile-content 以屏幕顶为坐标原点（padding-top 53 已把状态栏含在内）；设备侧页面区域
    // 本身就落在状态栏之下，故须从 53 中扣掉状态栏高度，内容才会落在与原型相同的 53vp。
    const context: Context | null = this.contextOrNull()
    if (context === null) {
      return
    }
    try {
      const mainWindow: window.Window = await window.getLastWindow(context)
      const avoidArea: window.AvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      this.topInsetVp = this.getUIContext().px2vp(avoidArea.topRect.height)
    } catch (e) {
      // 取不到安全区时按 0 处理，顶距回退为原型的 53vp
      this.topInsetVp = 0
    }
  }

  async aboutToAppear(): Promise<void> {
    await this.resolveTopInset()
    const context: Context | null = this.contextOrNull()
    if (context !== null) {
      this.state.refresh(context)
    }
  }

  build() {
    Column({ space: 16 }) {
      this.buildProfileHeader()
      this.buildWeeklyOverview()
      this.buildStreak()
      this.buildAchievements()
      this.buildShortcuts()
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: Math.max(53 - this.topInsetVp, 0), bottom: 30 })
    .backgroundColor(PrototypeTokens.BG_INK)
  }

  @Builder
  private buildProfileHeader() {
    Row({ space: 12 }) {
      Stack() {
        Column()
          .width(52)
          .height(52)
          .borderRadius(26)
          .backgroundColor(PrototypeTokens.ACCENT_A10)
          .border({ width: 1, color: PrototypeTokens.ACCENT_A30 })
        Text(this.state.avatarLetter)
          .fontFamily('Inter')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(PrototypeTokens.ACCENT)
      }
      .width(52)
      .height(52)
      Column({ space: 4 }) {
        Text(this.state.nickname)
          .fontFamily('Inter')
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor(PrototypeTokens.TEXT_HI)
          .lineHeight(25.2)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.state.goalSubtitle)
          .fontFamily('Inter')
          .fontSize(12.5)
          .fontColor(PrototypeTokens.WHITE_A62)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Stack() {
        Column()
          .width(44)
          .height(44)
          .borderRadius(22)
          .backgroundColor(PrototypeTokens.WHITE_A05)
          .border({ width: 1, color: PrototypeTokens.WHITE_A08 })
        Image($rawfile('pencil-lucide-settings-2.svg'))
          .width(20)
          .height(20)
      }
      .width(44)
      .height(44)
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.settingsPressed = true
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.settingsPressed = false
        }
      })
      .scale({ x: this.settingsPressed ? MotionTokens.PRESS_ICON : 1, y: this.settingsPressed ? MotionTokens.PRESS_ICON : 1 })
      .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
      .onClick(() => {
        this.getUIContext().getRouter().pushUrl({ url: AppRoutes.SETTINGS })
      })
    }
    .width('100%')
    .padding({ top: 0, bottom: 0 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildWeeklyOverview() {
    Column({ space: 0 }) {
      Row() {
        Text('\u672c\u5468\u6982\u89c8')
          .fontFamily('Inter')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(PrototypeTokens.TEXT_HI)
          .lineHeight(20.4)
        Text(this.state.weekRangeText)
          .fontFamily('Inter')
          .fontSize(11)
          .fontColor(PrototypeTokens.WHITE_A62)
          .lineHeight(16)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Bottom)
      .margin({ bottom: 14 })

      Row({ space: 8 }) {
        Text(this.state.weekDurationText)
          .fontFamily('Inter')
          .fontSize(48)
          .fontWeight(FontWeight.Bold)
          .fontColor(PrototypeTokens.ACCENT)
          .letterSpacing(-0.96)
          .lineHeight(48)
        Text('\u5206\u949f')
          .fontFamily('Inter')
          .fontSize(16)
          .fontColor(PrototypeTokens.WHITE_A62)
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
      .margin({ top: 2 })

      Text('\u672c\u5468\u8bad\u7ec3\u65f6\u957f')
        .fontFamily('Inter')
        .fontSize(12)
        .fontColor(PrototypeTokens.WHITE_A54)
        .lineHeight(17)
        .margin({ top: 8 })

      Row()
        .width('100%')
        .height(1)
        .backgroundColor(PrototypeTokens.WHITE_A06)
        .margin({ top: 15, bottom: 13 })

      Row({ space: 12 }) {
        this.buildFocusMeta('\u8bad\u7ec3', this.state.weekCountText, '\u6b21')
      }
      .width('100%')
    }
    .width('100%')
    .padding(18)
    // 原型末尾「卡片统一：底色与描边（Card Surface v1）」把 .card / .sub-card / .lib-card /
    // .card.focus 统一成同一卡面：底色 rgba(255,255,255,.031)=#08FFFFFF、描边 var(--line-10)
    // =rgba(255,255,255,.10)=#1AFFFFFF。文件前段那份绿色 .card.focus（accent .06 / .22）已被该
    // 后置规则推翻——本卡不再是绿色强调卡；圆角 28 / padding 18 / 阴影沿用 .card.focus 原值。
    .backgroundColor(PrototypeTokens.WHITE_A03)
    .borderRadius(28)
    .border({ width: 1, color: PrototypeTokens.WHITE_A10 })
    // .card.focus 的 `box-shadow: 0 20px 40px rgba(0,0,0,.22)`，ArkUI 的 radius 即模糊半径。
    .shadow({ radius: 40, color: '#38000000', offsetX: 0, offsetY: 20 })
  }

  @Builder
  private buildFocusMeta(label: string, value: string, unit: string) {
    Column({ space: 4 }) {
      Text(label)
        .fontFamily('Inter')
        .fontSize(10.5)
        .fontWeight(FontWeight.Medium)
        .fontColor(PrototypeTokens.WHITE_A62)
      Row({ space: 3 }) {
        Text(value)
          .fontFamily('Inter')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(PrototypeTokens.TEXT_HI)
          .lineHeight(20)
        Text(unit)
          .fontFamily('Inter')
          .fontSize(10.5)
          .fontColor(PrototypeTokens.WHITE_A62)
          .lineHeight(12)
      }
      .alignItems(VerticalAlign.Bottom)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildStreak() {
    Column({ space: 0 }) {
      Row() {
        Text('\u8bad\u7ec3\u8fde\u7eed\u8bb0\u5f55')
          .fontFamily('Inter')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(PrototypeTokens.TEXT_HI)
        Text(this.state.streakLabel())
          .fontFamily('Inter')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(PrototypeTokens.ACCENT)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Bottom)
      .margin({ bottom: 14 })
      Row({ space: 7 }) {
        ForEach(this.state.weekDayLabels, (label: string, index: number) => {
          this.buildStreakDay(label, this.state.weekActiveFlags[index] === true)
        }, (label: string, index: number) => index.toString() + label)
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(PrototypeTokens.WHITE_A03)
    .borderRadius(22)
    .border({ width: 1, color: PrototypeTokens.WHITE_A10 })
  }

  @Builder
  private buildStreakDay(label: string, active: boolean) {
    Column({ space: 6 }) {
      Column()
        .width(28)
        .height(28)
        .borderRadius(14)
        .backgroundColor(active ? PrototypeTokens.ACCENT : PrototypeTokens.WHITE_A08)
        .border({ width: 1, color: active ? PrototypeTokens.ACCENT : PrototypeTokens.WHITE_A08 })
      Text(label)
        .fontFamily('Inter')
        .fontSize(10.5)
        .fontWeight(FontWeight.Medium)
        .fontColor(active ? PrototypeTokens.ACCENT : PrototypeTokens.WHITE_A62)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildAchievements() {    Column({ space: 0 }) {
      Text('\u6700\u8fd1\u6210\u5c31')
        .fontFamily('Inter')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(PrototypeTokens.TEXT_HI)
        .margin({ bottom: 12 })
      if (this.state.achievementRows.length === 0) {
        Text('\u5b8c\u6210\u8bad\u7ec3\u540e\uff0c\u8fd9\u91cc\u4f1a\u663e\u793a\u4f60\u7684\u6210\u5c31\u3002')
          .fontFamily('Inter')
          .fontSize(12.5)
          .fontColor('#9EFFFFFF')
          .padding({ top: 2, bottom: 2 })
      } else {
        ForEach(this.state.achievementRows, (row: AchievementRow) => {
          this.buildAchievement(row.title, row.note, row.value, row.icon)
        }, (row: AchievementRow) => row.title + '|' + row.note)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(PrototypeTokens.WHITE_A03)
    .borderRadius(22)
    .border({ width: 1, color: PrototypeTokens.WHITE_A10 })
  }

  @Builder
  private buildAchievement(title: string, note: string, value: string, icon: string) {
    Row({ space: 12 }) {
      Stack() {
        Column()
          .width(40)
          .height(40)
          .borderRadius(13)
          .backgroundColor(icon === 'trophy' ? '#1FD3B487' : PrototypeTokens.ACCENT_A10)
        if (icon === 'flame') {
          Image($rawfile('pencil-lucide-flame.svg'))
            .width(20)
            .height(20)
            .fillColor(PrototypeTokens.ACCENT)
        } else {
          Image($rawfile('pencil-lucide-trophy.svg'))
            .width(20)
            .height(20)
            .fillColor(PrototypeTokens.GOLD)
        }
      }
      .width(40)
      .height(40)
      Column({ space: 3 }) {
        Text(title)
          .fontFamily('Inter')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(PrototypeTokens.TEXT_HI)
        Text(note)
          .fontFamily('Inter')
          .fontSize(12)
          .fontColor(PrototypeTokens.WHITE_A62)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text(value)
        .fontFamily('Inter')
        .fontSize(11)
        .fontColor(icon === 'trophy' ? PrototypeTokens.GOLD : PrototypeTokens.ACCENT)
    }
    .width('100%')
    .padding({ top: 7, bottom: 7 })
  }

  @Builder
  private buildShortcuts() {
    Row({ space: 8 }) {
      this.buildShortcut('\u8eab\u4f53\u6570\u636e', 'scale')
      this.buildShortcut('\u52a8\u4f5c\u5e93', 'dumbbell')
    }
    .width('100%')
    .height(46)
  }

  @Builder
  private buildShortcut(label: string, icon: string) {
    Row({ space: 8 }) {
      if (icon === 'scale') {
        Image($rawfile('pencil-lucide-scale-balance.svg')).width(18).height(18)
      } else {
        Image($rawfile('pencil-lucide-dumbbell.svg')).width(18).height(18)
      }
      Text(label)
        .fontFamily('Inter')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(PrototypeTokens.WHITE_A70)
        .layoutWeight(1)
      Image($rawfile('pencil-plan-nav-chevron-right.svg'))
        .width(18)
        .height(18)
        .opacity(0.62)
    }
    .layoutWeight(1)
    .height(46)
    .padding({ left: 12, right: 12 })
    .backgroundColor(PrototypeTokens.WHITE_A05)
    .borderRadius(16)
    .border({ width: 1, color: PrototypeTokens.WHITE_A10 })
    .alignItems(VerticalAlign.Center)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.shortcutKey = icon
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.shortcutKey = ''
      }
    })
    .scale({ x: this.shortcutKey === icon ? MotionTokens.PRESS_SHORTCUT : 1, y: this.shortcutKey === icon ? MotionTokens.PRESS_SHORTCUT : 1 })
    .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
    .onClick(() => {
      if (icon === 'scale') {
        this.getUIContext().getRouter().pushUrl({ url: AppRoutes.BODY_DATA })
      } else {
        this.getUIContext().getRouter().pushUrl({ url: AppRoutes.EXERCISE_LIBRARY })
      }
    })
  }

}
