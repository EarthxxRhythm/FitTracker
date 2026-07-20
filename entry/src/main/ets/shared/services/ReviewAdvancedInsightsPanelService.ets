/**
 * ReviewAdvancedInsightsPanelService -- maps monetization state into review advanced-insights panel copy.
 *
 * Phase 4: gate deep review insights without breaking the free workout loop.
 */
import { MonetizationTier } from '../models/MonetizationModels'
import { ReviewWeeklyTrendItem } from './ReviewInsightsService'
import { ExercisePersonalRecordDetail } from './PersonalRecordService'

export class ReviewAdvancedInsightsPreviewTile {
  tileId: string = ''
  label: string = ''
  value: string = ''
  note: string = ''
}

export class ReviewAdvancedInsightsPanelPresentation {
  locked: boolean = true
  statusLabel: string = 'Free'
  title: string = '高级洞察预览'
  description: string = '升级后可查看更完整的周趋势与动作 PR 深度内容。'
  actionText: string = '查看 Pro 方案'
  supportingText: string = '不会影响当前免费训练主链。'
  tiles: ReviewAdvancedInsightsPreviewTile[] = []
}

class ReviewAdvancedInsightsPanelService {
  createDefaultPresentation(): ReviewAdvancedInsightsPanelPresentation {
    return this.createPresentation(
      true,
      'free',
      0,
      this.createEmptyWeeklyTrendItem(),
      0,
      this.createEmptyRecordDetail()
    )
  }

  createPresentation(
    locked: boolean,
    activeTier: MonetizationTier,
    weeklyTrendCount: number,
    selectedWeekTrend: ReviewWeeklyTrendItem,
    recordCount: number,
    selectedRecordDetail: ExercisePersonalRecordDetail
  ): ReviewAdvancedInsightsPanelPresentation {
    if (locked) {
      return this.createLockedPresentation(weeklyTrendCount, selectedWeekTrend, recordCount, selectedRecordDetail)
    }
    return this.createUnlockedPresentation(activeTier, weeklyTrendCount, selectedWeekTrend, recordCount, selectedRecordDetail)
  }

  private createLockedPresentation(
    weeklyTrendCount: number,
    selectedWeekTrend: ReviewWeeklyTrendItem,
    recordCount: number,
    selectedRecordDetail: ExercisePersonalRecordDetail
  ): ReviewAdvancedInsightsPanelPresentation {
    const presentation: ReviewAdvancedInsightsPanelPresentation = {
      locked: true,
      statusLabel: 'Free',
      title: '高级洞察预览',
      description: this.createLockedDescription(weeklyTrendCount, recordCount),
      actionText: '查看 Pro 方案',
      supportingText: '先保持当前训练节奏，等需要更深复盘时再升级即可。',
      tiles: [
        this.createPreviewTile(
          'weekly_preview',
          '周趋势深读',
          this.createLockedWeeklyValue(weeklyTrendCount),
          this.createLockedWeeklyNote(selectedWeekTrend)
        ),
        this.createPreviewTile(
          'record_preview',
          '动作 PR 深挖',
          this.createLockedRecordValue(recordCount, selectedRecordDetail),
          this.createLockedRecordNote(selectedRecordDetail)
        )
      ]
    }
    return presentation
  }

  private createUnlockedPresentation(
    activeTier: MonetizationTier,
    weeklyTrendCount: number,
    selectedWeekTrend: ReviewWeeklyTrendItem,
    recordCount: number,
    selectedRecordDetail: ExercisePersonalRecordDetail
  ): ReviewAdvancedInsightsPanelPresentation {
    const statusLabel: string = activeTier === 'plus' ? 'Plus 已覆盖' : 'Pro 已解锁'
    const presentation: ReviewAdvancedInsightsPanelPresentation = {
      locked: false,
      statusLabel: statusLabel,
      title: '高级洞察已解锁',
      description: this.createUnlockedDescription(activeTier, weeklyTrendCount, recordCount),
      actionText: '查看当前权益',
      supportingText: '下面的周趋势与动作 PR 深度内容已按当前权益开放。',
      tiles: [
        this.createPreviewTile(
          'weekly_preview',
          '当前周趋势',
          this.createUnlockedWeeklyValue(weeklyTrendCount, selectedWeekTrend),
          this.createUnlockedWeeklyNote(selectedWeekTrend)
        ),
        this.createPreviewTile(
          'record_preview',
          '当前动作 PR',
          this.createUnlockedRecordValue(recordCount, selectedRecordDetail),
          this.createUnlockedRecordNote(selectedRecordDetail)
        )
      ]
    }
    return presentation
  }

  private createLockedDescription(weeklyTrendCount: number, recordCount: number): string {
    if (weeklyTrendCount > 0 || recordCount > 0) {
      return '你的训练历史已经开始积累，升级后可直接查看完整周趋势、动作 PR 变化和更深的复盘细节。'
    }
    return '完成更多训练后，这里会成为你的深度复盘区，集中查看周趋势与动作 PR 变化。'
  }

