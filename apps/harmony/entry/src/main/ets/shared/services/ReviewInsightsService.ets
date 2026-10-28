/**
 * ReviewInsightsService -- training review insights for weekly trends and filtered recent sessions.
 *
 * Function #14: recent workout filters and weekly trend details.
 */
import ReviewService from './ReviewService'
import { ReviewRecentSessionRecord } from './ReviewDashboardService'
import TrainingDayLabelService from './TrainingDayLabelService'
import WorkoutSummaryService from './WorkoutSummaryService'
import { WorkoutSession, WorkoutSet } from '../models/TrainingModels'
import { resolveWeekStart, WeekStart } from '../../common/utils/WeekUtils'

export class ReviewRecentSessionFilterOption {
  filterId: string = ''
  label: string = ''
  description: string = ''
  matchedSessionCount: number = 0
  locked: boolean = false
}

export class ReviewWeeklyTrendItem {
  weekId: string = ''
  weekLabel: string = ''
  dateRangeText: string = ''
  sessionCount: number = 0
  totalDurationSeconds: number = 0
  totalDurationText: string = '0 分钟'
  totalVolume: number = 0
  completionRate: number = 0
  completionText: string = '0/0 组'
  averageSessionText: string = '0 分钟/次'
  dominantDayId: string = ''
  dominantDayLabel: string = ''
  summaryText: string = ''
}

class ReviewInsightsService {
  private readonly recentRecordLimit: number = 6
  private readonly weeklyTrendLimit: number = 6
  private currentReferenceTime: number = 0
  private weekStart: WeekStart = 'monday'

  createRecentFilters(
    sessions: WorkoutSession[],
    now: number,
    unlimitedHistoryUnlocked: boolean
  ): ReviewRecentSessionFilterOption[] {
    this.currentReferenceTime = now
    const filters: ReviewRecentSessionFilterOption[] = []
    filters.push(this.createFilterOption('recent_7_days', '最近 7 天', '聚焦最近一周训练', sessions, now, false))
    filters.push(this.createFilterOption('recent_30_days', '最近 30 天', '看近一个月节奏', sessions, now, false))
    filters.push(this.createFilterOption(
      'all_sessions',
      '全部记录',
      unlimitedHistoryUnlocked ? '查看所有已保存训练' : '升级 Pro 后查看全部历史记录',
      sessions,
      now,
      !unlimitedHistoryUnlocked
    ))
    return filters
  }

  filterRecentRecords(
    sessions: WorkoutSession[],
    filterId: string,
    now: number,
    unlimitedHistoryUnlocked: boolean
  ): ReviewRecentSessionRecord[] {
    this.currentReferenceTime = now
    const resolvedFilterId: string = this.resolveFilterId(filterId, unlimitedHistoryUnlocked)
    const filteredSessions: WorkoutSession[] = []
    for (let index = sessions.length - 1; index >= 0; index--) {
      const session: WorkoutSession = sessions[index]
      if (this.matchesFilter(session, resolvedFilterId, now)) {
        filteredSessions.push(session)
      }
      if (filteredSessions.length >= this.recentRecordLimit) {
        break
      }
    }

    const records: ReviewRecentSessionRecord[] = []
    for (let index = 0; index < filteredSessions.length; index++) {
      records.push(this.createRecentRecord(filteredSessions[index]))
    }
    return records
  }

  resolveFilterId(filterId: string, unlimitedHistoryUnlocked: boolean): string {
    if (filterId === 'all_sessions' && !unlimitedHistoryUnlocked) {
      return 'recent_30_days'
    }
    return filterId
  }

  createWeeklyTrendItems(sessions: WorkoutSession[], now: number, weekStart: WeekStart): ReviewWeeklyTrendItem[] {
    this.currentReferenceTime = now
    this.weekStart = weekStart
    const items: ReviewWeeklyTrendItem[] = []
    const currentWeekStart: Date = this.createWeekStart(now)
    for (let offset = 0; offset < this.weeklyTrendLimit; offset++) {
      const weekStart: Date = new Date(
        currentWeekStart.getFullYear(),
        currentWeekStart.getMonth(),
        currentWeekStart.getDate() - offset * 7
      )
      items.push(this.createWeeklyTrendItem(sessions, weekStart))
    }

    for (let index = 0; index < items.length; index++) {
      const current: ReviewWeeklyTrendItem = items[index]
      const previous: ReviewWeeklyTrendItem | undefined = index + 1 < items.length ? items[index + 1] : undefined
      current.summaryText = this.createWeeklySummaryText(current, previous, index)
    }
    return items
  }

