/**
 * AgcCloudSnapshotStore —— AGC 云数据库（Cloud Foundation Kit）快照存储实现。
 *
 * 前提：CloudEnvironment.ensureCloudDatabaseReady() 已完成 cloudCommon 初始化
 * （携带登录凭据 authProvider 与 schema.json）；由 CloudSyncService 在已登录时保证。
 *
 * 对象类型 SyncSnapshot 与 AGC 控制台对象类型（AppScope/resources/rawfile/schema.json）一一对应：
 *   userId(String, 主键) / payloadJson(Text) / updatedAt(Long) / deviceTag(String) / schemaVersion(Integer)
 * 字段名须与控制台定义一致（两侧不一致将报 1008230002）。
 * 存储区名须与 AGC 控制台「存储区」名称一致（docs/cloud-setup.md §3）。
 */
import { Context } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { cloudDatabase } from '@kit.CloudFoundationKit'
import {
  CloudSnapshot,
  CloudSnapshotStore,
  SNAPSHOT_SCHEMA_VERSION,
  createCloudSnapshot
} from './CloudSnapshotStore'

/** AGC 控制台「存储区」名称（与 docs/cloud-setup.md §3 约定一致；实测时以控制台为准）。 */
const CLOUD_DB_ZONE_NAME: string = 'FitTracker'

/** SyncSnapshot 对象类：String/Text → string，Long/Integer → number（官方字段类型映射）。 */
class SyncSnapshot extends cloudDatabase.DatabaseObject {
  public naturalbase_ClassName(): string {
    return 'SyncSnapshot'
  }

  public userId: string | undefined
  public payloadJson: string | undefined
  public updatedAt: number | undefined
  public deviceTag: string | undefined
  public schemaVersion: number | undefined
}

export { SyncSnapshot }

class AgcCloudSnapshotStore extends CloudSnapshotStore {
  async pull(context: Context, userId: string): Promise<CloudSnapshot | null> {
    try {
      const zone: cloudDatabase.DatabaseZone = cloudDatabase.zone(CLOUD_DB_ZONE_NAME)
      const condition: cloudDatabase.DatabaseQuery<SyncSnapshot> = new cloudDatabase.DatabaseQuery(SyncSnapshot)
      condition.equalTo('userId', userId)
      const rows: SyncSnapshot[] = await zone.query(condition)
      if (rows.length === 0) {
        return null
      }
      return this.toSnapshot(rows[0])
    } catch (error) {
      // 与 LocalSandboxSnapshotStore.pull 语义一致：读取失败按「无快照」返回，
      // 由上层的 push 路径暴露失败（权限/网络问题不静默成功）
      this.logError('pull', error)
      return null
    }
  }

  async push(context: Context, snapshot: CloudSnapshot): Promise<boolean> {
    try {
      const zone: cloudDatabase.DatabaseZone = cloudDatabase.zone(CLOUD_DB_ZONE_NAME)
      const row: SyncSnapshot = new SyncSnapshot()
      row.userId = snapshot.userId
      row.payloadJson = snapshot.payloadJson
      row.updatedAt = snapshot.updatedAt
      row.deviceTag = snapshot.deviceTag
      row.schemaVersion = snapshot.schemaVersion
      const affected: number = await zone.upsert(row)
      return affected > 0
    } catch (error) {
      this.logError('push', error)
      return false
    }
  }

  private toSnapshot(row: SyncSnapshot): CloudSnapshot | null {
    const userId: string = row.userId !== undefined ? row.userId : ''
    const payloadJson: string = row.payloadJson !== undefined ? row.payloadJson : ''
    const updatedAt: number = row.updatedAt !== undefined ? row.updatedAt : 0
    const deviceTag: string = row.deviceTag !== undefined ? row.deviceTag : ''
    const schemaVersion: number = row.schemaVersion !== undefined ? row.schemaVersion : 0
    if (userId.length === 0 || payloadJson.length === 0) {
      return null
    }
    if (schemaVersion !== SNAPSHOT_SCHEMA_VERSION) {
      return null
    }
    return createCloudSnapshot(userId, payloadJson, updatedAt, deviceTag, schemaVersion)
  }

  private logError(scope: string, error: object): void {
    const err: BusinessError = error as BusinessError
    hilog.error(0x0000, 'AgcSnapshotStore', scope + ' failed: code=' + err.code + ' message=' + err.message)
  }
}

export default new AgcCloudSnapshotStore()
