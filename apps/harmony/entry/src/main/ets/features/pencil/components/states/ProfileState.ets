/**
 * 「我的」Tab 状态层。
 *
 * 由 PencilAppShell 以 `@State` 持有（生命周期 = 主壳，tab 切换不销毁），
 * ProfileContent 以 `@ObjectLink` 消费。装载编排从 ProfileContent.aboutToAppear 迁入。
 *
 * 样例初值已修正为**空态/占位**（同 Android 端 68e797f 收口口径）——不再用「林默」等
 * 原型样例，避免「先闪样例再翻真数据」。装载失败时也回落空态占位（原 `keep placeholder`
 * 语义保留，但占位内容从样例改为中性值）。
 */
import { Context } from '@kit.AbilityKit'
import { StateBase } from './StateBase'
import UserProfileService, { UserProfile, WeightUnit } from '../../../../common/services/UserProfileService'
import { kgToDisplay, weightUnitLabel } from '../../../../common/utils/WeightUtils'
import WorkoutSessionService, { WeeklyStats } from '../../../../common/services/WorkoutSessionService'
import SettingsService, { AppSettings } from '../../../../common/services/SettingsService'
import { resolveWeekStart, WeekStart } from '../../../../common/utils/WeekUtils'
import { computeStreakCount, computeWeekActiveFlagsFrom } from '../../../../common/utils/StreakUtils'
import PersonalRecordService, { ExercisePersonalRecordDetail } from '../../../../shared/services/PersonalRecordService'
import WorkoutSessionPersistenceBridgeService from '../../../workout/services/WorkoutSessionPersistenceBridgeService'
import { WorkoutSession } from '../../../../shared/models/TrainingModels'
import GoalRepository from '../../../../shared/services/GoalRepository'
import { UserGoal } from '../../../../shared/models/TrainingModels'

/** 一条最近成就的展示数据（`note` 已按当前单位换算）。 */
export interface AchievementRow {
  title: string
  note: string
  value: string
  icon: string
}

@Observed
export class ProfileState extends StateBase {
  /** 展示单位（来自「设置 · 体重单位」）；成就卡样例重量的基准值仍为 kg。 */
  displayUnit: WeightUnit = 'kg'
  achievementRows: AchievementRow[] = []
  avatarLetter: string = '\u2014'
  nickname: string = '\u2014'
  goalSubtitle: string = '\u672a\u8bbe\u7f6e\u76ee\u6807'
  weekRangeText: string = ''
  weekDurationText: string = '0'
  weekCountText: string = '0'
  /** 连续训练天数（真实派生）；0 = 尚未开始。 */
  streakCount: number = 0
  /** 本周打卡标记（跟随「设置 · 周开始日」）。 */
  weekActiveFlags: boolean[] = [false, false, false, false, false, false, false]
  /** 打卡格的星期标签序（随周开始日重排）。 */
  weekDayLabels: string[] = ['一', '二', '三', '四', '五', '六', '日']
  /** 「设置 · 周开始日」（打卡格与连续记录的周口径）。 */
  weekStartKey: WeekStart = 'monday'
  /** 个人记录明细（真实 PR，供成就卡派生）。 */
  personalRecordDetails: ExercisePersonalRecordDetail[] = []

  /** 按需装载。[force] 为 true 跳过新鲜度判断（首次 aboutToAppear 用）。 */
  async refresh(context: Context, force: boolean = false): Promise<void> {
    if (!force && !this.needRefresh()) {
      return
    }
    if (!this.tryBeginLoading()) {
      return
    }
    try {
      await this.load(context)
      this.markLoaded()
    } finally {
      this.endLoading()
    }
  }

  /** 装载主体（等价迁移自 ProfileContent.aboutToAppear）。 */
  private async load(context: Context): Promise<void> {
    // 周区间由设置页「周开始日」决定；先按默认周一渲染，读到设置后再覆盖。
    this.weekRangeText = this.computeWeekRangeText('monday')
    try {
      const settings: AppSettings = await SettingsService.loadSettings(context)
      this.weekStartKey = settings.weekStart
      this.weekRangeText = this.computeWeekRangeText(settings.weekStart)
    } catch (error) {
      // Settings read failed: keep the monday-based week range computed above.
    }
    try {
      const profile: UserProfile = await UserProfileService.loadProfile(context)
      // 成就卡里的样例重量按「设置 · 体重单位」换算展示（基准值仍是 kg）。
      this.displayUnit = profile.weightUnit
      this.avatarLetter = profile.avatar.trim().length > 0
        ? profile.avatar.trim().charAt(0)
        : '\u2014'
      this.nickname = profile.nickname.trim().length > 0
        ? profile.nickname.trim()
        : '\u2014'
    } catch (error) {
      // Profile read failed: keep the neutral placeholder.
    }
    try {
      const goal: UserGoal | undefined = await GoalRepository.loadGoal(context)
      if (goal !== undefined && goal.createdAt > 0) {
        const dayCount: number = this.computeGoalDayCount(goal.createdAt)
        this.goalSubtitle = '\u589e\u808c\u7b2c ' + dayCount.toString() + ' \u5929 \u00b7 \u4fdd\u6301\u8282\u594f'
      } else {
        this.goalSubtitle = '\u672a\u8bbe\u7f6e\u76ee\u6807'
      }
    } catch (error) {
      // Goal read failed: keep the neutral placeholder.
    }
    try {
      const stats: WeeklyStats = await WorkoutSessionService.getWeeklyStats(context)
      this.weekDurationText = Math.round(stats.duration / 60).toString()
      this.weekCountText = stats.count.toString()
    } catch (error) {
      // Weekly stats read failed: keep the neutral placeholder.
    }
    // 连续记录与本周打卡：由真实训练日期派生（与完成页同一实现）。
    try {
      const trainingDates: string[] = await WorkoutSessionService.getTrainingDates(context)
      this.streakCount = computeStreakCount(trainingDates)
      this.applyWeekFlags(trainingDates, this.weekStartKey)
    } catch (error) {
      this.streakCount = 0
      this.weekActiveFlags = [false, false, false, false, false, false, false]
    }
    // 个人记录：取真实会话派生（供成就卡）；失败保持空（成就卡渲染空态）。
    try {
      const sessions: WorkoutSession[] = await WorkoutSessionPersistenceBridgeService.loadPersistedSessions(context)
      this.personalRecordDetails = PersonalRecordService.createRecordDetails(sessions)
    } catch (error) {
      this.personalRecordDetails = []
    }
    // 成就行在 streak / 本周统计 / PR 都就绪后统一重算（首帧那次用的是空数据）。
    this.achievementRows = this.createAchievementRows()
  }

