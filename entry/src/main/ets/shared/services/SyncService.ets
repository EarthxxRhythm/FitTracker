/**
 * SyncService -- bundled local content sync state and package application.
 *
 * Feature #4: local repositories and app state.
 */
import { Context } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { FitTrackerStores } from '../../app/AppState'
import {
  ContentSyncManifest,
  ContentSyncMetadata,
  ContentSyncStatus,
  EquipmentItem,
  ExerciseContent,
  MuscleGroup,
  createContentSyncMetadata,
  createContentSyncStatus
} from '../models/TrainingModels'
import {
  BUNDLED_CONTENT_SYNC_EQUIPMENT,
  BUNDLED_CONTENT_SYNC_EXERCISES,
  BUNDLED_CONTENT_SYNC_MANIFEST,
  BUNDLED_CONTENT_SYNC_MUSCLES
} from '../../generated/LocalContentSyncPackage'
import ContentRepository, { ContentSourceInfo } from './ContentRepository'
import ContentDatabaseService from './ContentDatabaseService'

const CONTENT_SYNC_SCHEMA_VERSION: number = 1
const FULL_PACKAGE_KIND: string = 'full'
const KEY_METADATA: string = 'metadata'
const STATUS_LOCAL_AVAILABLE: string = 'local_available'
const STATUS_UP_TO_DATE: string = 'up_to_date'
const STATUS_SYNC_APPLIED: string = 'sync_applied'
const STATUS_SYNC_FAILED: string = 'sync_failed'
const STATUS_MANIFEST_UNSUPPORTED: string = 'manifest_unsupported'
const JSONL_FALLBACK_SOURCE_ID: string = 'jsonl_seed'
const LOCAL_DATABASE_SOURCE_ID: string = 'local_database'

interface BundledContentSyncPackageData {
  manifest: ContentSyncManifest
  muscles: MuscleGroup[]
  equipment: EquipmentItem[]
  exercises: ExerciseContent[]
}

export abstract class ContentSyncMetadataStore {
  abstract get(key: string, defaultValue: string): Promise<string>
  abstract put(key: string, value: string): Promise<void>
  abstract flush(): Promise<void>
}

class ArkPreferencesContentSyncStore extends ContentSyncMetadataStore {
  private readonly prefs: preferences.Preferences

  constructor(prefs: preferences.Preferences) {
    super()
    this.prefs = prefs
  }

  async get(key: string, defaultValue: string): Promise<string> {
    return await this.prefs.get(key, defaultValue) as string
  }

  async put(key: string, value: string): Promise<void> {
    await this.prefs.put(key, value)
  }

  async flush(): Promise<void> {
    await this.prefs.flush()
  }
}

class SyncService {
  private testStore: ContentSyncMetadataStore | null = null
  private testPackage: BundledContentSyncPackageData | null = null

  setStoreForTesting(store: ContentSyncMetadataStore | null): void {
    this.testStore = store
  }

  setBundledPackageForTesting(
    manifest: ContentSyncManifest,
    muscles: MuscleGroup[],
    equipment: EquipmentItem[],
    exercises: ExerciseContent[]
  ): void {
    this.testPackage = {
      manifest: manifest,
      muscles: muscles,
      equipment: equipment,
      exercises: exercises
    }
  }

  clearBundledPackageForTesting(): void {
    this.testPackage = null
  }

  async readMetadata(context: Context): Promise<ContentSyncMetadata> {
    const fallbackMetadata: ContentSyncMetadata = this.createDefaultMetadata()
    try {
      const store: ContentSyncMetadataStore = await this.getStore(context)
      const json: string = await store.get(KEY_METADATA, '')
      if (json.trim().length === 0) {
        return fallbackMetadata
      }
      const metadata: ContentSyncMetadata = JSON.parse(json) as ContentSyncMetadata
      if (!this.isValidMetadata(metadata)) {
        return fallbackMetadata
      }
      return this.copyMetadata(metadata)
    } catch (error) {
      return fallbackMetadata
    }
  }

  async getSyncStatus(context: Context): Promise<ContentSyncStatus> {
    const metadata: ContentSyncMetadata = await this.readMetadata(context)
    return this.createStatusFromMetadata(ContentRepository.getContentSourceInfo(), metadata)
  }

