/**
 * AdvancedPlanVariantsService -- builds advanced plan upsell copy and pro plan variants.
 *
 * Phase 4: add a real advanced_plans capability on plan-detail surfaces without gating the core workout loop.
 */
import {
  ExerciseRef,
  PresetPlan,
  TrainingDay
} from '../../common/services/TrainingPlanService'
import { MonetizationTier } from '../models/MonetizationModels'

export type AdvancedPlanVariantId = 'volume_boost' | 'density_boost' | 'recovery_friendly'

export class AdvancedPlanVariantCardViewModel {
  variantId: AdvancedPlanVariantId = 'volume_boost'
  badgeText: string = ''
  title: string = ''
  summary: string = ''
  detail: string = ''
  actionText: string = ''
  locked: boolean = true
}

export class AdvancedPlanVariantsPresentation {
  locked: boolean = true
  statusLabel: string = 'Free'
  title: string = '高级计划变体'
  description: string = '升级后可在当前预置计划基础上切换不同训练策略。'
  actionText: string = '查看 Pro 方案'
  cards: AdvancedPlanVariantCardViewModel[] = []
}

export class AdvancedPlanVariantDraft {
  variantId: AdvancedPlanVariantId = 'volume_boost'
  name: string = ''
  targetAudience: string = ''
  weeklyFrequency: string = ''
  days: TrainingDay[] = []
}

class AdvancedPlanVariantsService {
  createDefaultPresentation(): AdvancedPlanVariantsPresentation {
    const emptyPlan: PresetPlan = {
      id: '',
      name: '',
      coverColor: '',
      targetAudience: '',
      weeklyFrequency: '',
      days: []
    }
    return this.createPresentation(emptyPlan, true, 'free')
  }

  createPresentation(
    plan: PresetPlan,
    locked: boolean,
    activeTier: MonetizationTier
  ): AdvancedPlanVariantsPresentation {
    const cards: AdvancedPlanVariantCardViewModel[] = [
      this.createCard('volume_boost', locked),
      this.createCard('density_boost', locked),
      this.createCard('recovery_friendly', locked)
    ]
    const presentation: AdvancedPlanVariantsPresentation = {
      locked: locked,
      statusLabel: this.getStatusLabel(locked, activeTier),
      title: '高级计划变体',
      description: this.getDescription(plan, locked, activeTier),
      actionText: locked ? '查看 Pro 方案' : '启用变体计划',
      cards: cards
    }
    return presentation
  }

  createVariantDraft(plan: PresetPlan, variantId: AdvancedPlanVariantId): AdvancedPlanVariantDraft {
    if (variantId === 'density_boost') {
      return this.createDensityDraft(plan)
    }
    if (variantId === 'recovery_friendly') {
      return this.createRecoveryDraft(plan)
    }
    return this.createVolumeDraft(plan)
  }

  private createVolumeDraft(plan: PresetPlan): AdvancedPlanVariantDraft {
    const draft: AdvancedPlanVariantDraft = {
      variantId: 'volume_boost',
      name: plan.name + ' · 高容量',
      targetAudience: plan.targetAudience + ' · 适合恢复良好时冲量',
      weeklyFrequency: plan.weeklyFrequency + ' · 主动作额外加组',
      days: this.createVolumeDays(plan.days)
    }
    return draft
  }

  private createDensityDraft(plan: PresetPlan): AdvancedPlanVariantDraft {
    const draft: AdvancedPlanVariantDraft = {
      variantId: 'density_boost',
      name: plan.name + ' · 高密度',
      targetAudience: plan.targetAudience + ' · 适合时间更紧时保持效率',
      weeklyFrequency: plan.weeklyFrequency + ' · 单次时长更紧凑',
      days: this.createDensityDays(plan.days)
    }
    return draft
  }

  private createRecoveryDraft(plan: PresetPlan): AdvancedPlanVariantDraft {
    const draft: AdvancedPlanVariantDraft = {
      variantId: 'recovery_friendly',
      name: plan.name + ' · 恢复优先',
      targetAudience: plan.targetAudience + ' · 适合疲劳偏高或恢复周',
      weeklyFrequency: plan.weeklyFrequency + ' · 控制疲劳堆积',
      days: this.createRecoveryDays(plan.days)
    }
    return draft
  }

  private createCard(variantId: AdvancedPlanVariantId, locked: boolean): AdvancedPlanVariantCardViewModel {
    if (variantId === 'density_boost') {
      return this.createDensityCard(locked)
    }
    if (variantId === 'recovery_friendly') {
      return this.createRecoveryCard(locked)
    }
    return this.createVolumeCard(locked)
  }

  private createVolumeCard(locked: boolean): AdvancedPlanVariantCardViewModel {
    const card: AdvancedPlanVariantCardViewModel = {
      variantId: 'volume_boost',
      badgeText: 'Pro',
      title: '高容量变体',
      summary: '保留当前分化结构，给主动作补 1 组冲量。',
      detail: '适合恢复良好、希望在当前周期拉高总训练量时使用。',
      actionText: locked ? '升级解锁' : '启用高容量',
      locked: locked
    }
    return card
  }

  private createDensityCard(locked: boolean): AdvancedPlanVariantCardViewModel {
    const card: AdvancedPlanVariantCardViewModel = {
      variantId: 'density_boost',
      badgeText: 'Pro',
      title: '高密度变体',
      summary: '压缩每次训练长度，优先保留最关键动作。',
      detail: '适合时间更紧的周，把计划收拢到更容易完成的主线版本。',
      actionText: locked ? '升级解锁' : '启用高密度',
      locked: locked
    }
    return card
  }

