/**
 * WorkoutSummaryPage -- post-workout summary review.
 * Function #11: workout summary review.
 * Function #13: exercise personal best records in workout summary.
 */
import { router } from '@kit.ArkUI'
import { AppRoutes } from '../../../app/AppRoutes'
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens, TouchTokens } from '../../../common/styles/DesignTokens'
import { AppButton } from '../../../components/AppButton'
import { AppCard } from '../../../components/AppCard'
import { AppInput } from '../../../components/AppInput'
import { WorkoutSession } from '../../../shared/models/TrainingModels'
import ContentRepository from '../../../shared/services/ContentRepository'
import WorkoutRepository from '../../../shared/services/WorkoutRepository'
import WorkoutSummaryService, {
  WorkoutSummary,
  WorkoutSummaryExerciseRecord
} from '../../../shared/services/WorkoutSummaryService'
import WorkoutSessionEditService, {
  WorkoutSessionEditModel,
  WorkoutSessionEditSet
} from '../services/WorkoutSessionEditService'
import WorkoutSessionPersistenceBridgeService from '../services/WorkoutSessionPersistenceBridgeService'

@Entry
@Component
export struct WorkoutSummaryPage {
  @State loading: boolean = true
  @State hasSession: boolean = false
  @State sessionId: string = ''
  @State dayId: string = ''
  @State durationText: string = '0 分钟'
  @State durationSeconds: number = 0
  @State completedSets: number = 0
  @State targetSets: number = 0
  @State completionRate: number = 0
  @State totalVolume: number = 0
  @State fatigueScore: number = 0
  @State exerciseRecords: WorkoutSummaryExerciseRecord[] = []
  @State isEditMode: boolean = false
  @State showUndoConfirm: boolean = false
  @State actionMessage: string = ''
  @State actionMessageType: string = 'info'
  @State editTargetSetsText: string = ''
  @State editCustomNotes: string = ''
  @State editSets: WorkoutSessionEditSet[] = []
  @State savingEdit: boolean = false
  @State undoingSession: boolean = false
  @State canRestoreRemovedSession: boolean = false

  currentSession: WorkoutSession | undefined = undefined
  lastRemovedSession: WorkoutSession | undefined = undefined

  async aboutToAppear(): Promise<void> {
    this.loading = true
    this.isEditMode = false
    this.showUndoConfirm = false
    this.actionMessage = ''
    this.actionMessageType = 'info'
    this.savingEdit = false
    this.undoingSession = false
    this.loadSummarySession()
    if (this.currentSession !== undefined) {
      try {
        await WorkoutSessionPersistenceBridgeService.saveOrUpdateSession(getContext(this), this.currentSession)
      } catch (e) {
        // Keep summary visible even if legacy persistence sync fails.
      }
    }
    this.loading = false
  }

  loadSummarySession(): void {
    const session: WorkoutSession | undefined = this.findSession()
    this.currentSession = session
    if (session === undefined) {
      this.applySummary(WorkoutSummaryService.createEmptySummary())
      return
    }

    const summary: WorkoutSummary = WorkoutSummaryService.createSummaryWithHistory(session, WorkoutRepository.getSessions())
    this.applySummary(summary)
  }

  findSession(): WorkoutSession | undefined {
    const routeSessionId: string = this.getRouteSessionId()
    if (routeSessionId.length > 0) {
      const sessionById: WorkoutSession | undefined = WorkoutRepository.getSessionById(routeSessionId)
      if (sessionById !== undefined) {
        return sessionById
      }
    }
    return WorkoutRepository.getLatestSession()
  }

  getRouteSessionId(): string {
    try {
      const params = router.getParams() as Record<string, string>
      if (params.sessionId !== undefined) {
        return params.sessionId
      }
    } catch (e) {
      return ''
    }
    return ''
  }

  applySummary(summary: WorkoutSummary): void {
    this.hasSession = summary.hasSession
    this.sessionId = summary.sessionId
    this.dayId = summary.dayId
    this.durationText = summary.durationText
    this.durationSeconds = summary.durationSeconds
    this.completedSets = summary.completedSets
    this.targetSets = summary.targetSets
    this.completionRate = summary.completionRate
    this.totalVolume = summary.totalVolume
    this.fatigueScore = summary.fatigueScore
    this.exerciseRecords = this.copyExerciseRecords(summary.exerciseRecords)
  }

