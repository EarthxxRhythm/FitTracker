/** PlanGroupDetailContent —— 计划组详细页界面体（对应 plan-group-detail.html · screen-plan-group-detail）。
 *  数据源：TrainingPlanService.getPresetPlanById(planId)；「使用此计划」调用 enablePlan 真正落库。 */
import { MotionTokens } from '../../../common/styles/DesignTokens'
import TrainingPlanService, { PresetPlan, TrainingDay, UserPlan } from '../../../common/services/TrainingPlanService'
import { Context } from '@kit.AbilityKit'

interface GroupExercise {
  name: string
  sets: number
  reps: string
  muscle: string
}

interface GroupDay {
  title: string
  focus: string
  exercises: GroupExercise[]
}

function createGroupExercise(name: string, sets: number, reps: string, muscle: string): GroupExercise {
  const item: GroupExercise = {
    name: name,
    sets: sets,
    reps: reps,
    muscle: muscle
  }
  return item
}

function createGroupDay(title: string, focus: string, exercises: GroupExercise[]): GroupDay {
  const item: GroupDay = {
    title: title,
    focus: focus,
    exercises: exercises
  }
  return item
}

@Component
export struct PlanGroupDetailContent {
  // 计划 id（由 PencilPlanGroupDetailPage 从 getParams() 转入）。
  @Prop planId: string = ''

  @State private planName: string = ''
  @State private planDesc: string = ''
  @State private planTags: string[] = []
  @State private days: GroupDay[] = []
  @State private weekCells: string[] = []
  @State private notFound: boolean = false
  @State private isCurrent: boolean = false
  @State private backPressed: boolean = false
  @State private ctaPressed: boolean = false
  @State private dayKey: string = ''
  @State private exerciseKey: string = ''
  @State private activeDay: number = 0
  @State private toastMessage: string = ''
  @State private toastVisible: boolean = false
  @State private toastTimer: number = -1

  private readonly dowLabels: string[] = ['一', '二', '三', '四', '五', '六', '日']

  aboutToAppear(): void {
    this.loadPlan()
  }

  private async loadPlan(): Promise<void> {
    const plan: PresetPlan | undefined = TrainingPlanService.getPresetPlanById(this.planId)
    if (plan === undefined) {
      this.notFound = true
      return
    }
    this.notFound = false
    this.planName = plan.name
    this.planDesc = plan.description
    this.planTags = [plan.targetAudience, plan.weeklyFrequency, plan.days.length.toString() + ' 个训练日']
    this.days = this.buildDays(plan)
    this.weekCells = this.buildWeekCells(plan)
    this.activeDay = 0
    await this.refreshCurrentState()
  }

  private buildDays(plan: PresetPlan): GroupDay[] {
    const result: GroupDay[] = []
    for (let dayIndex = 0; dayIndex < plan.days.length; dayIndex++) {
      const day: TrainingDay = plan.days[dayIndex]
      const exercises: GroupExercise[] = []
      for (let exerciseIndex = 0; exerciseIndex < day.exercises.length; exerciseIndex++) {
        const exercise = day.exercises[exerciseIndex]
        exercises.push(createGroupExercise(
          exercise.name,
          exercise.sets,
          exercise.reps,
          exercise.targetMuscle
        ))
      }
      result.push(createGroupDay(day.dayLabel, this.focusOf(day), exercises))
    }
    return result
  }

  /** 该训练日涉及的目标肌群（去重、按出现顺序）。 */
  private focusOf(day: TrainingDay): string {
    const muscles: string[] = []
    for (let index = 0; index < day.exercises.length; index++) {
      const muscle: string = day.exercises[index].targetMuscle
      if (muscle.length > 0 && muscles.indexOf(muscle) < 0) {
        muscles.push(muscle)
      }
    }
    return muscles.join(' · ')
  }

