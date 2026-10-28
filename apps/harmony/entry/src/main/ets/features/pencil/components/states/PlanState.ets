/**
 * 计划 Tab 状态层。
 *
 * 由 PencilAppShell 以 `@State` 持有（生命周期 = 主壳，tab 切换不销毁），
 * PlanContent 以 `@ObjectLink` 消费。装载编排从 PlanContent.loadPlanData 迁入，
 * 并把「reloadToken 无条件重读」升级为「invalidate() 置脏 + 按需 refresh」。
 *
 * 数据源优先级不变：① 计划组「已启用的预置计划」→ ② 目标生成计划 → 空态。
 */
import { Context } from '@kit.AbilityKit'
import { StateBase } from './StateBase'
import GoalRepository from '../../../../shared/services/GoalRepository'
import PlanEngine from '../../../../shared/services/PlanEngine'
import ContentRepository from '../../../../shared/services/ContentRepository'
import WorkoutSessionService, { WeeklyStats } from '../../../../common/services/WorkoutSessionService'
import TrainingPlanService, { UserPlan } from '../../../../common/services/TrainingPlanService'
import {
  PlanDayItem,
  PlanExerciseItem,
  buildPlanDayItemsFromUserPlan,
  createPlanDayItem,
  createPlanExerciseItem,
  relativeDayBadge
} from '../PlanTabModel'
import HomePlanService from '../../../../shared/services/HomePlanService'
import {
  ExerciseContent,
  PlanDay,
  PlannedExercise,
  TrainingPlan,
  UserGoal
} from '../../../../shared/models/TrainingModels'
import { goalTypeLabel } from '../../../../common/utils/GoalLabels'

@Observed
export class PlanState extends StateBase {
  planDays: PlanDayItem[] = []
  planName: string = '训练计划'
  goalMeta: string = '尚未启用计划'
  planMeta: string = '到「计划」页选择并启用一套计划后即可开始训练'
  weeklyProgress: string = '本周 0 / 0 天'
  progressPercent: number = 0
  /** 单次时长（分钟）；预置计划无此字段时沿用目标设置里的值，未设目标为 45 兜底。 */
  sessionMinutes: number = 45

  /**
   * 按需装载当前计划。[force] 为 true 跳过新鲜度判断（首次 aboutToAppear 用）。
   *
   * 装载期间**不清空字段**——保留旧值，避免「切回 tab 时数据先清空再填」的可见跳变
   * （这是原实现「不闪但重读期显示陈旧数据」的语义，本次只消除无谓重读，不改此优点）。
   */
  async refresh(context: Context, force: boolean = false): Promise<void> {
    if (!force && !this.needRefresh()) {
      return
    }
    if (!this.tryBeginLoading()) {
      return
    }
    try {
      await this.load(context)
      this.markLoaded()
    } finally {
      this.endLoading()
    }
  }

  /** 装载主体（等价迁移自 PlanContent.loadPlanData）。 */
  private async load(context: Context): Promise<void> {
    try {
      const current: UserPlan | null = await TrainingPlanService.getCurrentPlan(context)
      if (current !== null) {
        this.applyCurrentPlanState(current)
        await this.loadWeeklyProgress(context, current.days.length)
        return
      }
    } catch (error) {
      // 读当前预置计划失败时回退到目标生成计划，不把整页打空。
    }
    try {
      const goal: UserGoal | undefined = await GoalRepository.loadGoal(context)
      if (goal === undefined) {
        this.applyEmptyState()
        return
      }
      const plan: TrainingPlan = PlanEngine.generatePlan(goal)
      this.sessionMinutes = goal.sessionMinutes
      this.planDays = this.buildPlanDayItems(plan, goal)
      this.planName = plan.name.length > 0 ? plan.name : '训练计划'
      this.goalMeta = goalTypeLabel(goal.goalType) + ' · ' + plan.days.length.toString() + ' 练分化'
      this.planMeta = this.goalMeta + ' · ' + plan.cycleWeeks.toString() + ' 周推进'
      await this.loadWeeklyProgress(context, plan.days.length)
    } catch (error) {
      this.applyEmptyState()
    }
  }

