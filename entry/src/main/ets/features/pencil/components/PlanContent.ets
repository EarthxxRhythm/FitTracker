/** PlanContent - 计划 Tab 界面体（供 PencilAppShell 与独立注册页复用）。 */

import { AppRoutes } from '../../../app/AppRoutes'
import { MotionTokens } from '../../../common/styles/DesignTokens'
import GoalRepository from '../../../shared/services/GoalRepository'
import PlanEngine from '../../../shared/services/PlanEngine'
import ContentRepository from '../../../shared/services/ContentRepository'
import WorkoutSessionService, { WeeklyStats } from '../../../common/services/WorkoutSessionService'
import {
  ExerciseContent,
  PlanDay,
  PlannedExercise,
  TrainingPlan,
  UserGoal
} from '../../../shared/models/TrainingModels'

interface PlanExerciseItem {
  name: string
  muscle: string
  sets: string
  reps: string
}

interface PlanDayItem {
  tag: string
  title: string
  focus: string
  muscle: string
  duration: string
  badge: string
  today: boolean
  exercises: PlanExerciseItem[]
}

function createPlanExercise(name: string, muscle: string, sets: string, reps: string): PlanExerciseItem {
  const item: PlanExerciseItem = {
    name: name,
    muscle: muscle,
    sets: sets,
    reps: reps
  }
  return item
}

function createPlanDay(
  tag: string,
  title: string,
  focus: string,
  muscle: string,
  duration: string,
  badge: string,
  today: boolean,
  exercises: PlanExerciseItem[]
): PlanDayItem {
  const item: PlanDayItem = {
    tag: tag,
    title: title,
    focus: focus,
    muscle: muscle,
    duration: duration,
    badge: badge,
    today: today,
    exercises: exercises
  }
  return item
}

@Component
export struct PlanContent {
  @State private activeCard: number = 0
  @State private masterPressed: boolean = false
  @State private planDays: PlanDayItem[] = []
  @State private planName: string = '训练计划'
  @State private goalMeta: string = '尚未设置目标'
  @State private planMeta: string = '完成目标设置后自动生成训练计划'
  @State private weeklyProgress: string = '本周 0 / 0 天'
  @State private progressPercent: number = 0
  private sessionMinutes: number = 45

  aboutToAppear(): void {
    this.loadPlanData()
  }

  private async loadPlanData(): Promise<void> {
    const hostContext: Context | undefined = this.getUIContext().getHostContext()
    if (hostContext === undefined) {
      this.applyEmptyState()
      return
    }
    try {
      const goal: UserGoal | undefined = await GoalRepository.loadGoal(hostContext)
      if (goal === undefined) {
        this.applyEmptyState()
        return
      }
      const plan: TrainingPlan = PlanEngine.generatePlan(goal)
      this.sessionMinutes = goal.sessionMinutes
      this.planDays = this.buildPlanDayItems(plan)
      this.planName = plan.name.length > 0 ? plan.name : '训练计划'
      this.goalMeta = this.goalTypeLabel(goal.goalType) + ' · ' + plan.days.length.toString() + ' 练分化'
      this.planMeta = this.goalMeta + ' · ' + plan.cycleWeeks.toString() + ' 周推进'
      await this.loadWeeklyProgress(hostContext, plan.days.length)
    } catch (error) {
      this.applyEmptyState()
    }
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
    this.goalMeta = '尚未设置目标'
    this.planMeta = '完成目标设置后自动生成训练计划'
    this.weeklyProgress = '本周 0 / 0 天'
    this.progressPercent = 0
  }

