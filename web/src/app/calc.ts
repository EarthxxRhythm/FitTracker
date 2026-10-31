/**
 * 纯计算层——复刻版的计算口径。
 *
 * 每一条都对应产品源码里的唯一实现，注释里带锚点。**不要"顺手优化"这些公式**：
 * 用户拿真机对照就能看出口径差异，比如给 Epley 加个 reps===1 特判，1RM 就会比真机低。
 *
 * 本文件不碰 DOM、不碰 localStorage、不碰 React——纯输入输出，因此可被 node:test 直接测。
 */

import type {
  ExerciseContent,
  MuscleGroup,
  TrainingDay,
  WeekStart,
  WorkoutSession,
  WorkoutSet
} from './types'

// ── R1：Epley 1RM ──────────────────────────────────────────────────────

/**
 * 估算 1RM。
 *
 * 与 TrainingModels.ets:426-429 逐字一致：weight × (1 + reps/30)，两位小数。
 * 刻意保留真机的口径缺陷——reps=1 时返回 1.033×weight 而非 weight，没有边界特判。
 * 官网写的是「按 Epley 公式估算 1RM」，改口径就是改承诺。
 */
export function estimateOneRepMax(weight: number, reps: number): number {
  const raw = weight * (1 + reps / 30)
  return Math.round(raw * 100) / 100
}

// ── R2：训练量 ─────────────────────────────────────────────────────────

/** 训练量 = Σ(weight × reps)，热身组不计。见 ReviewService.ets:9-18。 */
export function calculateVolume(sets: WorkoutSet[]): number {
  let volume = 0
  for (const set of sets) {
    if (!set.isWarmup) {
      volume += set.weight * set.reps
    }
  }
  return volume
}

/** 本次训练里最好的单组 1RM（排除热身）。见 ReviewService.ets:20-33。 */
export function calculateBestEstimatedOneRepMax(sets: WorkoutSet[]): number {
  let best = 0
  for (const set of sets) {
    if (!set.isWarmup) {
      const value = estimateOneRepMax(set.weight, set.reps)
      if (value > best) best = value
    }
  }
  return best
}

// ── R3：有效组 ─────────────────────────────────────────────────────────

/** 有效组 = weight>0 且 reps>0 且非热身。见 WorkoutSummaryService.ets:120-131。 */
export function countCompletedSets(sets: WorkoutSet[]): number {
  let count = 0
  for (const set of sets) {
    if (set.weight > 0 && set.reps > 0 && !set.isWarmup) count++
  }
  return count
}

// ── R4：完成率 ─────────────────────────────────────────────────────────

/** 完成率 = round(completed × 100 / planned)；planned<=0 时为 0。见 ReviewService.ets:32-37。 */
export function calculateCompletionRate(completed: number, planned: number): number {
  if (planned <= 0) return 0
  return Math.round((completed * 100) / planned)
}

// ── R6 / R7：肌群 → 身体部位 ───────────────────────────────────────────

/** 身体图 18 部位 key。**顺序是契约**，与 ReviewInsightsService.ets:165-169 一致，勿改。 */
export const BODY_PART_KEYS = [
  'trapezius',
  'deltoids',
  'chest',
  'upper-back',
  'serratus',
  'biceps',
  'triceps',
  'forearm',
  'abs',
  'obliques',
  'lower-back',
  'gluteal',
  'quadriceps',
  'hamstring',
  'adductors',
  'hip-flexors',
  'calves',
  'tibialis'
] as const

export const BODY_PART_LABELS: Record<string, string> = {
  trapezius: '斜方肌',
  deltoids: '三角肌',
  chest: '胸部',
  'upper-back': '上背',
  serratus: '前锯肌',
  biceps: '二头',
  triceps: '三头',
  forearm: '前臂',
  abs: '腹肌',
  obliques: '腹斜肌',
  'lower-back': '下背',
  gluteal: '臀部',
  quadriceps: '股四头',
  hamstring: '腘绳肌',
  adductors: '内收肌',
  'hip-flexors': '髋屈肌',
  calves: '小腿',
  tibialis: '胫骨前肌'
}

/** 6 个粗肌群 → 18 个身体部位。见 ReviewInsightsService.ets:145-160。 */
const MUSCLE_TO_BODY_PARTS: Record<string, string[]> = {
  muscle_chest: ['chest', 'serratus'],
  muscle_back: ['upper-back', 'lower-back', 'trapezius'],
  muscle_shoulders: ['deltoids', 'trapezius'],
  muscle_arms: ['biceps', 'triceps', 'forearm'],
  muscle_legs: ['quadriceps', 'hamstring', 'gluteal', 'adductors', 'calves'],
  muscle_core: ['abs', 'obliques', 'hip-flexors']
}

