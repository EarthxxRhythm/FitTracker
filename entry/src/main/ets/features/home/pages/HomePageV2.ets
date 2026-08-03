/**
 * HomePageV2 —— FitTracker Home 的 ArkUI 落地页，按 design.pen 当前设计实现。
 * 功能 #home-redesign
 */
import { Context } from '@kit.AbilityKit'
import { AppRoutes } from '../../../app/AppRoutes'
import TrainingPlanService, { UserPlan } from '../../../common/services/TrainingPlanService'
import WorkoutDraftService from '../../../common/services/WorkoutDraftService'
import {
  ColorTokens,
  RadiusTokens,
  ShadowTokens
} from '../../../common/styles/DesignTokens'
import { TrainingPlan, UserGoal } from '../../../shared/models/TrainingModels'
import GoalRepository from '../../../shared/services/GoalRepository'
import HomePlanService from '../../../shared/services/HomePlanService'
import PlanEngine from '../../../shared/services/PlanEngine'
import HomeDashboardService, {
  HomeDashboardBoundaryItem,
  HomeDashboardMetric,
  HomeDashboardViewModel,
  HomeDashboardWeekItem
} from '../services/HomeDashboardService'
import HomeResumeService from '../services/HomeResumeService'

interface HomeNavItem {
  itemId: string
  label: string
  route: string
  selected: boolean
  iconType: string
}

function createHomeNavItem(
  itemId: string,
  label: string,
  route: string,
  selected: boolean,
  iconType: string
): HomeNavItem {
  return {
    itemId: itemId,
    label: label,
    route: itemId === 'profile' ? AppRoutes.PROFILE : route,
    selected: selected,
    iconType: iconType
  }
}

const HOME_NAV_ITEMS: HomeNavItem[] = [
  createHomeNavItem('home', '首页', AppRoutes.HOME, false, 'none'),
  createHomeNavItem('plan', '计划', AppRoutes.TRAINING_PLAN_DETAIL, false, 'none'),
  createHomeNavItem('train', '训练', AppRoutes.ACTIVE_WORKOUT, true, 'train'),
  createHomeNavItem('review', '回顾', AppRoutes.REVIEW_HOME, false, 'none'),
  createHomeNavItem('profile', '我的', '', false, 'none')
]

@Entry
@Component
struct HomePageV2 {
  @State loading: boolean = true
  @State viewModel: HomeDashboardViewModel = HomeDashboardService.createLoadingViewModel(new Date())

  private getHostContextOrNull(): Context | null {
    const hostContext = this.getUIContext().getHostContext()
    if (hostContext === undefined || hostContext === null) {
      return null
    }
    return hostContext as Context
  }

  async aboutToAppear(): Promise<void> {
    await this.loadPage()
  }

  private async loadPage(): Promise<void> {
    const now: Date = new Date()
    this.loading = true
    this.viewModel = HomeDashboardService.createLoadingViewModel(now)
    try {
      const context: Context | null = this.getHostContextOrNull()
      if (context === null) {
        this.viewModel = HomeDashboardService.createNoGoalViewModel(now)
        this.loading = false
        return
      }

      const resumePresentation = HomeResumeService.createPresentation(await WorkoutDraftService.getDraft(context))
      const currentPlan: UserPlan | null = await TrainingPlanService.getCurrentPlan(context)
      if (currentPlan !== null) {
        this.viewModel = HomeDashboardService.createReadyViewModel(
          HomePlanService.createSummaryFromCurrentPlan(
            currentPlan,
            TrainingPlanService.getTodayLabel(),
            TrainingPlanService.getTodayTraining(currentPlan)
          ),
          resumePresentation.hasRecoverableDraft,
          resumePresentation.summaryText,
          now
        )
        this.loading = false
        return
      }

      const goal: UserGoal | undefined = await GoalRepository.loadGoal(context)
      if (goal === undefined) {
        this.viewModel = HomeDashboardService.createNoGoalViewModel(now)
        this.loading = false
        return
      }

      const generatedPlan: TrainingPlan = PlanEngine.generatePlan(goal)
      this.viewModel = HomeDashboardService.createReadyViewModel(
        HomePlanService.createSummary(goal, generatedPlan, this.getTodaySeed()),
        resumePresentation.hasRecoverableDraft,
        resumePresentation.summaryText,
        now
      )
    } catch (error) {
      this.viewModel = HomeDashboardService.createNoGoalViewModel(now)
    }
    this.loading = false
  }

