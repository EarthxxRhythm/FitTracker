/**
 * GoalAdjustmentPreviewService -- preview plan changes before applying a goal adjustment.
 *
 * Feature #12: goal adjustment preview for review and onboarding flows.
 */
import {
  PlanDay,
  PlannedExercise,
  TrainingPlan,
  UserGoal,
  createUserGoal
} from '../models/TrainingModels'
import { GoalSetupPrefill } from './GoalSetupService'
import ContentRepository from './ContentRepository'
import PlanEngine from './PlanEngine'

export interface GoalAdjustmentValueChange {
  changed: boolean
  currentText: string
  nextText: string
  description: string
}

export interface GoalAdjustmentListChange {
  changed: boolean
  currentIds: string[]
  nextIds: string[]
  currentText: string
  nextText: string
  addedIds: string[]
  removedIds: string[]
  addedText: string
  removedText: string
  description: string
}

export interface GoalAdjustmentPlanSnapshot {
  planName: string
  weeklyDays: number
  trainingDayCount: number
  totalExercises: number
  focusSummary: string
  dailySummaries: string[]
}

export interface GoalAdjustmentPreviewResult {
  hasChanges: boolean
  changeCount: number
  changedKeys: string[]
  previewGoal: UserGoal
  previewPlan: TrainingPlan
  goalTypeChange: GoalAdjustmentValueChange
  weeklyDaysChange: GoalAdjustmentValueChange
  sessionMinutesChange: GoalAdjustmentValueChange
  equipmentChange: GoalAdjustmentListChange
  restrictedMuscleChange: GoalAdjustmentListChange
  currentPlanSnapshot: GoalAdjustmentPlanSnapshot
  previewPlanSnapshot: GoalAdjustmentPlanSnapshot
  planChanged: boolean
  overviewText: string
  arrangementChangeText: string
  summaryHighlights: string[]
}

function createGoalAdjustmentValueChange(
  changed: boolean,
  currentText: string,
  nextText: string,
  description: string
): GoalAdjustmentValueChange {
  const item: GoalAdjustmentValueChange = {
    changed: changed,
    currentText: currentText,
    nextText: nextText,
    description: description
  }
  return item
}

function createGoalAdjustmentListChange(
  changed: boolean,
  currentIds: string[],
  nextIds: string[],
  currentText: string,
  nextText: string,
  addedIds: string[],
  removedIds: string[],
  addedText: string,
  removedText: string,
  description: string
): GoalAdjustmentListChange {
  const item: GoalAdjustmentListChange = {
    changed: changed,
    currentIds: currentIds,
    nextIds: nextIds,
    currentText: currentText,
    nextText: nextText,
    addedIds: addedIds,
    removedIds: removedIds,
    addedText: addedText,
    removedText: removedText,
    description: description
  }
  return item
}

function createGoalAdjustmentPlanSnapshot(
  planName: string,
  weeklyDays: number,
  trainingDayCount: number,
  totalExercises: number,
  focusSummary: string,
  dailySummaries: string[]
): GoalAdjustmentPlanSnapshot {
  const item: GoalAdjustmentPlanSnapshot = {
    planName: planName,
    weeklyDays: weeklyDays,
    trainingDayCount: trainingDayCount,
    totalExercises: totalExercises,
    focusSummary: focusSummary,
    dailySummaries: dailySummaries
  }
  return item
}

