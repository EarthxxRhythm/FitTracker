/**
 * CloudSyncService 测试（ohosTest）
 *
 * 覆盖：决策矩阵全分支（push/pull/none/conflict_pull）、fake 云存储全流程、
 * 同步状态与自动同步开关、未同步变更判定、pull 后收敛（本地并集回写）。
 *
 * 稳定性说明：hypium 1.0.25 的 Spec.run / runHookFunc 对 async 用例与钩子为裸调用
 * （不 await），同套件内异步链会交错推进。本文件的异步场景收敛在单个 async 用例内
 * 串行断言，清理内联；决策矩阵为纯同步断言。
 */
import { abilityDelegatorRegistry } from '@kit.TestKit'
import { describe, expect, it } from '@ohos/hypium'
import AuthService from '../../../main/ets/common/services/AuthService'
import SessionManager from '../../../main/ets/common/services/SessionManager'
import TrainingPlanService from '../../../main/ets/common/services/TrainingPlanService'
import UserProfileService from '../../../main/ets/common/services/UserProfileService'
import WorkoutDraftService from '../../../main/ets/common/services/WorkoutDraftService'
import WorkoutSessionPersistenceBridgeService from '../../../main/ets/features/workout/services/WorkoutSessionPersistenceBridgeService'
import GoalRepository from '../../../main/ets/shared/services/GoalRepository'
import GoalSetupService from '../../../main/ets/shared/services/GoalSetupService'
import WorkoutRepository from '../../../main/ets/shared/services/WorkoutRepository'
import UserDataBackupService, { UserDataBackupPackage } from '../../../main/ets/shared/services/UserDataBackupService'
import CloudSyncService, { SyncResult, SyncState } from '../../../main/ets/shared/services/CloudSyncService'
import { CloudSnapshot, CloudSnapshotStore, createCloudSnapshot } from '../../../main/ets/shared/services/CloudSnapshotStore'
import {
  UserGoal,
  WorkoutSession,
  createWorkoutSession,
  createWorkoutSet
} from '../../../main/ets/shared/models/TrainingModels'
import { acquireAuthSyncGate, ensureWarmup, releaseAuthSyncGate, WarmupOutcome } from './AuthSyncTestGate'

const TEST_USER_ID: string = 'sandbox:13700007777'

function getTestContext(): Context {
  const appContext: Context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext()
  return appContext.getApplicationContext().createModuleContext('entry')
}

class FakeCloudSnapshotStore extends CloudSnapshotStore {
  private snapshots: Map<string, CloudSnapshot> = new Map()

  async pull(context: Context, userId: string): Promise<CloudSnapshot | null> {
    const found: CloudSnapshot | undefined = this.snapshots.get(userId)
    return found === undefined ? null : found
  }

  async push(context: Context, snapshot: CloudSnapshot): Promise<boolean> {
    this.snapshots.set(snapshot.userId, snapshot)
    return true
  }

  overwrite(snapshot: CloudSnapshot): void {
    this.snapshots.set(snapshot.userId, snapshot)
  }

  read(userId: string): CloudSnapshot | null {
    const found: CloudSnapshot | undefined = this.snapshots.get(userId)
    return found === undefined ? null : found
  }

  count(): number {
    return this.snapshots.size
  }

  clear(): void {
    this.snapshots.clear()
  }
}

function buildRemotePayload(goal: UserGoal | null, nickname: string): string {
  const backupPackage: UserDataBackupPackage = UserDataBackupService.createPackage(goal, [], '', [], 2000)
  return JSON.stringify({
    schemaVersion: 1,
    backupJson: JSON.stringify(backupPackage),
    nickname: nickname,
    avatar: '',
    weightUnit: 'kg'
  })
}

async function seedLocalData(): Promise<void> {
  const context: Context = getTestContext()
  const goal: UserGoal = GoalSetupService.createCurrentGoalFromSelection(
    'hypertrophy',
    'beginner',
    3,
    45,
    ['eq_bodyweight'],
    [],
    1000
  )
  await GoalRepository.saveGoal(context, goal)
  GoalRepository.clearLocal()
  const sessions: WorkoutSession[] = [
    createWorkoutSession(
      'session_sync_1',
      'plan_sync',
      'day_1',
      1000,
      1900,
      900,
      1,
      720,
      0,
      'sync-test',
      [createWorkoutSet('session_sync_1_set_1', 'ex_barbell_bench_press', 90, 8, 8, false)]
    )
  ]
  await WorkoutSessionPersistenceBridgeService.replacePersistedSessions(context, sessions)
  await WorkoutSessionPersistenceBridgeService.syncRepositoryFromPersistence(context)
}

