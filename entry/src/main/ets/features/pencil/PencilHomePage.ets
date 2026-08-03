/** PencilHomePage - FitTracker Home prototype page. Function #27 */
import { AppRoutes } from '../../app/AppRoutes'
@Component
export struct PencilHomeContent {
  private static readonly VIEWPORT_WIDTH: number = 390
  private static readonly DESIGN_WIDTH: number = 430
  private static readonly SCALE: number = PencilHomeContent.VIEWPORT_WIDTH / PencilHomeContent.DESIGN_WIDTH
  private static readonly CHINESE_FONT_FAMILY: string = 'Noto Sans SC'
  private static readonly NUMBER_FONT_FAMILY: string = 'Inter'
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
          center: [77 * PencilHomeContent.SCALE, 0],
          radius: 260 * PencilHomeContent.SCALE,
          colors: [['#1550ECA7', 0], ['#0050ECA7', 1]]
        })
      Column() {
        Scroll() {
          Column({ space: 22 * PencilHomeContent.SCALE }) {
            Column({ space: 6 * PencilHomeContent.SCALE }) {
              Text('\u0035\u6708\u0032\u0032\u65e5 \u5468\u56db')
                .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
                .fontSize(14 * PencilHomeContent.SCALE)
                .fontColor('#B3FFFFFF')
                .fontWeight(FontWeight.Medium)
                .width('100%')
              Text('\u65e9\u4e0a\u597d\uff0c\u4e13\u6ce8\u8bad\u7ec3')
                .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
                .fontSize(40 * PencilHomeContent.SCALE)
                .lineHeight(39 * PencilHomeContent.SCALE)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F7FBF8')
                .width('100%')
            }
            this.todayCard()
            this.weekPanel()
            this.boundaryPanel()
          }
          .width('100%')
          .padding({
            left: 18 * PencilHomeContent.SCALE,
            right: 18 * PencilHomeContent.SCALE,
            top: 58 * PencilHomeContent.SCALE,
            bottom: 40 * PencilHomeContent.SCALE
          })
        }
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('100%')
    }
    .width(PencilHomeContent.VIEWPORT_WIDTH)
    .height('100%')
  }
  @Builder
  private todayCard() {
    Column({ space: 16 * PencilHomeContent.SCALE }) {
      Row({ space: 18 * PencilHomeContent.SCALE }) {
        Column({ space: 8 * PencilHomeContent.SCALE }) {
          Text('\u4eca\u65e5\u8bad\u7ec3')
            .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
            .fontSize(14 * PencilHomeContent.SCALE)
            .fontWeight(FontWeight.Bold)
            .fontColor('#50ECA7')
          Row({ space: 8 * PencilHomeContent.SCALE }) {
            Text('\u4e0a\u80a2\u529b\u91cf')
              .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
              .fontSize(24 * PencilHomeContent.SCALE)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F7FBF8')
            Text('\u63a8\u8350')
              .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
              .fontSize(10 * PencilHomeContent.SCALE)
              .fontWeight(FontWeight.Bold)
              .fontColor('#50ECA7')
              .padding({
                left: 8 * PencilHomeContent.SCALE,
                right: 8 * PencilHomeContent.SCALE,
                top: 5 * PencilHomeContent.SCALE,
                bottom: 5 * PencilHomeContent.SCALE
              })
              .backgroundColor('#1A50ECA7')
              .borderRadius(999 * PencilHomeContent.SCALE)
          }
          Text('\u80f8\u90e8 \u00b7 \u80a9\u90e8 \u00b7 \u4e09\u5934\u808c')
            .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
            .fontSize(14 * PencilHomeContent.SCALE)
            .fontColor('#9EFFFFFF')
          Text('\u8bad\u7ec3\u65e5 \u00b7 \u5efa\u8bae\u5b8c\u6210')
            .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
            .fontSize(12 * PencilHomeContent.SCALE)
            .fontWeight(FontWeight.Bold)
            .fontColor('#50ECA7')
            .padding({
              left: 14 * PencilHomeContent.SCALE,
              right: 14 * PencilHomeContent.SCALE,
              top: 9 * PencilHomeContent.SCALE,
              bottom: 9 * PencilHomeContent.SCALE
            })
            .backgroundColor('#1A50ECA7')
            .borderRadius(999 * PencilHomeContent.SCALE)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Stack() {
          Progress({ value: 14, total: 100, type: ProgressType.Ring })
            .width(112 * PencilHomeContent.SCALE)
            .height(112 * PencilHomeContent.SCALE)
            .color('#50ECA7')
            .backgroundColor('#12FFFFFF')
          Column()
            .width(90 * PencilHomeContent.SCALE)
            .height(90 * PencilHomeContent.SCALE)
            .borderRadius(45 * PencilHomeContent.SCALE)
            .backgroundColor('#0D1117')
            .border({ width: PencilHomeContent.SCALE, color: '#66FFFFFF' })
          Column({ space: 2 * PencilHomeContent.SCALE }) {
            Text('14%')
              .fontFamily(PencilHomeContent.NUMBER_FONT_FAMILY)
              .fontSize(20 * PencilHomeContent.SCALE)
              .fontWeight(FontWeight.Bold)
              .fontColor('#50ECA7')
            Text('\u672c\u5468\u8fdb\u5ea6')
              .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
              .fontSize(11 * PencilHomeContent.SCALE)
              .fontColor('#8AFFFFFF')
          }
          .alignItems(HorizontalAlign.Center)
        }
        .width(112 * PencilHomeContent.SCALE)
        .height(112 * PencilHomeContent.SCALE)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Top)
      Row()
        .width('100%')
        .height(PencilHomeContent.SCALE)
        .backgroundColor('#14FFFFFF')
      Row({ space: 8 * PencilHomeContent.SCALE }) {
        this.metric('dumbbell', '\u52a8\u4f5c\u6570', '8', '\u4e2a\u52a8\u4f5c')
        this.metric('clock-3', '\u9884\u8ba1\u7528\u65f6', '60', '\u5206\u949f')
        this.metric('rotate-ccw', '\u5b8c\u6210\u5ea6', '\u4e0a\u6b21\u672a\u5b8c\u6210', '\u53ef\u4ece\u4e0a\u6b21\u8fdb\u5ea6\u7ee7\u7eed')
      }
      .width('100%')
      Button('\u5f00\u59cb\u8bad\u7ec3')
        .width('100%')
        .height(44 * PencilHomeContent.SCALE)
        .fontSize(15 * PencilHomeContent.SCALE)
        .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
        .fontWeight(FontWeight.Bold)
        .fontColor('#08110D')
        .linearGradient({ angle: 180, colors: [['#47D994', 0], ['#53E7A5', 1]] })
        .borderRadius(22 * PencilHomeContent.SCALE)
        .padding(0)
        .shadow({ radius: 28 * PencilHomeContent.SCALE, color: '#2950ECA7', offsetX: 0, offsetY: 12 * PencilHomeContent.SCALE })
        .onClick(() => {
          this.getUIContext().getRouter().pushUrl({ url: AppRoutes.ACTIVE_WORKOUT })
        })
      Button('\u67e5\u770b\u9884\u89c8')
        .width('100%')
        .height(44 * PencilHomeContent.SCALE)
        .fontSize(15 * PencilHomeContent.SCALE)
        .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
        .fontWeight(FontWeight.Medium)
        .fontColor('#F7FBF8')
        .backgroundColor('#08FFFFFF')
        .borderRadius(22 * PencilHomeContent.SCALE)
        .padding(0)
        .border({ width: PencilHomeContent.SCALE, color: '#10FFFFFF' })
        .onClick(() => {
          this.getUIContext().getRouter().pushUrl({ url: AppRoutes.WORKOUT_PREVIEW })
        })
    }
    .width('100%')
    .height(466 * PencilHomeContent.SCALE)
    .padding(20 * PencilHomeContent.SCALE)
    .justifyContent(FlexAlign.SpaceBetween)
    .linearGradient({ angle: 180, colors: [['#0AFFFFFF', 0], ['#05FFFFFF', 1]] })
    .borderRadius(28 * PencilHomeContent.SCALE)
    .border({ width: PencilHomeContent.SCALE, color: '#10FFFFFF' })
    .shadow({ radius: 48 * PencilHomeContent.SCALE, color: '#38000000', offsetX: 0, offsetY: 24 * PencilHomeContent.SCALE })
  }

  @Builder
  private weekPanel() {
    Column({ space: 16 * PencilHomeContent.SCALE }) {
      Row() {
        Column({ space: 4 * PencilHomeContent.SCALE }) {
          Text('\u672c\u5468\u8282\u594f')
            .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
            .fontSize(16 * PencilHomeContent.SCALE)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F7FBF8')
          Text('\u5468\u4e00\u2014\u5468\u65e5')
            .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
            .fontSize(11 * PencilHomeContent.SCALE)
            .fontColor('#66FFFFFF')
        }
        Text('\u0033 / \u0035 \u6b21')
          .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
          .fontSize(11 * PencilHomeContent.SCALE)
          .fontWeight(FontWeight.Bold)
          .fontColor('#50ECA7')
          .padding({
            left: 14 * PencilHomeContent.SCALE,
            right: 14 * PencilHomeContent.SCALE,
            top: 9 * PencilHomeContent.SCALE,
            bottom: 9 * PencilHomeContent.SCALE
          })
          .backgroundColor('#04FFFFFF')
          .borderRadius(999 * PencilHomeContent.SCALE)
          .border({ width: PencilHomeContent.SCALE, color: '#10FFFFFF' })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      Row({ space: 8 * PencilHomeContent.SCALE }) {
        this.weekDay('\u4e00', '20', true)
        this.weekDay('\u4e8c', '21', true)
        this.weekDay('\u4e09', '22', false)
        this.weekDay('\u56db', '23', false)
        this.weekDay('\u4e94', '24', false)
        this.weekDay('\u516d', '25', false)
        this.weekDay('\u65e5', '26', false)
      }
      .width('100%')
      Row() {
        Text('\u5df2\u5b8c\u6210 3 / 5 \u6b21')
          .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
          .fontSize(12 * PencilHomeContent.SCALE)
          .fontColor('#8AFFFFFF')
        Text('60%')
          .fontFamily(PencilHomeContent.NUMBER_FONT_FAMILY)
          .fontSize(12 * PencilHomeContent.SCALE)
          .fontWeight(FontWeight.Bold)
          .fontColor('#50ECA7')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      Stack() {
        Column()
          .width('100%')
          .height(6 * PencilHomeContent.SCALE)
          .backgroundColor('#14FFFFFF')
          .borderRadius(999 * PencilHomeContent.SCALE)
        Column()
          .width('60%')
          .height(6 * PencilHomeContent.SCALE)
          .backgroundColor('#50ECA7')
          .borderRadius(999 * PencilHomeContent.SCALE)
          .alignSelf(ItemAlign.Start)
      }
      .width('100%')
      .height(6 * PencilHomeContent.SCALE)
    }
    .width('100%')
    .height(248 * PencilHomeContent.SCALE)
    .padding(18 * PencilHomeContent.SCALE)
    .linearGradient({ angle: 180, colors: [['#08FFFFFF', 0], ['#04FFFFFF', 1]] })
    .borderRadius(30 * PencilHomeContent.SCALE)
    .border({ width: PencilHomeContent.SCALE, color: '#10FFFFFF' })
    .shadow({ radius: 36 * PencilHomeContent.SCALE, color: '#24000000', offsetX: 0, offsetY: 18 * PencilHomeContent.SCALE })
  }

  @Builder
  private boundaryPanel() {
    Column({ space: 14 * PencilHomeContent.SCALE }) {
      Row() {
        Text('\u8ba1\u5212\u8fb9\u754c')
          .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
          .fontSize(16 * PencilHomeContent.SCALE)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text('\u5f53\u524d\u751f\u6548')
          .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
          .fontSize(11 * PencilHomeContent.SCALE)
          .fontColor('#50ECA7')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      this.boundary('\u76ee\u6807', '\u8bad\u7ec3\u4f18\u5148\u7ea7', '#F7FBF8')
      this.boundary('\u5668\u68b0', '\u53ef\u7528\u73af\u5883', '#F7FBF8')
      this.boundary('\u9650\u5236', '\u80a9\u90e8\u8f7b\u5fae\u4e0d\u9002', '#FFD7C5')
    }
    .width('100%')
    .height(308 * PencilHomeContent.SCALE)
    .padding(18 * PencilHomeContent.SCALE)
    .linearGradient({ angle: 180, colors: [['#171C23', 0], ['#10151B', 1]] })
    .borderRadius(30 * PencilHomeContent.SCALE)
    .border({ width: PencilHomeContent.SCALE, color: '#14FFFFFF' })
    .shadow({ radius: 36 * PencilHomeContent.SCALE, color: '#24000000', offsetX: 0, offsetY: 18 * PencilHomeContent.SCALE })
  }

  @Builder
  private metric(iconName: string, label: string, value: string, note: string) {
    Column({ space: 8 * PencilHomeContent.SCALE }) {
      if (iconName === 'dumbbell') {
        Image($rawfile('pencil-home-metric-dumbbell.svg'))
          .width(36 * PencilHomeContent.SCALE)
          .height(36 * PencilHomeContent.SCALE)
      } else if (iconName === 'clock-3') {
        Image($rawfile('pencil-home-metric-clock-3.svg'))
          .width(36 * PencilHomeContent.SCALE)
          .height(36 * PencilHomeContent.SCALE)
      } else {
        Image($rawfile('pencil-home-metric-rotate-ccw.svg'))
          .width(36 * PencilHomeContent.SCALE)
          .height(36 * PencilHomeContent.SCALE)
      }
      Text(label)
        .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
        .fontSize(12 * PencilHomeContent.SCALE)
        .fontColor('#A3FFFFFF')
      Text(label === '\u5b8c\u6210\u5ea6' ? '\u4e0a\u6b21...' : value)
        .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
        .fontSize(30 * PencilHomeContent.SCALE)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(note)
        .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
        .fontSize(11 * PencilHomeContent.SCALE)
        .fontColor('#8AFFFFFF')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private weekDay(day: string, date: string, active: boolean) {
    Column({ space: 6 * PencilHomeContent.SCALE }) {
      Text(day)
        .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
        .fontSize(11 * PencilHomeContent.SCALE)
        .fontColor('#8AFFFFFF')
      Text(active ? '\u2713' : '\u00b7')
        .fontFamily(PencilHomeContent.NUMBER_FONT_FAMILY)
        .fontSize(14 * PencilHomeContent.SCALE)
        .fontWeight(FontWeight.Bold)
        .fontColor(active ? '#07100B' : '#66FFFFFF')
        .width(32 * PencilHomeContent.SCALE)
        .height(32 * PencilHomeContent.SCALE)
        .textAlign(TextAlign.Center)
        .backgroundColor(active ? '#50ECA7' : '#0FFFFFFF')
        .borderRadius(16 * PencilHomeContent.SCALE)
        .border({ width: PencilHomeContent.SCALE, color: active ? '#50ECA7' : '#14FFFFFF' })
      Text(date)
        .fontFamily(PencilHomeContent.NUMBER_FONT_FAMILY)
        .fontSize(10 * PencilHomeContent.SCALE)
        .fontColor(active ? '#50ECA7' : '#66FFFFFF')
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private boundary(label: string, value: string, valueColor: string) {
    Row() {
      Text(label)
        .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
        .fontSize(13 * PencilHomeContent.SCALE)
        .fontWeight(FontWeight.Medium)
        .fontColor('#DEFFFFFF')
        .padding({
          left: 10 * PencilHomeContent.SCALE,
          right: 10 * PencilHomeContent.SCALE,
          top: 7 * PencilHomeContent.SCALE,
          bottom: 7 * PencilHomeContent.SCALE
        })
        .backgroundColor('#0AFFFFFF')
        .borderRadius(999 * PencilHomeContent.SCALE)
      Text(value)
        .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
        .fontSize(14 * PencilHomeContent.SCALE)
        .fontWeight(FontWeight.Bold)
        .fontColor(valueColor)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(58 * PencilHomeContent.SCALE)
    .padding(14 * PencilHomeContent.SCALE)
    .backgroundColor('#06FFFFFF')
    .borderRadius(22 * PencilHomeContent.SCALE)
    .border({ width: PencilHomeContent.SCALE, color: '#0DFFFFFF' })
    .justifyContent(FlexAlign.SpaceBetween)
  }
}

@Entry
@Component
struct PencilHomePage {
  aboutToAppear(): void {
    this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.APP_SHELL })
  }

  build() {
    Column() {
      PencilHomeContent()
    }
    .width(390)
    .height('100%')
  }
}
