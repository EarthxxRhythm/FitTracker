import { abilityDelegatorRegistry } from '@kit.TestKit'
import { afterAll, beforeAll, beforeEach, describe, expect, it } from '@ohos/hypium'
import {
  ContentSyncManifest,
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

const CONTENT_DATABASE_TEST_DB_NAME: string = 'fittracker_content_sync_test_' + Date.now().toString() + '.db'

function getTestContext(): Context {
  const appContext: Context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext()
  return appContext.getApplicationContext().createModuleContext('entry')
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

function copyStringArray(source: string[]): string[] {
  const values: string[] = []
  for (let index = 0; index < source.length; index++) {
    values.push(source[index])
  }
  return values
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

export default function contentDatabaseServiceTest(): void {
  describe('ContentDatabaseService', () => {
    beforeAll(() => {
      ContentDatabaseService.setDatabaseNameForTesting(CONTENT_DATABASE_TEST_DB_NAME)
    })

    beforeEach(async () => {
      ContentRepository.useJsonlSeedSource()
      await ContentDatabaseService.clearDatabaseForTesting(getTestContext())
    })

    afterAll(() => {
      ContentRepository.useJsonlSeedSource()
      ContentDatabaseService.setDatabaseNameForTesting('')
    })

    it('imports bundled package into local database and switches repository source', 0, async () => {
      const imported: boolean = await ContentDatabaseService.importPackageAndUseDatabase(
        getTestContext(),
        BUNDLED_CONTENT_SYNC_MANIFEST,
        BUNDLED_CONTENT_SYNC_MUSCLES,
        BUNDLED_CONTENT_SYNC_EQUIPMENT,
        BUNDLED_CONTENT_SYNC_EXERCISES
      )

      expect(imported).assertTrue()
      expect(ContentRepository.getContentSourceInfo().sourceId).assertEqual('local_database')
      expect(ContentRepository.getExercises().length).assertEqual(BUNDLED_CONTENT_SYNC_MANIFEST.exerciseCount)
      expect(ContentRepository.getLocalContentVersion()).assertEqual(BUNDLED_CONTENT_SYNC_MANIFEST.packageVersion)
    })

    it('loads existing imported database content on the next startup pass', 0, async () => {
      await ContentDatabaseService.importPackageAndUseDatabase(
        getTestContext(),
        BUNDLED_CONTENT_SYNC_MANIFEST,
        BUNDLED_CONTENT_SYNC_MUSCLES,
        BUNDLED_CONTENT_SYNC_EQUIPMENT,
        BUNDLED_CONTENT_SYNC_EXERCISES
      )

      ContentRepository.useJsonlSeedSource()
      const loaded: boolean = await ContentDatabaseService.loadDatabaseAndUse(getTestContext())

      expect(loaded).assertTrue()
      expect(ContentRepository.getContentSourceInfo().sourceId).assertEqual('local_database')
      expect(ContentRepository.getExercises().length).assertEqual(BUNDLED_CONTENT_SYNC_MANIFEST.exerciseCount)
    })

    it('returns false and keeps JSONL when startup load sees an empty database', 0, async () => {
      const loaded: boolean = await ContentDatabaseService.loadDatabaseAndUse(getTestContext())

      expect(loaded).assertFalse()
      expect(ContentDatabaseService.getLastImportFailureReason()).assertEqual('')
      expect(ContentRepository.getContentSourceInfo().sourceId).assertEqual('jsonl_seed')
      expect(ContentRepository.getExercises().length).assertEqual(BUNDLED_CONTENT_SYNC_MANIFEST.exerciseCount)
    })

    it('rejects stored database content when the bundled manifest self-check fails on startup', 0, async () => {
      const upgradedVersion: number = BUNDLED_CONTENT_SYNC_MANIFEST.packageVersion + 1
      const upgradedExercises: ExerciseContent[] = createVersionedExercises(upgradedVersion)
      const upgradedManifest: ContentSyncManifest = createManifest(
        upgradedVersion,
        upgradedExercises.length
      )

      const imported: boolean = await ContentDatabaseService.importPackageAndUseDatabase(
        getTestContext(),
        upgradedManifest,
        BUNDLED_CONTENT_SYNC_MUSCLES,
        BUNDLED_CONTENT_SYNC_EQUIPMENT,
        upgradedExercises
      )
      expect(imported).assertTrue()

      ContentRepository.useJsonlSeedSource()
      const loaded: boolean = await ContentDatabaseService.loadDatabaseAndUse(getTestContext())

      expect(loaded).assertFalse()
      expect(ContentDatabaseService.getLastImportFailureReason()).assertEqual('content_version_mismatch')
      expect(ContentRepository.getContentSourceInfo().sourceId).assertEqual('jsonl_seed')
      expect(ContentRepository.getLocalContentVersion()).assertEqual(BUNDLED_CONTENT_SYNC_MANIFEST.packageVersion)
    })

    it('rolls back count mismatch imports and keeps the existing database source available', 0, async () => {
      await ContentDatabaseService.importPackageAndUseDatabase(
        getTestContext(),
        BUNDLED_CONTENT_SYNC_MANIFEST,
        BUNDLED_CONTENT_SYNC_MUSCLES,
        BUNDLED_CONTENT_SYNC_EQUIPMENT,
        BUNDLED_CONTENT_SYNC_EXERCISES
      )

      const mismatchedManifest: ContentSyncManifest = createManifest(
        BUNDLED_CONTENT_SYNC_MANIFEST.packageVersion,
        BUNDLED_CONTENT_SYNC_MANIFEST.exerciseCount + 1
      )
      const imported: boolean = await ContentDatabaseService.importPackageAndUseDatabase(
        getTestContext(),
        mismatchedManifest,
        BUNDLED_CONTENT_SYNC_MUSCLES,
        BUNDLED_CONTENT_SYNC_EQUIPMENT,
        BUNDLED_CONTENT_SYNC_EXERCISES
      )

      expect(imported).assertFalse()
      expect(ContentDatabaseService.getLastImportFailureReason()).assertEqual('exercise_count_mismatch')
      expect(ContentRepository.getContentSourceInfo().sourceId).assertEqual('local_database')

      ContentRepository.useJsonlSeedSource()
      const loaded: boolean = await ContentDatabaseService.loadDatabaseAndUse(getTestContext())
      expect(loaded).assertTrue()
      expect(ContentRepository.getExercises().length).assertEqual(BUNDLED_CONTENT_SYNC_MANIFEST.exerciseCount)
    })

    it('falls back to JSONL when package import fails before any database source is active', 0, async () => {
      const versionedExercises: ExerciseContent[] = createVersionedExercises(2)
      const mismatchedVersionManifest: ContentSyncManifest = createManifest(3, versionedExercises.length)
      const imported: boolean = await ContentDatabaseService.importPackageAndUseDatabase(
        getTestContext(),
        mismatchedVersionManifest,
        BUNDLED_CONTENT_SYNC_MUSCLES,
        BUNDLED_CONTENT_SYNC_EQUIPMENT,
        versionedExercises
      )

      expect(imported).assertFalse()
      expect(ContentDatabaseService.getLastImportFailureReason()).assertEqual('content_version_mismatch')
      expect(ContentRepository.getContentSourceInfo().sourceId).assertEqual('jsonl_seed')
      expect(ContentRepository.getLocalContentVersion()).assertEqual(BUNDLED_CONTENT_SYNC_MANIFEST.packageVersion)
    })

    it('does not pollute the stored database when staged import validation fails', 0, async () => {
      await ContentDatabaseService.importPackageAndUseDatabase(
        getTestContext(),
        BUNDLED_CONTENT_SYNC_MANIFEST,
        BUNDLED_CONTENT_SYNC_MUSCLES,
        BUNDLED_CONTENT_SYNC_EQUIPMENT,
        BUNDLED_CONTENT_SYNC_EXERCISES
      )

      const versionedExercises: ExerciseContent[] = createVersionedExercises(2)
      const mismatchedVersionManifest: ContentSyncManifest = createManifest(3, versionedExercises.length)
      const imported: boolean = await ContentDatabaseService.importPackageAndUseDatabase(
        getTestContext(),
        mismatchedVersionManifest,
        BUNDLED_CONTENT_SYNC_MUSCLES,
        BUNDLED_CONTENT_SYNC_EQUIPMENT,
        versionedExercises
      )

      expect(imported).assertFalse()
      expect(ContentDatabaseService.getLastImportFailureReason()).assertEqual('content_version_mismatch')
      expect(ContentRepository.getContentSourceInfo().sourceId).assertEqual('local_database')

      ContentRepository.useJsonlSeedSource()
      const loaded: boolean = await ContentDatabaseService.loadDatabaseAndUse(getTestContext())

      expect(loaded).assertTrue()
      expect(ContentRepository.getContentSourceInfo().sourceId).assertEqual('local_database')
      expect(ContentRepository.getLocalContentVersion()).assertEqual(BUNDLED_CONTENT_SYNC_MANIFEST.packageVersion)
      expect(ContentRepository.getExercises().length).assertEqual(BUNDLED_CONTENT_SYNC_MANIFEST.exerciseCount)
    })
  })
}
