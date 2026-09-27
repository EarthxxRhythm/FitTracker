/** HomeContent - 首页 Tab 界面体（供 PencilAppShell 与独立注册页复用）。 */
import { AppRoutes } from '../../../app/AppRoutes'
import { MotionTokens } from '../../../common/styles/DesignTokens'
import { Context } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { UserGoal, TrainingPlan, PlanDay, WorkoutSession } from '../../../shared/models/TrainingModels'
import WorkoutSessionService, { WeeklyStats } from '../../../common/services/WorkoutSessionService'
import StatsDashboardService, { StatsDashboardSummary } from '../../../shared/services/StatsDashboardService'
import GoalRepository from '../../../shared/services/GoalRepository'
import PlanEngine from '../../../shared/services/PlanEngine'
import HomePlanService, { HomePlanSummary } from '../../../shared/services/HomePlanService'
import WorkoutSessionPersistenceBridgeService from '../../workout/services/WorkoutSessionPersistenceBridgeService'

interface HomeWeekDayItem {
  label: string
  dateText: string
  isTrained: boolean
}

@Component
export struct HomeContent {
  private static readonly CHINESE_FONT_FAMILY: string = 'Noto Sans SC'
  private static readonly NUMBER_FONT_FAMILY: string = 'Inter'
  @State private primaryPressed: boolean = false
  @State private currentDateText: string = ''
  @State private greetingText: string = ''
  @State private weeklyProgressPercent: number = 0
  @State private todayExerciseCount: number = 0
  @State private todayDurationMinutes: number = 0
  @State private todayMuscleGroupCount: number = 0
  @State private weeklyTrainedCount: number = 0
  @State private weeklyPlannedDays: number = 0
  @State private weekDays: HomeWeekDayItem[] = []
  @State private topInsetVp: number = 0

  async aboutToAppear(): Promise<void> {
    await this.resolveTopInset()
    this.applyDateAndGreeting()
    const context: Context | null = this.contextOrNull()
    if (context === null) {
      this.applyEmptyState()
      return
    }
    try {
      await this.loadDynamicContent(context)
    } catch (error) {
      this.weeklyTrainedCount = 0
      this.weekDays = this.createWeekDayItems([])
      this.applyEmptyState()
    }
  }

  private contextOrNull(): Context | null {
    const host = this.getUIContext().getHostContext()
    return host === undefined || host === null ? null : host as Context
  }

