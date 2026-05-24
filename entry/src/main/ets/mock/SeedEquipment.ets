/**
 * SeedEquipment -- local equipment seed content for target-loop planning.
 *
 * Feature #2: seed content and content repository.
 */
import { EquipmentItem, createEquipmentItem } from '../shared/models/TrainingModels'

export const SEED_EQUIPMENT: EquipmentItem[] = [
  createEquipmentItem('eq_barbell', '杠铃'),
  createEquipmentItem('eq_dumbbell', '哑铃'),
  createEquipmentItem('eq_cable', '绳索'),
  createEquipmentItem('eq_machine', '固定器械'),
  createEquipmentItem('eq_bodyweight', '徒手'),
  createEquipmentItem('eq_band', '弹力带')
]
