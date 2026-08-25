/** PencilReviewPage - FitTracker review prototype page. */

import { MotionTokens } from '../../common/styles/DesignTokens'
import WorkoutSessionService, {
  SavedExercise,
  SavedSet,
  WorkoutSession as LegacyWorkoutSession
} from '../../common/services/WorkoutSessionService'
import ReviewDashboardService, { ReviewDashboardSummary } from '../../shared/services/ReviewDashboardService'
import ReviewInsightsService, { ReviewWeeklyTrendItem } from '../../shared/services/ReviewInsightsService'
import WorkoutSessionPersistenceBridgeService from '../workout/services/WorkoutSessionPersistenceBridgeService'
import { WorkoutSession, WorkoutSet } from '../../shared/models/TrainingModels'

interface ReviewBarItem {
  label: string
  height: number
  active: boolean
}

interface DistributionItem {
  label: string
  percent: number
  value: string
}

interface MuscleAggregate {
  label: string
  sets: number
}

const WEEKDAY_LABELS: string[] = ['一', '二', '三', '四', '五', '六', '日']

@Component
export struct PencilReviewContent {
  @State private timeScale: string = 'week'
  @State private segKey: string = ''
  @State private summary: ReviewDashboardSummary = ReviewDashboardService.createEmptySummary()
  @State private weekBars: ReviewBarItem[] = []
  @State private distributionItems: DistributionItem[] = []
  @State private trendItems: ReviewWeeklyTrendItem[] = []
  @State private monthLabel: string = ''
  @State private monthBadge: string = ''
  @State private weekRangeText: string = ''
  @State private trainDays: number[] = []
  @State private calendarDays: number[] = []
  @State private todayDay: number = -1
  @State private monthSessionCount: number = 0
  @State private monthDurationMinutes: number = 0

  async aboutToAppear(): Promise<void> {
    const now: number = Date.now()
    this.initCalendarShell(now)
    const context = this.getUIContext().getHostContext()
    if (context === undefined) {
      this.applyEmptyState()
      return
    }
    try {
      const legacySessions: LegacyWorkoutSession[] = await WorkoutSessionService.getSessions(context)
      const sessions: WorkoutSession[] = await WorkoutSessionPersistenceBridgeService.loadPersistedSessions(context)
      if (sessions.length === 0) {
        this.summary = ReviewDashboardService.createEmptySummary()
      } else {
        this.summary = ReviewDashboardService.createSummary(sessions)
      }
      this.trendItems = ReviewInsightsService.createWeeklyTrendItems(sessions, now)
      this.weekBars = this.buildWeekBars(sessions, now)
      this.distributionItems = this.buildDistribution(legacySessions, now)
      this.initCalendarData(sessions, now)
    } catch (error) {
      this.applyEmptyState()
    }
  }

  private applyEmptyState(): void {
    this.summary = ReviewDashboardService.createEmptySummary()
    this.trendItems = []
    this.weekBars = []
    this.distributionItems = []
    this.trainDays = []
    this.monthSessionCount = 0
    this.monthDurationMinutes = 0
  }

  private initCalendarShell(now: number): void {
    const date: Date = new Date(now)
    const year: number = date.getFullYear()
    const month: number = date.getMonth()
    this.monthLabel = year.toString() + ' 年 ' + (month + 1).toString() + ' 月'
    this.monthBadge = '本月 · ' + (month + 1).toString() + '月'
    this.weekRangeText = this.formatWeekRange(now)
    this.todayDay = date.getDate()
    const daysInMonth: number = new Date(year, month + 1, 0).getDate()
    const days: number[] = []
    for (let day = 1; day <= daysInMonth; day++) {
      days.push(day)
    }
    this.calendarDays = days
  }

