/**
 * CloudSyncService —— 云同步编排（整包快照模型）。
 *
 * 同步算法（v1）：
 *  1. 聚合本地数据为整包 JSON（复用 UserDataBackupService 序列化 + 用户资料）
 *  2. 本地 hash / 云端 hash / lastSyncedHash 三值决策（decideSyncAction）
 *  3. push（上行）/ pull（下行合并）/ none（已同步）/ conflict_pull（云端优先）
 *  4. 状态持久化到 fit_tracker_sync；meta 绑定 userId，账号切换自动视为全新同步
 *
 * 权威模型（方案 A：本地存储 + 云同步）：
 *  - 离线可写本地，联网后同步；冲突按「服务端接收时间最近写入为准」（云端 updatedAt 较新时下行）。
 */
import { Context } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { FitTrackerStores } from '../../app/AppState'
import CloudEnvironment, { CloudBackend } from '../../common/services/CloudEnvironment'
import SessionManager from '../../common/services/SessionManager'
import UserProfileService, { UserProfile } from '../../common/services/UserProfileService'
import AvatarImageService from '../../common/services/AvatarImageService'
import UserDataBackupService, { UserDataBackupImportResult, UserDataBackupPackage } from './UserDataBackupService'
import supabaseCloudSnapshotStore from './SupabaseCloudSnapshotStore'
import cloudSnapshotStore, {
  CloudSnapshot,
  CloudSnapshotStore,
  SNAPSHOT_SCHEMA_VERSION,
  createCloudSnapshot
} from './CloudSnapshotStore'

export type SyncAction = 'push' | 'pull' | 'none' | 'conflict_pull' | 'failed' | 'skipped'

/** 云存储解析判据（独立可测）：测试注入 > Supabase > 沙盒兜底。 */
export type SyncStoreKind = 'testing' | 'supabase' | 'sandbox'

export function resolveStoreKind(testingInjected: boolean, backend: CloudBackend): SyncStoreKind {
  if (testingInjected) {
    return 'testing'
  }
  if (backend === 'supabase') {
    return 'supabase'
  }
  return 'sandbox'
}

const META_KEY: string = 'meta'
const ENVELOPE_SCHEMA_VERSION: number = 1

export interface SyncState {
  status: string
  lastSyncAt: number
  lastError: string
}

export interface SyncResult {
  success: boolean
  action: string
  message: string
  syncedAt: number
}

interface SyncMeta {
  userId: string
  lastSyncedHash: string
  lastSyncAt: number
  lastStatus: string
  lastError: string
}

interface CloudPayloadEnvelope {
  schemaVersion: number
  backupJson: string
  nickname: string
  avatar: string
  weightUnit: string
  /** 身体档案（用于 BMI / 基础代谢派生）；旧信封无此字段时为 undefined。 */
  heightCm: number
  gender: string
  birthYear: number
  /** 训练经验；旧信封无此字段时为 undefined（下行保留本地值）。 */
  experience?: string
  /**
   * 头像图片（压缩后 JPEG 的 base64，约 8～20KB）；空串表示无图。
   * 旧信封无此字段时为 undefined（下行保留本地头像）。
   */
  avatarImage?: string
  /**
   * 头像内容摘要（[avatarImage] 的 djb2）：只把摘要纳入变更检测视图，
   * 避免整段 base64 进入 canonical 串；同图在任何设备上摘要一致，不会因本机路径不同而抖动。
   */
  avatarImageHash?: string
}

class CloudSyncService {
  private testingStore: CloudSnapshotStore | null = null
  private syncInProgress: boolean = false

  /** 测试注入：替换云存储；传 null 恢复默认（沙盒文件存储）。 */
  setStoreForTesting(store: CloudSnapshotStore | null): void {
    this.testingStore = store
  }