  /** 当前计划态：元信息与「计划组」列表页的当前计划卡同口径，保证两处一致。 */
  private applyCurrentPlanState(plan: UserPlan): void {
    this.planDays = buildPlanDayItemsFromUserPlan(plan)
    this.planName = plan.name.length > 0 ? plan.name : '训练计划'
    this.goalMeta = plan.targetAudience
    this.planMeta = plan.targetAudience + ' · ' + plan.days.length.toString() + ' 练分化 · ' + plan.weeklyFrequency
  }

  private async loadWeeklyProgress(context: Context, totalDays: number): Promise<void> {
    let completedDays: number = 0
    try {
      const stats: WeeklyStats = await WorkoutSessionService.getWeeklyStats(context)
      completedDays = stats.count
    } catch (error) {
      completedDays = 0
    }
    this.weeklyProgress = '本周 ' + completedDays.toString() + ' / ' + totalDays.toString() + ' 天'
    this.progressPercent = totalDays > 0 ? Math.min(100, Math.round(completedDays * 100 / totalDays)) : 0
  }

  private applyEmptyState(): void {
    this.planDays = []
    this.planName = '训练计划'
    this.goalMeta = '尚未启用计划'
    this.planMeta = '到「计划」页选择并启用一套计划后即可开始训练'
    this.weeklyProgress = '本周 0 / 0 天'
    this.progressPercent = 0
  }

  // ── 派生（从 PlanContent 迁入） ──────────────────────────────────────────

  private buildPlanDayItems(plan: TrainingPlan, goal: UserGoal): PlanDayItem[] {
    // 「今日」卡与首页/训练预览同口径：按目标创建至今的天数在循环日中定位今天，
    // 而不是恒把第 1 天当今日（历史上 deck 首卡标「今日」但预览选的是另一天）。
    const daySeed: number = HomePlanService.createDaySeedFromGoal(goal.createdAt, Date.now())
    const todayIndex: number = plan.days.length === 0
      ? -1
      : (daySeed - 1) % plan.days.length
    const items: PlanDayItem[] = []
    for (let index = 0; index < plan.days.length; index++) {
      const day: PlanDay = plan.days[index]
      const focusName: string = this.focusMuscleName(day)
      const title: string = focusName.length > 0 ? focusName + '日' : day.title
      const distance: number = (index - todayIndex + plan.days.length) % plan.days.length
      items.push(createPlanDayItem(
        this.shortMuscleLabel(focusName),
        title,
        focusName + ' · 训练',
        this.sessionMinutes.toString() + ' 分钟',
        relativeDayBadge(distance, index),
        index === todayIndex,
        this.buildExerciseItems(day.exercises, focusName)
      ))
    }
    return items
  }

  private buildExerciseItems(planned: PlannedExercise[], dayFocusName: string): PlanExerciseItem[] {
    const items: PlanExerciseItem[] = []
    for (let index = 0; index < planned.length; index++) {
      const item: PlannedExercise = planned[index]
      const content: ExerciseContent | undefined = ContentRepository.getExerciseById(item.exerciseId)
      let name: string = item.exerciseId
      let muscle: string = dayFocusName
      if (content !== undefined) {
        name = content.nameZh
        muscle = this.exerciseMuscleName(content, dayFocusName)
      }
      items.push(createPlanExerciseItem(name, muscle, item.targetSets.toString(), item.targetReps))
    }
    return items
  }

  private exerciseMuscleName(content: ExerciseContent, fallbackName: string): string {
    if (content.primaryMuscleIds.length === 0) {
      return fallbackName
    }
    return ContentRepository.getMuscleName(content.primaryMuscleIds[0])
  }

  private focusMuscleName(day: PlanDay): string {
    if (day.focusMuscleIds.length === 0) {
      return day.title
    }
    return ContentRepository.getMuscleName(day.focusMuscleIds[0])
  }

  private shortMuscleLabel(focusName: string): string {
    if (focusName === '胸部') {
      return '胸'
    }
    if (focusName === '背部') {
      return '背'
    }
    if (focusName === '腿部') {
      return '腿'
    }
    if (focusName === '肩部') {
      return '肩'
    }
    if (focusName === '手臂') {
      return '臂'
    }
    return focusName
  }
}
