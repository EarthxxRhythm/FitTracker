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
  WeeklyStats,
  countDistinctPlanDays
} from '../../../main/ets/common/services/WorkoutSessionService'
import { TrainingDay } from '../../../main/ets/common/services/TrainingPlanService'

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

  setRawJson(json: string): void {
    this.sessionsJson = json
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
  const sets: SavedSet[] = [{ weight, reps, isWarmup: false }]
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

function createLegacyWarmupSession(id: string, createdAt: string): WorkoutSession {
  const session: WorkoutSession = {
    id,
    planId: 'plan_push_pull_legs',
    planName: 'Muscle Plan',
    dayLabel: 'Monday',
    startTime: 1000,
    endTime: 4600,
    durationSeconds: 3600,
    totalSets: 2,
    totalVolume: 1180,
    notes: 'warmup-pr-check',
    exercises: [{
      name: 'bench',
      targetMuscle: 'chest',
      sets: [
        { weight: 100, reps: 1, isWarmup: true },
        { weight: 60, reps: 3, isWarmup: false }
      ]
    }],
    createdAt
  }
  return session
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
        expect(weeklyStats.sets).assertEqual(2)
        expect(weeklyStats.volume).assertEqual(1030)
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
        expect(weeklyStats.sets).assertEqual(1)
        expect(weeklyStats.volume).assertEqual(500)
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

      it('should ignore warmup sets when deriving legacy exercise records', 0, async () => {
        const createdAt = createCurrentWeekDate(4)
        const session = createLegacyWarmupSession('session_warmup_record', createdAt)
        fakeStore.setSessions([session])

        const records = await WorkoutSessionService.getAllExerciseRecords(testContext)
        const benchRecord = findRecord(records, 'bench')

        expect(records.length).assertEqual(1)
        expect(benchRecord !== null).assertTrue()
        if (benchRecord !== null) {
          expect(benchRecord.bestWeight).assertEqual(60)
          expect(benchRecord.bestReps).assertEqual(3)
          expect(benchRecord.best1RM).assertEqual(calcEpley1RM(60, 3))
        }
      })

      it('should default missing warmup flags from older persisted payloads to false', 0, async () => {
        const createdAt = createCurrentWeekDate(5)
        fakeStore.setRawJson('[{"id":"legacy_missing_flag","planId":"plan_push_pull_legs","planName":"Muscle Plan",' +
          '"dayLabel":"Monday","startTime":1000,"endTime":4600,"durationSeconds":3600,"totalSets":1,' +
          '"totalVolume":240,"notes":"legacy","exercises":[{"name":"bench","targetMuscle":"chest",' +
          '"sets":[{"weight":80,"reps":8}]}],"createdAt":"' + createdAt + '"}]')

        const sessions = await WorkoutSessionService.getSessions(testContext)
        const records = await WorkoutSessionService.getAllExerciseRecords(testContext)
        const benchRecord = findRecord(records, 'bench')

        expect(sessions.length).assertEqual(1)
        expect(sessions[0].exercises.length).assertEqual(1)
        expect(sessions[0].exercises[0].sets.length).assertEqual(1)
        expect(sessions[0].exercises[0].sets[0].isWarmup).assertFalse()
        expect(benchRecord !== null).assertTrue()
        if (benchRecord !== null) {
          expect(benchRecord.best1RM).assertEqual(calcEpley1RM(80, 8))
        }
      })

      it('should dedupe training dates when multiple sessions share the same training day', 0, async () => {
        const duplicatedDate = createCurrentWeekDate(1)
        const uniqueDate = createCurrentWeekDate(2)
        fakeStore.setSessions([
          createSession('session_dup_1', duplicatedDate, 2, 120, 'a', 'bench', 60, 8),
          createSession('session_dup_2', duplicatedDate, 3, 180, 'b', 'row', 70, 8),
          createSession('session_unique', uniqueDate, 4, 260, 'c', 'squat', 80, 6)
        ])

        const trainingDates = await WorkoutSessionService.getTrainingDates(testContext)

        expect(trainingDates.length).assertEqual(2)
        expect(trainingDates[0]).assertEqual(duplicatedDate)
        expect(trainingDates[1]).assertEqual(uniqueDate)
      })

      it('should count only monday through sunday sessions in current week stats', 0, async () => {
        const monday = createCurrentWeekDate(0)
        const sunday = createCurrentWeekDate(6)
        const previousSunday = createCurrentWeekDate(-1)
        const nextMonday = createCurrentWeekDate(7)
        fakeStore.setSessions([
          createSession('session_previous_sunday', previousSunday, 1, 90, 'prev', 'press', 30, 10),
          createSession('session_monday', monday, 3, 240, 'monday', 'bench', 60, 8),
          createSession('session_sunday', sunday, 4, 400, 'sunday', 'squat', 100, 5),
          createSession('session_next_monday', nextMonday, 2, 120, 'next', 'row', 60, 6)
        ])

        const weeklyStats: WeeklyStats = await WorkoutSessionService.getWeeklyStats(testContext)

        expect(weeklyStats.count).assertEqual(2)
        expect(weeklyStats.duration).assertEqual(7200)
        expect(weeklyStats.sets).assertEqual(2)
        expect(weeklyStats.volume).assertEqual(980)
      })
    })

    // ============================================================
    // countDistinctPlanDays（数据一致性收口：按计划训练日去重）
    // ============================================================
    describe('countDistinctPlanDays', () => {
      const weekStart = '2026-11-02'
      const weekEnd = '2026-11-08'
      const days: TrainingDay[] = [
        { dayLabel: '周一 胸', exercises: [] },
        { dayLabel: '周三 背', exercises: [] },
        { dayLabel: '周五 腿', exercises: [] }
      ]

      function makeSession(id: string, planId: string, dayLabel: string, createdAt: string): WorkoutSession {
        const session: WorkoutSession = {
          id: id,
          planId: planId,
          planName: 'P',
          dayLabel: dayLabel,
          startTime: 1000,
          endTime: 2000,
          durationSeconds: 1000,
          totalSets: 1,
          totalVolume: 10,
          notes: '',
          exercises: [],
          createdAt: createdAt
        }
        return session
      }

      it('same dayLabel twice in one day counts as 1', 0, () => {
        const sessions: WorkoutSession[] = [
          makeSession('s1', 'p1', '周一 胸', '2026-11-03'),
          makeSession('s2', 'p1', '周一 胸', '2026-11-03')
        ]
        expect(countDistinctPlanDays(sessions, 'p1', days, weekStart, weekEnd)).assertEqual(1)
      })

      it('same dayLabel across two days still counts as 1 (keyed by plan day)', 0, () => {
        const sessions: WorkoutSession[] = [
          makeSession('s1', 'p1', '周一 胸', '2026-11-03'),
          makeSession('s2', 'p1', '周一 胸', '2026-11-05')
        ]
        expect(countDistinctPlanDays(sessions, 'p1', days, weekStart, weekEnd)).assertEqual(1)
      })

      it('empty dayLabel sessions are not counted', 0, () => {
        const sessions: WorkoutSession[] = [
          makeSession('s1', 'p1', '', '2026-11-03'),
          makeSession('s2', 'p1', '周一 胸', '2026-11-04')
        ]
        expect(countDistinctPlanDays(sessions, 'p1', days, weekStart, weekEnd)).assertEqual(1)
      })

      it('dayLabel outside current plan days is not counted', 0, () => {
        const sessions: WorkoutSession[] = [
          makeSession('s1', 'p1', '周一 胸', '2026-11-03'),
          makeSession('s2', 'p1', '周日 休息', '2026-11-04')
        ]
        expect(countDistinctPlanDays(sessions, 'p1', days, weekStart, weekEnd)).assertEqual(1)
      })

      it('other plan sessions and out-of-window sessions are excluded', 0, () => {
        const sessions: WorkoutSession[] = [
          makeSession('s1', 'p1', '周一 胸', '2026-11-03'),
          makeSession('s2', 'p2', '周一 胸', '2026-11-03'),
          makeSession('s3', 'p1', '周三 背', '2026-11-10')
        ]
        expect(countDistinctPlanDays(sessions, 'p1', days, weekStart, weekEnd)).assertEqual(1)
      })

      it('empty planId or empty days returns 0', 0, () => {
        const sessions: WorkoutSession[] = [
          makeSession('s1', 'p1', '周一 胸', '2026-11-03')
        ]
        const emptyDays: TrainingDay[] = []
        expect(countDistinctPlanDays(sessions, '', days, weekStart, weekEnd)).assertEqual(0)
        expect(countDistinctPlanDays(sessions, 'p1', emptyDays, weekStart, weekEnd)).assertEqual(0)
      })
    })
  })
}
