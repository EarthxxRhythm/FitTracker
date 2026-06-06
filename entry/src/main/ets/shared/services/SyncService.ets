/**
 * SyncService - placeholder content sync state.
 *
 * Feature #4: local repositories and app state.
 */
import {
  ContentSyncManifest,
  ContentSyncMetadata,
  ContentSyncStatus,
  createContentSyncMetadata,
  createContentSyncStatus
} from '../models/TrainingModels'
import ContentRepository from './ContentRepository'

const CONTENT_SYNC_SCHEMA_VERSION: number = 1
const FULL_PACKAGE_KIND: string = 'full'
const LOCAL_STATUS: string = 'local_available'
const JSONL_FALLBACK_SOURCE_ID: string = 'jsonl_seed'

class SyncService {
  getLocalStatus(): ContentSyncStatus {
    const sourceInfo = ContentRepository.getContentSourceInfo()
    return createContentSyncStatus(
      ContentRepository.getLocalContentVersion(),
      0,
      0,
      0,
      0,
      sourceInfo.sourceId,
      sourceInfo.sourceName,
      JSONL_FALLBACK_SOURCE_ID,
      LOCAL_STATUS,
      ''
    )
  }

  createLocalMetadata(): ContentSyncMetadata {
    const status: ContentSyncStatus = this.getLocalStatus()
    return createContentSyncMetadata(
      CONTENT_SYNC_SCHEMA_VERSION,
      status.localVersion,
      status.remoteVersion,
      status.lastCheckedAt,
      status.lastSyncAttemptAt,
      status.lastAppliedAt,
      status.activeSourceId,
      status.fallbackSourceId,
      status.status,
      status.failureReason
    )
  }

  supportsManifest(manifest: ContentSyncManifest): boolean {
    if (manifest.syncSchemaVersion !== CONTENT_SYNC_SCHEMA_VERSION) {
      return false
    }
    if (manifest.packageKind !== FULL_PACKAGE_KIND) {
      return false
    }
    if (manifest.packageVersion <= 0) {
      return false
    }
    if (manifest.packageUrl.trim().length === 0 || manifest.packageChecksum.trim().length === 0) {
      return false
    }
    return manifest.exerciseCount > 0
  }

  shouldApplyManifest(localStatus: ContentSyncStatus, manifest: ContentSyncManifest): boolean {
    if (!this.supportsManifest(manifest)) {
      return false
    }
    return manifest.packageVersion > localStatus.localVersion
  }

  canTrainOffline(): boolean {
    return true
  }
}

export default new SyncService()
