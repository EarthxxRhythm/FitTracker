/** PencilActivePage - FitTracker Active Workout prototype page. */
import { AppRoutes } from '../../app/AppRoutes'

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

@Component
export struct PencilActiveContent {
  @State private completed: number = 2
  @State private weight: number = 32
  @State private reps: number = 9
  @State private showModal: boolean = false
  @State private records: SetRecordItem[] = []

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
    if (this.completed >= PROGRESS_SEGMENTS.length) {
      return
    }
    const nextRecords: SetRecordItem[] = this.records.slice()
    nextRecords.push(createSetRecord(this.completed + 1, this.weight, this.reps))
    this.records = nextRecords
    this.completed += 1
    this.showModal = false
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
        Scroll() {
          Column({ space: 14 }) {
            this.demoCard()
            this.setList()
          }
          .width('100%')
          .padding({ left: 18, right: 18, top: 16, bottom: 24 })
        }
        .layoutWeight(1)
        .width('100%')

        this.dock()
      }
      .width('100%')
      .height('100%')

      if (this.showModal) {
        this.recordModal()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private topProgress() {
    Column({ space: 10 }) {
      Row() {
        Text('第 ' + (this.completed + 1).toString() + ' 组 / 共 ' + PROGRESS_SEGMENTS.length.toString() + ' 组')
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
          Text('00:00')
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
        .linearGradient({
          angle: 180,
          colors: [['#2A3934', 0], ['#16211F', 1]]
        })

      Image($rawfile('pencil-lucide-person-standing.svg'))
        .width(150)
        .height(150)
        .fillColor('#7E8F96')
        .position({ x: 105, y: 38 })

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
