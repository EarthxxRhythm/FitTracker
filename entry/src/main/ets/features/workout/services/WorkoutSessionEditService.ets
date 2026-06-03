/**
 * WorkoutSessionEditService —— 已保存训练记录编辑态纯逻辑服务
 *
 * 功能 #11：训练总结后的记录修正
 */
import {
  WorkoutSession,
  WorkoutSet,
  createWorkoutSession,
  createWorkoutSet,
  estimateOneRepMax
} from '../../../shared/models/TrainingModels'

const COMPLETED_SETS_PREFIX: string = 'completed_sets='
const TARGET_SETS_PREFIX: string = 'target_sets='

export interface WorkoutSessionEditSet {
  setId: string
  exerciseId: string
  weightText: string
  repsText: string
  weight: number
  reps: number
  rpe: number
  isWarmup: boolean
  estimatedOneRepMax: number
  isComplete: boolean
}

export interface WorkoutSessionEditModel {
  sessionId: string
  planId: string
  dayId: string
  startedAt: number
  endedAt: number
  durationSeconds: number
  fatigueScore: number
  targetSets: number
  completedSets: number
  customNotes: string
  sets: WorkoutSessionEditSet[]
}

interface ParsedSessionNotes {
  targetSets: number
  customNotes: string
}

class WorkoutSessionEditService {
  createEditModel(session: WorkoutSession): WorkoutSessionEditModel {
    const parsedNotes: ParsedSessionNotes = this.parseSessionNotes(session.notes, session.totalSets)
    const sets: WorkoutSessionEditSet[] = this.createEditSets(session.sets)
    const model: WorkoutSessionEditModel = {
      sessionId: session.sessionId,
      planId: session.planId,
      dayId: session.dayId,
      startedAt: session.startedAt,
      endedAt: session.endedAt,
      durationSeconds: session.durationSeconds,
      fatigueScore: session.fatigueScore,
      targetSets: parsedNotes.targetSets,
      completedSets: this.countCompletedSets(sets),
      customNotes: parsedNotes.customNotes,
      sets: sets
    }
    return model
  }

  updateSetEntry(
    model: WorkoutSessionEditModel,
    setId: string,
    weightText: string,
    repsText: string
  ): WorkoutSessionEditModel {
    const sets: WorkoutSessionEditSet[] = []
    for (let index = 0; index < model.sets.length; index++) {
      const set: WorkoutSessionEditSet = model.sets[index]
      if (set.setId === setId) {
        sets.push(this.createEditSet(set.setId, set.exerciseId, weightText, repsText, set.rpe, set.isWarmup))
      } else {
        sets.push(this.copyEditSet(set))
      }
    }
    return this.createModelWithSets(model, sets)
  }

  updateSetWeight(
    model: WorkoutSessionEditModel,
    setId: string,
    weightText: string
  ): WorkoutSessionEditModel {
    const repsText: string = this.findSetRepsText(model.sets, setId)
    return this.updateSetEntry(model, setId, weightText, repsText)
  }

  updateSetReps(
    model: WorkoutSessionEditModel,
    setId: string,
    repsText: string
  ): WorkoutSessionEditModel {
    const weightText: string = this.findSetWeightText(model.sets, setId)
    return this.updateSetEntry(model, setId, weightText, repsText)
  }

  createCorrectedSession(model: WorkoutSessionEditModel): WorkoutSession {
    const sets: WorkoutSet[] = this.createWorkoutSets(model.sets)
    const session: WorkoutSession = createWorkoutSession(
      model.sessionId,
      model.planId,
      model.dayId,
      model.startedAt,
      model.endedAt,
      model.durationSeconds,
      this.countCompletedSets(model.sets),
      this.calculateTotalVolume(sets),
      model.fatigueScore,
      this.createSessionNotes(this.countCompletedSets(model.sets), model.targetSets, model.customNotes),
      sets
    )
    return session
  }

  private createModelWithSets(model: WorkoutSessionEditModel, sets: WorkoutSessionEditSet[]): WorkoutSessionEditModel {
    const nextModel: WorkoutSessionEditModel = {
      sessionId: model.sessionId,
      planId: model.planId,
      dayId: model.dayId,
      startedAt: model.startedAt,
      endedAt: model.endedAt,
      durationSeconds: model.durationSeconds,
      fatigueScore: model.fatigueScore,
      targetSets: model.targetSets,
      completedSets: this.countCompletedSets(sets),
      customNotes: model.customNotes,
      sets: sets
    }
    return nextModel
  }

  private createEditSets(source: WorkoutSet[]): WorkoutSessionEditSet[] {
    const sets: WorkoutSessionEditSet[] = []
    for (let index = 0; index < source.length; index++) {
      const set: WorkoutSet = source[index]
      sets.push(
        this.createEditSet(
          set.setId,
          set.exerciseId,
          this.createWeightText(set.weight),
          this.createRepsText(set.reps),
          set.rpe,
          set.isWarmup
        )
      )
    }
    return sets
  }

