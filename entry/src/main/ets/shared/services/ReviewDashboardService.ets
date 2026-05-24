/**
 * ReviewDashboardService - aggregates sessions for the MVP review dashboard.
 *
 * Feature #12: review dashboard and next adjustment hint.
 * Feature #14: recent workout records and historical trend summary.
 */
import { WorkoutSession } from '../models/TrainingModels'
import ReviewService from './ReviewService'
import WorkoutSummaryService from './WorkoutSummaryService'

export interface ReviewDashboardSummary {
  hasSessions: boolean
  sessionCount: number
  totalCompletedSets: number
  totalTargetSets: number
  averageCompletionRate: number
  totalDurationSeconds: number
  totalDurationText: string
  latestSessionId: string
  latestDayId: string
  adjustmentHint: string
  adjustmentText: string
  recentRecords: ReviewRecentSessionRecord[]
  trendSummary: ReviewTrendSummary
}

export interface ReviewRecentSessionRecord {
  sessionId: string
  dayId: string
  dateText: string
  durationText: string
  completedSets: number
  targetSets: number
  completionRate: number
  completionText: string
  totalVolume: number
  volumeText: string
}

export interface ReviewTrendSummary {
  hasTrend: boolean
  recentSessionCount: number
  previousSessionCount: number
  recentTotalVolume: number
  previousTotalVolume: number
  recentCompletionRate: number
  previousCompletionRate: number
  volumeTrendText: string
  completionTrendText: string
  summaryText: string
}

class ReviewDashboardService {
  private readonly recentRecordLimit: number = 5
  private readonly trendWindowSize: number = 2

  createSummary(sessions: WorkoutSession[]): ReviewDashboardSummary {
    if (sessions.length === 0) {
      return this.createEmptySummary()
    }

    let totalCompletedSets: number = 0
    let totalTargetSets: number = 0
    let totalDurationSeconds: number = 0
    for (let index = 0; index < sessions.length; index++) {
      const session: WorkoutSession = sessions[index]
      totalCompletedSets += this.getCompletedSets(session)
      totalTargetSets += this.getTargetSets(session)
      totalDurationSeconds += session.durationSeconds
    }

    const latestSession: WorkoutSession = sessions[sessions.length - 1]
    const averageCompletionRate: number = ReviewService.calculateCompletionRate(totalCompletedSets, totalTargetSets)
    const hint: string = this.getAdjustmentHint(averageCompletionRate)
    const summary: ReviewDashboardSummary = {
      hasSessions: true,
      sessionCount: sessions.length,
      totalCompletedSets: totalCompletedSets,
      totalTargetSets: totalTargetSets,
      averageCompletionRate: averageCompletionRate,
      totalDurationSeconds: totalDurationSeconds,
      totalDurationText: WorkoutSummaryService.formatDuration(totalDurationSeconds),
      latestSessionId: latestSession.sessionId,
      latestDayId: latestSession.dayId,
      adjustmentHint: hint,
      adjustmentText: this.getAdjustmentText(hint),
      recentRecords: this.createRecentRecords(sessions),
      trendSummary: this.createTrendSummary(sessions)
    }
    return summary
  }

  createEmptySummary(): ReviewDashboardSummary {
    const summary: ReviewDashboardSummary = {
      hasSessions: false,
      sessionCount: 0,
      totalCompletedSets: 0,
      totalTargetSets: 0,
      averageCompletionRate: 0,
      totalDurationSeconds: 0,
      totalDurationText: '0 分钟',
      latestSessionId: '',
      latestDayId: '',
      adjustmentHint: 'start_training',
      adjustmentText: '先完成一次训练，再根据完成率调整下次计划。',
      recentRecords: [],
      trendSummary: this.createEmptyTrendSummary()
    }
    return summary
  }

