import { describe, it, expect } from '@ohos/hypium'
import { ExerciseContent } from '../../../main/ets/shared/models/TrainingModels'
import ContentRepository from '../../../main/ets/shared/services/ContentRepository'

export default function contentRepositoryTest(): void {
  describe('ContentRepository', () => {
    it('returns Chinese labels for local exercise metadata', 0, () => {
      expect(ContentRepository.getMuscleName('muscle_chest')).assertEqual('胸部')
      expect(ContentRepository.getEquipmentName('eq_bodyweight')).assertEqual('徒手')
    })

    it('keeps local action library seeded with Chinese exercise detail', 0, () => {
      const exercise: ExerciseContent | undefined = ContentRepository.getExerciseById('ex_push_up')
      expect(exercise !== undefined).assertTrue()
      if (exercise !== undefined) {
        expect(exercise.nameZh).assertEqual('俯卧撑')
        expect(exercise.steps.length > 0).assertTrue()
        expect(ContentRepository.hasVideoAsset(exercise)).assertFalse()
      }
    })
  })
}