  copyExerciseRecords(source: WorkoutSummaryExerciseRecord[]): WorkoutSummaryExerciseRecord[] {
    const records: WorkoutSummaryExerciseRecord[] = []
    for (let index = 0; index < source.length; index++) {
      const sourceRecord: WorkoutSummaryExerciseRecord = source[index]
      const record: WorkoutSummaryExerciseRecord = {
        exerciseId: sourceRecord.exerciseId,
        exerciseName: sourceRecord.exerciseName,
        bestOneRepMax: sourceRecord.bestOneRepMax,
        bestWeight: sourceRecord.bestWeight,
        bestReps: sourceRecord.bestReps,
        dateText: sourceRecord.dateText
      }
      records.push(record)
    }
    return records
  }

  copyEditSets(source: WorkoutSessionEditSet[]): WorkoutSessionEditSet[] {
    const sets: WorkoutSessionEditSet[] = []
    for (let index = 0; index < source.length; index++) {
      const sourceSet: WorkoutSessionEditSet = source[index]
      const set: WorkoutSessionEditSet = {
        setId: sourceSet.setId,
        exerciseId: sourceSet.exerciseId,
        weightText: sourceSet.weightText,
        repsText: sourceSet.repsText,
        weight: sourceSet.weight,
        reps: sourceSet.reps,
        rpe: sourceSet.rpe,
        isWarmup: sourceSet.isWarmup,
        estimatedOneRepMax: sourceSet.estimatedOneRepMax,
        isComplete: sourceSet.isComplete
      }
      sets.push(set)
    }
    return sets
  }

  openHome(): void {
    try {
      router.replaceUrl({ url: AppRoutes.HOME })
    } catch (e) {
      // stay on summary
    }
  }

  openReview(): void {
    try {
      router.pushUrl({ url: AppRoutes.REVIEW_HOME })
    } catch (e) {
      // stay on summary
    }
  }

  enterEditMode(): void {
    if (this.currentSession === undefined) {
      return
    }
    const model: WorkoutSessionEditModel = WorkoutSessionEditService.createEditModel(this.currentSession)
    this.applyEditModel(model)
    this.isEditMode = true
    this.showUndoConfirm = false
    this.actionMessage = '已进入编辑模式，可修正组数、重量、次数和备注。'
    this.actionMessageType = 'info'
  }

  applyEditModel(model: WorkoutSessionEditModel): void {
    this.editTargetSetsText = model.targetSets.toString()
    this.editCustomNotes = model.customNotes
    this.editSets = this.copyEditSets(model.sets)
  }

  cancelEditMode(): void {
    this.isEditMode = false
    this.savingEdit = false
    this.actionMessage = '已取消编辑，本次训练保留当前保存结果。'
    this.actionMessageType = 'info'
  }

  showUndoPanel(): void {
    this.showUndoConfirm = true
    this.isEditMode = false
    this.actionMessage = '确认后会移除当前训练记录，但仍可在本页立即恢复。'
    this.actionMessageType = 'warning'
  }

  hideUndoPanel(): void {
    this.showUndoConfirm = false
    this.actionMessage = '已取消撤销操作。'
    this.actionMessageType = 'info'
  }

  createCurrentEditModel(targetSets: number): WorkoutSessionEditModel {
    const session: WorkoutSession = this.currentSession as WorkoutSession
    const model: WorkoutSessionEditModel = {
      sessionId: session.sessionId,
      planId: session.planId,
      dayId: session.dayId,
      startedAt: session.startedAt,
      endedAt: session.endedAt,
      durationSeconds: session.durationSeconds,
      fatigueScore: session.fatigueScore,
      targetSets: targetSets,
      completedSets: this.countCompletedEditSets(this.editSets),
      customNotes: this.editCustomNotes.trim(),
      sets: this.copyEditSets(this.editSets)
    }
    return model
  }

  countCompletedEditSets(sets: WorkoutSessionEditSet[]): number {
    let count: number = 0
    for (let index = 0; index < sets.length; index++) {
      if (sets[index].isComplete) {
        count++
      }
    }
    return count
  }

  updateSetWeight(setId: string, weightText: string): void {
    if (!this.isEditMode || this.currentSession === undefined) {
      return
    }
    const model: WorkoutSessionEditModel = this.createCurrentEditModel(this.getParsedTargetSets())
    const nextModel: WorkoutSessionEditModel = WorkoutSessionEditService.updateSetWeight(model, setId, weightText)
    this.applyEditModel(nextModel)
  }

