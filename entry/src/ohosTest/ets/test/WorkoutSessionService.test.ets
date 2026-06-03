/**
 * WorkoutSessionService 单元测试
 * 功能 #26、#28-#32：覆盖训练记录持久化编辑、删除与基础统计一致性
 */
import { describe, beforeAll, beforeEach, afterAll, it, expect } from '@ohos/hypium'
import WorkoutSessionService, {
  ExerciseRecord,
  SavedSet,
  SessionPreferencesStore,
  WorkoutSession,
  WeeklyStats
} from '../../../main/ets/common/services/WorkoutSessionService'

const KEY_SESSIONS = 'sessions'

class FakePreferencesStore extends SessionPreferencesStore {
  private sessionsJson: string = '[]'

  async get(key: string, defaultValue: string): Promise<string> {
    if (key === KEY_SESSIONS) {
      return this.sessionsJson
    }
    return defaultValue
  }

  async put(key: string, value: string): Promise<void> {
    if (key === KEY_SESSIONS) {
      this.sessionsJson = value
    }
  }

  async flush(): Promise<void> {
  }

  setSessions(sessions: WorkoutSession[]): void {
    this.sessionsJson = JSON.stringify(sessions)
  }
}

function calcEpley1RM(weight: number, reps: number): number {
  return Math.round(weight * (1 + reps / 30))
}

function formatDate(date: Date): string {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
}

function createCurrentWeekDate(offsetDays: number): string {
  const now = new Date()
  const dayOfWeek = now.getDay()
  const mondayOffset = dayOfWeek === 0 ? 6 : dayOfWeek - 1
  const monday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - mondayOffset)
  const target = new Date(monday.getTime() + offsetDays * 24 * 60 * 60 * 1000)
  return formatDate(target)
}

function createSession(
  id: string,
  createdAt: string,
  totalSets: number,
  totalVolume: number,
  notes: string,
  exerciseName: string,
  weight: number,
  reps: number
): WorkoutSession {
  const sets: SavedSet[] = [{ weight, reps }]
  return {
    id,
    planId: 'plan_push_pull_legs',
    planName: 'Muscle Plan',
    dayLabel: 'Monday',
    startTime: 1000,
    endTime: 4600,
    durationSeconds: 3600,
    totalSets,
    totalVolume,
    notes,
    exercises: [{
      name: exerciseName,
      targetMuscle: 'chest',
      sets
    }],
    createdAt
  }
}

function findRecord(records: ExerciseRecord[], exerciseName: string): ExerciseRecord | null {
  for (const record of records) {
    if (record.exerciseName === exerciseName) {
      return record
    }
  }
  return null
}

