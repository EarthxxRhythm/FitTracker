/**
 * PersonalRecordService -- per-exercise historical personal records.
 *
 * Feature #25: exercise history best 1RM, best weight and best reps.
 */
import { ExerciseContent, WorkoutSession, WorkoutSet, estimateOneRepMax } from '../models/TrainingModels'
import ContentRepository from './ContentRepository'

export class ExercisePersonalRecord {
  exerciseId: string = ''
  exerciseName: string = ''
  bestOneRepMax: number = 0
  bestWeight: number = 0
  bestReps: number = 0
  bestDateText: string = ''
}

export class ExercisePersonalRecordDetail {
  exerciseId: string = ''
  exerciseName: string = ''
  bestOneRepMax: number = 0
  bestWeight: number = 0
  bestReps: number = 0
  bestDateText: string = ''
  lastPerformedAt: number = 0
  lastPerformedDateText: string = ''
  sessionCount: number = 0
  performedSetCount: number = 0
  recentOneRepMax: number = 0
  recentWeight: number = 0
  recentReps: number = 0
  recentVolume: number = 0
  trendText: string = ''
}

class PersonalRecordService {
  createRecords(sessions: WorkoutSession[]): ExercisePersonalRecord[] {
    const records: ExercisePersonalRecord[] = []
    for (let sessionIndex = 0; sessionIndex < sessions.length; sessionIndex++) {
      const session: WorkoutSession = sessions[sessionIndex]
      for (let setIndex = 0; setIndex < session.sets.length; setIndex++) {
        const set: WorkoutSet = session.sets[setIndex]
        if (!this.isRecordableSet(set)) {
          continue
        }
        const record: ExercisePersonalRecord = this.findOrCreateRecord(records, set.exerciseId)
        this.updateRecord(record, session, set)
      }
    }
    return records
  }

  createRecordDetails(sessions: WorkoutSession[]): ExercisePersonalRecordDetail[] {
    const details: ExercisePersonalRecordDetail[] = []
    for (let sessionIndex = 0; sessionIndex < sessions.length; sessionIndex++) {
      const session: WorkoutSession = sessions[sessionIndex]
      const countedExerciseIds: string[] = []
      for (let setIndex = 0; setIndex < session.sets.length; setIndex++) {
        const set: WorkoutSet = session.sets[setIndex]
        if (!this.isRecordableSet(set)) {
          continue
        }
        const detail: ExercisePersonalRecordDetail = this.findOrCreateRecordDetail(details, set.exerciseId)
        if (!this.containsExerciseId(countedExerciseIds, set.exerciseId)) {
          countedExerciseIds.push(set.exerciseId)
          detail.sessionCount += 1
        }
        detail.performedSetCount += 1
        this.updateRecordDetail(detail, session, set)
      }
    }
    this.sortRecordDetails(details)
    return details
  }