export function mapMuscleIdToBodyParts(muscleId: string): string[] {
  return MUSCLE_TO_BODY_PARTS[muscleId] ?? []
}

// ── R5：肌肉分布（按组数，不按重量） ────────────────────────────────────

/**
 * 近 limit 次训练内，每个身体部位被「练了几组」。
 *
 * 口径来自 ReviewInsightsService.ets:179-209：
 *  - 每一条 set 给它所属动作的每个 primaryMuscleId 映射到的**每个部位各 +1**
 *  - 是组数计数，与重量、次数无关；热身组不排除（真机也不排除）
 *  - 同一动作落到多个部位时全部 +1，所以 18 部位之和远大于总组数
 *  - secondaryMuscleIds 完全不参与
 *
 * @param resolvePrimaryMuscles 由调用方注入「动作 → 主肌群 id」，避免计算层依赖内容库
 */
export function createMuscleVolume(
  sessions: WorkoutSession[],
  resolvePrimaryMuscles: (exerciseId: string) => string[],
  limit = 8
): number[] {
  const volume: number[] = BODY_PART_KEYS.map(() => 0)
  if (sessions.length === 0) return volume

  const recent = takeRecent(sessions, limit)
  for (const session of recent) {
    for (const set of session.sets) {
      const muscleIds = resolvePrimaryMuscles(set.exerciseId)
      for (const muscleId of muscleIds) {
        for (const part of mapMuscleIdToBodyParts(muscleId)) {
          const index = BODY_PART_KEYS.indexOf(part as (typeof BODY_PART_KEYS)[number])
          if (index >= 0) volume[index] = volume[index] + 1
        }
      }
    }
  }
  return volume
}

/** 按 startedAt 升序取末尾 limit 条。见 ReviewInsightsService.ets:323-330。 */
export function takeRecent(sessions: WorkoutSession[], limit: number): WorkoutSession[] {
  if (sessions.length <= limit) {
    return [...sessions].sort((a, b) => a.startedAt - b.startedAt)
  }
  const sorted = [...sessions].sort((a, b) => a.startedAt - b.startedAt)
  return sorted.slice(sorted.length - limit)
}

// ── R8：热力等级 ───────────────────────────────────────────────────────

/**
 * 把部位训练量归一为 0–4 级。见 ReviewInsightsService.ets:211-250。
 *
 * 等级是**相对量**：与最大值同量级（>75%）取 4；所有部位相等时全 4 级。
 * 无任何训练量时返回全 0（页面据此渲染空态）。
 */
export function createMuscleLevels(volume: number[]): number[] {
  let max = 0
  for (const value of volume) {
    if (value > max) max = value
  }
  if (max <= 0) return volume.map(() => 0)

  return volume.map((value) => {
    if (value <= 0) return 0
    const ratio = value / max
    if (ratio <= 0.25) return 1
    if (ratio <= 0.5) return 2
    if (ratio <= 0.75) return 3
    return 4
  })
}

// ── R9：肌群排行 ───────────────────────────────────────────────────────

export type MuscleRankingMode = 'balance' | 'fatigue' | 'strength'

/**
 * 按模式排序的下标序列（与 volume / levels 同序的下标）。
 *
 * 见 ReviewInsightsService.ets:252-290：balance 用真实组数，fatigue / strength 用 1–4 级
 * （等级会把不同组数合并成同档，统一按组数排会与热力图着色不一致）。
 * 用插入排序保证**稳定**：同值时新元素插在等值元素之后，下标保持原序。
 */
export function createMuscleRanking(
  levels: number[],
  volume: number[],
  mode: MuscleRankingMode
): number[] {
  const key = (index: number) => (mode === 'balance' ? volume[index] : levels[index])
  const order: number[] = []
  for (let index = 0; index < volume.length; index++) {
    const value = key(index)
    let insertAt = order.length
    for (let cursor = 0; cursor < order.length; cursor++) {
      if (value > key(order[cursor])) {
        insertAt = cursor
        break
      }
    }
    order.splice(insertAt, 0, index)
  }
  return order
}

// ── R10：今日训练（预置计划路径） ──────────────────────────────────────

const WEEKDAY_LABELS = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']

