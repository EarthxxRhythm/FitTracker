/**
 * AchievementNoticeService 纯函数单元测试
 * 覆盖里程碑命中/未命中边界，与连续训练天数的锚点（今天/昨天宽限）、断档、跨月、空集。
 */
import { describe, it, expect } from '@ohos/hypium'
import { achievementMilestone, computeStreak } from '../../../main/ets/common/services/AchievementNoticeService'

export default function achievementNoticeServiceTest(): void {
  describe('AchievementNoticeService', () => {
    it('returns milestone value when streak hits 3/7/14/30', 0, () => {
      expect(achievementMilestone(3)).assertEqual(3)
      expect(achievementMilestone(7)).assertEqual(7)
      expect(achievementMilestone(14)).assertEqual(14)
      expect(achievementMilestone(30)).assertEqual(30)
    })

    it('returns null when streak misses milestone', 0, () => {
      expect(achievementMilestone(0)).assertEqual(null)
      expect(achievementMilestone(1)).assertEqual(null)
      expect(achievementMilestone(2)).assertEqual(null)
      expect(achievementMilestone(4)).assertEqual(null)
      expect(achievementMilestone(6)).assertEqual(null)
      expect(achievementMilestone(29)).assertEqual(null)
      expect(achievementMilestone(31)).assertEqual(null)
    })

    it('counts from today when today is trained', 0, () => {
      const dates: string[] = ['2026-10-13', '2026-10-12', '2026-10-11']
      expect(computeStreak(dates, '2026-10-13')).assertEqual(3)
    })

    it('counts from yesterday when today is not trained', 0, () => {
      const dates: string[] = ['2026-10-12', '2026-10-11']
      expect(computeStreak(dates, '2026-10-13')).assertEqual(2)
    })

    it('returns 0 when neither today nor yesterday is trained', 0, () => {
      const dates: string[] = ['2026-10-10', '2026-10-09']
      expect(computeStreak(dates, '2026-10-13')).assertEqual(0)
    })

    it('returns 0 for empty date set', 0, () => {
      const dates: string[] = []
      expect(computeStreak(dates, '2026-10-13')).assertEqual(0)
    })

    it('stops at the first gap in the chain', 0, () => {
      const dates: string[] = ['2026-10-13', '2026-10-11']
      expect(computeStreak(dates, '2026-10-13')).assertEqual(1)
    })

    it('counts across month boundary', 0, () => {
      const dates: string[] = ['2026-11-01', '2026-10-31']
      expect(computeStreak(dates, '2026-11-01')).assertEqual(2)
    })

    it('ignores date order in the input set', 0, () => {
      const dates: string[] = ['2026-10-12', '2026-10-13', '2026-10-11']
      expect(computeStreak(dates, '2026-10-13')).assertEqual(3)
    })
  })
}