  private getTodaySeed(): number {
    const today: Date = new Date()
    const day: number = today.getDay()
    if (day === 0) {
      return 7
    }
    return day
  }

  private openRoute(route: string): void {
    if (route.length === 0) {
      return
    }
    try {
      this.getUIContext().getRouter().pushUrl({ url: route })
    } catch (error) {
    }
  }

  private replaceRoute(route: string): void {
    if (route.length === 0) {
      return
    }
    try {
      this.getUIContext().getRouter().replaceUrl({ url: route })
    } catch (error) {
    }
  }

  private getHeaderTitle(): string {
    if (this.loading) {
      return '早上好，专注训练'
    }
    if (!this.viewModel.hasGoal) {
      return '先定目标，再开始训练'
    }
    if (this.viewModel.primaryActionRoute === AppRoutes.ACTIVE_WORKOUT) {
      return '继续上次训练'
    }
    return this.viewModel.greetingText
  }

  private getHeroMuscleText(): string {
    if (!this.viewModel.hasGoal) {
      return '先完成目标设置，首页会自动整理今天的训练重点。'
    }
    if (this.viewModel.heroSubtitle.length > 0) {
      return this.viewModel.heroSubtitle
    }
    return '今日训练已准备就绪'
  }

  private getHeroTagText(): string {
    if (!this.viewModel.hasGoal) {
      return '待开始'
    }
    if (this.viewModel.primaryActionRoute === AppRoutes.ACTIVE_WORKOUT) {
      return '恢复中'
    }
    return '推荐'
  }

  private getHeroTagFillColor(): string {
    if (!this.viewModel.hasGoal) {
      return 'rgba(181,152,105,0.14)'
    }
    if (this.viewModel.primaryActionRoute === AppRoutes.ACTIVE_WORKOUT) {
      return 'rgba(255,255,255,0.10)'
    }
    return 'rgba(80,236,167,0.10)'
  }

  private getHeroTagTextColor(): string {
    if (!this.viewModel.hasGoal) {
      return ColorTokens.WARNING
    }
    if (this.viewModel.primaryActionRoute === AppRoutes.ACTIVE_WORKOUT) {
      return ColorTokens.TEXT_ON_DARK
    }
    return ColorTokens.ACCENT_PRIMARY
  }

  private getStatusBackgroundColor(): string {
    if (this.viewModel.statusTone === 'warning') {
      return ColorTokens.WARNING_BG
    }
    if (this.viewModel.statusTone === 'success') {
      return 'rgba(80,236,167,0.10)'
    }
    if (this.viewModel.statusTone === 'info') {
      return ColorTokens.INFO_BG
    }
    return ColorTokens.SURFACE_GLASS
  }

  private getStatusBorderColor(): string {
    if (this.viewModel.statusTone === 'warning') {
      return ColorTokens.STATE_WARN_BORDER
    }
    if (this.viewModel.statusTone === 'success') {
      return ColorTokens.STATE_SUCCESS_BORDER
    }
    if (this.viewModel.statusTone === 'info') {
      return ColorTokens.BORDER_GLASS
    }
    return ColorTokens.BORDER_GLASS
  }

  private getWeekDateText(): string {
    const now: Date = new Date()
    const weekday: number = now.getDay() === 0 ? 7 : now.getDay()
    const start: Date = new Date(now.getTime())
    start.setDate(now.getDate() - weekday + 1)
    const end: Date = new Date(start.getTime())
    end.setDate(start.getDate() + 6)
    return (start.getMonth() + 1).toString() + '/' + start.getDate().toString() + ' - ' +
      (end.getMonth() + 1).toString() + '/' + end.getDate().toString()
  }