async function resetAll(fakeStore: FakeCloudSnapshotStore): Promise<void> {
  const context: Context = getTestContext()
  fakeStore.clear()
  WorkoutRepository.clear()
  GoalRepository.clearLocal()
  await GoalRepository.clearSavedGoal(context)
  await TrainingPlanService.replaceMyPlans(context, [], '')
  await WorkoutSessionPersistenceBridgeService.replacePersistedSessions(context, [])
  await WorkoutDraftService.clearDraft(context)
  await UserProfileService.clearProfile(context)
  await SessionManager.clearSession(context)
  await SessionManager.clearToken(context)
  await CloudSyncService.resetMeta(context)
  await AuthService.clearPersistedUsers(context)
}

async function seedRemoteConflict(fakeStore: FakeCloudSnapshotStore, goalType: string, updatedOffsetMs: number): Promise<void> {
  const remoteGoal: UserGoal = GoalSetupService.createCurrentGoalFromSelection(
    goalType,
    'intermediate',
    4,
    60,
    ['eq_barbell'],
    [],
    5000
  )
  fakeStore.overwrite(createCloudSnapshot(
    TEST_USER_ID,
    buildRemotePayload(remoteGoal, '云端用户'),
    Date.now() + updatedOffsetMs,
    'remote-device',
    1
  ))
}

