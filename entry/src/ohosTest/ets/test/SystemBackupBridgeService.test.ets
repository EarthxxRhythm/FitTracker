import { fileIo } from '@kit.CoreFileKit'
import { abilityDelegatorRegistry } from '@kit.TestKit'
import { afterAll, beforeAll, beforeEach, describe, expect, it } from '@ohos/hypium'
import TrainingPlanService, { UserPlan } from '../../../main/ets/common/services/TrainingPlanService'
import WorkoutSessionService, { SessionPreferencesStore } from '../../../main/ets/common/services/WorkoutSessionService'
import GoalRepository from '../../../main/ets/shared/services/GoalRepository'
import GoalSetupService from '../../../main/ets/shared/services/GoalSetupService'
import {
  createBackupCallbackResult,
  createBackupProcessInfo,
  createIdleBackupProcessInfo
} from '../../../main/ets/entrybackupability/EntryBackupAbility'
import SystemBackupBridgeService, {
  SystemBackupBridgeResult
} from '../../../main/ets/shared/services/SystemBackupBridgeService'
import UserDataBackupService from '../../../main/ets/shared/services/UserDataBackupService'
import WorkoutRepository from '../../../main/ets/shared/services/WorkoutRepository'
import WorkoutSessionPersistenceBridgeService from '../../../main/ets/features/workout/services/WorkoutSessionPersistenceBridgeService'
import {
  UserGoal,
  WorkoutSession,
  createWorkoutSession,
  createWorkoutSet
} from '../../../main/ets/shared/models/TrainingModels'

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
    'plan_backup_bridge',
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

function createBackupDirPath(testName: string): string {
  return getTestContext().filesDir + '/backup-bridge-' + testName + '-' + Date.now().toString()
}

function createBridgeResult(success: boolean, detailText: string): SystemBackupBridgeResult {
  const result: SystemBackupBridgeResult = {
    success: success,
    statusId: success ? 'backup_restored' : 'backup_failed',
    detailText: detailText,
    backupFilePath: 'C:\\backup\\fittracker-user-data-backup.json',
    importedResult: null
  }
  return result
}

function writeTextFile(filePath: string, value: string): void {
  const file = fileIo.openSync(
    filePath,
    fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
  )
  try {
    fileIo.writeSync(file.fd, value)
  } finally {
    fileIo.closeSync(file.fd)
  }
}

