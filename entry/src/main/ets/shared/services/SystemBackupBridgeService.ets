/**
 * SystemBackupBridgeService -- bridge the shared JSON backup schema into the system backup directory.
 *
 * Feature #41: reuse the existing manual backup package for EntryBackupAbility.
 */
import { fileIo } from '@kit.CoreFileKit'
import UserDataBackupService, { UserDataBackupImportResult } from './UserDataBackupService'

const SYSTEM_BACKUP_FILE_NAME = 'fittracker-user-data-backup.json'

export interface SystemBackupBridgeResult {
  success: boolean
  statusId: string
  detailText: string
  backupFilePath: string
  importedResult: UserDataBackupImportResult | null
}

class SystemBackupBridgeService {
  getBackupFilePath(backupDir: string): string {
    if (backupDir.endsWith('\\') || backupDir.endsWith('/')) {
      return backupDir + SYSTEM_BACKUP_FILE_NAME
    }
    return backupDir + '/' + SYSTEM_BACKUP_FILE_NAME
  }

  async exportBackupPackageToDirectory(context: Context, backupDir: string): Promise<SystemBackupBridgeResult> {
    const backupFilePath: string = this.getBackupFilePath(backupDir)
    try {
      await this.ensureDirectory(backupDir)
      const packageText: string = await UserDataBackupService.exportPackage(context)
      this.writeTextFile(backupFilePath, packageText)
      return this.createResult(true, 'backup_exported', '系统备份包已写入备份目录。', backupFilePath, null)
    } catch (e) {
      return this.createResult(false, 'backup_export_failed', '系统备份导出失败。', backupFilePath, null)
    }
  }

  async importBackupPackageFromDirectory(context: Context, backupDir: string): Promise<SystemBackupBridgeResult> {
    const backupFilePath: string = this.getBackupFilePath(backupDir)
    if (!fileIo.accessSync(backupFilePath)) {
      return this.createResult(false, 'backup_file_missing', '备份目录中没有找到可恢复的 JSON 包。', backupFilePath, null)
    }

    let packageText: string = ''
    try {
      packageText = await fileIo.readText(backupFilePath)
    } catch (e) {
      return this.createResult(false, 'backup_read_failed', '系统备份包读取失败。', backupFilePath, null)
    }

    const importedResult: UserDataBackupImportResult = await UserDataBackupService.importPackage(context, packageText)
    return this.createResult(
      importedResult.success,
      importedResult.success ? 'backup_restored' : importedResult.statusId,
      importedResult.statusText,
      backupFilePath,
      importedResult
    )
  }

  private async ensureDirectory(backupDir: string): Promise<void> {
    if (fileIo.accessSync(backupDir)) {
      return
    }
    await fileIo.mkdir(backupDir, true)
  }

  private writeTextFile(filePath: string, value: string): void {
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

  private createResult(
    success: boolean,
    statusId: string,
    detailText: string,
    backupFilePath: string,
    importedResult: UserDataBackupImportResult | null
  ): SystemBackupBridgeResult {
    const result: SystemBackupBridgeResult = {
      success: success,
      statusId: statusId,
      detailText: detailText,
      backupFilePath: backupFilePath,
      importedResult: importedResult
    }
    return result
  }
}

export default new SystemBackupBridgeService()
