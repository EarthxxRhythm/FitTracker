/**
 * ContentDatabaseService -- initializes and imports local exercise content database.
 *
 * Phase 4: bundled content sync package can be imported into the local RDB store.
 */
import { Context } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import {
  ContentSyncManifest,
  EquipmentItem,
  ExerciseContent,
  MuscleGroup,
  createEquipmentItem,
  createExerciseContent,
  createMuscleGroup
} from '../models/TrainingModels'
import {
  BUNDLED_CONTENT_SYNC_EQUIPMENT,
  BUNDLED_CONTENT_SYNC_EXERCISES,
  BUNDLED_CONTENT_SYNC_MANIFEST,
  BUNDLED_CONTENT_SYNC_MUSCLES
} from '../../generated/LocalContentSyncPackage'
import ContentRepository from './ContentRepository'
import { DatabaseContentDataSource } from './DatabaseContentDataSource'

const DEFAULT_DB_NAME: string = 'fittracker_content.db'

interface SeedPackageData {
  manifest: ContentSyncManifest
  muscles: MuscleGroup[]
  equipment: EquipmentItem[]
  exercises: ExerciseContent[]
}

class ContentDatabaseServiceImpl {
  private testDbName: string = ''
  private lastImportFailureReason: string = ''
  private testSeedPackage: SeedPackageData | null = null

  getLastImportFailureReason(): string {
    return this.lastImportFailureReason
  }

  setDatabaseNameForTesting(name: string): void {
    this.testDbName = name
  }

  setSeedPackageForTesting(
    manifest: ContentSyncManifest,
    muscles: MuscleGroup[],
    equipment: EquipmentItem[],
    exercises: ExerciseContent[]
  ): void {
    this.testSeedPackage = {
      manifest: manifest,
      muscles: muscles,
      equipment: equipment,
      exercises: exercises
    }
  }

  clearSeedPackageForTesting(): void {
    this.testSeedPackage = null
  }

  async clearDatabaseForTesting(context: Context): Promise<void> {
    const store: relationalStore.RdbStore = await this.openStore(context)
    await this.createTables(store)
    await this.clearTables(store)
  }

  async importSeedAndUseDatabase(context: Context): Promise<boolean> {
    const seedPackage: SeedPackageData = this.getSeedPackage()
    return this.importPackageAndUseDatabase(
      context,
      seedPackage.manifest,
      seedPackage.muscles,
      seedPackage.equipment,
      seedPackage.exercises
    )
  }

  async importPackageAndUseDatabase(
    context: Context,
    manifest: ContentSyncManifest,
    muscles: MuscleGroup[],
    equipment: EquipmentItem[],
    exercises: ExerciseContent[]
  ): Promise<boolean> {
    const keepCurrentSource: boolean = ContentRepository.getContentSourceInfo().databaseBacked
    this.lastImportFailureReason = ''

    try {
      this.validateExerciseCollection(exercises, manifest)
      const store: relationalStore.RdbStore = await this.openStore(context)
      await this.createTables(store)
      store.beginTransaction()
      try {
        await this.clearTables(store)
        await this.insertMuscles(store, muscles)
        await this.insertEquipment(store, equipment)
        await this.insertExercises(store, exercises)
        const dataSource: DatabaseContentDataSource = await this.loadDatabaseDataSource(store)
        this.validateImportedPackage(dataSource, manifest)
        store.commit()
        ContentRepository.useContentDataSource(dataSource)
        this.lastImportFailureReason = ''
        return true
      } catch (error) {
        this.rollbackQuietly(store)
      }
    } catch (error) {
    }

    if (this.lastImportFailureReason.length === 0) {
      this.lastImportFailureReason = 'import_failed'
    }
    if (!keepCurrentSource) {
      ContentRepository.useJsonlSeedSource()
    }
    return false
  }

  async loadDatabaseAndUse(context: Context): Promise<boolean> {
    this.lastImportFailureReason = ''
    try {
      const store: relationalStore.RdbStore = await this.openStore(context)
      await this.createTables(store)
      const dataSource: DatabaseContentDataSource = await this.loadDatabaseDataSource(store)
      if (dataSource.getExercises().length === 0) {
        ContentRepository.useJsonlSeedSource()
        return false
      }
      this.validateImportedPackage(dataSource, BUNDLED_CONTENT_SYNC_MANIFEST)
      ContentRepository.useContentDataSource(dataSource)
      this.lastImportFailureReason = ''
      return true
    } catch (error) {
      ContentRepository.useJsonlSeedSource()
      return false
    }
  }

