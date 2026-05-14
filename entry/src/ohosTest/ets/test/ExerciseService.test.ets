/**
 * ExerciseService 单元测试
 * 覆盖动作库数据：getAll、search、filterByMuscle、filterByEquipment、getPage、hasMore、getById
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import exerciseService from '../../../main/ets/common/services/ExerciseService'

export default function exerciseServiceTest(): void {
  describe('ExerciseService', () => {
    beforeAll(() => {
    })

    afterAll(() => {
    })

    // ============================================================
    // getAll / getTotalCount
    // ============================================================
    describe('getAll', () => {
      it('should return all exercises', 0, () => {
        const exercises = exerciseService.getAll()
        expect(exercises.length).assertEqual(45)
      })

      it('should return exercises with valid structure', 0, () => {
        const exercises = exerciseService.getAll()
        const first = exercises[0]
        expect(first.id).assertEqual('e1')
        expect(first.name).assertEqual('杠铃平板卧推')
        expect(first.primaryMuscle).assertEqual('胸')
        expect(first.equipment).assertEqual('杠铃')
      })
    })

    describe('getTotalCount', () => {
      it('should return 45', 0, () => {
        expect(exerciseService.getTotalCount()).assertEqual(45)
      })
    })

    // ============================================================
    // search
    // ============================================================
    describe('search', () => {
      it('should find by exact name', 0, () => {
        const results = exerciseService.search('杠铃平板卧推')
        expect(results.length).assertEqual(1)
        expect(results[0].name).assertEqual('杠铃平板卧推')
      })

      it('should find by partial name', 0, () => {
        const results = exerciseService.search('深蹲')
        expect(results.length).assertEqual(3) // 杠铃深蹲, 史密斯机深蹲, 保加利亚分腿蹲
      })

      it('should find by alias', 0, () => {
        const results = exerciseService.search('squat')
        expect(results.length).assertEqual(2) // 杠铃深蹲, 史密斯机深蹲
      })

      it('should return all when query is empty', 0, () => {
        const results = exerciseService.search('')
        expect(results.length).assertEqual(45)
      })

      it('should return all when query is whitespace-only', 0, () => {
        const results = exerciseService.search('   ')
        expect(results.length).assertEqual(45)
      })

      it('should return empty for non-matching query', 0, () => {
        const results = exerciseService.search('量子健身')
        expect(results.length).assertEqual(0)
      })

      it('should be case-insensitive for aliases', 0, () => {
        const results = exerciseService.search('PULL UP')
        expect(results.length).assertEqual(1)
        expect(results[0].name).assertEqual('引体向上')
      })
    })

    // ============================================================
    // filterByMuscle
    // ============================================================
    describe('filterByMuscle', () => {
      it('should filter by "胸"', 0, () => {
        const results = exerciseService.filterByMuscle('胸')
        expect(results.length).assertEqual(7) // e1-e7
      })

      it('should filter by "背"', 0, () => {
        const results = exerciseService.filterByMuscle('背')
        expect(results.length).assertEqual(8) // e8-e14 + e40
      })

      it('should filter by "腿"', 0, () => {
        const results = exerciseService.filterByMuscle('腿')
        expect(results.length).assertEqual(9) // e15-e21 + e41-e42
      })

      it('should return all for "全部"', 0, () => {
        const results = exerciseService.filterByMuscle('全部')
        expect(results.length).assertEqual(45)
      })

      it('should return all for empty string', 0, () => {
        const results = exerciseService.filterByMuscle('')
        expect(results.length).assertEqual(45)
      })

      it('should return empty for unknown muscle', 0, () => {
        const results = exerciseService.filterByMuscle('眼球')
        expect(results.length).assertEqual(0)
      })
    })

    // ============================================================
    // filterByEquipment
    // ============================================================
    describe('filterByEquipment', () => {
      it('should filter by "杠铃"', 0, () => {
        const results = exerciseService.filterByEquipment('杠铃')
        expect(results.length).assertEqual(13)
      })

      it('should filter by "哑铃"', 0, () => {
        const results = exerciseService.filterByEquipment('哑铃')
        expect(results.length).assertEqual(11)
      })

      it('should filter by "自重"', 0, () => {
        const results = exerciseService.filterByEquipment('自重')
        expect(results.length).assertEqual(7)
      })

      it('should return all for "全部"', 0, () => {
        const results = exerciseService.filterByEquipment('全部')
        expect(results.length).assertEqual(45)
      })

      it('should return all for empty string', 0, () => {
        const results = exerciseService.filterByEquipment('')
        expect(results.length).assertEqual(45)
      })
    })

    // ============================================================
    // getPage / hasMore
    // ============================================================
    describe('getPage', () => {
      it('should return first 20 items for page 1', 0, () => {
        const all = exerciseService.getAll()
        const page = exerciseService.getPage(all, 1)
        expect(page.length).assertEqual(20)
        expect(page[0].id).assertEqual('e1')
      })

      it('should return next 20 items for page 2', 0, () => {
        const all = exerciseService.getAll()
        const page = exerciseService.getPage(all, 2)
        expect(page.length).assertEqual(20)
        expect(page[0].id).assertEqual('e21')
      })

      it('should return 5 items for page 3 (last page)', 0, () => {
        const all = exerciseService.getAll()
        const page = exerciseService.getPage(all, 3)
        expect(page.length).assertEqual(5)
        expect(page[0].id).assertEqual('e41')
      })

      it('should return empty for page beyond total', 0, () => {
        const all = exerciseService.getAll()
        const page = exerciseService.getPage(all, 10)
        expect(page.length).assertEqual(0)
      })
    })

    describe('hasMore', () => {
      it('should return true when more pages exist', 0, () => {
        const all = exerciseService.getAll()
        expect(exerciseService.hasMore(all, 1)).assertTrue()
      })

      it('should return true for last complete page', 0, () => {
        const all = exerciseService.getAll()
        expect(exerciseService.hasMore(all, 2)).assertTrue()
      })

      it('should return false when no more pages', 0, () => {
        const all = exerciseService.getAll()
        expect(exerciseService.hasMore(all, 3)).assertFalse()
      })

      it('should return false beyond last page', 0, () => {
        const all = exerciseService.getAll()
        expect(exerciseService.hasMore(all, 5)).assertFalse()
      })
    })

    // ============================================================
    // getById
    // ============================================================
    describe('getById', () => {
      it('should find by existing id', 0, () => {
        const ex = exerciseService.getById('e1')
        expect(ex).assertNotNull()
        if (ex) {
          expect(ex.name).assertEqual('杠铃平板卧推')
        }
      })

      it('should find mid-range id', 0, () => {
        const ex = exerciseService.getById('e23')
        if (ex) {
          expect(ex.name).assertEqual('哑铃侧平举')
          expect(ex.primaryMuscle).assertEqual('肩')
        }
      })

      it('should return undefined for non-existing id', 0, () => {
        const ex = exerciseService.getById('e999')
        expect(ex === undefined).assertTrue()
      })
    })

    // ============================================================
    // getMuscleGroups / getEquipmentTypes
    // ============================================================
    describe('getMuscleGroups', () => {
      it('should return 6 muscle groups plus "全部"', 0, () => {
        const groups = exerciseService.getMuscleGroups()
        expect(groups.length).assertEqual(7)
        expect(groups[0]).assertEqual('全部')
      })
    })

    describe('getEquipmentTypes', () => {
      it('should return 5 equipment types', 0, () => {
        const types = exerciseService.getEquipmentTypes()
        expect(types.length).assertEqual(5)
        expect(types[0]).assertEqual('杠铃')
      })
    })
  })
}
