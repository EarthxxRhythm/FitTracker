/**
 * AccountDataLifecycle —— 账号数据生命周期（退出登录编排 / 业务数据清空）。
 *
 * v1 单账号切换模型：退出 = 清理本机业务数据（云端已同步的数据在下次登录后恢复），
 * 不引入 per-user 本地存储前缀（改动面控制）；旧本地数据在首次登录时经同步认领上传。
 */
import { Context } from '@kit.AbilityKit'
import AuthService from '../../common/services/AuthService'
import SessionManager from '../../common/services/SessionManager'
import TrainingPlanService from '../../common/services/TrainingPlanService'
import UserProfileService from '../../common/services/UserProfileService'
import WorkoutDraftService from '../../common/services/WorkoutDraftService'
import WorkoutSessionPersistenceBridgeService from '../../features/workout/services/WorkoutSessionPersistenceBridgeService'
import CloudSyncService from './CloudSyncService'
import GoalRepository from './GoalRepository'
import WorkoutRepository from './WorkoutRepository'

export interface SignOutPreview {
  hasSession: boolean
  /** 退出前尝试同步后仍有未上传的本地变更。 */
  pendingChanges: boolean
  lastSyncAt: number
}

class AccountDataLifecycle {
  /**
   * 退出前预检：best-effort 同步一次，然后报告是否仍有未同步变更。
   * UI 在 pendingChanges 为 true 时应弹出确认（退出将丢失未同步数据）。
   */
  async prepareSignOut(context: Context): Promise<SignOutPreview> {
    const hasSession: boolean = await SessionManager.isLoggedIn(context)
    if (!hasSession) {
      const empty: SignOutPreview = {
        hasSession: false,
        pendingChanges: false,
        lastSyncAt: 0
      }
      return empty
    }
    await CloudSyncService.syncNow(context)
    const pendingChanges: boolean = await CloudSyncService.hasPendingChanges(context)
    const state = await CloudSyncService.getState(context)
    const preview: SignOutPreview = {
      hasSession: true,
      pendingChanges: pendingChanges,
      lastSyncAt: state.lastSyncAt
    }
    return preview
  }

  /** 完成退出：清认证会话 + 清本机业务数据 + 重置同步元数据。 */
  async completeSignOut(context: Context): Promise<void> {
    await AuthService.logout(context)
    await this.clearBusinessData(context)
    await CloudSyncService.resetMeta(context)
  }

  /** 清空本机业务数据（保留设置、内容库与沙盒账号目录）。 */
  async clearBusinessData(context: Context): Promise<void> {
    GoalRepository.clearLocal()
    await GoalRepository.clearSavedGoal(context)
    await TrainingPlanService.replaceMyPlans(context, [], '')
    WorkoutRepository.clear()
    await WorkoutSessionPersistenceBridgeService.replacePersistedSessions(context, [])
    await WorkoutDraftService.clearDraft(context)
    await UserProfileService.clearProfile(context)
  }
}

export default new AccountDataLifecycle()
