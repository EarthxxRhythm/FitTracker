/** PencilActivePage —— FitTracker Active Workout 原型页。功能 #27 */
import { AppRoutes } from '../../app/AppRoutes'

@Component
export struct PencilActiveContent {
  private static readonly VIEWPORT_WIDTH: number = 390
  private static readonly DESIGN_WIDTH: number = 430
  private static readonly SCALE: number = PencilActiveContent.VIEWPORT_WIDTH / PencilActiveContent.DESIGN_WIDTH
  private static readonly CONTENT_FONT: string = 'HarmonyOS Sans'
  private static readonly MONO_FONT: string = 'Geist Mono'

  @State rest: boolean = false
  @State completed: number = 2
  private finish(): void {
    this.getUIContext().getRouter().pushUrl({ url: AppRoutes.WORKOUT_COMPLETE })
  }

  private completeSet(): void {
    this.completed = Math.min(6, this.completed + 1)
    this.rest = true
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
          center: [215 * PencilActiveContent.SCALE, 0],
          radius: 220 * PencilActiveContent.SCALE,
          colors: [['#1550ECA7', 0], ['#0050ECA7', 1]]
        })
      Column() {
        Scroll() {
          Column({ space: 18 * PencilActiveContent.SCALE }) {
            this.progressCard()
            this.controlCard()
          }.width('100%').padding({
            left: 18 * PencilActiveContent.SCALE,
            right: 18 * PencilActiveContent.SCALE,
            top: 18 * PencilActiveContent.SCALE,
            bottom: 80 * PencilActiveContent.SCALE
          })
        }.layoutWeight(1)
      }.width('100%').height('100%')
    }.width(PencilActiveContent.VIEWPORT_WIDTH).height('100%')
  }

  @Builder progressCard() {
    Column({ space: 16 * PencilActiveContent.SCALE }) {
      Row() {
        Row({ space: 6 * PencilActiveContent.SCALE }) {
          Column().width(6 * PencilActiveContent.SCALE).height(6 * PencilActiveContent.SCALE)
            .borderRadius(3 * PencilActiveContent.SCALE).backgroundColor('#50ECA7')
          Text(this.rest ? '本组完成' : '训练中').fontFamily(PencilActiveContent.CONTENT_FONT)
            .fontSize(12 * PencilActiveContent.SCALE).lineHeight(16 * PencilActiveContent.SCALE)
            .fontWeight(FontWeight.Bold).fontColor('#50ECA7')
        }
        Text(this.rest ? '已记录 32 kg × 9' : '自动保存 · 刚刚').fontFamily(PencilActiveContent.CONTENT_FONT)
          .fontSize(11 * PencilActiveContent.SCALE).lineHeight(15 * PencilActiveContent.SCALE)
          .fontWeight(FontWeight.Normal).fontColor('#9AFFFFFF').padding({
            left: 10 * PencilActiveContent.SCALE,
            right: 10 * PencilActiveContent.SCALE,
            top: 7 * PencilActiveContent.SCALE,
            bottom: 7 * PencilActiveContent.SCALE
          }).backgroundColor('#08FFFFFF').borderRadius(999 * PencilActiveContent.SCALE)
      }.width('100%').justifyContent(FlexAlign.SpaceBetween)
      Row({ space: 16 * PencilActiveContent.SCALE }) {
        this.setRail()
        Column().width(1 * PencilActiveContent.SCALE).height(214 * PencilActiveContent.SCALE)
          .backgroundColor('#12FFFFFF')
        Column({ space: 14 * PencilActiveContent.SCALE }) {
          Column({ space: 5 * PencilActiveContent.SCALE }) {
            Text('杠铃卧推').fontFamily(PencilActiveContent.CONTENT_FONT).fontSize(34 * PencilActiveContent.SCALE)
              .lineHeight(42 * PencilActiveContent.SCALE).fontWeight(FontWeight.Bold).fontColor('#F7FBF8')
            Text(this.rest ? '组间恢复  |  下一组 · 第 3 组' : '第 2 组  |  正式组')
              .fontFamily(PencilActiveContent.CONTENT_FONT).fontSize(13 * PencilActiveContent.SCALE)
              .lineHeight(18 * PencilActiveContent.SCALE).fontWeight(FontWeight.Bold).fontColor('#50ECA7')
            Text(this.rest ? '下一组目标 8–10 次 · 32 kg' : '目标 8–10 次 · 建议 32 kg')
              .fontFamily(PencilActiveContent.CONTENT_FONT).fontSize(12 * PencilActiveContent.SCALE)
              .lineHeight(17 * PencilActiveContent.SCALE).fontWeight(FontWeight.Normal).fontColor('#9AFFFFFF')
          }.alignItems(HorizontalAlign.Start)
          Row({ space: 8 * PencilActiveContent.SCALE }) {
            this.stat('组进度', this.completed.toString() + ' / 6')
            this.stat(this.rest ? '剩余休息' : '上次休息', this.rest ? '01:12' : '01:34')
            this.stat('节奏', '3·1·1')
          }.width('100%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%').alignItems(VerticalAlign.Top)
      Column({ space: 9 * PencilActiveContent.SCALE }) {
        Row({ space: 8 * PencilActiveContent.SCALE }) {
          Text('第 1 个动作 · ' + this.completed.toString() + '/6 组').fontFamily(PencilActiveContent.CONTENT_FONT)
            .fontSize(12 * PencilActiveContent.SCALE).lineHeight(17 * PencilActiveContent.SCALE)
            .fontWeight(FontWeight.Normal).fontColor('#B3FFFFFF').layoutWeight(1)
          Text(this.rest ? '下一组保持肩胛稳定 18:28' : '肩部注意 · 可替代 18:24')
            .fontFamily(PencilActiveContent.CONTENT_FONT).fontSize(11 * PencilActiveContent.SCALE)
            .lineHeight(15 * PencilActiveContent.SCALE).fontWeight(FontWeight.Normal).fontColor('#9AFFFFFF')
        }.width('100%').alignItems(VerticalAlign.Center)
        Stack() {
          Column().width('100%').height(4 * PencilActiveContent.SCALE).backgroundColor('#14FFFFFF')
            .borderRadius(999 * PencilActiveContent.SCALE)
          Column().width(this.rest ? '48%' : '38%').height(4 * PencilActiveContent.SCALE)
            .backgroundColor('#50ECA7').borderRadius(999 * PencilActiveContent.SCALE).alignSelf(ItemAlign.Start)
        }.width('100%').height(4 * PencilActiveContent.SCALE)
      }.width('100%').padding({
        left: 14 * PencilActiveContent.SCALE,
        right: 14 * PencilActiveContent.SCALE,
        top: 12 * PencilActiveContent.SCALE,
        bottom: 12 * PencilActiveContent.SCALE
      }).backgroundColor('#06FFFFFF').borderRadius(16 * PencilActiveContent.SCALE)
        .border({ width: 1 * PencilActiveContent.SCALE, color: '#0AFFFFFF' })
    }.width('100%').padding({
      left: 18 * PencilActiveContent.SCALE,
      right: 18 * PencilActiveContent.SCALE,
      top: 18 * PencilActiveContent.SCALE,
      bottom: 20 * PencilActiveContent.SCALE
    }).backgroundColor('#08FFFFFF').borderRadius(32 * PencilActiveContent.SCALE)
      .border({ width: 1 * PencilActiveContent.SCALE, color: '#14FFFFFF' })
  }

  @Builder setRail() {
    Column({ space: 7 * PencilActiveContent.SCALE }) {
      Text('01').fontFamily(PencilActiveContent.MONO_FONT).fontSize(28 * PencilActiveContent.SCALE)
        .lineHeight(34 * PencilActiveContent.SCALE).fontWeight(FontWeight.Bold).fontColor('#F7FBF8')
      Text('/ 04').fontFamily(PencilActiveContent.MONO_FONT).fontSize(10 * PencilActiveContent.SCALE)
        .lineHeight(14 * PencilActiveContent.SCALE).fontWeight(FontWeight.Normal).fontColor('#7AFFFFFF')
      Stack() {
        Column({ space: 7 * PencilActiveContent.SCALE }) {
          Column().width(3 * PencilActiveContent.SCALE).height(28 * PencilActiveContent.SCALE)
            .backgroundColor('#50ECA7').borderRadius(999 * PencilActiveContent.SCALE)
          Column().width(3 * PencilActiveContent.SCALE).height(12 * PencilActiveContent.SCALE)
            .backgroundColor('#26FFFFFF').borderRadius(999 * PencilActiveContent.SCALE)
          Column().width(3 * PencilActiveContent.SCALE).height(12 * PencilActiveContent.SCALE)
            .backgroundColor('#1AFFFFFF').borderRadius(999 * PencilActiveContent.SCALE)
          Column().width(3 * PencilActiveContent.SCALE).height(12 * PencilActiveContent.SCALE)
            .backgroundColor('#12FFFFFF').borderRadius(999 * PencilActiveContent.SCALE)
        }.width(3 * PencilActiveContent.SCALE)
      }.width(3 * PencilActiveContent.SCALE).height(91 * PencilActiveContent.SCALE)
        .margin({ top: 2 * PencilActiveContent.SCALE, bottom: 2 * PencilActiveContent.SCALE })
      Image($rawfile('pencil-lucide-dumbbell.svg')).width(18 * PencilActiveContent.SCALE)
        .height(18 * PencilActiveContent.SCALE)
    }.width(50 * PencilActiveContent.SCALE).height(214 * PencilActiveContent.SCALE)
      .padding({ top: 2 * PencilActiveContent.SCALE, bottom: 2 * PencilActiveContent.SCALE })
      .justifyContent(FlexAlign.SpaceBetween).alignItems(HorizontalAlign.Center)
  }

  @Builder controlCard() {
    Column({ space: 14 * PencilActiveContent.SCALE }) {
      Row() {
        Column({ space: 4 * PencilActiveContent.SCALE }) {
          Text(this.rest ? 'REST CONTROL' : 'SET CONSOLE').fontFamily(PencilActiveContent.MONO_FONT)
            .fontSize(10 * PencilActiveContent.SCALE).lineHeight(14 * PencilActiveContent.SCALE)
            .fontWeight(FontWeight.Normal).fontColor('#50ECA7')
          Text(this.rest ? '恢复计时' : '执行记录台').fontFamily(PencilActiveContent.CONTENT_FONT)
            .fontSize(18 * PencilActiveContent.SCALE).lineHeight(24 * PencilActiveContent.SCALE)
            .fontWeight(FontWeight.Bold).fontColor('#F7FBF8')
        }
        Text(this.rest ? '自动开始  开启' : 'RPE 7.5').fontFamily(PencilActiveContent.CONTENT_FONT)
          .fontSize(11 * PencilActiveContent.SCALE).lineHeight(15 * PencilActiveContent.SCALE)
          .fontWeight(FontWeight.Normal).fontColor('#9AFFFFFF').padding({
            left: 10 * PencilActiveContent.SCALE,
            right: 10 * PencilActiveContent.SCALE,
            top: 7 * PencilActiveContent.SCALE,
            bottom: 7 * PencilActiveContent.SCALE
          }).backgroundColor('#08FFFFFF').borderRadius(999 * PencilActiveContent.SCALE)
      }.width('100%').justifyContent(FlexAlign.SpaceBetween)
      if (!this.rest) {
        Column({ space: 12 * PencilActiveContent.SCALE }) {
          Row() {
            Row({ space: 8 * PencilActiveContent.SCALE }) {
              Stack({ alignContent: Alignment.Center }) {
                Column().width(28 * PencilActiveContent.SCALE).height(28 * PencilActiveContent.SCALE)
                  .borderRadius(10 * PencilActiveContent.SCALE).backgroundColor('#1A50ECA7')
                  .border({ width: 1 * PencilActiveContent.SCALE, color: '#2450ECA7' })
                Text('02').fontFamily(PencilActiveContent.MONO_FONT).fontSize(12 * PencilActiveContent.SCALE)
                  .lineHeight(16 * PencilActiveContent.SCALE).fontWeight(FontWeight.Bold).fontColor('#50ECA7')
              }.width(28 * PencilActiveContent.SCALE).height(28 * PencilActiveContent.SCALE)
              Column({ space: 3 * PencilActiveContent.SCALE }) {
                Text('当前组').fontFamily(PencilActiveContent.CONTENT_FONT).fontSize(16 * PencilActiveContent.SCALE)
                  .lineHeight(21 * PencilActiveContent.SCALE).fontWeight(FontWeight.Bold).fontColor('#F7FBF8')
                Text('正式组 · 上次 30 kg × 9 · 本组 +2 kg').fontSize(11 * PencilActiveContent.SCALE)
                  .fontFamily(PencilActiveContent.CONTENT_FONT).lineHeight(16 * PencilActiveContent.SCALE)
                  .fontWeight(FontWeight.Normal).fontColor('#7AFFFFFF')
              }.alignItems(HorizontalAlign.Start)
            }.layoutWeight(1)
            Row({ space: 2 * PencilActiveContent.SCALE }) {
              Text('热身').fontFamily(PencilActiveContent.CONTENT_FONT).fontSize(11 * PencilActiveContent.SCALE)
                .lineHeight(15 * PencilActiveContent.SCALE).fontWeight(FontWeight.Normal).fontColor('#61FFFFFF').padding({
                left: 9 * PencilActiveContent.SCALE,
                right: 9 * PencilActiveContent.SCALE,
                top: 6 * PencilActiveContent.SCALE,
                bottom: 6 * PencilActiveContent.SCALE
              }).borderRadius(9 * PencilActiveContent.SCALE)
              Text('正式').fontFamily(PencilActiveContent.CONTENT_FONT).fontSize(11 * PencilActiveContent.SCALE)
                .lineHeight(15 * PencilActiveContent.SCALE).fontWeight(FontWeight.Bold).fontColor('#50ECA7')
                .padding({
                  left: 9 * PencilActiveContent.SCALE,
                  right: 9 * PencilActiveContent.SCALE,
                  top: 6 * PencilActiveContent.SCALE,
                  bottom: 6 * PencilActiveContent.SCALE
                }).backgroundColor('#1A50ECA7').borderRadius(9 * PencilActiveContent.SCALE)
            }.padding(3 * PencilActiveContent.SCALE).backgroundColor('#08FFFFFF')
              .borderRadius(12 * PencilActiveContent.SCALE)
          }.width('100%')
          Row({ space: 10 * PencilActiveContent.SCALE }) { this.input('重量', '32'); this.input('次数', '9') }
            .width('100%')
          Button('✓  完成本组').width('100%').height(50 * PencilActiveContent.SCALE).padding(0)
            .fontFamily(PencilActiveContent.CONTENT_FONT).fontSize(14 * PencilActiveContent.SCALE)
            .fontWeight(FontWeight.Bold).fontColor('#07100B')
            .backgroundColor('#50ECA7').borderRadius(16 * PencilActiveContent.SCALE)
            .onClick(() => { this.completeSet() })
        }.width('100%').padding(14 * PencilActiveContent.SCALE).backgroundColor('#B8080D11')
          .borderRadius(22 * PencilActiveContent.SCALE)
          .border({ width: 1 * PencilActiveContent.SCALE, color: '#2450ECA7' })
      } else {
        Column({ space: 14 * PencilActiveContent.SCALE }) {
          Row() {
            Row({ space: 10 * PencilActiveContent.SCALE }) {
              Stack({ alignContent: Alignment.Center }) {
                Column().width(30 * PencilActiveContent.SCALE).height(30 * PencilActiveContent.SCALE)
                  .borderRadius(10 * PencilActiveContent.SCALE).backgroundColor('#1A50ECA7')
                Text('✓').fontFamily(PencilActiveContent.CONTENT_FONT).fontSize(16 * PencilActiveContent.SCALE)
                  .lineHeight(20 * PencilActiveContent.SCALE).fontWeight(FontWeight.Bold).fontColor('#50ECA7')
              }.width(30 * PencilActiveContent.SCALE).height(30 * PencilActiveContent.SCALE)
              Column({ space: 3 * PencilActiveContent.SCALE }) {
                Text('第 2 组已完成').fontFamily(PencilActiveContent.CONTENT_FONT).fontSize(16 * PencilActiveContent.SCALE)
                  .lineHeight(21 * PencilActiveContent.SCALE).fontWeight(FontWeight.Bold).fontColor('#F7FBF8')
                Text('32 kg × 9 · RPE 7.5').fontFamily(PencilActiveContent.CONTENT_FONT).fontSize(10 * PencilActiveContent.SCALE)
                  .lineHeight(14 * PencilActiveContent.SCALE).fontWeight(FontWeight.Normal).fontColor('#7AFFFFFF')
              }.alignItems(HorizontalAlign.Start)
            }.layoutWeight(1)
            Text('已同步').fontFamily(PencilActiveContent.CONTENT_FONT).fontSize(11 * PencilActiveContent.SCALE)
              .lineHeight(15 * PencilActiveContent.SCALE).fontWeight(FontWeight.Bold).fontColor('#50ECA7')
          }.width('100%')
          Row() {
            Button('− 15 秒').height(36 * PencilActiveContent.SCALE).padding(0).fontFamily(PencilActiveContent.CONTENT_FONT)
              .fontSize(11 * PencilActiveContent.SCALE)
              .fontWeight(FontWeight.Normal).fontColor('#B3FFFFFF').backgroundColor('#08FFFFFF').borderRadius(999 * PencilActiveContent.SCALE)
            Text('01:12').fontFamily(PencilActiveContent.MONO_FONT).fontSize(42 * PencilActiveContent.SCALE)
              .lineHeight(50 * PencilActiveContent.SCALE).fontWeight(FontWeight.Bold).fontColor('#F7FBF8').layoutWeight(1).textAlign(TextAlign.Center)
            Button('+ 15 秒').height(36 * PencilActiveContent.SCALE).padding(0).fontFamily(PencilActiveContent.CONTENT_FONT)
              .fontSize(11 * PencilActiveContent.SCALE)
              .fontWeight(FontWeight.Normal).fontColor('#B3FFFFFF').backgroundColor('#08FFFFFF').borderRadius(999 * PencilActiveContent.SCALE)
          }.width('100%').alignItems(VerticalAlign.Center)
          Stack() {
            Column().width('100%').height(5 * PencilActiveContent.SCALE).backgroundColor('#14FFFFFF')
              .borderRadius(999 * PencilActiveContent.SCALE)
            Column().width('68%').height(5 * PencilActiveContent.SCALE).backgroundColor('#50ECA7')
              .borderRadius(999 * PencilActiveContent.SCALE).alignSelf(ItemAlign.Start)
          }.width('100%').height(5 * PencilActiveContent.SCALE)
          Button('▷  开始第 3 组').width('100%').height(44 * PencilActiveContent.SCALE).padding(0)
            .fontFamily(PencilActiveContent.CONTENT_FONT).fontSize(14 * PencilActiveContent.SCALE)
            .fontWeight(FontWeight.Bold).fontColor('#07100B')
            .backgroundColor('#50ECA7').borderRadius(16 * PencilActiveContent.SCALE)
            .onClick(() => { this.rest = false })
        }.width('100%').padding(14 * PencilActiveContent.SCALE).backgroundColor('#B8080D11')
          .borderRadius(22 * PencilActiveContent.SCALE)
          .border({ width: 1 * PencilActiveContent.SCALE, color: '#2450ECA7' })
      }
      this.records()
      Button('□  结束训练').width('100%').height(44 * PencilActiveContent.SCALE).padding(0)
        .fontFamily(PencilActiveContent.CONTENT_FONT).fontSize(13 * PencilActiveContent.SCALE)
        .fontWeight(FontWeight.Normal).fontColor('#9AFFFFFF').backgroundColor('#06FFFFFF')
        .borderRadius(16 * PencilActiveContent.SCALE).onClick(() => { this.finish() })
    }.width('100%').padding(18 * PencilActiveContent.SCALE).backgroundColor('#08FFFFFF')
      .borderRadius(30 * PencilActiveContent.SCALE)
      .border({ width: 1 * PencilActiveContent.SCALE, color: '#14FFFFFF' })
  }

  @Builder records() {
    Column({ space: 8 * PencilActiveContent.SCALE }) {
      Row() {
        Text('本动作记录').fontFamily(PencilActiveContent.CONTENT_FONT).fontSize(17 * PencilActiveContent.SCALE)
          .lineHeight(23 * PencilActiveContent.SCALE).fontWeight(FontWeight.Bold).fontColor('#F7FBF8')
        Text(this.completed.toString() + ' / 6').fontFamily(PencilActiveContent.CONTENT_FONT).fontSize(14 * PencilActiveContent.SCALE)
          .lineHeight(19 * PencilActiveContent.SCALE).fontWeight(FontWeight.Bold).fontColor('#50ECA7')
      }.width('100%').justifyContent(FlexAlign.SpaceBetween)
      this.record('第 1 组', '30 kg × 10')
      if (this.rest) {
        this.record('第 2 组', '32 kg × 9')
      } else {
        this.currentRecord('第 2 组 · 当前', '32 kg × 9')
      }
      Row() {
        Text('第 3–6 组').fontFamily(PencilActiveContent.CONTENT_FONT).fontSize(14 * PencilActiveContent.SCALE)
          .lineHeight(19 * PencilActiveContent.SCALE).fontWeight(FontWeight.Normal).fontColor('#66FFFFFF').layoutWeight(1)
        Text(this.rest ? '第 3 组即将开始' : '待开始').fontFamily(PencilActiveContent.CONTENT_FONT)
          .fontSize(12 * PencilActiveContent.SCALE).lineHeight(17 * PencilActiveContent.SCALE)
          .fontWeight(FontWeight.Normal).fontColor('#66FFFFFF')
      }.width('100%').height(52 * PencilActiveContent.SCALE).padding({
        left: 12 * PencilActiveContent.SCALE,
        right: 12 * PencilActiveContent.SCALE
      }).backgroundColor('#06FFFFFF').borderRadius(13 * PencilActiveContent.SCALE).alignItems(VerticalAlign.Center)
      Row() {
        Text('后续动作 · 已折叠').fontFamily(PencilActiveContent.CONTENT_FONT).fontSize(14 * PencilActiveContent.SCALE)
          .lineHeight(19 * PencilActiveContent.SCALE).fontWeight(FontWeight.Bold).fontColor('#9AFFFFFF').layoutWeight(1)
        Text('⌄').fontFamily(PencilActiveContent.CONTENT_FONT).fontSize(15 * PencilActiveContent.SCALE)
          .lineHeight(20 * PencilActiveContent.SCALE).fontWeight(FontWeight.Normal).fontColor('#7AFFFFFF')
      }.width('100%')
      Column({ space: 2 * PencilActiveContent.SCALE }) {
        Row() {
          Text('02   坐姿划船').fontFamily(PencilActiveContent.CONTENT_FONT).fontSize(14 * PencilActiveContent.SCALE)
            .lineHeight(19 * PencilActiveContent.SCALE).fontWeight(FontWeight.Normal).fontColor('#7AFFFFFF').layoutWeight(1)
          Text('4 × 10').fontFamily(PencilActiveContent.MONO_FONT).fontSize(12 * PencilActiveContent.SCALE)
            .lineHeight(17 * PencilActiveContent.SCALE).fontWeight(FontWeight.Normal).fontColor('#66FFFFFF')
        }.width('100%').height(46 * PencilActiveContent.SCALE).alignItems(VerticalAlign.Center)
        Column().width('100%').height(1 * PencilActiveContent.SCALE).backgroundColor('#08FFFFFF')
        Row() {
          Text('03   哑铃侧平举').fontFamily(PencilActiveContent.CONTENT_FONT).fontSize(14 * PencilActiveContent.SCALE)
            .lineHeight(19 * PencilActiveContent.SCALE).fontWeight(FontWeight.Normal).fontColor('#66FFFFFF').layoutWeight(1)
          Text('3 × 12').fontFamily(PencilActiveContent.MONO_FONT).fontSize(12 * PencilActiveContent.SCALE)
            .lineHeight(17 * PencilActiveContent.SCALE).fontWeight(FontWeight.Normal).fontColor('#52FFFFFF')
        }.width('100%').height(46 * PencilActiveContent.SCALE).alignItems(VerticalAlign.Center)
      }.width('100%').padding({
        left: 10 * PencilActiveContent.SCALE,
        right: 10 * PencilActiveContent.SCALE,
        top: 4 * PencilActiveContent.SCALE,
        bottom: 4 * PencilActiveContent.SCALE
      }).backgroundColor('#06FFFFFF').borderRadius(16 * PencilActiveContent.SCALE)
    }.width('100%')
  }

  @Builder stat(label: string, value: string) {
    Column({ space: 4 * PencilActiveContent.SCALE }) {
      Text(label).fontFamily(PencilActiveContent.CONTENT_FONT).fontSize(10 * PencilActiveContent.SCALE)
        .lineHeight(14 * PencilActiveContent.SCALE).fontWeight(FontWeight.Normal).fontColor('#7AFFFFFF')
      Text(value).fontFamily(PencilActiveContent.MONO_FONT).fontSize(16 * PencilActiveContent.SCALE)
        .lineHeight(20 * PencilActiveContent.SCALE).fontWeight(FontWeight.Bold).fontColor('#F7FBF8')
    }.layoutWeight(1).padding({ left: 11 * PencilActiveContent.SCALE, right: 11 * PencilActiveContent.SCALE, top: 10 * PencilActiveContent.SCALE, bottom: 10 * PencilActiveContent.SCALE }).backgroundColor('#081017')
      .borderRadius(14 * PencilActiveContent.SCALE)
      .border({ width: 1 * PencilActiveContent.SCALE, color: '#0DFFFFFF' })
      .alignItems(HorizontalAlign.Start)
  }

  @Builder input(label: string, value: string) {
    Column({ space: 8 * PencilActiveContent.SCALE }) {
      Row() {
        Text(label).fontFamily(PencilActiveContent.CONTENT_FONT).fontSize(12 * PencilActiveContent.SCALE)
          .lineHeight(16 * PencilActiveContent.SCALE).fontWeight(FontWeight.Normal).fontColor('#9AFFFFFF')
        Text(label === '重量' ? 'KG' : '8–10').fontFamily(PencilActiveContent.MONO_FONT).fontSize(10 * PencilActiveContent.SCALE)
          .lineHeight(14 * PencilActiveContent.SCALE).fontWeight(FontWeight.Normal).fontColor('#50ECA7')
      }.width('100%').justifyContent(FlexAlign.SpaceBetween)
      Row() {
        Text('−').fontFamily(PencilActiveContent.CONTENT_FONT).fontSize(16 * PencilActiveContent.SCALE)
          .lineHeight(20 * PencilActiveContent.SCALE).fontWeight(FontWeight.Bold).fontColor('#9AFFFFFF')
          .padding(7 * PencilActiveContent.SCALE).backgroundColor('#08FFFFFF')
          .borderRadius(10 * PencilActiveContent.SCALE)
        Text(value).fontFamily(PencilActiveContent.MONO_FONT).fontSize(24 * PencilActiveContent.SCALE)
          .lineHeight(30 * PencilActiveContent.SCALE).fontWeight(FontWeight.Bold).fontColor('#F7FBF8').layoutWeight(1).textAlign(TextAlign.Center)
        Text('+').fontFamily(PencilActiveContent.CONTENT_FONT).fontSize(16 * PencilActiveContent.SCALE)
          .lineHeight(20 * PencilActiveContent.SCALE).fontWeight(FontWeight.Bold).fontColor('#9AFFFFFF')
          .padding(7 * PencilActiveContent.SCALE).backgroundColor('#08FFFFFF')
          .borderRadius(10 * PencilActiveContent.SCALE)
      }.width('100%')
    }.layoutWeight(1).padding(12 * PencilActiveContent.SCALE).backgroundColor('#06FFFFFF')
      .borderRadius(17 * PencilActiveContent.SCALE).alignItems(HorizontalAlign.Start)
  }

  @Builder currentRecord(label: string, value: string) {
    Row() {
      Text(label).fontFamily(PencilActiveContent.CONTENT_FONT).fontSize(17 * PencilActiveContent.SCALE)
        .lineHeight(23 * PencilActiveContent.SCALE).fontWeight(FontWeight.Normal).fontColor('#F7FBF8').layoutWeight(1)
      Text(value).fontFamily(PencilActiveContent.MONO_FONT).fontSize(15 * PencilActiveContent.SCALE)
        .lineHeight(21 * PencilActiveContent.SCALE).fontWeight(FontWeight.Bold).fontColor('#50ECA7')
    }.width('100%').height(60 * PencilActiveContent.SCALE).padding({ left: 12 * PencilActiveContent.SCALE, right: 12 * PencilActiveContent.SCALE }).backgroundColor('#08FFFFFF')
      .borderRadius(14 * PencilActiveContent.SCALE)
  }

  @Builder record(label: string, value: string) {
    Row() {
      Text(label).fontFamily(PencilActiveContent.CONTENT_FONT).fontSize(17 * PencilActiveContent.SCALE)
        .lineHeight(23 * PencilActiveContent.SCALE).fontWeight(FontWeight.Normal).fontColor('#B3FFFFFF').layoutWeight(1)
      Text(value).fontFamily(PencilActiveContent.MONO_FONT).fontSize(15 * PencilActiveContent.SCALE)
        .lineHeight(21 * PencilActiveContent.SCALE).fontWeight(FontWeight.Bold).fontColor('#50ECA7')
    }.width('100%').height(60 * PencilActiveContent.SCALE).padding({ left: 12 * PencilActiveContent.SCALE, right: 12 * PencilActiveContent.SCALE }).backgroundColor('#08FFFFFF')
      .borderRadius(14 * PencilActiveContent.SCALE)
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
