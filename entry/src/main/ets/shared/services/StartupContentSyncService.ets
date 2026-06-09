/**
 * StartupContentSyncService -- orchestrates startup-time content source preparation.
 *
 * Phase 4: keep the startup content sync sequence consistent and testable.
 */
import { Context } from '@kit.AbilityKit'
import { ContentSyncStatus } from '../models/TrainingModels'
import ContentDatabaseService from './ContentDatabaseService'
import ContentRepository from './ContentRepository'
import SyncService from './SyncService'

class StartupContentSyncService {
  private failBeforeSyncForTesting: boolean = false

  setFailBeforeSyncForTesting(enabled: boolean): void {
    this.failBeforeSyncForTesting = enabled
  }

  async prepareContent(context: Context): Promise<ContentSyncStatus> {
    try {
      await ContentDatabaseService.loadDatabaseAndUse(context)
      if (this.failBeforeSyncForTesting) {
        throw new Error('startup_content_sync_forced_failure')
      }
      let status: ContentSyncStatus = await SyncService.applyBundledPackageIfNeeded(context)
      if (!ContentRepository.getContentSourceInfo().databaseBacked) {
        const imported: boolean = await ContentDatabaseService.importSeedAndUseDatabase(context)
        if (imported) {
          status = await SyncService.applyBundledPackageIfNeeded(context)
        } else {
          status = await SyncService.getSyncStatus(context)
        }
      }
      return status
    } catch (error) {
      ContentRepository.useJsonlSeedSource()
      return await SyncService.getSyncStatus(context)
    }
  }
}

export default new StartupContentSyncService()