  private rollbackQuietly(store: relationalStore.RdbStore): void {
    try {
      store.rollBack()
    } catch (error) {
    }
  }

  private validateImportedPackage(dataSource: DatabaseContentDataSource, manifest: ContentSyncManifest): void {
    this.validateExerciseCollection(dataSource.getExercises(), manifest)
  }

  private validateExerciseCollection(exercises: ExerciseContent[], manifest: ContentSyncManifest): void {
    if (exercises.length !== manifest.exerciseCount) {
      this.lastImportFailureReason = 'exercise_count_mismatch'
      throw new Error('exercise_count_mismatch')
    }
    if (this.getHighestContentVersion(exercises) !== manifest.packageVersion) {
      this.lastImportFailureReason = 'content_version_mismatch'
      throw new Error('content_version_mismatch')
    }
  }

  private getHighestContentVersion(exercises: ExerciseContent[]): number {
    let version: number = 0
    for (let index = 0; index < exercises.length; index++) {
      if (exercises[index].contentVersion > version) {
        version = exercises[index].contentVersion
      }
    }
    return version
  }

  private async openStore(context: Context): Promise<relationalStore.RdbStore> {
    const config: relationalStore.StoreConfig = {
      name: this.getStoreName(),
      securityLevel: relationalStore.SecurityLevel.S1
    }
    return relationalStore.getRdbStore(context, config)
  }

  private getStoreName(): string {
    if (this.testDbName.length > 0) {
      return this.testDbName
    }
    return DEFAULT_DB_NAME
  }

  private getSeedPackage(): SeedPackageData {
    if (this.testSeedPackage !== null) {
      return this.testSeedPackage
    }
    return {
      manifest: BUNDLED_CONTENT_SYNC_MANIFEST,
      muscles: BUNDLED_CONTENT_SYNC_MUSCLES,
      equipment: BUNDLED_CONTENT_SYNC_EQUIPMENT,
      exercises: BUNDLED_CONTENT_SYNC_EXERCISES
    }
  }

  private async createTables(store: relationalStore.RdbStore): Promise<void> {
    await store.executeSql('CREATE TABLE IF NOT EXISTS muscles (muscle_id TEXT PRIMARY KEY, name_zh TEXT NOT NULL, region TEXT NOT NULL)')
    await store.executeSql('CREATE TABLE IF NOT EXISTS equipment (equipment_id TEXT PRIMARY KEY, name_zh TEXT NOT NULL, category TEXT)')
    await store.executeSql('CREATE TABLE IF NOT EXISTS exercises (exercise_id TEXT PRIMARY KEY, name_zh TEXT NOT NULL, name_en TEXT NOT NULL, aliases_json TEXT NOT NULL, primary_muscle_ids_json TEXT NOT NULL, secondary_muscle_ids_json TEXT NOT NULL, equipment_ids_json TEXT NOT NULL, difficulty TEXT NOT NULL, goal_tags_json TEXT NOT NULL, video_url TEXT NOT NULL, cover_url TEXT NOT NULL, cover_source_label TEXT NOT NULL DEFAULT \'\', video_source_label TEXT NOT NULL DEFAULT \'\', media_license_text TEXT NOT NULL DEFAULT \'\', steps_json TEXT NOT NULL, cues_json TEXT NOT NULL, common_mistakes_json TEXT NOT NULL, safety_notes_json TEXT NOT NULL, alternative_exercise_ids_json TEXT NOT NULL, content_version INTEGER NOT NULL)')
    await this.ensureExerciseColumns(store)
  }

  private async clearTables(store: relationalStore.RdbStore): Promise<void> {
    await store.executeSql('DELETE FROM exercises')
    await store.executeSql('DELETE FROM equipment')
    await store.executeSql('DELETE FROM muscles')
  }