class GoalAdjustmentPreviewService {
  createPreview(
    currentGoal: UserGoal,
    currentPlan: TrainingPlan,
    selection: GoalSetupPrefill,
    now: number
  ): GoalAdjustmentPreviewResult {
    const previewGoal: UserGoal = createUserGoal(
      currentGoal.goalId,
      selection.goalType,
      selection.level,
      selection.weeklyDays,
      selection.sessionMinutes,
      this.copyStringArray(selection.equipmentIds),
      this.copyStringArray(selection.restrictedMuscleIds),
      currentGoal.createdAt,
      now
    )
    const previewPlan: TrainingPlan = PlanEngine.generatePlan(previewGoal)
    const goalTypeChange: GoalAdjustmentValueChange = this.createGoalTypeChange(currentGoal.goalType, selection.goalType)
    const weeklyDaysChange: GoalAdjustmentValueChange = this.createWeeklyDaysChange(currentGoal.weeklyDays, selection.weeklyDays)
    const sessionMinutesChange: GoalAdjustmentValueChange = this.createSessionMinutesChange(
      currentGoal.sessionMinutes,
      selection.sessionMinutes
    )
    const equipmentChange: GoalAdjustmentListChange = this.createEquipmentChange(
      currentGoal.equipmentIds,
      selection.equipmentIds
    )
    const restrictedMuscleChange: GoalAdjustmentListChange = this.createRestrictedMuscleChange(
      currentGoal.restrictedMuscleIds,
      selection.restrictedMuscleIds
    )
    const changedKeys: string[] = this.collectChangedKeys(
      goalTypeChange,
      weeklyDaysChange,
      sessionMinutesChange,
      equipmentChange,
      restrictedMuscleChange
    )
    const currentPlanSnapshot: GoalAdjustmentPlanSnapshot = this.createPlanSnapshot(currentPlan)
    const previewPlanSnapshot: GoalAdjustmentPlanSnapshot = this.createPlanSnapshot(previewPlan)
    const planChanged: boolean = this.hasPlanChanged(currentPlan, previewPlan)
    const summaryHighlights: string[] = this.createSummaryHighlights(
      goalTypeChange,
      weeklyDaysChange,
      sessionMinutesChange,
      equipmentChange,
      restrictedMuscleChange,
      currentPlanSnapshot,
      previewPlanSnapshot,
      planChanged
    )
    const result: GoalAdjustmentPreviewResult = {
      hasChanges: changedKeys.length > 0,
      changeCount: changedKeys.length,
      changedKeys: changedKeys,
      previewGoal: previewGoal,
      previewPlan: previewPlan,
      goalTypeChange: goalTypeChange,
      weeklyDaysChange: weeklyDaysChange,
      sessionMinutesChange: sessionMinutesChange,
      equipmentChange: equipmentChange,
      restrictedMuscleChange: restrictedMuscleChange,
      currentPlanSnapshot: currentPlanSnapshot,
      previewPlanSnapshot: previewPlanSnapshot,
      planChanged: planChanged,
      overviewText: this.createOverviewText(changedKeys, previewPlanSnapshot, planChanged),
      arrangementChangeText: this.createArrangementChangeText(currentPlanSnapshot, previewPlanSnapshot, planChanged),
      summaryHighlights: summaryHighlights
    }
    return result
  }

  private createGoalTypeChange(currentGoalType: string, nextGoalType: string): GoalAdjustmentValueChange {
    const currentText: string = this.getGoalTypeLabel(currentGoalType)
    const nextText: string = this.getGoalTypeLabel(nextGoalType)
    const changed: boolean = currentGoalType !== nextGoalType
    const description: string = changed
      ? '目标从' + currentText + '调整为' + nextText
      : '目标保持' + currentText
    return createGoalAdjustmentValueChange(changed, currentText, nextText, description)
  }

  private createWeeklyDaysChange(currentWeeklyDays: number, nextWeeklyDays: number): GoalAdjustmentValueChange {
    const currentText: string = this.createWeeklyDaysText(currentWeeklyDays)
    const nextText: string = this.createWeeklyDaysText(nextWeeklyDays)
    const changed: boolean = currentWeeklyDays !== nextWeeklyDays
    const description: string = changed
      ? '每周训练频率由' + currentText + '调整为' + nextText
      : '每周训练频率保持' + currentText
    return createGoalAdjustmentValueChange(changed, currentText, nextText, description)
  }

  private createSessionMinutesChange(currentSessionMinutes: number, nextSessionMinutes: number): GoalAdjustmentValueChange {
    const currentText: string = this.createSessionMinutesText(currentSessionMinutes)
    const nextText: string = this.createSessionMinutesText(nextSessionMinutes)
    const changed: boolean = currentSessionMinutes !== nextSessionMinutes
    const description: string = changed
      ? '单次训练时长由' + currentText + '调整为' + nextText
      : '单次训练时长保持' + currentText
    return createGoalAdjustmentValueChange(changed, currentText, nextText, description)
  }

  private createEquipmentChange(currentEquipmentIds: string[], nextEquipmentIds: string[]): GoalAdjustmentListChange {
    return this.createListChange(currentEquipmentIds, nextEquipmentIds, true, '器械条件')
  }

  private createRestrictedMuscleChange(currentMuscleIds: string[], nextMuscleIds: string[]): GoalAdjustmentListChange {
    return this.createListChange(currentMuscleIds, nextMuscleIds, false, '限制肌群')
  }

