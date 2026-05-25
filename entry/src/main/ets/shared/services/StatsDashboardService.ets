/**
 * StatsDashboardService -- weekly stats and calendar heatmap aggregation.
 *
 * Feature #24: weekly training statistics and calendar heatmap.
 */
import { WorkoutSession } from '../models/TrainingModels'
import WorkoutSummaryService from './WorkoutSummaryService'

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

class StatsDashboardService {
  createSummary(sessions: WorkoutSession[], now: number): StatsDashboardSummary {
    const heatmapDays: CalendarHeatmapDay[] = this.createHeatmapDays(sessions, now)
    const summary: StatsDashboardSummary = {
      weeklyStats: this.createWeeklyStats(sessions, now),
      monthTitle: this.formatMonthTitle(now),
      heatmapDays: heatmapDays,
      heatmapRows: this.createHeatmapRows(heatmapDays)
    }
    return summary
  }

  createEmptySummary(now: number): StatsDashboardSummary {
    return this.createSummary([], now)
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

  private createWeeklyStats(sessions: WorkoutSession[], now: number): WeeklyTrainingStats {
    const weekStart: Date = this.createWeekStart(now)
    const weekEnd: Date = new Date(weekStart.getFullYear(), weekStart.getMonth(), weekStart.getDate() + 6)
    const weekStartTime: number = weekStart.getTime()
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
        totalSets += session.totalSets
        totalVolume += this.getSessionVolume(session)
      }
    }

    const weekStartText: string = this.formatDate(weekStart.getTime())
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

  private createHeatmapDays(sessions: WorkoutSession[], now: number): CalendarHeatmapDay[] {
    const current: Date = new Date(now)
    const monthStart: Date = new Date(current.getFullYear(), current.getMonth(), 1)
    const gridStart: Date = this.createWeekStart(monthStart.getTime())
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

  private createWeekStart(timestamp: number): Date {
    const value: Date = new Date(timestamp)
    const dayOfWeek: number = value.getDay()
    let mondayOffset: number = dayOfWeek - 1
    if (dayOfWeek === 0) {
      mondayOffset = 6
    }
    return new Date(value.getFullYear(), value.getMonth(), value.getDate() - mondayOffset)
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
    if (session.totalVolume > 0) {
      return session.totalVolume
    }
    let volume: number = 0
    for (let index = 0; index < session.sets.length; index++) {
      volume += session.sets[index].weight * session.sets[index].reps
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
