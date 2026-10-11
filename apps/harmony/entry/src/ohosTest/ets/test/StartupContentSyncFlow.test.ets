/**
 * StartupContentSyncFlow.test -- startup content sync orchestration coverage.
 */
import { abilityDelegatorRegistry } from '@kit.TestKit'
import { afterAll, beforeAll, beforeEach, describe, expect, it } from '@ohos/hypium'
import {
  ContentSyncManifest,
  ContentSyncMetadata,
  ExerciseContent,
  createContentSyncManifest,
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
import StartupContentSyncService from '../../../main/ets/shared/services/StartupContentSyncService'
import SyncService, { ContentSyncMetadataStore } from '../../../main/ets/shared/services/SyncService'

const STARTUP_CONTENT_SYNC_TEST_DB_NAME: string = 'fittracker_startup_content_sync_test_' + Date.now().toString() + '.db'

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
  packageVersion: number,
  exerciseCount: number
): ContentSyncManifest {
  return createContentSyncManifest(
    BUNDLED_CONTENT_SYNC_MANIFEST.syncSchemaVersion,
    BUNDLED_CONTENT_SYNC_MANIFEST.packageKind,
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

export default function startupContentSyncFlowTest(): void {
  const fakeStore = new FakeContentSyncMetadataStore()

  describe('StartupContentSyncFlow', () => {
    beforeAll(() => {
      ContentDatabaseService.setDatabaseNameForTesting(STARTUP_CONTENT_SYNC_TEST_DB_NAME)
      SyncService.setStoreForTesting(fakeStore)
    })

    beforeEach(async () => {
      fakeStore.clear()
      SyncService.clearBundledPackageForTesting()
      ContentDatabaseService.clearSeedPackageForTesting()
      StartupContentSyncService.setFailBeforeSyncForTesting(false)
      ContentRepository.useJsonlSeedSource()
      await ContentDatabaseService.clearDatabaseForTesting(getTestContext())
    })

    afterAll(() => {
      SyncService.clearBundledPackageForTesting()
      SyncService.setStoreForTesting(null)
      ContentDatabaseService.clearSeedPackageForTesting()
      StartupContentSyncService.setFailBeforeSyncForTesting(false)
      ContentRepository.useJsonlSeedSource()
      ContentDatabaseService.setDatabaseNameForTesting('')
    })

    it('imports bundled content on first startup and records applied metadata', 0, async () => {
      const status = await StartupContentSyncService.prepareContent(getTestContext())
      const metadata: ContentSyncMetadata = await SyncService.readMetadata(getTestContext())

      expect(status.status).assertEqual('sync_applied')
      expect(status.activeSourceId).assertEqual('local_database')
      expect(metadata.status).assertEqual('sync_applied')
      expect(metadata.lastAppliedAt > 0).assertTrue()
      expect(ContentRepository.getContentSourceInfo().sourceId).assertEqual('local_database')
      expect(ContentRepository.getExercises().length).assertEqual(BUNDLED_CONTENT_SYNC_MANIFEST.exerciseCount)
    })

    it('loads the existing database on the next startup pass and stays up to date', 0, async () => {
      await StartupContentSyncService.prepareContent(getTestContext())

      ContentRepository.useJsonlSeedSource()
      const status = await StartupContentSyncService.prepareContent(getTestContext())
      const metadata: ContentSyncMetadata = await SyncService.readMetadata(getTestContext())

      expect(status.status).assertEqual('up_to_date')
      expect(status.activeSourceId).assertEqual('local_database')
      expect(metadata.status).assertEqual('up_to_date')
      expect(ContentRepository.getContentSourceInfo().sourceId).assertEqual('local_database')
    })

    it('keeps the existing database when a startup upgrade attempt fails', 0, async () => {
      await StartupContentSyncService.prepareContent(getTestContext())

      const upgradedExercises: ExerciseContent[] = createVersionedExercises(2)
      SyncService.setBundledPackageForTesting(
        createManifest(3, upgradedExercises.length),
        BUNDLED_CONTENT_SYNC_MUSCLES,
        BUNDLED_CONTENT_SYNC_EQUIPMENT,
        upgradedExercises
      )

      ContentRepository.useJsonlSeedSource()
      const status = await StartupContentSyncService.prepareContent(getTestContext())
      const metadata: ContentSyncMetadata = await SyncService.readMetadata(getTestContext())

      expect(status.status).assertEqual('sync_failed')
      expect(status.failureReason).assertEqual('content_version_mismatch')
      expect(status.activeSourceId).assertEqual('local_database')
      expect(metadata.status).assertEqual('sync_failed')
      expect(ContentRepository.getContentSourceInfo().sourceId).assertEqual('local_database')
      expect(ContentRepository.getExercises().length).assertEqual(BUNDLED_CONTENT_SYNC_MANIFEST.exerciseCount)
    })

    it('falls back to JSONL when startup has no database and bundled imports fail', 0, async () => {
      const upgradedExercises: ExerciseContent[] = createVersionedExercises(2)
      const mismatchedManifest: ContentSyncManifest = createManifest(3, upgradedExercises.length)
      SyncService.setBundledPackageForTesting(
        mismatchedManifest,
        BUNDLED_CONTENT_SYNC_MUSCLES,
        BUNDLED_CONTENT_SYNC_EQUIPMENT,
        upgradedExercises
      )
      ContentDatabaseService.setSeedPackageForTesting(
        mismatchedManifest,
        BUNDLED_CONTENT_SYNC_MUSCLES,
        BUNDLED_CONTENT_SYNC_EQUIPMENT,
        upgradedExercises
      )

      const status = await StartupContentSyncService.prepareContent(getTestContext())
      const metadata: ContentSyncMetadata = await SyncService.readMetadata(getTestContext())

      expect(status.status).assertEqual('sync_failed')
      expect(status.failureReason).assertEqual('content_version_mismatch')
      expect(status.activeSourceId).assertEqual('jsonl_seed')
      expect(metadata.status).assertEqual('sync_failed')
      expect(ContentRepository.getContentSourceInfo().sourceId).assertEqual('jsonl_seed')
    })

    it('falls back to JSONL sync status when startup orchestration throws before sync application', 0, async () => {
      await ContentDatabaseService.importPackageAndUseDatabase(
        getTestContext(),
        BUNDLED_CONTENT_SYNC_MANIFEST,
        BUNDLED_CONTENT_SYNC_MUSCLES,
        BUNDLED_CONTENT_SYNC_EQUIPMENT,
        BUNDLED_CONTENT_SYNC_EXERCISES
      )

      ContentRepository.useJsonlSeedSource()
      StartupContentSyncService.setFailBeforeSyncForTesting(true)
      const status = await StartupContentSyncService.prepareContent(getTestContext())
      const metadata: ContentSyncMetadata = await SyncService.readMetadata(getTestContext())

      expect(status.status).assertEqual('local_available')
      expect(status.activeSourceId).assertEqual('jsonl_seed')
      expect(metadata.status).assertEqual('local_available')
      expect(ContentRepository.getContentSourceInfo().sourceId).assertEqual('jsonl_seed')
    })
  })
}
