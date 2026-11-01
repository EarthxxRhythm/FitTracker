/**
 * StatsDashboardService -- weekly stats and calendar heatmap aggregation.
 *
 * Feature #24: weekly training statistics and calendar heatmap.
 */
import { WorkoutSession, WorkoutSet } from '../models/TrainingModels'
import WorkoutSummaryService from './WorkoutSummaryService'
import { resolveWeekStart, WeekStart } from '../../common/utils/WeekUtils'

export interface WeeklyTrainingStats {
  weekStartText: string
  weekEndText: string
  dateRangeText: string
  sessionCount: number
  totalDurationSeconds: number
  totalDurationText: string
  totalSets: number
  totalVolume: number
}

export interface CalendarHeatmapDay {
  dateText: string
  dayOfMonth: number
  isCurrentMonth: boolean
  sessionCount: number
  totalVolume: number
  level: number
  accessibilityText: string
}

export interface CalendarHeatmapRow {
  rowId: string
  days: CalendarHeatmapDay[]
}

export interface StatsDashboardSummary {
  weeklyStats: WeeklyTrainingStats
  monthTitle: string
  heatmapDays: CalendarHeatmapDay[]
  heatmapRows: CalendarHeatmapRow[]
}

/**
 * 本周「按计划训练日去重」的完成计数（repository 会话源，纯函数，无 IO）。
 *
 * 数据一致性收口：首页环「本周完成进度」的分子。repository 会话有 dayId
 * （无 dayLabel），故去重键 = planId + dayId；仅计 planId 匹配且 dayId 命中
 * dayIds 的会话，同键多次仅计 1；dayId 为空的历史会话不计。
 * 不变量：0 ≤ 结果 ≤ dayIds.length。
 * 与 legacy 源 `countDistinctPlanDays`（planId+dayLabel）语义等价、键不同。
 */
export function countDistinctPlanDaysById(
  sessions: WorkoutSession[],
  planId: string,
  dayIds: string[],
  weekStartTime: number,
  weekEndExclusive: number
): number {
  if (planId.length === 0 || dayIds.length === 0) {
    return 0
  }
  const seenKeys: string[] = []
  let count = 0
  for (let index = 0; index < sessions.length; index++) {
    const session: WorkoutSession = sessions[index]
    if (session.planId !== planId) {
      continue
    }
    if (session.startedAt < weekStartTime || session.startedAt >= weekEndExclusive) {
      continue
    }
    if (session.dayId.length === 0) {
      continue
    }
    if (dayIds.indexOf(session.dayId) < 0) {
      continue
    }
    const key: string = planId + '|' + session.dayId
    if (seenKeys.indexOf(key) >= 0) {
      continue
    }
    seenKeys.push(key)
    count++
  }
  return count
}

class StatsDashboardService {
  createSummary(sessions: WorkoutSession[], now: number, weekStart: WeekStart): StatsDashboardSummary {
    const heatmapDays: CalendarHeatmapDay[] = this.createHeatmapDays(sessions, now, weekStart)
    const summary: StatsDashboardSummary = {
      weeklyStats: this.createWeeklyStats(sessions, now, weekStart),
      monthTitle: this.formatMonthTitle(now),
      heatmapDays: heatmapDays,
      heatmapRows: this.createHeatmapRows(heatmapDays)
    }
    return summary
  }

  createEmptySummary(now: number, weekStart: WeekStart): StatsDashboardSummary {
    return this.createSummary([], now, weekStart)
  }

  findHeatmapDay(days: CalendarHeatmapDay[], dateText: string): CalendarHeatmapDay | undefined {
    for (let index = 0; index < days.length; index++) {
      const day: CalendarHeatmapDay = days[index]
      if (day.dateText === dateText) {
        return day
      }
    }
    return undefined
  }

  private createWeeklyStats(sessions: WorkoutSession[], now: number, weekStart: WeekStart): WeeklyTrainingStats {
    const weekStartDate: Date = this.createWeekStart(now, weekStart)
    const weekEnd: Date = new Date(weekStartDate.getFullYear(), weekStartDate.getMonth(), weekStartDate.getDate() + 6)
    const weekStartTime: number = weekStartDate.getTime()
    const weekEndExclusive: number = new Date(
      weekEnd.getFullYear(),
      weekEnd.getMonth(),
      weekEnd.getDate() + 1
    ).getTime()
    let sessionCount: number = 0
    let totalDurationSeconds: number = 0
    let totalSets: number = 0
    let totalVolume: number = 0

    for (let index = 0; index < sessions.length; index++) {
      const session: WorkoutSession = sessions[index]
      if (session.startedAt >= weekStartTime && session.startedAt < weekEndExclusive) {
        sessionCount++
        totalDurationSeconds += session.durationSeconds
        totalSets += this.getSessionCompletedSets(session)
        totalVolume += this.getSessionVolume(session)
      }
    }

    const weekStartText: string = this.formatDate(weekStartDate.getTime())
    const weekEndText: string = this.formatDate(weekEnd.getTime())
    const stats: WeeklyTrainingStats = {
      weekStartText: weekStartText,
      weekEndText: weekEndText,
      dateRangeText: weekStartText + ' - ' + weekEndText,
      sessionCount: sessionCount,
      totalDurationSeconds: totalDurationSeconds,
      totalDurationText: WorkoutSummaryService.formatDuration(totalDurationSeconds),
      totalSets: totalSets,
      totalVolume: totalVolume
    }
    return stats
  }

