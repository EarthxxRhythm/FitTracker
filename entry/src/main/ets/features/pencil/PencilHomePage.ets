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
          colors: [['#0B0F13', 0], ['#0A0D12', 1]]
        })
      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: [70, 0],
          radius: 254,
          colors: [['#1F50ECA7', 0], ['#0050ECA7', 1]]
        })
      Column() {
        Scroll() {
          Column() {
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
            Row()
              .height(19)
            this.todayCard()
            Row()
              .height(16)
            this.weekPanel()
            this.boundaryPanel()
          }
          .width('100%')
          .padding({
            left: 16,
            right: 16,
            top: 53,
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
              .width(42)
              .height(18)
              .padding(0)
              .textAlign(TextAlign.Center)
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
            .width(160)
            .height(18)
            .padding(0)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Stack() {
          Column()
            .width(96)
            .height(96)
            .borderRadius(48)
            .border({ width: 5, color: '#50ECA7' })
          Column()
            .width(78)
            .height(78)
            .borderRadius(39)
            .backgroundColor('#0D1117')
            .border({ width: 1, color: '#66FFFFFF' })
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
        .width(96)
        .height(96)
        .translate({ y: 6 })
      }
      .width('100%')
      .height(103)
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Top)
      Row()
        .height(16)
      Row()
        .width('100%')
        .height(1)
        .backgroundColor('#14FFFFFF')
      Row()
        .height(18)
      Row({ space: 5 }) {
        this.metric('dumbbell', '\u52a8\u4f5c\u6570', '8', '\u4e2a\u52a8\u4f5c')
        this.metric('clock-3', '\u9884\u8ba1\u7528\u65f6', '60', '\u5206\u949f')
        this.metric('rotate-ccw', '\u5b8c\u6210\u5ea6', '\u4e0a\u6b21\u672a\u5b8c\u6210', '\u53ef\u4ece\u4e0a\u6b21\u8fdb\u5ea6\u7ee7\u7eed')
      }
      .width('100%')
      .height(96)
      Button('\u5f00\u59cb\u8bad\u7ec3')
        .width('100%')
        .height(40)
        .fontSize(15 * PencilHomeContent.SCALE)
        .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
        .fontWeight(FontWeight.Bold)
        .fontColor('#08110D')
        .linearGradient({ angle: 90, colors: [['#47D994', 0], ['#53E7A5', 1]] })
        .borderRadius(22 * PencilHomeContent.SCALE)
        .padding(0)
        .onClick(() => {
          this.getUIContext().getRouter().pushUrl({ url: AppRoutes.ACTIVE_WORKOUT })
        })
      Row()
        .height(8)
      Button('\u67e5\u770b\u9884\u89c8')
        .width('100%')
        .height(40)
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
    .height(422)
    .padding(18)
    .linearGradient({ angle: 180, colors: [['#0AFFFFFF', 0], ['#05FFFFFF', 1]] })
    .borderRadius(28 * PencilHomeContent.SCALE)
    .border({ width: PencilHomeContent.SCALE, color: '#10FFFFFF' })
    .shadow({ radius: 48 * PencilHomeContent.SCALE, color: '#38000000', offsetX: 0, offsetY: 24 * PencilHomeContent.SCALE })
  }

  @Builder
  private weekPanel() {
    Column() {
      Row() {
        Column({ space: 2 }) {
          Text('\u672c\u5468\u8282\u594f')
            .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
            .fontSize(14.5)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F7FBF8')
            .height(22)
          Text('\u5468\u4e00\u2014\u5468\u65e5')
            .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
            .fontSize(10)
            .fontColor('#66FFFFFF')
            .height(16)
        }
        Text('\u0033 / \u0035 \u6b21')
          .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor('#50ECA7')
          .width(63)
          .height(20)
          .padding(0)
          .textAlign(TextAlign.Center)
          .translate({ y: 2 })
      }
      .width('100%')
      .height(40)
      .justifyContent(FlexAlign.SpaceBetween)
      Row()
        .height(18)
      Row({ space: 5 }) {
        this.weekDay('\u4e00', '20', true)
        this.weekDay('\u4e8c', '21', true)
        this.weekDay('\u4e09', '22', false)
        this.weekDay('\u56db', '23', false)
        this.weekDay('\u4e94', '24', false)
        this.weekDay('\u516d', '25', false)
        this.weekDay('\u65e5', '26', false)
      }
      .width(319)
      .height(62)
      Row()
        .height(15)
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
      .width(321)
      .height(16)
      .justifyContent(FlexAlign.SpaceBetween)
      Row()
        .height(12)
      Stack() {
        Column()
          .width(321)
          .height(6)
          .backgroundColor('#14FFFFFF')
          .borderRadius(999)
        Column()
          .width(193)
          .height(6)
          .backgroundColor('#50ECA7')
          .borderRadius(999)
          .alignSelf(ItemAlign.Start)
      }
      .width(321)
      .height(6)
    }
    .width('100%')
    .height(225)
    .padding(16)
    .backgroundColor('#08FFFFFF')
    .borderRadius(27.2)
    .border({ width: 1, color: '#10FFFFFF' })
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
    Column({ space: 4 }) {
      if (iconName === 'dumbbell') {
        Image($rawfile('pencil-home-metric-dumbbell.svg'))
          .width(22)
          .height(22)
          .fillColor('#50ECA7')
      } else if (iconName === 'clock-3') {
        Image($rawfile('pencil-home-metric-clock-3.svg'))
          .width(22)
          .height(22)
          .fillColor('#50ECA7')
      } else {
        Image($rawfile('pencil-home-metric-rotate-ccw.svg'))
          .width(22)
          .height(22)
          .fillColor('#50ECA7')
      }
      Text(label)
        .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
        .fontSize(9.8)
        .fontColor('#A3FFFFFF')
        .width('100%')
        .height(16)
        .textAlign(TextAlign.Center)
      Text(label === '\u5b8c\u6210\u5ea6' ? '\u4e0a\u6b21...' : value)
        .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
        .fontSize(label === '\u5b8c\u6210\u5ea6' ? 13 : 27.2)
        .lineHeight(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
        .width('100%')
        .height(28)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(note)
        .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
        .fontSize(8.8)
        .fontColor('#8AFFFFFF')
        .width('100%')
        .height(16)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .height(96)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private weekDay(day: string, date: string, active: boolean) {
    Column({ space: 3 }) {
      Text(day)
        .fontFamily(PencilHomeContent.CHINESE_FONT_FAMILY)
        .fontSize(9.5)
        .fontColor('#8AFFFFFF')
      Column()
        .width(28)
        .height(28)
        .backgroundColor(active ? '#50ECA7' : '#0FFFFFFF')
        .borderRadius(14)
        .border({ width: 1, color: active ? '#50ECA7' : '#14FFFFFF' })
      Text(date)
        .fontFamily(PencilHomeContent.NUMBER_FONT_FAMILY)
        .fontSize(9)
        .fontColor(active ? '#50ECA7' : '#66FFFFFF')
    }
    .layoutWeight(1)
    .height(62)
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
