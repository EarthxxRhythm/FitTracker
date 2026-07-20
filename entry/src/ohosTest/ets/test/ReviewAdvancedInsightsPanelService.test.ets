import { describe, expect, it } from '@ohos/hypium'
import { MonetizationTier } from '../../../main/ets/shared/models/MonetizationModels'
import { ExercisePersonalRecordDetail } from '../../../main/ets/shared/services/PersonalRecordService'
import ReviewAdvancedInsightsPanelService from '../../../main/ets/shared/services/ReviewAdvancedInsightsPanelService'
import { ReviewWeeklyTrendItem } from '../../../main/ets/shared/services/ReviewInsightsService'

function createSelectedWeekTrend(): ReviewWeeklyTrendItem {
  const item: ReviewWeeklyTrendItem = {
    weekId: '2026-06-08',
    weekLabel: '本周',
    dateRangeText: '2026-06-08 - 2026-06-14',
    sessionCount: 3,
    totalDurationSeconds: 5400,
    totalDurationText: '90 分钟',
    totalVolume: 2600,
    completionRate: 88,
    completionText: '22/25 组',
    averageSessionText: '30 分钟/次',
    dominantDayId: 'push_day',
    dominantDayLabel: 'push_day',
    summaryText: '本周训练节奏稳定，完成率保持在高位。'
  }
  return item
}

function createSelectedRecordDetail(): ExercisePersonalRecordDetail {
  const detail: ExercisePersonalRecordDetail = {
    exerciseId: 'bench_press',
    exerciseName: '杠铃卧推',
    bestOneRepMax: 92,
    bestWeight: 75,
    bestReps: 8,
    bestDateText: '2026-06-01',
    lastPerformedAt: 1717977600000,
    lastPerformedDateText: '2026-06-09',
    sessionCount: 5,
    performedSetCount: 18,
    recentOneRepMax: 90,
    recentWeight: 72.5,
    recentReps: 8,
    recentVolume: 1740,
    trendText: '最近一次距离 PR 还差 2 kg。'
  }
  return detail
}

export default function reviewAdvancedInsightsPanelServiceTest(): void {
  describe('ReviewAdvancedInsightsPanelService', () => {
    it('creates a locked teaser presentation for free users', 0, () => {
      const presentation = ReviewAdvancedInsightsPanelService.createPresentation(
        true,
        'free',
        4,
        createSelectedWeekTrend(),
        3,
        createSelectedRecordDetail()
      )

      expect(presentation.locked).assertTrue()
      expect(presentation.statusLabel).assertEqual('Free')
      expect(presentation.title).assertEqual('高级洞察预览')
      expect(presentation.actionText).assertEqual('查看 Pro 方案')
      expect(presentation.tiles.length).assertEqual(2)
      expect(presentation.tiles[0].value).assertEqual('最近 4 周')
      expect(presentation.tiles[1].value).assertEqual('杠铃卧推')
    })

    it('creates an unlocked pro presentation with current insight summaries', 0, () => {
      const presentation = ReviewAdvancedInsightsPanelService.createPresentation(
        false,
        'pro',
        4,
        createSelectedWeekTrend(),
        3,
        createSelectedRecordDetail()
      )

      expect(presentation.locked).assertFalse()
      expect(presentation.statusLabel).assertEqual('Pro 已解锁')
      expect(presentation.title).assertEqual('高级洞察已解锁')
      expect(presentation.actionText).assertEqual('查看当前权益')
      expect(presentation.tiles[0].value).assertEqual('本周')
      expect(presentation.tiles[1].value).assertEqual('杠铃卧推 · 92kg')
    })

    it('creates a plus-specific status label for plus users', 0, () => {
      const tier: MonetizationTier = 'plus'
      const presentation = ReviewAdvancedInsightsPanelService.createPresentation(
        false,
        tier,
        0,
        createSelectedWeekTrend(),
        0,
        createSelectedRecordDetail()
      )

      expect(presentation.locked).assertFalse()
      expect(presentation.statusLabel).assertEqual('Plus 已覆盖')
    })
  })
}
