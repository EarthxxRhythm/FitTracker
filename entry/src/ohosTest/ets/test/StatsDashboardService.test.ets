import { describe, it, expect } from '@ohos/hypium'
import { WorkoutSession, createWorkoutSession, createWorkoutSet } from '../../../main/ets/shared/models/TrainingModels'
import StatsDashboardService, {
  CalendarHeatmapDay,
  StatsDashboardSummary,
  WeeklyTrainingStats
} from '../../../main/ets/shared/services/StatsDashboardService'

export default function statsDashboardServiceTest(): void {
  describe('StatsDashboardService', () => {
    it('summarizes current week sessions and builds a calendar heatmap', 0, () => {
      const sessions: WorkoutSession[] = [
        createWorkoutSession(
          'session_stats_previous_week',
          'plan_stats',
          'day_1',
          1715472000000,
          1715473800000,
          1800,
          2,
          600,
          0,
          'completed_sets=2;target_sets=3',
          [createWorkoutSet('set_previous', 'ex_push_up', 30, 10, 7, false)]
        ),
        createWorkoutSession(
          'session_stats_monday',
          'plan_stats',
          'day_2',
          1715558400000,
          1715562000000,
          3600,
          3,
          900,
          0,
          'completed_sets=3;target_sets=3',
          [createWorkoutSet('set_monday', 'ex_squat', 60, 10, 8, false)]
        ),
        createWorkoutSession(
          'session_stats_wednesday',
          'plan_stats',
          'day_3',
          1715731200000,
          1715733000000,
          1800,
          4,
          1200,
          0,
          'completed_sets=4;target_sets=4',
          [createWorkoutSet('set_wednesday', 'ex_row', 80, 10, 8, false)]
        )
      ]

      const summary: StatsDashboardSummary = StatsDashboardService.createSummary(sessions, 1715817600000)
      const weekly: WeeklyTrainingStats = summary.weeklyStats
      expect(weekly.sessionCount).assertEqual(2)
      expect(weekly.totalDurationSeconds).assertEqual(5400)
      expect(weekly.totalDurationText).assertEqual('1 小时 30 分钟')
      expect(weekly.totalSets).assertEqual(7)
      expect(weekly.totalVolume).assertEqual(2100)
      expect(weekly.dateRangeText).assertEqual('2024-05-13 - 2024-05-19')

      expect(summary.heatmapDays.length).assertEqual(42)
      expect(summary.monthTitle).assertEqual('2024 年 5 月')

      const monday: CalendarHeatmapDay | undefined = StatsDashboardService.findHeatmapDay(summary.heatmapDays, '2024-05-13')
      expect(monday !== undefined).assertTrue()
      if (monday !== undefined) {
        expect(monday.sessionCount).assertEqual(1)
        expect(monday.totalVolume).assertEqual(900)
        expect(monday.level).assertEqual(2)
      }

      const wednesday: CalendarHeatmapDay | undefined =
        StatsDashboardService.findHeatmapDay(summary.heatmapDays, '2024-05-15')
      expect(wednesday !== undefined).assertTrue()
      if (wednesday !== undefined) {
        expect(wednesday.sessionCount).assertEqual(1)
        expect(wednesday.totalVolume).assertEqual(1200)
        expect(wednesday.level).assertEqual(3)
      }
    })
  })
}