  private async resolveTopInset(): Promise<void> {
    // 原型 .home-content 以屏幕顶为坐标原点（padding-top 53 已把状态栏含在内）；设备侧页面区域
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

  private applyDateAndGreeting(): void {
    const now: Date = new Date()
    this.currentDateText = this.formatDateText(now)
    this.greetingText = this.createGreeting(now.getHours())
  }

  private formatDateText(now: Date): string {
    const weekdayLabels: string[] = ['日', '一', '二', '三', '四', '五', '六']
    return (now.getMonth() + 1).toString() + '月' + now.getDate().toString() + '日 周' + weekdayLabels[now.getDay()]
  }

  private createGreeting(hour: number): string {
    if (hour >= 5 && hour < 11) {
      return '早上好，专注训练'
    }
    if (hour >= 11 && hour < 18) {
      return '下午好，专注训练'
    }
    return '晚上好，专注训练'
  }

  private async loadDynamicContent(context: Context): Promise<void> {
    const now: number = Date.now()
    const weeklyStats: WeeklyStats = await WorkoutSessionService.getWeeklyStats(context)
    const trainingDates: string[] = await WorkoutSessionService.getTrainingDates(context)
    this.weekDays = this.createWeekDayItems(trainingDates)
    this.weeklyTrainedCount = weeklyStats.count

    const goal: UserGoal | undefined = await GoalRepository.loadGoal(context)
    if (goal === undefined) {
      this.applyEmptyState()
      return
    }

    const plan: TrainingPlan = PlanEngine.generatePlan(goal)
    const daySeed: number = this.createDaySeed(goal.createdAt, now)
    const summary: HomePlanSummary = HomePlanService.createSummary(goal, plan, daySeed)
    const todayDay: PlanDay | undefined = HomePlanService.pickTodayDay(plan, daySeed)
    this.todayExerciseCount = summary.todayExerciseCount
    this.todayDurationMinutes = summary.sessionMinutes
    this.todayMuscleGroupCount = todayDay === undefined ? 0 : todayDay.focusMuscleIds.length
    this.weeklyPlannedDays = plan.days.length

    const sessions: WorkoutSession[] = await WorkoutSessionPersistenceBridgeService.loadPersistedSessions(context)
    const dashboard: StatsDashboardSummary = sessions.length === 0
      ? StatsDashboardService.createEmptySummary(now)
      : StatsDashboardService.createSummary(sessions, now)
    this.weeklyProgressPercent = this.createProgressPercent(dashboard.weeklyStats.sessionCount, this.weeklyPlannedDays)
  }

  private createDaySeed(goalCreatedAt: number, now: number): number {
    const dayCount: number = Math.floor((now - goalCreatedAt) / 86400000) + 1
    if (dayCount < 1) {
      return 1
    }
    return dayCount
  }

  private createProgressPercent(completed: number, planned: number): number {
    if (planned <= 0) {
      return 0
    }
    const percent: number = Math.round(completed * 100 / planned)
    if (percent > 100) {
      return 100
    }
    return percent
  }

  private createWeekDayItems(trainingDates: string[]): HomeWeekDayItem[] {
    const items: HomeWeekDayItem[] = []
    const now: Date = new Date()
    const dayOfWeek: number = now.getDay()
    const mondayOffset: number = dayOfWeek === 0 ? 6 : dayOfWeek - 1
    const monday: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate() - mondayOffset)
    const weekdayLabels: string[] = ['一', '二', '三', '四', '五', '六', '日']
    for (let index = 0; index < 7; index++) {
      const date: Date = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + index)
      const item: HomeWeekDayItem = {
        label: weekdayLabels[index],
        dateText: date.getDate().toString(),
        isTrained: this.containsTrainingDate(trainingDates, this.formatDateKey(date))
      }
      items.push(item)
    }
    return items
  }

  private containsTrainingDate(dates: string[], target: string): boolean {
    for (let index = 0; index < dates.length; index++) {
      if (dates[index] === target) {
        return true
      }
    }
    return false
  }

  private formatDateKey(date: Date): string {
    return date.getFullYear().toString() + '-' + this.padTwoDigits(date.getMonth() + 1) + '-' +
      this.padTwoDigits(date.getDate())
  }

  private padTwoDigits(value: number): string {
    if (value < 10) {
      return '0' + value.toString()
    }
    return value.toString()
  }

  private applyEmptyState(): void {
    this.weeklyProgressPercent = 0
    this.todayExerciseCount = 0
    this.todayDurationMinutes = 0
    this.todayMuscleGroupCount = 0
    this.weeklyPlannedDays = 0
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#0B0F13')
      Column() {
        Column() {
          Column() {
            Column({ space: 5.4 }) {
              Text(this.currentDateText)
                .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
                .fontSize(12.7)
                .fontColor('#B3FFFFFF')
                .fontWeight(FontWeight.Medium)
                .letterSpacing(0.127)
                .width('100%')
              Text(this.greetingText)
                .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
                .fontSize(36.3)
                .lineHeight(43.56)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F7FBF8')
                .width('100%')
            }
            Row()
              .height(19)
            this.todayCard()
            Row()
              .height(16)
            this.weekPanel()
          }
          .width('100%')
          .padding({
            left: 16,
            right: 16,
            top: Math.max(53 - this.topInsetVp, 0),
            bottom: 36
          })
        }
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean, currentRatio: number) => {
        if (isVisible) {
          const ctx: Context | undefined = this.getUIContext().getHostContext()
          if (ctx !== undefined) {
            this.loadDynamicContent(ctx)
          }
        }
      })
    }
    .width('100%')
    .height('100%')
  }
  @Builder
  private todayCard() {
    Column() {
      // 受光玻璃：原型 .today 的 `box-shadow: 0 1px 0 rgba(255,255,255,.05) inset` 顶部受光边。
      // ArkUI 的 .shadow() 不支持 inset，且渐变层的白段会被 1vp 卡边框盖住——改用卡内首个 1vp 高光行，
      // padding-top 由 20 改为 19 以保持总内边距不变。
      Row()
        .width('100%')
        .height(1)
        .backgroundColor('#0DFFFFFF')
      Row({ space: 14 }) {
        Column({ space: 8 }) {
          Text('\u4eca\u65e5\u8bad\u7ec3')
            .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
            .fontSize(12.7)
            .lineHeight(19)
            .fontWeight(FontWeight.Bold)
            .fontColor('#50ECA7')
            .letterSpacing(0.762)
          Row({ space: 8 }) {
            Text('\u4e0a\u80a2\u529b\u91cf')
              .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
              .fontSize(22)
              .lineHeight(24.64)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F7FBF8')
            Text('\u63a8\u8350')
              .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
              .fontSize(9)
              .lineHeight(10.8)
              .fontWeight(FontWeight.Bold)
              .letterSpacing(0.18)
              .fontColor('#50ECA7')
              .backgroundColor('#1F50ECA7')
              .border({ width: 1, color: '#2B50ECA7' })
              .borderRadius(999)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          }
          Text('\u80f8\u90e8 \u00b7 \u80a9\u90e8 \u00b7 \u4e09\u5934\u808c')
            .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
            .fontSize(12.7)
            .lineHeight(19)
            .fontColor('#9EFFFFFF')
          Row({ space: 7 }) {
            Stack({ alignContent: Alignment.Center }) {
              Circle({ width: 12, height: 12 })
                .fill('#1F50ECA7')
              Circle({ width: 6, height: 6 })
                .fill('#50ECA7')
            }
            .width(12)
            .height(12)
            Text('\u8bad\u7ec3\u65e5 \u00b7 \u5efa\u8bae\u5b8c\u6210')
              .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
              .fontSize(10.9)
              .lineHeight(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#8AFFFFFF')
          }
          // 原型 .today-id .day 是 margin-top:9px，而 .label/.title-row/.muscle 都是 8px；
          // 外层 Column space:8 统一了间距，这里补回这 1vp。
          .margin({ top: 1 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Stack({ alignContent: Alignment.Center }) {
          // 原型 .today-ring .outer 的 `filter: drop-shadow(0 0 9px rgba(80,236,167,.28))`：
          // 浏览器实测渲染不出可见光晕（环外沿起 12vp 内的像素恒等于卡片背景色 15,28,27）；
          // 而 ArkUI 的 .shadow() 会沿 96×96 矩形边界铺出方形光框。两者都不做，只保留环本身。
          Progress({ value: this.weeklyProgressPercent, total: 100, type: ProgressType.Ring })
            .width(96)
            .height(96)
            .color('#50ECA7')
            .backgroundColor('rgba(255,255,255,0.12)')
            .style({ strokeWidth: 7, enableSmoothEffect: true })
          Column()
            .width(78)
            .height(78)
            .borderRadius(39)
            // 受光玻璃：原型 .today-ring .inner 的 `radial-gradient(120% 120% at 50% 0%, rgba(255,255,255,.06), transparent 52%), var(--ring-inner)`——
            // 内圈顶部受光。小圆内用纵向线性渐变近似该径向顶光。
            .linearGradient({
              angle: 180,
              colors: [
                ['#0FFFFFFF', 0],
                ['#000D1117', 0.52],
                ['#0D1117', 1]
              ]
            })
            .border({ width: 1, color: '#17FFFFFF' })
            .shadow({ radius: 16, color: 'rgba(0,0,0,0.32)', offsetX: 0, offsetY: 6 })
          Column({ space: 2 }) {
            Text(this.weeklyProgressPercent.toString() + '%')
              .fontFamily(HomeContent.NUMBER_FONT_FAMILY)
              .fontSize(19)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F7FBF8')
              .letterSpacing(-0.38)
            Text('\u672c\u5468\u8fdb\u5ea6')
              .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
              .fontSize(9.5)
              .fontColor('#8AFFFFFF')
          }
          .alignItems(HorizontalAlign.Center)
        }
        .width(96)
        .height(96)
        .margin({ top: 4 })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Top)
      Row()
        .height(18)
      Row()
        .width('100%')
        .height(1)
        .linearGradient({ angle: 90, colors: [['#00FFFFFF', 0], ['#21FFFFFF', 0.5], ['#00FFFFFF', 1]] })
      Row()
        .height(16)
      Row({ space: 10 }) {
        this.metric('dumbbell', '\u52a8\u4f5c\u6570', this.todayExerciseCount.toString(), '\u4e2a\u52a8\u4f5c')
        this.metric('clock-3', '\u9884\u8ba1\u7528\u65f6', this.todayDurationMinutes.toString(), '\u5206\u949f')
        this.metric('target', '\u76ee\u6807\u808c\u7fa4', this.todayMuscleGroupCount.toString(), '\u4e2a\u808c\u7fa4')
      }
      .width('100%')
      Row()
        .height(16)
      Button('\u5f00\u59cb\u8bad\u7ec3')
        .width('100%')
        .height(40)
        .fontSize(13.6)
        .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
        .fontWeight(FontWeight.Bold)
        .fontColor('#08110D')
        .backgroundColor('#50ECA7')
        .borderRadius(20)
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.primaryPressed = true
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.primaryPressed = false
          }
        })
        .scale({ x: this.primaryPressed ? MotionTokens.PRESS_PRIMARY : 1, y: this.primaryPressed ? MotionTokens.PRESS_PRIMARY : 1 })
        .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
        .padding(0)
        .onClick(() => {
          this.getUIContext().getRouter().pushUrl({ url: AppRoutes.WORKOUT_PREVIEW })
        })
      Row()
        .height(8)
      Button('\u67e5\u770b\u9884\u89c8')
        .width('100%')
        .height(40)
        .fontSize(13.6)
        .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
        .fontWeight(FontWeight.Medium)
        .fontColor('#F7FBF8')
        .backgroundColor('#08FFFFFF')
        .borderRadius(20)
        .padding(0)
        .border({ width: 1, color: '#1AFFFFFF' })
        .onClick(() => {
          this.getUIContext().getRouter().pushUrl({ url: AppRoutes.WORKOUT_PREVIEW })
        })
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 19, bottom: 18 })
    .backgroundColor('#0F50ECA7')
    .borderRadius(26)
    .border({ width: 1, color: '#3850ECA7' })
    .shadow({ radius: 44, color: 'rgba(0,0,0,0.24)', offsetX: 0, offsetY: 22 })
  }

  @Builder
  private weekPanel() {
    Column() {
      Row() {
        Column({ space: 2 }) {
          Text('\u672c\u5468\u8282\u594f')
            .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
            .fontSize(14.5)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F7FBF8')
            .height(22)
          Text('\u5468\u4e00\u2014\u5468\u65e5')
            .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
            .fontSize(10)
            .fontColor('#66FFFFFF')
            .height(16)
        }
        Text(this.weeklyTrainedCount.toString() + ' / ' + this.weeklyPlannedDays.toString() + ' 次')
          .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor('#50ECA7')
          .height(20)
          .translate({ y: 2 })
      }
      .width('100%')
      .height(40)
      .justifyContent(FlexAlign.SpaceBetween)
      Row()
        .height(18)
      Row({ space: 7 }) {
        ForEach(this.weekDays, (item: HomeWeekDayItem) => {
          this.weekDay(item.label, item.dateText, item.isTrained)
        }, (item: HomeWeekDayItem) => item.dateText + '_' + item.label)
      }
      .width('100%')
      .height(78)
    }
    .width('100%')
    .height(168)
    .padding(16)
    .backgroundColor('#08FFFFFF')
    .borderRadius(27.2)
    .border({ width: 1, color: '#1AFFFFFF' })
    .shadow({ radius: 36, color: '#24000000', offsetX: 0, offsetY: 18 })
  }

  @Builder
  private metric(iconName: string, label: string, value: string, note: string) {
    Column({ space: 5 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (iconName === 'dumbbell') {
          // 原型 <symbol id="i-dumbbell">：5 条 1.8 描边的杠铃线段。
          // 不能用 .fillColor()——它连填充一起改成强调色，未显式 fill="none" 的 path 会被填成实心色块。
          Image($rawfile('pencil-home-metric-dumbbell.svg'))
            .width(20)
            .height(20)
        } else if (iconName === 'clock-3') {
          // 原型 <symbol id="i-clock">：r=8.5 描边圆 + 指针。
          Image($rawfile('pencil-home-metric-clock-3.svg'))
            .width(20)
            .height(20)
        } else {
          // 原型 <symbol id="i-target">：r=8.5 / 4.6 / 1.2 三同心圆，描边 1.8。
          // 24 viewBox 显示到 20vp → 外径 14.17vp、中径 7.67vp、线宽 1.5vp。
          Stack({ alignContent: Alignment.Center }) {
            Circle({ width: 14.17, height: 14.17 })
              .fill(Color.Transparent)
              .stroke('#50ECA7')
              .strokeWidth(1.5)
            Circle({ width: 7.67, height: 7.67 })
              .fill(Color.Transparent)
              .stroke('#50ECA7')
              .strokeWidth(1.5)
            Circle({ width: 2, height: 2 })
              .fill('#50ECA7')
          }
          .width(20)
          .height(20)
        }
      }
      .width(38)
      .height(38)
      .borderRadius(12)
      .backgroundColor('#1250ECA7')
      .border({ width: 1, color: '#1F50ECA7' })
      .margin({ bottom: 2 })
      Text(label)
        .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
        .fontSize(9.8)
        .fontColor('#9EFFFFFF')
        .width('100%')
        .height(15)
        .textAlign(TextAlign.Center)
      Text(value)
        .fontFamily(HomeContent.NUMBER_FONT_FAMILY)
        .fontSize(26)
        .lineHeight(26)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
        .letterSpacing(-0.52)
        .width('100%')
        .height(26)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(note)
        .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
        .fontSize(8.8)
        .fontColor('#8AFFFFFF')
        .width('100%')
        .height(15)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private weekDay(day: string, date: string, active: boolean) {
    Column({ space: 8 }) {
      Text(day)
        .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
        .fontSize(10)
        .fontWeight(600)
        .fontColor(active ? '#F7FBF8' : '#9EFFFFFF')
        .height(14)
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(34)
          .height(34)
          .borderRadius(17)
          .backgroundColor(active ? '#50ECA7' : '#0FFFFFFF')
          .border({ width: 1, color: active ? '#50ECA7' : '#14FFFFFF' })
          // 受光玻璃：原型 .week-day.active .dot 第一层 `0 0 0 4px var(--accent-12)` 外圈光晕
          .shadow({ radius: active ? 4 : 0, color: active ? '#1F50ECA7' : 'rgba(0,0,0,0)', offsetX: 0, offsetY: 0 })
          // 原型 .dot 的 `transition: background/border-color/box-shadow .18s ease`
          .animation({ duration: MotionTokens.DURATION_COLOR_BASE, curve: MotionTokens.EASE_MOTION })
        if (active) {
          // 原型 .dot::after：11×6 的 border-left+border-bottom 旋转 -45° 的对勾（2px 描边）。
          // 不用 ArkUI Path——其 commands 坐标此处按物理像素解释（width/height 却是 vp），
          // 在 3.38 密度下对勾只有 17×13px 且偏向左上、退化成黑块；改用 SVG 资源，尺寸随 vp 正确缩放。
          Image($rawfile('pencil-home-check.svg'))
            .width(13)
            .height(9)
        }
      }
      .width(34)
      .height(34)
      // 受光玻璃：原型 .week-day.active .dot 第二层 `0 5px 12px rgba(0,0,0,.24)` 下缘投影
      .shadow({
        radius: active ? 12 : 0,
        color: active ? '#3D000000' : 'rgba(0,0,0,0)',
        offsetX: 0,
        offsetY: active ? 5 : 0
      })
      Text(date)
        .fontFamily(HomeContent.NUMBER_FONT_FAMILY)
        .fontSize(10)
        .fontWeight(600)
        .fontColor(active ? '#50ECA7' : '#8AFFFFFF')
        .height(14)
    }
    .layoutWeight(1)
    .height(78)
    .alignItems(HorizontalAlign.Center)
  }
}

