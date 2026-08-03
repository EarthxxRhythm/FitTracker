/**
 * HomeDashboardService -- maps training summaries into the new home design system view model.
 */
import { AppRoutes } from '../../../app/AppRoutes'
import { HomePlanSummary, HomeWeeklyPlanDay } from '../../../shared/services/HomePlanService'

export type HomeDashboardTone = 'success' | 'warning' | 'info' | 'neutral'

export interface HomeDashboardMetric {
  label: string
  value: string
  note: string
  emphasize: boolean
}

export interface HomeDashboardBoundaryItem {
  itemId: string
  markerText: string
  label: string
  value: string
}

export interface HomeDashboardWeekItem {
  itemId: string
  title: string
  subtitle: string
  current: boolean
  completed: boolean
}

export interface HomeDashboardViewModel {
  hasGoal: boolean
  dateText: string
  greetingText: string
  heroEyebrow: string
  heroTitle: string
  heroSubtitle: string
  statusText: string
  statusTone: HomeDashboardTone
  progressText: string
  progressLabel: string
  primaryActionLabel: string
  primaryActionRoute: string
  secondaryActionLabel: string
  secondaryActionRoute: string
  reviewActionLabel: string
  reviewActionRoute: string
  metrics: HomeDashboardMetric[]
  weeklyItems: HomeDashboardWeekItem[]
  boundaryItems: HomeDashboardBoundaryItem[]
}

const WEEKDAY_LABELS: string[] = [
  '\u5468\u65e5',
  '\u5468\u4e00',
  '\u5468\u4e8c',
  '\u5468\u4e09',
  '\u5468\u56db',
  '\u5468\u4e94',
  '\u5468\u516d'
]

class HomeDashboardService {
  createLoadingViewModel(now: Date): HomeDashboardViewModel {
    return {
      hasGoal: false,
      dateText: this.formatDate(now),
      greetingText: this.resolveGreeting(now),
      heroEyebrow: '\u6b63\u5728\u51c6\u5907',
      heroTitle: '\u6b63\u5728\u6574\u7406\u4eca\u65e5\u8bad\u7ec3',
      heroSubtitle: '\u6b63\u5728\u8bfb\u53d6\u8ba1\u5212\u3001\u8349\u7a3f\u548c\u6062\u590d\u72b6\u6001\u3002',
      statusText: '\u51c6\u5907\u4e2d',
      statusTone: 'info',
      progressText: '--',
      progressLabel: '\u672c\u5468\u8fdb\u5ea6',
      primaryActionLabel: '\u6b63\u5728\u51c6\u5907',
      primaryActionRoute: '',
      secondaryActionLabel: '\u67e5\u770b\u52a8\u4f5c\u5e93',
      secondaryActionRoute: AppRoutes.EXERCISE_LIBRARY,
      reviewActionLabel: '\u8bad\u7ec3\u56de\u987e',
      reviewActionRoute: AppRoutes.REVIEW_HOME,
      metrics: this.createLoadingMetrics(),
      weeklyItems: [],
      boundaryItems: []
    }
  }

  createNoGoalViewModel(now: Date): HomeDashboardViewModel {
    return {
      hasGoal: false,
      dateText: this.formatDate(now),
      greetingText: this.resolveGreeting(now),
      heroEyebrow: '\u5f00\u59cb\u914d\u7f6e',
      heroTitle: '\u5148\u786e\u5b9a\u4f60\u7684\u8bad\u7ec3\u76ee\u6807',
      heroSubtitle: '\u5b8c\u6210\u76ee\u6807\u8bbe\u7f6e\u540e\uff0c\u9996\u9875\u4f1a\u76f4\u63a5\u544a\u8bc9\u4f60\u4eca\u5929\u7ec3\u4ec0\u4e48\u3001\u4ece\u54ea\u91cc\u5f00\u59cb\u3002',
      statusText: '\u5148\u5b8c\u6210\u8bbe\u7f6e',
      statusTone: 'warning',
      progressText: '--',
      progressLabel: '\u672c\u5468\u8fdb\u5ea6',
      primaryActionLabel: '\u8bbe\u7f6e\u8bad\u7ec3\u76ee\u6807',
      primaryActionRoute: AppRoutes.GOAL_SETUP,
      secondaryActionLabel: '\u67e5\u770b\u52a8\u4f5c\u5e93',
      secondaryActionRoute: AppRoutes.EXERCISE_LIBRARY,
      reviewActionLabel: '\u8bad\u7ec3\u56de\u987e',
      reviewActionRoute: AppRoutes.REVIEW_HOME,
      metrics: this.createNoGoalMetrics(),
      weeklyItems: [],
      boundaryItems: []
    }
  }

