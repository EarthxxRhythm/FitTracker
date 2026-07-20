import { describe, expect, it } from '@ohos/hypium'
import { WorkoutSession, createWorkoutSet } from '../../../main/ets/shared/models/TrainingModels'
import ReviewInsightsService from '../../../main/ets/shared/services/ReviewInsightsService'

function createSession(
  sessionId: string,
  startedAt: number,
  dayId: string = 'push_day',
  totalVolume: number = 320,
  durationSeconds: number = 1800,
  notes: string = 'completed_sets=4;target_sets=4'
): WorkoutSession {
  const session: WorkoutSession = {
    sessionId: sessionId,
    planId: 'plan_review',
    dayId: dayId,
    startedAt: startedAt,
    endedAt: startedAt + durationSeconds * 1000,
    durationSeconds: durationSeconds,
    totalSets: 4,
    totalVolume: totalVolume,
    fatigueScore: 3,
    notes: notes,
    sets: [
      {
        setId: sessionId + '_set_1',
        exerciseId: 'bench_press',
        weight: 80,
        reps: 4,
        rpe: 8,
        isWarmup: false
      }
    ]
  }
  return session
}

export default function reviewInsightsServiceTest(): void {
  describe('ReviewInsightsService', () => {
    it('marks all history filter as locked for free history access', 0, () => {
      const now: number = Date.UTC(2026, 5, 10)
      const filters = ReviewInsightsService.createRecentFilters(
        [createSession('recent', now - 2 * 24 * 60 * 60 * 1000)],
        now,
        false
      )

      expect(filters.length).assertEqual(3)
      expect(filters[2].filterId).assertEqual('all_sessions')
      expect(filters[2].locked).assertTrue()
      expect(ReviewInsightsService.resolveFilterId('all_sessions', false)).assertEqual('recent_30_days')
    })

    it('keeps all history unlocked for pro history access', 0, () => {
      const now: number = Date.UTC(2026, 5, 10)
      const filters = ReviewInsightsService.createRecentFilters(
        [createSession('recent', now - 2 * 24 * 60 * 60 * 1000)],
        now,
        true
      )

      expect(filters[2].locked).assertFalse()
      expect(ReviewInsightsService.resolveFilterId('all_sessions', true)).assertEqual('all_sessions')
    })

    it('falls back to recent 30 days when free users request all history', 0, () => {
      const now: number = Date.UTC(2026, 5, 10)
      const sessions: WorkoutSession[] = [
        createSession('recent', now - 5 * 24 * 60 * 60 * 1000),
        createSession('older_than_30_days', now - 45 * 24 * 60 * 60 * 1000)
      ]

      const freeRecords = ReviewInsightsService.filterRecentRecords(sessions, 'all_sessions', now, false)
      const proRecords = ReviewInsightsService.filterRecentRecords(sessions, 'all_sessions', now, true)

      expect(freeRecords.length).assertEqual(1)
      expect(freeRecords[0].sessionId).assertEqual('recent')
      expect(proRecords.length).assertEqual(2)
    })

    it('keeps the latest six matching records in reverse chronological save order', 0, () => {
      const now: number = Date.UTC(2026, 5, 10)
      const sessions: WorkoutSession[] = [
        createSession('session_1', now - 8 * 24 * 60 * 60 * 1000),
        createSession('session_2', now - 7 * 24 * 60 * 60 * 1000),
        createSession('session_3', now - 6 * 24 * 60 * 60 * 1000),
        createSession('session_4', now - 5 * 24 * 60 * 60 * 1000),
        createSession('session_5', now - 4 * 24 * 60 * 60 * 1000),
        createSession('session_6', now - 3 * 24 * 60 * 60 * 1000),
        createSession('session_7', now - 2 * 24 * 60 * 60 * 1000),
        createSession('session_8', now - 1 * 24 * 60 * 60 * 1000)
      ]

      const records = ReviewInsightsService.filterRecentRecords(sessions, 'recent_7_days', now, true)

      expect(records.length).assertEqual(6)
      expect(records[0].sessionId).assertEqual('session_8')
      expect(records[0].dayLabel).assertEqual('推日')
      expect(records[1].sessionId).assertEqual('session_7')
      expect(records[5].sessionId).assertEqual('session_3')
    })

    it('builds weekly trend items with fallback volume, completion rate, dominant day and delta summary', 0, () => {
      const now: number = Date.UTC(2026, 5, 12, 12, 0, 0)
      const sessions: WorkoutSession[] = [
        createSession(
          'previous_week',
          Date.UTC(2026, 5, 2, 9, 0, 0),
          'lower_day',
          600,
          1800,
          'completed_sets=2;target_sets=4'
        ),
        createSession(
          'current_week_light',
          Date.UTC(2026, 5, 9, 9, 0, 0),
          'push_day',
          0,
          1800,
          'completed_sets=3;target_sets=4'
        ),
        createSession(
          'current_week_heavy',
          Date.UTC(2026, 5, 11, 9, 0, 0),
          'pull_day',
          400,
          2400,
          'completed_sets=2;target_sets=2'
        )
      ]
      sessions[0].sets[0].weight = 100
      sessions[0].sets[0].reps = 3
      sessions[0].sets.push(createWorkoutSet('previous_week_set_2', 'bench_press', 100, 3, 8, false))
      sessions[1].sets[0].weight = 58
      sessions[1].sets[0].reps = 5
      sessions[1].sets.push(createWorkoutSet('current_week_light_set_2', 'bench_press', 1, 5, 8, false))
      sessions[1].sets.push(createWorkoutSet('current_week_light_set_3', 'bench_press', 1, 5, 8, false))
      sessions[2].sets.push(createWorkoutSet('current_week_heavy_set_2', 'bench_press', 40, 2, 8, false))

      const items = ReviewInsightsService.createWeeklyTrendItems(sessions, now)
      const currentWeek = items[0]
      const previousWeek = items[1]

      expect(items.length).assertEqual(6)
      expect(currentWeek.weekId).assertEqual('2026-06-08')
      expect(currentWeek.sessionCount).assertEqual(2)
      expect(currentWeek.totalDurationSeconds).assertEqual(4200)
      expect(currentWeek.totalVolume).assertEqual(700)
      expect(currentWeek.completionRate).assertEqual(83)
      expect(currentWeek.dominantDayId).assertEqual('pull_day')
      expect(currentWeek.dominantDayLabel).assertEqual('拉日')
      expect(currentWeek.summaryText.indexOf('100') >= 0).assertTrue()
      expect(currentWeek.summaryText.indexOf('33') >= 0).assertTrue()

      expect(previousWeek.weekId).assertEqual('2026-06-01')
      expect(previousWeek.sessionCount).assertEqual(1)
      expect(previousWeek.totalVolume).assertEqual(600)
      expect(previousWeek.completionRate).assertEqual(50)
    })

    it('formats generated and named day ids for weekly review outputs', 0, () => {
      const now: number = Date.UTC(2026, 5, 12, 12, 0, 0)
      const sessions: WorkoutSession[] = [
        createSession('named_day', Date.UTC(2026, 5, 10, 9, 0, 0), 'push_day', 320, 1800),
        createSession('generated_day', Date.UTC(2026, 5, 11, 9, 0, 0), 'day_2', 500, 2100)
      ]

      const records = ReviewInsightsService.filterRecentRecords(sessions, 'recent_7_days', now, true)
      const trendItems = ReviewInsightsService.createWeeklyTrendItems(sessions, now)

      expect(records[0].sessionId).assertEqual('generated_day')
      expect(records[0].dayLabel).assertEqual('第 2 天')
      expect(records[1].dayLabel).assertEqual('推日')
      expect(trendItems[0].dominantDayId).assertEqual('day_2')
      expect(trendItems[0].dominantDayLabel).assertEqual('第 2 天')
    })
  })
}
