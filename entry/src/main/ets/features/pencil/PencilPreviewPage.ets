/** PencilPreviewPage —— FitTracker 训练预览页（依据 fittracker-training-preview.html 还原）。 */

import { AppRoutes } from '../../app/AppRoutes'

interface PreviewExerciseItem {
  name: string
  prescription: string
  current: boolean
}

const WARM_UP_EXERCISES: PreviewExerciseItem[] = [
  { name: '弹力带肩袖激活', prescription: '2 × 15', current: false },
  { name: '肩胛俯卧撑', prescription: '2 × 12', current: false }
]

const PRIMARY_EXERCISES: PreviewExerciseItem[] = [
  { name: '杠铃卧推', prescription: '4 × 6', current: true },
  { name: '上斜哑铃卧推', prescription: '3 × 8', current: false },
  { name: '坐姿肩推', prescription: '3 × 10', current: false },
  { name: '绳索下压', prescription: '3 × 12', current: false }
]

@Entry
@Component
struct PencilPreviewPage {
  @Builder
  private buildTopBar() {
    Row() {
      Row({ space: 12 }) {
        Stack({ alignContent: Alignment.Center }) {
          Text('‹')
            .fontFamily('Noto Sans SC')
            .fontSize(30)
            .fontColor('#D1FFFFFF')
        }
        .width(44)
        .height(44)
        .borderRadius(15)
        .backgroundColor('#08FFFFFF')
        .border({ width: 1, color: '#14FFFFFF' })
        .onClick(() => {
          this.getUIContext().getRouter().back()
        })

        Text('训练预览')
          .fontFamily('Noto Sans SC')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F7FBF8')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(VerticalAlign.Center)

      Stack({ alignContent: Alignment.Center }) {
        Text('⋯')
          .fontFamily('Noto Sans SC')
          .fontSize(22)
          .fontColor('#D1FFFFFF')
      }
      .width(44)
      .height(44)
      .borderRadius(15)
      .backgroundColor('#08FFFFFF')
      .border({ width: 1, color: '#14FFFFFF' })
      .onClick(() => {
        this.getUIContext().getPromptAction().showToast({ message: '更多选项（原型）' })
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildHero() {
    Column() {
      Text('Day 01')
        .fontFamily('Geist Mono')
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor('#50ECA7')
        .letterSpacing(2)

      Text('训练预览')
        .fontFamily('Noto Sans SC')
        .fontSize(32)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
        .margin({ top: 8 })

      Text('第 1 天 · 上肢力量')
        .fontFamily('Noto Sans SC')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#8AFFFFFF')
        .margin({ top: 8 })

      Stack({ alignContent: Alignment.Center }) {
        Image($rawfile('pencil-lucide-activity.svg'))
          .width(30)
          .height(30)
          .fillColor('#50ECA7')
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .border({ width: 2, color: '#4D50ECA7' })
      .margin({ top: 14 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .margin({ top: 16 })
  }

  @Builder
  private buildGroupLabel(text: string, topMargin: number) {
    Text(text)
      .fontFamily('Noto Sans SC')
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor('#8AFFFFFF')
      .letterSpacing(0.96)
      .padding({ left: 6, right: 6 })
      .margin({ top: topMargin, bottom: 8 })
  }

  @Builder
  private buildExerciseItem(item: PreviewExerciseItem) {
    Row() {
      Text(item.name)
        .fontFamily('Noto Sans SC')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(item.current ? '#F7FBF8' : '#E0FFFFFF')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text(item.prescription)
        .fontFamily('Inter')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(item.current ? '#50ECA7' : '#8AFFFFFF')
    }
    .width('100%')
    .height(52)
    .padding({ left: 14, right: 14 })
    .alignItems(VerticalAlign.Center)
    .borderRadius(16)
    .border({ width: 1, color: item.current ? '#4750ECA7' : '#0EFFFFFF' })
    .backgroundColor(item.current ? '#1A50ECA7' : '#07FFFFFF')
  }

  @Builder
  private buildExerciseList() {
    Column() {
      this.buildGroupLabel('热身动作', 0)
      Column({ space: 7 }) {
        ForEach(WARM_UP_EXERCISES, (item: PreviewExerciseItem) => {
          this.buildExerciseItem(item)
        }, (item: PreviewExerciseItem) => item.name)
      }
      .width('100%')

      this.buildGroupLabel('主动作', 18)
      Column({ space: 7 }) {
        ForEach(PRIMARY_EXERCISES, (item: PreviewExerciseItem) => {
          this.buildExerciseItem(item)
        }, (item: PreviewExerciseItem) => item.name)
      }
      .width('100%')
    }
    .width('100%')
    .layoutWeight(1)
    .margin({ top: 16 })
  }

  @Builder
  private buildActionSection() {
    Column({ space: 12 }) {
      Text('确认动作与重量后开始训练')
        .width('100%')
        .textAlign(TextAlign.Center)
        .fontFamily('Noto Sans SC')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor('#8AFFFFFF')

      Button('开始训练')
        .width('100%')
        .height(52)
        .fontFamily('Noto Sans SC')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#07100B')
        .linearGradient({
          angle: 180,
          colors: [['#53E7A5', 0], ['#47D994', 1]]
        })
        .borderRadius(26)
        .shadow({
          radius: 28,
          color: '#3D000000',
          offsetX: 0,
          offsetY: 14
        })
        .onClick(() => {
          this.getUIContext().getPromptAction().showToast({ message: '已准备进入训练执行' })
          this.getUIContext().getRouter().pushUrl({ url: AppRoutes.ACTIVE_WORKOUT })
        })
    }
    .width('100%')
    .margin({ top: 16 })
  }

  @Builder
  private buildHomeIndicator() {
    Column() {
      Row()
        .width(134)
        .height(5)
        .borderRadius(3)
        .backgroundColor('#40FFFFFF')
    }
    .width('100%')
    .margin({ top: 8 })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [['#0D1316', 0], ['#090C10', 1]]
        })

      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: [195, 169],
          radius: 468,
          colors: [['#1450ECA7', 0], ['#0050ECA7', 0.6]]
        })

      Column() {
        this.buildTopBar()
        this.buildHero()
        this.buildExerciseList()
        this.buildActionSection()
        this.buildHomeIndicator()
      }
      .width('100%')
      .height('100%')
      .padding({
        left: 18,
        right: 18,
        top: 56,
        bottom: 12
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0A0D12')
  }
}
