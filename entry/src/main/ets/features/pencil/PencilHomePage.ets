/** PencilHomePage - FitTracker Home prototype page. Function #27 */
import { AppRoutes } from '../../app/AppRoutes'
import { MotionTokens } from '../../common/styles/DesignTokens'
import { Context } from '@kit.AbilityKit'
import { UserGoal, TrainingPlan, PlanDay, WorkoutSession } from '../../shared/models/TrainingModels'
import WorkoutSessionService, { WeeklyStats } from '../../common/services/WorkoutSessionService'
import StatsDashboardService, { StatsDashboardSummary } from '../../shared/services/StatsDashboardService'
import GoalRepository from '../../shared/services/GoalRepository'
import PlanEngine from '../../shared/services/PlanEngine'
import HomePlanService, { HomePlanSummary } from '../../shared/services/HomePlanService'
import WorkoutSessionPersistenceBridgeService from '../workout/services/WorkoutSessionPersistenceBridgeService'

interface HomeWeekDayItem {
  label: string
  dateText: string
  isTrained: boolean
}

@Component
export struct PencilHomeContent {
  private static readonly CHINESE_FONT_FAMILY: string = 'Noto Sans SC'
  private static readonly NUMBER_FONT_FAMILY: string = 'Inter'
  @State private primaryPressed: boolean = false
  @State private ghostPressed: boolean = false
  @State private currentDateText: string = ''
  @State private greetingText: string = ''
  @State private weeklyProgressPercent: number = 0
  @State private todayExerciseCount: number = 0
  @State private todayDurationMinutes: number = 0
  @State private todayMuscleGroupCount: number = 0
  @State private weeklyTrainedCount: number = 0
  @State private weeklyPlannedDays: number = 0
  @State private weekDays: HomeWeekDayItem[] = []