  /** 周一→周日 7 格节奏：该日若有训练日覆盖则显示该日短标签，否则「休」。 */
  private buildWeekCells(plan: PresetPlan): string[] {
    const cells: string[] = []
    for (let index = 0; index < 7; index++) {
      const dayNum: number = index === 6 ? 0 : index + 1
      let label: string = '休'
      for (let dayIndex = 0; dayIndex < plan.days.length; dayIndex++) {
        const week: number[] | undefined = plan.days[dayIndex].dayOfWeek
        if (week !== undefined && week.indexOf(dayNum) >= 0) {
          label = this.shortTag(plan.days[dayIndex].dayLabel)
          break
        }
      }
      cells.push(label)
    }
    return cells
  }

  /** 训练日短标签：去掉「周一」前缀取首字，如「推日」→推、「周一 胸部」→胸、「上肢A」→上。 */
  private shortTag(label: string): string {
    let text: string = label
    if (text.length >= 2 && text.substring(0, 1) === '周') {
      text = text.substring(2)
    }
    text = text.trim()
    if (text.length === 0) {
      return '练'
    }
    return text.substring(0, 1)
  }

  private async refreshCurrentState(): Promise<void> {
    const hostContext: Context | undefined = this.getUIContext().getHostContext()
    if (hostContext === undefined) {
      return
    }
    const current: UserPlan | null = await TrainingPlanService.getCurrentPlan(hostContext)
    if (current === null) {
      this.isCurrent = false
      return
    }
    this.isCurrent = current.name === this.planName
  }

  private handleBack(): void {
    this.getUIContext().getRouter().back()
  }

  private showToast(message: string): void {
    this.toastMessage = message
    this.toastVisible = true
    if (this.toastTimer >= 0) {
      clearTimeout(this.toastTimer)
    }
    this.toastTimer = setTimeout(() => {
      this.toastVisible = false
    }, 1600)
  }

  private async usePlan(): Promise<void> {
    if (this.notFound) {
      return
    }
    const hostContext: Context | undefined = this.getUIContext().getHostContext()
    if (hostContext === undefined) {
      this.showToast('启用失败：缺少运行环境')
      return
    }
    const enabled: UserPlan | null = await TrainingPlanService.enablePlan(hostContext, this.planId)
    if (enabled === null) {
      this.showToast('启用失败，请稍后重试')
      return
    }
    this.isCurrent = true
    this.showToast('已将「' + enabled.name + '」设为当前计划')
  }

  aboutToDisappear(): void {
    if (this.toastTimer >= 0) {
      clearTimeout(this.toastTimer)
    }
  }

  private isWeekRest(cell: string): boolean {
    return cell === '休'
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        this.topBar()

        if (this.notFound) {
          this.emptyState()
        } else {
          Scroll() {
            Column({ space: 16 }) {
              this.summaryCard()
              this.rhythmSection()
              this.dayTabs()
              this.dayPanel()
            }
            .width('100%')
            .padding({ top: 16, bottom: 16, left: 16, right: 16 })
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)

          this.ctaBar()
        }
      }
      .width('100%')
      .height('100%')

