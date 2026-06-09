/**
 * ReviewHomePage —— 增强训练回顾页。
 *
 * 功能 #12：训练回顾与目标调整建议。
 * 功能 #14：最近训练筛选、按周趋势查看与按动作查看个人纪录。
 */
import { router } from '@kit.ArkUI'
import { AppRoutes } from '../../../app/AppRoutes'
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens, TouchTokens } from '../../../common/styles/DesignTokens'
import { AppButton } from '../../../components/AppButton'
import { AppCard } from '../../../components/AppCard'
import { AppInput } from '../../../components/AppInput'
import { PrimaryDestinationStrip } from '../../../components/PrimaryDestinationStrip'
import PlanEngine from '../../../shared/services/PlanEngine'
import GoalRepository from '../../../shared/services/GoalRepository'
import GoalSetupService, { GoalSetupPrefill } from '../../../shared/services/GoalSetupService'
import GoalAdjustmentPreviewService, {
  GoalAdjustmentPlanSnapshot
} from '../../../shared/services/GoalAdjustmentPreviewService'
import UserDataBackupService from '../../../shared/services/UserDataBackupService'
import PersonalRecordService, {
  ExercisePersonalRecordDetail
} from '../../../shared/services/PersonalRecordService'
import ReviewDashboardService, {
  ReviewGoalAdjustmentAction,
  ReviewDashboardSummary,
  ReviewPlanRegenerationResult,
  ReviewRecentSessionRecord,
  ReviewTrendSummary
} from '../../../shared/services/ReviewDashboardService'
import ReviewInsightsService, {
  ReviewRecentSessionFilterOption,
  ReviewWeeklyTrendItem
} from '../../../shared/services/ReviewInsightsService'
import ReviewAdvancedInsightsPanelService, {
  ReviewAdvancedInsightsPanelPresentation,
  ReviewAdvancedInsightsPreviewTile
} from '../../../shared/services/ReviewAdvancedInsightsPanelService'
import MonetizationGateService from '../../../shared/services/MonetizationGateService'
import ReviewUpgradeEntryService, {
  ReviewUpgradeEntryPresentation
} from '../../../shared/services/ReviewUpgradeEntryService'
import StatsDashboardService, {
  CalendarHeatmapDay,
  CalendarHeatmapRow,
  StatsDashboardSummary
} from '../../../shared/services/StatsDashboardService'
import WorkoutRepository from '../../../shared/services/WorkoutRepository'
import { TrainingPlan, UserGoal, WorkoutSession } from '../../../shared/models/TrainingModels'
import { MonetizationCapability, MonetizationTier } from '../../../shared/models/MonetizationModels'
import SessionManager from '../../../common/services/SessionManager'
import UserProfileService, { UserProfile, WeightUnit } from '../../../common/services/UserProfileService'
import WorkoutSessionPersistenceBridgeService from '../../workout/services/WorkoutSessionPersistenceBridgeService'

@Entry
@Component
export struct ReviewHomePage {
  @State loading: boolean = true
  @State hasSessions: boolean = false
  @State sessionCount: number = 0
  @State totalCompletedSets: number = 0
  @State totalTargetSets: number = 0
  @State averageCompletionRate: number = 0
  @State totalDurationText: string = '0 分钟'
  @State latestSessionId: string = ''
  @State latestDayId: string = ''
  @State adjustmentText: string = ''
  @State adjustmentTitle: string = ''
  @State adjustmentDescription: string = ''
  @State adjustmentButtonText: string = '暂无可应用调整'
  @State canApplyAdjustment: boolean = false
  @State applyingAdjustment: boolean = false
  @State adjustmentStatusText: string = ''
  @State trendSummary: ReviewTrendSummary = ReviewDashboardService.createEmptyTrendSummary()
  @State weeklySessionCount: number = 0
  @State weeklyDurationText: string = '0 分钟'
  @State weeklyTotalSets: number = 0
  @State weeklyTotalVolume: number = 0
  @State weeklyDateRangeText: string = ''
  @State heatmapMonthTitle: string = ''
  @State heatmapRows: CalendarHeatmapRow[] = []
  @State recentFilterOptions: ReviewRecentSessionFilterOption[] = []
  @State selectedRecentFilterId: string = 'recent_7_days'
  @State unlimitedHistoryUnlocked: boolean = false
  @State historyUpgradeHintText: string = ''
  @State filteredRecentRecords: ReviewRecentSessionRecord[] = []
  @State weeklyTrends: ReviewWeeklyTrendItem[] = []
  @State selectedWeekId: string = ''
  @State selectedWeekTrend: ReviewWeeklyTrendItem = ReviewInsightsService.createEmptyWeeklyTrendItem()
  @State recordDetails: ExercisePersonalRecordDetail[] = []
  @State selectedExerciseId: string = ''
  @State selectedRecordDetail: ExercisePersonalRecordDetail = PersonalRecordService.createEmptyRecordDetail()
  @State profileNickname: string = ''
  @State profileAvatar: string = ''
  @State profileWeightUnit: WeightUnit = 'kg'
  @State profileStatusText: string = ''
  @State profileLoading: boolean = false
  @State backupPackageText: string = ''
  @State backupStatusText: string = ''
  @State backupStatusTone: string = 'info'
  @State backupBusy: boolean = false
  @State backupFlow: string = 'idle'
  @State hasAdjustmentPreview: boolean = false
  @State adjustmentPreviewOverviewText: string = ''
  @State adjustmentPreviewArrangementText: string = ''
  @State adjustmentPreviewCurrentSummaryText: string = ''
  @State adjustmentPreviewNextSummaryText: string = ''
  @State adjustmentPreviewHighlights: string[] = []
  @State advancedInsightsEntry: ReviewUpgradeEntryPresentation =
    ReviewUpgradeEntryService.createDefaultAdvancedInsightsPresentation()
  @State advancedInsightsPanel: ReviewAdvancedInsightsPanelPresentation =
    ReviewAdvancedInsightsPanelService.createDefaultPresentation()
  @State advancedInsightsLocked: boolean = true
  @State advancedInsightsActiveTier: MonetizationTier = 'free'
  currentGoal: UserGoal | undefined = undefined
  currentAdjustmentAction: ReviewGoalAdjustmentAction = ReviewDashboardService.createEmptyGoalAdjustmentAction()
  sessions: WorkoutSession[] = []
  currentNow: number = 0

  async aboutToAppear(): Promise<void> {
    await this.reloadReviewData()
  }

  async reloadReviewData(): Promise<void> {
    this.loading = true
    this.currentNow = Date.now()
    try {
      this.sessions = await WorkoutSessionPersistenceBridgeService.syncRepositoryFromPersistence(getContext(this))
    } catch (e) {
      this.sessions = WorkoutRepository.getSessions()
    }
    const summary: ReviewDashboardSummary = ReviewDashboardService.createSummary(this.sessions)
    const statsSummary: StatsDashboardSummary = StatsDashboardService.createSummary(this.sessions, this.currentNow)
    this.applySummary(summary)
    this.applyStatsSummary(statsSummary)
    await this.loadUnlimitedHistoryAccess()
    this.applyReviewInsights(this.sessions, this.currentNow)
    try {
      const goal: UserGoal | undefined = await GoalRepository.loadGoal(getContext(this))
      this.currentGoal = goal
      if (goal !== undefined) {
        this.applyAdjustmentAction(ReviewDashboardService.createGoalAdjustmentAction(summary, goal))
      } else {
        this.applyAdjustmentAction(ReviewDashboardService.createEmptyGoalAdjustmentAction())
      }
    } catch (e) {
      this.currentGoal = undefined
      this.applyAdjustmentAction(ReviewDashboardService.createEmptyGoalAdjustmentAction())
    }
    this.refreshAdjustmentPreview()
    await this.loadProfile()
    await this.loadAdvancedInsightsEntry()
    this.loading = false
  }

  applyReviewInsights(sessions: WorkoutSession[], now: number): void {
    const filters: ReviewRecentSessionFilterOption[] = ReviewInsightsService.createRecentFilters(
      sessions,
      now,
      this.unlimitedHistoryUnlocked
    )
    this.recentFilterOptions = this.copyRecentFilterOptions(filters)
    if (!this.hasFilter(this.recentFilterOptions, this.selectedRecentFilterId)) {
      this.selectedRecentFilterId = this.recentFilterOptions.length > 0 ? this.recentFilterOptions[0].filterId : 'recent_7_days'
    }
    this.selectedRecentFilterId = ReviewInsightsService.resolveFilterId(
      this.selectedRecentFilterId,
      this.unlimitedHistoryUnlocked
    )
    this.filteredRecentRecords = this.copyRecentRecords(
      ReviewInsightsService.filterRecentRecords(
        sessions,
        this.selectedRecentFilterId,
        now,
        this.unlimitedHistoryUnlocked
      )
    )

    const trendItems: ReviewWeeklyTrendItem[] = ReviewInsightsService.createWeeklyTrendItems(sessions, now)
    this.weeklyTrends = this.copyWeeklyTrends(trendItems)
    if (this.weeklyTrends.length > 0) {
      this.selectWeekTrend(this.weeklyTrends[0].weekId)
    } else {
      this.selectedWeekId = ''
      this.selectedWeekTrend = ReviewInsightsService.createEmptyWeeklyTrendItem()
    }

    const details: ExercisePersonalRecordDetail[] = PersonalRecordService.createRecordDetails(sessions)
    this.recordDetails = this.copyRecordDetails(details)
    if (this.recordDetails.length > 0) {
      this.selectExerciseRecord(this.recordDetails[0].exerciseId)
    } else {
      this.selectedExerciseId = ''
      this.selectedRecordDetail = PersonalRecordService.createEmptyRecordDetail()
    }
    this.refreshAdvancedInsightsPanel()
  }

  hasFilter(filters: ReviewRecentSessionFilterOption[], filterId: string): boolean {
    for (let index = 0; index < filters.length; index++) {
      if (filters[index].filterId === filterId) {
        return true
      }
    }
    return false
  }

  findRecentFilterOption(filterId: string): ReviewRecentSessionFilterOption | undefined {
    for (let index = 0; index < this.recentFilterOptions.length; index++) {
      const option: ReviewRecentSessionFilterOption = this.recentFilterOptions[index]
      if (option.filterId === filterId) {
        return option
      }
    }
    return undefined
  }

  applyStatsSummary(summary: StatsDashboardSummary): void {
    this.weeklySessionCount = summary.weeklyStats.sessionCount
    this.weeklyDurationText = summary.weeklyStats.totalDurationText
    this.weeklyTotalSets = summary.weeklyStats.totalSets
    this.weeklyTotalVolume = summary.weeklyStats.totalVolume
    this.weeklyDateRangeText = summary.weeklyStats.dateRangeText
    this.heatmapMonthTitle = summary.monthTitle
    this.heatmapRows = this.copyHeatmapRows(summary.heatmapRows)
  }

