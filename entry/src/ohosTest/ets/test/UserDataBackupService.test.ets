import { describe, expect, it } from '@ohos/hypium'
import { UserPlan } from '../../../main/ets/common/services/TrainingPlanService'
import UserDataBackupService, { UserDataBackupPackage } from '../../../main/ets/shared/services/UserDataBackupService'
import GoalSetupService from '../../../main/ets/shared/services/GoalSetupService'
import { UserGoal, WorkoutSession, createWorkoutSession, createWorkoutSet } from '../../../main/ets/shared/models/TrainingModels'

function createPlan(planId: string, enabledAt: number): UserPlan {
  const plan: UserPlan = {
    id: planId,
    name: '测试计划',
    coverColor: '#00C853',
    targetAudience: '测试',
    weeklyFrequency: '3天/周',
    days: [{
      dayLabel: '周一',
      dayOfWeek: [1],
      exercises: [{
        name: '杠铃卧推',
        targetMuscle: '胸部',
        sets: 4,
        reps: '8-10'
      }]
    }],
    enabledAt: enabledAt
  }
  return plan
}

function createSession(sessionId: string, weight: number): WorkoutSession {
  return createWorkoutSession(
    sessionId,
    'plan_backup',
    'day_1',
    1000,
    1900,
    900,
    1,
    weight * 8,
    0,
    'completed_sets=1;target_sets=1',
    [createWorkoutSet(sessionId + '_set_1', 'ex_barbell_bench_press', weight, 8, 8, false)]
  )
}

export default function userDataBackupServiceTest(): void {
  describe('UserDataBackupService', () => {
    it('parses a valid backup package and keeps key counts', 0, () => {
      const goal: UserGoal = GoalSetupService.createGoalFromSelection(
        'goal_backup',
        'strength',
        'intermediate',
        3,
        45,
        ['eq_bodyweight', 'eq_barbell'],
        [],
        1000
      )
      const backupPackage: UserDataBackupPackage = UserDataBackupService.createPackage(
        goal,
        [createPlan('plan_backup', 1000)],
        'plan_backup',
        [createSession('session_backup_1', 80)],
        2000
      )

      const parsed: UserDataBackupPackage | null = UserDataBackupService.parsePackageJson(JSON.stringify(backupPackage))

      expect(parsed !== null).assertTrue()
      if (parsed !== null) {
        expect(parsed.schemaVersion).assertEqual(1)
        expect(parsed.plans.length).assertEqual(1)
        expect(parsed.sessions.length).assertEqual(1)
        expect(parsed.currentPlanId).assertEqual('plan_backup')
        expect(parsed.goal !== null).assertTrue()
      }
    })

    it('merges imported sessions by sessionId and prefers imported copies', 0, () => {
      const existingSessions: WorkoutSession[] = [
        createSession('session_same', 70),
        createSession('session_keep', 75)
      ]
      const importedSessions: WorkoutSession[] = [
        createSession('session_same', 90),
        createSession('session_new', 95)
      ]

      const mergedSessions: WorkoutSession[] = UserDataBackupService.mergeSessions(existingSessions, importedSessions)

      expect(mergedSessions.length).assertEqual(3)
      expect(mergedSessions[0].sessionId).assertEqual('session_same')
      expect(mergedSessions[0].totalVolume).assertEqual(720)
      expect(mergedSessions[1].sessionId).assertEqual('session_keep')
      expect(mergedSessions[2].sessionId).assertEqual('session_new')
    })
  })
}