  /**
   * 纯函数决策（独立可测）。remoteHash 为空串表示云端无快照。
   *  - 云端无 → push（首同步/认领）
   *  - 本地无变化 → 云端也无变化则 none，否则 pull
   *  - 仅本地变化 → push
   *  - 双方都变 → 云端在同步窗口后更新则 conflict_pull（云端优先），否则 push
   */
  decideSyncAction(
    localHash: string,
    remoteHash: string,
    lastSyncedHash: string,
    remoteUpdatedAt: number,
    lastSyncAt: number
  ): SyncAction {
    if (remoteHash.length === 0) {
      return 'push'
    }
    if (localHash === lastSyncedHash) {
      return remoteHash === lastSyncedHash ? 'none' : 'pull'
    }
    if (remoteHash === lastSyncedHash) {
      return 'push'
    }
    return remoteUpdatedAt > lastSyncAt ? 'conflict_pull' : 'push'
  }

  async getState(context: Context): Promise<SyncState> {
    const meta: SyncMeta = await this.readMeta(context)
    const hasSession: boolean = await SessionManager.isLoggedIn(context)
    let status: string = meta.lastStatus
    if (this.syncInProgress) {
      status = 'syncing'
    } else if (!hasSession) {
      status = 'unauthenticated'
    } else if (status.length === 0) {
      status = 'never'
    }
    const state: SyncState = {
      status: status,
      lastSyncAt: meta.lastSyncAt,
      lastError: meta.lastError
    }
    return state
  }

  /** 是否存在未同步到云端的本地变更（供退出确认使用）。 */
  async hasPendingChanges(context: Context): Promise<boolean> {
    const session = await SessionManager.getSession(context)
    if (session === null) {
      return false
    }
    const meta: SyncMeta = await this.readMeta(context)
    if (meta.userId !== session.userId) {
      return true
    }
    const payload: string = await this.buildLocalPayload(context)
    return this.hashPayload(payload) !== meta.lastSyncedHash
  }

  async syncNow(context: Context): Promise<SyncResult> {
    if (this.syncInProgress) {
      return this.createResult(false, 'skipped', '同步进行中', Date.now())
    }
    this.syncInProgress = true
    try {
      const session = await SessionManager.getSession(context)
      if (session === null) {
        return this.createResult(false, 'skipped', '未登录', Date.now())
      }
      const localPayload: string = await this.buildLocalPayload(context)
      const localHash: string = this.hashPayload(localPayload)
      const meta: SyncMeta = await this.readMeta(context)
      const sameAccount: boolean = meta.userId === session.userId
      const baseline: string = sameAccount ? meta.lastSyncedHash : ''
      const baselineAt: number = sameAccount ? meta.lastSyncAt : 0
      const store: CloudSnapshotStore | null = await this.resolveStore(context)
      if (store === null) {
        await this.writeMeta(context, this.createMeta(
          session.userId,
          baseline,
          baselineAt,
          'failed',
          '云服务未就绪，请稍后重试'
        ))
        return this.createResult(false, 'failed', '云服务未就绪，请稍后重试', Date.now())
      }
      const remote: CloudSnapshot | null = await store.pull(context, session.userId)
      const remoteHash: string = remote === null ? '' : this.hashPayload(remote.payloadJson)
      const remoteUpdatedAt: number = remote === null ? 0 : remote.updatedAt
      const action: SyncAction = this.decideSyncAction(localHash, remoteHash, baseline, remoteUpdatedAt, baselineAt)
      const now: number = Date.now()

      if (action === 'push') {
        const pushed: boolean = await store.push(
          context,
          createCloudSnapshot(session.userId, localPayload, now, this.resolveDeviceTag(), SNAPSHOT_SCHEMA_VERSION)
        )
        if (!pushed) {
          await this.writeMeta(context, this.createMeta(session.userId, baseline, baselineAt, 'failed', '同步上传失败'))
          return this.createResult(false, 'push', '同步上传失败，请稍后重试', now)
        }
        await this.writeMeta(context, this.createMeta(session.userId, localHash, now, 'synced', ''))
        return this.createResult(true, 'push', '已同步到云端', now)
      }

      if (action === 'pull' || action === 'conflict_pull') {
        if (remote === null) {
          await this.writeMeta(context, this.createMeta(session.userId, baseline, baselineAt, 'failed', '云端快照缺失'))
          return this.createResult(false, action, '云端快照缺失，请稍后重试', now)
        }
        const applied: boolean = await this.applyRemotePayload(context, remote.payloadJson)
        if (!applied) {
          await this.writeMeta(context, this.createMeta(session.userId, baseline, baselineAt, 'failed', '云端数据恢复失败'))
          return this.createResult(false, action, '云端数据恢复失败，请稍后重试', now)
        }
        // 基线记录为「云端快照 hash」而非导入后的本地并集：
        // 若本地保留有云端没有的实体（sessions 并集合并语义），下次同步会判「仅本地变化 → push」，
        // 把并集回写云端后收敛为 none；hasPendingChanges 也据此正确报告未上行数据（守住退出确认）。
        await this.writeMeta(context, this.createMeta(session.userId, remoteHash, now, 'synced', ''))
        const message: string = action === 'conflict_pull' ? '云端数据较新，已采用云端版本' : '已从云端恢复'
        return this.createResult(true, action, message, now)
      }

      await this.writeMeta(context, this.createMeta(session.userId, localHash, now, 'synced', ''))
      return this.createResult(true, 'none', '已是最新', now)
    } catch (error) {
      return this.createResult(false, 'failed', '同步失败，请稍后重试', Date.now())
    } finally {
      this.syncInProgress = false
    }
  }