  applySummary(summary: ReviewDashboardSummary): void {
    this.hasSessions = summary.hasSessions
    this.sessionCount = summary.sessionCount
    this.totalCompletedSets = summary.totalCompletedSets
    this.totalTargetSets = summary.totalTargetSets
    this.averageCompletionRate = summary.averageCompletionRate
    this.totalDurationText = summary.totalDurationText
    this.latestSessionId = summary.latestSessionId
    this.latestDayId = summary.latestDayId
    this.adjustmentText = summary.adjustmentText
    this.trendSummary = summary.trendSummary
  }

  applyAdjustmentAction(action: ReviewGoalAdjustmentAction): void {
    this.currentAdjustmentAction = action
    this.adjustmentTitle = action.title
    this.adjustmentDescription = action.description
    this.adjustmentButtonText = action.buttonText
    this.canApplyAdjustment = action.canApply
  }

  refreshAdjustmentPreview(): void {
    if (this.currentGoal === undefined || !this.canApplyAdjustment) {
      this.clearAdjustmentPreview()
      return
    }

    const selection: GoalSetupPrefill = GoalSetupService.createPrefillFromGoal(this.currentGoal)
    selection.weeklyDays = this.currentAdjustmentAction.targetWeeklyDays
    selection.sessionMinutes = this.currentAdjustmentAction.targetSessionMinutes
    const currentPlan: TrainingPlan = PlanEngine.generatePlan(this.currentGoal)
    const preview = GoalAdjustmentPreviewService.createPreview(
      this.currentGoal,
      currentPlan,
      selection,
      this.currentNow
    )

    this.hasAdjustmentPreview = preview.hasChanges || preview.planChanged
    this.adjustmentPreviewOverviewText = preview.overviewText
    this.adjustmentPreviewArrangementText = preview.arrangementChangeText
    this.adjustmentPreviewCurrentSummaryText = this.createPlanSummaryText(preview.currentPlanSnapshot)
    this.adjustmentPreviewNextSummaryText = this.createPlanSummaryText(preview.previewPlanSnapshot)
    this.adjustmentPreviewHighlights = this.copyStringArray(preview.summaryHighlights)
  }

  clearAdjustmentPreview(): void {
    this.hasAdjustmentPreview = false
    this.adjustmentPreviewOverviewText = ''
    this.adjustmentPreviewArrangementText = ''
    this.adjustmentPreviewCurrentSummaryText = ''
    this.adjustmentPreviewNextSummaryText = ''
    this.adjustmentPreviewHighlights = []
  }

  createPlanSummaryText(snapshot: GoalAdjustmentPlanSnapshot): string {
    return '每周' + snapshot.weeklyDays.toString() + '天 · ' +
      snapshot.totalExercises.toString() + '个动作 · ' + snapshot.focusSummary
  }

  async loadProfile(): Promise<void> {
    const profile: UserProfile = await UserProfileService.loadProfile(getContext(this))
    this.profileNickname = profile.nickname
    this.profileAvatar = profile.avatar
    this.profileWeightUnit = profile.weightUnit
  }

  async loadUnlimitedHistoryAccess(): Promise<void> {
    try {
      const gateResult = await MonetizationGateService.getGateResult(getContext(this), 'unlimited_history')
      this.unlimitedHistoryUnlocked = gateResult.allowed
    } catch (e) {
      this.unlimitedHistoryUnlocked = false
    }
  }

  async loadAdvancedInsightsEntry(): Promise<void> {
    try {
      const gateResult = await MonetizationGateService.getGateResult(getContext(this), 'advanced_insights')
      this.advancedInsightsLocked = !gateResult.allowed
      this.advancedInsightsActiveTier = gateResult.activeTier
      this.advancedInsightsEntry = ReviewUpgradeEntryService.createAdvancedInsightsPresentation(
        gateResult,
        this.sessionCount,
        this.weeklySessionCount
      )
      this.refreshAdvancedInsightsPanel()
    } catch (e) {
      this.advancedInsightsLocked = true
      this.advancedInsightsActiveTier = 'free'
      this.advancedInsightsEntry = ReviewUpgradeEntryService.createDefaultAdvancedInsightsPresentation()
      this.refreshAdvancedInsightsPanel()
    }
  }

  openMonetizationHub(capability: MonetizationCapability, sourceLabel: string): void {
    try {
      router.pushUrl({
        url: AppRoutes.MONETIZATION_HUB,
        params: {
          focusCapability: capability,
          focusSourceLabel: sourceLabel
        }
      })
    } catch (e) {
      // stay on review
    }
  }

  selectRecentFilter(filterId: string): void {
    const option: ReviewRecentSessionFilterOption | undefined = this.findRecentFilterOption(filterId)
    if (option !== undefined && option.locked) {
      this.historyUpgradeHintText = '全部历史记录已作为 Pro 权益开放。'
      this.openMonetizationHub('unlimited_history', '最近训练筛选')
      return
    }
    this.selectedRecentFilterId = filterId
    this.historyUpgradeHintText = ''
    this.filteredRecentRecords = this.copyRecentRecords(
      ReviewInsightsService.filterRecentRecords(
        this.sessions,
        filterId,
        this.currentNow,
        this.unlimitedHistoryUnlocked
      )
    )
  }

  selectWeekTrend(weekId: string): void {
    this.selectedWeekId = weekId
    for (let index = 0; index < this.weeklyTrends.length; index++) {
      const item: ReviewWeeklyTrendItem = this.weeklyTrends[index]
      if (item.weekId === weekId) {
        this.selectedWeekTrend = this.copyWeeklyTrend(item)
        this.refreshAdvancedInsightsPanel()
        return
      }
    }
    this.selectedWeekTrend = ReviewInsightsService.createEmptyWeeklyTrendItem()
    this.refreshAdvancedInsightsPanel()
  }

  selectExerciseRecord(exerciseId: string): void {
    this.selectedExerciseId = exerciseId
    for (let index = 0; index < this.recordDetails.length; index++) {
      const detail: ExercisePersonalRecordDetail = this.recordDetails[index]
      if (detail.exerciseId === exerciseId) {
        this.selectedRecordDetail = this.copyRecordDetail(detail)
        this.refreshAdvancedInsightsPanel()
        return
      }
    }
    this.selectedRecordDetail = PersonalRecordService.createEmptyRecordDetail()
    this.refreshAdvancedInsightsPanel()
  }

  refreshAdvancedInsightsPanel(): void {
    this.advancedInsightsPanel = ReviewAdvancedInsightsPanelService.createPresentation(
      this.advancedInsightsLocked,
      this.advancedInsightsActiveTier,
      this.weeklyTrends.length,
      this.selectedWeekTrend,
      this.recordDetails.length,
      this.selectedRecordDetail
    )
  }

  openHome(): void {
    try {
      router.replaceUrl({ url: AppRoutes.HOME })
    } catch (e) {
      // stay on current page
    }
  }

  openGoalSetup(): void {
    try {
      router.pushUrl({ url: AppRoutes.GOAL_SETUP })
    } catch (e) {
      // stay on current page
    }
  }

  openLatestSummary(): void {
    if (this.latestSessionId.length === 0) {
      return
    }
    try {
      router.pushUrl({ url: AppRoutes.WORKOUT_SUMMARY, params: { sessionId: this.latestSessionId } })
    } catch (e) {
      // stay on current page
    }
  }

  openExerciseDetail(): void {
    if (this.selectedRecordDetail.exerciseId.length === 0) {
      return
    }
    try {
      router.pushUrl({
        url: AppRoutes.EXERCISE_DETAIL,
        params: { exerciseId: this.selectedRecordDetail.exerciseId }
      })
    } catch (e) {
      // stay on current page
    }
  }

  async saveNickname(): Promise<void> {
    const nickname: string = this.profileNickname.trim()
    this.profileNickname = nickname
    this.profileLoading = true
    this.profileStatusText = ''
    await UserProfileService.saveNickname(getContext(this), nickname)
    this.profileStatusText = UserProfileService.getLastPersistenceError().length > 0 ? '昵称保存失败' : '昵称已保存'
    this.profileLoading = false
  }

  async saveWeightUnit(unit: WeightUnit): Promise<void> {
    if (this.profileWeightUnit === unit) {
      return
    }
    this.profileLoading = true
    this.profileStatusText = ''
    this.profileWeightUnit = unit
    await UserProfileService.saveWeightUnit(getContext(this), unit)
    this.profileStatusText = UserProfileService.getLastPersistenceError().length > 0 ? '重量单位保存失败' : '重量单位已保存'
    this.profileLoading = false
  }

  async logout(): Promise<void> {
    this.profileLoading = true
    this.profileStatusText = ''
    await SessionManager.clearToken(getContext(this))
    this.profileLoading = false
    if (SessionManager.getLastPersistenceError().length > 0) {
      this.profileStatusText = '退出登录失败'
      return
    }
    try {
      router.replaceUrl({ url: AppRoutes.LOGIN })
    } catch (e) {
      this.profileStatusText = '跳转登录页失败'
    }
  }

  async exportBackupPackage(): Promise<void> {
    if (this.backupBusy) {
      return
    }
    this.backupFlow = 'export'
    this.backupBusy = true
    this.backupStatusText = ''
    this.backupStatusTone = 'info'
    try {
      this.backupPackageText = await UserDataBackupService.exportPackage(getContext(this))
      this.backupStatusText = UserDataBackupService.getExportSuccessStatusText()
      this.backupStatusTone = 'success'
    } catch (e) {
      this.backupStatusText = UserDataBackupService.getExportFailureStatusText()
      this.backupStatusTone = 'error'
    }
    this.backupBusy = false
  }

  async importBackupPackage(): Promise<void> {
    if (this.backupBusy) {
      return
    }
    this.backupFlow = 'import'
    if (this.backupPackageText.trim().length === 0) {
      this.backupStatusText = UserDataBackupService.getEmptyImportStatusText()
      this.backupStatusTone = 'warning'
      return
    }

    this.backupBusy = true
    const result = await UserDataBackupService.importPackage(getContext(this), this.backupPackageText)
    this.backupStatusText = result.statusText
    this.backupStatusTone = this.resolveBackupStatusTone(result.success, result.usedPlanFallback)
    this.backupBusy = false
    if (result.success) {
      await this.reloadReviewData()
    }
  }

  clearBackupPackageText(): void {
    this.backupPackageText = ''
    this.backupStatusText = ''
    this.backupStatusTone = 'info'
    this.backupFlow = 'idle'
  }

  resolveBackupStatusTone(success: boolean, usedPlanFallback: boolean): string {
    if (!success) {
      return 'error'
    }
    if (usedPlanFallback) {
      return 'warning'
    }
    return 'success'
  }

  getBackupStatusColor(): string {
    if (this.backupStatusTone === 'error') {
      return ColorTokens.ERROR
    }
    if (this.backupStatusTone === 'warning') {
      return ColorTokens.WARNING
    }
    if (this.backupStatusTone === 'success') {
      return ColorTokens.SUCCESS
    }
    return ColorTokens.TEXT_SECONDARY
  }

  hasBackupPackageText(): boolean {
    return this.backupPackageText.trim().length > 0
  }