  createReadyViewModel(
    summary: HomePlanSummary,
    hasRecoverableDraft: boolean,
    recoverDraftSummary: string,
    now: Date
  ): HomeDashboardViewModel {
    const metrics: HomeDashboardMetric[] = this.createReadyMetrics(summary, hasRecoverableDraft, recoverDraftSummary)
    const boundaryItems: HomeDashboardBoundaryItem[] = this.createBoundaryItems(summary)
    const weeklyItems: HomeDashboardWeekItem[] = this.createWeekItems(summary.weeklyPlanDays)
    const progressText: string = this.createProgressText(weeklyItems)

    let heroEyebrow: string = '\u4eca\u65e5\u8bad\u7ec3'
    let heroTitle: string = summary.hasTodayWorkout ? summary.todayTitle : '\u6062\u590d\u4e0e\u8c03\u6574'
    let heroSubtitle: string = summary.hasTodayWorkout
      ? summary.planName + ' \u00b7 ' + summary.todayExerciseCount.toString() + ' \u4e2a\u52a8\u4f5c'
      : summary.todayRestMessage
    let statusText: string = summary.hasTodayWorkout
      ? '\u8bad\u7ec3\u65e5 \u00b7 \u5efa\u8bae\u5b8c\u6210'
      : '\u6062\u590d\u65e5 \u00b7 \u4fdd\u6301\u8282\u594f'
    let statusTone: HomeDashboardTone = summary.hasTodayWorkout ? 'success' : 'info'
    let primaryActionLabel: string = summary.hasTodayWorkout
      ? '\u5f00\u59cb\u8bad\u7ec3'
      : '\u67e5\u770b\u8bad\u7ec3\u56de\u987e'
    let primaryActionRoute: string = summary.startRoute
    let secondaryActionLabel: string = summary.hasTodayWorkout
      ? '\u67e5\u770b\u9884\u89c8'
      : '\u8c03\u6574\u76ee\u6807'
    let secondaryActionRoute: string = summary.hasTodayWorkout
      ? AppRoutes.WORKOUT_PREVIEW
      : AppRoutes.GOAL_SETUP

    if (hasRecoverableDraft) {
      heroEyebrow = '\u6062\u590d\u8bad\u7ec3'
      heroTitle = '\u4ece\u4e0a\u6b21\u4e2d\u65ad\u5904\u7ee7\u7eed'
      heroSubtitle = recoverDraftSummary
      statusText = '\u53ef\u7ee7\u7eed\u8bad\u7ec3'
      statusTone = 'warning'
      primaryActionLabel = '\u7ee7\u7eed\u8bad\u7ec3'
      primaryActionRoute = AppRoutes.ACTIVE_WORKOUT
      secondaryActionLabel = '\u67e5\u770b\u9884\u89c8'
      secondaryActionRoute = AppRoutes.WORKOUT_PREVIEW
    }

    return {
      hasGoal: true,
      dateText: this.formatDate(now),
      greetingText: this.resolveGreeting(now),
      heroEyebrow: heroEyebrow,
      heroTitle: heroTitle,
      heroSubtitle: heroSubtitle,
      statusText: statusText,
      statusTone: statusTone,
      progressText: progressText,
      progressLabel: '\u672c\u5468\u8fdb\u5ea6',
      primaryActionLabel: primaryActionLabel,
      primaryActionRoute: primaryActionRoute,
      secondaryActionLabel: secondaryActionLabel,
      secondaryActionRoute: secondaryActionRoute,
      reviewActionLabel: '\u8bad\u7ec3\u56de\u987e',
      reviewActionRoute: AppRoutes.REVIEW_HOME,
      metrics: metrics,
      weeklyItems: weeklyItems,
      boundaryItems: boundaryItems
    }
  }

  private createLoadingMetrics(): HomeDashboardMetric[] {
    const items: HomeDashboardMetric[] = []
    items.push(this.createMetric('\u5f53\u524d\u72b6\u6001', '\u51c6\u5907\u4e2d', '\u6b63\u5728\u540c\u6b65\u4eca\u5929\u7684\u8bad\u7ec3\u5165\u53e3', true))
    items.push(this.createMetric('\u672c\u5468\u9891\u7387', '--', '\u7b49\u5f85\u8bfb\u53d6\u8bad\u7ec3\u8ba1\u5212', false))
    items.push(this.createMetric('\u9884\u8ba1\u65f6\u957f', '--', '\u7b49\u5f85\u8bfb\u53d6\u8ba1\u5212\u65f6\u957f', false))
    return items
  }

  private createNoGoalMetrics(): HomeDashboardMetric[] {
    const items: HomeDashboardMetric[] = []
    items.push(this.createMetric('\u5f53\u524d\u72b6\u6001', '\u5f85\u914d\u7f6e', '\u5148\u5b8c\u6210\u76ee\u6807\u8bbe\u7f6e', true))
    items.push(this.createMetric('\u8bad\u7ec3\u9891\u7387', '--', '\u8bbe\u7f6e\u540e\u81ea\u52a8\u751f\u6210\u672c\u5468\u8282\u594f', false))
    items.push(this.createMetric('\u5355\u6b21\u65f6\u957f', '--', '\u8bbe\u7f6e\u540e\u81ea\u52a8\u751f\u6210\u65f6\u957f\u9884\u7b97', false))
    return items
  }