  createEmptyWeeklyTrendItem(): ReviewWeeklyTrendItem {
    const item: ReviewWeeklyTrendItem = {
      weekId: '',
      weekLabel: '本周趋势',
      dateRangeText: '',
      sessionCount: 0,
      totalDurationSeconds: 0,
      totalDurationText: '0 分钟',
      totalVolume: 0,
      completionRate: 0,
      completionText: '0/0 组',
      averageSessionText: '0 分钟/次',
      dominantDayId: '',
      dominantDayLabel: '',
      summaryText: '完成训练后，这里会开始累积周趋势。'
    }
    return item
  }

  // ── 肌群热力与努力程度派生（真实数据） ──────────────────────────
  //
  // 内容库用 6 个粗肌群 id（muscle_chest/back/shoulders/arms/legs/core），
  // 而热力图用 18 个身体图部位 key（MM_MUSCLE_KEYS 顺序）。此表是两者之间的映射——
  // 一个粗肌群可落到多个细部位（如 shoulders → deltoids/trapezius）。

  /** 粗肌群 id → 身体图部位 key（下标与 ReviewContent.MM_MUSCLE_KEYS 对齐）。 */
  private mapMuscleIdToBodyParts(muscleId: string): string[] {
    if (muscleId === 'muscle_chest') {
      return ['chest', 'serratus']
    }
    if (muscleId === 'muscle_back') {
      return ['upper-back', 'lower-back', 'trapezius']
    }
    if (muscleId === 'muscle_shoulders') {
      return ['deltoids', 'trapezius']
    }
    if (muscleId === 'muscle_arms') {
      return ['biceps', 'triceps', 'forearm']
    }
    if (muscleId === 'muscle_legs') {
      return ['quadriceps', 'hamstring', 'gluteal', 'adductors', 'calves']
    }
    if (muscleId === 'muscle_core') {
      return ['abs', 'obliques', 'hip-flexors']
    }
    return []
  }

  /** 身体图 18 部位 key（顺序须与 ReviewContent.MM_MUSCLE_KEYS 一致）。 */
  private readonly bodyPartKeys: string[] = [
    'trapezius', 'deltoids', 'chest', 'upper-back', 'serratus', 'biceps', 'triceps', 'forearm',
    'abs', 'obliques', 'lower-back', 'gluteal', 'quadriceps', 'hamstring', 'adductors', 'hip-flexors',
    'calves', 'tibialis'
  ]

  /**
   * 肌群训练量（近 [limit] 次训练）：按组数聚合到 18 个身体部位。
   *
   * 需要「动作 → 主肌群」的解析器（由调用方注入，避免本服务依赖 ContentRepository 造成环依赖）。
   * 返回 18 元组，与 [bodyPartKeys] 同序；无数据时为全 0。
   */
  createMuscleVolume(
    sessions: WorkoutSession[],
    resolvePrimaryMuscles: (exerciseId: string) => string[],
    limit: number
  ): number[] {
    const volume: number[] = []
    for (let index = 0; index < this.bodyPartKeys.length; index++) {
      volume.push(0)
    }
    if (sessions.length === 0) {
      return volume
    }
    const recent: WorkoutSession[] = this.takeRecent(sessions, limit)
    for (let sessionIndex = 0; sessionIndex < recent.length; sessionIndex++) {
      const sets: WorkoutSet[] = recent[sessionIndex].sets
      for (let setIndex = 0; setIndex < sets.length; setIndex++) {
        const muscleIds: string[] = resolvePrimaryMuscles(sets[setIndex].exerciseId)
        for (let muscleIndex = 0; muscleIndex < muscleIds.length; muscleIndex++) {
          const parts: string[] = this.mapMuscleIdToBodyParts(muscleIds[muscleIndex])
          for (let partIndex = 0; partIndex < parts.length; partIndex++) {
            const keyIndex: number = this.bodyPartKeys.indexOf(parts[partIndex])
            if (keyIndex >= 0) {
              volume[keyIndex] = volume[keyIndex] + 1
            }
          }
        }
      }
    }
    return volume
  }

