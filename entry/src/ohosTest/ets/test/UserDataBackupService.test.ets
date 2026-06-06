import { abilityDelegatorRegistry } from '@kit.TestKit'
import { afterAll, beforeAll, beforeEach, describe, expect, it } from '@ohos/hypium'
import TrainingPlanService, { UserPlan } from '../../../main/ets/common/services/TrainingPlanService'
import WorkoutSessionService, { SessionPreferencesStore } from '../../../main/ets/common/services/WorkoutSessionService'
import GoalRepository from '../../../main/ets/shared/services/GoalRepository'
import UserDataBackupService, { UserDataBackupPackage } from '../../../main/ets/shared/services/UserDataBackupService'
import GoalSetupService from '../../../main/ets/shared/services/GoalSetupService'
import WorkoutRepository from '../../../main/ets/shared/services/WorkoutRepository'
import WorkoutSessionPersistenceBridgeService from '../../../main/ets/features/workout/services/WorkoutSessionPersistenceBridgeService'
import { UserGoal, WorkoutSession, createWorkoutSession, createWorkoutSet } from '../../../main/ets/shared/models/TrainingModels'

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

  clear(): void {
    this.sessionsJson = '[]'
  }
}

function getTestContext(): Context {
  return abilityDelegatorRegistry.getAbilityDelegator().getAppContext()
}

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

async function resetPersistedData(): Promise<void> {
  WorkoutRepository.clear()
  await GoalRepository.clearSavedGoal(getTestContext())
  await TrainingPlanService.replaceMyPlans(getTestContext(), [], '')
  await WorkoutSessionPersistenceBridgeService.replacePersistedSessions(getTestContext(), [])
}