  private getProgressCurrent(): number {
    const text: string = this.viewModel.progressText
    const slashIndex: number = text.indexOf('/')
    if (slashIndex <= 0) {
      return 0
    }
    const currentText: string = text.substring(0, slashIndex)
    const value: number = Number(currentText)
    if (isNaN(value)) {
      return 0
    }
    return value
  }

  private getProgressTotal(): number {
    const text: string = this.viewModel.progressText
    const slashIndex: number = text.indexOf('/')
    if (slashIndex < 0 || slashIndex >= text.length - 1) {
      if (this.viewModel.weeklyItems.length > 0) {
        return this.viewModel.weeklyItems.length
      }
      return 1
    }
    const totalText: string = text.substring(slashIndex + 1)
    const value: number = Number(totalText)
    if (isNaN(value) || value <= 0) {
      if (this.viewModel.weeklyItems.length > 0) {
        return this.viewModel.weeklyItems.length
      }
      return 1
    }
    return value
  }

  private getProgressPercent(): number {
    const total: number = this.getProgressTotal()
    if (total <= 0) {
      return 0
    }
    return this.getProgressCurrent() * 100 / total
  }

  private getProgressHighlightOpacity(): number {
    const percent: number = this.getProgressPercent()
    if (percent >= 75) {
      return 1
    }
    if (percent >= 50) {
      return 0.82
    }
    if (percent >= 25) {
      return 0.68
    }
    return 0.52
  }

  private getWeekProgressWidth(): string {
    const width: number = 358 * this.getProgressPercent() / 100
    return width.toString()
  }

  private getWeekFooterLeft(): string {
    const completedCount: number = this.getCompletedWeekItemCount()
    const total: number = this.getWeekTargetCount()
    return '已完成 ' + completedCount.toString() + ' / ' + total.toString() + ' 次训练'
  }

  private getWeekFooterRight(): string {
    const remainingCount: number = this.getWeekTargetCount() - this.getCompletedWeekItemCount()
    if (remainingCount <= 0) {
      return '本周已完成'
    }
    return '剩余 ' + remainingCount.toString() + ' 次待完成'
  }

  private getWeekTargetCount(): number {
    const total: number = this.getProgressTotal()
    if (total > 0) {
      return total
    }
    if (this.viewModel.weeklyItems.length > 0) {
      return this.viewModel.weeklyItems.length
    }
    return 1
  }

  private getCompletedWeekItemCount(): number {
    let count: number = 0
    let index: number = 0
    while (index < this.viewModel.weeklyItems.length) {
      const item: HomeDashboardWeekItem = this.viewModel.weeklyItems[index]
      if (item.completed) {
        count += 1
      }
      index += 1
    }
    return count
  }

  private getMetricLabel(item: HomeDashboardMetric, index: number): string {
    if (this.loading && index === 2) {
      return '同步状态'
    }
    return item.label
  }

  private getMetricValueColor(index: number): string {
    if (index === 2) {
      return ColorTokens.ACCENT_PRIMARY
    }
    return ColorTokens.TEXT_ON_DARK
  }

  private getMetricValueSize(item: HomeDashboardMetric, index: number): number {
    if (index === 2 || item.value.length > 4) {
      return 20
    }
    return 30
  }

  private getMetricValueLineHeight(item: HomeDashboardMetric, index: number): number {
    if (index === 2 || item.value.length > 4) {
      return 22
    }
    return 28
  }

  private getBoundaryValueColor(item: HomeDashboardBoundaryItem): string {
    if (item.itemId === 'restriction') {
      return '#FFD7C5'
    }
    return ColorTokens.TEXT_ON_DARK
  }

  private getBoundaryHint(item: HomeDashboardBoundaryItem): string {
    if (item.itemId === 'goal') {
      return '训练优先级'
    }
    if (item.itemId === 'equipment') {
      return '可用环境'
    }
    return '动作约束'
  }

