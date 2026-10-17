/**
 * StreakUtils —— 训练连续记录与本周打卡派生（纯函数）的契约测试。
 *
 * 覆盖 059b845 引入的共享实现：连续天数回溯口径（今天/昨天起算、断档归零）、
 * 本周打卡标记（周一首与周日首两种口径，长度恒 7）、日期键格式化。
 */
import { describe, it, expect } from '@ohos/hypium'
import {
  padTwoDigits,
  formatDateKey,
  computeStreakCount,
  computeWeekActiveFlags,
  computeWeekActiveFlagsFrom
} from '../../../main/ets/common/utils/StreakUtils'

export default function streakUtilsTest(): void {
  describe('StreakUtils', () => {
    it('pad_two_digits_pads_single_digit_only', 0, () => {
      expect(padTwoDigits(3)).assertEqual('03')
      expect(padTwoDigits(12)).assertEqual('12')
    })

    it('format_date_key_is_yyyy_mm_dd', 0, () => {
      const date: Date = new Date(2026, 9, 5)
      expect(formatDateKey(date)).assertEqual('2026-10-05')
    })

    it('streak_count_empty_is_zero', 0, () => {
      expect(computeStreakCount([])).assertEqual(0)
    })

    it('streak_count_consecutive_ending_today', 0, () => {
      const today: Date = new Date()
      const yesterday: Date = new Date(today.getFullYear(), today.getMonth(), today.getDate() - 1)
      expect(
        computeStreakCount([formatDateKey(today), formatDateKey(yesterday)])
      ).assertEqual(2)
    })

    it('streak_count_starts_from_yesterday_when_today_untrained', 0, () => {
      const today: Date = new Date()
      const yesterday: Date = new Date(today.getFullYear(), today.getMonth(), today.getDate() - 1)
      const dayBefore: Date = new Date(today.getFullYear(), today.getMonth(), today.getDate() - 2)
      expect(
        computeStreakCount([formatDateKey(yesterday), formatDateKey(dayBefore)])
      ).assertEqual(2)
    })

    it('streak_count_breaks_on_gap', 0, () => {
      const today: Date = new Date()
      const dayBefore: Date = new Date(today.getFullYear(), today.getMonth(), today.getDate() - 2)
      expect(
        computeStreakCount([formatDateKey(today), formatDateKey(dayBefore)])
      ).assertEqual(1)
    })

    it('week_flags_length_is_seven_and_marks_today', 0, () => {
      const flags: boolean[] = computeWeekActiveFlags([formatDateKey(new Date())])
      expect(flags.length).assertEqual(7)
      let activeCount: number = 0
      flags.forEach((flag: boolean) => {
        if (flag) {
          activeCount++
        }
      })
      expect(activeCount).assertEqual(1)
    })

    it('week_flags_from_sunday_keeps_length_seven', 0, () => {
      const flags: boolean[] = computeWeekActiveFlagsFrom('sunday', [formatDateKey(new Date())])
      expect(flags.length).assertEqual(7)
      let activeCount: number = 0
      flags.forEach((flag: boolean) => {
        if (flag) {
          activeCount++
        }
      })
      expect(activeCount).assertEqual(1)
    })
  })
}