  private buildPlanDayItems(plan: TrainingPlan): PlanDayItem[] {
    const items: PlanDayItem[] = []
    for (let index = 0; index < plan.days.length; index++) {
      const day: PlanDay = plan.days[index]
      const focusName: string = this.focusMuscleName(day)
      const title: string = focusName.length > 0 ? focusName + '日' : day.title
      items.push(createPlanDay(
        this.shortMuscleLabel(focusName),
        title,
        focusName + ' · 训练',
        focusName,
        this.sessionMinutes.toString() + ' 分钟',
        this.badgeFor(index),
        index === 0,
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
      items.push(createPlanExercise(name, muscle, item.targetSets.toString(), item.targetReps))
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

  private badgeFor(index: number): string {
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

  private goalTypeLabel(goalType: string): string {
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

  private activeDayCaption(): string {
    if (this.planDays.length === 0) {
      return '暂无安排'
    }
    const safeIndex: number = Math.min(this.activeCard, this.planDays.length - 1)
    return '第 ' + (safeIndex + 1).toString() + ' 天 · ' + this.planDays[safeIndex].tag
  }

  private rel(index: number): number {
    return index - this.activeCard
  }

  private opacityFor(rel: number): number {
    const distance: number = Math.abs(rel)
    if (distance <= 1) {
      return 1 - 0.26 * distance
    }
    if (distance < 1.2) {
      return 0.74 * (1 - (distance - 1) / 0.2)
    }
    return 0
  }

  private scaleFor(rel: number): number {
    return 1 - 0.18 * Math.min(Math.abs(rel), 1.2)
  }

  private zFor(rel: number): number {
    return Math.max(1, 100 - Math.abs(rel) * 30)
  }

  private darkenFor(rel: number): number {
    const distance: number = Math.abs(rel)
    if (distance <= 1) {
      return 0.1 * distance
    }
    if (distance < 1.2) {
      return 0.1 + (distance - 1)
    }
    return 0.3
  }

  build() {
    Column() {
      Column({ space: 16 }) {
        this.masterCard()
        Stack({ alignContent: Alignment.TopStart }) {
          ForEach(this.planDays, (day: PlanDayItem, index: number) => {
            this.deckCard(day, index)
          }, (day: PlanDayItem) => day.title)
        }
        .width('100%')
        .layoutWeight(4)
        .clip(true)
        .gesture(
          SwipeGesture({ direction: SwipeDirection.Horizontal })
            .onAction((event: GestureEvent) => {
              if (event.angle !== undefined) {
                const horizontal: number = Math.abs(event.angle)
                const isLeft: boolean = horizontal > 90 && horizontal < 270
                if (isLeft && this.activeCard < this.planDays.length - 1) {
                  this.activeCard += 1
                } else if (!isLeft && this.activeCard > 0) {
                  this.activeCard -= 1
                }
              }
            })
        )
      }
      .width('100%')
      .height('100%')
      .padding({
        left: 16,
        right: 16,
        top: 53,
        bottom: 24
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0B0F13')
  }

  @Builder
  private masterCard() {
    Column() {
      Row() {
        Text('当前计划')
          .fontFamily('Noto Sans SC')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#50ECA7')
        Text(this.weeklyProgress)
          .fontFamily('Inter')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor('#50ECA7')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Text(this.planName)
        .fontFamily('Noto Sans SC')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
        .width('100%')
        .margin({ top: 8 })

      Text(this.planMeta)
        .fontFamily('Noto Sans SC')
        .fontSize(11.5)
        .fontColor('#9EFFFFFF')
        .width('100%')
        .margin({ top: 5 })

      Blank()

      Row({ space: 10 }) {
        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width('100%')
            .height(6)
            .backgroundColor('#2450ECA7')
            .borderRadius(999)
          Row()
            .width(this.progressPercent.toString() + '%')
            .height(6)
            .backgroundColor('#50ECA7')
            .borderRadius(999)
        }
        .layoutWeight(1)
        .height(6)

        Text(this.activeDayCaption())
          .fontFamily('Inter')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor('#9EFFFFFF')
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor('#0F50ECA7')
    .borderRadius(24)
    .border({ width: 1, color: '#3850ECA7' })
    .shadow({ radius: 28, color: '#33000000', offsetX: 0, offsetY: 14 })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.masterPressed = true
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.masterPressed = false
      }
    })
    .scale({ x: this.masterPressed ? MotionTokens.PRESS_ICON : 1, y: this.masterPressed ? MotionTokens.PRESS_ICON : 1 })
    .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
    .onClick(() => {
      this.getUIContext().getRouter().pushUrl({ url: AppRoutes.PLANS })
    })
  }

  @Builder
  private deckCard(day: PlanDayItem, index: number) {
    Stack() {
      Column() {
        Column({ space: 14 }) {
          Row({ space: 10 }) {
            Text('第 ' + (index + 1).toString() + ' 天 · ' + day.tag)
              .fontFamily('Geist Mono')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor('#9EFFFFFF')
            Text(day.badge)
              .fontFamily('Noto Sans SC')
              .fontSize(10)
              .fontWeight(day.today ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(day.today ? '#07100B' : '#9EFFFFFF')
              .padding({ left: 9, right: 9, top: 4, bottom: 4 })
              .backgroundColor(day.today ? '#50ECA7' : '#0FFFFFFF')
              .borderRadius(999)
              .border({ width: 1, color: day.today ? '#00FFFFFF' : '#0FFFFFFF' })
            Blank()
            Stack({ alignContent: Alignment.Center }) {
              Image($rawfile('pencil-lucide-dumbbell.svg'))
                .width(20)
                .height(20)
                .fillColor('#50ECA7')
            }
            .width(40)
            .height(40)
            .borderRadius(12)
            .backgroundColor('#1A50ECA7')
            .border({ width: 1, color: '#4050ECA7' })
          }
          .width('100%')

          Text(day.title)
            .fontFamily('Noto Sans SC')
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F7FBF8')
            .width('100%')

          Text(day.focus + ' · ' + day.exercises.length.toString() + ' 个动作 · ' + day.duration)
            .fontFamily('Noto Sans SC')
            .fontSize(14)
            .fontColor('#9EFFFFFF')
            .width('100%')
        }
        .width('100%')

        Scroll() {
          Column({ space: 5 }) {
            Text('动作清单')
              .fontFamily('Noto Sans SC')
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor('#8AFFFFFF')
              .width('100%')
            ForEach(day.exercises, (exercise: PlanExerciseItem, exerciseIndex: number) => {
              Row({ space: 10 }) {
                Text((exerciseIndex + 1).toString().padStart(2, '0'))
                  .fontFamily('Geist Mono')
                  .fontSize(11)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#50ECA7')
                  .width(24)
                Text(exercise.name)
                  .fontFamily('Noto Sans SC')
                  .fontSize(13.5)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#F7FBF8')
                Text(exercise.muscle)
                  .fontFamily('Noto Sans SC')
                  .fontSize(11)
                  .fontColor('#8AFFFFFF')
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(exercise.sets + ' × ' + exercise.reps)
                  .fontFamily('Inter')
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#9EFFFFFF')
              }
              .width('100%')
              .height(44)
              .padding({ left: 10, right: 10 })
              .backgroundColor('#0FFFFFFF')
              .borderRadius(10)
              .alignItems(VerticalAlign.Center)
            }, (exercise: PlanExerciseItem) => exercise.name)
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .margin({ top: 14 })
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .padding(18)

      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
        .opacity(this.darkenFor(this.rel(index)))
        .borderRadius(24)
        .animation({ duration: MotionTokens.DURATION_MARKER, curve: MotionTokens.EASE_MOTION })
    }
    .width(342)
    .height('100%')
    .backgroundColor('#151B20')
    .borderRadius(24)
    .border({ width: 1, color: '#17FFFFFF' })
    .shadow({ radius: 36, color: '#52000000', offsetX: 0, offsetY: 18 })
    .position({ x: 8, y: 0 })
    .translate({ x: this.rel(index) * 294.12, y: 16 * Math.abs(this.rel(index)) })
    .rotate({ angle: this.rel(index) * 6 })
    .scale({ x: this.scaleFor(this.rel(index)), y: this.scaleFor(this.rel(index)) })
    .opacity(this.opacityFor(this.rel(index)))
    .zIndex(this.zFor(this.rel(index)))
    .animation({ duration: MotionTokens.DURATION_MARKER, curve: MotionTokens.EASE_MOTION })
  }
}