  private createRecoveryCard(locked: boolean): AdvancedPlanVariantCardViewModel {
    const card: AdvancedPlanVariantCardViewModel = {
      variantId: 'recovery_friendly',
      badgeText: 'Plus',
      title: '恢复优先变体',
      summary: '降低辅助动作负荷，优先保留技术与节奏。',
      detail: '适合疲劳偏高、睡眠不足或想把训练周做得更稳的时候使用。',
      actionText: locked ? '升级解锁' : '启用恢复优先',
      locked: locked
    }
    return card
  }

  private createVolumeDays(source: TrainingDay[]): TrainingDay[] {
    const days: TrainingDay[] = []
    for (let dayIndex = 0; dayIndex < source.length; dayIndex++) {
      const sourceDay: TrainingDay = source[dayIndex]
      const exercises: ExerciseRef[] = []
      for (let exerciseIndex = 0; exerciseIndex < sourceDay.exercises.length; exerciseIndex++) {
        const sourceExercise: ExerciseRef = sourceDay.exercises[exerciseIndex]
        let nextSets: number = sourceExercise.sets
        if (exerciseIndex < 3) {
          nextSets = nextSets + 1
        }
        const exercise: ExerciseRef = {
          name: sourceExercise.name,
          targetMuscle: sourceExercise.targetMuscle,
          sets: nextSets,
          reps: sourceExercise.reps
        }
        exercises.push(exercise)
      }
      const day: TrainingDay = {
        dayLabel: sourceDay.dayLabel,
        dayOfWeek: this.copyDayOfWeek(sourceDay.dayOfWeek),
        exercises: exercises
      }
      days.push(day)
    }
    return days
  }

  private createDensityDays(source: TrainingDay[]): TrainingDay[] {
    const days: TrainingDay[] = []
    for (let dayIndex = 0; dayIndex < source.length; dayIndex++) {
      const sourceDay: TrainingDay = source[dayIndex]
      const exercises: ExerciseRef[] = []
      const maxCount: number = sourceDay.exercises.length > 4 ? 4 : sourceDay.exercises.length
      for (let exerciseIndex = 0; exerciseIndex < maxCount; exerciseIndex++) {
        const sourceExercise: ExerciseRef = sourceDay.exercises[exerciseIndex]
        let reps: string = sourceExercise.reps
        let sets: number = sourceExercise.sets
        if (exerciseIndex < 2) {
          if (sets < 4) {
            sets = 4
          }
          reps = '6-10'
        } else if (exerciseIndex === maxCount - 1) {
          reps = '10-12'
        }
        const exercise: ExerciseRef = {
          name: sourceExercise.name,
          targetMuscle: sourceExercise.targetMuscle,
          sets: sets,
          reps: reps
        }
        exercises.push(exercise)
      }
      const day: TrainingDay = {
        dayLabel: sourceDay.dayLabel,
        dayOfWeek: this.copyDayOfWeek(sourceDay.dayOfWeek),
        exercises: exercises
      }
      days.push(day)
    }
    return days
  }

  private createRecoveryDays(source: TrainingDay[]): TrainingDay[] {
    const days: TrainingDay[] = []
    for (let dayIndex = 0; dayIndex < source.length; dayIndex++) {
      const sourceDay: TrainingDay = source[dayIndex]
      const exercises: ExerciseRef[] = []
      const keepCount: number = sourceDay.exercises.length > 4 ? sourceDay.exercises.length - 1 : sourceDay.exercises.length
      for (let exerciseIndex = 0; exerciseIndex < keepCount; exerciseIndex++) {
        const sourceExercise: ExerciseRef = sourceDay.exercises[exerciseIndex]
        let sets: number = sourceExercise.sets
        if (exerciseIndex > 0 && sets > 2) {
          sets = sets - 1
        }
        const exercise: ExerciseRef = {
          name: sourceExercise.name,
          targetMuscle: sourceExercise.targetMuscle,
          sets: sets,
          reps: sourceExercise.reps
        }
        exercises.push(exercise)
      }
      const day: TrainingDay = {
        dayLabel: sourceDay.dayLabel,
        dayOfWeek: this.copyDayOfWeek(sourceDay.dayOfWeek),
        exercises: exercises
      }
      days.push(day)
    }
    return days
  }

  private getStatusLabel(locked: boolean, activeTier: MonetizationTier): string {
    if (locked) {
      return 'Free'
    }
    if (activeTier === 'plus') {
      return 'Plus 已解锁'
    }
    return 'Pro 已解锁'
  }

  private getDescription(plan: PresetPlan, locked: boolean, activeTier: MonetizationTier): string {
    const planName: string = plan.name.length > 0 ? plan.name : '当前计划'
    if (locked) {
      return planName + ' 现在可以继续直接使用。升级后，你可以在不改动训练主链的前提下切换不同训练策略。'
    }
    if (activeTier === 'plus') {
      return '当前权益已解锁 ' + planName + ' 的高级计划变体。选一个更适合本周状态的版本，再启用到首页主训练入口。'
    }
    return '当前权益已解锁 ' + planName + ' 的高级计划变体。你可以继续沿用原计划，也可以切成更聚焦的本周版本。'
  }

  private copyDayOfWeek(source: number[] | undefined): number[] | undefined {
    if (source === undefined) {
      return undefined
    }
    const values: number[] = []
    for (let index = 0; index < source.length; index++) {
      values.push(source[index])
    }
    return values
  }
}

export default new AdvancedPlanVariantsService()
