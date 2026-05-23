/**
 * ReviewDashboardService - aggregates sessions for the MVP review dashboard.
 *
 * Feature #12: review dashboard and next adjustment hint.
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
}

class ReviewDashboardService {
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
      adjustmentText: this.getAdjustmentText(hint)
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
      adjustmentText: '先完成一次训练，再根据完成率调整下次计划。'
    }
    return summary
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
