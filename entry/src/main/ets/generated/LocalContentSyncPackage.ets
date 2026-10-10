/**
 * LocalContentSyncPackage -- generated bundled content sync package.
 * Run: node tools/content/build-content.mjs
 */
import { EquipmentItem, ExerciseContent, MuscleGroup, ContentSyncManifest, createContentSyncManifest } from '../shared/models/TrainingModels'
import { LOCAL_EQUIPMENT, LOCAL_EXERCISES, LOCAL_MUSCLES } from './LocalExerciseContent'

export const BUNDLED_CONTENT_SYNC_MANIFEST: ContentSyncManifest = createContentSyncManifest(
  1,
  "full",
  2,
  "local://content-package",
  "sha256:0703ac1cf656180c596d0b7bde4cae5d5034015cd99d603c811f8bd19d076447",
  44946,
  1780704000000,
  50,
  "bundled",
  "菲特 bundled content package"
)

export const BUNDLED_CONTENT_SYNC_MUSCLES: MuscleGroup[] = LOCAL_MUSCLES
export const BUNDLED_CONTENT_SYNC_EQUIPMENT: EquipmentItem[] = LOCAL_EQUIPMENT
export const BUNDLED_CONTENT_SYNC_EXERCISES: ExerciseContent[] = LOCAL_EXERCISES
