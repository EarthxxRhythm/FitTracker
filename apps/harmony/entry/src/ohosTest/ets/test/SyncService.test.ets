import { abilityDelegatorRegistry } from '@kit.TestKit'
import { afterAll, beforeAll, beforeEach, describe, expect, it } from '@ohos/hypium'
import {
  ContentSyncManifest,
  ContentSyncMetadata,
  ExerciseContent,
  createContentSyncManifest,
  createContentSyncMetadata,
  createExerciseContent
} from '../../../main/ets/shared/models/TrainingModels'
import {
  BUNDLED_CONTENT_SYNC_EQUIPMENT,
  BUNDLED_CONTENT_SYNC_EXERCISES,
  BUNDLED_CONTENT_SYNC_MANIFEST,
  BUNDLED_CONTENT_SYNC_MUSCLES
} from '../../../main/ets/generated/LocalContentSyncPackage'
import ContentDatabaseService from '../../../main/ets/shared/services/ContentDatabaseService'
import ContentRepository from '../../../main/ets/shared/services/ContentRepository'
import SyncService, { ContentSyncMetadataStore } from '../../../main/ets/shared/services/SyncService'

const SYNC_SERVICE_TEST_DB_NAME: string = 'fittracker_content_sync_service_test_' + Date.now().toString() + '.db'

class FakeContentSyncMetadataStore extends ContentSyncMetadataStore {
  private metadataJson: string = ''

  async get(key: string, defaultValue: string): Promise<string> {
    if (key === 'metadata' && this.metadataJson.length > 0) {
      return this.metadataJson
    }
    return defaultValue
  }

  async put(key: string, value: string): Promise<void> {
    if (key === 'metadata') {
      this.metadataJson = value
    }
  }

  async flush(): Promise<void> {
  }

  clear(): void {
    this.metadataJson = ''
  }
}

function getTestContext(): Context {
  const appContext: Context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext()
  return appContext.getApplicationContext().createModuleContext('entry')
}

function copyStringArray(source: string[]): string[] {
  const values: string[] = []
  for (let index = 0; index < source.length; index++) {
    values.push(source[index])
  }
  return values
}

function cloneExerciseWithVersion(source: ExerciseContent, contentVersion: number): ExerciseContent {
  return createExerciseContent(
    source.exerciseId,
    source.nameZh,
    source.nameEn,
    copyStringArray(source.aliases),
    copyStringArray(source.primaryMuscleIds),
    copyStringArray(source.secondaryMuscleIds),
    copyStringArray(source.equipmentIds),
    source.difficulty,
    copyStringArray(source.goalTags),
    source.videoUrl,
    source.coverUrl,
    source.coverSourceLabel,
    source.videoSourceLabel,
    source.mediaLicenseText,
    copyStringArray(source.steps),
    copyStringArray(source.cues),
    copyStringArray(source.commonMistakes),
    copyStringArray(source.safetyNotes),
    copyStringArray(source.alternativeExerciseIds),
    contentVersion
  )
}

function createVersionedExercises(contentVersion: number): ExerciseContent[] {
  const exercises: ExerciseContent[] = []
  for (let index = 0; index < BUNDLED_CONTENT_SYNC_EXERCISES.length; index++) {
    exercises.push(cloneExerciseWithVersion(BUNDLED_CONTENT_SYNC_EXERCISES[index], contentVersion))
  }
  return exercises
}

function createManifest(
  syncSchemaVersion: number,
  packageKind: string,
  packageVersion: number,
  exerciseCount: number
): ContentSyncManifest {
  return createContentSyncManifest(
    syncSchemaVersion,
    packageKind,
    packageVersion,
    BUNDLED_CONTENT_SYNC_MANIFEST.packageUrl,
    BUNDLED_CONTENT_SYNC_MANIFEST.packageChecksum,
    BUNDLED_CONTENT_SYNC_MANIFEST.packageSizeBytes,
    BUNDLED_CONTENT_SYNC_MANIFEST.generatedAt,
    exerciseCount,
    BUNDLED_CONTENT_SYNC_MANIFEST.releaseChannel,
    BUNDLED_CONTENT_SYNC_MANIFEST.sourceNote
  )
}

