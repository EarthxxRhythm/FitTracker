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
  "sha256:f71088d2cb5dfdb32d3ab8baae25cc4243641154a7f814bc563196995fff2b35",
  45226,
  1780704000000,
  50,
  "bundled",
  "FitTracker bundled content package"
)

export const BUNDLED_CONTENT_SYNC_MUSCLES: MuscleGroup[] = LOCAL_MUSCLES
export const BUNDLED_CONTENT_SYNC_EQUIPMENT: EquipmentItem[] = LOCAL_EQUIPMENT
export const BUNDLED_CONTENT_SYNC_EXERCISES: ExerciseContent[] = LOCAL_EXERCISES