  async aboutToAppear(): Promise<void> {
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
        .linearGradient({
          angle: 180,
          colors: [['#0B0F13', 0], ['#0A0D12', 1]]
        })
      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: [70, 0],
          radius: 254,
          colors: [['#1F50ECA7', 0], ['#0050ECA7', 1]]
        })
      Column() {
        Column() {
          Column({ space: 6 }) {
            Text(this.currentDateText)
              .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
              .fontSize(14)
              .fontColor('#B3FFFFFF')
              .fontWeight(FontWeight.Medium)
              .width('100%')
            Text(this.greetingText)
              .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
              .fontSize(40)
              .lineHeight(39)
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
        .height('100%')
        .padding({
          left: 16,
          right: 16,
          top: 53,
          bottom: 40
        })
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
      Row({ space: 18 }) {
        Column({ space: 8 }) {
          Text('\u4eca\u65e5\u8bad\u7ec3')
            .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#50ECA7')
          Row({ space: 8 }) {
            Text('\u4e0a\u80a2\u529b\u91cf')
              .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F7FBF8')
            Text('\u63a8\u8350')
              .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
              .fontSize(10)
              .fontWeight(FontWeight.Bold)
              .fontColor('#50ECA7')
              .width(42)
              .height(18)
              .padding(0)
              .textAlign(TextAlign.Center)
          }
          Text('\u80f8\u90e8 \u00b7 \u80a9\u90e8 \u00b7 \u4e09\u5934\u808c')
            .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
            .fontSize(14)
            .fontColor('#9EFFFFFF')
          Text('\u8bad\u7ec3\u65e5 \u00b7 \u5efa\u8bae\u5b8c\u6210')
            .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#50ECA7')
            .width(160)
            .height(18)
            .padding(0)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Stack() {
          Column()
            .width(96)
            .height(96)
            .borderRadius(48)
            .border({ width: 5, color: '#50ECA7' })
          Column()
            .width(78)
            .height(78)
            .borderRadius(39)
            .backgroundColor('#0D1117')
            .border({ width: 1, color: '#66FFFFFF' })
          Column({ space: 2 }) {
            Text(this.weeklyProgressPercent.toString() + '%')
              .fontFamily(PencilHomeContent.NUMBER_FONT_FAMILY)
              .fontSize(18.1)
              .fontWeight(FontWeight.Bold)
              .fontColor('#50ECA7')
            Text('\u672c\u5468\u8fdb\u5ea6')
              .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
              .fontSize(10)
              .fontColor('#8AFFFFFF')
          }
          .alignItems(HorizontalAlign.Center)
        }
        .width(96)
        .height(96)
        .translate({ y: 6 })
      }
      .width('100%')
      .height(103)
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Top)
      Row()
        .height(16)
      Row()
        .width('100%')
        .height(1)
        .backgroundColor('#14FFFFFF')
      Row()
        .height(18)
      Row({ space: 5 }) {
        this.metric('dumbbell', '\u52a8\u4f5c\u6570', this.todayExerciseCount.toString(), '\u4e2a\u52a8\u4f5c')
        this.metric('clock-3', '\u9884\u8ba1\u7528\u65f6', this.todayDurationMinutes.toString(), '\u5206\u949f')
        this.metric('target', '\u76ee\u6807\u808c\u7fa4', this.todayMuscleGroupCount.toString(), '\u4e2a\u808c\u7fa4')
      }
      .width('100%')
      .height(96)
      Blank()
      Button('\u5f00\u59cb\u8bad\u7ec3')
        .width('100%')
        .height(40)
        .fontSize(15)
        .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
        .fontWeight(FontWeight.Bold)
        .fontColor('#08110D')
        .linearGradient({ angle: 90, colors: [['#47D994', 0], ['#53E7A5', 1]] })
        .borderRadius(22)
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
        .fontSize(15)
        .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
        .fontWeight(FontWeight.Medium)
        .fontColor('#F7FBF8')
        .backgroundColor('#08FFFFFF')
        .borderRadius(22)
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.ghostPressed = true
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.ghostPressed = false
          }
        })
        .scale({ x: this.ghostPressed ? MotionTokens.PRESS_SHORTCUT : 1, y: this.ghostPressed ? MotionTokens.PRESS_SHORTCUT : 1 })
        .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
        .padding(0)
        .border({ width: 1, color: '#10FFFFFF' })
        .onClick(() => {
          this.getUIContext().getRouter().pushUrl({ url: AppRoutes.WORKOUT_PREVIEW })
        })
    }
    .width('100%')
    .layoutWeight(1)
    .padding(18)
    .linearGradient({ angle: 180, colors: [['#0AFFFFFF', 0], ['#05FFFFFF', 1]] })
    .borderRadius(28)
    .border({ width: 1, color: '#10FFFFFF' })
    .shadow({ radius: 48, color: '#38000000', offsetX: 0, offsetY: 24 })
  }

  @Builder
  private weekPanel() {
    Column() {
      Row() {
        Column({ space: 2 }) {
          Text('\u672c\u5468\u8282\u594f')
            .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
            .fontSize(14.5)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F7FBF8')
            .height(22)
          Text('\u5468\u4e00\u2014\u5468\u65e5')
            .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
            .fontSize(10)
            .fontColor('#66FFFFFF')
            .height(16)
        }
        Text(this.weeklyTrainedCount.toString() + ' / ' + this.weeklyPlannedDays.toString() + ' 次')
          .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor('#50ECA7')
          .width(63)
          .height(20)
          .padding(0)
          .textAlign(TextAlign.Center)
          .translate({ y: 2 })
      }
      .width('100%')
      .height(40)
      .justifyContent(FlexAlign.SpaceBetween)
      Row()
        .height(18)
      Row({ space: 5 }) {
        ForEach(this.weekDays, (item: HomeWeekDayItem) => {
          this.weekDay(item.label, item.dateText, item.isTrained)
        }, (item: HomeWeekDayItem) => item.dateText + '_' + item.label)
      }
      .width(319)
      .height(62)
    }
    .width('100%')
    .height(152)
    .padding(16)
    .backgroundColor('#08FFFFFF')
    .borderRadius(27.2)
    .border({ width: 1, color: '#10FFFFFF' })
    .shadow({ radius: 36, color: '#24000000', offsetX: 0, offsetY: 18 })
  }

  @Builder
  private metric(iconName: string, label: string, value: string, note: string) {
    Column({ space: 4 }) {
      if (iconName === 'dumbbell') {
        Image($rawfile('pencil-home-metric-dumbbell.svg'))
          .width(22)
          .height(22)
          .fillColor('#50ECA7')
      } else if (iconName === 'clock-3') {
        Image($rawfile('pencil-home-metric-clock-3.svg'))
          .width(22)
          .height(22)
          .fillColor('#50ECA7')
      } else {
        Stack({ alignContent: Alignment.Center }) {
          Circle({ width: 22, height: 22 })
            .fill(Color.Transparent)
            .stroke('#50ECA7')
            .strokeWidth(1.7)
          Circle({ width: 12, height: 12 })
            .fill(Color.Transparent)
            .stroke('#50ECA7')
            .strokeWidth(1.7)
          Circle({ width: 3, height: 3 })
            .fill('#50ECA7')
        }
        .width(22)
        .height(22)
      }
      Text(label)
        .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
        .fontSize(9.8)
        .fontColor('#9EFFFFFF')
        .width('100%')
        .height(15)
        .textAlign(TextAlign.Center)
      Text(value)
        .fontFamily(PencilHomeContent.NUMBER_FONT_FAMILY)
        .fontSize(26)
        .lineHeight(26)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
        .width('100%')
        .height(26)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(note)
        .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
        .fontSize(8.8)
        .fontColor('#8AFFFFFF')
        .width('100%')
        .height(15)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .height(96)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private weekDay(day: string, date: string, active: boolean) {
    Column({ space: 3 }) {
      Text(day)
        .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
        .fontSize(9.5)
        .fontColor('#8AFFFFFF')
      Column()
        .width(28)
        .height(28)
        .backgroundColor(active ? '#50ECA7' : '#0FFFFFFF')
        .borderRadius(14)
        .border({ width: 1, color: active ? '#50ECA7' : '#14FFFFFF' })
      Text(date)
        .fontFamily(PencilHomeContent.NUMBER_FONT_FAMILY)
        .fontSize(9)
        .fontColor(active ? '#50ECA7' : '#66FFFFFF')
    }
    .layoutWeight(1)
    .height(62)
    .alignItems(HorizontalAlign.Center)
  }
}

@Entry
@Component
struct PencilHomePage {
  aboutToAppear(): void {
    this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.APP_SHELL })
  }

  build() {
    Column() {
      PencilHomeContent()
    }
    .width('100%')
    .height('100%')
  }
}