export default function syncServiceTest(): void {
  const fakeStore = new FakeContentSyncMetadataStore()

  describe('SyncService', () => {
    beforeAll(() => {
      ContentDatabaseService.setDatabaseNameForTesting(SYNC_SERVICE_TEST_DB_NAME)
      SyncService.setStoreForTesting(fakeStore)
    })

    beforeEach(async () => {
      fakeStore.clear()
      SyncService.clearBundledPackageForTesting()
      ContentRepository.useJsonlSeedSource()
      await ContentDatabaseService.clearDatabaseForTesting(getTestContext())
    })

    afterAll(() => {
      SyncService.clearBundledPackageForTesting()
      SyncService.setStoreForTesting(null)
      ContentRepository.useJsonlSeedSource()
      ContentDatabaseService.setDatabaseNameForTesting('')
    })

    it('returns local available status when no metadata has been stored yet', 0, async () => {
      const metadata: ContentSyncMetadata = await SyncService.readMetadata(getTestContext())
      const status = await SyncService.getSyncStatus(getTestContext())

      expect(metadata.status).assertEqual('local_available')
      expect(status.status).assertEqual('local_available')
      expect(status.activeSourceId).assertEqual('jsonl_seed')
      expect(status.remoteVersion).assertEqual(BUNDLED_CONTENT_SYNC_MANIFEST.packageVersion)
    })

    it('records manifest unsupported status when bundled schema is invalid', 0, async () => {
      SyncService.setBundledPackageForTesting(
        createManifest(99, 'full', 2, BUNDLED_CONTENT_SYNC_EXERCISES.length),
        BUNDLED_CONTENT_SYNC_MUSCLES,
        BUNDLED_CONTENT_SYNC_EQUIPMENT,
        createVersionedExercises(2)
      )

      const status = await SyncService.applyBundledPackageIfNeeded(getTestContext())
      const metadata: ContentSyncMetadata = await SyncService.readMetadata(getTestContext())

      expect(status.status).assertEqual('manifest_unsupported')
      expect(status.failureReason).assertEqual('unsupported_schema')
      expect(metadata.status).assertEqual('manifest_unsupported')
      expect(ContentRepository.getContentSourceInfo().sourceId).assertEqual('jsonl_seed')
    })

    it('records manifest unsupported status when bundled package kind is not supported', 0, async () => {
      SyncService.setBundledPackageForTesting(
        createManifest(1, 'delta', 2, BUNDLED_CONTENT_SYNC_EXERCISES.length),
        BUNDLED_CONTENT_SYNC_MUSCLES,
        BUNDLED_CONTENT_SYNC_EQUIPMENT,
        createVersionedExercises(2)
      )

      const status = await SyncService.applyBundledPackageIfNeeded(getTestContext())
      const metadata: ContentSyncMetadata = await SyncService.readMetadata(getTestContext())

      expect(status.status).assertEqual('manifest_unsupported')
      expect(status.failureReason).assertEqual('unsupported_kind')
      expect(metadata.status).assertEqual('manifest_unsupported')
      expect(metadata.failureReason).assertEqual('unsupported_kind')
      expect(ContentRepository.getContentSourceInfo().sourceId).assertEqual('jsonl_seed')
    })

    it('records manifest unsupported status when bundled manifest fields are invalid', 0, async () => {
      SyncService.setBundledPackageForTesting(
        createManifest(1, 'full', 0, BUNDLED_CONTENT_SYNC_EXERCISES.length),
        BUNDLED_CONTENT_SYNC_MUSCLES,
        BUNDLED_CONTENT_SYNC_EQUIPMENT,
        createVersionedExercises(2)
      )

      const status = await SyncService.applyBundledPackageIfNeeded(getTestContext())
      const metadata: ContentSyncMetadata = await SyncService.readMetadata(getTestContext())

      expect(status.status).assertEqual('manifest_unsupported')
      expect(status.failureReason).assertEqual('invalid_manifest')
      expect(metadata.status).assertEqual('manifest_unsupported')
      expect(metadata.failureReason).assertEqual('invalid_manifest')
      expect(ContentRepository.getContentSourceInfo().sourceId).assertEqual('jsonl_seed')
    })

    it('marks bundled package as up to date when version does not exceed current local content', 0, async () => {
      const status = await SyncService.applyBundledPackageIfNeeded(getTestContext())
      const metadata: ContentSyncMetadata = await SyncService.readMetadata(getTestContext())

      expect(status.status).assertEqual('up_to_date')
      expect(metadata.status).assertEqual('up_to_date')
      expect(ContentRepository.getContentSourceInfo().sourceId).assertEqual('jsonl_seed')
    })

    it('imports a higher bundled package version and persists applied metadata', 0, async () => {
      const upgradedVersion: number = BUNDLED_CONTENT_SYNC_MANIFEST.packageVersion + 1
      const upgradedExercises: ExerciseContent[] = createVersionedExercises(upgradedVersion)
      SyncService.setBundledPackageForTesting(
        createManifest(1, 'full', upgradedVersion, upgradedExercises.length),
        BUNDLED_CONTENT_SYNC_MUSCLES,
        BUNDLED_CONTENT_SYNC_EQUIPMENT,
        upgradedExercises
      )

      const status = await SyncService.applyBundledPackageIfNeeded(getTestContext())
      const metadata: ContentSyncMetadata = await SyncService.readMetadata(getTestContext())

      expect(status.status).assertEqual('sync_applied')
      expect(status.activeSourceId).assertEqual('local_database')
      expect(status.localVersion).assertEqual(upgradedVersion)
      expect(metadata.status).assertEqual('sync_applied')
      expect(metadata.lastAppliedAt > 0).assertTrue()
    })

    it('records sync failure when package import self-check fails', 0, async () => {
      const upgradedExercises: ExerciseContent[] = createVersionedExercises(2)
      SyncService.setBundledPackageForTesting(
        createManifest(1, 'full', 3, upgradedExercises.length),
        BUNDLED_CONTENT_SYNC_MUSCLES,
        BUNDLED_CONTENT_SYNC_EQUIPMENT,
        upgradedExercises
      )

      const status = await SyncService.applyBundledPackageIfNeeded(getTestContext())
      const metadata: ContentSyncMetadata = await SyncService.readMetadata(getTestContext())

      expect(status.status).assertEqual('sync_failed')
      expect(status.failureReason).assertEqual('content_version_mismatch')
      expect(status.activeSourceId).assertEqual('jsonl_seed')
      expect(metadata.status).assertEqual('sync_failed')
      expect(metadata.failureReason).assertEqual('content_version_mismatch')
    })
  })
}