export default function systemBackupBridgeServiceTest(): void {
  const fakeStore = new FakePreferencesStore()
  describe('SystemBackupBridgeService', () => {
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

    it('exports a backup package to directory and restores it back', 0, async () => {
      await resetPersistedData()

      const goal: UserGoal = GoalSetupService.createGoalFromSelection(
        'goal_backup_bridge',
        'strength',
        'intermediate',
        4,
        60,
        ['eq_barbell'],
        [],
        5000
      )
      await GoalRepository.saveGoal(getTestContext(), goal)
      await TrainingPlanService.replaceMyPlans(getTestContext(), [createPlan('plan_backup_bridge', 3000)], 'plan_backup_bridge')
      await WorkoutSessionPersistenceBridgeService.replacePersistedSessions(getTestContext(), [createSession('session_backup_bridge_1', 100)])

      const backupDir: string = createBackupDirPath('roundtrip')
      const exportResult = await SystemBackupBridgeService.exportBackupPackageToDirectory(getTestContext(), backupDir)
      const backupText: string = await fileIo.readText(exportResult.backupFilePath)

      expect(exportResult.success).assertTrue()
      expect(exportResult.statusId).assertEqual('backup_exported')
      expect(fileIo.accessSync(exportResult.backupFilePath)).assertTrue()

      const parsedPackage = UserDataBackupService.parsePackageJson(backupText)
      expect(parsedPackage !== null).assertTrue()
      if (parsedPackage !== null) {
        expect(parsedPackage.currentPlanId).assertEqual('plan_backup_bridge')
        expect(parsedPackage.sessions.length).assertEqual(1)
      }

      await resetPersistedData()

      const importResult = await SystemBackupBridgeService.importBackupPackageFromDirectory(getTestContext(), backupDir)
      const restoredGoal: UserGoal | undefined = await GoalRepository.loadGoal(getTestContext())
      const restoredPlans: UserPlan[] = await TrainingPlanService.getMyPlans(getTestContext())
      const restoredCurrentPlanId: string = await TrainingPlanService.getCurrentPlanId(getTestContext())
      const restoredSessions: WorkoutSession[] = await WorkoutSessionPersistenceBridgeService.loadPersistedSessions(getTestContext())

      expect(importResult.success).assertTrue()
      expect(importResult.statusId).assertEqual('backup_restored')
      expect(importResult.importedResult !== null).assertTrue()
      if (importResult.importedResult !== null) {
        expect(importResult.importedResult.importedPlanCount).assertEqual(1)
        expect(importResult.importedResult.mergedSessionCount).assertEqual(1)
      }
      expect(restoredGoal !== undefined).assertTrue()
      expect(restoredPlans.length).assertEqual(1)
      expect(restoredCurrentPlanId).assertEqual('plan_backup_bridge')
      expect(restoredSessions.length).assertEqual(1)
      expect(restoredSessions[0].sessionId).assertEqual('session_backup_bridge_1')

      await resetPersistedData()
    })

    it('reports missing backup file without attempting import', 0, async () => {
      const backupDir: string = createBackupDirPath('missing')
      const importResult = await SystemBackupBridgeService.importBackupPackageFromDirectory(getTestContext(), backupDir)

      expect(importResult.success).assertFalse()
      expect(importResult.statusId).assertEqual('backup_file_missing')
      expect(importResult.importedResult).assertNull()
      expect(importResult.backupFilePath).assertEqual(SystemBackupBridgeService.getBackupFilePath(backupDir))
    })

    it('reports backup read failure with stable status text', 0, async () => {
      const backupDir: string = createBackupDirPath('read-failed')
      await fileIo.mkdir(backupDir, true)
      await fileIo.mkdir(SystemBackupBridgeService.getBackupFilePath(backupDir), true)

      const importResult = await SystemBackupBridgeService.importBackupPackageFromDirectory(getTestContext(), backupDir)

      expect(importResult.success).assertFalse()
      expect(importResult.statusId).assertEqual('backup_read_failed')
      expect(importResult.detailText).assertEqual('系统备份包读取失败。')
      expect(importResult.importedResult).assertNull()
    })

    it('propagates unsupported schema restore failure without mutating local data', 0, async () => {
      await resetPersistedData()

      const localGoal: UserGoal = GoalSetupService.createGoalFromSelection(
        'goal_backup_local_guard',
        'strength',
        'intermediate',
        4,
        60,
        ['eq_barbell'],
        [],
        5000
      )
      await GoalRepository.saveGoal(getTestContext(), localGoal)
      await TrainingPlanService.replaceMyPlans(getTestContext(), [createPlan('plan_backup_local_guard', 3000)], 'plan_backup_local_guard')
      await WorkoutSessionPersistenceBridgeService.replacePersistedSessions(getTestContext(), [createSession('session_backup_local_guard', 100)])

      const backupPackage = UserDataBackupService.createPackage(
        null,
        [createPlan('plan_backup_import_unsupported', 4000)],
        'plan_backup_import_unsupported',
        [createSession('session_backup_import_unsupported', 110)],
        6000
      )
      const unsupportedBackupText: string = JSON.stringify({
        schemaVersion: 99,
        exportedAt: backupPackage.exportedAt,
        goal: backupPackage.goal,
        plans: backupPackage.plans,
        currentPlanId: backupPackage.currentPlanId,
        sessions: backupPackage.sessions,
        contentMeta: backupPackage.contentMeta
      })

      const backupDir: string = createBackupDirPath('unsupported-schema')
      await fileIo.mkdir(backupDir, true)
      writeTextFile(SystemBackupBridgeService.getBackupFilePath(backupDir), unsupportedBackupText)

      const importResult = await SystemBackupBridgeService.importBackupPackageFromDirectory(getTestContext(), backupDir)
      const restoredGoal: UserGoal | undefined = await GoalRepository.loadGoal(getTestContext())
      const restoredCurrentPlanId: string = await TrainingPlanService.getCurrentPlanId(getTestContext())
      const restoredSessions: WorkoutSession[] = await WorkoutSessionPersistenceBridgeService.loadPersistedSessions(getTestContext())

      expect(importResult.success).assertFalse()
      expect(importResult.statusId).assertEqual('backup_schema_unsupported')
      expect(importResult.importedResult !== null).assertTrue()
      if (importResult.importedResult !== null) {
        expect(importResult.importedResult.statusId).assertEqual('backup_schema_unsupported')
      }
      expect(restoredGoal !== undefined).assertTrue()
      if (restoredGoal !== undefined) {
        expect(restoredGoal.goalId).assertEqual('goal_backup_local_guard')
      }
      expect(restoredCurrentPlanId).assertEqual('plan_backup_local_guard')
      expect(restoredSessions.length).assertEqual(1)
      expect(restoredSessions[0].sessionId).assertEqual('session_backup_local_guard')

      await resetPersistedData()
    })

    it('formats callback and process payloads for EntryBackupAbility', 0, () => {
      const result: SystemBackupBridgeResult = createBridgeResult(false, 'line 1\n"quoted" path')
      const callbackPayload: string = createBackupCallbackResult('restore', result)
      const processPayload: string = createBackupProcessInfo('restore_ex', result)
      const idlePayload: string = createIdleBackupProcessInfo()

      expect(callbackPayload).assertEqual(
        '{"type":"restore","errorCode":1,"errorInfo":"line 1\\n\\"quoted\\" path","statusId":"backup_failed","success":false,"backupFilePath":"C:\\\\backup\\\\fittracker-user-data-backup.json","detailText":"line 1\\n\\"quoted\\" path"}'
      )
      expect(processPayload).assertEqual(
        '{"stage":"restore_ex","statusId":"backup_failed","success":false,"backupFilePath":"C:\\\\backup\\\\fittracker-user-data-backup.json","detailText":"line 1\\n\\"quoted\\" path"}'
      )
      expect(idlePayload).assertEqual(
        '{"stage":"idle","statusId":"idle","success":false,"backupFilePath":"","detailText":"no backup activity yet"}'
      )
    })
  })
}
