/**
 * WorkoutSummaryPage -- post-workout summary review.
 * Function #11: workout summary review.
 * Function #13: exercise personal best records in workout summary.
 */
import { router } from '@kit.ArkUI'
import { AppRoutes } from '../../../app/AppRoutes'
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens, TouchTokens } from '../../../common/styles/DesignTokens'
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
  @State completedSets: number = 0
  @State targetSets: number = 0
  @State completionRate: number = 0
  @State totalVolume: number = 0
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

  aboutToAppear(): void {
    this.loading = true
    this.isEditMode = false
    this.showUndoConfirm = false
    this.actionMessage = ''
    this.actionMessageType = 'info'
    this.savingEdit = false
    this.undoingSession = false
    this.loadSummarySession()
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
    this.completedSets = summary.completedSets
    this.targetSets = summary.targetSets
    this.completionRate = summary.completionRate
    this.totalVolume = summary.totalVolume
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
    this.actionMessage = '已进入编辑模式，可直接修正组数、重量、次数与备注。'
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
    this.actionMessage = '已取消编辑，本次训练仍保持当前保存结果。'
    this.actionMessageType = 'info'
  }

  showUndoPanel(): void {
    this.showUndoConfirm = true
    this.isEditMode = false
    this.actionMessage = '确认后会移除当前训练记录，仍可在本页立即恢复。'
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
      this.actionMessage = '目标组数需要大于 0，保存前请先修正。'
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
      this.actionMessage = syncSucceeded ? '训练记录已更新。' : '训练记录已更新，旧持久层同步失败。'
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
    return ColorTokens.TEXT_SECONDARY
  }

  getEditScopeText(): string {
    const completedSets: number = this.countCompletedEditSets(this.editSets)
    return '当前已识别 ' + completedSets.toString() + ' 组完成记录，可逐组修正重量、次数与备注。'
  }

  getUndoDescriptionText(): string {
    return '建议仅在刚保存且确认有误时使用。撤销后会从当前训练记录中移除，并提供一次恢复入口。'
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

  getSetStatusColor(set: WorkoutSessionEditSet): string {
    if (set.isComplete) {
      return ColorTokens.SUCCESS
    }
    return ColorTokens.TEXT_DISABLED
  }

  getSetOneRepMaxText(set: WorkoutSessionEditSet): string {
    if (set.estimatedOneRepMax <= 0) {
      return '录入重量和次数后显示 1RM'
    }
    return '参考 1RM ' + set.estimatedOneRepMax.toString() + ' kg'
  }

  @Builder
  buildMetric(label: string, value: string) {
    Column({ space: SpacingTokens.XS }) {
      Text(value)
        .fontSize(FontTokens.HEADLINE_SIZE)
        .fontWeight(FontTokens.HEADLINE_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)
        .maxLines(1)

      Text(label)
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .maxLines(1)
    }
    .layoutWeight(1)
    .padding(SpacingTokens.MD)
    .borderRadius(RadiusTokens.SM)
    .backgroundColor(ColorTokens.SURFACE_PRIMARY)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildRecordMetric(label: string, value: string) {
    Column({ space: SpacingTokens.XS }) {
      Text(value)
        .fontSize(FontTokens.BODY_BOLD_SIZE)
        .fontWeight(FontTokens.BODY_BOLD_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)
        .maxLines(1)

      Text(label)
        .fontSize(FontTokens.SMALL_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .maxLines(1)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildExerciseRecord(record: WorkoutSummaryExerciseRecord) {
    Column({ space: SpacingTokens.SM }) {
      Row() {
        Text(record.exerciseName)
          .fontSize(FontTokens.BODY_BOLD_SIZE)
          .fontWeight(FontTokens.BODY_BOLD_WEIGHT)
          .fontColor(ColorTokens.TEXT_PRIMARY)
          .maxLines(1)
          .layoutWeight(1)

        Text(record.dateText)
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .maxLines(1)
      }
      .width('100%')

      Row({ space: SpacingTokens.SM }) {
        this.buildRecordMetric('最佳 1RM', record.bestOneRepMax.toString() + ' kg')
        this.buildRecordMetric('最佳重量', record.bestWeight.toString() + ' kg')
        this.buildRecordMetric('最佳次数', record.bestReps.toString() + ' 次')
      }
      .width('100%')
    }
    .width('100%')
    .padding(SpacingTokens.MD)
    .borderRadius(RadiusTokens.SM)
    .backgroundColor(ColorTokens.SURFACE_PRIMARY)
  }

  @Builder
  buildActionNotice() {
    if (this.actionMessage.length > 0) {
      Row() {
        Text(this.actionMessage)
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(this.getActionMessageColor())
          .layoutWeight(1)
      }
      .width('100%')
      .padding(SpacingTokens.MD)
      .borderRadius(RadiusTokens.SM)
      .backgroundColor(ColorTokens.SURFACE_PRIMARY)
    }
  }

  @Builder
  buildEditSetCard(set: WorkoutSessionEditSet, displayIndex: number) {
    Column({ space: SpacingTokens.SM }) {
      Row() {
        Column({ space: SpacingTokens.XS }) {
          Text(this.getExerciseName(set.exerciseId) + ' · 第 ' + displayIndex.toString() + ' 组')
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
          .fontColor(ColorTokens.TEXT_ON_PRIMARY)
          .padding({
            top: SpacingTokens.XS,
            bottom: SpacingTokens.XS,
            left: SpacingTokens.SM,
            right: SpacingTokens.SM
          })
          .backgroundColor(this.getSetStatusColor(set))
          .borderRadius(RadiusTokens.FULL)
      }
      .width('100%')

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
    .borderRadius(RadiusTokens.SM)
    .backgroundColor(ColorTokens.SURFACE_PRIMARY)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildEditShell() {
    Column({ space: SpacingTokens.MD }) {
      Text('编辑本次训练')
        .fontSize(FontTokens.TITLE_SIZE)
        .fontWeight(FontTokens.TITLE_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)

      Text(this.getEditScopeText())
        .fontSize(FontTokens.BODY_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)

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

      Button(this.savingEdit ? '保存中...' : '提交编辑')
        .width('100%')
        .height(TouchTokens.BUTTON_HEIGHT_LARGE)
        .fontSize(FontTokens.BODY_SIZE)
        .fontColor(ColorTokens.TEXT_ON_PRIMARY)
        .backgroundColor(ColorTokens.PRIMARY)
        .borderRadius(RadiusTokens.FULL)
        .enabled(!this.savingEdit)
        .opacity(this.savingEdit ? 0.6 : 1)
        .onClick(() => {
          this.submitEditDraft()
        })

      Button('取消编辑')
        .width('100%')
        .height(TouchTokens.BUTTON_HEIGHT_LARGE)
        .fontSize(FontTokens.BODY_SIZE)
        .fontColor(ColorTokens.TEXT_PRIMARY)
        .backgroundColor(ColorTokens.SURFACE_ELEVATED)
        .borderRadius(RadiusTokens.FULL)
        .enabled(!this.savingEdit)
        .opacity(this.savingEdit ? 0.6 : 1)
        .onClick(() => {
          this.cancelEditMode()
        })
    }
    .width('100%')
    .padding(SpacingTokens.MD)
    .borderRadius(RadiusTokens.SM)
    .backgroundColor(ColorTokens.BG_SECONDARY)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildUndoShell() {
    if (this.showUndoConfirm) {
      Column({ space: SpacingTokens.MD }) {
        Text('撤销本次保存')
          .fontSize(FontTokens.TITLE_SIZE)
          .fontWeight(FontTokens.TITLE_WEIGHT)
          .fontColor(ColorTokens.TEXT_PRIMARY)

        Text(this.getUndoDescriptionText())
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)

        Text('记录编号：' + this.sessionId)
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)

        Button(this.undoingSession ? '撤销中...' : '确认撤销')
          .width('100%')
          .height(TouchTokens.BUTTON_HEIGHT_LARGE)
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_ON_PRIMARY)
          .backgroundColor(ColorTokens.WARNING)
          .borderRadius(RadiusTokens.FULL)
          .enabled(!this.undoingSession)
          .opacity(this.undoingSession ? 0.6 : 1)
          .onClick(() => {
            this.confirmUndoSave()
          })

        Button('先保留记录')
          .width('100%')
          .height(TouchTokens.BUTTON_HEIGHT_LARGE)
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_PRIMARY)
          .backgroundColor(ColorTokens.SURFACE_ELEVATED)
          .borderRadius(RadiusTokens.FULL)
          .enabled(!this.undoingSession)
          .opacity(this.undoingSession ? 0.6 : 1)
          .onClick(() => {
            this.hideUndoPanel()
          })
      }
      .width('100%')
      .padding(SpacingTokens.MD)
      .borderRadius(RadiusTokens.SM)
      .backgroundColor(ColorTokens.BG_SECONDARY)
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildNoSessionState() {
    Column({ space: SpacingTokens.MD }) {
      Text('没有找到训练记录')
        .fontSize(FontTokens.TITLE_SIZE)
        .fontWeight(FontTokens.TITLE_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)

      Text(this.canRestoreRemovedSession ? '刚撤销的训练记录仍可恢复。' : '可能是从复盘页直接进入，先回到首页开始一次训练。')
        .fontSize(FontTokens.BODY_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)

      if (this.canRestoreRemovedSession) {
        Button('恢复刚撤销的记录')
          .width('100%')
          .height(TouchTokens.BUTTON_HEIGHT_LARGE)
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_ON_PRIMARY)
          .backgroundColor(ColorTokens.PRIMARY)
          .borderRadius(RadiusTokens.FULL)
          .onClick(() => {
            this.restoreRemovedSession()
          })
      }

      Button('回到首页')
        .width('100%')
        .height(TouchTokens.BUTTON_HEIGHT_LARGE)
        .fontSize(FontTokens.BODY_SIZE)
        .fontColor(ColorTokens.TEXT_PRIMARY)
        .backgroundColor(ColorTokens.SURFACE_ELEVATED)
        .borderRadius(RadiusTokens.FULL)
        .onClick(() => {
          this.openHome()
        })
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
        Column({ space: SpacingTokens.SM }) {
          Text('训练复盘')
            .fontSize(FontTokens.DISPLAY_SIZE)
            .fontWeight(FontTokens.DISPLAY_WEIGHT)
            .fontColor(ColorTokens.TEXT_PRIMARY)

          Text(this.loading ? '正在整理本次训练' : '本次训练已经保存到本地记录')
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        if (!this.loading) {
          this.buildActionNotice()
        }

        if (!this.loading && !this.hasSession) {
          this.buildNoSessionState()
        }

        if (!this.loading && this.hasSession) {
          Column({ space: SpacingTokens.MD }) {
            Column({ space: SpacingTokens.SM }) {
              Row() {
                Text('完成度')
                  .fontSize(FontTokens.TITLE_SIZE)
                  .fontWeight(FontTokens.TITLE_WEIGHT)
                  .fontColor(ColorTokens.TEXT_PRIMARY)
                  .layoutWeight(1)

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
            }
            .width('100%')
            .padding(SpacingTokens.MD)
            .borderRadius(RadiusTokens.SM)
            .backgroundColor(ColorTokens.BG_SECONDARY)

            Column({ space: SpacingTokens.SM }) {
              Text('记录操作')
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontTokens.TITLE_WEIGHT)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Text('支持修正本次训练的组数、重量、次数与备注，也可以直接撤销并恢复。')
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)

              Button(this.isEditMode ? '正在编辑本次训练' : '编辑本次训练')
                .width('100%')
                .height(TouchTokens.BUTTON_HEIGHT_LARGE)
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_ON_PRIMARY)
                .backgroundColor(ColorTokens.PRIMARY)
                .borderRadius(RadiusTokens.FULL)
                .enabled(!this.isEditMode)
                .opacity(this.isEditMode ? 0.6 : 1)
                .onClick(() => {
                  this.enterEditMode()
                })

              Button('撤销本次保存')
                .width('100%')
                .height(TouchTokens.BUTTON_HEIGHT_LARGE)
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_PRIMARY)
                .backgroundColor(ColorTokens.SURFACE_ELEVATED)
                .borderRadius(RadiusTokens.FULL)
                .onClick(() => {
                  this.showUndoPanel()
                })
            }
            .width('100%')
            .padding(SpacingTokens.MD)
            .borderRadius(RadiusTokens.SM)
            .backgroundColor(ColorTokens.BG_SECONDARY)
            .alignItems(HorizontalAlign.Start)

            if (this.isEditMode) {
              this.buildEditShell()
            }

            this.buildUndoShell()

            Row({ space: SpacingTokens.SM }) {
              this.buildMetric('完成组数', this.completedSets.toString() + '/' + this.targetSets.toString())
              this.buildMetric('训练时长', this.durationText)
            }
            .width('100%')

            Row({ space: SpacingTokens.SM }) {
              this.buildMetric('训练日', this.dayId)
              this.buildMetric('训练容量', this.totalVolume.toString())
            }
            .width('100%')

            Column({ space: SpacingTokens.SM }) {
              Text('动作最佳记录')
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontTokens.TITLE_WEIGHT)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              ForEach(this.exerciseRecords, (record: WorkoutSummaryExerciseRecord) => {
                this.buildExerciseRecord(record)
              }, (record: WorkoutSummaryExerciseRecord) => record.exerciseId)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Column({ space: SpacingTokens.SM }) {
              Text('记录编号')
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)

              Text(this.sessionId)
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_PRIMARY)
            }
            .width('100%')
            .padding(SpacingTokens.MD)
            .borderRadius(RadiusTokens.SM)
            .backgroundColor(ColorTokens.SURFACE_PRIMARY)
            .alignItems(HorizontalAlign.Start)

            Button('回到首页')
              .width('100%')
              .height(TouchTokens.BUTTON_HEIGHT_LARGE)
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_ON_PRIMARY)
              .backgroundColor(ColorTokens.PRIMARY)
              .borderRadius(RadiusTokens.FULL)
              .onClick(() => {
                this.openHome()
              })

            Button('查看训练回顾')
              .width('100%')
              .height(TouchTokens.BUTTON_HEIGHT_LARGE)
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_PRIMARY)
              .backgroundColor(ColorTokens.SURFACE_ELEVATED)
              .borderRadius(RadiusTokens.FULL)
              .onClick(() => {
                this.openReview()
              })
          }
          .width('100%')
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
