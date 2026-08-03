/** PencilPlanPage - FitTracker Plan prototype page. Function #27 */
import { AppRoutes } from '../../app/AppRoutes'

@Component
export struct PencilPlanContent {
  private static readonly VIEWPORT_WIDTH: number = 390
  private static readonly DESIGN_WIDTH: number = 430
  private static readonly SCALE: number = PencilPlanContent.VIEWPORT_WIDTH / PencilPlanContent.DESIGN_WIDTH
  build() {
    Column() {
      Scroll() {
        this.scrollContent()
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').backgroundColor('#0B0F13')
  }

  @Builder
  private scrollContent() {
    Column({ space: 18 * PencilPlanContent.SCALE }) {
      this.planHero()
      this.carouselSection()
      Row({ space: 6 * PencilPlanContent.SCALE }) {
        Column().width(18 * PencilPlanContent.SCALE).height(5 * PencilPlanContent.SCALE)
          .borderRadius(2 * PencilPlanContent.SCALE).backgroundColor('#50ECA7')
        Column().width(5 * PencilPlanContent.SCALE).height(5 * PencilPlanContent.SCALE)
          .borderRadius(3 * PencilPlanContent.SCALE).backgroundColor('#3AFFFFFF')
        Column().width(5 * PencilPlanContent.SCALE).height(5 * PencilPlanContent.SCALE)
          .borderRadius(3 * PencilPlanContent.SCALE).backgroundColor('#3AFFFFFF')
        Column().width(5 * PencilPlanContent.SCALE).height(5 * PencilPlanContent.SCALE)
          .borderRadius(3 * PencilPlanContent.SCALE).backgroundColor('#3AFFFFFF')
      }.width('100%').height(8 * PencilPlanContent.SCALE).justifyContent(FlexAlign.Center)
    }.width('100%').padding({
      left: 18 * PencilPlanContent.SCALE,
      right: 18 * PencilPlanContent.SCALE,
      top: 58 * PencilPlanContent.SCALE,
      bottom: 118 * PencilPlanContent.SCALE
    })
  }
  @Builder planHero() {
    Column({ space: 14 * PencilPlanContent.SCALE }) {
      Column({ space: 10 * PencilPlanContent.SCALE }) {
        Column({ space: 6 * PencilPlanContent.SCALE }) {
          Text('五日增肌计划').fontFamily('Geist').fontSize(28 * PencilPlanContent.SCALE)
            .fontWeight(FontWeight.Bold).fontColor('#F7FBF8').width('100%')
          Text('5 练分化，6 周推进。').fontSize(13 * PencilPlanContent.SCALE)
            .fontColor('#9AFFFFFF').width('100%')
        }
      }.width('100%')
      Row({ space: 10 * PencilPlanContent.SCALE }) {
        this.heroMetric('频率', '每周 5 练')
        this.heroMetric('目标', '增肌优先')
        this.heroMetric('周期', '6 周')
      }.width('100%')
    }.width('100%').padding(18 * PencilPlanContent.SCALE).backgroundColor('#08FFFFFF')
      .borderRadius(28 * PencilPlanContent.SCALE)
      .border({ width: 1 * PencilPlanContent.SCALE, color: '#10FFFFFF' })
  }

  @Builder carouselSection() {
    Row({ space: 9 * PencilPlanContent.SCALE }) {
      this.activeCard()
      Column({ space: 10 * PencilPlanContent.SCALE }) {
        Text('第 2 天').fontSize(12 * PencilPlanContent.SCALE).fontColor('#7AFFFFFF')
        Text('上肢拉伸').fontSize(20 * PencilPlanContent.SCALE).fontWeight(FontWeight.Bold).fontColor('#F7FBF8')
        Text('明日计划').fontSize(12 * PencilPlanContent.SCALE).fontColor('#7AFFFFFF')
      }.width(290 * PencilPlanContent.SCALE).height(632 * PencilPlanContent.SCALE)
        .margin({ top: 10 * PencilPlanContent.SCALE }).padding(16 * PencilPlanContent.SCALE)
        .backgroundColor('#0D50ECA7').borderRadius(30 * PencilPlanContent.SCALE)
      Column({ space: 10 * PencilPlanContent.SCALE }) {
        Text('第 3 天').fontSize(12 * PencilPlanContent.SCALE).fontColor('#7AFFFFFF')
        Text('核心恢复').fontSize(18 * PencilPlanContent.SCALE).fontWeight(FontWeight.Bold).fontColor('#F7FBF8')
      }.width(276 * PencilPlanContent.SCALE).height(620 * PencilPlanContent.SCALE)
        .margin({ top: 18 * PencilPlanContent.SCALE }).padding(18 * PencilPlanContent.SCALE)
        .backgroundColor('#0D50ECA7').borderRadius(28 * PencilPlanContent.SCALE)
    }.width(730 * PencilPlanContent.SCALE).height(730 * PencilPlanContent.SCALE)
      .padding({ left: 14 * PencilPlanContent.SCALE })
      .alignSelf(ItemAlign.Start)
  }

  @Builder activeCard() {
    Column({ space: 14 * PencilPlanContent.SCALE }) {
      Column({ space: 8 * PencilPlanContent.SCALE }) {
        Row() {
          Column({ space: 8 * PencilPlanContent.SCALE }) {
            Text('第 1 天 / 推').fontSize(12 * PencilPlanContent.SCALE)
              .fontWeight(FontWeight.Bold).fontColor('#9AFFFFFF')
            Text('推举日').fontSize(29 * PencilPlanContent.SCALE)
              .fontWeight(FontWeight.Bold).fontColor('#F7FBF8')
            Text('上肢推力').fontSize(16 * PencilPlanContent.SCALE).fontColor('#9AFFFFFF')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Text('今日').fontSize(12 * PencilPlanContent.SCALE).fontWeight(FontWeight.Bold)
            .fontColor('#07100B').padding({
              left: 12 * PencilPlanContent.SCALE,
              right: 12 * PencilPlanContent.SCALE,
              top: 8 * PencilPlanContent.SCALE,
              bottom: 8 * PencilPlanContent.SCALE
            }).backgroundColor('#50ECA7').borderRadius(999 * PencilPlanContent.SCALE)
        }.width('100%')
      }.width('100%')
      Row({ space: 8 * PencilPlanContent.SCALE }) {
        this.dayMetric('动作数量', '5 个')
        this.dayMetric('预计时长', '62 分钟')
      }.width('100%')
      Row({ space: 6 * PencilPlanContent.SCALE }) {
        this.muscle('胸部', true)
        this.muscle('前三角', false)
        this.muscle('肱三头', false)
      }.width('100%')
      this.exercise('01', '杠铃卧推', '胸部 / 三头', '4 × 6')
      this.exercise('02', '上斜哑铃卧推', '上肢', '3 × 8')
      this.exercise('03', '坐姿推肩', '肩前束', '3 × 8')
      this.exercise('04', '绳索夹胸', '胸部收缩', '3 × 12')
      this.exercise('05', '双绳下压', '三头收尾', '2 × 15')
    }.width(323 * PencilPlanContent.SCALE).height(644 * PencilPlanContent.SCALE)
      .padding(16 * PencilPlanContent.SCALE).backgroundColor('#08FFFFFF')
      .borderRadius(32 * PencilPlanContent.SCALE)
      .border({ width: 1 * PencilPlanContent.SCALE, color: '#14FFFFFF' })
  }

  @Builder heroMetric(label: string, value: string) {
    Column({ space: 3 * PencilPlanContent.SCALE }) {
      Text(label).fontSize(11 * PencilPlanContent.SCALE).fontColor('#7AFFFFFF')
      Text(value).fontSize(21 * PencilPlanContent.SCALE).fontWeight(FontWeight.Bold).fontColor('#F7FBF8')
    }.layoutWeight(1).padding({
      left: 12 * PencilPlanContent.SCALE,
      right: 12 * PencilPlanContent.SCALE,
      top: 13 * PencilPlanContent.SCALE,
      bottom: 12 * PencilPlanContent.SCALE
    }).backgroundColor('#08FFFFFF').borderRadius(22 * PencilPlanContent.SCALE)
      .alignItems(HorizontalAlign.Start)
  }

  @Builder dayMetric(label: string, value: string) {
    Column({ space: 4 * PencilPlanContent.SCALE }) {
      Text(label).fontSize(11 * PencilPlanContent.SCALE).fontColor('#7AFFFFFF')
      Text(value).fontSize(22 * PencilPlanContent.SCALE).fontWeight(FontWeight.Bold).fontColor('#F7FBF8')
    }.layoutWeight(1).padding({
      left: 14 * PencilPlanContent.SCALE,
      right: 14 * PencilPlanContent.SCALE,
      top: 13 * PencilPlanContent.SCALE,
      bottom: 13 * PencilPlanContent.SCALE
    }).backgroundColor('#08FFFFFF').borderRadius(22 * PencilPlanContent.SCALE)
      .alignItems(HorizontalAlign.Start)
  }

  @Builder muscle(label: string, active: boolean) {
    Text(label).fontSize(12 * PencilPlanContent.SCALE)
      .fontColor(active ? '#07100B' : '#9AFFFFFF')
      .padding({ left: 12 * PencilPlanContent.SCALE, right: 12 * PencilPlanContent.SCALE })
      .backgroundColor(active ? '#50ECA7' : '#08FFFFFF')
      .borderRadius(18 * PencilPlanContent.SCALE).height(34 * PencilPlanContent.SCALE)
      .textAlign(TextAlign.Center)
  }

  @Builder exercise(index: string, name: string, group: string, prescription: string) {
    Row({ space: 10 * PencilPlanContent.SCALE }) {
      Text(index).fontSize(12 * PencilPlanContent.SCALE).fontWeight(FontWeight.Bold).fontColor('#50ECA7')
        .width(28 * PencilPlanContent.SCALE).height(28 * PencilPlanContent.SCALE).textAlign(TextAlign.Center)
        .backgroundColor('#081017').borderRadius(999 * PencilPlanContent.SCALE)
      Column({ space: 3 * PencilPlanContent.SCALE }) {
        Text(name).fontSize(15 * PencilPlanContent.SCALE).fontWeight(FontWeight.Medium).fontColor('#F7FBF8')
        Text(group).fontSize(12 * PencilPlanContent.SCALE).fontColor('#7AFFFFFF')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text(prescription).fontSize(12 * PencilPlanContent.SCALE).fontWeight(FontWeight.Bold).fontColor('#50ECA7')
        .padding({ left: 8 * PencilPlanContent.SCALE, right: 8 * PencilPlanContent.SCALE })
        .backgroundColor('#1A50ECA7').borderRadius(999 * PencilPlanContent.SCALE)
        .height(28 * PencilPlanContent.SCALE).textAlign(TextAlign.Center)
    }.width('100%').padding(12 * PencilPlanContent.SCALE).backgroundColor('#06FFFFFF')
      .borderRadius(20 * PencilPlanContent.SCALE)
  }

}

@Entry
@Component
struct PencilPlanPage {
  build() {
    Column() {
      PencilPlanContent()
    }
  }
}
