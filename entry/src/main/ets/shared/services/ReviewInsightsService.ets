/**
 * ReviewInsightsService -- training review insights for weekly trends and filtered recent sessions.
 *
 * Function #14: recent workout filters and weekly trend details.
 */
import ReviewService from './ReviewService'
import { ReviewRecentSessionRecord } from './ReviewDashboardService'
import WorkoutSummaryService from './WorkoutSummaryService'
import { WorkoutSession } from '../models/TrainingModels'

export class ReviewRecentSessionFilterOption {
  filterId: string = ''
  label: string = ''
  description: string = ''
  matchedSessionCount: number = 0
  locked: boolean = false
}

export class ReviewWeeklyTrendItem {
  weekId: string = ''
  weekLabel: string = ''
  dateRangeText: string = ''
  sessionCount: number = 0
  totalDurationSeconds: number = 0
  totalDurationText: string = '0 分钟'
  totalVolume: number = 0
  completionRate: number = 0
  completionText: string = '0/0 组'
  averageSessionText: string = '0 分钟/次'
  dominantDayId: string = ''
  summaryText: string = ''
}

class ReviewInsightsService {
  private readonly recentRecordLimit: number = 6
  private readonly weeklyTrendLimit: number = 6
  private currentReferenceTime: number = 0

  createRecentFilters(
    sessions: WorkoutSession[],
    now: number,
    unlimitedHistoryUnlocked: boolean
  ): ReviewRecentSessionFilterOption[] {
    this.currentReferenceTime = now
    const filters: ReviewRecentSessionFilterOption[] = []
    filters.push(this.createFilterOption('recent_7_days', '最近 7 天', '聚焦最近一周训练', sessions, now, false))
    filters.push(this.createFilterOption('recent_30_days', '最近 30 天', '看近一个月节奏', sessions, now, false))
    filters.push(this.createFilterOption(
      'all_sessions',
      '全部记录',
      unlimitedHistoryUnlocked ? '查看所有已保存训练' : '升级 Pro 后查看全部历史记录',
      sessions,
      now,
      !unlimitedHistoryUnlocked
    ))
    return filters
  }

  filterRecentRecords(
    sessions: WorkoutSession[],
    filterId: string,
    now: number,
    unlimitedHistoryUnlocked: boolean
  ): ReviewRecentSessionRecord[] {
    this.currentReferenceTime = now
    const resolvedFilterId: string = this.resolveFilterId(filterId, unlimitedHistoryUnlocked)
    const filteredSessions: WorkoutSession[] = []
    for (let index = sessions.length - 1; index >= 0; index--) {
      const session: WorkoutSession = sessions[index]
      if (this.matchesFilter(session, resolvedFilterId, now)) {
        filteredSessions.push(session)
      }
      if (filteredSessions.length >= this.recentRecordLimit) {
        break
      }
    }

    const records: ReviewRecentSessionRecord[] = []
    for (let index = 0; index < filteredSessions.length; index++) {
      records.push(this.createRecentRecord(filteredSessions[index]))
    }
    return records
  }

  resolveFilterId(filterId: string, unlimitedHistoryUnlocked: boolean): string {
    if (filterId === 'all_sessions' && !unlimitedHistoryUnlocked) {
      return 'recent_30_days'
    }
    return filterId
  }

  createWeeklyTrendItems(sessions: WorkoutSession[], now: number): ReviewWeeklyTrendItem[] {
    this.currentReferenceTime = now
    const items: ReviewWeeklyTrendItem[] = []
    const currentWeekStart: Date = this.createWeekStart(now)
    for (let offset = 0; offset < this.weeklyTrendLimit; offset++) {
      const weekStart: Date = new Date(
        currentWeekStart.getFullYear(),
        currentWeekStart.getMonth(),
        currentWeekStart.getDate() - offset * 7
      )
      items.push(this.createWeeklyTrendItem(sessions, weekStart))
    }

    for (let index = 0; index < items.length; index++) {
      const current: ReviewWeeklyTrendItem = items[index]
      const previous: ReviewWeeklyTrendItem | undefined = index + 1 < items.length ? items[index + 1] : undefined
      current.summaryText = this.createWeeklySummaryText(current, previous, index)
    }
    return items
  }