  updateSetReps(setId: string, repsText: string): void {
    if (!this.isEditMode || this.currentSession === undefined) {
      return
    }
    const model: WorkoutSessionEditModel = this.createCurrentEditModel(this.getParsedTargetSets())
    const nextModel: WorkoutSessionEditModel = WorkoutSessionEditService.updateSetReps(model, setId, repsText)
    this.applyEditModel(nextModel)
  }

  getParsedTargetSets(): number {
    const parsed: number = Math.floor(Number(this.editTargetSetsText))
    if (Number.isNaN(parsed) || parsed <= 0) {
      return 0
    }
    return parsed
  }

  async submitEditDraft(): Promise<void> {
    if (this.currentSession === undefined || this.savingEdit) {
      return
    }
    const targetSetsValue: number = this.getParsedTargetSets()
    if (targetSetsValue <= 0) {
      this.actionMessage = '目标总组数需要大于 0，保存前请先修正。'
      this.actionMessageType = 'warning'
      return
    }

    this.savingEdit = true
    let syncSucceeded: boolean = true
    try {
      const model: WorkoutSessionEditModel = this.createCurrentEditModel(targetSetsValue)
      const correctedSession: WorkoutSession = WorkoutSessionEditService.createCorrectedSession(model)
      const updated: boolean = WorkoutRepository.updateSession(correctedSession)
      if (!updated) {
        this.actionMessage = '未找到可更新的训练记录，请返回后重新进入。'
        this.actionMessageType = 'warning'
        return
      }

      this.currentSession = correctedSession
      try {
        await WorkoutSessionPersistenceBridgeService.saveOrUpdateSession(getContext(this), correctedSession)
      } catch (e) {
        syncSucceeded = false
      }

      const summary: WorkoutSummary = WorkoutSummaryService.createSummaryWithHistory(
        correctedSession,
        WorkoutRepository.getSessions()
      )
      this.applySummary(summary)
      this.isEditMode = false
      this.showUndoConfirm = false
      this.actionMessage = syncSucceeded ? '训练记录已更新。' : '训练记录已更新，但旧持久层同步失败。'
      this.actionMessageType = syncSucceeded ? 'success' : 'warning'
    } finally {
      this.savingEdit = false
    }
  }

  async confirmUndoSave(): Promise<void> {
    if (this.currentSession === undefined || this.undoingSession) {
      return
    }

    this.undoingSession = true
    let syncSucceeded: boolean = true
    try {
      const removedSession: WorkoutSession | undefined = WorkoutRepository.removeSession(this.currentSession.sessionId)
      if (removedSession === undefined) {
        this.actionMessage = '没有找到当前训练记录，无法撤销。'
        this.actionMessageType = 'warning'
        return
      }

      this.lastRemovedSession = removedSession
      this.currentSession = undefined
      this.canRestoreRemovedSession = true
      this.isEditMode = false
      this.showUndoConfirm = false
      this.applySummary(WorkoutSummaryService.createEmptySummary())

      try {
        await WorkoutSessionPersistenceBridgeService.removeSession(getContext(this), removedSession.sessionId)
      } catch (e) {
        syncSucceeded = false
      }

      this.actionMessage = syncSucceeded ? '已撤销本次保存，可立即恢复。' : '已撤销本次保存，但旧持久层删除失败。'
      this.actionMessageType = syncSucceeded ? 'success' : 'warning'
    } finally {
      this.undoingSession = false
    }
  }

  async restoreRemovedSession(): Promise<void> {
    if (this.lastRemovedSession === undefined) {
      return
    }

    const sessionToRestore: WorkoutSession = this.lastRemovedSession
    const restored: boolean = WorkoutRepository.restoreSession(sessionToRestore)
    if (!restored) {
      this.actionMessage = '恢复失败，当前记录已存在。'
      this.actionMessageType = 'warning'
      return
    }

    this.currentSession = sessionToRestore
    this.lastRemovedSession = undefined
    this.canRestoreRemovedSession = false

    let syncSucceeded: boolean = true
    try {
      await WorkoutSessionPersistenceBridgeService.restoreSession(getContext(this), sessionToRestore)
    } catch (e) {
      syncSucceeded = false
    }

    const summary: WorkoutSummary = WorkoutSummaryService.createSummaryWithHistory(
      sessionToRestore,
      WorkoutRepository.getSessions()
    )
    this.applySummary(summary)
    this.actionMessage = syncSucceeded ? '训练记录已恢复。' : '训练记录已恢复，但旧持久层恢复失败。'
    this.actionMessageType = syncSucceeded ? 'success' : 'warning'
  }

