/** PencilActivePage - FitTracker Active Workout prototype page. */
import { AppRoutes } from '../../app/AppRoutes'
import { WorkoutSession, WorkoutSet, createWorkoutSession, createWorkoutSet } from '../../shared/models/TrainingModels'
import WorkoutRepository from '../../shared/services/WorkoutRepository'

interface SetRecordItem {
  index: number
  weight: number
  reps: number
}

function createSetRecord(index: number, weight: number, reps: number): SetRecordItem {
  const item: SetRecordItem = {
    index: index,
    weight: weight,
    reps: reps
  }
  return item
}

const PROGRESS_SEGMENTS: number[] = [0, 1, 2, 3, 4, 5]

interface CelebratePiece {
  id: string
  x: number
  y: number
  width: number
  height: number
  rot: number
  color: string
}

const CELEBRATE_PIECES: CelebratePiece[] = [
  { id: 'cp0', x: 120, y: 220, width: 8, height: 14, rot: 25, color: '#50ECA7' },
  { id: 'cp1', x: 268, y: 212, width: 8, height: 14, rot: -30, color: '#8CEBCC' },
  { id: 'cp2', x: 300, y: 330, width: 8, height: 14, rot: 15, color: '#45C9A1' },
  { id: 'cp3', x: 86, y: 342, width: 8, height: 14, rot: -20, color: '#F7FBF8' },
  { id: 'cp4', x: 148, y: 432, width: 8, height: 14, rot: 40, color: '#50ECA7' },
  { id: 'cp5', x: 248, y: 444, width: 8, height: 14, rot: -45, color: '#8CEBCC' },
  { id: 'cp6', x: 187, y: 168, width: 8, height: 14, rot: 12, color: '#45C9A1' },
  { id: 'cp7', x: 78, y: 262, width: 8, height: 14, rot: -15, color: '#F7FBF8' },
  { id: 'cp8', x: 296, y: 258, width: 8, height: 14, rot: 30, color: '#50ECA7' },
  { id: 'cp9', x: 122, y: 186, width: 8, height: 14, rot: -35, color: '#8CEBCC' },
  { id: 'cp10', x: 254, y: 190, width: 8, height: 14, rot: 20, color: '#45C9A1' },
  { id: 'cp11', x: 202, y: 494, width: 8, height: 14, rot: -25, color: '#F7FBF8' }
]

function formatClock(totalSeconds: number): string {
  const minutes: number = Math.floor(totalSeconds / 60)
  const seconds: number = totalSeconds % 60
  const mm: string = minutes < 10 ? '0' + minutes.toString() : minutes.toString()
  const ss: string = seconds < 10 ? '0' + seconds.toString() : seconds.toString()
  return mm + ':' + ss
}

@Component
export struct PencilActiveContent {
  @State private completed: number = 0
  @State private weight: number = 32
  @State private reps: number = 9
  @State private showModal: boolean = false
  @State private records: SetRecordItem[] = []
  @State private celebrating: boolean = false
  @State private elapsedSeconds: number = 0
  private celebrateTimer: number = -1
  private clockTimer: number = -1
  private finished: boolean = false

  aboutToAppear(): void {
    this.clockTimer = setInterval(() => {
      this.elapsedSeconds += 1
    }, 1000)
  }

  aboutToDisappear(): void {
    if (this.clockTimer !== -1) {
      clearInterval(this.clockTimer)
      this.clockTimer = -1
    }
    if (this.celebrateTimer !== -1) {
      clearTimeout(this.celebrateTimer)
      this.celebrateTimer = -1
    }
  }

  private finish(): void {
    this.getUIContext().getRouter().pushUrl({ url: AppRoutes.WORKOUT_COMPLETE })
  }

  private openModal(): void {
    if (this.completed < PROGRESS_SEGMENTS.length) {
      this.showModal = true
    }
  }

  private closeModal(): void {
    this.showModal = false
  }

  private changeWeight(delta: number): void {
    this.weight = Math.max(20, Math.min(200, this.weight + delta))
  }

