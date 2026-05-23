/**
 * SyncService - placeholder content sync state.
 *
 * Feature #4: local repositories and app state.
 */
import { ContentSyncStatus, createContentSyncStatus } from '../models/TrainingModels'
import ContentRepository from './ContentRepository'

class SyncService {
  getLocalStatus(): ContentSyncStatus {
    return createContentSyncStatus(ContentRepository.getLocalContentVersion(), 0, 0, 'local_available')
  }

  canTrainOffline(): boolean {
    return true
  }
}

export default new SyncService()
