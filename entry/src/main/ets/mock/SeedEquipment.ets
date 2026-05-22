/**
 * SeedEquipment -- local equipment seed content for target-loop planning.
 *
 * Feature #2: seed content and content repository.
 */
import { EquipmentItem, createEquipmentItem } from '../shared/models/TrainingModels'

export const SEED_EQUIPMENT: EquipmentItem[] = [
  createEquipmentItem('eq_barbell', 'Barbell'),
  createEquipmentItem('eq_dumbbell', 'Dumbbell'),
  createEquipmentItem('eq_cable', 'Cable'),
  createEquipmentItem('eq_machine', 'Machine'),
  createEquipmentItem('eq_bodyweight', 'Bodyweight'),
  createEquipmentItem('eq_band', 'Band')
]