  createEmptyRecordDetail(): ExercisePersonalRecordDetail {
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
      trendText: '完成训练后，这里会显示动作纪录变化。'
    }
    return detail
  }

  private updateRecord(record: ExercisePersonalRecord, session: WorkoutSession, set: WorkoutSet): void {
    const oneRepMax: number = Math.round(estimateOneRepMax(set.weight, set.reps))
    if (oneRepMax > record.bestOneRepMax) {
      record.bestOneRepMax = oneRepMax
      record.bestDateText = this.formatDate(session.startedAt)
    } else if (oneRepMax === record.bestOneRepMax && record.bestDateText.length === 0) {
      record.bestDateText = this.formatDate(session.startedAt)
    }
    if (set.weight > record.bestWeight) {
      record.bestWeight = set.weight
    }
    if (set.reps > record.bestReps) {
      record.bestReps = set.reps
    }
  }

  private findOrCreateRecord(records: ExercisePersonalRecord[], exerciseId: string): ExercisePersonalRecord {
    for (let index = 0; index < records.length; index++) {
      const record: ExercisePersonalRecord = records[index]
      if (record.exerciseId === exerciseId) {
        return record
      }
    }
    const record: ExercisePersonalRecord = {
      exerciseId: exerciseId,
      exerciseName: this.getExerciseName(exerciseId),
      bestOneRepMax: 0,
      bestWeight: 0,
      bestReps: 0,
      bestDateText: ''
    }
    records.push(record)
    return record
  }

  private findOrCreateRecordDetail(details: ExercisePersonalRecordDetail[], exerciseId: string): ExercisePersonalRecordDetail {
    for (let index = 0; index < details.length; index++) {
      const detail: ExercisePersonalRecordDetail = details[index]
      if (detail.exerciseId === exerciseId) {
        return detail
      }
    }
    const detail: ExercisePersonalRecordDetail = {
      exerciseId: exerciseId,
      exerciseName: this.getExerciseName(exerciseId),
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
    details.push(detail)
    return detail
  }

  private updateRecordDetail(detail: ExercisePersonalRecordDetail, session: WorkoutSession, set: WorkoutSet): void {
    const oneRepMax: number = Math.round(estimateOneRepMax(set.weight, set.reps))
    if (oneRepMax > detail.bestOneRepMax) {
      detail.bestOneRepMax = oneRepMax
      detail.bestDateText = this.formatDate(session.startedAt)
    } else if (oneRepMax === detail.bestOneRepMax && detail.bestDateText.length === 0) {
      detail.bestDateText = this.formatDate(session.startedAt)
    }
    if (set.weight > detail.bestWeight) {
      detail.bestWeight = set.weight
    }
    if (set.reps > detail.bestReps) {
      detail.bestReps = set.reps
    }

    const setVolume: number = set.weight * set.reps
    if (session.startedAt > detail.lastPerformedAt) {
      detail.lastPerformedAt = session.startedAt
      detail.lastPerformedDateText = this.formatDate(session.startedAt)
      detail.recentOneRepMax = oneRepMax
      detail.recentWeight = set.weight
      detail.recentReps = set.reps
      detail.recentVolume = setVolume
    } else if (session.startedAt === detail.lastPerformedAt) {
      if (oneRepMax >= detail.recentOneRepMax) {
        detail.recentOneRepMax = oneRepMax
        detail.recentWeight = set.weight
        detail.recentReps = set.reps
      }
      detail.recentVolume += setVolume
    }

    detail.trendText = this.createTrendText(detail)
  }

  private createTrendText(detail: ExercisePersonalRecordDetail): string {
    if (detail.lastPerformedDateText.length === 0) {
      return '完成训练后，这里会显示动作纪录变化。'
    }
    if (detail.recentOneRepMax >= detail.bestOneRepMax) {
      return '最近一次训练已追平当前 PR。'
    }
    return '最近一次距离 PR 还差 ' + (detail.bestOneRepMax - detail.recentOneRepMax).toString() + ' kg。'
  }

  private containsExerciseId(values: string[], exerciseId: string): boolean {
    for (let index = 0; index < values.length; index++) {
      if (values[index] === exerciseId) {
        return true
      }
    }
    return false
  }

  private sortRecordDetails(details: ExercisePersonalRecordDetail[]): void {
    for (let outerIndex = 0; outerIndex < details.length; outerIndex++) {
      for (let innerIndex = outerIndex + 1; innerIndex < details.length; innerIndex++) {
        if (this.shouldSwapDetails(details[outerIndex], details[innerIndex])) {
          const current: ExercisePersonalRecordDetail = details[outerIndex]
          details[outerIndex] = details[innerIndex]
          details[innerIndex] = current
        }
      }
    }
  }

  private shouldSwapDetails(current: ExercisePersonalRecordDetail, candidate: ExercisePersonalRecordDetail): boolean {
    if (candidate.bestOneRepMax > current.bestOneRepMax) {
      return true
    }
    if (candidate.bestOneRepMax === current.bestOneRepMax && candidate.lastPerformedAt > current.lastPerformedAt) {
      return true
    }
    return false
  }

  private isRecordableSet(set: WorkoutSet): boolean {
    return set.exerciseId.length > 0 && !set.isWarmup && set.weight > 0 && set.reps > 0
  }

  private getExerciseName(exerciseId: string): string {
    const exercise: ExerciseContent | undefined = ContentRepository.getExerciseById(exerciseId)
    if (exercise !== undefined) {
      return exercise.nameZh
    }
    return exerciseId
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

export default new PersonalRecordService()