  /**
   * 把肌群训练量归一为 4 级（1–4）——用于热力图着色。
   *
   * 按相对最大值分档：与最大值同量级（> 75%）取 4；训练量为 0 取 0。
   * 所有部位训练量相同时同为 4 级——等级是相对量，不代表绝对强度。
   * 无任何训练量时返回全 0（调用方据此渲染空态）。
   */
  createMuscleLevels(volume: number[]): number[] {
    const levels: number[] = []
    let max: number = 0
    for (let index = 0; index < volume.length; index++) {
      if (volume[index] > max) {
        max = volume[index]
      }
    }
    if (max <= 0) {
      for (let index = 0; index < volume.length; index++) {
        levels.push(0)
      }
      return levels
    }
    for (let index = 0; index < volume.length; index++) {
      if (volume[index] <= 0) {
        levels.push(0)
      } else {
        const ratio: number = volume[index] / max
        if (ratio <= 0.25) {
          levels.push(1)
        } else if (ratio <= 0.5) {
          levels.push(2)
        } else if (ratio <= 0.75) {
          levels.push(3)
        } else {
          levels.push(4)
        }
      }
    }
    return levels
  }

  /** 努力程度序列（近 [count] 次训练的整体 RPE 1–10）；未评价（0）的场次跳过。 */
  createEffortLevels(sessions: WorkoutSession[], count: number): number[] {
    const recent: WorkoutSession[] = this.takeRecent(sessions, count)
    const levels: number[] = []
    for (let index = 0; index < recent.length; index++) {
      const raw: number | undefined = recent[index].sessionRpe
      const rpe: number = raw === undefined ? 0 : raw
      if (rpe > 0) {
        levels.push(rpe)
      }
    }
    return levels
  }

  /**
   * 肌群结论文案（按真实最高/最低训练量部位拼装）；无数据返回空态文案。
   *
   * `labels` 为 18 部位的显示名（与 volume 同序），由调用方注入以免本服务持有 UI 文案。
   */
  createMuscleSummary(volume: number[], labels: string[]): string {
    let maxIndex: number = -1
    let minIndex: number = -1
    let maxValue: number = 0
    let minValue: number = -1
    for (let index = 0; index < volume.length; index++) {
      if (volume[index] > maxValue) {
        maxValue = volume[index]
        maxIndex = index
      }
      if (volume[index] > 0 && (minValue < 0 || volume[index] < minValue)) {
        minValue = volume[index]
        minIndex = index
      }
    }
    if (maxIndex < 0) {
      return '完成训练后，这里会显示肌群训练分布。'
    }
    const maxLabel: string = maxIndex < labels.length ? labels[maxIndex] : ''
    if (minIndex < 0 || minIndex === maxIndex) {
      return maxLabel + '训练量最高。'
    }
    const minLabel: string = minIndex < labels.length ? labels[minIndex] : ''
    return maxLabel + '训练量最高，' + minLabel + '最少。'
  }

  /** 取最近 [count] 次训练（按 startedAt 升序后的末尾若干条）。 */
  private takeRecent(sessions: WorkoutSession[], count: number): WorkoutSession[] {
    const sorted: WorkoutSession[] = sessions.slice()
    sorted.sort((a: WorkoutSession, b: WorkoutSession) => a.startedAt - b.startedAt)
    const start: number = sorted.length > count ? sorted.length - count : 0
    return sorted.slice(start)
  }

  private createFilterOption(
    filterId: string,
    label: string,
    description: string,
    sessions: WorkoutSession[],
    now: number,
    locked: boolean
  ): ReviewRecentSessionFilterOption {
    let matchedSessionCount: number = 0
    for (let index = 0; index < sessions.length; index++) {
      if (this.matchesFilter(sessions[index], filterId, now)) {
        matchedSessionCount++
      }
    }
    const option: ReviewRecentSessionFilterOption = {
      filterId: filterId,
      label: label,
      description: description,
      matchedSessionCount: matchedSessionCount,
      locked: locked
    }
    return option
  }