/** 从「周五 手臂」这类标签里解析星期；无则 -1。见 TrainingPlanService.ets:263-272。 */
export function getDayNumberFromLabel(label: string): number {
  if (label.includes('周一')) return 1
  if (label.includes('周二')) return 2
  if (label.includes('周三')) return 3
  if (label.includes('周四')) return 4
  if (label.includes('周五')) return 5
  if (label.includes('周六')) return 6
  if (label.includes('周日')) return 0
  return -1
}

/**
 * 今天对应哪个训练日；-1 = 休息日。
 * 见 TrainingPlanService.ets:278-291：先按 dayOfWeek 匹配，缺失时按 dayLabel 兜底。
 */
export function resolveTodayTrainingIndex(days: TrainingDay[], todayWeekday: number): number {
  for (let index = 0; index < days.length; index++) {
    const weekdays = days[index].dayOfWeek
    if (weekdays !== undefined && weekdays.length > 0 && weekdays.indexOf(todayWeekday) >= 0) {
      return index
    }
  }
  for (let index = 0; index < days.length; index++) {
    if (getDayNumberFromLabel(days[index].dayLabel) === todayWeekday) return index
  }
  return -1
}

/** 该训练日距今天最近一次是几天后（0=今天）；解析不出星期时 -1。见 TrainingPlanService.ets:296-320。 */
export function resolveDayDistance(day: TrainingDay, todayWeekday: number): number {
  const weekdays: number[] = []
  if (day.dayOfWeek !== undefined) {
    for (const value of day.dayOfWeek) weekdays.push(value)
  }
  if (weekdays.length === 0) {
    const labelWeekday = getDayNumberFromLabel(day.dayLabel)
    if (labelWeekday >= 0) weekdays.push(labelWeekday)
  }
  if (weekdays.length === 0) return -1
  let best = 7
  for (const weekday of weekdays) {
    const distance = (weekday - todayWeekday + 7) % 7
    if (distance < best) best = distance
  }
  return best >= 7 ? -1 : best
}

// ── R11：今日训练（目标生成计划路径） ──────────────────────────────────

/** 目标创建至今第几天（≥1）。见 HomePlanService.ets:222-232。 */
export function createDaySeedFromGoal(goalCreatedAt: number, now: number): number {
  const dayCount = Math.floor((now - goalCreatedAt) / 86400000) + 1
  return dayCount < 1 ? 1 : dayCount
}

/** 按种子轮转取训练日。见 HomePlanService.ets:204-217。 */
export function pickTodayDay<T>(days: T[], daySeed: number): T | undefined {
  if (days.length === 0) return undefined
  const normalized = daySeed <= 0 ? 1 : daySeed
  return days[(normalized - 1) % days.length]
}

// ── R15：周区间 ────────────────────────────────────────────────────────

/** 本地时区「今天」的星期下标：0=周日。 */
export function weekdayIndex(now: number): number {
  return new Date(now).getDay()
}

/**
 * 本周起点（本地时区当日 0 点，回退 offset 天）。
 * 见 WeekUtils.ets:11-22：weekStart=monday 时周日要退 6 天。
 */
export function resolveWeekStart(now: number, weekStart: WeekStart): number {
  const date = new Date(now)
  const dayOfWeek = date.getDay()
  let offset: number
  if (weekStart === 'monday') {
    offset = dayOfWeek === 0 ? 6 : dayOfWeek - 1
  } else {
    offset = dayOfWeek
  }
  return new Date(date.getFullYear(), date.getMonth(), date.getDate() - offset).getTime()
}

/** 一周 7 天的起点时间戳（按 weekStart 对齐）。 */
export function weekDayStarts(now: number, weekStart: WeekStart): number[] {
  const start = resolveWeekStart(now, weekStart)
  const days: number[] = []
  const base = new Date(start)
  for (let index = 0; index < 7; index++) {
    days.push(new Date(base.getFullYear(), base.getMonth(), base.getDate() + index).getTime())
  }
  return days
}

/** 本周区间的可读文字，例如「10月26日 – 11月1日」。 */
export function formatWeekRange(now: number, weekStart: WeekStart): string {
  const starts = weekDayStarts(now, weekStart)
  const end = starts[6]
  return `${formatMonthDay(starts[0])} – ${formatMonthDay(end)}`
}

// ── 格式化 ─────────────────────────────────────────────────────────────

export function pad2(value: number): string {
  return value < 10 ? `0${value}` : String(value)
}