  private createReadyMetrics(
    summary: HomePlanSummary,
    hasRecoverableDraft: boolean,
    recoverDraftSummary: string
  ): HomeDashboardMetric[] {
    const items: HomeDashboardMetric[] = []
    if (hasRecoverableDraft) {
      items.push(this.createMetric('\u5f53\u524d\u72b6\u6001', '\u53ef\u6062\u590d', '\u4ece\u4e0a\u6b21\u4e2d\u65ad\u5904\u7ee7\u7eed', true))
      items.push(this.createMetric('\u672c\u5468\u9891\u7387', summary.weeklyDays.toString() + ' \u5929/\u5468', summary.primaryMetaText, false))
      items.push(this.createMetric('\u6062\u590d\u8fdb\u5ea6', '\u7ee7\u7eed\u5f55\u5165', recoverDraftSummary, false))
      return items
    }

    if (summary.hasTodayWorkout) {
      items.push(this.createMetric('\u52a8\u4f5c\u6570', summary.todayExerciseCount.toString(), '\u4eca\u65e5\u8bad\u7ec3\u52a8\u4f5c', true))
      items.push(this.createMetric('\u9884\u8ba1\u7528\u65f6', summary.sessionMinutes.toString(), '\u5206\u949f', false))
      items.push(this.createMetric('\u8ba1\u5212\u6765\u6e90', summary.planName, summary.primaryMetaText, false))
      return items
    }

    items.push(this.createMetric('\u5f53\u524d\u72b6\u6001', '\u6062\u590d\u65e5', '\u4eca\u5929\u4ee5\u6062\u590d\u548c\u8c03\u6574\u4e3a\u4e3b', true))
    items.push(this.createMetric('\u672c\u5468\u9891\u7387', summary.weeklyDays.toString() + ' \u5929/\u5468', summary.primaryMetaText, false))
    items.push(this.createMetric('\u8ba1\u5212\u6765\u6e90', summary.planName, '\u4fdd\u6301\u5f53\u524d\u8282\u594f\u5373\u53ef', false))
    return items
  }

  private createBoundaryItems(summary: HomePlanSummary): HomeDashboardBoundaryItem[] {
    const items: HomeDashboardBoundaryItem[] = []
    items.push(this.createBoundaryItem('goal', '\u76ee', '\u76ee\u6807', summary.goalSummary))
    items.push(this.createBoundaryItem('equipment', '\u5668', '\u5668\u68b0', summary.equipmentSummary))
    items.push(this.createBoundaryItem('restriction', '\u9650', '\u9650\u5236', summary.restrictionSummary))
    return items
  }

  private createWeekItems(days: HomeWeeklyPlanDay[]): HomeDashboardWeekItem[] {
    const items: HomeDashboardWeekItem[] = []
    const currentIndex: number = this.findCurrentIndex(days)
    for (let index = 0; index < days.length; index++) {
      const sourceDay: HomeWeeklyPlanDay = days[index]
      const item: HomeDashboardWeekItem = {
        itemId: sourceDay.dayId,
        title: sourceDay.title,
        subtitle: sourceDay.exerciseCount.toString() + ' \u52a8\u4f5c',
        current: sourceDay.isToday,
        completed: currentIndex >= 0 && index < currentIndex
      }
      items.push(item)
    }
    return items
  }

  private findCurrentIndex(days: HomeWeeklyPlanDay[]): number {
    for (let index = 0; index < days.length; index++) {
      if (days[index].isToday) {
        return index
      }
    }
    return -1
  }

  private createProgressText(items: HomeDashboardWeekItem[]): string {
    if (items.length === 0) {
      return '--'
    }
    for (let index = 0; index < items.length; index++) {
      if (items[index].current) {
        return (index + 1).toString() + '/' + items.length.toString()
      }
    }
    return '0/' + items.length.toString()
  }

  private createMetric(label: string, value: string, note: string, emphasize: boolean): HomeDashboardMetric {
    return {
      label: label,
      value: value,
      note: note,
      emphasize: emphasize
    }
  }

  private createBoundaryItem(
    itemId: string,
    markerText: string,
    label: string,
    value: string
  ): HomeDashboardBoundaryItem {
    return {
      itemId: itemId,
      markerText: markerText,
      label: label,
      value: value
    }
  }

  private formatDate(now: Date): string {
    const month: number = now.getMonth() + 1
    const day: number = now.getDate()
    const weekday: string = WEEKDAY_LABELS[now.getDay()]
    return month.toString() + '\u6708' + day.toString() + '\u65e5 ' + weekday
  }

  private resolveGreeting(now: Date): string {
    const hour: number = now.getHours()
    if (hour < 12) {
      return '\u65e9\u4e0a\u597d\uff0c\u4e13\u6ce8\u8bad\u7ec3'
    }
    if (hour < 18) {
      return '\u4e0b\u5348\u597d\uff0c\u7ee7\u7eed\u63a8\u8fdb'
    }
    return '\u665a\u4e0a\u597d\uff0c\u5b8c\u6210\u4eca\u5929'
  }
}

export default new HomeDashboardService()
