/** PlanGroupDetailContent —— 计划组详细页界面体（对应 plan-group-detail.html · screen-plan-group-detail）。 */
import { MotionTokens } from '../../../common/styles/DesignTokens'

interface GroupExercise {
  name: string
  sets: number
  reps: string
  equipment: string
  note: string
}

interface GroupDay {
  title: string
  focus: string
  exercises: GroupExercise[]
}

function createGroupExercise(name: string, sets: number, reps: string, equipment: string, note: string): GroupExercise {
  return {
    name: name,
    sets: sets,
    reps: reps,
    equipment: equipment,
    note: note
  }
}

function createGroupDay(title: string, focus: string, exercises: GroupExercise[]): GroupDay {
  return {
    title: title,
    focus: focus,
    exercises: exercises
  }
}

@Component
export struct PlanGroupDetailContent {
  @State private backPressed: boolean = false
  @State private ctaPressed: boolean = false
  @State private dayKey: string = ''
  @State private activeDay: number = 0
  @State private toastVisible: boolean = false
  @State private toastTimer: number = -1

  private readonly planName: string = '推拉腿分裂'
  private readonly planDesc: string = '按动作模式循环：推（胸、肩、三头）、拉（背、二头）、腿（下肢）。每个部位每周练 1-2 次，适合各阶段训练者。'
  private readonly planTags: string[] = ['初中高级通用', '3 天 / 周', '3 个训练日']
  private readonly weekCells: string[] = ['推', '拉', '腿', '休', '休', '休', '休']
  private readonly days: GroupDay[] = [
    createGroupDay('推', '胸大肌 · 三角肌 · 肱三头肌', [
      createGroupExercise('杠铃卧推', 4, '8', '杠铃', '主项 · 肩胛后收下沉'),
      createGroupExercise('站姿推举', 3, '10', '哑铃', '核心收紧 · 不反弓'),
      createGroupExercise('哑铃侧平举', 3, '12', '哑铃', '轻重量控制 · 不耸肩'),
      createGroupExercise('绳索下压', 3, '12', '器械', '肘部固定 · 顶峰收缩')
    ]),
    createGroupDay('拉', '背阔肌 · 菱形肌 · 肱二头肌', [
      createGroupExercise('引体向上', 4, '8', '自重', '肩胛下沉 · 可负重'),
      createGroupExercise('杠铃划船', 4, '10', '杠铃', '背部平直 · 肩胛后收'),
      createGroupExercise('高位下拉', 3, '12', '器械', '下拉至锁骨 · 不耸肩'),
      createGroupExercise('二头弯举', 3, '12', '哑铃', '上臂贴紧 · 不借力')
    ]),
    createGroupDay('腿', '股四头肌 · 腘绳肌 · 臀大肌', [
      createGroupExercise('杠铃深蹲', 4, '8', '杠铃', '主项 · 膝盖同脚尖'),
      createGroupExercise('腿举', 3, '12', '器械', '下放至 90° · 不锁膝'),
      createGroupExercise('腿弯举', 3, '12', '器械', '控制离心 · 顶峰收缩'),
      createGroupExercise('弓步蹲', 3, '12', '哑铃', '每侧 · 身体垂直下沉')
    ])
  ]

  private handleBack(): void {
    this.getUIContext().getRouter().back()
  }