  private matchesFilter(session: WorkoutSession, filterId: string, now: number): boolean {
    if (filterId === 'recent_7_days') {
      return session.startedAt >= now - 7 * 24 * 60 * 60 * 1000
    }
    if (filterId === 'recent_30_days') {
      return session.startedAt >= now - 30 * 24 * 60 * 60 * 1000
    }
    return true
  }

  private createRecentRecord(session: WorkoutSession): ReviewRecentSessionRecord {
    const completedSets: number = this.getCompletedSets(session)
    const targetSets: number = this.getTargetSets(session)
    const completionRate: number = ReviewService.calculateCompletionRate(completedSets, targetSets)
    const totalVolume: number = this.getTotalVolume(session)
    const record: ReviewRecentSessionRecord = {
      sessionId: session.sessionId,
      dayId: session.dayId,
      dayLabel: TrainingDayLabelService.formatCompact(session.dayId),
      dateText: this.formatDate(session.startedAt),
      durationText: WorkoutSummaryService.formatDuration(session.durationSeconds),
      completedSets: completedSets,
      targetSets: targetSets,
      completionRate: completionRate,
      completionText: completedSets.toString() + '/' + targetSets.toString() + ' 组',
      totalVolume: totalVolume,
      volumeText: totalVolume.toString() + ' kg'
    }
    return record
  }

  private getDisplayDayLabel(dayId: string): string {
    const generatedPlanMatch: RegExpMatchArray | null = dayId.match(/^day_(\d+)$/)
    if (generatedPlanMatch !== null) {
      return '第 ' + generatedPlanMatch[1] + ' 天'
    }

    const currentPlanMatch: RegExpMatchArray | null = dayId.match(/^current_plan_day_(\d+)$/)
    if (currentPlanMatch !== null) {
      return '第 ' + currentPlanMatch[1] + ' 天'
    }

    return dayId
  }

  private createWeeklyTrendItem(sessions: WorkoutSession[], weekStart: Date): ReviewWeeklyTrendItem {
    const weekStartTime: number = weekStart.getTime()
    const weekEnd: Date = new Date(weekStart.getFullYear(), weekStart.getMonth(), weekStart.getDate() + 6)
    const weekEndExclusive: number = new Date(
      weekEnd.getFullYear(),
      weekEnd.getMonth(),
      weekEnd.getDate() + 1
    ).getTime()
    let sessionCount: number = 0
    let totalDurationSeconds: number = 0
    let totalVolume: number = 0
    let completedSets: number = 0
    let targetSets: number = 0
    let dominantDayId: string = ''
    let dominantVolume: number = 0

    for (let index = 0; index < sessions.length; index++) {
      const session: WorkoutSession = sessions[index]
      if (session.startedAt < weekStartTime || session.startedAt >= weekEndExclusive) {
        continue
      }
      sessionCount++
      totalDurationSeconds += session.durationSeconds
      totalVolume += this.getTotalVolume(session)
      completedSets += this.getCompletedSets(session)
      targetSets += this.getTargetSets(session)
      const sessionVolume: number = this.getTotalVolume(session)
      if (sessionVolume >= dominantVolume) {
        dominantVolume = sessionVolume
        dominantDayId = session.dayId
      }
    }

    const completionRate: number = ReviewService.calculateCompletionRate(completedSets, targetSets)
    const averageSessionSeconds: number = sessionCount > 0 ? Math.floor(totalDurationSeconds / sessionCount) : 0
    const item: ReviewWeeklyTrendItem = {
      weekId: this.formatDate(weekStartTime),
      weekLabel: this.createWeekLabel(weekStartTime),
      dateRangeText: this.formatDate(weekStartTime) + ' - ' + this.formatDate(weekEnd.getTime()),
      sessionCount: sessionCount,
      totalDurationSeconds: totalDurationSeconds,
      totalDurationText: WorkoutSummaryService.formatDuration(totalDurationSeconds),
      totalVolume: totalVolume,
      completionRate: completionRate,
      completionText: completedSets.toString() + '/' + targetSets.toString() + ' 组',
      averageSessionText: WorkoutSummaryService.formatDuration(averageSessionSeconds) + '/次',
      dominantDayId: dominantDayId,
      dominantDayLabel: TrainingDayLabelService.formatCompact(dominantDayId),
      summaryText: ''
    }
    return item
  }