  async applyBundledPackageIfNeeded(context: Context): Promise<ContentSyncStatus> {
    const bundledPackage: BundledContentSyncPackageData = this.getBundledPackage()
    const now: number = Date.now()
    const previousMetadata: ContentSyncMetadata = await this.readMetadata(context)
    const currentSourceInfo: ContentSourceInfo = ContentRepository.getContentSourceInfo()
    const localVersion: number = ContentRepository.getLocalContentVersion()
    const manifestFailureReason: string = this.getManifestFailureReason(bundledPackage.manifest)

    if (manifestFailureReason.length > 0) {
      const unsupportedMetadata: ContentSyncMetadata = createContentSyncMetadata(
        CONTENT_SYNC_SCHEMA_VERSION,
        localVersion,
        this.getKnownRemoteVersion(bundledPackage.manifest),
        now,
        previousMetadata.lastSyncAttemptAt,
        previousMetadata.lastAppliedAt,
        currentSourceInfo.sourceId,
        JSONL_FALLBACK_SOURCE_ID,
        STATUS_MANIFEST_UNSUPPORTED,
        manifestFailureReason
      )
      await this.writeMetadata(context, unsupportedMetadata)
      return this.createStatusFromMetadata(currentSourceInfo, unsupportedMetadata)
    }

    if (this.shouldRecordExistingBundledDatabase(currentSourceInfo, previousMetadata, bundledPackage.manifest, localVersion)) {
      const adoptedMetadata: ContentSyncMetadata = createContentSyncMetadata(
        CONTENT_SYNC_SCHEMA_VERSION,
        localVersion,
        bundledPackage.manifest.packageVersion,
        now,
        previousMetadata.lastSyncAttemptAt,
        now,
        currentSourceInfo.sourceId,
        JSONL_FALLBACK_SOURCE_ID,
        STATUS_SYNC_APPLIED,
        ''
      )
      await this.writeMetadata(context, adoptedMetadata)
      return this.createStatusFromMetadata(currentSourceInfo, adoptedMetadata)
    }

    if (!this.shouldApplyBundledPackage(currentSourceInfo, bundledPackage.manifest, localVersion)) {
      const upToDateMetadata: ContentSyncMetadata = createContentSyncMetadata(
        CONTENT_SYNC_SCHEMA_VERSION,
        localVersion,
        bundledPackage.manifest.packageVersion,
        now,
        previousMetadata.lastSyncAttemptAt,
        previousMetadata.lastAppliedAt,
        currentSourceInfo.sourceId,
        JSONL_FALLBACK_SOURCE_ID,
        STATUS_UP_TO_DATE,
        ''
      )
      await this.writeMetadata(context, upToDateMetadata)
      return this.createStatusFromMetadata(currentSourceInfo, upToDateMetadata)
    }

    const applied: boolean = await ContentDatabaseService.importPackageAndUseDatabase(
      context,
      bundledPackage.manifest,
      bundledPackage.muscles,
      bundledPackage.equipment,
      bundledPackage.exercises
    )
    if (applied) {
      const appliedSourceInfo: ContentSourceInfo = ContentRepository.getContentSourceInfo()
      const appliedLocalVersion: number = ContentRepository.getLocalContentVersion()
      const appliedMetadata: ContentSyncMetadata = createContentSyncMetadata(
        CONTENT_SYNC_SCHEMA_VERSION,
        appliedLocalVersion,
        bundledPackage.manifest.packageVersion,
        now,
        now,
        now,
        appliedSourceInfo.sourceId,
        JSONL_FALLBACK_SOURCE_ID,
        STATUS_SYNC_APPLIED,
        ''
      )
      await this.writeMetadata(context, appliedMetadata)
      return this.createStatusFromMetadata(appliedSourceInfo, appliedMetadata)
    }

    const failedSourceInfo: ContentSourceInfo = ContentRepository.getContentSourceInfo()
    const failedLocalVersion: number = ContentRepository.getLocalContentVersion()
    const failedMetadata: ContentSyncMetadata = createContentSyncMetadata(
      CONTENT_SYNC_SCHEMA_VERSION,
      failedLocalVersion,
      bundledPackage.manifest.packageVersion,
      now,
      now,
      previousMetadata.lastAppliedAt,
      failedSourceInfo.sourceId,
      JSONL_FALLBACK_SOURCE_ID,
      STATUS_SYNC_FAILED,
      ContentDatabaseService.getLastImportFailureReason()
    )
    await this.writeMetadata(context, failedMetadata)
    return this.createStatusFromMetadata(failedSourceInfo, failedMetadata)
  }

  private shouldApplyBundledPackage(
    currentSourceInfo: ContentSourceInfo,
    manifest: ContentSyncManifest,
    localVersion: number
  ): boolean {
    return manifest.packageVersion > localVersion
  }

  private shouldRecordExistingBundledDatabase(
    currentSourceInfo: ContentSourceInfo,
    previousMetadata: ContentSyncMetadata,
    manifest: ContentSyncManifest,
    localVersion: number
  ): boolean {
    if (!currentSourceInfo.databaseBacked) {
      return false
    }
    if (currentSourceInfo.sourceId !== LOCAL_DATABASE_SOURCE_ID) {
      return false
    }
    if (previousMetadata.lastAppliedAt > 0) {
      return false
    }
    return localVersion >= manifest.packageVersion
  }