  private changeReps(delta: number): void {
    this.reps = Math.max(1, Math.min(15, this.reps + delta))
  }

  private completeSet(): void {
    if (this.completed >= PROGRESS_SEGMENTS.length || this.finished) {
      return
    }
    const nextRecords: SetRecordItem[] = this.records.slice()
    nextRecords.push(createSetRecord(this.completed + 1, this.weight, this.reps))
    this.records = nextRecords
    this.completed += 1
    this.showModal = false
    this.celebrating = true
    const isLast: boolean = this.completed >= PROGRESS_SEGMENTS.length
    if (isLast) {
      this.finished = true
      this.saveCompletedSession()
    }
    this.celebrateTimer = setTimeout(() => {
      this.celebrating = false
      this.celebrateTimer = -1
      if (isLast) {
        this.finish()
      }
    }, isLast ? 900 : 1400)
  }

  private saveCompletedSession(): void {
    const sets: WorkoutSet[] = []
    let totalVolume: number = 0
    for (let index = 0; index < this.records.length; index++) {
      const record: SetRecordItem = this.records[index]
      const set: WorkoutSet = createWorkoutSet(
        'set_' + record.index.toString(),
        'bench_press',
        record.weight,
        record.reps,
        0,
        false
      )
      sets.push(set)
      totalVolume += record.weight * record.reps
    }
    const endedAt: number = Date.now()
    const startedAt: number = endedAt - 60000
    const session: WorkoutSession = createWorkoutSession(
      'session_' + endedAt.toString(),
      'active_plan',
      'active_day',
      startedAt,
      endedAt,
      60,
      sets.length,
      Math.round(totalVolume * 100) / 100,
      0,
      'completed_sets=' + sets.length.toString() + ';target_sets=' + PROGRESS_SEGMENTS.length.toString(),
      sets
    )
    WorkoutRepository.saveSession(session)
  }

  private segmentBackground(index: number): string {
    if (index < this.completed) {
      return '#50ECA7'
    }
    if (index === this.completed) {
      return '#2950ECA7'
    }
    return '#12FFFFFF'
  }

  private segmentBorder(index: number): string {
    if (index < this.completed) {
      return '#50ECA7'
    }
    if (index === this.completed) {
      return '#8050ECA7'
    }
    return '#0DFFFFFF'
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#0B0F13')

      Column() {
        this.topProgress()
        Column() {
          this.demoCard()
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 12, bottom: 14 })
        Scroll() {
          this.setList()
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 18, right: 18, top: 0, bottom: 24 })