  private createListChange(
    currentIds: string[],
    nextIds: string[],
    isEquipment: boolean,
    title: string
  ): GoalAdjustmentListChange {
    const normalizedCurrentIds: string[] = this.normalizeIdList(currentIds)
    const normalizedNextIds: string[] = this.normalizeIdList(nextIds)
    const changed: boolean = !this.areStringArraysEqual(normalizedCurrentIds, normalizedNextIds)
    const addedIds: string[] = this.findAddedIds(normalizedCurrentIds, normalizedNextIds)
    const removedIds: string[] = this.findAddedIds(normalizedNextIds, normalizedCurrentIds)
    const currentText: string = this.createNamedListText(normalizedCurrentIds, isEquipment)
    const nextText: string = this.createNamedListText(normalizedNextIds, isEquipment)
    const addedText: string = this.createNamedListText(addedIds, isEquipment)
    const removedText: string = this.createNamedListText(removedIds, isEquipment)
    let description: string = title + '保持' + currentText
    if (changed) {
      description = title + '从' + currentText + '调整为' + nextText
      if (addedIds.length > 0 || removedIds.length > 0) {
        description += '；新增' + addedText + '；移除' + removedText
      }
    }
    return createGoalAdjustmentListChange(
      changed,
      normalizedCurrentIds,
      normalizedNextIds,
      currentText,
      nextText,
      addedIds,
      removedIds,
      addedText,
      removedText,
      description
    )
  }

  private collectChangedKeys(
    goalTypeChange: GoalAdjustmentValueChange,
    weeklyDaysChange: GoalAdjustmentValueChange,
    sessionMinutesChange: GoalAdjustmentValueChange,
    equipmentChange: GoalAdjustmentListChange,
    restrictedMuscleChange: GoalAdjustmentListChange
  ): string[] {
    const changedKeys: string[] = []
    if (goalTypeChange.changed) {
      changedKeys.push('goalType')
    }
    if (weeklyDaysChange.changed) {
      changedKeys.push('weeklyDays')
    }
    if (sessionMinutesChange.changed) {
      changedKeys.push('sessionMinutes')
    }
    if (equipmentChange.changed) {
      changedKeys.push('equipmentIds')
    }
    if (restrictedMuscleChange.changed) {
      changedKeys.push('restrictedMuscleIds')
    }
    return changedKeys
  }

  private createPlanSnapshot(plan: TrainingPlan): GoalAdjustmentPlanSnapshot {
    const dailySummaries: string[] = []
    const focusNames: string[] = []
    let totalExercises: number = 0
    let trainingDayCount: number = 0
    for (let index = 0; index < plan.days.length; index++) {
      const day: PlanDay = plan.days[index]
      totalExercises += day.exercises.length
      if (day.exercises.length > 0) {
        trainingDayCount += 1
      }
      this.appendUniqueFocusNames(focusNames, day.focusMuscleIds)
      dailySummaries.push(this.createDailySummary(day))
    }
    const snapshot: GoalAdjustmentPlanSnapshot = createGoalAdjustmentPlanSnapshot(
      plan.name,
      plan.days.length,
      trainingDayCount,
      totalExercises,
      this.createSortedJoinedText(focusNames, '、', '暂无'),
      dailySummaries
    )
    return snapshot
  }

  private createDailySummary(day: PlanDay): string {
    const focusText: string = this.createNamedListText(day.focusMuscleIds, false)
    const exerciseText: string = this.createExerciseSummary(day.exercises)
    return day.title + '：' + focusText + '，' + day.exercises.length.toString() + ' 个动作（' + exerciseText + '）'
  }

  private createExerciseSummary(exercises: PlannedExercise[]): string {
    if (exercises.length === 0) {
      return '休息'
    }
    const names: string[] = []
    let limit: number = exercises.length
    if (limit > 3) {
      limit = 3
    }
    for (let index = 0; index < limit; index++) {
      const exerciseName: string = this.getExerciseName(exercises[index].exerciseId)
      names.push(exerciseName)
    }
    let text: string = this.createSortedJoinedText(names, '、', '休息')
    if (exercises.length > 3) {
      text += '等'
    }
    return text
  }

