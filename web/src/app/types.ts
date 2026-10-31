/**
 * web 复刻版的类型层。
 *
 * 逐字段照抄产品契约，不"简化"：
 *  - 训练数据来自 apps/harmony/entry/src/main/ets/shared/models/TrainingModels.ets
 *  - 预置计划来自 apps/harmony/entry/src/main/ets/common/services/TrainingPlanService.ets:21-41
 *
 * 字段同名同义是有意的：官网文案承诺「按 Epley 公式估算 1RM」「肌肉分布」，
 * 用户拿真机一对照就能看出口径差异。若将来要接云同步，只需换 store 实现，不必重写数据层。
 */

// ── 内容库（generated/content.generated.ts 的类型） ─────────────────────

export interface MuscleGroup {
  muscleId: string
  nameZh: string
  region: string
}

export interface EquipmentItem {
  equipmentId: string
  nameZh: string
}

export interface ExerciseContent {
  exerciseId: string
  nameZh: string
  nameEn: string
  aliases: string[]
  primaryMuscleIds: string[]
  secondaryMuscleIds: string[]
  equipmentIds: string[]
  difficulty: string
  goalTags: string[]
  videoUrl: string
  coverUrl: string
  coverSourceLabel: string
  videoSourceLabel: string
  mediaLicenseText: string
  steps: string[]
  cues: string[]
  commonMistakes: string[]
  safetyNotes: string[]
  alternativeExerciseIds: string[]
  contentVersion: number
}

// ── 预置计划（TrainingPlanService.ets:13-41） ───────────────────────────

/** 计划里的一个动作。预置计划用中文名索引，不是 exerciseId。 */
export interface ExerciseRef {
  name: string
  targetMuscle: string
  sets: number
  reps: string
}

export interface TrainingDay {
  dayLabel: string
  exercises: ExerciseRef[]
  /** 0=周日, 1=周一 … 6=周六；缺省时按 dayLabel 里的「周X」兜底。 */
  dayOfWeek?: number[]
}

export interface PresetPlan {
  id: string
  name: string
  coverColor: string
  targetAudience: string
  weeklyFrequency: string
  description: string
  days: TrainingDay[]
}

export interface UserPlan extends PresetPlan {
  enabledAt: number
}

// ── 训练记录（TrainingModels.ets:72-108） ───────────────────────────────

export interface WorkoutSet {
  setId: string
  exerciseId: string
  weight: number
  reps: number
  rpe: number
  isWarmup: boolean
}

export interface WorkoutSession {
  sessionId: string
  planId: string
  dayId: string
  startedAt: number
  endedAt: number
  durationSeconds: number
  totalSets: number
  totalVolume: number
  fatigueScore: number
  /** 整体努力程度 RPE 1-10；0 = 未评价。 */
  sessionRpe?: number
  /** 内嵌 `completed_sets=N;target_sets=M`，摘要页靠它还原计划组数。 */
  notes: string
  sets: WorkoutSet[]
}

// ── 训练执行中的活跃态（ActiveWorkoutService.ets:18-56） ─────────────────

export interface ActiveWorkoutSetEntry {
  setIndex: number
  weightText: string
  repsText: string
  estimatedOneRepMax: number
  oneRepMaxText: string
  isWarmup: boolean
  isComplete: boolean
}

export interface ActiveWorkoutExercise {
  plannedExerciseId: string
  exerciseId: string
  name: string
  /** 进入训练时定下，永不收缩——用于区分「练满」与「提前结束」。 */
  plannedTargetSets: number
  targetSets: number
  targetReps: string
  intensityNote: string
  completedSets: number
  sets: ActiveWorkoutSetEntry[]
}

export interface ActiveWorkoutState {
  hasWorkout: boolean
  planId: string
  dayId: string
  title: string
  totalTargetSets: number
  completedSets: number
  currentExerciseName: string
  currentExerciseSetProgress: string
  exercises: ActiveWorkoutExercise[]
}

// ── 身体数据 ───────────────────────────────────────────────────────────

export interface BodyRecord {
  id: string
  at: number
  weight: number
  bodyFat?: number
}

// ── 设置 ───────────────────────────────────────────────────────────────

export type WeightUnit = 'kg' | 'lbs'
export type WeekStart = 'monday' | 'sunday'

export interface WebSettings {
  weightUnit: WeightUnit
  weekStart: WeekStart
}

// ── 本机快照（localStorage 载荷） ───────────────────────────────────────

export interface WebSnapshot {
  schemaVersion: 1
  createdAt: number
  sessions: WorkoutSession[]
  /** 启用中的预置计划 id；空串表示还没选计划。 */
  currentPlanId: string
  /** 启用过的计划克隆（启用时刻），键为 planId。 */
  enabledPlans: UserPlan[]
  bodyRecords: BodyRecord[]
  favorites: string[]
  draft: ActiveWorkoutState | null
  draftStartedAt: number
  settings: WebSettings
}
