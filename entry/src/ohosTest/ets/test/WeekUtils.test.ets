/**
 * WeekUtils unit test
 * 覆盖 resolveWeekStart 在周一/周日两种模式下的全天枚举与跨周边界。
 * 基准：2024-05-12 为周日，2024-05-13 为周一（与 StatsDashboardService.test 的周区间断言一致）。
 */
import { describe, it, expect } from '@ohos/hypium'
import { resolveWeekStart } from '../../../main/ets/common/utils/WeekUtils'

export default function weekUtilsTest(): void {
  describe('WeekUtils', () => {
    it('resolves monday-based week start for every weekday', 0, () => {
      // 2024-05-13（周一）～ 2024-05-19（周日）应全部归入 05-13 这一周
      for (let day = 13; day <= 19; day++) {
        const start: Date = resolveWeekStart(new Date(2024, 4, day, 12, 0, 0), 'monday')
        expect(start.getFullYear()).assertEqual(2024)
        expect(start.getMonth()).assertEqual(4)
        expect(start.getDate()).assertEqual(13)
      }
    })

    it('resolves sunday-based week start for every weekday', 0, () => {
      // 2024-05-12（周日）～ 2024-05-18（周六）应全部归入 05-12 这一周
      for (let day = 12; day <= 18; day++) {
        const start: Date = resolveWeekStart(new Date(2024, 4, day, 12, 0, 0), 'sunday')
        expect(start.getFullYear()).assertEqual(2024)
        expect(start.getMonth()).assertEqual(4)
        expect(start.getDate()).assertEqual(12)
      }
    })

    it('handles cross-week boundaries for both modes', 0, () => {
      // 周日 05-12：周一模式归入上一周（05-06），周日模式归入当天
      const sunday: Date = new Date(2024, 4, 12, 8, 0, 0)
      const sundayForMonday: Date = resolveWeekStart(sunday, 'monday')
      const sundayForSunday: Date = resolveWeekStart(sunday, 'sunday')
      expect(sundayForMonday.getDate()).assertEqual(6)
      expect(sundayForMonday.getMonth()).assertEqual(4)
      expect(sundayForSunday.getDate()).assertEqual(12)

      // 周日 05-19：周一模式归入 05-13 一周，周日模式归入当天
      const nextSunday: Date = new Date(2024, 4, 19, 8, 0, 0)
      const nextSundayForMonday: Date = resolveWeekStart(nextSunday, 'monday')
      const nextSundayForSunday: Date = resolveWeekStart(nextSunday, 'sunday')
      expect(nextSundayForMonday.getDate()).assertEqual(13)
      expect(nextSundayForSunday.getDate()).assertEqual(19)
    })
  })
}