  createEmptyWeeklyTrendItem(): ReviewWeeklyTrendItem {
    const item: ReviewWeeklyTrendItem = {
      weekId: '',
      weekLabel: '本周趋势',
      dateRangeText: '',
      sessionCount: 0,
      totalDurationSeconds: 0,
      totalDurationText: '0 分钟',
      totalVolume: 0,
      completionRate: 0,
      completionText: '0/0 组',
      averageSessionText: '0 分钟/次',
      dominantDayId: '',
      summaryText: '完成训练后，这里会开始累积周趋势。'
    }
    return item
  }

  private createFilterOption(
    filterId: string,
    label: string,
    description: string,
    sessions: WorkoutSession[],
    now: number,
    locked: boolean
  ): ReviewRecentSessionFilterOption {
    let matchedSessionCount: number = 0
    for (let index = 0; index < sessions.length; index++) {
      if (this.matchesFilter(sessions[index], filterId, now)) {
        matchedSessionCount++
      }
    }
    const option: ReviewRecentSessionFilterOption = {
      filterId: filterId,
      label: label,
      description: description,
      matchedSessionCount: matchedSessionCount,
      locked: locked
    }
    return option
  }

  private matchesFilter(session: WorkoutSession, filterId: string, now: number): boolean {
    if (filterId === 'recent_7_days') {
      return session.startedAt >= now - 7 * 24 * 60 * 60 * 1000
    }
    if (filterId === 'recent_30_days') {
      return session.startedAt >= now - 30 * 24 * 60 * 60 * 1000
    }
    return true
  }

  private createRecentRecord(session: WorkoutSession): ReviewRecentSessionRecord {
    const completedSets: number = this.getCompletedSets(session)
    const targetSets: number = this.getTargetSets(session)
    const completionRate: number = ReviewService.calculateCompletionRate(completedSets, targetSets)
    const totalVolume: number = this.getTotalVolume(session)
    const record: ReviewRecentSessionRecord = {
      sessionId: session.sessionId,
      dayId: session.dayId,
      dateText: this.formatDate(session.startedAt),
      durationText: WorkoutSummaryService.formatDuration(session.durationSeconds),
      completedSets: completedSets,
      targetSets: targetSets,
      completionRate: completionRate,
      completionText: completedSets.toString() + '/' + targetSets.toString() + ' 组',
      totalVolume: totalVolume,
      volumeText: totalVolume.toString() + ' kg'
    }
    return record
  }

  private createWeeklyTrendItem(sessions: WorkoutSession[], weekStart: Date): ReviewWeeklyTrendItem {
    const weekStartTime: number = weekStart.getTime()
    const weekEnd: Date = new Date(weekStart.getFullYear(), weekStart.getMonth(), weekStart.getDate() + 6)
    const weekEndExclusive: number = new Date(
      weekEnd.getFullYear(),
      weekEnd.getMonth(),
      weekEnd.getDate() + 1
    ).getTime()
    let sessionCount: number = 0
    let totalDurationSeconds: number = 0
    let totalVolume: number = 0
    let completedSets: number = 0
    let targetSets: number = 0
    let dominantDayId: string = ''
    let dominantVolume: number = 0

    for (let index = 0; index < sessions.length; index++) {
      const session: WorkoutSession = sessions[index]
      if (session.startedAt < weekStartTime || session.startedAt >= weekEndExclusive) {
        continue
      }
      sessionCount++
      totalDurationSeconds += session.durationSeconds
      totalVolume += this.getTotalVolume(session)
      completedSets += this.getCompletedSets(session)
      targetSets += this.getTargetSets(session)
      const sessionVolume: number = this.getTotalVolume(session)
      if (sessionVolume >= dominantVolume) {
        dominantVolume = sessionVolume
        dominantDayId = session.dayId
      }
    }

    const completionRate: number = ReviewService.calculateCompletionRate(completedSets, targetSets)
    const averageSessionSeconds: number = sessionCount > 0 ? Math.floor(totalDurationSeconds / sessionCount) : 0
    const item: ReviewWeeklyTrendItem = {
      weekId: this.formatDate(weekStartTime),
      weekLabel: this.createWeekLabel(weekStartTime),
      dateRangeText: this.formatDate(weekStartTime) + ' - ' + this.formatDate(weekEnd.getTime()),
      sessionCount: sessionCount,
      totalDurationSeconds: totalDurationSeconds,
      totalDurationText: WorkoutSummaryService.formatDuration(totalDurationSeconds),
      totalVolume: totalVolume,
      completionRate: completionRate,
      completionText: completedSets.toString() + '/' + targetSets.toString() + ' 组',
      averageSessionText: WorkoutSummaryService.formatDuration(averageSessionSeconds) + '/次',
      dominantDayId: dominantDayId,
      summaryText: ''
    }
    return item
  }