  getPageSubtitle(): string {
    if (this.loading) {
      return '正在整理本次训练结果与记录状态'
    }
    if (!this.hasSession) {
      if (this.canRestoreRemovedSession) {
        return '本次记录已撤销，但你仍可以在这里立即恢复'
      }
      return '没有找到可展示的训练记录，先回到主流程开始训练'
    }
    return '先确认这次训练的完成情况，再决定是否修正记录或进入回顾'
  }

  getHeroBadgeText(): string {
    if (this.loading) {
      return '同步中'
    }
    if (this.canRestoreRemovedSession && !this.hasSession) {
      return '可恢复'
    }
    if (this.isEditMode) {
      return '编辑中'
    }
    if (this.showUndoConfirm) {
      return '待确认'
    }
    if (this.hasSession) {
      return '已保存'
    }
    return '无记录'
  }

  getHeroBadgeBackgroundColor(): string {
    if (this.canRestoreRemovedSession && !this.hasSession) {
      return ColorTokens.OVERLAY_ACCENT
    }
    if (this.isEditMode) {
      return ColorTokens.OVERLAY_PRIMARY
    }
    if (this.showUndoConfirm) {
      return ColorTokens.WARNING_BG
    }
    if (this.hasSession) {
      return ColorTokens.OVERLAY_SUCCESS
    }
    return ColorTokens.SURFACE_ELEVATED
  }

  getHeroTitle(): string {
    if (!this.hasSession) {
      return '训练总结'
    }
    return this.getDayLabel()
  }

  getDayLabel(): string {
    if (this.dayId.indexOf('current_plan_day_') === 0) {
      return '当前计划 第 ' + this.dayId.substring('current_plan_day_'.length) + ' 天'
    }
    if (this.dayId.indexOf('day_') === 0) {
      return '训练日 第 ' + this.dayId.substring('day_'.length) + ' 天'
    }
    if (this.dayId.length > 0) {
      return this.dayId
    }
    return '训练完成'
  }

  getHeroSummary(): string {
    if (!this.hasSession) {
      return '这次训练记录当前不可见，你可以返回首页继续训练，或恢复刚撤销的记录。'
    }
    let prText: string = '暂无 PR 亮点'
    if (this.exerciseRecords.length > 0) {
      prText = '本次新增 ' + this.exerciseRecords.length.toString() + ' 条动作纪录亮点'
    }
    return this.durationText + ' | 完成 ' + this.completedSets.toString() + '/' + this.targetSets.toString() +
      ' 组 | 训练量 ' + this.totalVolume.toString() + ' | ' + prText
  }

  getCompletionText(): string {
    return this.completionRate.toString() + '%'
  }

  getProgressWidth(): string {
    if (this.completionRate <= 0) {
      return '1%'
    }
    if (this.completionRate > 100) {
      return '100%'
    }
    return this.completionRate.toString() + '%'
  }

  getActionMessageColor(): string {
    if (this.actionMessageType === 'warning') {
      return ColorTokens.WARNING
    }
    if (this.actionMessageType === 'success') {
      return ColorTokens.SUCCESS
    }
    return ColorTokens.INFO
  }

  getActionMessageBackgroundColor(): string {
    if (this.actionMessageType === 'warning') {
      return ColorTokens.WARNING_BG
    }
    if (this.actionMessageType === 'success') {
      return ColorTokens.SUCCESS_BG
    }
    return ColorTokens.INFO_BG
  }

  getEditScopeText(): string {
    const completed: number = this.countCompletedEditSets(this.editSets)
    return '当前识别到 ' + completed.toString() + ' 组已完成记录，可逐组修正重量、次数与备注。'
  }

  getUndoDescriptionText(): string {
    return '建议只在刚保存且确认有误时使用。撤销后会从当前训练记录中移除，并保留一次立即恢复入口。'
  }

  getExerciseName(exerciseId: string): string {
    const exercise = ContentRepository.getExerciseById(exerciseId)
    if (exercise !== undefined) {
      return exercise.nameZh
    }
    return exerciseId
  }

