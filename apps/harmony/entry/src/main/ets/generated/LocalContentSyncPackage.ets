/**
 * LocalContentSyncPackage -- generated bundled content sync package.
 * Run: node tools/content/build-content.mjs
 */
import { EquipmentItem, ExerciseContent, MuscleGroup, ContentSyncManifest, createContentSyncManifest } from '../shared/models/TrainingModels'
import { LOCAL_EQUIPMENT, LOCAL_EXERCISES, LOCAL_MUSCLES } from './LocalExerciseContent'

export const BUNDLED_CONTENT_SYNC_MANIFEST: ContentSyncManifest = createContentSyncManifest(
  1,
  "full",
  3,
  "local://content-package",
  "sha256:bc752f6d5318677fc73e8da0598578251ffeb262649bc514d964877d805667f1",
  100461,
  1780704000000,
  102,
  "bundled",
  "菲特 bundled content package"
)

export const BUNDLED_CONTENT_SYNC_MUSCLES: MuscleGroup[] = LOCAL_MUSCLES
export const BUNDLED_CONTENT_SYNC_EQUIPMENT: EquipmentItem[] = LOCAL_EQUIPMENT
export const BUNDLED_CONTENT_SYNC_EXERCISES: ExerciseContent[] = LOCAL_EXERCISES