export default function cloudSyncServiceTest(): void {
  const fakeStore = new FakeCloudSnapshotStore()
  CloudSyncService.setStoreForTesting(fakeStore)

  describe('CloudSyncService decision matrix', () => {
    it('pushes when the cloud has no snapshot', 0, () => {
      expect(CloudSyncService.decideSyncAction('aaa', '', '', 0, 0)).assertEqual('push')
    })

    it('reports none when both sides match the baseline', 0, () => {
      expect(CloudSyncService.decideSyncAction('same', 'same', 'same', 100, 100)).assertEqual('none')
    })

    it('pulls when only the cloud changed', 0, () => {
      expect(CloudSyncService.decideSyncAction('same', 'remote-new', 'same', 200, 100)).assertEqual('pull')
    })

    it('pushes when only the local side changed', 0, () => {
      expect(CloudSyncService.decideSyncAction('local-new', 'same', 'same', 100, 100)).assertEqual('push')
    })

    it('prefers the cloud on newer conflicts', 0, () => {
      expect(CloudSyncService.decideSyncAction('local-new', 'remote-new', 'same', 300, 100)).assertEqual('conflict_pull')
    })

    it('pushes when the cloud conflict is older than the last sync', 0, () => {
      expect(CloudSyncService.decideSyncAction('local-new', 'remote-new', 'same', 50, 100)).assertEqual('push')
    })
  })

  describe('CloudSyncService sync flow', () => {
    it('runs push none pull conflict convergence skip and auto preference in order', 0, async () => {
      const warmup: WarmupOutcome = await ensureWarmup(getTestContext)
      const context: Context = warmup.context
      await acquireAuthSyncGate()
      try {

      // 1) 首同步：push + synced 状态 + 无未同步变更
      await resetAll(fakeStore)
      await AuthService.seedSandboxSession(context, '13700007777', '同步测试')
      await seedLocalData()
      let result: SyncResult = await CloudSyncService.syncNow(context)
      expect(result.success).assertTrue()
      expect(result.action).assertEqual('push')
      expect(fakeStore.count()).assertEqual(1)
      let state: SyncState = await CloudSyncService.getState(context)
      expect(state.status).assertEqual('synced')
      expect(state.lastSyncAt > 0).assertTrue()
      expect(await CloudSyncService.hasPendingChanges(context)).assertFalse()

      // 2) 双方无变化：none
      result = await CloudSyncService.syncNow(context)
      expect(result.success).assertTrue()
      expect(result.action).assertEqual('none')
      expect(fakeStore.count()).assertEqual(1)

      // 3) 仅云端变化：pull（恢复远程目标）
      await resetAll(fakeStore)
      await AuthService.seedSandboxSession(context, '13700007777', '同步测试')
      await seedLocalData()
      await CloudSyncService.syncNow(context)
      await seedRemoteConflict(fakeStore, 'strength', 1000)
      result = await CloudSyncService.syncNow(context)
      expect(result.success).assertTrue()
      expect(result.action).assertEqual('pull')
      let goal: UserGoal | undefined = await GoalRepository.loadGoal(context)
      expect(goal !== undefined).assertTrue()
      if (goal !== undefined) {
        expect(goal.goalType).assertEqual('strength')
      }

      // 4) 双方都变且云端较新：conflict_pull（云端优先）
      await resetAll(fakeStore)
      await AuthService.seedSandboxSession(context, '13700007777', '同步测试')
      await seedLocalData()
      await CloudSyncService.syncNow(context)
      const localGoal: UserGoal = GoalSetupService.createCurrentGoalFromSelection(
        'fat_loss',
        'beginner',
        2,
        30,
        ['eq_bodyweight'],
        [],
        6000
      )
      await GoalRepository.saveGoal(context, localGoal)
      GoalRepository.clearLocal()
      await seedRemoteConflict(fakeStore, 'strength', 5000)
      result = await CloudSyncService.syncNow(context)
      expect(result.success).assertTrue()
      expect(result.action).assertEqual('conflict_pull')
      goal = await GoalRepository.loadGoal(context)
      expect(goal !== undefined).assertTrue()
      if (goal !== undefined) {
        expect(goal.goalType).assertEqual('strength')
      }

      // 5) pull 后收敛：本地并集回写云端 → 再同步为 none
      await resetAll(fakeStore)
      await AuthService.seedSandboxSession(context, '13700007777', '同步测试')
      await seedLocalData()
      await CloudSyncService.syncNow(context)
      const remoteGoal: UserGoal = GoalSetupService.createCurrentGoalFromSelection(
        'strength',
        'intermediate',
        4,
        60,
        ['eq_barbell'],
        [],
        5000
      )
      const remoteSessions: WorkoutSession[] = [
        createWorkoutSession(
          'session_remote_c',
          'plan_sync',
          'day_2',
          2000,
          2900,
          900,
          1,
          700,
          0,
          '',
          [createWorkoutSet('session_remote_c_set_1', 'ex_dumbbell_press', 22, 10, 8, false)]
        )
      ]
      const remotePackage: UserDataBackupPackage = UserDataBackupService.createPackage(
        remoteGoal,
        [],
        '',
        remoteSessions,
        2000
      )
      fakeStore.overwrite(createCloudSnapshot(
        TEST_USER_ID,
        JSON.stringify({
          schemaVersion: 1,
          backupJson: JSON.stringify(remotePackage),
          nickname: '云端用户',
          avatar: '',
          weightUnit: 'kg'
        }),
        Date.now() + 1000,
        'remote-device',
        1
      ))
      const pulled: SyncResult = await CloudSyncService.syncNow(context)
      expect(pulled.action).assertEqual('pull')
      expect(await CloudSyncService.hasPendingChanges(context)).assertTrue()
      const pushBack: SyncResult = await CloudSyncService.syncNow(context)
      expect(pushBack.action).assertEqual('push')
      const settled: SyncResult = await CloudSyncService.syncNow(context)
      expect(settled.action).assertEqual('none')
      const stored: CloudSnapshot | null = fakeStore.read(TEST_USER_ID)
      expect(stored !== null).assertTrue()
      if (stored !== null) {
        expect(stored.payloadJson.includes('session_sync_1')).assertTrue()
        expect(stored.payloadJson.includes('session_remote_c')).assertTrue()
      }

      // 6) 未登录：skipped + unauthenticated
      await resetAll(fakeStore)
      result = await CloudSyncService.syncNow(context)
      expect(result.success).assertFalse()
      expect(result.action).assertEqual('skipped')
      state = await CloudSyncService.getState(context)
      expect(state.status).assertEqual('unauthenticated')

      // 7) 自动同步开关持久化
      await CloudSyncService.setAutoEnabled(context, false)
      let offState: SyncState = await CloudSyncService.getState(context)
      expect(offState.autoEnabled).assertFalse()
      await CloudSyncService.setAutoEnabled(context, true)
      const onState: SyncState = await CloudSyncService.getState(context)
      expect(onState.autoEnabled).assertTrue()

      await resetAll(fakeStore)
      } finally {
        releaseAuthSyncGate()
      }
    })
  })
}
