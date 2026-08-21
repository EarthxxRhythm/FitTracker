/** PencilPlanPage - FitTracker Plan prototype page. */

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

const PLAN_DAYS: PlanDayItem[] = [
  createPlanDay('胸', '胸部日', '胸部 · 推力', '胸部', '62 分钟', '今日', true, [
    createPlanExercise('杠铃平板卧推', '胸部', '4', '8-12'),
    createPlanExercise('上斜哑铃卧推', '胸部', '3', '8-12'),
    createPlanExercise('哑铃飞鸟', '胸部', '3', '12-15'),
    createPlanExercise('绳索夹胸', '胸部', '3', '12-15'),
    createPlanExercise('双杠臂屈伸', '胸部', '3', '8-12')
  ]),
  createPlanDay('背', '背部日', '背部 · 拉力', '背部', '58 分钟', '明日', false, [
    createPlanExercise('引体向上', '背部', '4', '8-12'),
    createPlanExercise('杠铃划船', '背部', '4', '8-12'),
    createPlanExercise('高位下拉', '背部', '3', '10-12'),
    createPlanExercise('坐姿划船', '背部', '3', '10-12'),
    createPlanExercise('面拉', '背部', '3', '12-15')
  ]),
  createPlanDay('腿', '腿部日', '腿部 · 力量', '腿部', '66 分钟', '后天', false, [
    createPlanExercise('杠铃深蹲', '腿部', '4', '8-12'),
    createPlanExercise('罗马尼亚硬拉', '腿部', '3', '8-12'),
    createPlanExercise('腿举', '腿部', '3', '10-12'),
    createPlanExercise('腿弯举', '腿部', '3', '12-15'),
    createPlanExercise('提踵', '腿部', '4', '15-20')
  ]),
  createPlanDay('肩', '肩部日', '肩部 · 泵感', '肩部', '52 分钟', '第 4 天', false, [
    createPlanExercise('杠铃推举', '肩部', '4', '8-12'),
    createPlanExercise('哑铃侧平举', '肩部', '3', '12-15'),
    createPlanExercise('前平举', '肩部', '3', '12-15'),
    createPlanExercise('俯身飞鸟', '肩部', '3', '12-15'),
    createPlanExercise('耸肩', '肩部', '3', '12-15')
  ]),
  createPlanDay('臂', '手臂日', '手臂 · 收尾', '手臂', '48 分钟', '第 5 天', false, [
    createPlanExercise('杠铃弯举', '手臂', '4', '8-12'),
    createPlanExercise('哑铃锤式弯举', '手臂', '3', '10-12'),
    createPlanExercise('窄距卧推', '手臂', '4', '8-12'),
    createPlanExercise('绳索下压', '手臂', '3', '12-15'),
    createPlanExercise('集中弯举', '手臂', '3', '12-15')
  ])
]

@Component
export struct PencilPlanContent {
  @State private activeCard: number = 0

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

  build() {
    Column() {
      Column({ space: 16 }) {
        this.masterCard()
        Stack({ alignContent: Alignment.TopStart }) {
          ForEach(PLAN_DAYS, (day: PlanDayItem, index: number) => {
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
                if (isLeft && this.activeCard < PLAN_DAYS.length - 1) {
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
    Column({ space: 10 }) {
      Row() {
        Text('当前计划')
          .fontFamily('Noto Sans SC')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#50ECA7')
        Text('本周 1 / 5 天')
          .fontFamily('Inter')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor('#50ECA7')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Text('五日增肌计划')
        .fontFamily('Noto Sans SC')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
        .width('100%')

      Text('增肌 · 5 练分化 · 6 周推进')
        .fontFamily('Noto Sans SC')
        .fontSize(11.5)
        .fontColor('#9EFFFFFF')
        .width('100%')

      Row({ space: 10 }) {
        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width('100%')
            .height(6)
            .backgroundColor('#2450ECA7')
            .borderRadius(999)
          Row()
            .width('20%')
            .height(6)
            .backgroundColor('#50ECA7')
            .borderRadius(999)
        }
        .layoutWeight(1)
        .height(6)

        Text('第 1 天 · 胸')
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
    .border({ width: 1, color: '#1AFFFFFF' })
    .shadow({ radius: 28, color: '#33000000', offsetX: 0, offsetY: 14 })
  }

  @Builder
  private deckCard(day: PlanDayItem, index: number) {
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
    .width(310)
    .height('100%')
    .padding(18)
    .backgroundColor('#151B20')
    .borderRadius(24)
    .border({ width: 1, color: '#17FFFFFF' })
    .shadow({ radius: 36, color: '#52000000', offsetX: 0, offsetY: 18 })
    .position({ x: 24, y: 0 })
    .translate({ x: this.rel(index) * 267, y: 16 * Math.abs(this.rel(index)) })
    .rotate({ angle: this.rel(index) * 6 })
    .scale({ x: this.scaleFor(this.rel(index)), y: this.scaleFor(this.rel(index)) })
    .opacity(this.opacityFor(this.rel(index)))
    .zIndex(this.zFor(this.rel(index)))
  }
}

@Entry
@Component
struct PencilPlanPage {
  build() {
    Column() {
      PencilPlanContent()
    }
  }
}
