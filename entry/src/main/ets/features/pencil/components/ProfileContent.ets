/** ProfileContent - 我的 Tab 界面体（供 PencilAppShell 与独立注册页复用）。 */
import { MotionTokens } from '../../../common/styles/DesignTokens'
import { AppRoutes } from '../../../app/AppRoutes'
import { Context } from '@kit.AbilityKit'
import UserProfileService, { UserProfile } from '../../../common/services/UserProfileService'
import WorkoutSessionService, { WeeklyStats } from '../../../common/services/WorkoutSessionService'
import GoalRepository from '../../../shared/services/GoalRepository'
import { UserGoal } from '../../../shared/models/TrainingModels'
@Component
export struct ProfileContent {
  @State private settingsPressed: boolean = false
  @State private shortcutKey: string = ''
  @State private avatarLetter: string = '\u6797'
  @State private nickname: string = '\u8c31\u5c3c'
  @State private goalSubtitle: string = '\u589e\u808c\u7b2c 42 \u5929 \u00b7 \u4fdd\u6301\u8282\u594f'
  @State private weekRangeText: string = '7 \u6708 21 \u2013 27 \u65e5'
  @State private weekDurationText: string = '186'
  @State private weekCountText: string = '4'
  @State private weekCaloriesText: string = '1,240'

  private contextOrNull(): Context | null {
    const host = this.getUIContext().getHostContext()
    return host === undefined || host === null ? null : host as Context
  }

  async aboutToAppear(): Promise<void> {
    // Week range is pure date math and does not depend on persisted data.
    this.weekRangeText = this.computeWeekRangeText()
    const context: Context | null = this.contextOrNull()
    if (context === null) {
      // No host context: keep the placeholder values, never throw.
      return
    }
    try {
      const profile: UserProfile = await UserProfileService.loadProfile(context)
      // profile.weightUnit is loaded but not rendered on this page yet;
      // it is available for the future body-data entry.
      this.avatarLetter = profile.avatar.trim().length > 0
        ? profile.avatar.trim().charAt(0)
        : '\u6797'
      this.nickname = profile.nickname.trim().length > 0
        ? profile.nickname.trim()
        : '\u8c31\u5c3c'
    } catch (error) {
      // Profile read failed: keep the default avatar letter and nickname placeholder.
    }
    try {
      const goal: UserGoal | undefined = await GoalRepository.loadGoal(context)
      if (goal !== undefined && goal.createdAt > 0) {
        const dayCount: number = this.computeGoalDayCount(goal.createdAt)
        this.goalSubtitle = '\u589e\u808c\u7b2c ' + dayCount.toString() + ' \u5929 \u00b7 \u4fdd\u6301\u8282\u594f'
      } else {
        this.goalSubtitle = '\u672a\u8bbe\u7f6e\u76ee\u6807'
      }
    } catch (error) {
      // Goal read failed: keep the placeholder subtitle.
    }
    try {
      const stats: WeeklyStats = await WorkoutSessionService.getWeeklyStats(context)
      this.weekDurationText = Math.round(stats.duration / 60).toString()
      this.weekCountText = stats.count.toString()
      this.weekCaloriesText = this.estimateCaloriesText(stats.volume)
    } catch (error) {
      // Weekly stats read failed: keep the placeholder numbers.
    }
  }

