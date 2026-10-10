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
  "sha256:2c4de5884a57bbb220534707eac3432759e384ad5eb1b2f9dfa267a01dd75d68",
  45366,
  1780704000000,
  50,
  "bundled",
  "有恒运动 bundled content package"
)

export const BUNDLED_CONTENT_SYNC_MUSCLES: MuscleGroup[] = LOCAL_MUSCLES
export const BUNDLED_CONTENT_SYNC_EQUIPMENT: EquipmentItem[] = LOCAL_EQUIPMENT
export const BUNDLED_CONTENT_SYNC_EXERCISES: ExerciseContent[] = LOCAL_EXERCISES