  private getBoundaryStatusText(): string {
    if (this.viewModel.hasGoal) {
      return '当前生效'
    }
    return '等待设置'
  }

  private getWeekItemLabel(item: HomeDashboardWeekItem): string {
    const text: string = item.title
    if (text.length > 0) {
      return text.substring(0, 1)
    }
    return '练'
  }

  private getWeekItemDate(item: HomeDashboardWeekItem): string {
    const text: string = item.subtitle
    if (text.length === 0) {
      return '--'
    }
    return text
  }

  private getWeekCellFill(item: HomeDashboardWeekItem): string {
    if (item.completed) {
      return 'rgba(80,236,167,0.10)'
    }
    if (item.current) {
      return 'rgba(255,255,255,0.04)'
    }
    return 'rgba(255,255,255,0.03)'
  }

  private getWeekCellStroke(item: HomeDashboardWeekItem): string {
    if (item.completed) {
      return 'rgba(80,236,167,0.10)'
    }
    return 'rgba(255,255,255,0.04)'
  }

  private getWeekMarkFill(item: HomeDashboardWeekItem): string {
    if (item.completed) {
      return ColorTokens.ACCENT_PRIMARY
    }
    return 'rgba(255,255,255,0.08)'
  }

  private getWeekMarkText(item: HomeDashboardWeekItem): string {
    if (item.completed) {
      return '✓'
    }
    return '·'
  }

  private getWeekMarkTextColor(item: HomeDashboardWeekItem): string {
    if (item.completed) {
      return ColorTokens.TEXT_ON_PRIMARY
    }
    return 'rgba(255,255,255,0.40)'
  }

  private getWeekTitleColor(item: HomeDashboardWeekItem): string {
    if (item.completed) {
      return ColorTokens.ACCENT_PRIMARY
    }
    return 'rgba(255,255,255,0.40)'
  }

  private buildSafeMetric(index: number): HomeDashboardMetric {
    if (index < this.viewModel.metrics.length) {
      return this.viewModel.metrics[index]
    }
    return {
      label: '--',
      value: '--',
      note: '--',
      emphasize: false
    }
  }

  @Builder
  private buildMetricIcon(index: number) {
    if (index === 0) {
      Row({ space: 3 }) {
        Column()
          .width(4)
          .height(18)
          .backgroundColor('rgba(104,235,175,0.42)')
          .borderRadius(3)
        Column()
          .width(4)
          .height(24)
          .backgroundColor(ColorTokens.ACCENT_PRIMARY)
          .borderRadius(3)
        Column()
          .width(4)
          .height(18)
          .backgroundColor('rgba(238,243,246,0.82)')
          .borderRadius(3)
        Row({ space: 2 }) {
          Column()
            .width(12)
            .height(4)
            .backgroundColor(ColorTokens.TEXT_ON_DARK)
            .borderRadius(3)
          Column()
            .width(4)
            .height(18)
            .backgroundColor('rgba(238,243,246,0.82)')
            .borderRadius(3)
        }
      }
    } else if (index === 1) {
      Stack() {
        Column()
          .width(28)
          .height(28)
          .borderRadius(14)
          .border({ width: 2, color: 'rgba(238,243,246,0.84)' })
        Column()
          .width(2)
          .height(10)
          .backgroundColor(ColorTokens.TEXT_ON_DARK)
          .borderRadius(1)
          .offset({ y: -3 })
        Column()
          .width(10)
          .height(2)
          .backgroundColor(ColorTokens.TEXT_ON_DARK)
          .borderRadius(1)
          .offset({ x: 4, y: 2 })
        Column()
          .width(4)
          .height(4)
          .borderRadius(2)
          .backgroundColor(ColorTokens.ACCENT_PRIMARY)
      }
      .width(36)
      .height(36)
    } else {
      Row({ space: 2 }) {
        Column()
          .width(14)
          .height(14)
          .borderRadius(7)
          .border({ width: 2, color: 'rgba(238,243,246,0.84)' })
        Column()
          .width(10)
          .height(2)
          .backgroundColor(ColorTokens.ACCENT_PRIMARY)
          .borderRadius(1)
          .offset({ x: -8, y: -6 })
      }
      .width(36)
      .height(36)
    }
  }

