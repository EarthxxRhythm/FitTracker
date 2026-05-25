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