  private createWeeklySummaryText(
    current: ReviewWeeklyTrendItem,
    previous: ReviewWeeklyTrendItem | undefined,
    index: number
  ): string {
    if (current.sessionCount === 0) {
      return '这一周还没有训练记录。'
    }
    if (previous === undefined || previous.sessionCount === 0) {
      return '本周完成 ' + current.sessionCount.toString() + ' 次训练，平均完成率 ' +
        current.completionRate.toString() + '%。'
    }

    const volumeDelta: number = current.totalVolume - previous.totalVolume
    const completionDelta: number = current.completionRate - previous.completionRate
    if (index === 0) {
      return '相比上周，训练量' + this.createSignedText(volumeDelta, 'kg') + '，完成率' +
        this.createSignedText(completionDelta, '%') + '。'
    }
    return '相比更早一周，训练量' + this.createSignedText(volumeDelta, 'kg') + '，完成率' +
      this.createSignedText(completionDelta, '%') + '。'
  }

  private createSignedText(delta: number, unit: string): string {
    if (delta > 0) {
      return '增加 ' + delta.toString() + ' ' + unit
    }
    if (delta < 0) {
      return '减少 ' + Math.abs(delta).toString() + ' ' + unit
    }
    return '持平'
  }

  private createWeekLabel(timestamp: number): string {
    const nowWeekStart: string = this.formatDate(this.createWeekStart(this.currentReferenceTime).getTime())
    const weekId: string = this.formatDate(timestamp)
    if (weekId === nowWeekStart) {
      return '本周'
    }
    return '' + this.getWeekOffsetLabel(timestamp) + ' 周前'
  }

  private getWeekOffsetLabel(timestamp: number): string {
    const nowWeekStart: Date = this.createWeekStart(this.currentReferenceTime)
    const weekStart: Date = this.createWeekStart(timestamp)
    const deltaMilliseconds: number = nowWeekStart.getTime() - weekStart.getTime()
    const deltaWeeks: number = Math.floor(deltaMilliseconds / (7 * 24 * 60 * 60 * 1000))
    return deltaWeeks.toString()
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

  private getTotalVolume(session: WorkoutSession): number {
    if (session.totalVolume > 0) {
      return session.totalVolume
    }
    return ReviewService.calculateVolume(session.sets)
  }

  private getCompletedSets(session: WorkoutSession): number {
    return this.getNumberAfterPrefix(session.notes, 'completed_sets=', session.totalSets)
  }

  private getTargetSets(session: WorkoutSession): number {
    return this.getNumberAfterPrefix(session.notes, 'target_sets=', session.totalSets)
  }

  private getNumberAfterPrefix(source: string, prefix: string, fallbackValue: number): number {
    const startIndex: number = source.indexOf(prefix)
    if (startIndex < 0) {
      return fallbackValue
    }
    const valueStartIndex: number = startIndex + prefix.length
    let valueEndIndex: number = source.indexOf(';', valueStartIndex)
    if (valueEndIndex < 0) {
      valueEndIndex = source.length
    }
    const parsed: number = Number(source.substring(valueStartIndex, valueEndIndex))
    if (Number.isNaN(parsed)) {
      return fallbackValue
    }
    return Math.floor(parsed)
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

export default new ReviewInsightsService()
