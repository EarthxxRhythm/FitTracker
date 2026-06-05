/**
 * EntryBackupAbility -- bridge system backup callbacks to the shared JSON backup schema.
 *
 * Feature #41: reuse manual backup package structure for system backup and restore entrypoints.
 */
import { hilog } from '@kit.PerformanceAnalysisKit'
import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit'
import SystemBackupBridgeService, {
  SystemBackupBridgeResult
} from '../shared/services/SystemBackupBridgeService'

const DOMAIN = 0x0000
const TAG = 'FitTrackerBackup'

export function getJsonBooleanText(value: boolean): string {
  if (value) {
    return 'true'
  }
  return 'false'
}

export function escapeBackupJsonString(value: string): string {
  let escapedValue: string = value
  escapedValue = escapedValue.replace(/\\/g, '\\\\')
  escapedValue = escapedValue.replace(/"/g, '\\"')
  escapedValue = escapedValue.replace(/\r/g, '\\r')
  escapedValue = escapedValue.replace(/\n/g, '\\n')
  return escapedValue
}

export function createBackupCallbackResult(operation: string, result: SystemBackupBridgeResult): string {
  const errorCode: number = result.success ? 0 : 1
  return '{"type":"' + operation + '","errorCode":' + errorCode.toString() +
    ',"errorInfo":"' + escapeBackupJsonString(result.detailText) + '"}'
}

export function createBackupProcessInfo(stage: string, result: SystemBackupBridgeResult): string {
  return '{"stage":"' + stage + '","statusId":"' + result.statusId +
    '","success":' + getJsonBooleanText(result.success) +
    ',"backupFilePath":"' + escapeBackupJsonString(result.backupFilePath) +
    '","detailText":"' + escapeBackupJsonString(result.detailText) + '"}'
}

export function createIdleBackupProcessInfo(): string {
  return '{"stage":"idle","statusId":"idle","success":false,"backupFilePath":"","detailText":"no backup activity yet"}'
}

export default class EntryBackupAbility extends BackupExtensionAbility {
  private lastProcessInfo: string = ''

  async onBackup(): Promise<void> {
    const result: SystemBackupBridgeResult = await SystemBackupBridgeService.exportBackupPackageToDirectory(
      this.context,
      this.context.backupDir
    )
    this.recordProcessInfo('backup', result)
  }

  async onBackupEx(backupInfo: string): Promise<string> {
    hilog.info(DOMAIN, TAG, 'onBackupEx info %{public}s', backupInfo)
    const result: SystemBackupBridgeResult = await SystemBackupBridgeService.exportBackupPackageToDirectory(
      this.context,
      this.context.backupDir
    )
    this.recordProcessInfo('backup_ex', result)
    return this.createCallbackResult('backup', result)
  }

  async onRestore(bundleVersion: BundleVersion): Promise<void> {
    hilog.info(DOMAIN, TAG, 'onRestore %{public}s', JSON.stringify(bundleVersion))
    const result: SystemBackupBridgeResult = await SystemBackupBridgeService.importBackupPackageFromDirectory(
      this.context,
      this.context.backupDir
    )
    this.recordProcessInfo('restore', result)
  }

  async onRestoreEx(bundleVersion: BundleVersion, restoreInfo: string): Promise<string> {
    hilog.info(DOMAIN, TAG, 'onRestoreEx version %{public}s', JSON.stringify(bundleVersion))
    hilog.info(DOMAIN, TAG, 'onRestoreEx info %{public}s', restoreInfo)
    const result: SystemBackupBridgeResult = await SystemBackupBridgeService.importBackupPackageFromDirectory(
      this.context,
      this.context.backupDir
    )
    this.recordProcessInfo('restore_ex', result)
    return this.createCallbackResult('restore', result)
  }

  onProcess(): string {
    if (this.lastProcessInfo.length === 0) {
      return createIdleBackupProcessInfo()
    }
    return this.lastProcessInfo
  }

  async onRelease(scenario: number): Promise<void> {
    hilog.info(DOMAIN, TAG, 'onRelease scenario %{public}d', scenario)
    this.lastProcessInfo = ''
  }

  private recordProcessInfo(stage: string, result: SystemBackupBridgeResult): void {
    this.lastProcessInfo = createBackupProcessInfo(stage, result)
    if (result.success) {
      hilog.info(
        DOMAIN,
        TAG,
        '%{public}s success %{public}s %{public}s',
        stage,
        result.statusId,
        result.backupFilePath
      )
      return
    }
    hilog.error(
      DOMAIN,
      TAG,
      '%{public}s failed %{public}s %{public}s',
      stage,
      result.statusId,
      result.detailText
    )
  }

  private createCallbackResult(operation: string, result: SystemBackupBridgeResult): string {
    return createBackupCallbackResult(operation, result)
  }

  private createProcessInfo(stage: string, result: SystemBackupBridgeResult): string {
    return createBackupProcessInfo(stage, result)
  }

  private getJsonBooleanText(value: boolean): string {
    return getJsonBooleanText(value)
  }

  private escapeJsonString(value: string): string {
    return escapeBackupJsonString(value)
  }
}
