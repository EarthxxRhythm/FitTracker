/**
 * CloudSnapshotStore —— 云快照存储抽象。
 *
 * 载荷为整包 JSON（用户数据聚合信封），每个用户一条快照。
 * 实现：
 *  - LocalSandboxSnapshotStore：本机文件模拟云端存储（AGC 未配置 / 测试环境）
 *  - AgcCloudSnapshotStore（Wave 5）：AGC 云数据库 SyncSnapshot 对象 CRUD
 */
import { Context } from '@kit.AbilityKit'
import { fileIo } from '@kit.CoreFileKit'

export const SNAPSHOT_SCHEMA_VERSION: number = 1
const SANDBOX_SNAPSHOT_DIR: string = 'cloud_sandbox'

export interface CloudSnapshot {
  userId: string
  payloadJson: string
  updatedAt: number
  deviceTag: string
  schemaVersion: number
}

export function createCloudSnapshot(
  userId: string,
  payloadJson: string,
  updatedAt: number,
  deviceTag: string,
  schemaVersion: number
): CloudSnapshot {
  const snapshot: CloudSnapshot = {
    userId: userId,
    payloadJson: payloadJson,
    updatedAt: updatedAt,
    deviceTag: deviceTag,
    schemaVersion: schemaVersion
  }
  return snapshot
}

export abstract class CloudSnapshotStore {
  /** 拉取指定用户的最新快照；无快照返回 null。 */
  abstract pull(context: Context, userId: string): Promise<CloudSnapshot | null>

  /** 写入/覆盖用户快照；返回是否成功。 */
  abstract push(context: Context, snapshot: CloudSnapshot): Promise<boolean>
}

class LocalSandboxSnapshotStore extends CloudSnapshotStore {
  async pull(context: Context, userId: string): Promise<CloudSnapshot | null> {
    const filePath: string = this.resolveFilePath(context, userId)
    if (!this.pathExists(filePath)) {
      return null
    }
    try {
      const json: string = await fileIo.readText(filePath)
      const snapshot = JSON.parse(json) as CloudSnapshot
      if (!this.isValidSnapshot(snapshot)) {
        return null
      }
      return snapshot
    } catch (error) {
      return null
    }
  }

  async push(context: Context, snapshot: CloudSnapshot): Promise<boolean> {
    const dirPath: string = this.resolveDirPath(context)
    const filePath: string = this.resolveFilePath(context, snapshot.userId)
    try {
      await this.ensureDirectory(dirPath)
      this.writeTextFile(filePath, JSON.stringify(snapshot))
      return true
    } catch (error) {
      return false
    }
  }

  private resolveDirPath(context: Context): string {
    return context.filesDir + '/' + SANDBOX_SNAPSHOT_DIR
  }

  private resolveFilePath(context: Context, userId: string): string {
    return this.resolveDirPath(context) + '/' + this.encodeUserId(userId) + '.json'
  }

  private encodeUserId(userId: string): string {
    // 可逆编码：不同 userId 绝不映射到同一文件名（避免有损替换的跨账号碰撞）
    const encoded: string = encodeURIComponent(userId)
    return encoded.length > 0 ? encoded : 'unknown'
  }

  private async ensureDirectory(dirPath: string): Promise<void> {
    if (this.pathExists(dirPath)) {
      return
    }
    await fileIo.mkdir(dirPath, true)
  }

  private writeTextFile(filePath: string, value: string): void {
    const file = fileIo.openSync(
      filePath,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
    )
    try {
      fileIo.writeSync(file.fd, value)
    } finally {
      try {
        fileIo.closeSync(file.fd)
      } catch (error) {
        // 关闭失败不影响写入结果
      }
    }
  }

  private pathExists(filePath: string): boolean {
    try {
      return fileIo.accessSync(filePath)
    } catch (error) {
      return false
    }
  }

  private isValidSnapshot(snapshot: CloudSnapshot): boolean {
    if (snapshot === null || snapshot === undefined) {
      return false
    }
    if (snapshot.schemaVersion !== SNAPSHOT_SCHEMA_VERSION) {
      return false
    }
    if (typeof snapshot.userId !== 'string' || snapshot.userId.length === 0) {
      return false
    }
    if (typeof snapshot.payloadJson !== 'string' || snapshot.payloadJson.length === 0) {
      return false
    }
    if (typeof snapshot.updatedAt !== 'number' || !Number.isFinite(snapshot.updatedAt)) {
      return false
    }
    return true
  }
}

export default new LocalSandboxSnapshotStore()
