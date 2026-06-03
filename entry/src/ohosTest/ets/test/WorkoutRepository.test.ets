/**
 * WorkoutRepository 单元测试
 *
 * 功能 #11：训练记录更新、删除与恢复。
 */
import { beforeEach, describe, expect, it } from '@ohos/hypium'
import {
  WorkoutSession,
  createWorkoutSession,
  createWorkoutSet
} from '../../../main/ets/shared/models/TrainingModels'
import WorkoutRepository from '../../../main/ets/shared/services/WorkoutRepository'

function createSession(sessionId: string, weight: number, reps: number): WorkoutSession {
  return createWorkoutSession(
    sessionId,
    'plan_a',
    'day_1',
    1000,
    61000,
    60,
    1,
    weight * reps,
    0,
    'completed_sets=1;target_sets=1',
    [createWorkoutSet(sessionId + '_set_1', 'bench_press', weight, reps, 8, false)]
  )
}

export default function workoutRepositoryTest(): void {
  describe('WorkoutRepository', () => {
    beforeEach(() => {
      WorkoutRepository.clear()
    })

    it('updates saved session by sessionId', 0, () => {
      const originalSession: WorkoutSession = createSession('session_repo_update', 80, 8)
      const updatedSession: WorkoutSession = createSession('session_repo_update', 90, 6)

      WorkoutRepository.saveSession(originalSession)
      const updated: boolean = WorkoutRepository.updateSession(updatedSession)
      const storedSession: WorkoutSession | undefined = WorkoutRepository.getSessionById('session_repo_update')

      expect(updated).assertTrue()
      expect(storedSession !== undefined).assertTrue()
      if (storedSession !== undefined) {
        expect(storedSession.totalVolume).assertEqual(540)
        expect(storedSession.sets[0].weight).assertEqual(90)
      }
    })

    it('removes and restores a session once', 0, () => {
      const session: WorkoutSession = createSession('session_repo_restore', 100, 5)

      WorkoutRepository.saveSession(session)
      const removedSession: WorkoutSession | undefined = WorkoutRepository.removeSession('session_repo_restore')
      const restored: boolean = removedSession !== undefined ? WorkoutRepository.restoreSession(removedSession) : false
      const duplicateRestore: boolean = removedSession !== undefined ? WorkoutRepository.restoreSession(removedSession) : true
      const storedSession: WorkoutSession | undefined = WorkoutRepository.getSessionById('session_repo_restore')

      expect(removedSession !== undefined).assertTrue()
      expect(restored).assertTrue()
      expect(duplicateRestore).assertFalse()
      expect(storedSession !== undefined).assertTrue()
    })
  })
}