  /** 登录成功钩子：云端有数据则恢复，云端为空则认领上传；失败不阻塞登录流程。 */
  async onSignIn(context: Context): Promise<void> {
    try {
      await this.syncNow(context)
    } catch (error) {
      // 登录流程不因同步失败中断
    }
  }

  /** 后台静默同步（启动后 / 训练完成后）：同步恒定自动执行；失败记录状态不抛出。 */
  async requestBackgroundSync(context: Context): Promise<void> {
    try {
      await this.syncNow(context)
    } catch (error) {
      // 静默路径：状态由 syncNow 内部记录
    }
  }

  /** 重置同步元数据（登出时调用，防账号切换串账）。 */
  async resetMeta(context: Context): Promise<void> {
    const next: SyncMeta = this.createMeta('', '', 0, 'never', '')
    await this.writeMeta(context, next)
  }

  private async buildLocalPayload(context: Context): Promise<string> {
    const backupJson: string = await UserDataBackupService.exportPackage(context)
    const profile: UserProfile = await UserProfileService.loadProfile(context)
    // 头像：文件读不到（尚未设置 / 已被清理）按无图处理。
    const avatarImage: string = await AvatarImageService.readAsBase64(profile.avatarImagePath)
    const envelope: CloudPayloadEnvelope = {
      schemaVersion: ENVELOPE_SCHEMA_VERSION,
      backupJson: backupJson,
      nickname: profile.nickname,
      avatar: profile.avatar,
      weightUnit: profile.weightUnit,
      heightCm: profile.heightCm,
      gender: profile.gender,
      birthYear: profile.birthYear,
      experience: profile.experience,
      avatarImage: avatarImage,
      avatarImageHash: avatarImage.length > 0 ? this.djb2Hex(avatarImage) : ''
    }
    return JSON.stringify(envelope)
  }