  private async insertMuscles(store: relationalStore.RdbStore, muscles: MuscleGroup[]): Promise<void> {
    for (let index = 0; index < muscles.length; index++) {
      const muscle: MuscleGroup = muscles[index]
      await store.executeSql(
        'INSERT INTO muscles (muscle_id, name_zh, region) VALUES (?, ?, ?)',
        [muscle.muscleId, muscle.nameZh, muscle.region]
      )
    }
  }

  private async insertEquipment(store: relationalStore.RdbStore, equipment: EquipmentItem[]): Promise<void> {
    for (let index = 0; index < equipment.length; index++) {
      const item: EquipmentItem = equipment[index]
      await store.executeSql(
        'INSERT INTO equipment (equipment_id, name_zh, category) VALUES (?, ?, ?)',
        [item.equipmentId, item.nameZh, '']
      )
    }
  }

  private async insertExercises(store: relationalStore.RdbStore, exercises: ExerciseContent[]): Promise<void> {
    for (let index = 0; index < exercises.length; index++) {
      const exercise: ExerciseContent = exercises[index]
      await store.executeSql(
        'INSERT INTO exercises (exercise_id, name_zh, name_en, aliases_json, primary_muscle_ids_json, secondary_muscle_ids_json, equipment_ids_json, difficulty, goal_tags_json, video_url, cover_url, cover_source_label, video_source_label, media_license_text, steps_json, cues_json, common_mistakes_json, safety_notes_json, alternative_exercise_ids_json, content_version) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          exercise.exerciseId,
          exercise.nameZh,
          exercise.nameEn,
          this.encodeStringArray(exercise.aliases),
          this.encodeStringArray(exercise.primaryMuscleIds),
          this.encodeStringArray(exercise.secondaryMuscleIds),
          this.encodeStringArray(exercise.equipmentIds),
          exercise.difficulty,
          this.encodeStringArray(exercise.goalTags),
          exercise.videoUrl,
          exercise.coverUrl,
          exercise.coverSourceLabel,
          exercise.videoSourceLabel,
          exercise.mediaLicenseText,
          this.encodeStringArray(exercise.steps),
          this.encodeStringArray(exercise.cues),
          this.encodeStringArray(exercise.commonMistakes),
          this.encodeStringArray(exercise.safetyNotes),
          this.encodeStringArray(exercise.alternativeExerciseIds),
          exercise.contentVersion
        ]
      )
    }
  }

  private async loadDatabaseDataSource(store: relationalStore.RdbStore): Promise<DatabaseContentDataSource> {
    const muscles: MuscleGroup[] = await this.queryMuscles(store)
    const equipment: EquipmentItem[] = await this.queryEquipment(store)
    const exercises: ExerciseContent[] = await this.queryExercises(store)
    return new DatabaseContentDataSource(muscles, equipment, exercises)
  }

  private async queryMuscles(store: relationalStore.RdbStore): Promise<MuscleGroup[]> {
    const rows: MuscleGroup[] = []
    const resultSet: relationalStore.ResultSet = await store.querySql('SELECT muscle_id, name_zh, region FROM muscles ORDER BY muscle_id')
    while (resultSet.goToNextRow()) {
      rows.push(createMuscleGroup(
        resultSet.getString(resultSet.getColumnIndex('muscle_id')),
        resultSet.getString(resultSet.getColumnIndex('name_zh')),
        resultSet.getString(resultSet.getColumnIndex('region'))
      ))
    }
    resultSet.close()
    return rows
  }

  private async queryEquipment(store: relationalStore.RdbStore): Promise<EquipmentItem[]> {
    const rows: EquipmentItem[] = []
    const resultSet: relationalStore.ResultSet = await store.querySql('SELECT equipment_id, name_zh FROM equipment ORDER BY equipment_id')
    while (resultSet.goToNextRow()) {
      rows.push(createEquipmentItem(
        resultSet.getString(resultSet.getColumnIndex('equipment_id')),
        resultSet.getString(resultSet.getColumnIndex('name_zh'))
      ))
    }
    resultSet.close()
    return rows
  }

  private async queryExercises(store: relationalStore.RdbStore): Promise<ExerciseContent[]> {
    const rows: ExerciseContent[] = []
    const resultSet: relationalStore.ResultSet = await store.querySql('SELECT exercise_id, name_zh, name_en, aliases_json, primary_muscle_ids_json, secondary_muscle_ids_json, equipment_ids_json, difficulty, goal_tags_json, video_url, cover_url, cover_source_label, video_source_label, media_license_text, steps_json, cues_json, common_mistakes_json, safety_notes_json, alternative_exercise_ids_json, content_version FROM exercises ORDER BY exercise_id')
    while (resultSet.goToNextRow()) {
      rows.push(createExerciseContent(
        resultSet.getString(resultSet.getColumnIndex('exercise_id')),
        resultSet.getString(resultSet.getColumnIndex('name_zh')),
        resultSet.getString(resultSet.getColumnIndex('name_en')),
        this.decodeStringArray(resultSet.getString(resultSet.getColumnIndex('aliases_json'))),
        this.decodeStringArray(resultSet.getString(resultSet.getColumnIndex('primary_muscle_ids_json'))),
        this.decodeStringArray(resultSet.getString(resultSet.getColumnIndex('secondary_muscle_ids_json'))),
        this.decodeStringArray(resultSet.getString(resultSet.getColumnIndex('equipment_ids_json'))),
        resultSet.getString(resultSet.getColumnIndex('difficulty')),
        this.decodeStringArray(resultSet.getString(resultSet.getColumnIndex('goal_tags_json'))),
        resultSet.getString(resultSet.getColumnIndex('video_url')),
        resultSet.getString(resultSet.getColumnIndex('cover_url')),
        resultSet.getString(resultSet.getColumnIndex('cover_source_label')),
        resultSet.getString(resultSet.getColumnIndex('video_source_label')),
        resultSet.getString(resultSet.getColumnIndex('media_license_text')),
        this.decodeStringArray(resultSet.getString(resultSet.getColumnIndex('steps_json'))),
        this.decodeStringArray(resultSet.getString(resultSet.getColumnIndex('cues_json'))),
        this.decodeStringArray(resultSet.getString(resultSet.getColumnIndex('common_mistakes_json'))),
        this.decodeStringArray(resultSet.getString(resultSet.getColumnIndex('safety_notes_json'))),
        this.decodeStringArray(resultSet.getString(resultSet.getColumnIndex('alternative_exercise_ids_json'))),
        Number(resultSet.getLong(resultSet.getColumnIndex('content_version')))
      ))
    }
    resultSet.close()
    return rows
  }

  private async ensureExerciseColumns(store: relationalStore.RdbStore): Promise<void> {
    await this.tryAddExerciseColumn(store, 'cover_source_label', 'TEXT NOT NULL DEFAULT \'\'')
    await this.tryAddExerciseColumn(store, 'video_source_label', 'TEXT NOT NULL DEFAULT \'\'')
    await this.tryAddExerciseColumn(store, 'media_license_text', 'TEXT NOT NULL DEFAULT \'\'')
  }

  private async tryAddExerciseColumn(
    store: relationalStore.RdbStore,
    columnName: string,
    columnDefinition: string
  ): Promise<void> {
    try {
      await store.executeSql('ALTER TABLE exercises ADD COLUMN ' + columnName + ' ' + columnDefinition)
    } catch (error) {
    }
  }

  private encodeStringArray(values: string[]): string {
    let text: string = '['
    for (let index = 0; index < values.length; index++) {
      if (index > 0) {
        text += ','
      }
      text += '"' + this.escapeJsonString(values[index]) + '"'
    }
    text += ']'
    return text
  }

  private decodeStringArray(text: string): string[] {
    const values: string[] = []
    let current: string = ''
    let inString: boolean = false
    let escaped: boolean = false
    for (let index = 0; index < text.length; index++) {
      const char: string = text.charAt(index)
      if (!inString) {
        if (char === '"') {
          inString = true
          current = ''
        }
      } else if (escaped) {
        current += char
        escaped = false
      } else if (char === '\\') {
        escaped = true
      } else if (char === '"') {
        values.push(current)
        inString = false
      } else {
        current += char
      }
    }
    return values
  }

  private escapeJsonString(value: string): string {
    let text: string = ''
    for (let index = 0; index < value.length; index++) {
      const char: string = value.charAt(index)
      if (char === '"' || char === '\\') {
        text += '\\'
      }
      text += char
    }
    return text
  }
}

export default new ContentDatabaseServiceImpl()