  canImportBackup(): boolean {
    return !this.backupBusy && this.hasBackupPackageText()
  }

  getBackupStatusTitle(): string {
    if (this.backupBusy) {
      if (this.backupFlow === 'import') {
        return '正在导入备份'
      }
      return '正在生成备份'
    }
    if (this.backupStatusText.length > 0) {
      if (this.backupStatusTone === 'success') {
        if (this.backupFlow === 'import') {
          return '备份恢复完成'
        }
        return '备份已生成'
      }
      if (this.backupStatusTone === 'warning') {
        return '请先确认备份内容'
      }
      if (this.backupStatusTone === 'error') {
        return '备份处理失败'
      }
    }
    if (this.hasBackupPackageText()) {
      return '备份内容已就绪'
    }
    return '导出或导入本地数据'
  }

  getBackupStatusDescription(): string {
    if (this.backupBusy) {
      if (this.backupFlow === 'import') {
        return '请保持在当前页面，导入完成后会自动刷新回顾页数据。'
      }
      return '正在整理当前本地数据，完成后可直接复制下方备份包。'
    }
    if (this.backupStatusText.length > 0) {
      return this.backupStatusText
    }
    if (this.hasBackupPackageText()) {
      return '下方输入区已有备份内容，可复制保存，或直接执行导入恢复。'
    }
    return '先生成当前设备上的备份包，或粘贴已有备份 JSON 后执行恢复。'
  }

  getBackupStatusBackgroundColor(): string {
    if (this.backupBusy) {
      return ColorTokens.OVERLAY_PRIMARY
    }
    if (this.backupStatusTone === 'success') {
      return ColorTokens.SUCCESS_BG
    }
    if (this.backupStatusTone === 'warning') {
      return ColorTokens.OVERLAY_ACCENT
    }
    if (this.backupStatusTone === 'error') {
      return ColorTokens.SURFACE_PRIMARY
    }
    if (this.hasBackupPackageText()) {
      return ColorTokens.OVERLAY_PRIMARY
    }
    return ColorTokens.SURFACE_PRIMARY
  }

  getBackupStatusBorderColor(): string {
    if (this.backupBusy) {
      return ColorTokens.PRIMARY
    }
    if (this.backupStatusTone === 'success') {
      return ColorTokens.SUCCESS
    }
    if (this.backupStatusTone === 'warning') {
      return ColorTokens.WARNING
    }
    if (this.backupStatusTone === 'error') {
      return ColorTokens.ERROR
    }
    if (this.hasBackupPackageText()) {
      return ColorTokens.PRIMARY_DISABLED
    }
    return ColorTokens.SURFACE_ELEVATED
  }

  getBackupStatusTagText(): string {
    if (this.backupBusy) {
      return '处理中'
    }
    if (this.backupStatusTone === 'success') {
      return this.backupFlow === 'import' ? '已恢复' : '已生成'
    }
    if (this.backupStatusTone === 'warning') {
      return '待确认'
    }
    if (this.backupStatusTone === 'error') {
      return '失败'
    }
    if (this.hasBackupPackageText()) {
      return '可导入'
    }
    return '未开始'
  }

  getBackupPackageCountText(): string {
    const count: number = this.backupPackageText.trim().length
    if (count <= 0) {
      return '当前输入区为空'
    }
    return '当前已载入 ' + count.toString() + ' 个字符'
  }

  getBackupPackageHelperText(): string {
    if (this.backupBusy) {
      if (this.backupFlow === 'import') {
        return '导入时会按现有备份规则处理数据。'
      }
      return '生成完成后，备份内容会自动写入下方输入区。'
    }
    if (this.hasBackupPackageText()) {
      return '建议先确认内容来源，再执行导入恢复。'
    }
    return '支持两种方式：生成当前备份，或粘贴已有备份包。'
  }

  getBackupImportButtonColor(): string {
    if (this.backupBusy && this.backupFlow === 'import') {
      return ColorTokens.ACCENT
    }
    if (this.canImportBackup()) {
      return ColorTokens.ACCENT
    }
    return ColorTokens.SURFACE_ELEVATED
  }

  getBackupImportButtonTextColor(): string {
    if (this.backupBusy && this.backupFlow === 'import') {
      return ColorTokens.TEXT_ON_PRIMARY
    }
    if (this.canImportBackup()) {
      return ColorTokens.TEXT_ON_PRIMARY
    }
    return ColorTokens.TEXT_SECONDARY
  }

  getBackupInputBorderColor(): string {
    if (this.backupStatusTone === 'error') {
      return ColorTokens.ERROR
    }
    if (this.backupStatusTone === 'warning') {
      return ColorTokens.WARNING
    }
    if (this.hasBackupPackageText()) {
      return ColorTokens.PRIMARY_DISABLED
    }
    return ColorTokens.SURFACE_ELEVATED
  }

