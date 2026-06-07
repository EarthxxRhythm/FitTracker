/**
 * LocalContentSyncPackage -- generated bundled content sync package.
 * Run: node tools/content/build-content.mjs
 */
import { EquipmentItem, ExerciseContent, MuscleGroup, ContentSyncManifest, createContentSyncManifest } from '../shared/models/TrainingModels'
import { LOCAL_EQUIPMENT, LOCAL_EXERCISES, LOCAL_MUSCLES } from './LocalExerciseContent'

export const BUNDLED_CONTENT_SYNC_MANIFEST: ContentSyncManifest = createContentSyncManifest(
  1,
  "full",
  1,
  "local://content-package",
  "sha256:3a7c6b64429b8014bb2af1e0b1a573fec438b90c83c67ac19295f42ef97d58eb",
  41079,
  1780704000000,
  50,
  "bundled",
  "FitTracker bundled content package"
)

export const BUNDLED_CONTENT_SYNC_MUSCLES: MuscleGroup[] = LOCAL_MUSCLES
export const BUNDLED_CONTENT_SYNC_EQUIPMENT: EquipmentItem[] = LOCAL_EQUIPMENT
export const BUNDLED_CONTENT_SYNC_EXERCISES: ExerciseContent[] = LOCAL_EXERCISES
