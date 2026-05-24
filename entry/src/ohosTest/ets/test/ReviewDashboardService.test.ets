import { describe, beforeEach, it, expect } from '@ohos/hypium'
import { WorkoutSession, createWorkoutSet } from '../../../main/ets/shared/models/TrainingModels'
import ReviewDashboardService, {
  ReviewDashboardSummary,
  ReviewRecentSessionRecord,
  ReviewTrendSummary
} from '../../../main/ets/shared/services/ReviewDashboardService'
import WorkoutRepository from '../../../main/ets/shared/services/WorkoutRepository'

export default function reviewDashboardServiceTest(): void {
  describe('ReviewDashboardService', () => {
    beforeEach(() => {
      WorkoutRepository.clear()
    })

    it('builds recent workout records and historical trend summary from saved sessions', 0, () => {
      WorkoutRepository.saveSession(WorkoutRepository.createSession(
        'session_review_1',
        'plan_review',
        'day_1',
        1714521600000,
        1714523400000,
        1800,
        2,
        500,
        0,
        'completed_sets=2;target_sets=4',
        [createWorkoutSet('set_review_1', 'ex_barbell_bench_press', 50, 10, 7, false)]
      ))
      WorkoutRepository.saveSession(WorkoutRepository.createSession(
        'session_review_2',
        'plan_review',
        'day_2',
        1715126400000,
        1715129100000,
        2700,
        3,
        900,
        0,
        'completed_sets=3;target_sets=5',
        [createWorkoutSet('set_review_2', 'ex_barbell_row', 60, 10, 8, false)]
      ))
      WorkoutRepository.saveSession(WorkoutRepository.createSession(
        'session_review_3',
        'plan_review',
        'day_3',
        1715731200000,
        1715734800000,
        3600,
        4,
        1200,
        0,
        'completed_sets=4;target_sets=5',
        [createWorkoutSet('set_review_3', 'ex_barbell_squat', 80, 10, 8, false)]
      ))

      const sessions: WorkoutSession[] = WorkoutRepository.getSessions()
      const summary: ReviewDashboardSummary = ReviewDashboardService.createSummary(sessions)

      expect(summary.recentRecords.length).assertEqual(3)
      const latestRecord: ReviewRecentSessionRecord = summary.recentRecords[0]
      expect(latestRecord.sessionId).assertEqual('session_review_3')
      expect(latestRecord.dayId).assertEqual('day_3')
      expect(latestRecord.dateText).assertEqual('2024-05-15')
      expect(latestRecord.durationText).assertEqual('1 小时')
      expect(latestRecord.completionText).assertEqual('4/5 组 · 80%')
      expect(latestRecord.volumeText).assertEqual('1200 kg')

      const trend: ReviewTrendSummary = summary.trendSummary
      expect(trend.hasTrend).assertTrue()
      expect(trend.recentSessionCount).assertEqual(2)
      expect(trend.previousSessionCount).assertEqual(1)
      expect(trend.recentTotalVolume).assertEqual(2100)
      expect(trend.previousTotalVolume).assertEqual(500)
      expect(trend.volumeTrendText).assertEqual('训练量上升 1600 kg')
      expect(trend.completionTrendText).assertEqual('完成率上升 20%')
      expect(trend.summaryText).assertEqual('最近 2 次训练量和完成率均高于此前记录。')
    })
  })
}