  private createSummaryHighlights(
    goalTypeChange: GoalAdjustmentValueChange,
    weeklyDaysChange: GoalAdjustmentValueChange,
    sessionMinutesChange: GoalAdjustmentValueChange,
    equipmentChange: GoalAdjustmentListChange,
    restrictedMuscleChange: GoalAdjustmentListChange,
    currentPlanSnapshot: GoalAdjustmentPlanSnapshot,
    previewPlanSnapshot: GoalAdjustmentPlanSnapshot,
    planChanged: boolean
  ): string[] {
    const highlights: string[] = []
    if (goalTypeChange.changed) {
      highlights.push(goalTypeChange.description)
    }
    if (weeklyDaysChange.changed) {
      highlights.push(weeklyDaysChange.description)
    }
    if (sessionMinutesChange.changed) {
      highlights.push(sessionMinutesChange.description)
    }
    if (equipmentChange.changed) {
      highlights.push(equipmentChange.description)
    }
    if (restrictedMuscleChange.changed) {
      highlights.push(restrictedMuscleChange.description)
    }
    if (planChanged) {
      highlights.push(
        '计划概览由每周' + currentPlanSnapshot.weeklyDays.toString() + '天 / ' +
        currentPlanSnapshot.totalExercises.toString() + '个动作调整为每周' +
        previewPlanSnapshot.weeklyDays.toString() + '天 / ' +
        previewPlanSnapshot.totalExercises.toString() + '个动作'
      )
    } else {
      highlights.push(
        '训练安排保持每周' + previewPlanSnapshot.weeklyDays.toString() + '天 / ' +
        previewPlanSnapshot.totalExercises.toString() + '个动作'
      )
    }
    return highlights
  }

  private createOverviewText(
    changedKeys: string[],
    previewPlanSnapshot: GoalAdjustmentPlanSnapshot,
    planChanged: boolean
  ): string {
    if (changedKeys.length === 0) {
      return '当前选择与现有目标一致，计划保持不变。'
    }
    const changeLabelText: string = this.createChangeLabelText(changedKeys)
    if (planChanged) {
      return '已检测到' + changeLabelText + '变化，预览计划将更新为每周' +
        previewPlanSnapshot.weeklyDays.toString() + '天，共' +
        previewPlanSnapshot.totalExercises.toString() + '个动作。'
    }
    return '已检测到' + changeLabelText + '变化，训练安排暂不变化，可直接按新偏好保存。'
  }

  private createArrangementChangeText(
    currentPlanSnapshot: GoalAdjustmentPlanSnapshot,
    previewPlanSnapshot: GoalAdjustmentPlanSnapshot,
    planChanged: boolean
  ): string {
    if (!planChanged) {
      return '训练安排保持每周' + previewPlanSnapshot.weeklyDays.toString() + '天，重点肌群仍为' +
        previewPlanSnapshot.focusSummary + '。'
    }
    return '训练安排由每周' + currentPlanSnapshot.weeklyDays.toString() + '天、' +
      currentPlanSnapshot.totalExercises.toString() + '个动作、重点' + currentPlanSnapshot.focusSummary +
      '，调整为每周' + previewPlanSnapshot.weeklyDays.toString() + '天、' +
      previewPlanSnapshot.totalExercises.toString() + '个动作、重点' + previewPlanSnapshot.focusSummary + '。'
  }

  private createChangeLabelText(changedKeys: string[]): string {
    const labels: string[] = []
    for (let index = 0; index < changedKeys.length; index++) {
      labels.push(this.getChangeKeyLabel(changedKeys[index]))
    }
    return this.createSortedJoinedText(labels, '、', '设置')
  }

  private getChangeKeyLabel(changedKey: string): string {
    if (changedKey === 'goalType') {
      return '目标类型'
    }
    if (changedKey === 'weeklyDays') {
      return '训练天数'
    }
    if (changedKey === 'sessionMinutes') {
      return '训练时长'
    }
    if (changedKey === 'equipmentIds') {
      return '器械'
    }
    if (changedKey === 'restrictedMuscleIds') {
      return '限制肌群'
    }
    return changedKey
  }

  private hasPlanChanged(currentPlan: TrainingPlan, previewPlan: TrainingPlan): boolean {
    if (currentPlan.name !== previewPlan.name) {
      return true
    }
    if (currentPlan.days.length !== previewPlan.days.length) {
      return true
    }
    for (let index = 0; index < currentPlan.days.length; index++) {
      if (this.hasDayChanged(currentPlan.days[index], previewPlan.days[index])) {
        return true
      }
    }
    return false
  }

