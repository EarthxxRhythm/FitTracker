/** WorkoutCompletePage - FitTracker workout completion page. Function #27 */
import { AppRoutes } from '../../../app/AppRoutes'

@Entry
@Component
export struct WorkoutCompletePage {
  private static readonly VIEWPORT_WIDTH: number = 390
  private static readonly DESIGN_WIDTH: number = 430
  private static readonly SCALE: number = WorkoutCompletePage.VIEWPORT_WIDTH / WorkoutCompletePage.DESIGN_WIDTH

  private openSummary(): void {
    this.getUIContext().getRouter().pushUrl({ url: AppRoutes.WORKOUT_SUMMARY })
  }

  private returnHome(): void {
    this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.APP_SHELL })
  }

  @Builder
  private metric(label: string, value: string, note: string) {
    Column({ space: 9 * WorkoutCompletePage.SCALE }) {
      Text(label)
        .fontFamily('HarmonyOS Sans')
        .fontSize(15 * WorkoutCompletePage.SCALE)
        .lineHeight(20 * WorkoutCompletePage.SCALE)
        .fontWeight(FontWeight.Medium)
        .fontColor('#A6FFFFFF')
      Text(value)
        .fontFamily('HarmonyOS Sans')
        .fontSize(30 * WorkoutCompletePage.SCALE)
        .lineHeight(34 * WorkoutCompletePage.SCALE)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
        .maxLines(2)
      Text(note)
        .fontFamily('HarmonyOS Sans')
        .fontSize(15 * WorkoutCompletePage.SCALE)
        .lineHeight(21 * WorkoutCompletePage.SCALE)
        .fontWeight(FontWeight.Normal)
        .fontColor('#7AFFFFFF')
        .maxLines(2)
    }
    .layoutWeight(1)
    .height(154 * WorkoutCompletePage.SCALE)
    .padding(10 * WorkoutCompletePage.SCALE)
    .backgroundColor('#0B1513')
    .borderRadius(28 * WorkoutCompletePage.SCALE)
    .border({ width: 1 * WorkoutCompletePage.SCALE, color: '#173D3834' })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private highlight(icon: Resource, title: string, detail: string) {
    Row({ space: 18 * WorkoutCompletePage.SCALE }) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(52 * WorkoutCompletePage.SCALE)
          .height(52 * WorkoutCompletePage.SCALE)
          .borderRadius(17 * WorkoutCompletePage.SCALE)
          .backgroundColor('#1A50ECA7')
        Image(icon)
          .width(28 * WorkoutCompletePage.SCALE)
          .height(28 * WorkoutCompletePage.SCALE)
          .objectFit(ImageFit.Contain)
      }
      .width(52 * WorkoutCompletePage.SCALE)
      .height(52 * WorkoutCompletePage.SCALE)
      Column({ space: 5 * WorkoutCompletePage.SCALE }) {
        Text(title)
          .fontFamily('HarmonyOS Sans')
          .fontSize(26 * WorkoutCompletePage.SCALE)
          .lineHeight(32 * WorkoutCompletePage.SCALE)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
          .maxLines(1)
        Text(detail)
          .fontFamily('HarmonyOS Sans')
          .fontSize(18 * WorkoutCompletePage.SCALE)
          .lineHeight(25 * WorkoutCompletePage.SCALE)
          .fontWeight(FontWeight.Normal)
          .fontColor('#A6FFFFFF')
          .maxLines(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(52 * WorkoutCompletePage.SCALE)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private completionHeader() {
    Column({ space: 26 * WorkoutCompletePage.SCALE }) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(102 * WorkoutCompletePage.SCALE)
          .height(102 * WorkoutCompletePage.SCALE)
          .borderRadius(51 * WorkoutCompletePage.SCALE)
          .backgroundColor('#12332A')
          .border({ width: 1 * WorkoutCompletePage.SCALE, color: '#3B50ECA7' })
        Text('\u2713')
          .fontFamily('HarmonyOS Sans')
          .fontSize(62 * WorkoutCompletePage.SCALE)
          .lineHeight(72 * WorkoutCompletePage.SCALE)
          .fontWeight(FontWeight.Medium)
          .fontColor('#7EF0CB')
      }
      .width(102 * WorkoutCompletePage.SCALE)
      .height(102 * WorkoutCompletePage.SCALE)
      Text('\u8bad\u7ec3\u5b8c\u6210')
        .fontFamily('HarmonyOS Sans')
        .fontSize(44 * WorkoutCompletePage.SCALE)
        .lineHeight(54 * WorkoutCompletePage.SCALE)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
      Text('\u4eca\u5929\u7684\u8bad\u7ec3\u5df2\u4fdd\u5b58\uff0c\u505a\u5f97\u5f88\u597d\u3002')
        .fontFamily('HarmonyOS Sans')
        .fontSize(22 * WorkoutCompletePage.SCALE)
        .lineHeight(28 * WorkoutCompletePage.SCALE)
        .fontWeight(FontWeight.Normal)
        .fontColor('#B8FFFFFF')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ top: 64 * WorkoutCompletePage.SCALE, bottom: 33 * WorkoutCompletePage.SCALE })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private summaryCard() {
    Column({ space: 16 * WorkoutCompletePage.SCALE }) {
      Row() {
        Column({ space: 2 * WorkoutCompletePage.SCALE }) {
          Text('\u4e0a\u80a2\u529b\u91cf')
            .fontFamily('HarmonyOS Sans')
            .fontSize(28 * WorkoutCompletePage.SCALE)
            .lineHeight(32 * WorkoutCompletePage.SCALE)
            .fontWeight(FontWeight.Medium)
            .fontColor('#F7FBF8')
          Text('\u4eca\u65e5\u8bad\u7ec3\u8ba1\u5212')
            .fontFamily('HarmonyOS Sans')
            .fontSize(17 * WorkoutCompletePage.SCALE)
            .lineHeight(22 * WorkoutCompletePage.SCALE)
            .fontWeight(FontWeight.Normal)
            .fontColor('#A6FFFFFF')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        Text('\u5df2\u5b8c\u6210')
          .fontFamily('HarmonyOS Sans')
          .fontSize(17 * WorkoutCompletePage.SCALE)
          .lineHeight(22 * WorkoutCompletePage.SCALE)
          .fontWeight(FontWeight.Medium)
          .fontColor('#50ECA7')
          .padding({ left: 13 * WorkoutCompletePage.SCALE, right: 13 * WorkoutCompletePage.SCALE, top: 8 * WorkoutCompletePage.SCALE, bottom: 8 * WorkoutCompletePage.SCALE })
          .backgroundColor('#1A50ECA7')
          .borderRadius(999 * WorkoutCompletePage.SCALE)
      }
      .width('100%')
      .height(52 * WorkoutCompletePage.SCALE)
      .alignItems(VerticalAlign.Center)
      Row({ space: 12 * WorkoutCompletePage.SCALE }) {
        this.metric('\u8bad\u7ec3\u65f6\u957f', '42\u5206\u949f', '\u672c\u6b21\u8bad\u7ec3')
        this.metric('\u5b8c\u6210\u52a8\u4f5c', '8\u4e2a', '\u5168\u90e8\u5b8c\u6210')
        this.metric('\u8bad\u7ec3\u91cf', '2.48T', '\u6b63\u5f0f\u7ec4\u7d2f\u8ba1')
      }
      .width('100%')
      .height(154 * WorkoutCompletePage.SCALE)
    }
    .width('100%')
    .height(278 * WorkoutCompletePage.SCALE)
    .padding(28 * WorkoutCompletePage.SCALE)
    .backgroundColor('#101E1A')
    .borderRadius(34 * WorkoutCompletePage.SCALE)
    .border({ width: 1 * WorkoutCompletePage.SCALE, color: '#2CFFFFFF' })
  }

  @Builder
  private highlightsCard() {
    Column({ space: 20 * WorkoutCompletePage.SCALE }) {
      Row() {
        Text('\u672c\u6b21\u4eae\u70b9')
          .fontFamily('HarmonyOS Sans')
          .fontSize(28 * WorkoutCompletePage.SCALE)
          .lineHeight(34 * WorkoutCompletePage.SCALE)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
          .layoutWeight(1)
        Text('\u8bad\u7ec3\u8bb0\u5f55')
          .fontFamily('HarmonyOS Sans')
          .fontSize(17 * WorkoutCompletePage.SCALE)
          .lineHeight(22 * WorkoutCompletePage.SCALE)
          .fontWeight(FontWeight.Normal)
          .fontColor('#7AFFFFFF')
      }
      .width('100%')
      .height(34 * WorkoutCompletePage.SCALE)
      .alignItems(VerticalAlign.Center)
      this.highlight($rawfile('pencil-lucide-trophy.svg'), '\u65b0\u7684\u4e2a\u4eba\u7eaa\u5f55', '\u6760\u94c3\u5367\u63a8 32 kg \u00d7 9')
      this.highlight($rawfile('pencil-lucide-activity.svg'), '\u5b8c\u6210\u5ea6\u7a33\u5b9a', '8 / 8 \u4e2a\u52a8\u4f5c\u5168\u90e8\u5b8c\u6210')
      this.highlight($rawfile('pencil-lucide-sparkles.svg'), '\u8282\u594f\u4fdd\u6301\u826f\u597d', '\u7ec4\u95f4\u4f11\u606f\u63a7\u5236\u5728\u76ee\u6807\u8303\u56f4\u5185')
    }
    .width('100%')
    .padding(28 * WorkoutCompletePage.SCALE)
    .backgroundColor('#101E1A')
    .borderRadius(34 * WorkoutCompletePage.SCALE)
    .border({ width: 1 * WorkoutCompletePage.SCALE, color: '#2CFFFFFF' })
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 22 * WorkoutCompletePage.SCALE }) {
          this.completionHeader()
          this.summaryCard()
          this.highlightsCard()
          Button('\u67e5\u770b\u8bad\u7ec3\u603b\u7ed3')
            .width('100%')
            .height(52 * WorkoutCompletePage.SCALE)
            .padding(0)
            .fontFamily('HarmonyOS Sans')
            .fontSize(16 * WorkoutCompletePage.SCALE)
            .fontWeight(FontWeight.Medium)
            .fontColor('#07100B')
            .backgroundColor('#50ECA7')
            .borderRadius(18 * WorkoutCompletePage.SCALE)
            .onClick(() => { this.openSummary() })
          Button('\u8fd4\u56de\u9996\u9875')
            .width('100%')
            .height(52 * WorkoutCompletePage.SCALE)
            .padding(0)
            .fontFamily('HarmonyOS Sans')
            .fontSize(16 * WorkoutCompletePage.SCALE)
            .fontWeight(FontWeight.Medium)
            .fontColor('#F7FBF8')
            .backgroundColor('#08FFFFFF')
            .border({ width: 1 * WorkoutCompletePage.SCALE, color: '#1AFFFFFF' })
            .borderRadius(18 * WorkoutCompletePage.SCALE)
            .onClick(() => { this.returnHome() })
        }
        .width('100%')
        .padding({ left: 22 * WorkoutCompletePage.SCALE, right: 22 * WorkoutCompletePage.SCALE, bottom: 48 * WorkoutCompletePage.SCALE })
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width(390)
    .height('100%')
    .backgroundColor('#07100D')
  }
}