  @Builder
  buildBackupGuideItem(title: string, description: string) {
    Column({ space: SpacingTokens.XS }) {
      Text(title)
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(ColorTokens.TEXT_PRIMARY)

      Text(description)
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  getProfileWeightUnitDescription(): string {
    if (this.profileWeightUnit === 'lbs') {
      return '当前重量单位：lbs'
    }
    return '当前重量单位：kg'
  }

  async applyGoalAdjustment(): Promise<void> {
    if (this.applyingAdjustment || !this.canApplyAdjustment || this.currentGoal === undefined) {
      return
    }
    this.applyingAdjustment = true
    this.adjustmentStatusText = ''
    try {
      const result: ReviewPlanRegenerationResult = ReviewDashboardService.createPlanRegenerationResult(
        this.currentGoal,
        this.currentAdjustmentAction,
        Date.now()
      )
      await GoalRepository.saveGoal(getContext(this), result.adjustedGoal)
      this.currentGoal = result.adjustedGoal
      this.adjustmentStatusText = result.statusText
      this.applyAdjustmentAction(
        ReviewDashboardService.createGoalAdjustmentAction(this.createCurrentSummary(), result.adjustedGoal)
      )
      this.currentNow = Date.now()
      this.refreshAdjustmentPreview()
    } catch (e) {
      this.adjustmentStatusText = '保存调整失败，请稍后重试'
    }
    this.applyingAdjustment = false
  }

  createCurrentSummary(): ReviewDashboardSummary {
    const summary: ReviewDashboardSummary = {
      hasSessions: this.hasSessions,
      sessionCount: this.sessionCount,
      totalCompletedSets: this.totalCompletedSets,
      totalTargetSets: this.totalTargetSets,
      averageCompletionRate: this.averageCompletionRate,
      totalDurationSeconds: 0,
      totalDurationText: this.totalDurationText,
      latestSessionId: this.latestSessionId,
      latestDayId: this.latestDayId,
      adjustmentHint: this.currentAdjustmentAction.actionType,
      adjustmentText: this.adjustmentText,
      recentRecords: this.filteredRecentRecords,
      trendSummary: this.trendSummary
    }
    return summary
  }

  getCompletionText(): string {
    return this.averageCompletionRate.toString() + '%'
  }

  getProgressWidth(): string {
    if (this.averageCompletionRate <= 0) {
      return '1%'
    }
    if (this.averageCompletionRate > 100) {
      return '100%'
    }
    return this.averageCompletionRate.toString() + '%'
  }

  getHeatmapDayColor(day: CalendarHeatmapDay): string {
    if (!day.isCurrentMonth) {
      return ColorTokens.BG_SECONDARY
    }
    if (day.level <= 0) {
      return ColorTokens.SURFACE_ELEVATED
    }
    if (day.level === 1) {
      return ColorTokens.OVERLAY_PRIMARY
    }
    if (day.level === 2) {
      return ColorTokens.PRIMARY_DISABLED
    }
    if (day.level === 3) {
      return ColorTokens.PRIMARY
    }
    return ColorTokens.ACCENT_LIGHT
  }

  getHeatmapTextColor(day: CalendarHeatmapDay): string {
    if (!day.isCurrentMonth) {
      return ColorTokens.TEXT_DISABLED
    }
    if (day.level >= 2) {
      return ColorTokens.TEXT_ON_PRIMARY
    }
    return ColorTokens.TEXT_SECONDARY
  }

  getSelectedFilterDescription(): string {
    for (let index = 0; index < this.recentFilterOptions.length; index++) {
      const option: ReviewRecentSessionFilterOption = this.recentFilterOptions[index]
      if (option.filterId === this.selectedRecentFilterId) {
        return option.description + ' · ' + option.matchedSessionCount.toString() + ' 次训练'
      }
    }
    return '筛选最近训练记录'
  }

  copyHeatmapRows(source: CalendarHeatmapRow[]): CalendarHeatmapRow[] {
    const rows: CalendarHeatmapRow[] = []
    for (let rowIndex = 0; rowIndex < source.length; rowIndex++) {
      const sourceRow: CalendarHeatmapRow = source[rowIndex]
      const days: CalendarHeatmapDay[] = []
      for (let dayIndex = 0; dayIndex < sourceRow.days.length; dayIndex++) {
        const sourceDay: CalendarHeatmapDay = sourceRow.days[dayIndex]
        const day: CalendarHeatmapDay = {
          dateText: sourceDay.dateText,
          dayOfMonth: sourceDay.dayOfMonth,
          isCurrentMonth: sourceDay.isCurrentMonth,
          sessionCount: sourceDay.sessionCount,
          totalVolume: sourceDay.totalVolume,
          level: sourceDay.level,
          accessibilityText: sourceDay.accessibilityText
        }
        days.push(day)
      }
      rows.push({ rowId: sourceRow.rowId, days: days })
    }
    return rows
  }

  copyRecentFilterOptions(source: ReviewRecentSessionFilterOption[]): ReviewRecentSessionFilterOption[] {
    const options: ReviewRecentSessionFilterOption[] = []
    for (let index = 0; index < source.length; index++) {
      const option: ReviewRecentSessionFilterOption = source[index]
      options.push({
        filterId: option.filterId,
        label: option.label,
        description: option.description,
        matchedSessionCount: option.matchedSessionCount,
        locked: option.locked
      })
    }
    return options
  }

  copyRecentRecords(source: ReviewRecentSessionRecord[]): ReviewRecentSessionRecord[] {
    const records: ReviewRecentSessionRecord[] = []
    for (let index = 0; index < source.length; index++) {
      const record: ReviewRecentSessionRecord = source[index]
      records.push({
        sessionId: record.sessionId,
        dayId: record.dayId,
        dateText: record.dateText,
        durationText: record.durationText,
        completedSets: record.completedSets,
        targetSets: record.targetSets,
        completionRate: record.completionRate,
        completionText: record.completionText,
        totalVolume: record.totalVolume,
        volumeText: record.volumeText
      })
    }
    return records
  }

  copyWeeklyTrends(source: ReviewWeeklyTrendItem[]): ReviewWeeklyTrendItem[] {
    const items: ReviewWeeklyTrendItem[] = []
    for (let index = 0; index < source.length; index++) {
      items.push(this.copyWeeklyTrend(source[index]))
    }
    return items
  }

  copyWeeklyTrend(source: ReviewWeeklyTrendItem): ReviewWeeklyTrendItem {
    const item: ReviewWeeklyTrendItem = {
      weekId: source.weekId,
      weekLabel: source.weekLabel,
      dateRangeText: source.dateRangeText,
      sessionCount: source.sessionCount,
      totalDurationSeconds: source.totalDurationSeconds,
      totalDurationText: source.totalDurationText,
      totalVolume: source.totalVolume,
      completionRate: source.completionRate,
      completionText: source.completionText,
      averageSessionText: source.averageSessionText,
      dominantDayId: source.dominantDayId,
      summaryText: source.summaryText
    }
    return item
  }

  copyRecordDetails(source: ExercisePersonalRecordDetail[]): ExercisePersonalRecordDetail[] {
    const details: ExercisePersonalRecordDetail[] = []
    for (let index = 0; index < source.length; index++) {
      details.push(this.copyRecordDetail(source[index]))
    }
    return details
  }

  copyRecordDetail(source: ExercisePersonalRecordDetail): ExercisePersonalRecordDetail {
    const detail: ExercisePersonalRecordDetail = {
      exerciseId: source.exerciseId,
      exerciseName: source.exerciseName,
      bestOneRepMax: source.bestOneRepMax,
      bestWeight: source.bestWeight,
      bestReps: source.bestReps,
      bestDateText: source.bestDateText,
      lastPerformedAt: source.lastPerformedAt,
      lastPerformedDateText: source.lastPerformedDateText,
      sessionCount: source.sessionCount,
      performedSetCount: source.performedSetCount,
      recentOneRepMax: source.recentOneRepMax,
      recentWeight: source.recentWeight,
      recentReps: source.recentReps,
      recentVolume: source.recentVolume,
      trendText: source.trendText
    }
    return detail
  }

  copyStringArray(source: string[]): string[] {
    const values: string[] = []
    for (let index = 0; index < source.length; index++) {
      values.push(source[index])
    }
    return values
  }

  getReviewSubtitle(): string {
    if (this.loading) {
      return '正在整理最近训练、周趋势和动作纪录'
    }
    if (!this.hasSessions) {
      return '先完成一次训练，回顾页会开始生成你的训练节奏与趋势信号'
    }
    return '把最近训练、周趋势和动作 PR 放在同一块面板里看'
  }

  getCompletionStatusText(): string {
    if (this.averageCompletionRate >= 90) {
      return '执行稳定'
    }
    if (this.averageCompletionRate >= 70) {
      return '节奏在线'
    }
    return '还有提升空间'
  }

  getCompletionStatusColor(): string {
    if (this.averageCompletionRate >= 90) {
      return ColorTokens.SUCCESS
    }
    if (this.averageCompletionRate >= 70) {
      return ColorTokens.PRIMARY
    }
    return ColorTokens.WARNING
  }

  getCompletionStatusBackgroundColor(): string {
    if (this.averageCompletionRate >= 90) {
      return ColorTokens.OVERLAY_SUCCESS
    }
    if (this.averageCompletionRate >= 70) {
      return ColorTokens.OVERLAY_PRIMARY
    }
    return ColorTokens.OVERLAY_ACCENT
  }

  @Builder
  buildMetric(label: string, value: string) {
    Column({ space: SpacingTokens.XS }) {
      Text(value)
        .fontSize(FontTokens.TITLE_SIZE)
        .fontWeight(FontWeight.Bold)
        .fontColor(ColorTokens.TEXT_PRIMARY)
        .textAlign(TextAlign.Start)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(label)
        .fontSize(FontTokens.MICRO_SIZE)
        .fontWeight(FontTokens.MICRO_WEIGHT)
        .fontColor(ColorTokens.TEXT_TERTIARY)
        .textAlign(TextAlign.Start)
    }
    .layoutWeight(1)
    .padding(SpacingTokens.MD)
    .borderRadius(RadiusTokens.MD)
    .backgroundColor(ColorTokens.SURFACE_SECONDARY)
    .border({ width: 1, color: ColorTokens.BORDER_SUBTLE })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildSectionTitle(title: string, description: string) {
    Column({ space: SpacingTokens.XS }) {
      Text(title)
        .fontSize(FontTokens.TITLE_SIZE)
        .fontWeight(FontTokens.TITLE_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)

      Text(description)
        .fontSize(FontTokens.SMALL_SIZE)
        .fontColor(ColorTokens.TEXT_TERTIARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildFilterButton(label: string, selected: boolean, countText: string, locked: boolean, onTap: () => void) {
    Button(label + ' · ' + countText)
      .height(TouchTokens.BUTTON_HEIGHT_SMALL)
      .fontSize(FontTokens.CAPTION_SIZE)
      .fontColor(selected ? ColorTokens.TEXT_ON_PRIMARY : (locked ? ColorTokens.WARNING : ColorTokens.TEXT_PRIMARY))
      .backgroundColor(selected ? ColorTokens.PRIMARY : (locked ? ColorTokens.WARNING_BG : ColorTokens.SURFACE_SECONDARY))
      .borderRadius(RadiusTokens.MD)
      .border({
        width: 1,
        color: selected ? ColorTokens.PRIMARY : (locked ? ColorTokens.WARNING : ColorTokens.BORDER_SUBTLE)
      })
      .padding({ left: SpacingTokens.SM, right: SpacingTokens.SM })
      .margin({ right: SpacingTokens.SM, bottom: SpacingTokens.SM })
      .onClick(onTap)
  }

  @Builder
  buildWeeklyStats() {
    AppCard({ variant: 'outlined', cardPadding: 'default' }) {
      Column({ space: SpacingTokens.MD }) {
        Row() {
          this.buildSectionTitle('本周训练统计', this.weeklyDateRangeText)

          Text(this.weeklySessionCount.toString() + ' 次')
            .fontSize(FontTokens.SMALL_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(ColorTokens.PRIMARY)
            .padding({
              top: SpacingTokens.XS,
              bottom: SpacingTokens.XS,
              left: SpacingTokens.SM,
              right: SpacingTokens.SM
            })
            .backgroundColor(ColorTokens.OVERLAY_PRIMARY)
            .borderRadius(RadiusTokens.FULL)
        }
        .width('100%')

        Row({ space: SpacingTokens.SM }) {
          this.buildMetric('本周时长', this.weeklyDurationText)
          this.buildMetric('本周组数', this.weeklyTotalSets.toString())
        }
        .width('100%')

        Row({ space: SpacingTokens.SM }) {
          this.buildMetric('本周训练量', this.weeklyTotalVolume.toString() + ' kg')
          this.buildMetric('训练天数', this.weeklySessionCount.toString())
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildHeatmapDay(day: CalendarHeatmapDay) {
    Text(day.dayOfMonth.toString())
      .fontSize(FontTokens.SMALL_SIZE)
      .fontColor(this.getHeatmapTextColor(day))
      .textAlign(TextAlign.Center)
      .width(TouchTokens.CALENDAR_CELL)
      .height(TouchTokens.CALENDAR_CELL)
      .backgroundColor(this.getHeatmapDayColor(day))
      .borderRadius(RadiusTokens.XS)
  }

  @Builder
  buildCalendarHeatmap() {
    AppCard({ variant: 'outlined', cardPadding: 'default' }) {
      Column({ space: SpacingTokens.SM }) {
        Row() {
          this.buildSectionTitle('训练日历热力图', '颜色越亮，代表当天训练量越高')

          Text(this.heatmapMonthTitle)
            .fontSize(FontTokens.SMALL_SIZE)
            .fontColor(ColorTokens.TEXT_TERTIARY)
        }
        .width('100%')

        Column({ space: SpacingTokens.XS }) {
          Row({ space: SpacingTokens.XS }) {
            Text('一').fontSize(FontTokens.SMALL_SIZE).fontColor(ColorTokens.TEXT_TERTIARY).width(TouchTokens.CALENDAR_CELL).textAlign(TextAlign.Center)
            Text('二').fontSize(FontTokens.SMALL_SIZE).fontColor(ColorTokens.TEXT_TERTIARY).width(TouchTokens.CALENDAR_CELL).textAlign(TextAlign.Center)
            Text('三').fontSize(FontTokens.SMALL_SIZE).fontColor(ColorTokens.TEXT_TERTIARY).width(TouchTokens.CALENDAR_CELL).textAlign(TextAlign.Center)
            Text('四').fontSize(FontTokens.SMALL_SIZE).fontColor(ColorTokens.TEXT_TERTIARY).width(TouchTokens.CALENDAR_CELL).textAlign(TextAlign.Center)
            Text('五').fontSize(FontTokens.SMALL_SIZE).fontColor(ColorTokens.TEXT_TERTIARY).width(TouchTokens.CALENDAR_CELL).textAlign(TextAlign.Center)
            Text('六').fontSize(FontTokens.SMALL_SIZE).fontColor(ColorTokens.TEXT_TERTIARY).width(TouchTokens.CALENDAR_CELL).textAlign(TextAlign.Center)
            Text('日').fontSize(FontTokens.SMALL_SIZE).fontColor(ColorTokens.TEXT_TERTIARY).width(TouchTokens.CALENDAR_CELL).textAlign(TextAlign.Center)
          }
          .width('100%')

          ForEach(this.heatmapRows, (row: CalendarHeatmapRow) => {
            Row({ space: SpacingTokens.XS }) {
              ForEach(row.days, (day: CalendarHeatmapDay) => {
                this.buildHeatmapDay(day)
              }, (day: CalendarHeatmapDay) => day.dateText)
            }
            .width('100%')
          }, (row: CalendarHeatmapRow) => row.rowId)
        }
        .width('100%')
        .padding(SpacingTokens.SM)
        .backgroundColor(ColorTokens.SURFACE_PRIMARY)
        .borderRadius(RadiusTokens.MD)
        .border({ width: 1, color: ColorTokens.BORDER_SUBTLE })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildRecentRecord(record: ReviewRecentSessionRecord) {
    AppCard({ variant: 'outlined', cardPadding: 'compact' }) {
      Column({ space: SpacingTokens.SM }) {
        Row() {
          Column({ space: SpacingTokens.XS }) {
            Text(record.dayId)
              .fontSize(FontTokens.BODY_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text(record.dateText + ' · ' + record.durationText)
              .fontSize(FontTokens.CAPTION_SIZE)
              .fontColor(ColorTokens.TEXT_TERTIARY)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text(record.completionRate.toString() + '%')
            .fontSize(FontTokens.TITLE_SIZE)
            .fontWeight(FontTokens.TITLE_WEIGHT)
            .fontColor(ColorTokens.PRIMARY)
        }
        .width('100%')

        Row() {
          Text(record.completionText)
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
            .layoutWeight(1)

          Text(record.volumeText)
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.ACCENT_LIGHT)
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildRecentTrainingSection() {
    Column({ space: SpacingTokens.SM }) {
      this.buildSectionTitle('最近训练筛选', this.getSelectedFilterDescription())

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.recentFilterOptions, (option: ReviewRecentSessionFilterOption) => {
          this.buildFilterButton(
            option.label,
            option.filterId === this.selectedRecentFilterId,
            option.locked ? 'Pro' : option.matchedSessionCount.toString(),
            option.locked,
            () => {
              this.selectRecentFilter(option.filterId)
            }
          )
        }, (option: ReviewRecentSessionFilterOption) => option.filterId)
      }
      .width('100%')

      if (this.historyUpgradeHintText.length > 0) {
        Text(this.historyUpgradeHintText)
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(ColorTokens.WARNING)
          .width('100%')
      }

      if (this.filteredRecentRecords.length === 0) {
        Text('当前筛选条件下还没有训练记录。')
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .width('100%')
          .padding(SpacingTokens.MD)
          .borderRadius(RadiusTokens.SM)
          .backgroundColor(ColorTokens.SURFACE_PRIMARY)
      }

      ForEach(this.filteredRecentRecords, (record: ReviewRecentSessionRecord) => {
        this.buildRecentRecord(record)
      }, (record: ReviewRecentSessionRecord) => record.sessionId)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildTrendSummary() {
    AppCard({ variant: 'outlined', cardPadding: 'default' }) {
      Column({ space: SpacingTokens.SM }) {
        this.buildSectionTitle('历史训练趋势', this.trendSummary.summaryText)

        Row({ space: SpacingTokens.SM }) {
          this.buildMetric('训练量趋势', this.trendSummary.volumeTrendText)
          this.buildMetric('完成率趋势', this.trendSummary.completionTrendText)
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  getAdvancedInsightsStatusColor(): string {
    if (this.advancedInsightsEntry.locked) {
      return ColorTokens.WARNING
    }
    return ColorTokens.SUCCESS
  }

  getAdvancedInsightsStatusBackgroundColor(): string {
    if (this.advancedInsightsEntry.locked) {
      return ColorTokens.WARNING_BG
    }
    return ColorTokens.SUCCESS_BG
  }

  getAdvancedInsightsPanelStatusColor(): string {
    if (this.advancedInsightsPanel.locked) {
      return ColorTokens.WARNING
    }
    if (this.advancedInsightsActiveTier === 'plus') {
      return ColorTokens.ACCENT
    }
    return ColorTokens.SUCCESS
  }

  getAdvancedInsightsPanelStatusBackgroundColor(): string {
    if (this.advancedInsightsPanel.locked) {
      return ColorTokens.WARNING_BG
    }
    if (this.advancedInsightsActiveTier === 'plus') {
      return ColorTokens.OVERLAY_ACCENT
    }
    return ColorTokens.SUCCESS_BG
  }

  @Builder
  buildAdvancedInsightsEntrySection() {
    AppCard({ variant: 'panel', cardPadding: 'default' }) {
      Column({ space: SpacingTokens.MD }) {
        Row() {
          Column({ space: SpacingTokens.XS }) {
            Text('高级洞察入口')
              .fontSize(FontTokens.MICRO_SIZE)
              .fontWeight(FontTokens.MICRO_WEIGHT)
              .fontColor(ColorTokens.TEXT_TERTIARY)

            Text(this.advancedInsightsEntry.title)
              .fontSize(FontTokens.TITLE_SIZE)
              .fontWeight(FontTokens.TITLE_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text(this.advancedInsightsEntry.statusLabel)
            .fontSize(FontTokens.SMALL_SIZE)
            .fontColor(this.getAdvancedInsightsStatusColor())
            .padding({
              top: SpacingTokens.XS,
              bottom: SpacingTokens.XS,
              left: SpacingTokens.SM,
              right: SpacingTokens.SM
            })
            .backgroundColor(this.getAdvancedInsightsStatusBackgroundColor())
            .borderRadius(RadiusTokens.FULL)
        }
        .width('100%')

        Text(this.advancedInsightsEntry.description)
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .width('100%')

        Column({ space: SpacingTokens.XS }) {
          ForEach(this.advancedInsightsEntry.featureBullets, (item: string) => {
            Text('- ' + item)
              .fontSize(FontTokens.CAPTION_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
              .width('100%')
          }, (item: string) => item)
        }
        .width('100%')
        .padding(SpacingTokens.MD)
        .borderRadius(RadiusTokens.SM)
        .backgroundColor(ColorTokens.SURFACE_PRIMARY)
        .alignItems(HorizontalAlign.Start)

        AppButton({
          text: this.advancedInsightsEntry.actionText,
          type: this.advancedInsightsEntry.locked ? 'primary' : 'secondary',
          buttonSize: 'medium',
          block: true,
          onButtonClick: () => {
            this.openMonetizationHub('advanced_insights', '训练回顾')
          }
        })

        Text(this.advancedInsightsEntry.supportingText)
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(ColorTokens.TEXT_TERTIARY)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildAdvancedInsightsPreviewTile(tile: ReviewAdvancedInsightsPreviewTile) {
    Column({ space: SpacingTokens.XS }) {
      Text(tile.label)
        .fontSize(FontTokens.MICRO_SIZE)
        .fontWeight(FontTokens.MICRO_WEIGHT)
        .fontColor(ColorTokens.TEXT_TERTIARY)

      Text(tile.value)
        .fontSize(FontTokens.BODY_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(ColorTokens.TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(tile.note)
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .width('100%')
    }
    .width('100%')
    .padding(SpacingTokens.MD)
    .borderRadius(RadiusTokens.MD)
    .backgroundColor(ColorTokens.SURFACE_PRIMARY)
    .border({ width: 1, color: ColorTokens.BORDER_SUBTLE })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildAdvancedInsightsPanelSection() {
    if (this.advancedInsightsPanel.locked) {
      AppCard({ variant: 'outlined', cardPadding: 'default' }) {
        Column({ space: SpacingTokens.SM }) {
          Row() {
            Column({ space: SpacingTokens.XS }) {
              Text('高级洞察面板')
                .fontSize(FontTokens.MICRO_SIZE)
                .fontWeight(FontTokens.MICRO_WEIGHT)
                .fontColor(ColorTokens.TEXT_TERTIARY)

              Text(this.advancedInsightsPanel.title)
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontTokens.TITLE_WEIGHT)
                .fontColor(ColorTokens.TEXT_PRIMARY)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Text(this.advancedInsightsPanel.statusLabel)
              .fontSize(FontTokens.SMALL_SIZE)
              .fontColor(this.getAdvancedInsightsPanelStatusColor())
              .padding({
                top: SpacingTokens.XS,
                bottom: SpacingTokens.XS,
                left: SpacingTokens.SM,
                right: SpacingTokens.SM
              })
              .backgroundColor(this.getAdvancedInsightsPanelStatusBackgroundColor())
              .borderRadius(RadiusTokens.FULL)
          }
          .width('100%')

          Text(this.advancedInsightsPanel.description)
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
            .width('100%')

          ForEach(this.advancedInsightsPanel.tiles, (tile: ReviewAdvancedInsightsPreviewTile) => {
            this.buildAdvancedInsightsPreviewTile(tile)
          }, (tile: ReviewAdvancedInsightsPreviewTile) => tile.tileId)

          AppButton({
            text: this.advancedInsightsPanel.actionText,
            type: 'primary',
            buttonSize: 'medium',
            block: true,
            onButtonClick: () => {
              this.openMonetizationHub('advanced_insights', '训练回顾')
            }
          })

          Text(this.advancedInsightsPanel.supportingText)
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.TEXT_TERTIARY)
            .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    } else {
      Column({ space: SpacingTokens.SM }) {
        AppCard({ variant: 'panel', cardPadding: 'default' }) {
          Column({ space: SpacingTokens.SM }) {
            Row() {
              Column({ space: SpacingTokens.XS }) {
                Text('高级洞察面板')
                  .fontSize(FontTokens.MICRO_SIZE)
                  .fontWeight(FontTokens.MICRO_WEIGHT)
                  .fontColor(ColorTokens.TEXT_TERTIARY)

                Text(this.advancedInsightsPanel.title)
                  .fontSize(FontTokens.TITLE_SIZE)
                  .fontWeight(FontTokens.TITLE_WEIGHT)
                  .fontColor(ColorTokens.TEXT_PRIMARY)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Text(this.advancedInsightsPanel.statusLabel)
                .fontSize(FontTokens.SMALL_SIZE)
                .fontColor(this.getAdvancedInsightsPanelStatusColor())
                .padding({
                  top: SpacingTokens.XS,
                  bottom: SpacingTokens.XS,
                  left: SpacingTokens.SM,
                  right: SpacingTokens.SM
                })
                .backgroundColor(this.getAdvancedInsightsPanelStatusBackgroundColor())
                .borderRadius(RadiusTokens.FULL)
            }
            .width('100%')

            Text(this.advancedInsightsPanel.description)
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
              .width('100%')

            ForEach(this.advancedInsightsPanel.tiles, (tile: ReviewAdvancedInsightsPreviewTile) => {
              this.buildAdvancedInsightsPreviewTile(tile)
            }, (tile: ReviewAdvancedInsightsPreviewTile) => tile.tileId)

            AppButton({
              text: this.advancedInsightsPanel.actionText,
              type: 'secondary',
              buttonSize: 'medium',
              block: true,
              onButtonClick: () => {
                this.openMonetizationHub('advanced_insights', '训练回顾')
              }
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        this.buildWeeklyTrendSectionLab()
        this.buildRecordDetailSectionLab()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildWeeklyTrendCard(item: ReviewWeeklyTrendItem) {
    Column({ space: SpacingTokens.SM }) {
      Row() {
        Column({ space: SpacingTokens.XS }) {
          Text(item.weekLabel)
            .fontSize(FontTokens.BODY_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(ColorTokens.TEXT_PRIMARY)

          Text(item.dateRangeText)
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(item.sessionCount.toString() + ' 次')
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(ColorTokens.PRIMARY)
      }
      .width('100%')

      Row({ space: SpacingTokens.SM }) {
        this.buildMetric('训练量', item.totalVolume.toString() + ' kg')
        this.buildMetric('完成率', item.completionRate.toString() + '%')
      }
      .width('100%')

      Text(item.summaryText)
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
    }
    .width('100%')
    .padding(SpacingTokens.MD)
    .borderRadius(RadiusTokens.SM)
    .backgroundColor(this.selectedWeekId === item.weekId ? ColorTokens.SURFACE_SECONDARY : ColorTokens.SURFACE_PRIMARY)
    .border({
      width: 1,
      color: this.selectedWeekId === item.weekId ? ColorTokens.PRIMARY : ColorTokens.SURFACE_PRIMARY
    })
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.selectWeekTrend(item.weekId)
    })
  }

  @Builder
  buildWeeklyTrendSection() {
    Column({ space: SpacingTokens.SM }) {
      this.buildSectionTitle('按周趋势查看', '最近 6 周训练节奏与完成情况')

      if (this.weeklyTrends.length === 0) {
        Text('完成训练后，这里会开始累积周趋势。')
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .width('100%')
          .padding(SpacingTokens.MD)
          .borderRadius(RadiusTokens.SM)
          .backgroundColor(ColorTokens.SURFACE_PRIMARY)
      }

      ForEach(this.weeklyTrends, (item: ReviewWeeklyTrendItem) => {
        this.buildWeeklyTrendCard(item)
      }, (item: ReviewWeeklyTrendItem) => item.weekId)

      if (this.selectedWeekTrend.weekId.length > 0) {
        Column({ space: SpacingTokens.SM }) {
          Text('本周明细')
            .fontSize(FontTokens.BODY_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(ColorTokens.TEXT_PRIMARY)

          Row({ space: SpacingTokens.SM }) {
            this.buildMetric('总时长', this.selectedWeekTrend.totalDurationText)
            this.buildMetric('平均单次', this.selectedWeekTrend.averageSessionText)
          }
          .width('100%')

          Row({ space: SpacingTokens.SM }) {
            this.buildMetric('完成组数', this.selectedWeekTrend.completionText)
            this.buildMetric(
              '训练重点日',
              this.selectedWeekTrend.dominantDayId.length > 0 ? this.selectedWeekTrend.dominantDayId : '暂无'
            )
          }
          .width('100%')
        }
        .width('100%')
        .padding(SpacingTokens.MD)
        .borderRadius(RadiusTokens.SM)
        .backgroundColor(ColorTokens.BG_SECONDARY)
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildRecordDetailSection() {
    Column({ space: SpacingTokens.SM }) {
      this.buildSectionTitle('按动作查看个人纪录', '切换动作查看 PR、最近表现与训练频率')

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.recordDetails, (detail: ExercisePersonalRecordDetail) => {
          this.buildFilterButton(
            detail.exerciseName,
            detail.exerciseId === this.selectedExerciseId,
            detail.bestOneRepMax.toString() + 'kg',
            false,
            () => {
              this.selectExerciseRecord(detail.exerciseId)
            }
          )
        }, (detail: ExercisePersonalRecordDetail) => detail.exerciseId)
      }
      .width('100%')

      if (this.recordDetails.length === 0) {
        Text('完成正式组训练后，这里会显示动作个人纪录。')
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .width('100%')
          .padding(SpacingTokens.MD)
          .borderRadius(RadiusTokens.SM)
          .backgroundColor(ColorTokens.SURFACE_PRIMARY)
      }

      if (this.recordDetails.length > 0) {
        Column({ space: SpacingTokens.SM }) {
          Row() {
            Column({ space: SpacingTokens.XS }) {
              Text(this.selectedRecordDetail.exerciseName)
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontTokens.TITLE_WEIGHT)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Text('PR 记录于 ' + this.selectedRecordDetail.bestDateText)
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Text(this.selectedRecordDetail.bestOneRepMax.toString() + ' kg')
              .fontSize(FontTokens.HEADLINE_SIZE)
              .fontWeight(FontTokens.HEADLINE_WEIGHT)
              .fontColor(ColorTokens.PRIMARY)
          }
          .width('100%')

          Row({ space: SpacingTokens.SM }) {
            this.buildMetric('最佳重量', this.selectedRecordDetail.bestWeight.toString() + ' kg')
            this.buildMetric('最佳次数', this.selectedRecordDetail.bestReps.toString())
          }
          .width('100%')

          Row({ space: SpacingTokens.SM }) {
            this.buildMetric('训练次数', this.selectedRecordDetail.sessionCount.toString())
            this.buildMetric('累计正式组', this.selectedRecordDetail.performedSetCount.toString())
          }
          .width('100%')

          Row({ space: SpacingTokens.SM }) {
            this.buildMetric('最近 1RM', this.selectedRecordDetail.recentOneRepMax.toString() + ' kg')
            this.buildMetric('最近训练量', this.selectedRecordDetail.recentVolume.toString() + ' kg')
          }
          .width('100%')

          Text('最近训练：' + this.selectedRecordDetail.lastPerformedDateText + ' · ' +
            this.selectedRecordDetail.recentWeight.toString() + ' kg × ' +
            this.selectedRecordDetail.recentReps.toString())
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)

          Text(this.selectedRecordDetail.trendText)
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)

          Button('查看动作详情')
            .width('100%')
            .height(TouchTokens.BUTTON_HEIGHT_DEFAULT)
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_ON_PRIMARY)
            .backgroundColor(ColorTokens.PRIMARY)
            .borderRadius(RadiusTokens.FULL)
            .onClick(() => {
              this.openExerciseDetail()
            })
        }
        .width('100%')
        .padding(SpacingTokens.MD)
        .borderRadius(RadiusTokens.SM)
        .backgroundColor(ColorTokens.SURFACE_PRIMARY)
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildWeeklyTrendCardLab(item: ReviewWeeklyTrendItem) {
    Column() {
      AppCard({
        variant: this.selectedWeekId === item.weekId ? 'panel' : 'outlined',
        cardPadding: 'compact'
      }) {
        Column({ space: SpacingTokens.SM }) {
          Row() {
            Column({ space: SpacingTokens.XS }) {
              Text(item.weekLabel)
                .fontSize(FontTokens.BODY_SIZE)
                .fontWeight(FontWeight.Medium)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Text(item.dateRangeText)
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_TERTIARY)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Text(item.sessionCount.toString() + ' 次')
              .fontSize(FontTokens.SMALL_SIZE)
              .fontColor(ColorTokens.PRIMARY)
              .padding({
                top: SpacingTokens.XS,
                bottom: SpacingTokens.XS,
                left: SpacingTokens.SM,
                right: SpacingTokens.SM
              })
              .backgroundColor(ColorTokens.OVERLAY_PRIMARY)
              .borderRadius(RadiusTokens.FULL)
          }
          .width('100%')

          Row({ space: SpacingTokens.SM }) {
            this.buildMetric('训练量', item.totalVolume.toString() + ' kg')
            this.buildMetric('完成率', item.completionRate.toString() + '%')
          }
          .width('100%')

          Text(item.summaryText)
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .onClick(() => {
      this.selectWeekTrend(item.weekId)
    })
  }

  @Builder
  buildWeeklyTrendSectionLab() {
    AppCard({ variant: 'outlined', cardPadding: 'default' }) {
      Column({ space: SpacingTokens.SM }) {
        this.buildSectionTitle('按周趋势查看', '最近 6 周训练节奏与完成情况')

        if (this.weeklyTrends.length === 0) {
          Column() {
            Text('完成训练后，这里会开始积累周趋势。')
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
          }
          .width('100%')
          .padding(SpacingTokens.MD)
          .backgroundColor(ColorTokens.SURFACE_PRIMARY)
          .borderRadius(RadiusTokens.MD)
          .border({ width: 1, color: ColorTokens.BORDER_SUBTLE })
          .alignItems(HorizontalAlign.Start)
        }

        ForEach(this.weeklyTrends, (item: ReviewWeeklyTrendItem) => {
          this.buildWeeklyTrendCardLab(item)
        }, (item: ReviewWeeklyTrendItem) => item.weekId)

        if (this.selectedWeekTrend.weekId.length > 0) {
          AppCard({ variant: 'panel', cardPadding: 'compact' }) {
            Column({ space: SpacingTokens.SM }) {
              Text('本周明细')
                .fontSize(FontTokens.BODY_SIZE)
                .fontWeight(FontWeight.Medium)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Row({ space: SpacingTokens.SM }) {
                this.buildMetric('总时长', this.selectedWeekTrend.totalDurationText)
                this.buildMetric('平均单次', this.selectedWeekTrend.averageSessionText)
              }
              .width('100%')

              Row({ space: SpacingTokens.SM }) {
                this.buildMetric('完成组数', this.selectedWeekTrend.completionText)
                this.buildMetric(
                  '训练重点日',
                  this.selectedWeekTrend.dominantDayId.length > 0 ? this.selectedWeekTrend.dominantDayId : '暂无'
                )
              }
              .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildRecordDetailSectionLab() {
    AppCard({ variant: 'outlined', cardPadding: 'default' }) {
      Column({ space: SpacingTokens.SM }) {
        this.buildSectionTitle('按动作查看个人纪录', '切换动作查看 PR、最近表现与训练频率')

        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.recordDetails, (detail: ExercisePersonalRecordDetail) => {
            this.buildFilterButton(
              detail.exerciseName,
              detail.exerciseId === this.selectedExerciseId,
              detail.bestOneRepMax.toString() + 'kg',
              false,
              () => {
                this.selectExerciseRecord(detail.exerciseId)
              }
            )
          }, (detail: ExercisePersonalRecordDetail) => detail.exerciseId)
        }
        .width('100%')

        if (this.recordDetails.length === 0) {
          Column() {
            Text('完成正式组训练后，这里会显示动作个人纪录。')
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
          }
          .width('100%')
          .padding(SpacingTokens.MD)
          .backgroundColor(ColorTokens.SURFACE_PRIMARY)
          .borderRadius(RadiusTokens.MD)
          .border({ width: 1, color: ColorTokens.BORDER_SUBTLE })
          .alignItems(HorizontalAlign.Start)
        }

        if (this.recordDetails.length > 0) {
          AppCard({ variant: 'panel', cardPadding: 'default' }) {
            Column({ space: SpacingTokens.SM }) {
              Row() {
                Column({ space: SpacingTokens.XS }) {
                  Text(this.selectedRecordDetail.exerciseName)
                    .fontSize(FontTokens.TITLE_SIZE)
                    .fontWeight(FontTokens.TITLE_WEIGHT)
                    .fontColor(ColorTokens.TEXT_PRIMARY)

                  Text('PR 记录于 ' + this.selectedRecordDetail.bestDateText)
                    .fontSize(FontTokens.CAPTION_SIZE)
                    .fontColor(ColorTokens.TEXT_TERTIARY)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Text(this.selectedRecordDetail.bestOneRepMax.toString() + ' kg')
                  .fontSize(FontTokens.HEADLINE_SIZE)
                  .fontWeight(FontTokens.HEADLINE_WEIGHT)
                  .fontColor(ColorTokens.PRIMARY)
              }
              .width('100%')

              Row({ space: SpacingTokens.SM }) {
                this.buildMetric('最佳重量', this.selectedRecordDetail.bestWeight.toString() + ' kg')
                this.buildMetric('最佳次数', this.selectedRecordDetail.bestReps.toString())
              }
              .width('100%')

              Row({ space: SpacingTokens.SM }) {
                this.buildMetric('训练次数', this.selectedRecordDetail.sessionCount.toString())
                this.buildMetric('累计正式组', this.selectedRecordDetail.performedSetCount.toString())
              }
              .width('100%')

              Row({ space: SpacingTokens.SM }) {
                this.buildMetric('最近 1RM', this.selectedRecordDetail.recentOneRepMax.toString() + ' kg')
                this.buildMetric('最近训练量', this.selectedRecordDetail.recentVolume.toString() + ' kg')
              }
              .width('100%')

              Column({ space: SpacingTokens.XS }) {
                Text('最近训练')
                  .fontSize(FontTokens.MICRO_SIZE)
                  .fontWeight(FontTokens.MICRO_WEIGHT)
                  .fontColor(ColorTokens.TEXT_TERTIARY)

                Text(this.selectedRecordDetail.lastPerformedDateText + ' · ' +
                  this.selectedRecordDetail.recentWeight.toString() + ' kg × ' +
                  this.selectedRecordDetail.recentReps.toString())
                  .fontSize(FontTokens.CAPTION_SIZE)
                  .fontColor(ColorTokens.TEXT_SECONDARY)
              }
              .width('100%')
              .padding(SpacingTokens.MD)
              .backgroundColor(ColorTokens.SURFACE_SECONDARY)
              .borderRadius(RadiusTokens.MD)
              .border({ width: 1, color: ColorTokens.BORDER_SUBTLE })
              .alignItems(HorizontalAlign.Start)

              Text(this.selectedRecordDetail.trendText)
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)

              AppButton({
                text: '查看动作详情',
                type: 'primary',
                buttonSize: 'medium',
                block: true,
                onButtonClick: () => {
                  this.openExerciseDetail()
                }
              })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildAdjustmentPreviewSection() {
    if (this.hasAdjustmentPreview) {
      Column({ space: SpacingTokens.SM }) {
        Text('调整后预览')
          .fontSize(FontTokens.BODY_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(ColorTokens.TEXT_PRIMARY)

        Text(this.adjustmentPreviewOverviewText)
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .width('100%')

        Row({ space: SpacingTokens.SM }) {
          Column({ space: SpacingTokens.XS }) {
            Text('当前安排')
              .fontSize(FontTokens.CAPTION_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)

            Text(this.adjustmentPreviewCurrentSummaryText)
              .fontSize(FontTokens.SMALL_SIZE)
              .fontColor(ColorTokens.TEXT_PRIMARY)
              .width('100%')
          }
          .layoutWeight(1)
          .padding(SpacingTokens.SM)
          .borderRadius(RadiusTokens.SM)
          .backgroundColor(ColorTokens.BG_SECONDARY)
          .alignItems(HorizontalAlign.Start)

          Column({ space: SpacingTokens.XS }) {
            Text('调整后')
              .fontSize(FontTokens.CAPTION_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)

            Text(this.adjustmentPreviewNextSummaryText)
              .fontSize(FontTokens.SMALL_SIZE)
              .fontColor(ColorTokens.TEXT_PRIMARY)
              .width('100%')
          }
          .layoutWeight(1)
          .padding(SpacingTokens.SM)
          .borderRadius(RadiusTokens.SM)
          .backgroundColor(ColorTokens.BG_SECONDARY)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')

        Text(this.adjustmentPreviewArrangementText)
          .fontSize(FontTokens.SMALL_SIZE)
          .fontColor(ColorTokens.TEXT_PRIMARY)
          .width('100%')

        Column({ space: SpacingTokens.XS }) {
          ForEach(this.adjustmentPreviewHighlights, (highlight: string) => {
            Text('• ' + highlight)
              .fontSize(FontTokens.CAPTION_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
              .width('100%')
          }, (highlight: string) => highlight)
        }
        .width('100%')
      }
      .width('100%')
      .padding(SpacingTokens.SM)
      .borderRadius(RadiusTokens.SM)
      .backgroundColor(ColorTokens.BG_SECONDARY)
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildProfileSettings() {
    Column({ space: SpacingTokens.SM }) {
      Text('个人资料')
        .fontSize(FontTokens.TITLE_SIZE)
        .fontWeight(FontTokens.TITLE_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)

      Text(this.profileAvatar.length > 0 ? '头像占位：' + this.profileAvatar : '头像占位：默认头像')
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)

      Text(this.getProfileWeightUnitDescription())
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)

      AppInput({
        value: $profileNickname,
        placeholder: '输入昵称',
        type: 'text',
        maxLength: 20,
        showClear: true
      })

      Row({ space: SpacingTokens.SM }) {
        Button('kg')
          .layoutWeight(1)
          .height(TouchTokens.BUTTON_HEIGHT_DEFAULT)
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(this.profileWeightUnit === 'kg' ? ColorTokens.TEXT_ON_PRIMARY : ColorTokens.TEXT_PRIMARY)
          .backgroundColor(this.profileWeightUnit === 'kg' ? ColorTokens.PRIMARY : ColorTokens.SURFACE_ELEVATED)
          .borderRadius(RadiusTokens.FULL)
          .onClick(() => {
            this.saveWeightUnit('kg')
          })

        Button('lbs')
          .layoutWeight(1)
          .height(TouchTokens.BUTTON_HEIGHT_DEFAULT)
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(this.profileWeightUnit === 'lbs' ? ColorTokens.TEXT_ON_PRIMARY : ColorTokens.TEXT_PRIMARY)
          .backgroundColor(this.profileWeightUnit === 'lbs' ? ColorTokens.PRIMARY : ColorTokens.SURFACE_ELEVATED)
          .borderRadius(RadiusTokens.FULL)
          .onClick(() => {
            this.saveWeightUnit('lbs')
          })
      }
      .width('100%')

      Row({ space: SpacingTokens.SM }) {
        Button(this.profileLoading ? '保存中...' : '保存昵称')
          .layoutWeight(1)
          .height(TouchTokens.BUTTON_HEIGHT_DEFAULT)
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_ON_PRIMARY)
          .backgroundColor(ColorTokens.PRIMARY)
          .borderRadius(RadiusTokens.FULL)
          .enabled(!this.profileLoading)
          .onClick(() => {
            this.saveNickname()
          })

        Button('退出登录')
          .layoutWeight(1)
          .height(TouchTokens.BUTTON_HEIGHT_DEFAULT)
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_PRIMARY)
          .backgroundColor(ColorTokens.SURFACE_ELEVATED)
          .borderRadius(RadiusTokens.FULL)
          .enabled(!this.profileLoading)
          .onClick(() => {
            this.logout()
          })
      }
      .width('100%')

      if (this.profileStatusText.length > 0) {
        Text(this.profileStatusText)
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
      }
    }
    .width('100%')
    .padding(SpacingTokens.MD)
    .borderRadius(RadiusTokens.SM)
    .backgroundColor(ColorTokens.BG_SECONDARY)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildBackupSection() {
    Column({ space: SpacingTokens.SM }) {
      Text('数据备份')
        .fontSize(FontTokens.TITLE_SIZE)
        .fontWeight(FontTokens.TITLE_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)

      Text(UserDataBackupService.getUsageHintText())
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .width('100%')

      Text(UserDataBackupService.getScopeSummaryText())
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .width('100%')

      Text(UserDataBackupService.getRestoreRuleText())
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .width('100%')

      TextArea({ text: $$this.backupPackageText, placeholder: '导出或粘贴备份 JSON' })
        .width('100%')
        .height(180)
        .fontSize(FontTokens.SMALL_SIZE)
        .fontColor(ColorTokens.TEXT_PRIMARY)
        .placeholderColor(ColorTokens.TEXT_DISABLED)
        .backgroundColor(ColorTokens.SURFACE_SECONDARY)
        .borderRadius(RadiusTokens.SM)
        .border({
          width: 1,
          color: ColorTokens.SURFACE_ELEVATED
        })

      Row({ space: SpacingTokens.SM }) {
        Button(this.backupBusy ? '处理中...' : '生成备份包')
          .layoutWeight(1)
          .height(TouchTokens.BUTTON_HEIGHT_DEFAULT)
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_ON_PRIMARY)
          .backgroundColor(ColorTokens.PRIMARY)
          .borderRadius(RadiusTokens.FULL)
          .enabled(!this.backupBusy)
          .onClick(() => {
            this.exportBackupPackage()
          })

        Button(this.backupBusy ? '处理中...' : '导入备份包')
          .layoutWeight(1)
          .height(TouchTokens.BUTTON_HEIGHT_DEFAULT)
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_ON_PRIMARY)
          .backgroundColor(ColorTokens.ACCENT)
          .borderRadius(RadiusTokens.FULL)
          .enabled(!this.backupBusy)
          .onClick(() => {
            this.importBackupPackage()
          })
      }
      .width('100%')

      Button('清空输入区')
        .width('100%')
        .height(TouchTokens.BUTTON_HEIGHT_DEFAULT)
        .fontSize(FontTokens.BODY_SIZE)
        .fontColor(ColorTokens.TEXT_PRIMARY)
        .backgroundColor(ColorTokens.SURFACE_ELEVATED)
        .borderRadius(RadiusTokens.FULL)
        .enabled(!this.backupBusy)
        .onClick(() => {
          this.clearBackupPackageText()
        })

      if (this.backupStatusText.length > 0) {
        Text(this.backupStatusText)
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(this.getBackupStatusColor())
          .width('100%')
      }
    }
    .width('100%')
    .padding(SpacingTokens.MD)
    .borderRadius(RadiusTokens.SM)
    .backgroundColor(ColorTokens.BG_SECONDARY)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildBackupEntrySection() {
    Column({ space: SpacingTokens.MD }) {
      Column({ space: SpacingTokens.XS }) {
        Text('数据备份')
          .fontSize(FontTokens.TITLE_SIZE)
          .fontWeight(FontTokens.TITLE_WEIGHT)
          .fontColor(ColorTokens.TEXT_PRIMARY)

        Text('导出当前本地训练数据，或粘贴已有备份包恢复到这台设备。')
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: SpacingTokens.SM }) {
        Row() {
          Column({ space: SpacingTokens.XS }) {
            Text(this.getBackupStatusTitle())
              .fontSize(FontTokens.BODY_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text(this.getBackupStatusDescription())
              .fontSize(FontTokens.CAPTION_SIZE)
              .fontColor(this.getBackupStatusColor())
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text(this.getBackupStatusTagText())
            .fontSize(FontTokens.SMALL_SIZE)
            .fontColor(ColorTokens.TEXT_ON_PRIMARY)
            .padding({
              top: SpacingTokens.XS,
              bottom: SpacingTokens.XS,
              left: SpacingTokens.SM,
              right: SpacingTokens.SM
            })
            .backgroundColor(this.getBackupStatusBorderColor())
            .borderRadius(RadiusTokens.FULL)
        }
        .width('100%')

        Text(this.getBackupPackageCountText())
          .fontSize(FontTokens.SMALL_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)

        Text(this.getBackupPackageHelperText())
          .fontSize(FontTokens.SMALL_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .width('100%')
      }
      .width('100%')
      .padding(SpacingTokens.MD)
      .borderRadius(RadiusTokens.SM)
      .backgroundColor(this.getBackupStatusBackgroundColor())
      .border({
        width: 1,
        color: this.getBackupStatusBorderColor()
      })
      .alignItems(HorizontalAlign.Start)

      Column({ space: SpacingTokens.SM }) {
        Text('操作前说明')
          .fontSize(FontTokens.BODY_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(ColorTokens.TEXT_PRIMARY)

        this.buildBackupGuideItem('包含范围', UserDataBackupService.getScopeSummaryText())
        this.buildBackupGuideItem('导入规则', UserDataBackupService.getRestoreRuleText())
        this.buildBackupGuideItem('使用提醒', UserDataBackupService.getUsageHintText())
      }
      .width('100%')
      .padding(SpacingTokens.MD)
      .borderRadius(RadiusTokens.SM)
      .backgroundColor(ColorTokens.SURFACE_PRIMARY)
      .alignItems(HorizontalAlign.Start)

      Column({ space: SpacingTokens.SM }) {
        Row() {
          Column({ space: SpacingTokens.XS }) {
            Text('备份包内容')
              .fontSize(FontTokens.BODY_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text('生成后可复制保存；粘贴现有 JSON 后可直接导入恢复。')
              .fontSize(FontTokens.CAPTION_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text(this.hasBackupPackageText() ? '已载入' : '待输入')
            .fontSize(FontTokens.SMALL_SIZE)
            .fontColor(this.hasBackupPackageText() ? ColorTokens.TEXT_ON_PRIMARY : ColorTokens.TEXT_SECONDARY)
            .padding({
              top: SpacingTokens.XS,
              bottom: SpacingTokens.XS,
              left: SpacingTokens.SM,
              right: SpacingTokens.SM
            })
            .backgroundColor(this.hasBackupPackageText() ? ColorTokens.PRIMARY : ColorTokens.SURFACE_ELEVATED)
            .borderRadius(RadiusTokens.FULL)
        }
        .width('100%')

        TextArea({ text: $$this.backupPackageText, placeholder: '生成备份后会显示在这里，或在此粘贴备份 JSON' })
          .width('100%')
          .height(180)
          .fontSize(FontTokens.SMALL_SIZE)
          .fontColor(ColorTokens.TEXT_PRIMARY)
          .placeholderColor(ColorTokens.TEXT_DISABLED)
          .backgroundColor(ColorTokens.SURFACE_SECONDARY)
          .borderRadius(RadiusTokens.SM)
          .border({
            width: 1,
            color: this.getBackupInputBorderColor()
          })

        Row({ space: SpacingTokens.SM }) {
          Button(this.backupBusy && this.backupFlow === 'export' ? '生成中...' : '生成当前备份')
            .layoutWeight(1)
            .height(TouchTokens.BUTTON_HEIGHT_DEFAULT)
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_ON_PRIMARY)
            .backgroundColor(ColorTokens.PRIMARY)
            .borderRadius(RadiusTokens.FULL)
            .enabled(!this.backupBusy)
            .onClick(() => {
              this.exportBackupPackage()
            })

          Button(this.backupBusy && this.backupFlow === 'import' ? '导入中...' : '导入并恢复数据')
            .layoutWeight(1)
            .height(TouchTokens.BUTTON_HEIGHT_DEFAULT)
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(this.getBackupImportButtonTextColor())
            .backgroundColor(this.getBackupImportButtonColor())
            .borderRadius(RadiusTokens.FULL)
            .enabled(this.canImportBackup())
            .onClick(() => {
              this.importBackupPackage()
            })
        }
        .width('100%')

        Button('清空输入区')
          .width('100%')
          .height(TouchTokens.BUTTON_HEIGHT_DEFAULT)
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_PRIMARY)
          .backgroundColor(ColorTokens.SURFACE_ELEVATED)
          .borderRadius(RadiusTokens.FULL)
          .enabled(!this.backupBusy && this.hasBackupPackageText())
          .onClick(() => {
            this.clearBackupPackageText()
          })

        if (this.backupStatusText.length > 0) {
          Text('结果反馈：' + this.backupStatusText)
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(this.getBackupStatusColor())
            .width('100%')
        }
      }
      .width('100%')
      .padding(SpacingTokens.MD)
      .borderRadius(RadiusTokens.SM)
      .backgroundColor(ColorTokens.BG_SECONDARY)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(SpacingTokens.MD)
    .borderRadius(RadiusTokens.SM)
    .backgroundColor(ColorTokens.BG_SECONDARY)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll() {
      Column({ space: SpacingTokens.LG }) {
        AppCard({ variant: 'panel', cardPadding: 'default' }) {
          Column({ space: SpacingTokens.SM }) {
            Text('回顾控制台')
              .fontSize(FontTokens.MICRO_SIZE)
              .fontWeight(FontTokens.MICRO_WEIGHT)
              .fontColor(ColorTokens.TEXT_TERTIARY)

            Text('训练回顾')
              .fontSize(FontTokens.DISPLAY_SIZE)
              .fontWeight(FontTokens.DISPLAY_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text(this.getReviewSubtitle())
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        PrimaryDestinationStrip({ currentKey: 'review' })

        this.buildWeeklyStats()
        this.buildCalendarHeatmap()

        if (!this.loading && !this.hasSessions) {
          AppCard({ variant: 'outlined', cardPadding: 'default' }) {
            Column({ space: SpacingTokens.MD }) {
              Text('还没有训练记录')
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontTokens.TITLE_WEIGHT)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Text(this.adjustmentText)
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)

              AppButton({
                text: '开始今日训练',
                type: 'primary',
                buttonSize: 'large',
                block: true,
                onButtonClick: () => {
                  this.openHome()
                }
              })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
        }

        if (!this.loading && this.hasSessions) {
          Column({ space: SpacingTokens.MD }) {
            AppCard({ variant: 'panel', cardPadding: 'default' }) {
              Column({ space: SpacingTokens.MD }) {
                Row() {
                  Column({ space: SpacingTokens.XS }) {
                    Text('回顾总览')
                      .fontSize(FontTokens.MICRO_SIZE)
                      .fontWeight(FontTokens.MICRO_WEIGHT)
                      .fontColor(ColorTokens.TEXT_TERTIARY)

                    Text('平均完成率')
                      .fontSize(FontTokens.TITLE_SIZE)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(ColorTokens.TEXT_PRIMARY)
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  Text(this.getCompletionStatusText())
                    .fontSize(FontTokens.SMALL_SIZE)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.getCompletionStatusColor())
                    .padding({
                      top: SpacingTokens.XS,
                      bottom: SpacingTokens.XS,
                      left: SpacingTokens.SM,
                      right: SpacingTokens.SM
                    })
                    .backgroundColor(this.getCompletionStatusBackgroundColor())
                    .borderRadius(RadiusTokens.FULL)
                }
                .width('100%')

                Row({ space: SpacingTokens.SM }) {
                  Column({ space: SpacingTokens.XS }) {
                    Text(this.getCompletionText())
                      .fontSize(FontTokens.HERO_SIZE)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(ColorTokens.TEXT_PRIMARY)

                    Text('训练完成率')
                      .fontSize(FontTokens.SMALL_SIZE)
                      .fontColor(ColorTokens.TEXT_TERTIARY)
                  }
                  .layoutWeight(1)
                  .padding(SpacingTokens.MD)
                  .backgroundColor(ColorTokens.SURFACE_SECONDARY)
                  .borderRadius(RadiusTokens.MD)
                  .border({ width: 1, color: ColorTokens.BORDER_SUBTLE })
                  .alignItems(HorizontalAlign.Start)

                  Column({ space: SpacingTokens.XS }) {
                    Text(this.sessionCount.toString())
                      .fontSize(FontTokens.TITLE_SIZE)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(ColorTokens.DATA_HIGHLIGHT)

                    Text('累计训练次数')
                      .fontSize(FontTokens.SMALL_SIZE)
                      .fontColor(ColorTokens.TEXT_TERTIARY)
                  }
                  .layoutWeight(1)
                  .padding(SpacingTokens.MD)
                  .backgroundColor(ColorTokens.SURFACE_SECONDARY)
                  .borderRadius(RadiusTokens.MD)
                  .border({ width: 1, color: ColorTokens.BORDER_SUBTLE })
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')

                Stack({ alignContent: Alignment.Start }) {
                  Row()
                    .width('100%')
                    .height(TouchTokens.PROGRESS_BAR_HEIGHT)
                    .backgroundColor(ColorTokens.SURFACE_SECONDARY)
                    .borderRadius(RadiusTokens.FULL)

                  Row()
                    .width(this.getProgressWidth())
                    .height(TouchTokens.PROGRESS_BAR_HEIGHT)
                    .backgroundColor(ColorTokens.PRIMARY)
                    .borderRadius(RadiusTokens.FULL)
                }
                .width('100%')
                .height(TouchTokens.PROGRESS_BAR_HEIGHT)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            Row({ space: SpacingTokens.SM }) {
              this.buildMetric('训练次数', this.sessionCount.toString())
              this.buildMetric('完成组数', this.totalCompletedSets.toString() + '/' + this.totalTargetSets.toString())
            }
            .width('100%')

            Row({ space: SpacingTokens.SM }) {
              this.buildMetric('累计时长', this.totalDurationText)
              this.buildMetric('最近训练日', this.latestDayId)
            }
            .width('100%')

            this.buildRecentTrainingSection()
            this.buildTrendSummary()
            this.buildAdvancedInsightsEntrySection()
            this.buildAdvancedInsightsPanelSection()

            Column({ space: SpacingTokens.SM }) {
              Text('下次调整建议')
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontTokens.TITLE_WEIGHT)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Text(this.adjustmentText)
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)

              Text(this.adjustmentTitle)
                .fontSize(FontTokens.BODY_SIZE)
                .fontWeight(FontWeight.Medium)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Text(this.adjustmentDescription)
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)

              this.buildAdjustmentPreviewSection()

              if (this.adjustmentStatusText.length > 0) {
                Text(this.adjustmentStatusText)
                  .fontSize(FontTokens.CAPTION_SIZE)
                  .fontColor(ColorTokens.PRIMARY)
              }

              Button(this.applyingAdjustment ? '保存调整中...' : this.adjustmentButtonText)
                .width('100%')
                .height(TouchTokens.BUTTON_HEIGHT_DEFAULT)
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_ON_PRIMARY)
                .backgroundColor(this.canApplyAdjustment ? ColorTokens.PRIMARY : ColorTokens.PRIMARY_DISABLED)
                .borderRadius(RadiusTokens.FULL)
                .enabled(this.canApplyAdjustment && !this.applyingAdjustment)
                .onClick(() => {
                  this.applyGoalAdjustment()
                })
            }
            .width('100%')
            .padding(SpacingTokens.MD)
            .borderRadius(RadiusTokens.SM)
            .backgroundColor(ColorTokens.SURFACE_PRIMARY)
            .alignItems(HorizontalAlign.Start)

            AppButton({
              text: '调整下次计划',
              type: 'primary',
              buttonSize: 'large',
              block: true,
              onButtonClick: () => {
                this.openGoalSetup()
              }
            })

            AppButton({
              text: '查看最近复盘',
              type: 'secondary',
              buttonSize: 'large',
              block: true,
              onButtonClick: () => {
                this.openLatestSummary()
              }
            })
          }
          .width('100%')
        }

        if (!this.loading) {
          this.buildProfileSettings()
          this.buildBackupEntrySection()
        }
      }
      .width('100%')
      .padding(SpacingTokens.LG)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.BG_PRIMARY)
  }
}
