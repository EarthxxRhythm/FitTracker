/** WorkoutCompletePage - FitTracker workout completion page. */
import { AppRoutes } from '../../../app/AppRoutes'

const STREAK_DAYS: string[] = ['一', '二', '三', '四', '五', '六', '日']

@Entry
@Component
export struct WorkoutCompletePage {
  private openSummary(): void {
    this.getUIContext().getRouter().pushUrl({ url: AppRoutes.WORKOUT_SUMMARY })
  }

  build() {
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
            this.openSummary()
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 20 })
      .backgroundColor('#07100F')
      .border({ width: { top: 1 }, color: '#0FFFFFFF' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#07100F')
  }

  @Builder
  private completionHero() {
    Column({ space: 10 }) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(102)
          .height(102)
          .borderRadius(51)
          .backgroundColor('#122D28')
          .border({ width: 1, color: '#3B50ECA7' })
        Image($rawfile('pencil-lucide-trophy.svg'))
          .width(64)
          .height(64)
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

      Text('今天的训练已保存，做得很好。')
        .fontFamily('HarmonyOS Sans')
        .fontSize(18)
        .lineHeight(24)
        .fontColor('#B8FFFFFF')
        .textAlign(TextAlign.Center)
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