  // ── 派生（从 ProfileContent 迁入） ────────────────────────────────────────

  /** 按周开始日重排打卡格：周日首时标签序与标记都随之旋转。 */
  private applyWeekFlags(trainingDates: string[], weekStart: WeekStart): void {
    const flags: boolean[] = computeWeekActiveFlagsFrom(weekStart, trainingDates)
    if (weekStart === 'sunday') {
      this.weekDayLabels = ['日', '一', '二', '三', '四', '五', '六']
    } else {
      this.weekDayLabels = ['一', '二', '三', '四', '五', '六', '日']
    }
    this.weekActiveFlags = flags
  }

  /** 连续记录标题右侧文案：有训练显示「连续 N 天」，无则「尚未开始」。 */
  streakLabel(): string {
    if (this.streakCount <= 0) {
      return '\u5c1a\u672a\u5f00\u59cb'
    }
    return '\u8fde\u7eed ' + this.streakCount.toString() + ' \u5929'
  }

  private computeWeekRangeText(weekStart: WeekStart): string {
    const now: Date = new Date()
    const weekStartDate: Date = resolveWeekStart(now, weekStart)
    const weekEndDate: Date = new Date(weekStartDate.getFullYear(), weekStartDate.getMonth(), weekStartDate.getDate() + 6)
    const startText: string = (weekStartDate.getMonth() + 1).toString() + ' \u6708 ' + weekStartDate.getDate().toString()
    const endText: string = weekEndDate.getMonth() === weekStartDate.getMonth()
      ? weekEndDate.getDate().toString() + ' \u65e5'
      : (weekEndDate.getMonth() + 1).toString() + ' \u6708 ' + weekEndDate.getDate().toString() + ' \u65e5'
    return startText + ' \u2013 ' + endText
  }

  private computeGoalDayCount(createdAt: number): number {
    // createdAt is a millisecond timestamp; day 1 starts on the goal creation date.
    const oneDayMs: number = 24 * 60 * 60 * 1000
    const days: number = Math.floor((Date.now() - createdAt) / oneDayMs) + 1
    return days < 1 ? 1 : days
  }

  private achievementWeightText(kg: number): string {
    const value: number = kgToDisplay(kg, this.displayUnit)
    const text: string = Math.round(value * 10) % 10 === 0 ? Math.round(value).toString() : value.toFixed(1)
    return text + ' ' + weightUnitLabel(this.displayUnit)
  }

  /**
   * 构建成就行数据（全部由真实数据派生；无数据时返回空数组 → 卡片渲染空态）。
   *
   * ① 连续训练：用 [streakCount]；② 重量突破：取个人记录里最大 `bestWeight` 的动作与数值。
   */
  private createAchievementRows(): AchievementRow[] {
    const rows: AchievementRow[] = []
    if (this.streakCount > 0) {
      const streakRow: AchievementRow = {
        title: '\u7a33\u5b9a\u8f93\u51fa',
        note: '\u8fde\u7eed\u8bad\u7ec3 ' + this.streakCount.toString() + ' \u5929',
        value: '\u672c\u5468 ' + this.weekCountText + ' \u6b21',
        icon: 'flame'
      }
      rows.push(streakRow)
    }
    const best: ExercisePersonalRecordDetail | undefined = this.bestRecord()
    if (best !== undefined) {
      const prRow: AchievementRow = {
        title: '\u91cd\u91cf\u7a81\u7834',
        note: best.exerciseName + ' ' + this.achievementWeightText(best.bestWeight),
        value: best.bestDateText,
        icon: 'trophy'
      }
      rows.push(prRow)
    }
    return rows
  }

  /** 个人记录里最大重量的动作；无记录返回 undefined。 */
  private bestRecord(): ExercisePersonalRecordDetail | undefined {
    const details: ExercisePersonalRecordDetail[] = this.personalRecordDetails
    if (details.length === 0) {
      return undefined
    }
    let best: ExercisePersonalRecordDetail = details[0]
    for (let index = 1; index < details.length; index++) {
      if (details[index].bestWeight > best.bestWeight) {
        best = details[index]
      }
    }
    return best.bestWeight > 0 ? best : undefined
  }
}