  private async applyRemotePayload(context: Context, payloadJson: string): Promise<boolean> {
    try {
      const envelope = JSON.parse(payloadJson) as CloudPayloadEnvelope
      if (typeof envelope.backupJson !== 'string' || envelope.backupJson.length === 0) {
        return false
      }
      const importResult: UserDataBackupImportResult = await UserDataBackupService.importPackage(context, envelope.backupJson)
      if (typeof envelope.nickname === 'string') {
        const unit: string = envelope.weightUnit === 'lbs' ? 'lbs' : 'kg'
        // 身体档案：旧信封（无 heightCm/gender/birthYear）时保留本地已填值，不用 0 覆盖。
        const local: UserProfile = await UserProfileService.loadProfile(context)
        const heightCm: number = typeof envelope.heightCm === 'number' ? envelope.heightCm : local.heightCm
        const gender: string = typeof envelope.gender === 'string' ? envelope.gender : local.gender
        const birthYear: number = typeof envelope.birthYear === 'number' ? envelope.birthYear : local.birthYear
        // 训练经验：旧信封无此字段时同样保留本地值。
        const experience: string = typeof envelope.experience === 'string' ? envelope.experience : local.experience
        // 头像：新信封带去 base64 时与远端对齐；旧信封（无此字段）保留本地头像。
        const avatarImagePath: string = await this.resolveRemoteAvatarPath(context, envelope, local.avatarImagePath)
        const profile: UserProfile = {
          nickname: envelope.nickname,
          avatar: typeof envelope.avatar === 'string' ? envelope.avatar : '',
          weightUnit: unit === 'lbs' ? 'lbs' : 'kg',
          heightCm: heightCm,
          gender: gender === 'male' || gender === 'female' ? gender : '',
          birthYear: birthYear,
          experience: experience === 'beginner' || experience === 'intermediate' || experience === 'advanced'
            ? experience
            : '',
          avatarImagePath: avatarImagePath
        }
        await UserProfileService.saveProfile(context, profile)
      }
      return importResult.success
    } catch (error) {
      return false
    }
  }

  /**
   * 变更检测 hash：先规范化为确定性视图（剔除 exportedAt 等易变字段），再取 djb2 摘要。
   * 非安全用途；碰撞/漂移的代价仅为额外一次上行同步。
   */
  private hashPayload(payload: string): string {
    const canonical: string = this.normalizePayloadForHash(payload)
    return this.djb2Hex(canonical) + '_' + canonical.length.toString(16)
  }

  /** djb2 十六进制摘要（非安全用途）。头像内容摘要与整包 hash 共用同一算法。 */
  private djb2Hex(text: string): string {
    let hashValue: number = 5381
    for (let index = 0; index < text.length; index++) {
      hashValue = ((hashValue << 5) + hashValue + text.charCodeAt(index)) | 0
    }
    return (hashValue >>> 0).toString(16)
  }

  /**
   * 下行头像落位：远端与本地内容一致时保留本地文件（不重写）；
   * 远端为空则清掉本地图；旧信封（字段缺失）与原逻辑一致，保留本地值。
   */
  private async resolveRemoteAvatarPath(
    context: Context,
    envelope: CloudPayloadEnvelope,
    localPath: string
  ): Promise<string> {
    if (typeof envelope.avatarImage !== 'string') {
      return localPath
    }
    const remoteImage: string = envelope.avatarImage
    const remoteHash: string = remoteImage.length > 0 ? this.djb2Hex(remoteImage) : ''
    const localImage: string = await AvatarImageService.readAsBase64(localPath)
    const localHash: string = localImage.length > 0 ? this.djb2Hex(localImage) : ''
    if (remoteHash === localHash) {
      return localPath
    }
    if (remoteImage.length === 0) {
      await AvatarImageService.remove(localPath)
      return ''
    }
    const newPath: string = await AvatarImageService.writeFromBase64(context, remoteImage)
    if (newPath.length === 0) {
      // 写盘失败不阻断整包恢复：保留本地头像，下次同步再对齐。
      return localPath
    }
    await AvatarImageService.remove(localPath)
    return newPath
  }