  getSetStatusText(set: WorkoutSessionEditSet): string {
    if (set.isComplete) {
      return '已完成'
    }
    return '未完成'
  }

  getSetStatusBackgroundColor(set: WorkoutSessionEditSet): string {
    if (set.isComplete) {
      return ColorTokens.OVERLAY_SUCCESS
    }
    return ColorTokens.SURFACE_ELEVATED
  }

  getSetStatusTextColor(set: WorkoutSessionEditSet): string {
    if (set.isComplete) {
      return ColorTokens.SUCCESS
    }
    return ColorTokens.TEXT_SECONDARY
  }

  getSetOneRepMaxText(set: WorkoutSessionEditSet): string {
    if (set.estimatedOneRepMax <= 0) {
      return '录入重量和次数后显示参考 1RM'
    }
    return '参考 1RM ' + set.estimatedOneRepMax.toString() + ' kg'
  }

  getVolumeText(): string {
    return this.totalVolume.toString()
  }

  getFatigueText(): string {
    if (this.fatigueScore <= 0) {
      return '未记录'
    }
    return this.fatigueScore.toString()
  }

  @Builder
  buildHeroSection() {
    AppCard({ variant: 'panel', cardPadding: 'default' }) {
      Column({ space: SpacingTokens.MD }) {
        Row() {
          Column({ space: SpacingTokens.XS }) {
            Text('训练收官')
              .fontSize(FontTokens.MICRO_SIZE)
              .fontWeight(FontTokens.MICRO_WEIGHT)
              .fontColor(ColorTokens.TEXT_TERTIARY)

            Text(this.getHeroTitle())
              .fontSize(FontTokens.DISPLAY_SIZE)
              .fontWeight(FontTokens.DISPLAY_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(this.getPageSubtitle())
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
              .lineHeight(FontTokens.BODY_LINE_HEIGHT)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text(this.getHeroBadgeText())
            .fontSize(FontTokens.SMALL_SIZE)
            .fontColor(ColorTokens.TEXT_PRIMARY)
            .padding({
              top: SpacingTokens.XS,
              bottom: SpacingTokens.XS,
              left: SpacingTokens.SM,
              right: SpacingTokens.SM
            })
            .backgroundColor(this.getHeroBadgeBackgroundColor())
            .borderRadius(RadiusTokens.FULL)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        if (this.hasSession) {
          Text(this.getHeroSummary())
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
            .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
            .width('100%')

          Row({ space: SpacingTokens.MD }) {
            this.buildMetricTile('完成率', this.getCompletionText(), '本次训练')
            this.buildMetricTile('已完成', this.completedSets.toString() + '/' + this.targetSets.toString(), '目标组数')
          }
          .width('100%')

          Row({ space: SpacingTokens.MD }) {
            this.buildMetricTile('训练时长', this.durationText, '本次耗时')
            this.buildMetricTile('训练量', this.getVolumeText(), '累计重量')
          }
          .width('100%')
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildMetricTile(label: string, value: string, note: string) {
    Column({ space: SpacingTokens.XS }) {
      Text(label)
        .fontSize(FontTokens.SMALL_SIZE)
        .fontColor(ColorTokens.TEXT_TERTIARY)

      Text(value)
        .fontSize(FontTokens.HEADLINE_SIZE)
        .fontWeight(FontTokens.HEADLINE_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)
        .maxLines(2)

      Text(note)
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .maxLines(1)
    }
    .layoutWeight(1)
    .padding(SpacingTokens.MD)
    .backgroundColor(ColorTokens.SURFACE_SECONDARY)
    .borderRadius(RadiusTokens.MD)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildMessagePanel() {
    if (this.actionMessage.length > 0) {
      Column({ space: SpacingTokens.XS }) {
        Text('记录状态')
          .fontSize(FontTokens.SMALL_SIZE)
          .fontColor(this.getActionMessageColor())

        Text(this.actionMessage)
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(ColorTokens.TEXT_PRIMARY)
          .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
      }
      .width('100%')
      .padding(SpacingTokens.MD)
      .backgroundColor(this.getActionMessageBackgroundColor())
      .borderRadius(RadiusTokens.MD)
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildNoSessionState() {
    AppCard({ variant: 'outlined', cardPadding: 'default' }) {
      Column({ space: SpacingTokens.MD }) {
        Text('没有找到训练记录')
          .fontSize(FontTokens.TITLE_SIZE)
          .fontWeight(FontTokens.TITLE_WEIGHT)
          .fontColor(ColorTokens.TEXT_PRIMARY)

        Text(
          this.canRestoreRemovedSession ?
            '刚撤销的训练记录仍可恢复，恢复后会重新回到本页。' :
            '可能是从复盘页直接进入，或当前仓库里没有可展示的训练记录。'
        )
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .lineHeight(FontTokens.BODY_LINE_HEIGHT)

        if (this.canRestoreRemovedSession) {
          AppButton({
            text: '恢复刚撤销的记录',
            type: 'primary',
            buttonSize: 'large',
            block: true,
            onButtonClick: () => {
              this.restoreRemovedSession()
            }
          })
        }

        AppButton({
          text: '回到首页',
          type: 'secondary',
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

  @Builder
  buildProgressSection() {
    AppCard({ variant: 'panel', cardPadding: 'default' }) {
      Column({ space: SpacingTokens.MD }) {
        Row() {
          Column({ space: SpacingTokens.XS }) {
            Text('完成度')
              .fontSize(FontTokens.TITLE_SIZE)
              .fontWeight(FontTokens.TITLE_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text('本次训练的执行结果已经落库，可在这里做最终校对。')
              .fontSize(FontTokens.CAPTION_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text(this.getCompletionText())
            .fontSize(FontTokens.TITLE_SIZE)
            .fontWeight(FontTokens.TITLE_WEIGHT)
            .fontColor(ColorTokens.PRIMARY)
        }
        .width('100%')

        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width('100%')
            .height(TouchTokens.PROGRESS_BAR_HEIGHT)
            .backgroundColor(ColorTokens.SURFACE_ELEVATED)
            .borderRadius(RadiusTokens.FULL)

          Row()
            .width(this.getProgressWidth())
            .height(TouchTokens.PROGRESS_BAR_HEIGHT)
            .backgroundColor(ColorTokens.PRIMARY)
            .borderRadius(RadiusTokens.FULL)
        }
        .width('100%')
        .height(TouchTokens.PROGRESS_BAR_HEIGHT)

        Row({ space: SpacingTokens.MD }) {
          this.buildMetricTile('训练日', this.getDayLabel(), '当前入口')
          this.buildMetricTile('疲劳分', this.getFatigueText(), '主观负荷')
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildRecordSection() {
    AppCard({ variant: 'elevated', cardPadding: 'default' }) {
      Column({ space: SpacingTokens.MD }) {
        Text('本次亮点')
          .fontSize(FontTokens.TITLE_SIZE)
          .fontWeight(FontTokens.TITLE_WEIGHT)
          .fontColor(ColorTokens.TEXT_PRIMARY)

        if (this.exerciseRecords.length === 0) {
          Text('本次没有新的动作纪录亮点，但训练记录已经完整保存。')
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
            .width('100%')
        }

        ForEach(this.exerciseRecords, (record: WorkoutSummaryExerciseRecord) => {
          this.buildExerciseRecord(record)
        }, (record: WorkoutSummaryExerciseRecord) => record.exerciseId)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildExerciseRecord(record: WorkoutSummaryExerciseRecord) {
    Column({ space: SpacingTokens.SM }) {
      Row() {
        Column({ space: SpacingTokens.XS }) {
          Text(record.exerciseName)
            .fontSize(FontTokens.BODY_BOLD_SIZE)
            .fontWeight(FontTokens.BODY_BOLD_WEIGHT)
            .fontColor(ColorTokens.TEXT_PRIMARY)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(record.dateText)
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text('PR')
          .fontSize(FontTokens.SMALL_SIZE)
          .fontColor(ColorTokens.NEW_RECORD)
          .padding({
            top: SpacingTokens.XS,
            bottom: SpacingTokens.XS,
            left: SpacingTokens.SM,
            right: SpacingTokens.SM
          })
          .backgroundColor(ColorTokens.NEW_RECORD_BG)
          .borderRadius(RadiusTokens.FULL)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Row({ space: SpacingTokens.SM }) {
        this.buildRecordMetric('最佳 1RM', record.bestOneRepMax.toString() + ' kg')
        this.buildRecordMetric('最佳重量', record.bestWeight.toString() + ' kg')
        this.buildRecordMetric('最佳次数', record.bestReps.toString() + ' 次')
      }
      .width('100%')
    }
    .width('100%')
    .padding(SpacingTokens.MD)
    .backgroundColor(ColorTokens.SURFACE_SECONDARY)
    .borderRadius(RadiusTokens.MD)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildRecordMetric(label: string, value: string) {
    Column({ space: SpacingTokens.XS }) {
      Text(label)
        .fontSize(FontTokens.SMALL_SIZE)
        .fontColor(ColorTokens.TEXT_TERTIARY)

      Text(value)
        .fontSize(FontTokens.BODY_BOLD_SIZE)
        .fontWeight(FontTokens.BODY_BOLD_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)
        .maxLines(2)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildActionSection() {
    AppCard({ variant: 'outlined', cardPadding: 'default' }) {
      Column({ space: SpacingTokens.MD }) {
        Text('修正记录')
          .fontSize(FontTokens.TITLE_SIZE)
          .fontWeight(FontTokens.TITLE_WEIGHT)
          .fontColor(ColorTokens.TEXT_PRIMARY)

        Text('如果刚才录入有误，可以在这里修正组数、重量、次数与备注；撤销保存会移除整条记录。')
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .lineHeight(FontTokens.BODY_LINE_HEIGHT)

        AppButton({
          text: this.isEditMode ? '正在编辑本次训练' : '编辑本次训练',
          type: 'primary',
          buttonSize: 'large',
          block: true,
          disabled: this.isEditMode,
          onButtonClick: () => {
            this.enterEditMode()
          }
        })

        AppButton({
          text: '撤销本次保存',
          type: 'secondary',
          buttonSize: 'large',
          block: true,
          onButtonClick: () => {
            this.showUndoPanel()
          }
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildMetadataSection() {
    AppCard({ variant: 'outlined', cardPadding: 'compact' }) {
      Column({ space: SpacingTokens.SM }) {
        Text('记录元信息')
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontWeight(FontTokens.TITLE_WEIGHT)
          .fontColor(ColorTokens.TEXT_PRIMARY)

        this.buildInfoRow('记录编号', this.sessionId)
        this.buildInfoRow('训练日', this.getDayLabel())
        this.buildInfoRow('训练时长', this.durationText)
        this.buildInfoRow('训练量', this.getVolumeText())
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildInfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(FontTokens.SMALL_SIZE)
        .fontColor(ColorTokens.TEXT_TERTIARY)
        .width(72)

      Text(value)
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .layoutWeight(1)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  buildEditShell() {
    AppCard({ variant: 'elevated', cardPadding: 'default' }) {
      Column({ space: SpacingTokens.MD }) {
        Text('编辑本次训练')
          .fontSize(FontTokens.TITLE_SIZE)
          .fontWeight(FontTokens.TITLE_WEIGHT)
          .fontColor(ColorTokens.TEXT_PRIMARY)

        Text(this.getEditScopeText())
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .lineHeight(FontTokens.BODY_LINE_HEIGHT)

        AppInput({
          value: $editTargetSetsText,
          placeholder: '目标总组数',
          type: 'number'
        })

        AppInput({
          value: $editCustomNotes,
          placeholder: '训练备注，可留空',
          type: 'text',
          showClear: true
        })

        ForEach(this.editSets, (set: WorkoutSessionEditSet, index: number) => {
          this.buildEditSetCard(set, index + 1)
        }, (set: WorkoutSessionEditSet) => set.setId)

        AppButton({
          text: this.savingEdit ? '保存中...' : '提交编辑',
          type: 'primary',
          buttonSize: 'large',
          block: true,
          loading: this.savingEdit,
          onButtonClick: () => {
            this.submitEditDraft()
          }
        })

        AppButton({
          text: '取消编辑',
          type: 'secondary',
          buttonSize: 'large',
          block: true,
          disabled: this.savingEdit,
          onButtonClick: () => {
            this.cancelEditMode()
          }
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildEditSetCard(set: WorkoutSessionEditSet, displayIndex: number) {
    Column({ space: SpacingTokens.SM }) {
      Row() {
        Column({ space: SpacingTokens.XS }) {
          Text(this.getExerciseName(set.exerciseId) + ' | 第 ' + displayIndex.toString() + ' 组')
            .fontSize(FontTokens.BODY_BOLD_SIZE)
            .fontWeight(FontTokens.BODY_BOLD_WEIGHT)
            .fontColor(ColorTokens.TEXT_PRIMARY)

          Text(this.getSetOneRepMaxText(set))
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(this.getSetStatusText(set))
          .fontSize(FontTokens.SMALL_SIZE)
          .fontColor(this.getSetStatusTextColor(set))
          .padding({
            top: SpacingTokens.XS,
            bottom: SpacingTokens.XS,
            left: SpacingTokens.SM,
            right: SpacingTokens.SM
          })
          .backgroundColor(this.getSetStatusBackgroundColor(set))
          .borderRadius(RadiusTokens.FULL)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: SpacingTokens.SM }) {
        Column({ space: SpacingTokens.XS }) {
          Text('重量 kg')
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)

          TextInput({ text: set.weightText, placeholder: '0' })
            .type(InputType.Number)
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_PRIMARY)
            .placeholderColor(ColorTokens.TEXT_DISABLED)
            .backgroundColor(ColorTokens.SURFACE_SECONDARY)
            .borderRadius(RadiusTokens.SM)
            .height(TouchTokens.INPUT_HEIGHT)
            .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD })
            .onChange((value: string) => {
              this.updateSetWeight(set.setId, value)
            })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: SpacingTokens.XS }) {
          Text('次数')
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)

          TextInput({ text: set.repsText, placeholder: '0' })
            .type(InputType.Number)
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_PRIMARY)
            .placeholderColor(ColorTokens.TEXT_DISABLED)
            .backgroundColor(ColorTokens.SURFACE_SECONDARY)
            .borderRadius(RadiusTokens.SM)
            .height(TouchTokens.INPUT_HEIGHT)
            .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD })
            .onChange((value: string) => {
              this.updateSetReps(set.setId, value)
            })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
    }
    .width('100%')
    .padding(SpacingTokens.MD)
    .backgroundColor(ColorTokens.SURFACE_SECONDARY)
    .borderRadius(RadiusTokens.MD)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildUndoShell() {
    if (this.showUndoConfirm) {
      AppCard({ variant: 'outlined', cardPadding: 'default' }) {
        Column({ space: SpacingTokens.MD }) {
          Text('撤销本次保存')
            .fontSize(FontTokens.TITLE_SIZE)
            .fontWeight(FontTokens.TITLE_WEIGHT)
            .fontColor(ColorTokens.TEXT_PRIMARY)

          Text(this.getUndoDescriptionText())
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
            .lineHeight(FontTokens.BODY_LINE_HEIGHT)

          this.buildInfoRow('记录编号', this.sessionId)

          AppButton({
            text: this.undoingSession ? '撤销中...' : '确认撤销',
            type: 'primary',
            buttonSize: 'large',
            block: true,
            loading: this.undoingSession,
            onButtonClick: () => {
              this.confirmUndoSave()
            }
          })

          AppButton({
            text: '先保留记录',
            type: 'secondary',
            buttonSize: 'large',
            block: true,
            disabled: this.undoingSession,
            onButtonClick: () => {
              this.hideUndoPanel()
            }
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
  }

  @Builder
  buildNextStepSection() {
    AppCard({ variant: 'panel', cardPadding: 'default' }) {
      Column({ space: SpacingTokens.SM }) {
        Text('下一步')
          .fontSize(FontTokens.TITLE_SIZE)
          .fontWeight(FontTokens.TITLE_WEIGHT)
          .fontColor(ColorTokens.TEXT_PRIMARY)

        Text('确认记录无误后，可以直接进入训练回顾，或先回到首页继续下一轮安排。')
          .fontSize(FontTokens.SMALL_SIZE)
          .fontColor(ColorTokens.TEXT_TERTIARY)
          .lineHeight(FontTokens.SMALL_LINE_HEIGHT)

        AppButton({
          text: '查看训练回顾',
          type: 'primary',
          buttonSize: 'large',
          block: true,
          onButtonClick: () => {
            this.openReview()
          }
        })

        AppButton({
          text: '回到首页',
          type: 'secondary',
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

  build() {
    Scroll() {
      Column({ space: SpacingTokens.LG }) {
        this.buildHeroSection()

        if (!this.loading) {
          this.buildMessagePanel()
        }

        if (!this.loading && !this.hasSession) {
          this.buildNoSessionState()
        }

        if (!this.loading && this.hasSession) {
          this.buildProgressSection()
          this.buildRecordSection()
          this.buildActionSection()

          if (this.isEditMode) {
            this.buildEditShell()
          }

          this.buildUndoShell()
          this.buildMetadataSection()
          this.buildNextStepSection()
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