      if (this.toastVisible) {
        Row() {
          Text(this.toastMessage)
            .fontFamily('Noto Sans SC')
            .fontSize(13)
            .fontColor('#F7FBF8')
            .lineHeight(18)
            .textAlign(TextAlign.Center)
        }
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .constraintSize({ maxWidth: 320 })
        .backgroundColor('#F00D1117')
        .borderRadius(999)
        .border({ width: 1, color: '#1AFFFFFF' })
        .margin({ bottom: 88 })
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.translate({ y: 10 }))
          .animation({ duration: MotionTokens.DURATION_COLOR_BASE, curve: MotionTokens.EASE_MOTION }))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0B0F13')
  }

  @Builder
  private emptyState() {
    Column({ space: 10 }) {
      Text('未找到该计划')
        .fontFamily('Noto Sans SC')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
      Text('计划参数缺失或已下线，请返回重新选择。')
        .fontFamily('Noto Sans SC')
        .fontSize(13)
        .fontColor('#9EFFFFFF')
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 16, right: 16 })
  }

  @Builder
  private topBar() {
    Row({ space: 8 }) {
      Row() {
        Path()
          .width(22)
          .height(22)
          .commands('M13.75 4.58 L7.33 11 L13.75 17.42')
          .fillOpacity(0)
          .stroke('#B3FFFFFF')
          .strokeWidth(1.83)
          .strokeLineCap(LineCapStyle.Round)
          .strokeLineJoin(LineJoinStyle.Round)
      }
      .width(44)
      .height(44)
      .borderRadius(14)
      .justifyContent(FlexAlign.Center)
      .scale({ x: this.backPressed ? MotionTokens.PRESS_BACK : 1, y: this.backPressed ? MotionTokens.PRESS_BACK : 1 })
      .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.backPressed = true
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.backPressed = false
        }
      })
      .onClick(() => {
        this.handleBack()
      })

      Text(this.planName)
        .fontFamily('Noto Sans SC')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row()
        .width(44)
        .height(44)
    }
    .width('100%')
    .padding({ top: 52, bottom: 10, left: 12, right: 12 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor('#D10A0D12')
    .border({ width: { bottom: 1 }, color: '#0FFFFFFF' })
  }

  @Builder
  private summaryCard() {
    Column() {
      Text('计划组')
        .fontFamily('Noto Sans SC')
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor('#50ECA7')
        .letterSpacing(0.33)
      Text(this.planName)
        .fontFamily('Noto Sans SC')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .lineHeight(26)
        .fontColor('#F7FBF8')
        .margin({ top: 8 })
        .padding({ right: 8 })
      Text(this.planDesc)
        .fontFamily('Noto Sans SC')
        .fontSize(13)
        .lineHeight(21)
        .fontColor('#9EFFFFFF')
        .margin({ top: 8 })
      Row({ space: 7 }) {
        ForEach(this.planTags, (tag: string) => {
          Text(tag)
            .fontFamily('Noto Sans SC')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor('#50ECA7')
            .padding({ top: 4, bottom: 4, left: 11, right: 11 })
            .backgroundColor('#1F50ECA7')
            .border({ width: 1, color: '#4D50ECA7' })
            .borderRadius(999)
        }, (tag: string) => tag)
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .padding({ top: 16, bottom: 15, left: 16, right: 16 })
    .backgroundColor('#1450ECA7')
    .border({ width: 1, color: '#6650ECA7' })
    .borderRadius(20)
    .shadow({ radius: 28, color: '#33000000', offsetX: 0, offsetY: 14 })
  }

  @Builder
  private rhythmSection() {
    Column({ space: 10 }) {
      Text('每周节奏')
        .fontFamily('Noto Sans SC')
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#8AFFFFFF')
        .letterSpacing(0.24)
      Row({ space: 5 }) {
        ForEach(this.weekCells, (cell: string, index: number) => {
          Column({ space: 6 }) {
            Text(this.dowLabels[index])
              .fontFamily('Noto Sans SC')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor('#66FFFFFF')
            Column() {
              Text(cell)
                .fontFamily('Noto Sans SC')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.isWeekRest(cell) ? '#66FFFFFF' : '#50ECA7')
            }
            .width('100%')
            .height(34)
            .justifyContent(FlexAlign.Center)
            .borderRadius(10)
            .backgroundColor(this.isWeekRest(cell) ? '#08FFFFFF' : '#1F50ECA7')
            .border({ width: 1, color: this.isWeekRest(cell) ? '#1AFFFFFF' : '#4D50ECA7' })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
        }, (cell: string, index: number) => index.toString() + cell)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private dayTabs() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(this.days, (day: GroupDay, index: number) => {
          Button({ type: ButtonType.Normal }) {
            Column({ space: 3 }) {
              Text('第 ' + (index + 1).toString() + ' 天')
                .fontFamily('Inter')
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.activeDay === index ? '#50ECA7' : '#8AFFFFFF')
              Text(day.title)
                .fontFamily('Noto Sans SC')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.activeDay === index ? '#50ECA7' : '#F7FBF8')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          .constraintSize({ minWidth: 96 })
          .padding({ top: 10, bottom: 10, left: 12, right: 12 })
          .backgroundColor(this.activeDay === index ? '#2650ECA7' : '#0AFFFFFF')
          .border({ width: 1, color: this.activeDay === index ? '#7350ECA7' : '#1AFFFFFF' })
          .borderRadius(14)
          .scale({ x: this.dayKey === day.title ? MotionTokens.PRESS_SHORTCUT : 1, y: this.dayKey === day.title ? MotionTokens.PRESS_SHORTCUT : 1 })
          .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.dayKey = day.title
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.dayKey = ''
            }
          })
          .onClick(() => {
            this.activeDay = index
          })
        }, (day: GroupDay, index: number) => index.toString() + day.title)
      }
      .padding(2)
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
  }

  @Builder
  private dayPanel() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Text(this.days[this.activeDay].title)
          .fontFamily('Noto Sans SC')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text(this.days[this.activeDay].focus)
          .fontFamily('Noto Sans SC')
          .fontSize(12)
          .fontColor('#8AFFFFFF')
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      Column({ space: 9 }) {
        ForEach(this.days[this.activeDay].exercises, (exercise: GroupExercise, index: number) => {
          Row({ space: 12 }) {
            Column() {
              Text((index + 1).toString())
                .fontFamily('Inter')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#50ECA7')
            }
            .width(28)
            .height(28)
            .justifyContent(FlexAlign.Center)
            .borderRadius(9)
            .backgroundColor('#1A50ECA7')
            .border({ width: 1, color: '#3850ECA7' })

            Column({ space: 3 }) {
              Row({ space: 7 }) {
                Text(exercise.name)
                  .fontFamily('Noto Sans SC')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#F7FBF8')
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(exercise.muscle)
                  .fontFamily('Noto Sans SC')
                  .fontSize(10)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#8AFFFFFF')
                  .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                  .backgroundColor('#0FFFFFFF')
                  .border({ width: 1, color: '#0FFFFFFF' })
                  .borderRadius(999)
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Text(exercise.sets.toString() + ' × ' + exercise.reps)
              .fontFamily('Inter')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#8CEBCC')
          }
          .width('100%')
          .padding({ top: 12, bottom: 12, left: 13, right: 13 })
          .alignItems(VerticalAlign.Center)
          .backgroundColor('#151B20')
          .border({ width: 1, color: '#14FFFFFF' })
          .borderRadius(15)
          .scale({ x: this.exerciseKey === exercise.name ? MotionTokens.PRESS_PRIMARY : 1, y: this.exerciseKey === exercise.name ? MotionTokens.PRESS_PRIMARY : 1 })
          .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.exerciseKey = exercise.name
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.exerciseKey = ''
            }
          })
        }, (exercise: GroupExercise, index: number) => index.toString() + exercise.name)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private ctaBar() {
    Column() {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 7 }) {
          Path()
            .width(16)
            .height(16)
            .commands('M3.33 8.33 L6.33 11.33 L12.67 4.67')
            .fillOpacity(0)
            .stroke('#07100B')
            .strokeWidth(1.33)
            .strokeLineCap(LineCapStyle.Round)
            .strokeLineJoin(LineJoinStyle.Round)
          Text(this.isCurrent ? '已在使用' : '使用此计划')
            .fontFamily('Noto Sans SC')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#07100B')
            .letterSpacing(0.15)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height(52)
      .padding(0)
      .backgroundColor('#50ECA7')
      .borderRadius(16)
      .scale({ x: this.ctaPressed ? MotionTokens.PRESS_PRIMARY : 1, y: this.ctaPressed ? MotionTokens.PRESS_PRIMARY : 1 })
      .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.ctaPressed = true
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.ctaPressed = false
        }
      })
      .onClick(() => {
        this.usePlan()
      })
    }
    .width('100%')
    .padding({ top: 12, bottom: 20, left: 16, right: 16 })
    .backgroundColor('#EB0A0D12')
    .border({ width: { top: 1 }, color: '#0FFFFFFF' })
  }
}