  private createUnlockedDescription(activeTier: MonetizationTier, weeklyTrendCount: number, recordCount: number): string {
    if (weeklyTrendCount > 0 || recordCount > 0) {
      return '当前权益已开放高级洞察。继续在回顾页里查看更完整的周趋势与动作 PR 深度内容。'
    }
    if (activeTier === 'plus') {
      return '当前 Plus 权益已覆盖高级洞察，后续更深的周报与内容扩展也会优先落在这里。'
    }
    return '当前 Pro 权益已解锁高级洞察，这里会优先承接更深的复盘与分析能力。'
  }

  private createLockedWeeklyValue(weeklyTrendCount: number): string {
    if (weeklyTrendCount > 0) {
      return '最近 ' + weeklyTrendCount.toString() + ' 周'
    }
    return '6 周趋势'
  }

  private createLockedWeeklyNote(selectedWeekTrend: ReviewWeeklyTrendItem): string {
    if (selectedWeekTrend.weekId.length > 0) {
      return '解锁 ' + selectedWeekTrend.weekLabel + ' 的完整时长、完成率和重点训练日。'
    }
    return '解锁完整周趋势、平均单次时长与重点训练日。'
  }

  private createLockedRecordValue(recordCount: number, selectedRecordDetail: ExercisePersonalRecordDetail): string {
    if (selectedRecordDetail.exerciseId.length > 0) {
      return selectedRecordDetail.exerciseName
    }
    if (recordCount > 0) {
      return recordCount.toString() + ' 个动作'
    }
    return '动作 PR'
  }

  private createLockedRecordNote(selectedRecordDetail: ExercisePersonalRecordDetail): string {
    if (selectedRecordDetail.exerciseId.length > 0) {
      return '解锁 ' + selectedRecordDetail.exerciseName + ' 的 1RM、最近训练量和频率变化。'
    }
    return '解锁动作 PR 深度细节与训练频率变化。'
  }

  private createUnlockedWeeklyValue(weeklyTrendCount: number, selectedWeekTrend: ReviewWeeklyTrendItem): string {
    if (selectedWeekTrend.weekId.length > 0) {
      return selectedWeekTrend.weekLabel
    }
    if (weeklyTrendCount > 0) {
      return weeklyTrendCount.toString() + ' 周数据'
    }
    return '等待首周训练'
  }

  private createUnlockedWeeklyNote(selectedWeekTrend: ReviewWeeklyTrendItem): string {
    if (selectedWeekTrend.weekId.length > 0) {
      return selectedWeekTrend.summaryText
    }
    return '已解锁最近训练节奏与周详情。'
  }

  private createUnlockedRecordValue(recordCount: number, selectedRecordDetail: ExercisePersonalRecordDetail): string {
    if (selectedRecordDetail.exerciseId.length > 0) {
      if (selectedRecordDetail.bestOneRepMax > 0) {
        return selectedRecordDetail.exerciseName + ' · ' + selectedRecordDetail.bestOneRepMax.toString() + 'kg'
      }
      return selectedRecordDetail.exerciseName
    }
    if (recordCount > 0) {
      return recordCount.toString() + ' 个动作'
    }
    return '等待首个动作记录'
  }

  private createUnlockedRecordNote(selectedRecordDetail: ExercisePersonalRecordDetail): string {
    if (selectedRecordDetail.exerciseId.length > 0) {
      return selectedRecordDetail.trendText
    }
    return '已解锁动作 PR 深度细节。'
  }

  private createPreviewTile(tileId: string, label: string, value: string, note: string): ReviewAdvancedInsightsPreviewTile {
    const tile: ReviewAdvancedInsightsPreviewTile = {
      tileId: tileId,
      label: label,
      value: value,
      note: note
    }
    return tile
  }

  private createEmptyWeeklyTrendItem(): ReviewWeeklyTrendItem {
    const item: ReviewWeeklyTrendItem = {
      weekId: '',
      weekLabel: '',
      dateRangeText: '',
      sessionCount: 0,
      totalDurationSeconds: 0,
      totalDurationText: '',
      totalVolume: 0,
      completionRate: 0,
      completionText: '',
      averageSessionText: '',
      dominantDayId: '',
      dominantDayLabel: '',
      summaryText: ''
    }
    return item
  }

  private createEmptyRecordDetail(): ExercisePersonalRecordDetail {
    const detail: ExercisePersonalRecordDetail = {
      exerciseId: '',
      exerciseName: '',
      bestOneRepMax: 0,
      bestWeight: 0,
      bestReps: 0,
      bestDateText: '',
      lastPerformedAt: 0,
      lastPerformedDateText: '',
      sessionCount: 0,
      performedSetCount: 0,
      recentOneRepMax: 0,
      recentWeight: 0,
      recentReps: 0,
      recentVolume: 0,
      trendText: ''
    }
    return detail
  }
}

export default new ReviewAdvancedInsightsPanelService()
