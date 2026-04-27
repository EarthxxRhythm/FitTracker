/**
 * ExerciseService 单元测试
 *
 * 测试动作库服务：
 *   - 动作总数（45个）
 *   - 搜索功能（名称/别名）
 *   - 肌群筛选
 *   - 器械筛选
 *   - 分页加载
 *   - 肌群/器械列表
 */
import { describe, it, expect } from '@ohos/hypium'
import ExerciseService from '../main/ets/common/services/ExerciseService'

export default function exerciseServiceTest() {
  describe('ExerciseService — data integrity', () => {

    it('should have 45 exercises total', 0, () => {
      expect(ExerciseService.getTotalCount()).assertEqual(45)
    })

    it('should return all exercises from getAll', 0, () => {
      expect(ExerciseService.getAll().length).assertEqual(45)
    })

    it('should return all 7 muscle groups', 0, () => {
      const groups = ExerciseService.getMuscleGroups()
      expect(groups.length).assertEqual(7)
      expect(groups[0]).assertEqual('全部')
    })

    it('should return 5 equipment types', 0, () => {
      const types = ExerciseService.getEquipmentTypes()
      expect(types.length).assertEqual(5)
    })
  })

  describe('ExerciseService — search by name', () => {

    it('should find exercises by Chinese name', 0, () => {
      const results = ExerciseService.search('卧推')
      expect(results.length).assertLarger(0)
      expect(results.some(e => e.name.includes('卧推'))).assertTrue()
    })

    it('should find exercises by English alias', 0, () => {
      const results = ExerciseService.search('squat')
      expect(results.length).assertLarger(0)
      expect(results.some(e => e.name.includes('深蹲'))).assertTrue()
    })

    it('should return all for empty search', 0, () => {
      expect(ExerciseService.search('').length).assertEqual(45)
    })
  })

  describe('ExerciseService — muscle filter', () => {

    it('should filter by chest exercises', 0, () => {
      const results = ExerciseService.filterByMuscle('胸')
      expect(results.length).assertLarger(0)
      for (let e of results) {
        expect(e.primaryMuscle).assertEqual('胸')
      }
    })

    it('should filter by back exercises', 0, () => {
      const results = ExerciseService.filterByMuscle('背')
      for (let e of results) {
        expect(e.primaryMuscle).assertEqual('背')
      }
    })

    it('should return all for "全部" filter', 0, () => {
      expect(ExerciseService.filterByMuscle('全部').length).assertEqual(45)
    })
  })

  describe('ExerciseService — equipment filter', () => {

    it('should filter by barbell exercises', 0, () => {
      const results = ExerciseService.filterByEquipment('杠铃')
      expect(results.length).assertLarger(0)
      for (let e of results) {
        expect(e.equipment).assertEqual('杠铃')
      }
    })

    it('should filter by bodyweight exercises', 0, () => {
      const results = ExerciseService.filterByEquipment('自重')
      for (let e of results) {
        expect(e.equipment).assertEqual('自重')
      }
    })
  })

  describe('ExerciseService — pagination', () => {

    it('should return 20 items on first page', 0, () => {
      const page = ExerciseService.getPage(ExerciseService.getAll(), 1)
      expect(page.length).assertEqual(20)
    })

    it('should return 20 items on second page', 0, () => {
      const page = ExerciseService.getPage(ExerciseService.getAll(), 2)
      expect(page.length).assertEqual(20)
    })

    it('should return 5 items on third page (last page)', 0, () => {
      const page = ExerciseService.getPage(ExerciseService.getAll(), 3)
      expect(page.length).assertEqual(5)
    })

    it('should report hasMore correctly', 0, () => {
      expect(ExerciseService.hasMore(ExerciseService.getAll(), 1)).assertTrue()
      expect(ExerciseService.hasMore(ExerciseService.getAll(), 2)).assertTrue()
      expect(ExerciseService.hasMore(ExerciseService.getAll(), 3)).assertFalse()
    })
  })

  describe('ExerciseService — get by ID', () => {

    it('should find exercise by ID', 0, () => {
      const exercise = ExerciseService.getById('e1')
      expect(exercise !== undefined).assertTrue()
      expect(exercise!.name).assertContain('卧推')
    })

    it('should return undefined for unknown ID', 0, () => {
      expect(ExerciseService.getById('nonexistent') === undefined).assertTrue()
    })
  })
}
