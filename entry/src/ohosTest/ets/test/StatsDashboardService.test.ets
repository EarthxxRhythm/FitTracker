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
      expect(weekly.totalSets).assertEqual(2)
      expect(weekly.totalVolume).assertEqual(1400)
      expect(weekly.dateRangeText).assertEqual('2024-05-13 - 2024-05-19')

      expect(summary.heatmapDays.length).assertEqual(42)
      expect(summary.monthTitle).assertEqual('2024 年 5 月')

      const monday: CalendarHeatmapDay | undefined = StatsDashboardService.findHeatmapDay(summary.heatmapDays, '2024-05-13')
      expect(monday !== undefined).assertTrue()
      if (monday !== undefined) {
        expect(monday.sessionCount).assertEqual(1)
        expect(monday.totalVolume).assertEqual(600)
        expect(monday.level).assertEqual(2)
      }

      const wednesday: CalendarHeatmapDay | undefined =
        StatsDashboardService.findHeatmapDay(summary.heatmapDays, '2024-05-15')
      expect(wednesday !== undefined).assertTrue()
      if (wednesday !== undefined) {
        expect(wednesday.sessionCount).assertEqual(1)
        expect(wednesday.totalVolume).assertEqual(800)
        expect(wednesday.level).assertEqual(2)
      }
    })

    it('uses inclusive week boundaries and falls back to set volume when session volume is zero', 0, () => {
      const sessions: WorkoutSession[] = [
        createWorkoutSession(
          'session_previous_sunday',
          'plan_stats',
          'day_prev',
          Date.UTC(2024, 4, 12, 8, 0, 0),
          Date.UTC(2024, 4, 12, 8, 30, 0),
          1800,
          2,
          999,
          0,
          'completed_sets=2;target_sets=2',
          [createWorkoutSet('set_previous_sunday', 'ex_press', 30, 10, 7, false)]
        ),
        createWorkoutSession(
          'session_monday_fallback',
          'plan_stats',
          'day_monday',
          Date.UTC(2024, 4, 13, 8, 0, 0),
          Date.UTC(2024, 4, 13, 8, 45, 0),
          2700,
          3,
          0,
          0,
          'completed_sets=3;target_sets=3',
          [createWorkoutSet('set_monday_fallback', 'ex_press', 50, 10, 8, false)]
        ),
        createWorkoutSession(
          'session_sunday_inclusive',
          'plan_stats',
          'day_sunday',
          Date.UTC(2024, 4, 19, 8, 0, 0),
          Date.UTC(2024, 4, 19, 9, 0, 0),
          3600,
          4,
          800,
          0,
          'completed_sets=4;target_sets=4',
          [createWorkoutSet('set_sunday_inclusive', 'ex_row', 80, 5, 8, false)]
        ),
        createWorkoutSession(
          'session_next_monday',
          'plan_stats',
          'day_next',
          Date.UTC(2024, 4, 20, 8, 0, 0),
          Date.UTC(2024, 4, 20, 8, 20, 0),
          1200,
          1,
          200,
          0,
          'completed_sets=1;target_sets=1',
          [createWorkoutSet('set_next_monday', 'ex_curl', 20, 10, 7, false)]
        )
      ]

      const summary: StatsDashboardSummary = StatsDashboardService.createSummary(sessions, Date.UTC(2024, 4, 16, 12, 0, 0))
      const weekly: WeeklyTrainingStats = summary.weeklyStats

      expect(weekly.weekStartText).assertEqual('2024-05-13')
      expect(weekly.weekEndText).assertEqual('2024-05-19')
      expect(weekly.sessionCount).assertEqual(2)
      expect(weekly.totalDurationSeconds).assertEqual(6300)
      expect(weekly.totalSets).assertEqual(2)
      expect(weekly.totalVolume).assertEqual(900)
    })

    it('maps heatmap levels at each threshold edge', 0, () => {
      const sessions: WorkoutSession[] = [
        createWorkoutSession(
          'session_level_1',
          'plan_stats',
          'day_1',
          Date.UTC(2024, 4, 13, 8, 0, 0),
          Date.UTC(2024, 4, 13, 8, 10, 0),
          600,
          1,
          500,
          0,
          'completed_sets=1;target_sets=1',
          [createWorkoutSet('set_level_1', 'ex_1', 50, 10, 7, false)]
        ),
        createWorkoutSession(
          'session_level_2',
          'plan_stats',
          'day_2',
          Date.UTC(2024, 4, 14, 8, 0, 0),
          Date.UTC(2024, 4, 14, 8, 10, 0),
          600,
          1,
          1000,
          0,
          'completed_sets=1;target_sets=1',
          [createWorkoutSet('set_level_2', 'ex_2', 100, 10, 7, false)]
        ),
        createWorkoutSession(
          'session_level_3',
          'plan_stats',
          'day_3',
          Date.UTC(2024, 4, 15, 8, 0, 0),
          Date.UTC(2024, 4, 15, 8, 10, 0),
          600,
          1,
          1500,
          0,
          'completed_sets=1;target_sets=1',
          [createWorkoutSet('set_level_3', 'ex_3', 150, 10, 7, false)]
        ),
        createWorkoutSession(
          'session_level_4',
          'plan_stats',
          'day_4',
          Date.UTC(2024, 4, 16, 8, 0, 0),
          Date.UTC(2024, 4, 16, 8, 10, 0),
          600,
          1,
          1501,
          0,
          'completed_sets=1;target_sets=1',
          [createWorkoutSet('set_level_4', 'ex_4', 151, 10, 7, false)]
        )
      ]

      const summary: StatsDashboardSummary = StatsDashboardService.createSummary(sessions, Date.UTC(2024, 4, 16, 12, 0, 0))
      const levelOne: CalendarHeatmapDay | undefined = StatsDashboardService.findHeatmapDay(summary.heatmapDays, '2024-05-13')
      const levelTwo: CalendarHeatmapDay | undefined = StatsDashboardService.findHeatmapDay(summary.heatmapDays, '2024-05-14')
      const levelThree: CalendarHeatmapDay | undefined = StatsDashboardService.findHeatmapDay(summary.heatmapDays, '2024-05-15')
      const levelFour: CalendarHeatmapDay | undefined = StatsDashboardService.findHeatmapDay(summary.heatmapDays, '2024-05-16')

      expect(levelOne !== undefined).assertTrue()
      expect(levelTwo !== undefined).assertTrue()
      expect(levelThree !== undefined).assertTrue()
      expect(levelFour !== undefined).assertTrue()
      if (levelOne !== undefined && levelTwo !== undefined && levelThree !== undefined && levelFour !== undefined) {
        expect(levelOne.level).assertEqual(1)
        expect(levelTwo.level).assertEqual(2)
        expect(levelThree.level).assertEqual(3)
        expect(levelFour.level).assertEqual(4)
      }
    })
  })
}