  private createRecentRecords(sessions: WorkoutSession[]): ReviewRecentSessionRecord[] {
    const records: ReviewRecentSessionRecord[] = []
    let count: number = 0
    for (let index = sessions.length - 1; index >= 0 && count < this.recentRecordLimit; index--) {
      records.push(this.createRecentRecord(sessions[index]))
      count++
    }
    return records
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
      completionText: completedSets.toString() + '/' + targetSets.toString() + ' 组 · ' + completionRate.toString() + '%',
      totalVolume: totalVolume,
      volumeText: totalVolume.toString() + ' kg'
    }
    return record
  }

  private createTrendSummary(sessions: WorkoutSession[]): ReviewTrendSummary {
    if (sessions.length < 2) {
      return this.createEmptyTrendSummary()
    }

    let recentStartIndex: number = sessions.length - this.trendWindowSize
    if (recentStartIndex < 1) {
      recentStartIndex = 1
    }

    let recentCompletedSets: number = 0
    let recentTargetSets: number = 0
    let recentTotalVolume: number = 0
    for (let index = recentStartIndex; index < sessions.length; index++) {
      const session: WorkoutSession = sessions[index]
      recentCompletedSets += this.getCompletedSets(session)
      recentTargetSets += this.getTargetSets(session)
      recentTotalVolume += this.getTotalVolume(session)
    }

    let previousCompletedSets: number = 0
    let previousTargetSets: number = 0
    let previousTotalVolume: number = 0
    for (let index = 0; index < recentStartIndex; index++) {
      const session: WorkoutSession = sessions[index]
      previousCompletedSets += this.getCompletedSets(session)
      previousTargetSets += this.getTargetSets(session)
      previousTotalVolume += this.getTotalVolume(session)
    }

    const recentCompletionRate: number = ReviewService.calculateCompletionRate(recentCompletedSets, recentTargetSets)
    const previousCompletionRate: number = ReviewService.calculateCompletionRate(previousCompletedSets, previousTargetSets)
    const recentSessionCount: number = sessions.length - recentStartIndex
    const previousSessionCount: number = recentStartIndex
    const volumeDelta: number = recentTotalVolume - previousTotalVolume
    const completionDelta: number = recentCompletionRate - previousCompletionRate
    const trend: ReviewTrendSummary = {
      hasTrend: true,
      recentSessionCount: recentSessionCount,
      previousSessionCount: previousSessionCount,
      recentTotalVolume: recentTotalVolume,
      previousTotalVolume: previousTotalVolume,
      recentCompletionRate: recentCompletionRate,
      previousCompletionRate: previousCompletionRate,
      volumeTrendText: this.createVolumeTrendText(volumeDelta),
      completionTrendText: this.createCompletionTrendText(completionDelta),
      summaryText: this.createTrendSummaryText(recentSessionCount, volumeDelta, completionDelta)
    }
    return trend
  }

  createEmptyTrendSummary(): ReviewTrendSummary {
    const trend: ReviewTrendSummary = {
      hasTrend: false,
      recentSessionCount: 0,
      previousSessionCount: 0,
      recentTotalVolume: 0,
      previousTotalVolume: 0,
      recentCompletionRate: 0,
      previousCompletionRate: 0,
      volumeTrendText: '完成更多训练后生成趋势',
      completionTrendText: '完成更多训练后生成趋势',
      summaryText: '至少保存两次训练后，可以查看历史趋势。'
    }
    return trend
  }

  private createVolumeTrendText(delta: number): string {
    if (delta > 0) {
      return '训练量上升 ' + delta.toString() + ' kg'
    }
    if (delta < 0) {
      return '训练量下降 ' + Math.abs(delta).toString() + ' kg'
    }
    return '训练量持平'
  }

  private createCompletionTrendText(delta: number): string {
    if (delta > 0) {
      return '完成率上升 ' + delta.toString() + '%'
    }
    if (delta < 0) {
      return '完成率下降 ' + Math.abs(delta).toString() + '%'
    }
    return '完成率持平'
  }

  private createTrendSummaryText(recentSessionCount: number, volumeDelta: number, completionDelta: number): string {
    if (volumeDelta > 0 && completionDelta > 0) {
      return '最近 ' + recentSessionCount.toString() + ' 次训练量和完成率均高于此前记录。'
    }
    if (volumeDelta > 0 && completionDelta <= 0) {
      return '最近 ' + recentSessionCount.toString() + ' 次训练量提高，注意保持完成率稳定。'
    }
    if (volumeDelta <= 0 && completionDelta > 0) {
      return '最近 ' + recentSessionCount.toString() + ' 次完成率提高，训练量可以稳步推进。'
    }
    if (volumeDelta < 0 && completionDelta < 0) {
      return '最近 ' + recentSessionCount.toString() + ' 次训练表现回落，建议下次适当降低压力。'
    }
    return '最近 ' + recentSessionCount.toString() + ' 次训练与此前基本持平。'
  }

  private getTotalVolume(session: WorkoutSession): number {
    if (session.totalVolume > 0) {
      return session.totalVolume
    }
    return ReviewService.calculateVolume(session.sets)
  }

  private formatDate(timestamp: number): string {
    const date: Date = new Date(timestamp)
    const year: number = date.getFullYear()
    const month: number = date.getMonth() + 1
    const day: number = date.getDate()
    return year.toString() + '-' + this.padTwoDigits(month) + '-' + this.padTwoDigits(day)
  }

  private padTwoDigits(value: number): string {
    if (value < 10) {
      return '0' + value.toString()
    }
    return value.toString()
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

    const rawValue: string = source.substring(valueStartIndex, valueEndIndex)
    const parsed: number = Number(rawValue)
    if (Number.isNaN(parsed)) {
      return fallbackValue
    }
    return Math.floor(parsed)
  }

  private getAdjustmentHint(averageCompletionRate: number): string {
    if (averageCompletionRate < 70) {
      return 'reduce_load'
    }
    if (averageCompletionRate >= 95) {
      return 'increase_load'
    }
    return 'keep_plan'
  }

  private getAdjustmentText(hint: string): string {
    if (hint === 'reduce_load') {
      return '完成率偏低，下次建议减少训练天数或缩短单次时长。'
    }
    if (hint === 'increase_load') {
      return '完成率很高，下次可以增加训练天数或延长单次时长。'
    }
    return '完成率稳定，下次保持当前计划即可。'
  }
}

export default new ReviewDashboardService()