  private hasDayChanged(currentDay: PlanDay, previewDay: PlanDay): boolean {
    if (!this.areStringArraysEqual(
      this.normalizeIdList(currentDay.focusMuscleIds),
      this.normalizeIdList(previewDay.focusMuscleIds)
    )) {
      return true
    }
    if (currentDay.exercises.length !== previewDay.exercises.length) {
      return true
    }
    for (let index = 0; index < currentDay.exercises.length; index++) {
      if (this.hasExerciseChanged(currentDay.exercises[index], previewDay.exercises[index])) {
        return true
      }
    }
    return false
  }

  private hasExerciseChanged(currentExercise: PlannedExercise, previewExercise: PlannedExercise): boolean {
    if (currentExercise.exerciseId !== previewExercise.exerciseId) {
      return true
    }
    if (currentExercise.targetSets !== previewExercise.targetSets) {
      return true
    }
    if (currentExercise.targetReps !== previewExercise.targetReps) {
      return true
    }
    if (currentExercise.intensityNote !== previewExercise.intensityNote) {
      return true
    }
    return false
  }

  private createNamedListText(ids: string[], isEquipment: boolean): string {
    if (ids.length === 0) {
      if (isEquipment) {
        return '徒手'
      }
      return '无'
    }
    const names: string[] = []
    for (let index = 0; index < ids.length; index++) {
      if (isEquipment) {
        names.push(ContentRepository.getEquipmentName(ids[index]))
      } else {
        names.push(ContentRepository.getMuscleName(ids[index]))
      }
    }
    return this.createSortedJoinedText(names, '、', '无')
  }

  private createWeeklyDaysText(weeklyDays: number): string {
    return '每周' + weeklyDays.toString() + '天'
  }

  private createSessionMinutesText(sessionMinutes: number): string {
    return sessionMinutes.toString() + '分钟'
  }

  private getGoalTypeLabel(goalType: string): string {
    if (goalType === 'hypertrophy') {
      return '增肌'
    }
    if (goalType === 'strength') {
      return '力量'
    }
    if (goalType === 'fat_loss') {
      return '减脂'
    }
    if (goalType === 'posture') {
      return '体态'
    }
    return goalType
  }

  private getExerciseName(exerciseId: string): string {
    const exercise = ContentRepository.getExerciseById(exerciseId)
    if (exercise === undefined) {
      return exerciseId
    }
    return exercise.nameZh
  }

  private appendUniqueFocusNames(targetNames: string[], focusMuscleIds: string[]): void {
    for (let index = 0; index < focusMuscleIds.length; index++) {
      const muscleName: string = ContentRepository.getMuscleName(focusMuscleIds[index])
      if (!this.containsValue(targetNames, muscleName)) {
        targetNames.push(muscleName)
      }
    }
  }

  private findAddedIds(baseIds: string[], targetIds: string[]): string[] {
    const ids: string[] = []
    for (let index = 0; index < targetIds.length; index++) {
      const targetId: string = targetIds[index]
      if (!this.containsValue(baseIds, targetId)) {
        ids.push(targetId)
      }
    }
    return ids
  }

  private normalizeIdList(source: string[]): string[] {
    const ids: string[] = []
    for (let index = 0; index < source.length; index++) {
      const value: string = source[index]
      if (!this.containsValue(ids, value)) {
        ids.push(value)
      }
    }
    ids.sort((left: string, right: string): number => {
      if (left < right) {
        return -1
      }
      if (left > right) {
        return 1
      }
      return 0
    })
    return ids
  }

  private createSortedJoinedText(source: string[], separator: string, fallbackText: string): string {
    if (source.length === 0) {
      return fallbackText
    }
    const values: string[] = this.copyStringArray(source)
    values.sort((left: string, right: string): number => {
      if (left < right) {
        return -1
      }
      if (left > right) {
        return 1
      }
      return 0
    })
    let text: string = ''
    for (let index = 0; index < values.length; index++) {
      if (index > 0) {
        text += separator
      }
      text += values[index]
    }
    return text
  }

  private areStringArraysEqual(leftValues: string[], rightValues: string[]): boolean {
    if (leftValues.length !== rightValues.length) {
      return false
    }
    for (let index = 0; index < leftValues.length; index++) {
      if (leftValues[index] !== rightValues[index]) {
        return false
      }
    }
    return true
  }

  private copyStringArray(source: string[]): string[] {
    const values: string[] = []
    for (let index = 0; index < source.length; index++) {
      values.push(source[index])
    }
    return values
  }

  private containsValue(values: string[], targetValue: string): boolean {
    for (let index = 0; index < values.length; index++) {
      if (values[index] === targetValue) {
        return true
      }
    }
    return false
  }
}

export default new GoalAdjustmentPreviewService()