  private normalizePayloadForHash(payload: string): string {
    try {
      const envelope = JSON.parse(payload) as CloudPayloadEnvelope
      const backup = JSON.parse(envelope.backupJson) as UserDataBackupPackage
      const view: CloudPayloadEnvelope = {
        schemaVersion: envelope.schemaVersion,
        backupJson: JSON.stringify({
          schemaVersion: backup.schemaVersion,
          goal: backup.goal,
          plans: backup.plans,
          currentPlanId: backup.currentPlanId,
          sessions: backup.sessions,
          contentMeta: backup.contentMeta,
          // 身体数据域：不入此视图则其变化不改变 hash，同步变更检测对该域「失明」。
          bodyRecords: backup.bodyRecords,
          bodyMeasurements: backup.bodyMeasurements
        }),
        nickname: envelope.nickname,
        avatar: envelope.avatar,
        weightUnit: envelope.weightUnit,
        heightCm: envelope.heightCm,
        gender: envelope.gender,
        birthYear: envelope.birthYear,
        experience: envelope.experience,
        // 头像只纳入内容摘要：整段 base64 进 canonical 既冗长，也易因本机路径/重编码差异误判。
        avatarImageHash: envelope.avatarImageHash
      }
      return JSON.stringify(view)
    } catch (error) {
      return payload
    }
  }

  /**
   * 解析云存储：测试注入 > Supabase（就绪判据 = 配置存在，不回退沙盒）
   * > 本地沙盒存储。
   */
  private async resolveStore(context: Context): Promise<CloudSnapshotStore | null> {
    if (this.testingStore !== null) {
      return this.testingStore
    }
    // 幂等补齐云环境探测：登录态重启的新进程不经过登录页，若不在此调用，
    // Supabase 配置判定恒为未配置，同步会被静默降级到本地沙盒。
    await CloudEnvironment.initialize(context)
    const kind: SyncStoreKind = resolveStoreKind(false, CloudEnvironment.getBackend())
    if (kind === 'supabase') {
      // Supabase 就绪判据 = 配置存在（不走 cloudCommon，见 CloudEnvironment 注释）；
      // token 缺失不回退沙盒——由 store 内 isConfigured 与 401 语义表达（对齐 Android）。
      return supabaseCloudSnapshotStore
    }
    return cloudSnapshotStore
  }

  private resolveDeviceTag(): string {
    return 'local-device'
  }

  private async readMeta(context: Context): Promise<SyncMeta> {
    const fallback: SyncMeta = this.createMeta('', '', 0, 'never', '')
    try {
      const prefs = await preferences.getPreferences(context, FitTrackerStores.SYNC)
      const json = await prefs.get(META_KEY, '') as string
      if (json.trim().length === 0) {
        return fallback
      }
      const meta = JSON.parse(json) as SyncMeta
      if (!this.isValidMeta(meta)) {
        return fallback
      }
      return meta
    } catch (error) {
      return fallback
    }
  }

  private async writeMeta(context: Context, meta: SyncMeta): Promise<void> {
    try {
      const prefs = await preferences.getPreferences(context, FitTrackerStores.SYNC)
      await prefs.put(META_KEY, JSON.stringify(meta))
      await prefs.flush()
    } catch (error) {
      // 状态写入失败不阻塞同步流程
    }
  }

  private createMeta(
    userId: string,
    lastSyncedHash: string,
    lastSyncAt: number,
    lastStatus: string,
    lastError: string
  ): SyncMeta {
    const meta: SyncMeta = {
      userId: userId,
      lastSyncedHash: lastSyncedHash,
      lastSyncAt: lastSyncAt,
      lastStatus: lastStatus,
      lastError: lastError
    }
    return meta
  }

  private isValidMeta(meta: SyncMeta): boolean {
    if (meta === null || meta === undefined) {
      return false
    }
    if (typeof meta.userId !== 'string' || typeof meta.lastSyncedHash !== 'string') {
      return false
    }
    if (typeof meta.lastSyncAt !== 'number' || !Number.isFinite(meta.lastSyncAt)) {
      return false
    }
    if (typeof meta.lastStatus !== 'string' || typeof meta.lastError !== 'string') {
      return false
    }
    return true
  }

  private createResult(success: boolean, action: string, message: string, syncedAt: number): SyncResult {
    const result: SyncResult = {
      success: success,
      action: action,
      message: message,
      syncedAt: syncedAt
    }
    return result
  }
}

export default new CloudSyncService()
