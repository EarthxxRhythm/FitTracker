/** PencilPreviewPage —— FitTracker Workout Preview prototype page. 功能 #27 */

import { AppRoutes } from '../../app/AppRoutes'

@Entry
@Component
struct PencilPreviewPage {
  private static readonly SCALE: number = 390 / 430

  @Builder
  private buildPreviewHero() {
    Column({ space: 6 * PencilPreviewPage.SCALE }) {
      Text('训练预览')
        .fontFamily('Inter')
        .fontSize(28 * PencilPreviewPage.SCALE)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
      Text('第 1 天 · 上肢力量')
        .fontFamily('Inter')
        .fontSize(13 * PencilPreviewPage.SCALE)
        .fontWeight(FontWeight.Medium)
        .fontColor('#7AFFFFFF')
    }
    .width('100%')
    .height(48 * PencilPreviewPage.SCALE)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildExerciseSection() {
    Column() {
      Text('动作清单')
        .width('100%')
        .height(48 * PencilPreviewPage.SCALE)
        .textAlign(TextAlign.Center)
        .fontFamily('Inter')
        .fontSize(14 * PencilPreviewPage.SCALE)
        .fontWeight(FontWeight.Bold)
        .fontColor('#8FFFFFFF')

      Column() {
        Text('热身动作')
          .width('100%')
          .height(17 * PencilPreviewPage.SCALE)
          .textAlign(TextAlign.Center)
          .fontFamily('Inter')
          .fontSize(13 * PencilPreviewPage.SCALE)
          .fontWeight(FontWeight.Medium)
          .fontColor('#8FFFFFFF')
        this.exercise('弹力带肩袖激活', '2 × 15', false)
        this.exercise('肩胛俯卧撑', '2 × 12', false)
      }
      .width('100%')
      .height(123 * PencilPreviewPage.SCALE)
      .padding(14 * PencilPreviewPage.SCALE)
      .justifyContent(FlexAlign.SpaceBetween)
      .backgroundColor('#08FFFFFF')
      .borderRadius(22 * PencilPreviewPage.SCALE)
      .border({ width: 1, color: '#0AFFFFFF' })

      Column() {
        Text('主动作')
          .width('100%')
          .height(18 * PencilPreviewPage.SCALE)
          .textAlign(TextAlign.Center)
          .fontFamily('Inter')
          .fontSize(14 * PencilPreviewPage.SCALE)
          .fontWeight(FontWeight.Bold)
          .fontColor('#50ECA7')
        this.exercise('杠铃卧推', '4 × 6', true)
        this.exercise('上斜哑铃卧推', '3 × 8', true)
        this.exercise('坐姿肩推', '3 × 10', true)
        this.exercise('绳索下压', '3 × 12', true)
      }
      .width('100%')
      .height(282 * PencilPreviewPage.SCALE)
      .padding(14 * PencilPreviewPage.SCALE)
      .justifyContent(FlexAlign.SpaceBetween)
      .backgroundColor('#07FFFFFF')
      .borderRadius(24 * PencilPreviewPage.SCALE)
      .border({ width: 1, color: '#14FFFFFF' })
    }
    .width('100%')
    .height(497 * PencilPreviewPage.SCALE)
    .justifyContent(FlexAlign.SpaceBetween)
  }

  @Builder
  private buildActionSection() {
    Column({ space: 10 * PencilPreviewPage.SCALE }) {
      Text('确认动作与重量后开始训练')
        .width('100%')
        .fontFamily('Inter')
        .fontSize(12 * PencilPreviewPage.SCALE)
        .fontWeight(FontWeight.Medium)
        .fontColor('#73FFFFFF')

      Button('开始训练')
        .width('100%')
        .height(48 * PencilPreviewPage.SCALE)
        .fontFamily('Inter')
        .fontSize(16 * PencilPreviewPage.SCALE)
        .fontWeight(FontWeight.Bold)
        .fontColor('#07100C')
        .linearGradient({
          angle: 180,
          colors: [['#46D88F', 0], ['#58EDAD', 1]]
        })
        .borderRadius(24 * PencilPreviewPage.SCALE)
        .shadow({
          radius: 26 * PencilPreviewPage.SCALE,
          color: '#2650ECA7',
          offsetX: 0,
          offsetY: 14 * PencilPreviewPage.SCALE
        })
        .onClick(() => {
          this.getUIContext().getRouter().pushUrl({ url: AppRoutes.ACTIVE_WORKOUT })
        })
    }
    .width('100%')
    .padding(14 * PencilPreviewPage.SCALE)
    .backgroundColor('#09FFFFFF')
    .borderRadius(30 * PencilPreviewPage.SCALE)
    .border({ width: 1, color: '#10FFFFFF' })
  }

  @Builder
  private exercise(name: string, prescription: string, primary: boolean) {
    Row() {
      Text(name)
        .fontFamily('Inter')
        .fontSize((primary ? 18 : 16) * PencilPreviewPage.SCALE)
        .fontWeight(primary ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(primary ? '#F7FBF8' : '#C7FFFFFF')
        .layoutWeight(1)
      Text(prescription)
        .fontFamily('Inter')
        .fontSize(14 * PencilPreviewPage.SCALE)
        .fontWeight(FontWeight.Medium)
        .fontColor(primary ? '#50ECA7' : '#80FFFFFF')
    }
    .width('100%')
    .height((primary ? 50 : 34) * PencilPreviewPage.SCALE)
    .padding({
      left: (primary ? 14 : 0) * PencilPreviewPage.SCALE,
      right: (primary ? 14 : 0) * PencilPreviewPage.SCALE
    })
    .backgroundColor(primary ? '#0AFFFFFF' : '#00000000')
    .borderRadius((primary ? 18 : 0) * PencilPreviewPage.SCALE)
    .border({ width: primary ? 1 : 0, color: '#18FFFFFF' })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [['#0B0F13', 0], ['#0D1117', 0.52], ['#0A0D12', 1]]
        })

      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: [215 * PencilPreviewPage.SCALE, -25 * PencilPreviewPage.SCALE],
          radius: 170 * PencilPreviewPage.SCALE,
          colors: [['#1550ECA7', 0], ['#0050ECA7', 1]]
        })

      Column({ space: 20 * PencilPreviewPage.SCALE }) {
        this.buildPreviewHero()
        this.buildExerciseSection()
        Column({ space: 10 * PencilPreviewPage.SCALE }) {
          this.buildActionSection()
        }
        .width('100%')
        .padding({ top: 8 * PencilPreviewPage.SCALE })
      }
      .width('100%')
      .height('100%')
      .padding({
        left: 18 * PencilPreviewPage.SCALE,
        right: 18 * PencilPreviewPage.SCALE,
        top: 58 * PencilPreviewPage.SCALE,
        bottom: 18 * PencilPreviewPage.SCALE
      })
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0A0D12')
  }
}