  private createHeatmapDays(sessions: WorkoutSession[], now: number, weekStart: WeekStart): CalendarHeatmapDay[] {
    const current: Date = new Date(now)
    const monthStart: Date = new Date(current.getFullYear(), current.getMonth(), 1)
    const gridStart: Date = this.createWeekStart(monthStart.getTime(), weekStart)
    const days: CalendarHeatmapDay[] = []

    for (let offset = 0; offset < 42; offset++) {
      const date: Date = new Date(gridStart.getFullYear(), gridStart.getMonth(), gridStart.getDate() + offset)
      days.push(this.createHeatmapDay(sessions, date, current.getMonth()))
    }
    return days
  }

  private createHeatmapDay(sessions: WorkoutSession[], date: Date, currentMonth: number): CalendarHeatmapDay {
    const dateText: string = this.formatDate(date.getTime())
    const dayStart: number = new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime()
    const dayEndExclusive: number = new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1).getTime()
    let sessionCount: number = 0
    let totalVolume: number = 0

    for (let index = 0; index < sessions.length; index++) {
      const session: WorkoutSession = sessions[index]
      if (session.startedAt >= dayStart && session.startedAt < dayEndExclusive) {
        sessionCount++
        totalVolume += this.getSessionVolume(session)
      }
    }

    const day: CalendarHeatmapDay = {
      dateText: dateText,
      dayOfMonth: date.getDate(),
      isCurrentMonth: date.getMonth() === currentMonth,
      sessionCount: sessionCount,
      totalVolume: totalVolume,
      level: this.createHeatmapLevel(totalVolume),
      accessibilityText: this.createAccessibilityText(dateText, sessionCount, totalVolume)
    }
    return day
  }

  private createHeatmapRows(days: CalendarHeatmapDay[]): CalendarHeatmapRow[] {
    const rows: CalendarHeatmapRow[] = []
    for (let rowIndex = 0; rowIndex < 6; rowIndex++) {
      const rowDays: CalendarHeatmapDay[] = []
      for (let dayIndex = 0; dayIndex < 7; dayIndex++) {
        const sourceIndex: number = rowIndex * 7 + dayIndex
        rowDays.push(days[sourceIndex])
      }
      const row: CalendarHeatmapRow = {
        rowId: 'week_' + rowIndex.toString(),
        days: rowDays
      }
      rows.push(row)
    }
    return rows
  }

  private createWeekStart(timestamp: number, weekStart: WeekStart): Date {
    return resolveWeekStart(new Date(timestamp), weekStart)
  }

  private createHeatmapLevel(totalVolume: number): number {
    if (totalVolume <= 0) {
      return 0
    }
    if (totalVolume <= 500) {
      return 1
    }
    if (totalVolume <= 1000) {
      return 2
    }
    if (totalVolume <= 1500) {
      return 3
    }
    return 4
  }

  private getSessionVolume(session: WorkoutSession): number {
    if (session.sets.length > 0) {
      return this.calculateVolume(session.sets)
    }
    if (session.totalVolume > 0) {
      return session.totalVolume
    }
    return 0
  }

  private getSessionCompletedSets(session: WorkoutSession): number {
    if (session.sets.length > 0) {
      let count: number = 0
      for (let index = 0; index < session.sets.length; index++) {
        const set: WorkoutSet = session.sets[index]
        if (!set.isWarmup && set.weight > 0 && set.reps > 0) {
          count++
        }
      }
      return count
    }
    return 0
  }

  private calculateVolume(sets: WorkoutSet[]): number {
    let volume: number = 0
    for (let index = 0; index < sets.length; index++) {
      const set: WorkoutSet = sets[index]
      if (!set.isWarmup) {
        volume += set.weight * set.reps
      }
    }
    return volume
  }

  private createAccessibilityText(dateText: string, sessionCount: number, totalVolume: number): string {
    if (sessionCount <= 0) {
      return dateText + ' 无训练'
    }
    return dateText + ' ' + sessionCount.toString() + ' 次训练 ' + totalVolume.toString() + ' kg'
  }

  private formatMonthTitle(timestamp: number): string {
    const date: Date = new Date(timestamp)
    return date.getFullYear().toString() + ' 年 ' + (date.getMonth() + 1).toString() + ' 月'
  }

  private formatDate(timestamp: number): string {
    const date: Date = new Date(timestamp)
    return date.getFullYear().toString() + '-' + this.padTwoDigits(date.getMonth() + 1) + '-' +
      this.padTwoDigits(date.getDate())
  }

  private padTwoDigits(value: number): string {
    if (value < 10) {
      return '0' + value.toString()
    }
    return value.toString()
  }
}

export default new StatsDashboardService()
