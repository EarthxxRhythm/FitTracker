/** PencilReviewPage - FitTracker review prototype page. Function #27 */
@Component
export struct PencilReviewContent {
  private static readonly VIEWPORT_WIDTH: number = 390
  private static readonly DESIGN_WIDTH: number = 430
  static readonly SCALE: number = PencilReviewContent.VIEWPORT_WIDTH / PencilReviewContent.DESIGN_WIDTH
  @BuilderParam bottomBar: () => void = this.emptyBottomBar


  build() {
    Stack() {
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
          center: [215 * PencilReviewContent.SCALE, 0],
          radius: 220 * PencilReviewContent.SCALE,
          colors: [['#1550ECA7', 0], ['#0050ECA7', 1]]
        })

      Column() {
        Scroll() {
          Column({ space: 18 * PencilReviewContent.SCALE }) {
            this.buildHeader()
            this.buildOverview()
            this.buildStats()
            this.buildWeeklyActivity()
            this.buildRecentWorkouts()
          }
          .width('100%')
          .padding({
            left: 18 * PencilReviewContent.SCALE,
            right: 18 * PencilReviewContent.SCALE,
            top: 58 * PencilReviewContent.SCALE,
            bottom: 40 * PencilReviewContent.SCALE
          })
        }
        .width('100%')
        .layoutWeight(1)

        this.bottomBar()
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0B0F13')
  }

  @Builder
  private emptyBottomBar() {
  }