  private usePlan(): void {
    this.toastVisible = true
    if (this.toastTimer >= 0) {
      clearTimeout(this.toastTimer)
    }
    this.toastTimer = setTimeout(() => {
      this.toastVisible = false
    }, 1600)
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
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 180, colors: [['#0B0F13', 0], ['#0A0D12', 1]] })

      Column() {
        Row({ space: 10 }) {
          Row()
            .width(44)
            .height(44)
            .borderRadius(22)
            .backgroundColor('#0CFFFFFF')
            .border({ width: 1, color: '#14FFFFFF' })
            .justifyContent(FlexAlign.Center)
            .overlay(
              Path()
                .width(20)
                .height(20)
                .commands('M14 6 L8 12 L14 18')
                .fillOpacity(0)
                .stroke('#B3FFFFFF')
                .strokeWidth(2)
            )
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
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F7FBF8')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Row()
            .width(44)
            .height(44)
        }
        .width('100%')
        .padding({ top: 50, bottom: 12, left: 16, right: 16 })
        .alignItems(VerticalAlign.Center)

        Scroll() {
          Column({ space: 14 }) {
            this.summaryCard()
            this.rhythmCard()
            this.dayTabs()
            this.dayPanel()
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 24 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)

        Button('使用此计划')
          .width('100%')
          .height(54)
          .padding(0)
          .fontFamily('Noto Sans SC')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#07100B')
          .linearGradient({ angle: 90, colors: [['#47D994', 0], ['#53E7A5', 1]] })
          .borderRadius(18)
          .margin({ left: 16, right: 16, bottom: 18, top: 4 })
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
      .height('100%')

      if (this.toastVisible) {
        Text('已将「推拉腿分裂」设为当前计划')
          .fontFamily('Noto Sans SC')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#07100B')
          .backgroundColor('#50ECA7')
          .borderRadius(999)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .position({ x: '50%', y: '84%' })
          .translate({ x: -90 })
          .transition(TransitionEffect.OPACITY.animation({ duration: MotionTokens.DURATION_OVERLAY, curve: MotionTokens.EASE_MOTION }))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0B0F13')
  }

  @Builder
  private summaryCard() {
    Column() {
      Text('计划组')
        .fontFamily('Noto Sans SC')
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor('#50ECA7')
        .letterSpacing(0.4)
      Text(this.planName)
        .fontFamily('Noto Sans SC')
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
        .margin({ top: 8 })
      Text(this.planDesc)
        .fontFamily('Noto Sans SC')
        .fontSize(13)
        .lineHeight(21)
        .fontColor('#9EFFFFFF')
        .margin({ top: 10 })
      Row({ space: 8 }) {
        ForEach(this.planTags, (tag: string) => {
          Text(tag)
            .fontFamily('Noto Sans SC')
            .fontSize(10.5)
            .fontWeight(FontWeight.Medium)
            .fontColor('#B3FFFFFF')
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor('#0FFFFFFF')
            .border({ width: 1, color: '#0FFFFFFF' })
            .borderRadius(999)
        }, (tag: string) => tag)
      }
      .width('100%')
      .margin({ top: 14 })
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#08FFFFFF')
    .border({ width: 1, color: '#1AFFFFFF' })
    .borderRadius(22)
  }

  @Builder
  private rhythmCard() {
    Column() {
      Text('每周节奏')
        .fontFamily('Noto Sans SC')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
      Row() {
        ForEach(this.weekCells, (cell: string, index: number) => {
          Column() {
            Text(cell)
              .fontFamily('Noto Sans SC')
              .fontSize(12)
              .fontWeight(this.isWeekRest(cell) ? FontWeight.Medium : FontWeight.Bold)
              .fontColor(this.isWeekRest(cell) ? '#66FFFFFF' : '#07100B')
          }
          .layoutWeight(1)
          .height(34)
          .justifyContent(FlexAlign.Center)
          .borderRadius(10)
          .backgroundColor(this.isWeekRest(cell) ? '#0FFFFFFF' : '#50ECA7')
          .margin({ right: index < this.weekCells.length - 1 ? 4 : 0 })
        }, (cell: string) => cell)
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#08FFFFFF')
    .border({ width: 1, color: '#1AFFFFFF' })
    .borderRadius(22)
  }

  @Builder
  private dayTabs() {
    Row({ space: 8 }) {
      ForEach(this.days, (day: GroupDay, index: number) => {
        Button(day.title)
          .layoutWeight(1)
          .height(40)
          .padding(0)
          .fontFamily('Noto Sans SC')
          .fontSize(14.5)
          .fontWeight(this.activeDay === index ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.activeDay === index ? '#07100B' : '#B3FFFFFF')
          .backgroundColor(this.activeDay === index ? '#50ECA7' : '#0FFFFFFF')
          .border({ width: 1, color: this.activeDay === index ? '#50ECA7' : '#14FFFFFF' })
          .borderRadius(14)
          .scale({ x: this.dayKey === day.title ? MotionTokens.PRESS_SEGMENT : 1, y: this.dayKey === day.title ? MotionTokens.PRESS_SEGMENT : 1 })
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
      }, (day: GroupDay) => day.title)
    }
    .width('100%')
    .margin({ top: 2 })
  }

  @Builder
  private dayPanel() {
    Column() {
      Text(this.days[this.activeDay].title + '日 · ' + this.days[this.activeDay].focus)
        .fontFamily('Noto Sans SC')
        .fontSize(13.5)
        .fontColor('#B3FFFFFF')
      Column() {
        ForEach(this.days[this.activeDay].exercises, (exercise: GroupExercise, index: number) => {
          Row() {
            Text((index + 1).toString().padStart(2, '0'))
              .fontFamily('Inter')
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor('#50ECA7')
              .width(28)
            Column({ space: 4 }) {
              Row({ space: 6 }) {
                Text(exercise.name)
                  .fontFamily('Noto Sans SC')
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#F7FBF8')
                Text(exercise.equipment)
                  .fontFamily('Noto Sans SC')
                  .fontSize(10.5)
                  .fontColor('#66FFFFFF')
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .backgroundColor('#0FFFFFFF')
                  .borderRadius(999)
              }
              Text(exercise.note)
                .fontFamily('Noto Sans SC')
                .fontSize(12)
                .fontColor('#8AFFFFFF')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            Text(exercise.sets.toString() + ' × ' + exercise.reps)
              .fontFamily('Inter')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#50ECA7')
          }
          .width('100%')
          .padding({ top: 12, bottom: 12 })
          .border({ width: { bottom: 1 }, color: '#0FFFFFFF' })
        }, (exercise: GroupExercise) => exercise.name)
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#08FFFFFF')
    .border({ width: 1, color: '#1AFFFFFF' })
    .borderRadius(22)
  }
}