export default function userDataBackupServiceTest(): void {
  const fakeStore = new FakePreferencesStore()
  describe('UserDataBackupService', () => {
    beforeAll(() => {
      WorkoutSessionService.setStoreForTesting(fakeStore)
    })

    beforeEach(() => {
      fakeStore.clear()
      WorkoutRepository.clear()
    })

    afterAll(() => {
      WorkoutSessionService.setStoreForTesting(null)
    })

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

    it('rejects unsupported backup schema versions with null parse result', 0, () => {
      const goal: UserGoal = GoalSetupService.createGoalFromSelection(
        'goal_backup_schema',
        'strength',
        'intermediate',
        3,
        45,
        ['eq_bodyweight'],
        [],
        1000
      )
      const backupPackage: UserDataBackupPackage = UserDataBackupService.createPackage(
        goal,
        [createPlan('plan_schema', 1000)],
        'plan_schema',
        [createSession('session_schema', 85)],
        2000
      )
      const unsupportedPackage: UserDataBackupPackage = {
        schemaVersion: 99,
        exportedAt: backupPackage.exportedAt,
        goal: backupPackage.goal,
        plans: backupPackage.plans,
        currentPlanId: backupPackage.currentPlanId,
        sessions: backupPackage.sessions,
        contentMeta: backupPackage.contentMeta
      }
      const unsupportedJson: string = JSON.stringify(unsupportedPackage)

      const parsed: UserDataBackupPackage | null = UserDataBackupService.parsePackageJson(unsupportedJson)

      expect(parsed).assertNull()
    })

    it('rejects unsupported schema imports without mutating existing local data', 0, async () => {
      await resetPersistedData()

      const localGoal: UserGoal = GoalSetupService.createGoalFromSelection(
        'goal_local_protected',
        'fat_loss',
        'beginner',
        2,
        30,
        ['eq_bodyweight'],
        [],
        4000
      )
      await GoalRepository.saveGoal(getTestContext(), localGoal)
      await TrainingPlanService.replaceMyPlans(getTestContext(), [createPlan('plan_local_protected', 1000)], 'plan_local_protected')
      await WorkoutSessionPersistenceBridgeService.replacePersistedSessions(getTestContext(), [createSession('session_local_protected', 70)])

      const backupPackage: UserDataBackupPackage = UserDataBackupService.createPackage(
        null,
        [createPlan('plan_import_unsupported', 3000)],
        'plan_import_unsupported',
        [createSession('session_import_unsupported', 95)],
        7000
      )
      const unsupportedPackage: UserDataBackupPackage = {
        schemaVersion: 99,
        exportedAt: backupPackage.exportedAt,
        goal: backupPackage.goal,
        plans: backupPackage.plans,
        currentPlanId: backupPackage.currentPlanId,
        sessions: backupPackage.sessions,
        contentMeta: backupPackage.contentMeta
      }

      const importResult = await UserDataBackupService.importPackage(getTestContext(), JSON.stringify(unsupportedPackage))
      const savedGoal: UserGoal | undefined = await GoalRepository.loadGoal(getTestContext())
      const currentPlanId: string = await TrainingPlanService.getCurrentPlanId(getTestContext())
      const sessions: WorkoutSession[] = await WorkoutSessionPersistenceBridgeService.loadPersistedSessions(getTestContext())

      expect(importResult.success).assertFalse()
      expect(importResult.statusId).assertEqual('backup_schema_unsupported')
      expect(savedGoal !== undefined).assertTrue()
      if (savedGoal !== undefined) {
        expect(savedGoal.goalId).assertEqual('goal_local_protected')
      }
      expect(currentPlanId).assertEqual('plan_local_protected')
      expect(sessions.length).assertEqual(1)
      expect(sessions[0].sessionId).assertEqual('session_local_protected')

      await resetPersistedData()
    })

    it('returns stable failure result for empty or invalid backup json', 0, async () => {
      const emptyResult = await UserDataBackupService.importPackage(getTestContext(), '   ')
      const invalidResult = await UserDataBackupService.importPackage(getTestContext(), '{"schemaVersion":1')

      expect(emptyResult.success).assertFalse()
      expect(emptyResult.statusId).assertEqual('backup_invalid_json')
      expect(emptyResult.statusText).assertEqual('备份包格式无效，无法导入。')
      expect(invalidResult.success).assertFalse()
      expect(invalidResult.statusId).assertEqual('backup_invalid_json')
      expect(invalidResult.statusText).assertEqual('备份包格式无效，无法导入。')
    })

    it('normalizes invalid current plan id to the first available imported plan', 0, () => {
      const normalized = UserDataBackupService.normalizePlanSelection(
        [createPlan('plan_first', 1000), createPlan('plan_second', 2000)],
        'plan_missing'
      )

      expect(normalized.currentPlanId).assertEqual('plan_first')
      expect(normalized.usedFallback).assertTrue()
      expect(normalized.plans.length).assertEqual(2)
    })

    it('imports backup package and falls back current plan id when it is missing', 0, async () => {
      await resetPersistedData()

      const goal: UserGoal = GoalSetupService.createGoalFromSelection(
        'goal_backup_import',
        'strength',
        'intermediate',
        4,
        60,
        ['eq_barbell'],
        [],
        5000
      )
      const backupPackage: UserDataBackupPackage = UserDataBackupService.createPackage(
        goal,
        [createPlan('plan_import_first', 3000)],
        'plan_missing',
        [createSession('session_import_1', 100)],
        6000
      )

      const importResult = await UserDataBackupService.importPackage(getTestContext(), JSON.stringify(backupPackage))
      const currentPlanId: string = await TrainingPlanService.getCurrentPlanId(getTestContext())
      const savedGoal: UserGoal | undefined = await GoalRepository.loadGoal(getTestContext())
      const sessions: WorkoutSession[] = await WorkoutSessionPersistenceBridgeService.loadPersistedSessions(getTestContext())

      expect(importResult.success).assertTrue()
      expect(importResult.usedPlanFallback).assertTrue()
      expect(importResult.effectiveCurrentPlanId).assertEqual('plan_import_first')
      expect(currentPlanId).assertEqual('plan_import_first')
      expect(savedGoal !== undefined).assertTrue()
      expect(sessions.length).assertEqual(1)
      expect(sessions[0].sessionId).assertEqual('session_import_1')

      await resetPersistedData()
    })

    it('imports backup package with goal override semantics and session dedupe merge', 0, async () => {
      await resetPersistedData()

      const localGoal: UserGoal = GoalSetupService.createGoalFromSelection(
        'goal_local_existing',
        'fat_loss',
        'beginner',
        2,
        30,
        ['eq_bodyweight'],
        [],
        4000
      )
      await GoalRepository.saveGoal(getTestContext(), localGoal)
      await TrainingPlanService.replaceMyPlans(getTestContext(), [createPlan('plan_local_existing', 1000)], 'plan_local_existing')
      await WorkoutSessionPersistenceBridgeService.replacePersistedSessions(getTestContext(), [createSession('session_same', 70)])

      const backupPackage: UserDataBackupPackage = UserDataBackupService.createPackage(
        null,
        [createPlan('plan_import_override', 3000)],
        'plan_import_override',
        [createSession('session_same', 95)],
        7000
      )

      const importResult = await UserDataBackupService.importPackage(getTestContext(), JSON.stringify(backupPackage))
      const savedGoal: UserGoal | undefined = await GoalRepository.loadGoal(getTestContext())
      const currentPlanId: string = await TrainingPlanService.getCurrentPlanId(getTestContext())
      const sessions: WorkoutSession[] = await WorkoutSessionPersistenceBridgeService.loadPersistedSessions(getTestContext())

      expect(importResult.success).assertTrue()
      expect(importResult.usedPlanFallback).assertFalse()
      expect(savedGoal).assertUndefined()
      expect(currentPlanId).assertEqual('plan_import_override')
      expect(sessions.length).assertEqual(1)
      expect(sessions[0].sessionId).assertEqual('session_same')
      expect(sessions[0].totalVolume).assertEqual(760)

      await resetPersistedData()
    })
  })
}