        this.dock()
      }
      .width('100%')
      .height('100%')

      if (this.showModal) {
        this.recordModal()
      }

      this.celebrateOverlay()
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private topProgress() {
    Column({ space: 10 }) {
      Row() {
        Text(this.completed >= PROGRESS_SEGMENTS.length
          ? '训练完成 · 全部 ' + PROGRESS_SEGMENTS.length.toString() + ' 组'
          : '第 ' + (this.completed + 1).toString() + ' 组 / 共 ' + PROGRESS_SEGMENTS.length.toString() + ' 组')
          .fontFamily('Noto Sans SC')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#B3FFFFFF')
        Row({ space: 6 }) {
          Text('●')
            .fontFamily('HarmonyOS Sans')
            .fontSize(8)
            .fontColor('#50ECA7')
          Text('总时长')
            .fontFamily('Noto Sans SC')
            .fontSize(12)
            .fontColor('#99FFFFFF')
          Text(formatClock(this.elapsedSeconds))
            .fontFamily('Geist Mono')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F7FBF8')
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Row({ space: 6 }) {
        ForEach(PROGRESS_SEGMENTS, (index: number) => {
          Stack({ alignContent: Alignment.Center }) {
            Row()
              .width('100%')
              .height(12)
              .backgroundColor(this.segmentBackground(index))
              .borderRadius(999)
              .border({ width: 1, color: this.segmentBorder(index) })
            if (index === this.completed) {
              Row()
                .width(18)
                .height(18)
                .backgroundColor('#50ECA7')
                .borderRadius(9)
                .border({ width: 3, color: '#0B0F13' })
            }
          }
          .layoutWeight(1)
          .height(18)
        }, (index: number) => index.toString())
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 14, bottom: 12 })
    .backgroundColor('#0A0D12F5')
    .border({ width: { bottom: 1 }, color: '#0FFFFFFF' })
  }

  @Builder
  private demoCard() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#101816')

      this.demoVisual()

      Row({ space: 6 }) {
        Text('动作')
          .fontFamily('Noto Sans SC')
          .fontSize(11)
          .fontColor('#99FFFFFF')
        Text('1 / 4')
          .fontFamily('Geist Mono')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#50ECA7')
      }
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor('#081017D1')
      .borderRadius(999)
      .border({ width: 1, color: '#1AFFFFFF' })
      .position({ x: 14, y: 14 })

      Row() {
        Text('杠铃卧推')
          .fontFamily('Noto Sans SC')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text('第 ' + (this.completed + 1).toString() + ' 组 · 正式组')
          .fontFamily('Noto Sans SC')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#50ECA7')
      }
      .width(326)
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .justifyContent(FlexAlign.SpaceBetween)
      .backgroundColor('#081017D1')
      .borderRadius(16)
      .border({ width: 1, color: '#14FFFFFF' })
      .position({ x: 14, y: 178 })
    }
    .width('100%')
    .height(230)
    .borderRadius(28)
    .border({ width: 1, color: '#14FFFFFF' })
    .clip(true)
  }

  @Builder
  private demoVisual() {
    Stack({ alignContent: Alignment.TopStart }) {
      Row()
        .width(276)
        .height(12)
        .borderRadius(6)
        .linearGradient({
          angle: 180,
          colors: [['#2A3934', 0], ['#16211F', 1]]
        })
        .position({ x: 42, y: 158 })

      Row()
        .width(12)
        .height(36)
        .borderRadius(4)
        .backgroundColor('#101816')
        .position({ x: 66, y: 170 })

      Row()
        .width(12)
        .height(36)
        .borderRadius(4)
        .backgroundColor('#101816')
        .position({ x: 282, y: 170 })

      Row()
        .width(32)
        .height(32)
        .borderRadius(16)
        .backgroundColor('#0D1117')
        .border({ width: 2, color: '#2950ECA7' })
        .position({ x: 160, y: 56 })

      Row()
        .width(24)
        .height(62)
        .borderRadius(12)
        .backgroundColor('#0D1117')
        .border({ width: 2, color: '#2950ECA7' })
        .position({ x: 164, y: 88 })

      Row()
        .width(64)
        .height(15)
        .borderRadius(7)
        .backgroundColor('#0D1117')
        .border({ width: 2, color: '#2950ECA7' })
        .position({ x: 188, y: 142 })

      Row()
        .width(64)
        .height(15)
        .borderRadius(7)
        .backgroundColor('#0D1117')
        .border({ width: 2, color: '#2950ECA7' })
        .position({ x: 256, y: 142 })

      Path()
        .width(30)
        .height(20)
        .commands('M24 6 L6 14')
        .fillOpacity(0)
        .stroke('#0D1117')
        .strokeWidth(12)
        .strokeLineCap(LineCapStyle.Round)
        .position({ x: 144, y: 94 })

      Path()
        .width(30)
        .height(20)
        .commands('M6 6 L24 14')
        .fillOpacity(0)
        .stroke('#0D1117')
        .strokeWidth(12)
        .strokeLineCap(LineCapStyle.Round)
        .position({ x: 178, y: 94 })

      Row()
        .width(312)
        .height(8)
        .borderRadius(4)
        .linearGradient({
          angle: 180,
          colors: [['#7E8F96', 0], ['#3B4A45', 1]]
        })
        .position({ x: 24, y: 100 })

      Row()
        .width(34)
        .height(34)
        .borderRadius(17)
        .radialGradient({
          center: [17, 17],
          radius: 17,
          colors: [['#243B35', 0], ['#0F1716', 0.65], ['#080D0C', 1]]
        })
        .border({ width: 1.5, color: '#0B0F13' })
        .position({ x: 23, y: 87 })

      Row()
        .width(28)
        .height(28)
        .borderRadius(14)
        .radialGradient({
          center: [14, 14],
          radius: 14,
          colors: [['#243B35', 0], ['#0F1716', 0.65], ['#080D0C', 1]]
        })
        .border({ width: 1.5, color: '#0B0F13' })
        .position({ x: 44, y: 90 })

      Row()
        .width(34)
        .height(34)
        .borderRadius(17)
        .radialGradient({
          center: [17, 17],
          radius: 17,
          colors: [['#243B35', 0], ['#0F1716', 0.65], ['#080D0C', 1]]
        })
        .border({ width: 1.5, color: '#0B0F13' })
        .position({ x: 303, y: 87 })

      Row()
        .width(28)
        .height(28)
        .borderRadius(14)
        .radialGradient({
          center: [14, 14],
          radius: 14,
          colors: [['#243B35', 0], ['#0F1716', 0.65], ['#080D0C', 1]]
        })
        .border({ width: 1.5, color: '#0B0F13' })
        .position({ x: 288, y: 90 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private setList() {
    Column({ space: 10 }) {
      if (this.records.length === 0) {
        Column() {
          Text('还没有完成组')
            .fontFamily('Noto Sans SC')
            .fontSize(13)
            .fontColor('#8AFFFFFF')
        }
        .width('100%')
        .height(52)
        .justifyContent(FlexAlign.Center)
        .border({ width: 1, color: '#1AFFFFFF', style: BorderStyle.Dashed })
        .borderRadius(14)
      } else {
        ForEach(this.records, (record: SetRecordItem) => {
          Row() {
            Text('第 ' + record.index.toString() + ' 组')
              .fontFamily('Noto Sans SC')
              .fontSize(13)
              .fontColor('#B3FFFFFF')
            Text(record.weight.toString() + ' kg × ' + record.reps.toString())
              .fontFamily('Geist Mono')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F7FBF8')
            Text('✓')
              .fontFamily('HarmonyOS Sans')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#50ECA7')
          }
          .width('100%')
          .height(44)
          .padding({ left: 12, right: 12 })
          .justifyContent(FlexAlign.SpaceBetween)
          .backgroundColor('#08FFFFFF')
          .borderRadius(12)
          .border({ width: 1, color: '#14FFFFFF' })
        }, (record: SetRecordItem) => record.index.toString())
      }
    }
    .width('100%')
  }

  @Builder
  private dock() {
    Column() {
      Button('提交')
        .width('100%')
        .height(50)
        .padding(0)
        .fontFamily('Noto Sans SC')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#07100B')
        .backgroundColor('#50ECA7')
        .borderRadius(16)
        .shadow({ radius: 22, color: '#3D000000', offsetX: 0, offsetY: 10 })
        .onClick(() => {
          this.openModal()
        })
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 12, bottom: 18 })
    .backgroundColor('#0A0D12FA')
    .border({ width: { top: 1 }, color: '#0FFFFFFF' })
  }

  @Builder
  private recordModal() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#030606B8')

      Column({ space: 18 }) {
        Row() {
          Column({ space: 4 }) {
            Text('RECORD SET')
              .fontFamily('Geist Mono')
              .fontSize(10)
              .fontColor('#50ECA7')
            Text('记录本组')
              .fontFamily('Noto Sans SC')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F7FBF8')
            Text('杠铃卧推 · 第 ' + (this.completed + 1).toString() + ' 组')
              .fontFamily('Noto Sans SC')
              .fontSize(13)
              .fontColor('#99FFFFFF')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text('×')
            .fontFamily('HarmonyOS Sans')
            .fontSize(20)
            .fontColor('#B3FFFFFF')
            .width(36)
            .height(36)
            .textAlign(TextAlign.Center)
            .backgroundColor('#08FFFFFF')
            .borderRadius(18)
            .border({ width: 1, color: '#14FFFFFF' })
            .onClick(() => {
              this.closeModal()
            })
        }
        .width('100%')

        Row({ space: 12 }) {
          this.inputBox('重量', 'KG', this.weight, true)
          this.inputBox('次数', '8–10', this.reps, false)
        }
        .width('100%')

        Button('完成本组')
          .width('100%')
          .height(50)
          .padding(0)
          .fontFamily('Noto Sans SC')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#07100B')
          .backgroundColor('#50ECA7')
          .borderRadius(16)
          .onClick(() => {
            this.completeSet()
          })
      }
      .width(342)
      .padding(20)
      .backgroundColor('#101816')
      .borderRadius(28)
      .border({ width: 1, color: '#1AFFFFFF' })
      .shadow({ radius: 60, color: '#80000000', offsetX: 0, offsetY: 28 })
    }
    .width('100%')
    .height('100%')
    .onClick(() => {
      this.closeModal()
    })
  }

  @Builder
  private celebrateOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      ForEach(CELEBRATE_PIECES, (piece: CelebratePiece) => {
        Row()
          .width(piece.width)
          .height(piece.height)
          .backgroundColor(piece.color)
          .borderRadius(2)
          .rotate({ angle: piece.rot })
          .position({ x: piece.x, y: piece.y })
      }, (piece: CelebratePiece) => piece.id)

      Column({ space: 12 }) {
        Row() {
          Text('✓')
            .fontFamily('HarmonyOS Sans')
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor('#07100B')
        }
        .width(68)
        .height(68)
        .borderRadius(34)
        .backgroundColor('#50ECA7')
        .justifyContent(FlexAlign.Center)
        .shadow({ radius: 10, color: '#2450ECA7', offsetX: 0, offsetY: 0 })
        .scale({ x: this.celebrating ? 1 : 0.72, y: this.celebrating ? 1 : 0.72 })
        .animation({ duration: 220, curve: Curve.EaseOut })

        Text('本组完成')
          .fontFamily('HarmonyOS Sans')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
      }
    }
    .width('100%')
    .height('100%')
    .opacity(this.celebrating ? 1 : 0)
    .visibility(this.celebrating ? Visibility.Visible : Visibility.Hidden)
    .animation({ duration: 180, curve: Curve.EaseOut })
  }

  @Builder
  private inputBox(label: string, unit: string, value: number, isWeight: boolean) {
    Column({ space: 8 }) {
      Row() {
        Text(label)
          .fontFamily('Noto Sans SC')
          .fontSize(12)
          .fontColor('#99FFFFFF')
        Text(unit)
          .fontFamily('Geist Mono')
          .fontSize(10)
          .fontColor('#50ECA7')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Row() {
        Text('−')
          .fontFamily('HarmonyOS Sans')
          .fontSize(16)
          .fontColor('#99FFFFFF')
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
          .backgroundColor('#08FFFFFF')
          .borderRadius(10)
          .border({ width: 1, color: '#0FFFFFFF' })
          .onClick(() => {
            if (isWeight) {
              this.changeWeight(-1)
            } else {
              this.changeReps(-1)
            }
          })
        Text(value.toString())
          .fontFamily('Geist Mono')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('+')
          .fontFamily('HarmonyOS Sans')
          .fontSize(16)
          .fontColor('#99FFFFFF')
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
          .backgroundColor('#08FFFFFF')
          .borderRadius(10)
          .border({ width: 1, color: '#0FFFFFFF' })
          .onClick(() => {
            if (isWeight) {
              this.changeWeight(1)
            } else {
              this.changeReps(1)
            }
          })
      }
      .width('100%')
    }
    .layoutWeight(1)
    .padding(12)
    .backgroundColor('#06FFFFFF')
    .borderRadius(17)
    .border({ width: 1, color: '#0FFFFFFF' })
  }
}

@Entry
@Component
struct PencilActivePage {
  build() {
    Column() {
      PencilActiveContent()
    }
  }
}