  private createWeeklySummaryText(
    current: ReviewWeeklyTrendItem,
    previous: ReviewWeeklyTrendItem | undefined,
    index: number
  ): string {
    if (current.sessionCount === 0) {
      return '这一周还没有训练记录。'
    }
    if (previous === undefined || previous.sessionCount === 0) {
      return '本周完成 ' + current.sessionCount.toString() + ' 次训练，平均完成率 ' +
        current.completionRate.toString() + '%。'
    }

    const volumeDelta: number = current.totalVolume - previous.totalVolume
    const completionDelta: number = current.completionRate - previous.completionRate
    if (index === 0) {
      return '相比上周，训练量' + this.createSignedText(volumeDelta, 'kg') + '，完成率' +
        this.createSignedText(completionDelta, '%') + '。'
    }
    return '相比更早一周，训练量' + this.createSignedText(volumeDelta, 'kg') + '，完成率' +
      this.createSignedText(completionDelta, '%') + '。'
  }

  private createSignedText(delta: number, unit: string): string {
    if (delta > 0) {
      return '增加 ' + delta.toString() + ' ' + unit
    }
    if (delta < 0) {
      return '减少 ' + Math.abs(delta).toString() + ' ' + unit
    }
    return '持平'
  }

  private createWeekLabel(timestamp: number): string {
    const nowWeekStart: string = this.formatDate(this.createWeekStart(this.currentReferenceTime).getTime())
    const weekId: string = this.formatDate(timestamp)
    if (weekId === nowWeekStart) {
      return '本周'
    }
    return '' + this.getWeekOffsetLabel(timestamp) + ' 周前'
  }

  private getWeekOffsetLabel(timestamp: number): string {
    const nowWeekStart: Date = this.createWeekStart(this.currentReferenceTime)
    const weekStart: Date = this.createWeekStart(timestamp)
    const deltaMilliseconds: number = nowWeekStart.getTime() - weekStart.getTime()
    const deltaWeeks: number = Math.floor(deltaMilliseconds / (7 * 24 * 60 * 60 * 1000))
    return deltaWeeks.toString()
  }

  private createWeekStart(timestamp: number): Date {
    return resolveWeekStart(new Date(timestamp), this.weekStart)
  }

  private getTotalVolume(session: WorkoutSession): number {
    if (session.sets.length > 0) {
      return ReviewService.calculateVolume(session.sets)
    }
    if (session.totalVolume > 0) {
      return session.totalVolume
    }
    return ReviewService.calculateVolume(session.sets)
  }

  private getCompletedSets(session: WorkoutSession): number {
    if (session.sets.length > 0) {
      return this.countCompletedSets(session.sets)
    }
    return this.getNumberAfterPrefix(session.notes, 'completed_sets=', 0)
  }

  private getTargetSets(session: WorkoutSession): number {
    return this.getNumberAfterPrefix(session.notes, 'target_sets=', this.getCompletedSets(session))
  }

  private countCompletedSets(sets: WorkoutSet[]): number {
    let count: number = 0
    for (let index = 0; index < sets.length; index++) {
      if (sets[index].weight > 0 && sets[index].reps > 0 && !sets[index].isWarmup) {
        count++
      }
    }
    return count
  }

  private getNumberAfterPrefix(source: string, prefix: string, fallbackValue: number): number {
    const startIndex: number = source.indexOf(prefix)
    if (startIndex < 0) {
      return fallbackValue
    }
    const valueStartIndex: number = startIndex + prefix.length
    let valueEndIndex: number = source.indexOf(';', valueStartIndex)
    if (valueEndIndex < 0) {
      valueEndIndex = source.length
    }
    const parsed: number = Number(source.substring(valueStartIndex, valueEndIndex))
    if (Number.isNaN(parsed)) {
      return fallbackValue
    }
    return Math.floor(parsed)
  }

  private formatDate(timestamp: number): string {
    const date: Date = new Date(timestamp)
    return date.getFullYear().toString() + '-' + this.padTwoDigits(date.getMonth() + 1) + '-' +
      this.padTwoDigits(date.getDate())
  }

  private padTwoDigits(value: number): string {
    if (value < 10) {
      return '0' + value.toString()
    }
    return value.toString()
  }
}

export default new ReviewInsightsService()
