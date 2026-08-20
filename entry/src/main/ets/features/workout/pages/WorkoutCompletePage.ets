/** WorkoutCompletePage - FitTracker workout completion page. */
import { AppRoutes } from '../../../app/AppRoutes'

const STREAK_DAYS: string[] = ['一', '二', '三', '四', '五', '六', '日']

interface ConfettiPiece {
  id: string
  x: number
  y: number
  width: number
  height: number
  rot: number
  color: string
}

const CONFETTI_PIECES: ConfettiPiece[] = [
  { id: 'cf0', x: 24, y: 18, width: 8, height: 14, rot: 18, color: '#50ECA7' },
  { id: 'cf1', x: 66, y: 96, width: 7, height: 12, rot: -24, color: '#8CEBCC' },
  { id: 'cf2', x: 108, y: 42, width: 9, height: 16, rot: 33, color: '#45C9A1' },
  { id: 'cf3', x: 152, y: 128, width: 7, height: 13, rot: -12, color: '#7EF0CB' },
  { id: 'cf4', x: 196, y: 26, width: 8, height: 15, rot: 41, color: '#F3FBF7' },
  { id: 'cf5', x: 238, y: 108, width: 9, height: 14, rot: -33, color: '#50ECA7' },
  { id: 'cf6', x: 282, y: 34, width: 7, height: 12, rot: 15, color: '#8CEBCC' },
  { id: 'cf7', x: 322, y: 92, width: 8, height: 15, rot: -21, color: '#45C9A1' },
  { id: 'cf8', x: 356, y: 40, width: 8, height: 13, rot: 28, color: '#7EF0CB' },
  { id: 'cf9', x: 42, y: 178, width: 8, height: 14, rot: -18, color: '#F3FBF7' },
  { id: 'cf10', x: 92, y: 234, width: 7, height: 12, rot: 26, color: '#50ECA7' },
  { id: 'cf11', x: 138, y: 288, width: 8, height: 14, rot: -40, color: '#8CEBCC' },
  { id: 'cf12', x: 182, y: 186, width: 9, height: 15, rot: 12, color: '#45C9A1' },
  { id: 'cf13', x: 226, y: 252, width: 7, height: 13, rot: -26, color: '#7EF0CB' },
  { id: 'cf14', x: 270, y: 300, width: 8, height: 14, rot: 36, color: '#F3FBF7' },
  { id: 'cf15', x: 312, y: 176, width: 8, height: 15, rot: -14, color: '#50ECA7' },
  { id: 'cf16', x: 352, y: 226, width: 7, height: 12, rot: 22, color: '#8CEBCC' },
  { id: 'cf17', x: 58, y: 320, width: 8, height: 14, rot: -30, color: '#45C9A1' },
  { id: 'cf18', x: 132, y: 356, width: 7, height: 12, rot: 17, color: '#7EF0CB' },
  { id: 'cf19', x: 214, y: 330, width: 8, height: 14, rot: -22, color: '#F3FBF7' }
]

@Entry
@Component
export struct WorkoutCompletePage {
  @State private confettiVisible: boolean = true
  private confettiTimer: number = -1

  aboutToAppear(): void {
    this.confettiTimer = setTimeout(() => {
      this.confettiVisible = false
      this.confettiTimer = -1
    }, 4600)
  }

  aboutToDisappear(): void {
    if (this.confettiTimer !== -1) {
      clearTimeout(this.confettiTimer)
      this.confettiTimer = -1
    }
  }

  private returnHome(): void {
    this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.APP_SHELL })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Scroll() {
          Column() {
            this.completionHero()
            Blank()
              .height(30)
            this.streakCard()
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 48, bottom: 24 })
        }
        .layoutWeight(1)
        .width('100%')

        Column() {
          Button('继续')
            .width('100%')
            .height(52)
            .padding(0)
            .fontFamily('HarmonyOS Sans')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#07100B')
            .backgroundColor('#50ECA7')
            .borderRadius(18)
            .onClick(() => {
              this.returnHome()
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 12, bottom: 20 })
        .backgroundColor('#07100F')
        .border({ width: { top: 1 }, color: '#0FFFFFFF' })
      }
      .width('100%')
      .height('100%')

      this.confettiLayer()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#07100F')
  }

  @Builder
  private confettiLayer() {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(CONFETTI_PIECES, (piece: ConfettiPiece) => {
        Row()
          .width(piece.width)
          .height(piece.height)
          .backgroundColor(piece.color)
          .borderRadius(2)
          .rotate({ angle: piece.rot })
          .position({ x: piece.x, y: piece.y })
          .hitTestBehavior(HitTestMode.None)
      }, (piece: ConfettiPiece) => piece.id)
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
    .opacity(this.confettiVisible ? 1 : 0)
    .visibility(this.confettiVisible ? Visibility.Visible : Visibility.Hidden)
    .animation({ duration: 500, curve: Curve.EaseOut })
  }

  @Builder
  private completionHero() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(102)
          .height(102)
          .borderRadius(51)
          .backgroundColor('#122D28')
          .border({ width: 1, color: '#3B50ECA7' })
        Image($rawfile('pencil-lucide-trophy.svg'))
          .width(80)
          .height(80)
          .fillColor('#7EF0CB')
      }
      .width(102)
      .height(102)

      Text('训练完成')
        .fontFamily('HarmonyOS Sans')
        .fontSize(36)
        .lineHeight(44)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
        .margin({ top: 26 })

      Text('今天的训练已保存，做得很好。')
        .fontFamily('HarmonyOS Sans')
        .fontSize(18)
        .lineHeight(24)
        .fontColor('#B8FFFFFF')
        .textAlign(TextAlign.Center)
        .margin({ top: 10 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private streakCard() {
    Column({ space: 12 }) {
      Row() {
        Text('训练连续记录')
          .fontFamily('HarmonyOS Sans')
          .fontSize(18)
          .lineHeight(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text('连续 6 天')
          .fontFamily('Inter')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#50ECA7')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)

      Row({ space: 8 }) {
        ForEach(STREAK_DAYS, (day: string, index: number) => {
          Column({ space: 6 }) {
            Row()
              .width(28)
              .height(28)
              .backgroundColor(index < 6 ? '#50ECA7' : '#14FFFFFF')
              .borderRadius(14)
            Text(day)
              .fontFamily('HarmonyOS Sans')
              .fontSize(11)
              .fontColor(index < 6 ? '#50ECA7' : '#8AFFFFFF')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
        }, (day: string) => day)
      }
      .width('100%')
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#171C23')
    .borderRadius(28)
    .border({ width: 1, color: '#14FFFFFF' })
  }
}