export default function workoutSessionLogicTest(): void {
  const fakeStore = new FakePreferencesStore()
  const testContext: Context = {} as Context

  describe('WorkoutSessionService', () => {
    beforeAll(() => {
      WorkoutSessionService.setStoreForTesting(fakeStore)
    })

    beforeEach(() => {
      fakeStore.setSessions([])
    })

    afterAll(() => {
      WorkoutSessionService.setStoreForTesting(null)
    })

    describe('Epley 1RM Formula', () => {
      it('5 reps at 100kg should round to 117', 0, () => {
        expect(calcEpley1RM(100, 5)).assertEqual(117)
      })

      it('0 reps should return weight', 0, () => {
        expect(calcEpley1RM(100, 0)).assertEqual(100)
      })
    })

    describe('Session mutation persistence', () => {
      it('should replace a saved session by id and keep derived stats consistent', 0, async () => {
        const createdAt = createCurrentWeekDate(0)
        const originalSession = createSession('session_1', createdAt, 3, 300, 'original note', 'squat', 100, 5)
        const untouchedSession = createSession('session_2', createdAt, 2, 120, 'keep note', 'bench', 60, 8)
        const updatedSession = createSession('session_1', createdAt, 4, 360, 'updated note', 'squat', 110, 5)

        fakeStore.setSessions([originalSession, untouchedSession])

        const updated = await WorkoutSessionService.updateSession(testContext, updatedSession)
        const sessions = await WorkoutSessionService.getSessions(testContext)
        const weeklyStats: WeeklyStats = await WorkoutSessionService.getWeeklyStats(testContext)
        const records = await WorkoutSessionService.getAllExerciseRecords(testContext)
        const squatRecord = findRecord(records, 'squat')

        expect(updated).assertTrue()
        expect(sessions.length).assertEqual(2)
        expect(sessions[0].notes).assertEqual('updated note')
        expect(sessions[0].totalSets).assertEqual(4)
        expect(sessions[0].totalVolume).assertEqual(360)
        expect(weeklyStats.count).assertEqual(2)
        expect(weeklyStats.sets).assertEqual(6)
        expect(weeklyStats.volume).assertEqual(480)
        expect(squatRecord !== null).assertTrue()
        if (squatRecord !== null) {
          expect(squatRecord.best1RM).assertEqual(calcEpley1RM(110, 5))
          expect(squatRecord.bestDate).assertEqual(createdAt)
        }
      })

      it('should return false when updating a missing session id and keep stored data unchanged', 0, async () => {
        const createdAt = createCurrentWeekDate(1)
        const existingSession = createSession('session_kept', createdAt, 3, 240, 'keep', 'deadlift', 120, 3)
        const missingSession = createSession('session_missing', createdAt, 8, 800, 'missing', 'deadlift', 140, 2)

        fakeStore.setSessions([existingSession])

        const updated = await WorkoutSessionService.updateSession(testContext, missingSession)
        const sessions = await WorkoutSessionService.getSessions(testContext)

        expect(updated).assertFalse()
        expect(sessions.length).assertEqual(1)
        expect(sessions[0].id).assertEqual('session_kept')
        expect(sessions[0].notes).assertEqual('keep')
        expect(sessions[0].totalVolume).assertEqual(240)
      })

      it('should remove a saved session and update sessions records and weekly stats', 0, async () => {
        const createdAt = createCurrentWeekDate(2)
        const benchSession = createSession('session_bench', createdAt, 3, 240, 'bench day', 'bench', 80, 8)
        const squatSession = createSession('session_squat', createdAt, 4, 400, 'squat day', 'squat', 100, 5)

        fakeStore.setSessions([benchSession, squatSession])

        const removedSession = await WorkoutSessionService.removeSession(testContext, 'session_bench')
        const sessions = await WorkoutSessionService.getSessions(testContext)
        const weeklyStats: WeeklyStats = await WorkoutSessionService.getWeeklyStats(testContext)
        const records = await WorkoutSessionService.getAllExerciseRecords(testContext)
        const benchRecord = findRecord(records, 'bench')
        const squatRecord = findRecord(records, 'squat')

        expect(removedSession !== null).assertTrue()
        if (removedSession !== null) {
          expect(removedSession.id).assertEqual('session_bench')
        }
        expect(sessions.length).assertEqual(1)
        expect(sessions[0].id).assertEqual('session_squat')
        expect(weeklyStats.count).assertEqual(1)
        expect(weeklyStats.sets).assertEqual(4)
        expect(weeklyStats.volume).assertEqual(400)
        expect(benchRecord === null).assertTrue()
        expect(squatRecord !== null).assertTrue()
      })

      it('should restore a removed session only once for undo flows', 0, async () => {
        const createdAt = createCurrentWeekDate(3)
        const removedCandidate = createSession('session_restore', createdAt, 2, 140, 'restore me', 'row', 70, 6)

        fakeStore.setSessions([])

        const firstRestore = await WorkoutSessionService.restoreSession(testContext, removedCandidate)
        const duplicateRestore = await WorkoutSessionService.restoreSession(testContext, removedCandidate)
        const sessions = await WorkoutSessionService.getSessions(testContext)

        expect(firstRestore).assertTrue()
        expect(duplicateRestore).assertFalse()
        expect(sessions.length).assertEqual(1)
        expect(sessions[0].id).assertEqual('session_restore')
      })
    })
  })
}