  @Builder
  private buildHeader() {
    Row() {
      Column({ space: 4 * PencilReviewContent.SCALE }) {
        Text('\u6570\u636e\u56de\u987e')
          .fontFamily('Inter')
          .fontSize(12 * PencilReviewContent.SCALE)
          .fontWeight(600)
          .fontColor('#50ECA7')
        Text('\u8bad\u7ec3\u56de\u987e')
          .fontFamily('Geist')
          .fontSize(28 * PencilReviewContent.SCALE)
          .fontWeight(600)
          .fontColor('#F7FBF8')
      }
      Image($rawfile('pencil-calendar.svg'))
        .width(22 * PencilReviewContent.SCALE)
        .height(22 * PencilReviewContent.SCALE)
        .fillColor('#B2FFFFFF')
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildOverview() {
    Column({ space: 14 * PencilReviewContent.SCALE }) {
      Row() {
        Text('\u672c\u5468 \u00b7 6\u6708 7\u201313\u65e5')
          .fontFamily('Inter')
          .fontSize(14 * PencilReviewContent.SCALE)
          .fontWeight(600)
          .fontColor('#B3FFFFFF')
        Text('\u2191 +18%')
          .fontFamily('Inter')
          .fontSize(12 * PencilReviewContent.SCALE)
          .fontWeight(600)
          .fontColor('#50ECA7')
          .padding({
            left: 10 * PencilReviewContent.SCALE,
            right: 10 * PencilReviewContent.SCALE,
            top: 6 * PencilReviewContent.SCALE,
            bottom: 6 * PencilReviewContent.SCALE
          })
          .backgroundColor('#1A50ECA7')
          .borderRadius(999 * PencilReviewContent.SCALE)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
      Text('\u72b6\u6001\u4e0d\u9519\uff0c\u7ee7\u7eed\u4fdd\u6301\u3002')
        .fontFamily('Geist')
        .fontSize(22 * PencilReviewContent.SCALE)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
      Text('\u4f60\u6bd4\u4e0a\u5468\u591a\u5b8c\u6210\u4e86 1 \u6b21\u8bad\u7ec3\uff0c\u5e73\u5747\u8bad\u7ec3\u65f6\u957f\u4e5f\u63d0\u5347\u4e86 12 \u5206\u949f\u3002')
        .fontFamily('Inter')
        .fontSize(13 * PencilReviewContent.SCALE)
        .fontColor('#7AFFFFFF')
        .lineHeight(13 * 1.35 * PencilReviewContent.SCALE)
        .width('100%')
    }
    .width('100%')
    .height(160 * PencilReviewContent.SCALE)
    .padding(18 * PencilReviewContent.SCALE)
    .backgroundColor('#08FFFFFF')
    .borderRadius(28 * PencilReviewContent.SCALE)
    .border({ width: 1 * PencilReviewContent.SCALE, color: '#10FFFFFF' })
  }

  @Builder
  private buildStats() {
    Row({ space: 10 * PencilReviewContent.SCALE }) {
      this.buildStat('\u8bad\u7ec3', '4', '\u6b21')
      this.buildStat('\u65f6\u957f', '186', '\u5206\u949f')
      this.buildStat('\u5b8c\u6210\u7387', '92', '%')
    }
    .width('100%')
    .height(81 * PencilReviewContent.SCALE)
  }

  @Builder
  private buildStat(label: string, value: string, unit: string) {
    Column({ space: 5 * PencilReviewContent.SCALE }) {
      Text(label)
        .fontFamily('Inter')
        .fontSize(12 * PencilReviewContent.SCALE)
        .fontColor('#7AFFFFFF')
        .width('100%')
      Row({ space: 4 * PencilReviewContent.SCALE }) {
        Text(value)
          .fontFamily('Geist Mono')
          .fontSize(24 * PencilReviewContent.SCALE)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text(unit)
          .fontFamily('Inter')
          .fontSize(12 * PencilReviewContent.SCALE)
          .fontColor('#50ECA7')
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
    }
    .layoutWeight(1)
    .height(81 * PencilReviewContent.SCALE)
    .padding(14 * PencilReviewContent.SCALE)
    .backgroundColor('#171D24')
    .borderRadius(20 * PencilReviewContent.SCALE)
    .border({ width: 1 * PencilReviewContent.SCALE, color: '#0AFFFFFF' })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildWeeklyActivity() {
    Column({ space: 14 * PencilReviewContent.SCALE }) {
      Row() {
        Text('\u8bad\u7ec3\u8282\u594f')
          .fontFamily('Geist')
          .fontSize(16 * PencilReviewContent.SCALE)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text('\u8fc7\u53bb 7 \u5929')
          .fontFamily('Inter')
          .fontSize(12 * PencilReviewContent.SCALE)
          .fontColor('#7AFFFFFF')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      Row({ space: 10 * PencilReviewContent.SCALE }) {
        this.buildBar('\u4e00', 58, false)
        this.buildBar('\u4e8c', 92, true)
        this.buildBar('\u4e09', 74, true)
        this.buildBar('\u56db', 42, false)
        this.buildBar('\u4e94', 116, true)
        this.buildBar('\u516d', 82, true)
        this.buildBar('\u65e5', 46, false)
      }
      .width('100%')
      .height(150 * PencilReviewContent.SCALE)
      .alignItems(VerticalAlign.Bottom)
    }
    .width('100%')
    .height(223 * PencilReviewContent.SCALE)
    .padding(18 * PencilReviewContent.SCALE)
    .backgroundColor('#07FFFFFF')
    .borderRadius(28 * PencilReviewContent.SCALE)
    .border({ width: 1 * PencilReviewContent.SCALE, color: '#14FFFFFF' })
  }

  @Builder
  private buildBar(label: string, barHeight: number, active: boolean) {
    Column({ space: 8 * PencilReviewContent.SCALE }) {
      Column()
        .width('100%')
        .height(barHeight * PencilReviewContent.SCALE)
        .backgroundColor(active ? '#50ECA7' : '#3350ECA7')
        .borderRadius(10 * PencilReviewContent.SCALE)
      Text(label)
        .fontFamily('Inter')
        .fontSize(11 * PencilReviewContent.SCALE)
        .fontColor(active ? '#50ECA7' : '#66FFFFFF')
    }
    .layoutWeight(1)
    .height(150 * PencilReviewContent.SCALE)
    .justifyContent(FlexAlign.End)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildRecentWorkouts() {
    Column({ space: 12 * PencilReviewContent.SCALE }) {
      Row() {
        Text('\u6700\u8fd1\u8bad\u7ec3')
          .fontFamily('Geist')
          .fontSize(14 * PencilReviewContent.SCALE)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F7FBF8')
        Text('\u67e5\u770b\u5168\u90e8')
          .fontFamily('Inter')
          .fontSize(11 * PencilReviewContent.SCALE)
          .fontWeight(FontWeight.Bold)
          .fontColor('#50ECA7')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      this.buildRecentWorkout('\u5168\u8eab\u529b\u91cf', '\u6628\u5929 \u00b7 48 \u5206\u949f', '320 \u5343\u5361')
      this.buildRecentWorkout('\u6838\u5fc3\u4e0e\u7075\u6d3b\u6027', '\u5468\u56db \u00b7 36 \u5206\u949f', '210 \u5343\u5361')
    }
    .width('100%')
    .height(204 * PencilReviewContent.SCALE)
    .padding(18 * PencilReviewContent.SCALE)
    .backgroundColor('#171D24')
    .borderRadius(28 * PencilReviewContent.SCALE)
    .border({ width: 1 * PencilReviewContent.SCALE, color: '#10FFFFFF' })
  }

  @Builder
  private buildRecentWorkout(title: string, subtitle: string, calories: string) {
    Row({ space: 10 * PencilReviewContent.SCALE }) {
      Stack() {
        Column()
          .width(38 * PencilReviewContent.SCALE)
          .height(38 * PencilReviewContent.SCALE)
          .borderRadius(14 * PencilReviewContent.SCALE)
          .backgroundColor('#1A50ECA7')
        Image($rawfile('pencil-lucide-dumbbell.svg'))
          .width(18 * PencilReviewContent.SCALE)
          .height(18 * PencilReviewContent.SCALE)
      }
      .width(38 * PencilReviewContent.SCALE)
      .height(38 * PencilReviewContent.SCALE)
      Column({ space: 3 * PencilReviewContent.SCALE }) {
        Text(title)
          .fontFamily('Inter')
          .fontSize(14 * PencilReviewContent.SCALE)
          .fontWeight(600)
          .fontColor('#F7FBF8')
        Text(subtitle)
          .fontFamily('Inter')
          .fontSize(12 * PencilReviewContent.SCALE)
          .fontColor('#66FFFFFF')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text(calories)
        .fontFamily('Geist Mono')
        .fontSize(12 * PencilReviewContent.SCALE)
        .fontColor('#8FFFFFFF')
    }
    .width('100%')
    .height(60 * PencilReviewContent.SCALE)
    .padding({ top: 10 * PencilReviewContent.SCALE, bottom: 10 * PencilReviewContent.SCALE })
    .alignItems(VerticalAlign.Center)
  }
}

@Entry
@Component
struct PencilReviewPage {
  build() {
    Column() {
      PencilReviewContent()
    }
  }
}