/** 'YYYY-MM-DD'（本地时区）。 */
export function formatDate(ts: number): string {
  const date = new Date(ts)
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`
}

/** 'M月D日'。 */
export function formatMonthDay(ts: number): string {
  const date = new Date(ts)
  return `${date.getMonth() + 1}月${date.getDate()}日`
}

/** 'M月D日 周X'。 */
export function formatMonthDayWeekday(ts: number): string {
  return `${formatMonthDay(ts)} ${WEEKDAY_LABELS[weekdayIndex(ts)]}`
}

/** 同一天（本地时区）。 */
export function isSameDay(a: number, b: number): boolean {
  return formatDate(a) === formatDate(b)
}

/** 秒 → 「X 分钟」/「X 小时 Y 分钟」。见 WorkoutSummaryService.ets:63-84。 */
export function formatDuration(durationSeconds: number): string {
  if (durationSeconds <= 0) return '0 分钟'
  const minutes = Math.floor(durationSeconds / 60)
  if (minutes <= 0) return '1 分钟内'
  const hours = Math.floor(minutes / 60)
  const restMinutes = minutes % 60
  if (hours > 0 && restMinutes > 0) return `${hours} 小时 ${restMinutes} 分钟`
  if (hours > 0) return `${hours} 小时`
  return `${minutes} 分钟`
}

/** 秒 → `mm:ss`（训练计时器用）。 */
export function formatClock(durationSeconds: number): string {
  const safe = durationSeconds < 0 ? 0 : Math.floor(durationSeconds)
  return `${pad2(Math.floor(safe / 60))}:${pad2(safe % 60)}`
}

/** 训练量：整数不显示小数点，否则一位小数。 */
export function formatVolume(volume: number): string {
  const rounded = Math.round(volume * 10) / 10
  return Number.isInteger(rounded) ? String(rounded) : rounded.toFixed(1)
}

/** 数值去掉多余小数（1RM 展示用）。 */
export function formatNumber(value: number, digits = 1): string {
  const factor = 10 ** digits
  const rounded = Math.round(value * factor) / factor
  return Number.isInteger(rounded) ? String(rounded) : rounded.toFixed(digits)
}

// ── 内容库查询 ─────────────────────────────────────────────────────────

export interface ContentIndex {
  byId: Map<string, ExerciseContent>
  /** 中文名 → 动作。预置计划用中文名索引，这是那条路径的桥。 */
  byName: Map<string, ExerciseContent>
}

export function buildContentIndex(exercises: ExerciseContent[]): ContentIndex {
  const byId = new Map<string, ExerciseContent>()
  const byName = new Map<string, ExerciseContent>()
  for (const exercise of exercises) {
    byId.set(exercise.exerciseId, exercise)
    byName.set(exercise.nameZh, exercise)
    // 只按中英文名精确匹配，**不吃 aliases**——与 WorkoutPreviewService.ets:278-283 同口径。
    // 加上别名匹配会让 web 的动作映射率高于真机（实测 43 个计划动作真机只匹配上 17 个），
    // 那是美化，不是复刻。
    if (!byName.has(exercise.nameEn)) byName.set(exercise.nameEn, exercise)
  }
  return { byId, byName }
}

/**
 * 预置计划的中文动作名 → exerciseId。
 *
 * 匹配不上时返回 `${planId}_exercise_${position+1}` 占位并保留原名——与真机
 * WorkoutPreviewService.ets:255-270 一致：真机匹配不上时同样用占位 id +
 * 「预置计划动作暂未映射到动作库，将按名称记录」。占位 id 查不到主肌群，
 * 于是不进入肌肉分布——这是真机的既有行为，不是 web 的缺陷。
 */
export function resolvePresetExercise(
  index: ContentIndex,
  planId: string,
  name: string,
  position: number
): { exerciseId: string; name: string; mapped: boolean } {
  const content = index.byName.get(name)
  if (content) {
    return { exerciseId: content.exerciseId, name: content.nameZh, mapped: true }
  }
  return { exerciseId: `${planId}_exercise_${position + 1}`, name, mapped: false }
}

export function getPrimaryMuscleIds(index: ContentIndex, exerciseId: string): string[] {
  return index.byId.get(exerciseId)?.primaryMuscleIds ?? []
}

export function muscleNameZh(muscles: MuscleGroup[], muscleId: string): string {
  return muscles.find((muscle) => muscle.muscleId === muscleId)?.nameZh ?? muscleId
}