  private computeWeekRangeText(): string {
    const now: Date = new Date()
    const dayOfWeek: number = now.getDay()
    const mondayOffset: number = dayOfWeek === 0 ? 6 : dayOfWeek - 1
    const monday: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate() - mondayOffset)
    const sunday: Date = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + 6)
    const startText: string = (monday.getMonth() + 1).toString() + ' \u6708 ' + monday.getDate().toString()
    const endText: string = sunday.getMonth() === monday.getMonth()
      ? sunday.getDate().toString() + ' \u65e5'
      : (sunday.getMonth() + 1).toString() + ' \u6708 ' + sunday.getDate().toString() + ' \u65e5'
    return startText + ' \u2013 ' + endText
  }

  private computeGoalDayCount(createdAt: number): number {
    // createdAt is a millisecond timestamp; day 1 starts on the goal creation date.
    const oneDayMs: number = 24 * 60 * 60 * 1000
    const days: number = Math.floor((Date.now() - createdAt) / oneDayMs) + 1
    return days < 1 ? 1 : days
  }

  private estimateCaloriesText(volume: number): string {
    // WeeklyStats has no calorie field. Rough placeholder estimate:
    // 1 kg of training volume is treated as ~0.1 kcal; volume 0 shows 0.
    // Replace once real metabolic data is available.
    return Math.round(volume * 0.1).toString()
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        this.buildProfileHeader()
        this.buildWeeklyOverview()
        this.buildStreak()
        this.buildAchievements()
        this.buildShortcuts()
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .padding({ left: 16, right: 16, top: 53, bottom: 30 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor('#0B0F13')
  }

  @Builder
  private buildProfileHeader() {
    Row({ space: 12 }) {
      Stack() {
        Column()
          .width(52)
          .height(52)
          .borderRadius(26)
          .backgroundColor('#1A50ECA7')
          .border({ width: 1, color: '#4D50ECA7' })
        Text(this.avatarLetter)
          .fontFamily('Inter')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#50ECA7')
      }
      .width(52)
      .height(52)
      Column({ space: 4 }) {
        Text(this.nickname)
          .fontFamily('Inter')
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
          .lineHeight(25.2)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.goalSubtitle)
          .fontFamily('Inter')
          .fontSize(12.5)
          .fontColor('#9EFFFFFF')
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
          .backgroundColor('#0CFFFFFF')
          .border({ width: 1, color: '#14FFFFFF' })
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
          .fontColor('#F7FBF8')
        Text(this.weekRangeText)
          .fontFamily('Inter')
          .fontSize(11)
          .fontColor('#9EFFFFFF')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Bottom)
      .margin({ bottom: 14 })

      Row({ space: 8 }) {
        Text(this.weekDurationText)
          .fontFamily('Inter')
          .fontSize(48)
          .fontWeight(FontWeight.Bold)
          .fontColor('#50ECA7')
          .letterSpacing(-0.96)
          .lineHeight(48)
        Text('\u5206\u949f')
          .fontFamily('Inter')
          .fontSize(16)
          .fontColor('#9EFFFFFF')
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
      .margin({ top: 2 })

      Text('\u672c\u5468\u8bad\u7ec3\u65f6\u957f')
        .fontFamily('Inter')
        .fontSize(12)
        .fontColor('#8AFFFFFF')
        .margin({ top: 8 })

      Row()
        .width('100%')
        .height(1)
        .backgroundColor('#0FFFFFFF')
        .margin({ top: 15, bottom: 13 })

      Row({ space: 12 }) {
        this.buildFocusMeta('\u8bad\u7ec3', this.weekCountText, '\u6b21')
        this.buildFocusMeta('\u6d88\u8017', this.weekCaloriesText, '\u5343\u5361')
      }
      .width('100%')
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#0F50ECA7')
    .borderRadius(28)
    .border({ width: 1, color: '#3850ECA7' })
  }

  @Builder
  private buildFocusMeta(label: string, value: string, unit: string) {
    Column({ space: 4 }) {
      Text(label)
        .fontFamily('Inter')
        .fontSize(10.5)
        .fontWeight(FontWeight.Medium)
        .fontColor('#9EFFFFFF')
      Row({ space: 3 }) {
        Text(value)
          .fontFamily('Inter')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
          .lineHeight(20)
        Text(unit)
          .fontFamily('Inter')
          .fontSize(10.5)
          .fontColor('#9EFFFFFF')
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
          .fontColor('#F7FBF8')
        Text('\u8fde\u7eed 6 \u5929')
          .fontFamily('Inter')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#50ECA7')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Bottom)
      .margin({ bottom: 14 })
      Row({ space: 7 }) {
        this.buildStreakDay('\u4e00', true)
        this.buildStreakDay('\u4e8c', true)
        this.buildStreakDay('\u4e09', true)
        this.buildStreakDay('\u56db', true)
        this.buildStreakDay('\u4e94', true)
        this.buildStreakDay('\u516d', true)
        this.buildStreakDay('\u65e5', false)
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#06FFFFFF')
    .borderRadius(22)
    .border({ width: 1, color: '#1AFFFFFF' })
  }

  @Builder
  private buildStreakDay(label: string, active: boolean) {
    Column({ space: 6 }) {
      Column()
        .width(28)
        .height(28)
        .borderRadius(14)
        .backgroundColor(active ? '#50ECA7' : '#14FFFFFF')
        .border({ width: 1, color: active ? '#50ECA7' : '#14FFFFFF' })
      Text(label)
        .fontFamily('Inter')
        .fontSize(10.5)
        .fontWeight(FontWeight.Medium)
        .fontColor(active ? '#50ECA7' : '#9EFFFFFF')
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildAchievements() {
    Column({ space: 0 }) {
      Text('\u6700\u8fd1\u6210\u5c31')
        .fontFamily('Inter')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
        .margin({ bottom: 12 })
      this.buildAchievement('\u7a33\u5b9a\u8f93\u51fa', '\u8fde\u7eed\u8bad\u7ec3 7 \u5929', '\u672c\u5468\u5b8c\u6210\u5ea6 86%', 'flame')
      this.buildAchievement('\u91cd\u91cf\u7a81\u7834', '\u6df1\u8e72\u8fbe\u5230 80 kg', '\u5237\u65b0\u4e2a\u4eba\u6700\u4f73', 'trophy')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#06FFFFFF')
    .borderRadius(22)
    .border({ width: 1, color: '#1AFFFFFF' })
  }

  @Builder
  private buildAchievement(title: string, note: string, value: string, icon: string) {
    Row({ space: 12 }) {
      Stack() {
        Column()
          .width(40)
          .height(40)
          .borderRadius(13)
          .backgroundColor(icon === 'trophy' ? '#1FD3B487' : '#1A50ECA7')
        if (icon === 'flame') {
          Image($rawfile('pencil-lucide-flame.svg'))
            .width(20)
            .height(20)
            .fillColor('#50ECA7')
        } else {
          Image($rawfile('pencil-lucide-trophy.svg'))
            .width(20)
            .height(20)
            .fillColor('#D3B487')
        }
      }
      .width(40)
      .height(40)
      Column({ space: 3 }) {
        Text(title)
          .fontFamily('Inter')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text(note)
          .fontFamily('Inter')
          .fontSize(12)
          .fontColor('#9EFFFFFF')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text(value)
        .fontFamily('Inter')
        .fontSize(11)
        .fontColor(icon === 'trophy' ? '#D3B487' : '#50ECA7')
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
        .fontColor('#B3FFFFFF')
        .layoutWeight(1)
      Path()
        .width(18)
        .height(18)
        .commands('M9 6 L15 12 L9 18')
        .fillOpacity(0)
        .stroke('#9EFFFFFF')
        .strokeWidth(2)
    }
    .layoutWeight(1)
    .height(46)
    .padding({ left: 12, right: 12 })
    .backgroundColor('#0CFFFFFF')
    .borderRadius(16)
    .border({ width: 1, color: '#1AFFFFFF' })
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