  private initCalendarData(sessions: WorkoutSession[], now: number): void {
    const date: Date = new Date(now)
    const year: number = date.getFullYear()
    const month: number = date.getMonth()
    const trainDays: number[] = []
    let sessionCount: number = 0
    let durationSeconds: number = 0
    for (let index = 0; index < sessions.length; index++) {
      const sessionDate: Date = new Date(sessions[index].startedAt)
      if (sessionDate.getFullYear() !== year || sessionDate.getMonth() !== month) {
        continue
      }
      sessionCount++
      durationSeconds += sessions[index].durationSeconds
      const day: number = sessionDate.getDate()
      if (!this.containsDay(trainDays, day)) {
        trainDays.push(day)
      }
    }
    this.trainDays = trainDays
    this.monthSessionCount = sessionCount
    this.monthDurationMinutes = Math.round(durationSeconds / 60)
  }

  private containsDay(days: number[], target: number): boolean {
    for (let index = 0; index < days.length; index++) {
      if (days[index] === target) {
        return true
      }
    }
    return false
  }

  private formatWeekRange(now: number): string {
    const date: Date = new Date(now)
    const dayOfWeek: number = date.getDay()
    const mondayOffset: number = dayOfWeek === 0 ? 6 : dayOfWeek - 1
    const monday: Date = new Date(date.getFullYear(), date.getMonth(), date.getDate() - mondayOffset)
    const sunday: Date = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + 6)
    const mondayText: string = (monday.getMonth() + 1).toString() + '月' + monday.getDate().toString() + '日'
    const sundayText: string = (sunday.getMonth() + 1).toString() + '月' + sunday.getDate().toString() + '日'
    return mondayText + '–' + sundayText
  }

  private buildWeekBars(sessions: WorkoutSession[], now: number): ReviewBarItem[] {
    const date: Date = new Date(now)
    const dayOfWeek: number = date.getDay()
    const mondayOffset: number = dayOfWeek === 0 ? 6 : dayOfWeek - 1
    const monday: Date = new Date(date.getFullYear(), date.getMonth(), date.getDate() - mondayOffset)
    const setsPerDay: number[] = []
    let maxSets: number = 0
    for (let dayIndex = 0; dayIndex < 7; dayIndex++) {
      const dayStart: number = new Date(
        monday.getFullYear(), monday.getMonth(), monday.getDate() + dayIndex
      ).getTime()
      const dayEnd: number = dayStart + 24 * 60 * 60 * 1000
      let daySets: number = 0
      for (let sessionIndex = 0; sessionIndex < sessions.length; sessionIndex++) {
        const startedAt: number = sessions[sessionIndex].startedAt
        if (startedAt >= dayStart && startedAt < dayEnd) {
          daySets += this.countWorkingSets(sessions[sessionIndex])
        }
      }
      setsPerDay.push(daySets)
      if (daySets > maxSets) {
        maxSets = daySets
      }
    }
    const bars: ReviewBarItem[] = []
    for (let index = 0; index < 7; index++) {
      let height: number = 6
      if (maxSets > 0 && setsPerDay[index] > 0) {
        height = 12 + (setsPerDay[index] / maxSets) * 93
      }
      const bar: ReviewBarItem = {
        label: WEEKDAY_LABELS[index],
        height: height,
        active: setsPerDay[index] > 0
      }
      bars.push(bar)
    }
    return bars
  }

  private countWorkingSets(session: WorkoutSession): number {
    let count: number = 0
    for (let index = 0; index < session.sets.length; index++) {
      const set: WorkoutSet = session.sets[index]
      if (set.weight > 0 && set.reps > 0 && !set.isWarmup) {
        count++
      }
    }
    return count
  }

  private buildDistribution(legacySessions: LegacyWorkoutSession[], now: number): DistributionItem[] {
    const windowStart: number = now - 30 * 24 * 60 * 60 * 1000
    const muscleSets: Map<string, number> = new Map<string, number>()
    for (let sessionIndex = 0; sessionIndex < legacySessions.length; sessionIndex++) {
      const session: LegacyWorkoutSession = legacySessions[sessionIndex]
      if (session.startTime < windowStart) {
        continue
      }
      for (let exerciseIndex = 0; exerciseIndex < session.exercises.length; exerciseIndex++) {
        const exercise: SavedExercise = session.exercises[exerciseIndex]
        if (exercise.targetMuscle.length === 0) {
          continue
        }
        let workingSets: number = 0
        for (let setIndex = 0; setIndex < exercise.sets.length; setIndex++) {
          const set: SavedSet = exercise.sets[setIndex]
          if (set.weight > 0 && set.reps > 0 && !set.isWarmup) {
            workingSets++
          }
        }
        if (workingSets === 0) {
          continue
        }
        const previous: number | undefined = muscleSets.get(exercise.targetMuscle)
        let total: number = workingSets
        if (previous !== undefined) {
          total = previous + workingSets
        }
        muscleSets.set(exercise.targetMuscle, total)
      }
    }

    const aggregates: MuscleAggregate[] = []
    let totalSets: number = 0
    muscleSets.forEach((value: number, key: string) => {
      const aggregate: MuscleAggregate = {
        label: key,
        sets: value
      }
      aggregates.push(aggregate)
      totalSets += value
    })
    aggregates.sort((first: MuscleAggregate, second: MuscleAggregate) => second.sets - first.sets)

    const items: DistributionItem[] = []
    const limit: number = aggregates.length < 4 ? aggregates.length : 4
    for (let index = 0; index < limit; index++) {
      const percent: number = totalSets > 0 ? Math.round((aggregates[index].sets / totalSets) * 100) : 0
      const item: DistributionItem = {
        label: aggregates[index].label,
        percent: percent,
        value: aggregates[index].sets.toString() + ' 组'
      }
      items.push(item)
    }
    return items
  }

  private isTrainDay(day: number): boolean {
    return this.containsDay(this.trainDays, day)
  }

  private weekText(): string {
    if (this.timeScale === 'month') {
      return this.monthBadge
    }
    return '本周 · ' + this.weekRangeText
  }

  private badgeText(): string {
    if (!this.summary.hasSessions) {
      return '待积累'
    }
    if (!this.summary.trendSummary.hasTrend) {
      return '首次复盘'
    }
    const delta: number = this.summary.trendSummary.recentCompletionRate -
      this.summary.trendSummary.previousCompletionRate
    if (delta > 0) {
      return '↑ +' + delta.toString() + '%'
    }
    if (delta < 0) {
      return '↓ -' + Math.abs(delta).toString() + '%'
    }
    return '— 持平'
  }

  private headlineText(): string {
    if (!this.summary.hasSessions) {
      return '完成一次训练，开始你的复盘。'
    }
    if (this.summary.trendSummary.hasTrend) {
      return this.summary.trendSummary.summaryText
    }
    return '状态不错，继续保持。'
  }

  private descriptionText(): string {
    if (!this.summary.hasSessions) {
      return '完成第一次训练后，这里会汇总训练次数、时长与完成率。'
    }
    if (this.timeScale === 'month') {
      return '本月已完成 ' + this.monthSessionCount.toString() + ' 次训练，平均每周 ' +
        this.monthWeeklyAverage() + ' 次，累计训练 ' + this.monthDurationMinutes.toString() + ' 分钟。'
    }
    if (this.trendItems.length > 0) {
      return this.trendItems[0].summaryText
    }
    return '继续按计划训练，保持稳定节奏。'
  }

  private monthWeeklyAverage(): string {
    const date: Date = new Date()
    const dayOfMonth: number = date.getDate()
    const elapsedWeeks: number = Math.max(1, Math.ceil(dayOfMonth / 7))
    const average: number = Math.round((this.monthSessionCount / elapsedWeeks) * 10) / 10
    return average.toString()
  }

  private statValue(index: number): string {
    if (index === 0) {
      return this.summary.sessionCount.toString()
    }
    if (index === 1) {
      return Math.round(this.summary.totalDurationSeconds / 60).toString()
    }
    return this.summary.averageCompletionRate.toString()
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [['#0B0F13', 0], ['#0D1117', 0.52], ['#0A0D12', 1]]
        })

      Column() {
        Column() {
          this.segmentedControl()
        }
        .width('100%')
        .padding({ left: 16.3, right: 16.3, top: 24, bottom: 8 })

        Column({ space: 10 }) {
          this.overviewCard()
          this.statsRow()
          this.activityCard()
          if (this.timeScale === 'week') {
            this.distributionCard()
          }
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16.3, right: 16.3, top: 8, bottom: 16 })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0B0F13')
  }

  @Builder
  private segmentedControl() {
    Row() {
      Row() {
        this.segmentButton('周', 'week')
        this.segmentButton('月', 'month')
      }
      .padding(2)
      .backgroundColor('#0CFFFFFF')
      .borderRadius(999)
      .border({ width: 1, color: '#1AFFFFFF' })
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  private segmentButton(label: string, key: string) {
    Text(label)
      .fontFamily('Noto Sans SC')
      .fontSize(13)
      .fontWeight(this.timeScale === key ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(this.timeScale === key ? '#07100B' : '#9EFFFFFF')
      .width(53)
      .height(34)
      .textAlign(TextAlign.Center)
      .backgroundColor(this.timeScale === key ? '#50ECA7' : '#00000000')
      .borderRadius(999)
      .onClick(() => {
        this.timeScale = key
      })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.segKey = key
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.segKey = ''
        }
      })
      .scale({ x: this.segKey === key ? MotionTokens.PRESS_SEGMENT : 1, y: this.segKey === key ? MotionTokens.PRESS_SEGMENT : 1 })
      .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
  }

  @Builder
  private overviewCard() {
    Column({ space: 8 }) {
      Row() {
        Text(this.weekText())
          .fontFamily('Noto Sans SC')
          .fontSize(12.7)
          .fontWeight(FontWeight.Medium)
          .fontColor('#B3FFFFFF')
        Text(this.badgeText())
          .fontFamily('Inter')
          .fontSize(10.9)
          .fontWeight(FontWeight.Medium)
          .fontColor('#50ECA7')
          .padding({ left: 9.1, right: 9.1, top: 5.4, bottom: 5.4 })
          .backgroundColor('#1A50ECA7')
          .borderRadius(999)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Text(this.headlineText())
        .fontFamily('Noto Sans SC')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
        .width('100%')

      Text(this.descriptionText())
        .fontFamily('Noto Sans SC')
        .fontSize(11.8)
        .lineHeight(15.9)
        .fontColor('#7AFFFFFF')
        .width('100%')
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#08FFFFFF')
    .borderRadius(25.4)
    .border({ width: 1, color: '#10FFFFFF' })
  }

  @Builder
  private statsRow() {
    Row({ space: 9.1 }) {
      this.statCard('训练', '次', 0)
      this.statCard('时长', '分钟', 1)
      this.statCard('完成率', '%', 2)
    }
    .width('100%')
    .height(64)
  }

  @Builder
  private statCard(label: string, unit: string, index: number) {
    Column({ space: 4.5 }) {
      Text(label)
        .fontFamily('Noto Sans SC')
        .fontSize(10.9)
        .fontColor('#7AFFFFFF')
      Row({ space: 3.6 }) {
        Text(this.statValue(index))
          .fontFamily('Geist Mono')
          .fontSize(21.8)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text(unit)
          .fontFamily('Noto Sans SC')
          .fontSize(10.9)
          .fontColor('#50ECA7')
      }
    }
    .layoutWeight(1)
    .height(64)
    .padding(10)
    .backgroundColor('#171D24')
    .borderRadius(18.1)
    .border({ width: 1, color: '#0AFFFFFF' })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private activityCard() {
    Column({ space: 10 }) {
      Row() {
        Text('训练节奏')
          .fontFamily('Noto Sans SC')
          .fontSize(14.5)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text(this.timeScale === 'week' ? '过去 7 天' : '按月查看')
          .fontFamily('Noto Sans SC')
          .fontSize(10.9)
          .fontColor('#7AFFFFFF')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      if (this.timeScale === 'week') {
        Row({ space: 9.1 }) {
          ForEach(this.weekBars, (bar: ReviewBarItem) => {
            Column({ space: 7.3 }) {
              Row()
                .width('100%')
                .height(bar.height)
                .backgroundColor(bar.active ? '#50ECA7' : '#3350ECA7')
                .borderRadius(9.1)
              Text(bar.label)
                .fontFamily('Noto Sans SC')
                .fontSize(10)
                .fontColor(bar.active ? '#50ECA7' : '#8AFFFFFF')
            }
            .layoutWeight(1)
            .height('100%')
            .justifyContent(FlexAlign.End)
            .alignItems(HorizontalAlign.Center)
          }, (bar: ReviewBarItem) => bar.label)
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(VerticalAlign.Bottom)
      } else {
        this.calendarView()
      }
    }
    .width('100%')
    .layoutWeight(1)
    .padding(12)
    .backgroundColor('#07FFFFFF')
    .borderRadius(25.4)
    .border({ width: 1, color: '#14FFFFFF' })
  }

  @Builder
  private calendarView() {
    Column({ space: 10 }) {
      Row() {
        Text(this.monthLabel)
          .fontFamily('Noto Sans SC')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text('训练 ' + this.trainDays.length.toString() + ' 天')
          .fontFamily('Noto Sans SC')
          .fontSize(10.9)
          .fontColor('#7AFFFFFF')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Row() {
        ForEach(WEEKDAY_LABELS, (day: string) => {
          Text(day)
            .fontFamily('Noto Sans SC')
            .fontSize(10.5)
            .fontColor('#7AFFFFFF')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
        }, (day: string) => day)
      }
      .width('100%')

      Grid() {
        ForEach(this.calendarDays, (day: number) => {
          GridItem() {
            Column({ space: 2 }) {
              Text(day.toString())
                .fontFamily('Inter')
                .fontSize(12.5)
                .fontWeight(this.isTrainDay(day) ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(day === this.todayDay ? '#07100B' : (this.isTrainDay(day) ? '#50ECA7' : '#B3FFFFFF'))
              Row()
                .width(5)
                .height(5)
                .backgroundColor(day === this.todayDay ? '#07100B' : (this.isTrainDay(day) ? '#50ECA7' : '#00000000'))
                .borderRadius(2.5)
            }
            .width('100%')
            .height(36)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .backgroundColor(day === this.todayDay ? '#50ECA7' : (this.isTrainDay(day) ? '#1A50ECA7' : '#00000000'))
            .borderRadius(10)
            .border({ width: 1, color: this.isTrainDay(day) ? '#4250ECA7' : '#00000000' })
          }
        }, (day: number) => day.toString())
      }
      .width('100%')
      .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')
      .columnsGap(4)
      .rowsGap(4)
    }
    .width('100%')
  }

  @Builder
  private distributionCard() {
    Column({ space: 8 }) {
      Row() {
        Text('部位训练分布')
          .fontFamily('Noto Sans SC')
          .fontSize(14.5)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text('近 30 天 · 累计组数')
          .fontFamily('Noto Sans SC')
          .fontSize(10.9)
          .fontColor('#7AFFFFFF')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      if (this.distributionItems.length === 0) {
        Text('完成训练后生成部位分布。')
          .fontFamily('Noto Sans SC')
          .fontSize(11.8)
          .fontColor('#7AFFFFFF')
          .width('100%')
      } else {
        ForEach(this.distributionItems, (item: DistributionItem) => {
          Row({ space: 10 }) {
            Text(item.label)
              .fontFamily('Noto Sans SC')
              .fontSize(11.8)
              .fontColor('#B3FFFFFF')
              .width(44)
            Stack({ alignContent: Alignment.Start }) {
              Row()
                .width('100%')
                .height(6)
                .backgroundColor('#14FFFFFF')
                .borderRadius(999)
              Row()
                .width(item.percent.toString() + '%')
                .height(6)
                .backgroundColor('#50ECA7')
                .borderRadius(999)
            }
            .layoutWeight(1)
            .height(6)
            Text(item.value)
              .fontFamily('Geist Mono')
              .fontSize(11.8)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F7FBF8')
              .width(44)
              .textAlign(TextAlign.End)
          }
          .width('100%')
        }, (item: DistributionItem) => item.label)
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#08FFFFFF')
    .borderRadius(25.4)
    .border({ width: 1, color: '#1AFFFFFF' })
  }
}

@Entry
@Component
struct PencilReviewPage {
  build() {
    Column() {
      PencilReviewContent()
    }
  }
}
