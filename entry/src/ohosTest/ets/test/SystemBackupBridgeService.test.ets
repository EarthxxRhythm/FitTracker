import { fileIo } from '@kit.CoreFileKit'
import { abilityDelegatorRegistry } from '@kit.TestKit'
import { describe, expect, it } from '@ohos/hypium'
import TrainingPlanService, { UserPlan } from '../../../main/ets/common/services/TrainingPlanService'
import GoalRepository from '../../../main/ets/shared/services/GoalRepository'
import GoalSetupService from '../../../main/ets/shared/services/GoalSetupService'
import {
  createBackupCallbackResult,
  createBackupProcessInfo
} from '../../../main/ets/entrybackupability/EntryBackupAbility'
import SystemBackupBridgeService, {
  SystemBackupBridgeResult
} from '../../../main/ets/shared/services/SystemBackupBridgeService'
import UserDataBackupService from '../../../main/ets/shared/services/UserDataBackupService'
import WorkoutSessionPersistenceBridgeService from '../../../main/ets/features/workout/services/WorkoutSessionPersistenceBridgeService'
import {
  UserGoal,
  WorkoutSession,
  createWorkoutSession,
  createWorkoutSet
} from '../../../main/ets/shared/models/TrainingModels'

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

export default function systemBackupBridgeServiceTest(): void {
  describe('SystemBackupBridgeService', () => {
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

    it('formats callback and process payloads for EntryBackupAbility', 0, () => {
      const result: SystemBackupBridgeResult = createBridgeResult(false, 'line 1\n"quoted" path')
      const callbackPayload: string = createBackupCallbackResult('restore', result)
      const processPayload: string = createBackupProcessInfo('restore_ex', result)

      expect(callbackPayload).assertEqual(
        '{"type":"restore","errorCode":1,"errorInfo":"line 1\\n\\"quoted\\" path"}'
      )
      expect(processPayload).assertEqual(
        '{"stage":"restore_ex","statusId":"backup_failed","success":false,"backupFilePath":"C:\\\\backup\\\\fittracker-user-data-backup.json","detailText":"line 1\\n\\"quoted\\" path"}'
      )
    })
  })
}