  @Builder
  private buildHeader() {
    Column({ space: 6 }) {
      Text(this.viewModel.dateText)
        .fontSize(14)
        .lineHeight(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('rgba(255,255,255,0.70)')

      Text(this.getHeaderTitle())
        .fontSize(40)
        .lineHeight(40)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
        .letterSpacing(-0.04)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildHeroStatus() {
    Row({ space: 8 }) {
      Stack() {
        Column()
          .width(16)
          .height(16)
          .borderRadius(8)
          .backgroundColor('rgba(255,255,255,0.18)')
          .border({ width: 1.5, color: 'rgba(255,255,255,0.34)' })

        Text('✓')
          .fontSize(9)
          .lineHeight(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(ColorTokens.ACCENT_PRIMARY)
      }
      .width(16)
      .height(16)

      Text(this.viewModel.statusText)
        .fontSize(13)
        .lineHeight(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('rgba(247,251,248,0.90)')
    }
    .height(40)
    .padding({ left: 14, right: 14 })
    .backgroundColor(this.getStatusBackgroundColor())
    .borderRadius(999)
    .border({ width: 1, color: this.getStatusBorderColor() })
  }

  @Builder
  private buildHeroTag() {
    Row() {
      Text(this.getHeroTagText())
        .fontSize(12)
        .lineHeight(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getHeroTagTextColor())
    }
    .height(30)
    .padding({ left: 10, right: 10 })
    .backgroundColor(this.getHeroTagFillColor())
    .borderRadius(12)
    .border({ width: 1, color: 'rgba(255,255,255,0.06)' })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildProgressRing() {
    Stack() {
      Column()
        .width(112)
        .height(112)
        .borderRadius(56)
        .border({ width: 10, color: 'rgba(255,255,255,0.07)' })
        .shadow({
          radius: 22,
          color: 'rgba(0,0,0,0.18)',
          offsetX: 0,
          offsetY: 10
        })

      Column()
        .width(112)
        .height(112)
        .borderRadius(56)
        .border({ width: 10, color: 'rgba(80,236,167,0.18)' })
        .opacity(this.getProgressHighlightOpacity())
        .clip(true)

      Column()
        .width(90)
        .height(90)
        .borderRadius(45)
        .border({ width: 1, color: 'rgba(255,255,255,0.06)' })

      Column()
        .width(68)
        .height(68)
        .borderRadius(34)
        .backgroundColor('#0D1117')
        .border({ width: 1, color: 'rgba(255,255,255,0.03)' })
        .shadow({
          radius: 12,
          color: 'rgba(0,0,0,0.16)',
          offsetX: 0,
          offsetY: 4
        })

      Column({ space: 4 }) {
        Text(this.viewModel.progressText)
          .fontSize(22)
          .lineHeight(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(ColorTokens.ACCENT_PRIMARY)
          .letterSpacing(-0.03)

        Text(this.viewModel.progressLabel)
          .fontSize(10)
          .lineHeight(12)
          .fontWeight(FontWeight.Normal)
          .fontColor('rgba(255,255,255,0.52)')
      }
      .alignItems(HorizontalAlign.Center)

      Column()
        .width(10)
        .height(10)
        .borderRadius(5)
        .backgroundColor(ColorTokens.ACCENT_PRIMARY)
        .shadow({
          radius: 10,
          color: 'rgba(80,236,167,0.28)',
          offsetX: 0,
          offsetY: 0
        })
        .offset({ x: 34, y: -34 })
    }
    .width(112)
    .height(112)
  }

  @Builder
  private buildHeroTop() {
    Row({ space: 18 }) {
      Column({ space: 8 }) {
        Text(this.viewModel.heroEyebrow)
          .fontSize(14)
          .lineHeight(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(ColorTokens.ACCENT_PRIMARY)

        Row({ space: 10 }) {
          Text(this.viewModel.heroTitle)
            .fontSize(40)
            .lineHeight(38)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F7FBF8')
            .letterSpacing(-0.045)
            .layoutWeight(1)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          this.buildHeroTag()
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(this.getHeroMuscleText())
          .fontSize(14)
          .lineHeight(19)
          .fontWeight(FontWeight.Normal)
          .fontColor('rgba(255,255,255,0.62)')

        this.buildHeroStatus()
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      this.buildProgressRing()
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private buildMetricItem(item: HomeDashboardMetric, index: number) {
    Column({ space: 8 }) {
      if (index > 0) {
        Column()
          .width(1)
          .height(112)
          .backgroundColor('rgba(255,255,255,0.08)')
          .position({ x: -10, y: 0 })
      }

      this.buildMetricIcon(index)

      Text(this.getMetricLabel(item, index))
        .fontSize(12)
        .lineHeight(16)
        .fontWeight(FontWeight.Normal)
        .fontColor('rgba(255,255,255,0.64)')

      Text(item.value)
        .fontSize(this.getMetricValueSize(item, index))
        .lineHeight(this.getMetricValueLineHeight(item, index))
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getMetricValueColor(index))
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(item.note)
        .fontSize(11)
        .lineHeight(15)
        .fontWeight(FontWeight.Normal)
        .fontColor('rgba(255,255,255,0.54)')
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  private buildHeroMetrics() {
    Row() {
      this.buildMetricItem(this.buildSafeMetric(0), 0)
      this.buildMetricItem(this.buildSafeMetric(1), 1)
      this.buildMetricItem(this.buildSafeMetric(2), 2)
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
  }

  @Builder
  private buildHeroActions() {
    Column({ space: 12 }) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 8 }) {
          Text('▶')
            .fontSize(12)
            .lineHeight(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#08110D')

          Text(this.viewModel.primaryActionLabel)
            .fontSize(17)
            .lineHeight(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#08110D')
        }
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height(44)
      .backgroundColor(ColorTokens.ACCENT_PRIMARY)
      .borderRadius(22)
      .shadow({
        radius: 28,
        color: 'rgba(80,236,167,0.16)',
        offsetX: 0,
        offsetY: 12
      })
      .enabled(!this.loading && this.viewModel.primaryActionRoute.length > 0)
      .onClick(() => {
        this.openRoute(this.viewModel.primaryActionRoute)
      })

      Button({ type: ButtonType.Normal }) {
        Row({ space: 6 }) {
          Text(this.viewModel.secondaryActionLabel)
            .fontSize(15)
            .lineHeight(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('rgba(255,255,255,0.86)')

          Text('›')
            .fontSize(14)
            .lineHeight(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('rgba(255,255,255,0.72)')
        }
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height(44)
      .backgroundColor('rgba(255,255,255,0.08)')
      .borderRadius(22)
      .border({ width: 1, color: 'rgba(255,255,255,0.10)' })
      .onClick(() => {
        this.openRoute(this.viewModel.secondaryActionRoute)
      })
    }
    .width('100%')
  }

  @Builder
  private buildHeroCard() {
    Column({ space: 16 }) {
      this.buildHeroTop()

      Column()
        .width('100%')
        .height(1)
        .backgroundColor('rgba(255,255,255,0.08)')

      this.buildHeroMetrics()
      this.buildHeroActions()
    }
    .width('100%')
    .padding(20)
    .backgroundColor(ColorTokens.SURFACE_CARD_HERO)
    .borderRadius(28)
    .border({ width: 1, color: 'rgba(255,255,255,0.06)' })
    .shadow(ShadowTokens.GLASS_STRONG)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildSectionPill(text: string) {
    Row() {
      Text(text)
        .fontSize(12)
        .lineHeight(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('rgba(255,255,255,0.70)')
    }
    .padding({ left: 14, right: 14, top: 9, bottom: 9 })
    .backgroundColor('rgba(255,255,255,0.04)')
    .borderRadius(999)
    .border({ width: 1, color: 'rgba(255,255,255,0.10)' })
  }

  @Builder
  private buildWeekHeader() {
    Row() {
      Column({ space: 4 }) {
        Text('本周节奏')
          .fontSize(20)
          .lineHeight(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')

        Text(this.getWeekDateText())
          .fontSize(12)
          .lineHeight(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('rgba(255,255,255,0.40)')
      }
      .alignItems(HorizontalAlign.Start)

      this.buildSectionPill('查看日历')
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildWeekItem(item: HomeDashboardWeekItem) {
    Column({ space: 10 }) {
      Column({ space: 5 }) {
        Text(this.getWeekItemLabel(item))
          .fontSize(12)
          .lineHeight(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getWeekTitleColor(item))

        Text(this.getWeekItemDate(item))
          .fontSize(11)
          .lineHeight(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('rgba(255,255,255,0.70)')
      }
      .alignItems(HorizontalAlign.Center)

      Blank()
        .layoutWeight(1)

      Row() {
        Text(this.getWeekMarkText(item))
          .fontSize(11)
          .lineHeight(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getWeekMarkTextColor(item))
      }
      .width(22)
      .height(22)
      .backgroundColor(this.getWeekMarkFill(item))
      .borderRadius(11)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .width(50)
    .height(96)
    .padding({ left: 6, right: 6, top: 10, bottom: 10 })
    .backgroundColor(this.getWeekCellFill(item))
    .borderRadius(22)
    .border({ width: 1, color: this.getWeekCellStroke(item) })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildWeekProgress() {
    Column({ space: 10 }) {
      Stack() {
        Row()
          .width('100%')
          .height(6)
          .backgroundColor('rgba(255,255,255,0.07)')
          .borderRadius(999)

        Row()
          .width(this.getWeekProgressWidth())
          .height(6)
          .backgroundColor(ColorTokens.ACCENT_PRIMARY)
          .borderRadius(999)
      }
      .width('100%')
      .height(6)

      Row() {
        Text(this.getWeekFooterLeft())
          .fontSize(12)
          .lineHeight(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('rgba(255,255,255,0.40)')

        Text(this.getWeekFooterRight())
          .fontSize(12)
          .lineHeight(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('rgba(255,255,255,0.40)')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
  }

  @Builder
  private buildWeekPanel() {
    Column({ space: 16 }) {
      this.buildWeekHeader()

      Row({ space: 6 }) {
        ForEach(this.viewModel.weeklyItems, (item: HomeDashboardWeekItem) => {
          this.buildWeekItem(item)
        }, (item: HomeDashboardWeekItem) => item.itemId)
      }
      .width('100%')

      this.buildWeekProgress()
    }
    .width('100%')
    .padding(18)
    .backgroundColor('rgba(255,255,255,0.08)')
    .borderRadius(30)
    .border({ width: 1, color: 'rgba(255,255,255,0.10)' })
    .shadow({
      radius: 36,
      color: 'rgba(0,0,0,0.14)',
      offsetX: 0,
      offsetY: 18
    })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildBoundaryHeader() {
    Row() {
      Column({ space: 4 }) {
        Text('计划边界')
          .fontSize(22)
          .lineHeight(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')

        Text('当前周期固定约束')
          .fontSize(12)
          .lineHeight(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('rgba(255,255,255,0.40)')
      }
      .alignItems(HorizontalAlign.Start)

      Row() {
        Text(this.getBoundaryStatusText())
          .fontSize(11)
          .lineHeight(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(ColorTokens.ACCENT_PRIMARY)
      }
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor('rgba(80,236,167,0.10)')
      .borderRadius(999)
      .border({ width: 1, color: 'rgba(99,229,170,0.20)' })
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildBoundaryItem(item: HomeDashboardBoundaryItem) {
    Row() {
      Row({ space: 10 }) {
        Row() {
          Text(item.label)
            .fontSize(12)
            .lineHeight(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('rgba(255,255,255,0.88)')
        }
        .padding({ left: 10, right: 10, top: 7, bottom: 7 })
        .backgroundColor('rgba(255,255,255,0.04)')
        .borderRadius(999)
        .border({ width: 1, color: 'rgba(255,255,255,0.07)' })

        Text(this.getBoundaryHint(item))
          .fontSize(12)
          .lineHeight(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('rgba(255,255,255,0.40)')
      }

      Text(item.value)
        .fontSize(14)
        .lineHeight(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getBoundaryValueColor(item))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding(14)
    .backgroundColor(item.itemId === 'goal' ? 'rgba(255,255,255,0.08)' : 'rgba(255,255,255,0.06)')
    .borderRadius(22)
    .border({ width: 1, color: item.itemId === 'goal' ? 'rgba(255,255,255,0.10)' : 'rgba(255,255,255,0.05)' })
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildBoundaryPanel() {
    Column({ space: 14 }) {
      this.buildBoundaryHeader()

      Column({ space: 12 }) {
        ForEach(this.viewModel.boundaryItems, (item: HomeDashboardBoundaryItem) => {
          this.buildBoundaryItem(item)
        }, (item: HomeDashboardBoundaryItem) => item.itemId)
      }
      .width('100%')
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#131920')
    .borderRadius(30)
    .border({ width: 1, color: 'rgba(255,255,255,0.08)' })
    .shadow({
      radius: 36,
      color: 'rgba(0,0,0,0.14)',
      offsetX: 0,
      offsetY: 18
    })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildWorkoutNavIcon(active: boolean) {
    Row({ space: 2 }) {
      Column()
        .width(4)
        .height(14)
        .backgroundColor(active ? ColorTokens.ACCENT_PRIMARY : 'rgba(255,255,255,0.38)')
        .borderRadius(2)
      Column()
        .width(16)
        .height(4)
        .backgroundColor(active ? ColorTokens.ACCENT_PRIMARY : 'rgba(255,255,255,0.38)')
        .borderRadius(2)
      Column()
        .width(4)
        .height(14)
        .backgroundColor(active ? ColorTokens.ACCENT_PRIMARY : 'rgba(255,255,255,0.38)')
        .borderRadius(2)
    }
  }

  @Builder
  private buildNavItem(item: HomeNavItem) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 6 }) {
        if (item.iconType === 'train') {
          this.buildWorkoutNavIcon(true)
        }

        Text(item.label)
          .fontSize(13)
          .lineHeight(16)
          .fontWeight(item.selected ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(item.selected ? '#FFFFFF61' : '#FFFFFF61')
      }
      .width('100%')
      .height(56)
      .backgroundColor(item.selected ? 'rgba(80,236,167,0.10)' : 'rgba(0,0,0,0)')
      .borderRadius(16)
      .border({
        width: item.selected ? 1 : 0,
        color: item.selected ? 'rgba(80,236,167,0.10)' : 'rgba(0,0,0,0)'
      })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width(item.selected ? 88 : 80)
    .height(56)
    .backgroundColor('rgba(0,0,0,0)')
    .onClick(() => {
      if (item.route.length > 0 && item.route !== AppRoutes.HOME) {
        this.replaceRoute(item.route)
      }
    })
  }

  @Builder
  private buildBottomNav() {
    Row({ space: 0 }) {
      ForEach(HOME_NAV_ITEMS, (item: HomeNavItem) => {
        this.buildNavItem(item)
      }, (item: HomeNavItem) => item.itemId)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 7, bottom: 9 })
    .backgroundColor('rgba(10,13,18,0.98)')
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.SpaceBetween)
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 22 }) {
          this.buildHeader()
          this.buildHeroCard()
          if (this.viewModel.weeklyItems.length > 0) {
            this.buildWeekPanel()
          }
          if (this.viewModel.boundaryItems.length > 0) {
            this.buildBoundaryPanel()
          }
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 58, bottom: 40 })
        .constraintSize({ maxWidth: 430 })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')

      this.buildBottomNav()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0B0F13')
  }
}

export { HomePageV2 }