  private createEditSet(
    setId: string,
    exerciseId: string,
    weightText: string,
    repsText: string,
    rpe: number,
    isWarmup: boolean
  ): WorkoutSessionEditSet {
    const weight: number = this.parsePositiveNumber(weightText)
    const reps: number = this.parsePositiveInteger(repsText)
    let estimatedOneRepMax: number = 0
    let isComplete: boolean = false

    if (weight > 0 && reps > 0) {
      estimatedOneRepMax = Math.round(estimateOneRepMax(weight, reps))
      isComplete = true
    }

    const set: WorkoutSessionEditSet = {
      setId: setId,
      exerciseId: exerciseId,
      weightText: weightText,
      repsText: repsText,
      weight: weight,
      reps: reps,
      rpe: rpe,
      isWarmup: isWarmup,
      estimatedOneRepMax: estimatedOneRepMax,
      isComplete: isComplete
    }
    return set
  }

  private copyEditSet(source: WorkoutSessionEditSet): WorkoutSessionEditSet {
    const set: WorkoutSessionEditSet = {
      setId: source.setId,
      exerciseId: source.exerciseId,
      weightText: source.weightText,
      repsText: source.repsText,
      weight: source.weight,
      reps: source.reps,
      rpe: source.rpe,
      isWarmup: source.isWarmup,
      estimatedOneRepMax: source.estimatedOneRepMax,
      isComplete: source.isComplete
    }
    return set
  }

  private findSetWeightText(sets: WorkoutSessionEditSet[], setId: string): string {
    for (let index = 0; index < sets.length; index++) {
      if (sets[index].setId === setId) {
        return sets[index].weightText
      }
    }
    return ''
  }

  private findSetRepsText(sets: WorkoutSessionEditSet[], setId: string): string {
    for (let index = 0; index < sets.length; index++) {
      if (sets[index].setId === setId) {
        return sets[index].repsText
      }
    }
    return ''
  }

  private createWorkoutSets(source: WorkoutSessionEditSet[]): WorkoutSet[] {
    const sets: WorkoutSet[] = []
    for (let index = 0; index < source.length; index++) {
      const set: WorkoutSessionEditSet = source[index]
      if (set.isComplete) {
        sets.push(createWorkoutSet(set.setId, set.exerciseId, set.weight, set.reps, set.rpe, set.isWarmup))
      }
    }
    return sets
  }

  private countCompletedSets(sets: WorkoutSessionEditSet[]): number {
    let count: number = 0
    for (let index = 0; index < sets.length; index++) {
      if (sets[index].isComplete) {
        count++
      }
    }
    return count
  }

  private calculateTotalVolume(sets: WorkoutSet[]): number {
    let totalVolume: number = 0
    for (let index = 0; index < sets.length; index++) {
      totalVolume += sets[index].weight * sets[index].reps
    }
    return Math.round(totalVolume * 100) / 100
  }

  private parseSessionNotes(notes: string, fallbackTargetSets: number): ParsedSessionNotes {
    const parts: string[] = this.splitNotes(notes)
    const customParts: string[] = []
    let targetSets: number = fallbackTargetSets

    for (let index = 0; index < parts.length; index++) {
      const part: string = parts[index]
      if (this.startsWith(part, TARGET_SETS_PREFIX)) {
        const parsed: number = this.parsePositiveInteger(part.substring(TARGET_SETS_PREFIX.length))
        if (parsed > 0) {
          targetSets = parsed
        }
      } else if (!this.startsWith(part, COMPLETED_SETS_PREFIX) && !this.isEmptyText(part)) {
        customParts.push(part)
      }
    }

    const parsedNotes: ParsedSessionNotes = {
      targetSets: targetSets,
      customNotes: this.joinNotes(customParts)
    }
    return parsedNotes
  }

  private createSessionNotes(completedSets: number, targetSets: number, customNotes: string): string {
    const parts: string[] = []
    parts.push(COMPLETED_SETS_PREFIX + completedSets.toString())
    parts.push(TARGET_SETS_PREFIX + targetSets.toString())

    const customParts: string[] = this.splitNotes(customNotes)
    for (let index = 0; index < customParts.length; index++) {
      const part: string = customParts[index]
      if (!this.isEmptyText(part)) {
        parts.push(part)
      }
    }
    return this.joinNotes(parts)
  }

  private splitNotes(notes: string): string[] {
    if (this.isEmptyText(notes)) {
      const values: string[] = []
      return values
    }
    return notes.split(';')
  }

  private joinNotes(parts: string[]): string {
    let notes: string = ''
    for (let index = 0; index < parts.length; index++) {
      const part: string = parts[index]
      if (this.isEmptyText(part)) {
        continue
      }
      if (notes.length > 0) {
        notes += ';'
      }
      notes += part
    }
    return notes
  }

  private isEmptyText(value: string): boolean {
    return value.trim().length === 0
  }

  private startsWith(value: string, prefix: string): boolean {
    return value.indexOf(prefix) === 0
  }

  private createWeightText(value: number): string {
    if (value <= 0) {
      return ''
    }
    return value.toString()
  }

  private createRepsText(value: number): string {
    if (value <= 0) {
      return ''
    }
    return Math.floor(value).toString()
  }

  private parsePositiveNumber(value: string): number {
    const parsed: number = Number(value)
    if (Number.isNaN(parsed) || parsed <= 0) {
      return 0
    }
    return parsed
  }

  private parsePositiveInteger(value: string): number {
    const parsed: number = Math.floor(Number(value))
    if (Number.isNaN(parsed) || parsed <= 0) {
      return 0
    }
    return parsed
  }
}

export default new WorkoutSessionEditService()