  private getKnownRemoteVersion(manifest: ContentSyncManifest): number {
    if (manifest.packageVersion > 0) {
      return manifest.packageVersion
    }
    return 0
  }

  private createDefaultMetadata(): ContentSyncMetadata {
    const sourceInfo: ContentSourceInfo = ContentRepository.getContentSourceInfo()
    const bundledPackage: BundledContentSyncPackageData = this.getBundledPackage()
    return createContentSyncMetadata(
      CONTENT_SYNC_SCHEMA_VERSION,
      ContentRepository.getLocalContentVersion(),
      this.getKnownRemoteVersion(bundledPackage.manifest),
      0,
      0,
      0,
      sourceInfo.sourceId,
      JSONL_FALLBACK_SOURCE_ID,
      STATUS_LOCAL_AVAILABLE,
      ''
    )
  }

  private createStatusFromMetadata(
    sourceInfo: ContentSourceInfo,
    metadata: ContentSyncMetadata
  ): ContentSyncStatus {
    return createContentSyncStatus(
      ContentRepository.getLocalContentVersion(),
      metadata.lastKnownRemoteVersion,
      metadata.lastCheckedAt,
      metadata.lastSyncAttemptAt,
      metadata.lastAppliedAt,
      sourceInfo.sourceId,
      sourceInfo.sourceName,
      metadata.fallbackSourceId,
      metadata.status,
      metadata.failureReason
    )
  }

  private getManifestFailureReason(manifest: ContentSyncManifest): string {
    if (manifest.syncSchemaVersion !== CONTENT_SYNC_SCHEMA_VERSION) {
      return 'unsupported_schema'
    }
    if (manifest.packageKind !== FULL_PACKAGE_KIND) {
      return 'unsupported_kind'
    }
    if (manifest.packageVersion <= 0 || manifest.generatedAt <= 0) {
      return 'invalid_manifest'
    }
    if (manifest.packageUrl.trim().length === 0 || manifest.packageChecksum.trim().length === 0) {
      return 'invalid_manifest'
    }
    if (manifest.packageSizeBytes <= 0 || manifest.exerciseCount <= 0) {
      return 'invalid_manifest'
    }
    return ''
  }

  private isValidMetadata(metadata: ContentSyncMetadata): boolean {
    if (metadata.syncSchemaVersion !== CONTENT_SYNC_SCHEMA_VERSION) {
      return false
    }
    if (!Number.isFinite(metadata.localVersion) || !Number.isFinite(metadata.lastKnownRemoteVersion)) {
      return false
    }
    if (!Number.isFinite(metadata.lastCheckedAt) || !Number.isFinite(metadata.lastSyncAttemptAt)) {
      return false
    }
    if (!Number.isFinite(metadata.lastAppliedAt)) {
      return false
    }
    if (!this.isStringValue(metadata.activeSourceId) || !this.isStringValue(metadata.fallbackSourceId)) {
      return false
    }
    if (!this.isStringValue(metadata.status) || !this.isStringValue(metadata.failureReason)) {
      return false
    }
    return true
  }

  private isStringValue(value: string): boolean {
    if (value === null || value === undefined) {
      return false
    }
    return value.toString() === value
  }

  private copyMetadata(source: ContentSyncMetadata): ContentSyncMetadata {
    return createContentSyncMetadata(
      source.syncSchemaVersion,
      source.localVersion,
      source.lastKnownRemoteVersion,
      source.lastCheckedAt,
      source.lastSyncAttemptAt,
      source.lastAppliedAt,
      source.activeSourceId,
      source.fallbackSourceId,
      source.status,
      source.failureReason
    )
  }

  private async writeMetadata(context: Context, metadata: ContentSyncMetadata): Promise<void> {
    try {
      const store: ContentSyncMetadataStore = await this.getStore(context)
      await store.put(KEY_METADATA, JSON.stringify(metadata))
      await store.flush()
    } catch (error) {
    }
  }

  private async getStore(context: Context): Promise<ContentSyncMetadataStore> {
    if (this.testStore !== null) {
      return this.testStore
    }
    const prefs = await preferences.getPreferences(context, FitTrackerStores.CONTENT_SYNC)
    return new ArkPreferencesContentSyncStore(prefs)
  }

  private getBundledPackage(): BundledContentSyncPackageData {
    if (this.testPackage !== null) {
      return this.testPackage
    }
    return {
      manifest: BUNDLED_CONTENT_SYNC_MANIFEST,
      muscles: BUNDLED_CONTENT_SYNC_MUSCLES,
      equipment: BUNDLED_CONTENT_SYNC_EQUIPMENT,
      exercises: BUNDLED_CONTENT_SYNC_EXERCISES
    }
  }

  canTrainOffline(): boolean {
    return true
  }
}

export default new SyncService()
