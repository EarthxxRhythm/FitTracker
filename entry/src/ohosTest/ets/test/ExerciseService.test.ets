import { describe, it, expect } from '@ohos/hypium'
import exerciseService from '../../../main/ets/common/services/ExerciseService'

export default function exerciseServiceTest(): void {
  describe('ExerciseService', () => {
    describe('getAll', () => {
      it('returns all exercises with stable seed size', 0, () => {
        const exercises = exerciseService.getAll()
        expect(exercises.length).assertEqual(45)
        expect(exercises[0].id).assertEqual('e1')
      })
    })

    describe('getTotalCount', () => {
      it('matches the exercise seed size', 0, () => {
        expect(exerciseService.getTotalCount()).assertEqual(45)
      })
    })

    describe('search', () => {
      it('finds one exact exercise by name', 0, () => {
        const targetName: string = exerciseService.getAll()[0].name
        const results = exerciseService.search(targetName)
        expect(results.length).assertEqual(1)
        expect(results[0].id).assertEqual('e1')
      })

      it('finds exercises by a partial-name query derived from existing data', 0, () => {
        const source = exerciseService.getById('e15')
        expect(source !== undefined).assertTrue()
        if (source !== undefined) {
          const partialQuery: string = source.name.substring(0, 2)
          const results = exerciseService.search(partialQuery)
          expect(results.length).assertLarger(0)
          expect(results.some((item) => item.id === 'e15')).assertTrue()
        }
      })

      it('finds three exercises by alias query', 0, () => {
        const results = exerciseService.search('squat')
        expect(results.length).assertEqual(3)
      })

      it('returns all for empty or whitespace query', 0, () => {
        expect(exerciseService.search('').length).assertEqual(45)
        expect(exerciseService.search('   ').length).assertEqual(45)
      })

      it('keeps alias search case-insensitive', 0, () => {
        const results = exerciseService.search('PULL UP')
        expect(results.length).assertEqual(1)
        expect(results[0].id).assertEqual('e8')
      })
    })

    describe('filtering', () => {
      it('filters chest, back, and leg groups with current counts', 0, () => {
        const groups = exerciseService.getMuscleGroups()
        expect(exerciseService.filterByMuscle(groups[1]).length).assertEqual(8)
        expect(exerciseService.filterByMuscle(groups[2]).length).assertEqual(10)
        expect(exerciseService.filterByMuscle(groups[3]).length).assertEqual(9)
      })

      it('filters by equipment with current counts', 0, () => {
        const types = exerciseService.getEquipmentTypes()
        expect(exerciseService.filterByEquipment(types[0]).length).assertEqual(13)
        expect(exerciseService.filterByEquipment(types[1]).length).assertEqual(12)
        expect(exerciseService.filterByEquipment(types[4]).length).assertEqual(7)
      })

      it('returns all for empty or all filters', 0, () => {
        const groups = exerciseService.getMuscleGroups()
        const types = exerciseService.getEquipmentTypes()
        expect(exerciseService.filterByMuscle(groups[0]).length).assertEqual(45)
        expect(exerciseService.filterByMuscle('').length).assertEqual(45)
        expect(exerciseService.filterByEquipment('').length).assertEqual(45)
        expect(exerciseService.filterByEquipment(types[0]).length > 0).assertTrue()
      })
    })

    describe('pagination', () => {
      it('returns stable page slices', 0, () => {
        const all = exerciseService.getAll()
        expect(exerciseService.getPage(all, 1).length).assertEqual(20)
        expect(exerciseService.getPage(all, 2).length).assertEqual(20)
        expect(exerciseService.getPage(all, 3).length).assertEqual(5)
        expect(exerciseService.getPage(all, 10).length).assertEqual(0)
      })

      it('reports whether more pages remain', 0, () => {
        const all = exerciseService.getAll()
        expect(exerciseService.hasMore(all, 1)).assertTrue()
        expect(exerciseService.hasMore(all, 2)).assertTrue()
        expect(exerciseService.hasMore(all, 3)).assertFalse()
      })
    })

    describe('lookup metadata', () => {
      it('finds existing exercises by id', 0, () => {
        const first = exerciseService.getById('e1')
        const mid = exerciseService.getById('e23')
        expect(first !== undefined).assertTrue()
        expect(mid !== undefined).assertTrue()
      })

      it('returns undefined for missing ids', 0, () => {
        expect(exerciseService.getById('e999') === undefined).assertTrue()
      })

      it('exposes stable group and equipment option counts', 0, () => {
        expect(exerciseService.getMuscleGroups().length).assertEqual(7)
        expect(exerciseService.getEquipmentTypes().length).assertEqual(5)
      })
    })
  })
}
