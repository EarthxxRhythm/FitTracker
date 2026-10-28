/**
 * PlanTabModel —— 计划 Tab（PlanContent）展示模型与纯映射。
 *
 * 计划 Tab 的数据源有二，产出同一个 PlanDayItem 结构，组件只负责渲染：
 *   ① 计划组「已启用的预置计划」（TrainingPlanService.getCurrentPlan）→ buildPlanDayItemsFromUserPlan；
 *   ② 目标生成计划（GoalRepository + PlanEngine）→ 仍由 PlanContent 内联构建。
 *
 * 训练日短标签 / 焦点肌群的取法与「计划组详情页」同口径
 * （原 PlanGroupDetailContent 的 shortTag / focusOf，现收敛为本文件的单一实现）。
 */
import {
  ExerciseRef,
  TrainingDay,
  UserPlan,
  resolveDayDistance
} from '../../../common/services/TrainingPlanService'

export interface PlanExerciseItem {
  name: string
  muscle: string
  sets: string
  reps: string
}

export interface PlanDayItem {
  tag: string
  title: string
  focus: string
  duration: string
  badge: string
  today: boolean
  exercises: PlanExerciseItem[]
}

export function createPlanExerciseItem(name: string, muscle: string, sets: string, reps: string): PlanExerciseItem {
  const item: PlanExerciseItem = {
    name: name,
    muscle: muscle,
    sets: sets,
    reps: reps
  }
  return item
}

export function createPlanDayItem(
  tag: string,
  title: string,
  focus: string,
  duration: string,
  badge: string,
  today: boolean,
  exercises: PlanExerciseItem[]
): PlanDayItem {
  const item: PlanDayItem = {
    tag: tag,
    title: title,
    focus: focus,
    duration: duration,
    badge: badge,
    today: today,
    exercises: exercises
  }
  return item
}

/** 位置徽标：第 1/2/3 天为 今日/明日/后天，其余「第 N 天」。 */
export function positionBadge(index: number): string {
  if (index === 0) {
    return '今日'
  }
  if (index === 1) {
    return '明日'
  }
  if (index === 2) {
    return '后天'
  }
  return '第 ' + (index + 1).toString() + ' 天'
}

/**
 * 相对日徽标：按「距今天数」而不是卡片位置——0/1/2 天用今日/明日/后天，
 * 其余「N 天后」；解析不出距离时回退位置徽标。
 * 计划 tab 的「今日」必须与首页/训练预览（getTodayTraining 按 dayOfWeek 选天）同口径，
 * 否则卡片标「今日」的动作清单和预览页展示的不是同一天（历史上就是按位置恒标首日）。
 */
export function relativeDayBadge(distance: number, index: number): string {
  if (distance === 0) {
    return '今日'
  }
  if (distance === 1) {
    return '明日'
  }
  if (distance === 2) {
    return '后天'
  }
  if (distance > 2) {
    return distance.toString() + ' 天后'
  }
  return positionBadge(index)
}

/** 训练日短标签：去掉「周一」前缀取首字（「周一 胸部」→胸、「上肢A」→上、「推日」→推）。 */
export function shortDayTag(dayLabel: string): string {
  let text: string = dayLabel
  if (text.length >= 2 && text.substring(0, 1) === '周') {
    text = text.substring(2)
  }
  text = text.trim()
  if (text.length === 0) {
    return '练'
  }
  return text.substring(0, 1)
}

/** 训练日覆盖的目标肌群（去重、按出现顺序，以「 · 」相连）。 */
export function dayFocusMuscles(day: TrainingDay): string {
  const muscles: string[] = []
  for (let index = 0; index < day.exercises.length; index++) {
    const muscle: string = day.exercises[index].targetMuscle
    if (muscle.length > 0 && muscles.indexOf(muscle) < 0) {
      muscles.push(muscle)
    }
  }
  return muscles.join(' · ')
}

/** 日卡副标题：预置计划没有单次时长，duration 为空时不追加尾段。 */
export function daySubtitle(day: PlanDayItem): string {
  const base: string = day.focus + ' · ' + day.exercises.length.toString() + ' 个动作'
  if (day.duration.length === 0) {
    return base
  }
  return base + ' · ' + day.duration
}

/** 由「计划组已启用的预置计划」构建计划 Tab 的日卡片。todayWeekday 供测试注入固定星期。 */
export function buildPlanDayItemsFromUserPlan(plan: UserPlan, todayWeekday: number = new Date().getDay()): PlanDayItem[] {
  const items: PlanDayItem[] = []
  for (let index = 0; index < plan.days.length; index++) {
    const day: TrainingDay = plan.days[index]
    const distance: number = resolveDayDistance(day, todayWeekday)
    // 无星期信息的计划（自定义计划）解析不出距离，沿用旧的按位置回退：首日视为今日。
    const isToday: boolean = distance === 0 || (distance < 0 && index === 0)
    items.push(createPlanDayItem(
      shortDayTag(day.dayLabel),
      day.dayLabel,
      dayFocusMuscles(day),
      '',
      relativeDayBadge(distance, index),
      isToday,
      buildPlanExerciseItems(day.exercises)
    ))
  }
  return items
}

function buildPlanExerciseItems(exercises: ExerciseRef[]): PlanExerciseItem[] {
  const items: PlanExerciseItem[] = []
  for (let index = 0; index < exercises.length; index++) {
    const exercise: ExerciseRef = exercises[index]
    items.push(createPlanExerciseItem(exercise.name, exercise.targetMuscle, exercise.sets.toString(), exercise.reps))
  }
  return items
}
