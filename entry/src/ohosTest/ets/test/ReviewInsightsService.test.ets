import { describe, expect, it } from '@ohos/hypium'
import { WorkoutSession } from '../../../main/ets/shared/models/TrainingModels'
import ReviewInsightsService from '../../../main/ets/shared/services/ReviewInsightsService'

function createSession(sessionId: string, startedAt: number): WorkoutSession {
  const session: WorkoutSession = {
    sessionId: sessionId,
    planId: 'plan_review',
    dayId: 'push_day',
    startedAt: startedAt,
    endedAt: startedAt + 1800 * 1000,
    durationSeconds: 1800,
    totalSets: 4,
    totalVolume: 320,
    fatigueScore: 3,
    notes: 'completed_sets=4;target_sets=4',
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
  })
}
