/**
 * 首页 Tab 状态层。
 *
 * 由 PencilAppShell 以 `@State` 持有（生命周期 = 主壳，tab 切换不销毁），
 * HomeContent 以 `@ObjectLink` 消费。装载编排从 HomeContent 迁入，
 * `onVisibleAreaChange` 的「每次可见无条件重读」升级为「按需 refresh」。
 *
 * 数据源优先级不变：① 计划组已启用的预置计划 → ② 目标生成计划 → 空态。
 */
import { Context } from '@kit.AbilityKit'
import { StateBase } from './StateBase'
import { UserGoal, TrainingPlan, PlanDay, WorkoutSession } from '../../../../shared/models/TrainingModels'
import WorkoutSessionService, { WeeklyStats } from '../../../../common/services/WorkoutSessionService'
import TrainingPlanService, { TrainingDay, UserPlan } from '../../../../common/services/TrainingPlanService'
import ContentRepository from '../../../../shared/services/ContentRepository'
import { dayFocusMuscles } from '../PlanTabModel'
import StatsDashboardService, { StatsDashboardSummary } from '../../../../shared/services/StatsDashboardService'
import GoalRepository from '../../../../shared/services/GoalRepository'
import PlanEngine from '../../../../shared/services/PlanEngine'
import HomePlanService, { HomePlanSummary } from '../../../../shared/services/HomePlanService'
import WorkoutSessionPersistenceBridgeService from '../../../workout/services/WorkoutSessionPersistenceBridgeService'
import SettingsService, { AppSettings } from '../../../../common/services/SettingsService'

export interface HomeWeekDayItem {
  label: string
  dateText: string
  isTrained: boolean
}

@Observed
export class HomeState extends StateBase {
  currentDateText: string = ''
  greetingText: string = ''
  weeklyProgressPercent: number = 0
  // 今日训练卡文案：与「计划」Tab 同源，随当前计划（或目标生成计划）刷新。
  todayTitle: string = '尚未启用计划'
  todayMuscleText: string = '前往计划组选择训练计划'
  todayStatusText: string = '待安排'
  todayExerciseCount: number = 0
  todayDurationMinutes: number = 0
  todayMuscleGroupCount: number = 0
  weeklyTrainedCount: number = 0
  weeklyPlannedDays: number = 0
  weekDays: HomeWeekDayItem[] = []

  /** 按需装载。[force] 为 true 跳过新鲜度判断（首次 aboutToAppear 用）。 */
  async refresh(context: Context, force: boolean = false): Promise<void> {
    if (!force && !this.needRefresh()) {
      return
    }
    if (!this.tryBeginLoading()) {
      return
    }
    try {
      // 日期与问候是纯计算，每次 refresh 都重算（跨天时能自动更新）。
      this.applyDateAndGreeting()
      await this.load(context)
      this.markLoaded()
    } finally {
      this.endLoading()
    }
  }

  /** 装载主体（等价迁移自 HomeContent.loadDynamicContent）。 */
  private async load(context: Context): Promise<void> {
    const now: number = Date.now()
    const weeklyStats: WeeklyStats = await WorkoutSessionService.getWeeklyStats(context)
    const trainingDates: string[] = await WorkoutSessionService.getTrainingDates(context)
    this.weekDays = this.createWeekDayItems(trainingDates)
    this.weeklyTrainedCount = weeklyStats.count

    // 数据源优先级与「计划」Tab 一致：① 计划组已启用的预置计划 → ② 目标生成计划。
    const goal: UserGoal | undefined = await GoalRepository.loadGoal(context)
    const current: UserPlan | null = await TrainingPlanService.getCurrentPlan(context)

    if (current !== null) {
      const todayTraining: TrainingDay | null = TrainingPlanService.getTodayTraining(current)
      // 预置计划数据模型没有单次时长字段，暂沿用目标设置里的单次时长作为「预计用时」；
      // 未设置目标时为 0（数据缺口，见提交说明）。
      const sessionMinutes: number = goal === undefined ? 0 : goal.sessionMinutes
      const summary: HomePlanSummary = HomePlanService.createSummaryFromCurrentPlan(
        current,
        TrainingPlanService.getTodayLabel(),
        todayTraining,
        sessionMinutes
      )
      this.todayTitle = summary.todayTitle
      this.todayMuscleText = todayTraining === null ? '今日无训练安排' : dayFocusMuscles(todayTraining)
      this.todayStatusText = summary.hasTodayWorkout ? '训练日 · 建议完成' : '休息日 · 恢复优先'
      this.todayExerciseCount = summary.todayExerciseCount
      this.todayDurationMinutes = summary.sessionMinutes
      this.todayMuscleGroupCount = summary.todayMuscleGroupCount
      this.weeklyPlannedDays = summary.weeklyDays
    } else if (goal !== undefined) {
      const plan: TrainingPlan = PlanEngine.generatePlan(goal)
      const daySeed: number = this.createDaySeed(goal.createdAt, now)
      const summary: HomePlanSummary = HomePlanService.createSummary(goal, plan, daySeed)
      const todayDay: PlanDay | undefined = HomePlanService.pickTodayDay(plan, daySeed)
      this.todayTitle = summary.todayTitle
      this.todayMuscleText = todayDay === undefined || todayDay.focusMuscleIds.length === 0
        ? '今日无训练安排'
        : this.muscleNamesOf(todayDay.focusMuscleIds)
      this.todayStatusText = summary.hasTodayWorkout ? '训练日 · 建议完成' : '休息日 · 恢复优先'
      this.todayExerciseCount = summary.todayExerciseCount
      this.todayDurationMinutes = summary.sessionMinutes
      this.todayMuscleGroupCount = summary.todayMuscleGroupCount
      this.weeklyPlannedDays = plan.days.length
    } else {
      this.applyEmptyState()
      return
    }

    const settings: AppSettings = await SettingsService.loadSettings(context)
    const sessions: WorkoutSession[] = await WorkoutSessionPersistenceBridgeService.loadPersistedSessions(context)
    const dashboard: StatsDashboardSummary = sessions.length === 0
      ? StatsDashboardService.createEmptySummary(now, settings.weekStart)
      : StatsDashboardService.createSummary(sessions, now, settings.weekStart)
    this.weeklyProgressPercent = this.createProgressPercent(dashboard.weeklyStats.sessionCount, this.weeklyPlannedDays)
  }

  // ── 派生（从 HomeContent 迁入） ──────────────────────────────────────────

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

  /** 目标生成计划的今日肌群名（focusMuscleIds → 中文名）。 */
  private muscleNamesOf(muscleIds: string[]): string {
    const names: string[] = []
    for (let index = 0; index < muscleIds.length; index++) {
      names.push(ContentRepository.getMuscleName(muscleIds[index]))
    }
    return names.join(' · ')
  }

  /** 首页三格指标取值（在 @Builder 内部调用，保证读到的是最新状态）。 */
  metricValue(iconName: string): string {
    if (iconName === 'dumbbell') {
      return this.todayExerciseCount.toString()
    }
    if (iconName === 'clock-3') {
      return this.todayDurationMinutes.toString()
    }
    return this.todayMuscleGroupCount.toString()
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
    this.todayTitle = '尚未启用计划'
    this.todayMuscleText = '前往计划组选择训练计划'
    this.todayStatusText = '待安排'
    this.todayExerciseCount = 0
    this.todayDurationMinutes = 0
    this.todayMuscleGroupCount = 0
    this.weeklyPlannedDays = 0
  }
}
