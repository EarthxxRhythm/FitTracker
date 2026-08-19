/** PencilReviewPage - FitTracker review prototype page. */

interface ReviewBarItem {
  label: string
  height: number
  active: boolean
}

interface DistributionItem {
  label: string
  percent: number
  value: string
}

function createReviewBar(label: string, height: number, active: boolean): ReviewBarItem {
  const item: ReviewBarItem = {
    label: label,
    height: height,
    active: active
  }
  return item
}

function createDistribution(label: string, percent: number, value: string): DistributionItem {
  const item: DistributionItem = {
    label: label,
    percent: percent,
    value: value
  }
  return item
}

const WEEK_BARS: ReviewBarItem[] = [
  createReviewBar('一', 52.6, false),
  createReviewBar('二', 83.4, true),
  createReviewBar('三', 67.1, true),
  createReviewBar('四', 38.1, false),
  createReviewBar('五', 105.2, true),
  createReviewBar('六', 74.4, true),
  createReviewBar('日', 41.7, false)
]

const WEEKDAY_LABELS: string[] = ['一', '二', '三', '四', '五', '六', '日']
const CALENDAR_DAYS: number[] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30]
const TRAIN_DAYS: number[] = [2, 3, 5, 6, 9, 10, 12, 13, 16, 17, 19, 20, 23, 24, 26, 27, 30]
const DISTRIBUTION_ITEMS: DistributionItem[] = [
  createDistribution('胸部', 74, '42 组'),
  createDistribution('背部', 64, '36 组'),
  createDistribution('腿部', 71, '40 组'),
  createDistribution('核心', 43, '24 组')
]

@Component
export struct PencilReviewContent {
  @State private timeScale: string = 'week'

  private isTrainDay(day: number): boolean {
    for (let index = 0; index < TRAIN_DAYS.length; index++) {
      if (TRAIN_DAYS[index] === day) {
        return true
      }
    }
    return false
  }

  private weekText(): string {
    if (this.timeScale === 'month') {
      return '本月 · 6月'
    }
    return '本周 · 6月 7–13日'
  }

  private badgeText(): string {
    if (this.timeScale === 'month') {
      return '↑ +12%'
    }
    return '↑ +18%'
  }

  private headlineText(): string {
    if (this.timeScale === 'month') {
      return '本月节奏更稳定。'
    }
    return '状态不错，继续保持。'
  }

  private descriptionText(): string {
    if (this.timeScale === 'month') {
      return '本月已完成 16 次训练，平均每周 4 次，累计训练 720 分钟。'
    }
    return '你比上周多完成了 1 次训练，平均训练时长也提升了 12 分钟。'
  }

  private statValue(index: number): string {
    if (this.timeScale === 'month') {
      if (index === 0) {
        return '16'
      }
      if (index === 1) {
        return '720'
      }
      return '88'
    }
    if (index === 0) {
      return '4'
    }
    if (index === 1) {
      return '186'
    }
    return '92'
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [['#0B0F13', 0], ['#0D1117', 0.52], ['#0A0D12', 1]]
        })

      Column() {
        Scroll() {
          Column({ space: 14 }) {
            this.segmentedControl()
            this.overviewCard()
            this.statsRow()
            this.activityCard()
            this.distributionCard()
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 28 })
        }
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0B0F13')
  }

  @Builder
  private segmentedControl() {
    Row() {
      Row({ space: 4 }) {
        this.segmentButton('周', 'week')
        this.segmentButton('月', 'month')
      }
      .padding(3)
      .backgroundColor('#0CFFFFFF')
      .borderRadius(999)
      .border({ width: 1, color: '#1AFFFFFF' })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private segmentButton(label: string, key: string) {
    Text(label)
      .fontFamily('Noto Sans SC')
      .fontSize(13)
      .fontWeight(this.timeScale === key ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(this.timeScale === key ? '#07100B' : '#9EFFFFFF')
      .width(70)
      .height(44)
      .textAlign(TextAlign.Center)
      .backgroundColor(this.timeScale === key ? '#50ECA7' : '#00000000')
      .borderRadius(999)
      .onClick(() => {
        this.timeScale = key
      })
  }

  @Builder
  private overviewCard() {
    Column({ space: 12 }) {
      Row() {
        Text(this.weekText())
          .fontFamily('Noto Sans SC')
          .fontSize(12.7)
          .fontWeight(FontWeight.Medium)
          .fontColor('#B3FFFFFF')
        Text(this.badgeText())
          .fontFamily('Inter')
          .fontSize(10.9)
          .fontWeight(FontWeight.Medium)
          .fontColor('#50ECA7')
          .padding({ left: 9, right: 9, top: 5, bottom: 5 })
          .backgroundColor('#1A50ECA7')
          .borderRadius(999)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Text(this.headlineText())
        .fontFamily('Noto Sans SC')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
        .width('100%')

      Text(this.descriptionText())
        .fontFamily('Noto Sans SC')
        .fontSize(11.8)
        .lineHeight(15.9)
        .fontColor('#7AFFFFFF')
        .width('100%')
    }
    .width('100%')
    .padding(16.3)
    .backgroundColor('#08FFFFFF')
    .borderRadius(25.4)
    .border({ width: 1, color: '#10FFFFFF' })
  }

  @Builder
  private statsRow() {
    Row({ space: 9 }) {
      this.statCard('训练', '次', 0)
      this.statCard('时长', '分钟', 1)
      this.statCard('完成率', '%', 2)
    }
    .width('100%')
    .height(73.5)
  }

  @Builder
  private statCard(label: string, unit: string, index: number) {
    Column({ space: 4.5 }) {
      Text(label)
        .fontFamily('Noto Sans SC')
        .fontSize(10.9)
        .fontColor('#7AFFFFFF')
      Row({ space: 3.6 }) {
        Text(this.statValue(index))
          .fontFamily('Geist Mono')
          .fontSize(21.8)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text(unit)
          .fontFamily('Noto Sans SC')
          .fontSize(10.9)
          .fontColor('#50ECA7')
      }
    }
    .layoutWeight(1)
    .height(73.5)
    .padding(12.7)
    .backgroundColor('#171D24')
    .borderRadius(18.1)
    .border({ width: 1, color: '#0AFFFFFF' })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private activityCard() {
    Column({ space: 12.7 }) {
      Row() {
        Text('训练节奏')
          .fontFamily('Noto Sans SC')
          .fontSize(14.5)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text(this.timeScale === 'week' ? '过去 7 天' : '训练 16 天')
          .fontFamily('Noto Sans SC')
          .fontSize(10.9)
          .fontColor('#7AFFFFFF')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      if (this.timeScale === 'week') {
        Row({ space: 9.1 }) {
          ForEach(WEEK_BARS, (bar: ReviewBarItem) => {
            Column({ space: 7.3 }) {
              Row()
                .width('100%')
                .height(bar.height)
                .backgroundColor(bar.active ? '#50ECA7' : '#3350ECA7')
                .borderRadius(9.1)
              Text(bar.label)
                .fontFamily('Noto Sans SC')
                .fontSize(10)
                .fontColor(bar.active ? '#50ECA7' : '#8AFFFFFF')
            }
            .layoutWeight(1)
            .height(136.1)
            .justifyContent(FlexAlign.End)
            .alignItems(HorizontalAlign.Center)
          }, (bar: ReviewBarItem) => bar.label)
        }
        .width('100%')
        .height(136.1)
        .alignItems(VerticalAlign.Bottom)
      } else {
        this.calendarView()
      }
    }
    .width('100%')
    .padding(16.3)
    .backgroundColor('#07FFFFFF')
    .borderRadius(25.4)
    .border({ width: 1, color: '#14FFFFFF' })
  }

  @Builder
  private calendarView() {
    Column({ space: 10 }) {
      Row() {
        Text('2026 年 6 月')
          .fontFamily('Noto Sans SC')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text('训练 16 天')
          .fontFamily('Noto Sans SC')
          .fontSize(10.9)
          .fontColor('#7AFFFFFF')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Row() {
        ForEach(WEEKDAY_LABELS, (day: string) => {
          Text(day)
            .fontFamily('Noto Sans SC')
            .fontSize(10.5)
            .fontColor('#7AFFFFFF')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
        }, (day: string) => day)
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        ForEach(CALENDAR_DAYS, (day: number) => {
          Column({ space: 2 }) {
            Text(day.toString())
              .fontFamily('Inter')
              .fontSize(12.5)
              .fontWeight(this.isTrainDay(day) ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(day === 13 ? '#07100B' : (this.isTrainDay(day) ? '#50ECA7' : '#B3FFFFFF'))
            Row()
              .width(5)
              .height(5)
              .backgroundColor(day === 13 ? '#07100B' : (this.isTrainDay(day) ? '#50ECA7' : '#00000000'))
              .borderRadius(2.5)
          }
          .width(42)
          .height(36)
          .margin({ right: 4, bottom: 4 })
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor(day === 13 ? '#50ECA7' : (this.isTrainDay(day) ? '#1A50ECA7' : '#00000000'))
          .borderRadius(10)
          .border({ width: 1, color: this.isTrainDay(day) ? '#4250ECA7' : '#00000000' })
        }, (day: number) => day.toString())
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private distributionCard() {
    Column({ space: 13 }) {
      Row() {
        Text('部位训练分布')
          .fontFamily('Noto Sans SC')
          .fontSize(14.5)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text('近 30 天 · 累计组数')
          .fontFamily('Noto Sans SC')
          .fontSize(10.9)
          .fontColor('#7AFFFFFF')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      ForEach(DISTRIBUTION_ITEMS, (item: DistributionItem) => {
        Row({ space: 10 }) {
          Text(item.label)
            .fontFamily('Noto Sans SC')
            .fontSize(11.8)
            .fontColor('#B3FFFFFF')
            .width(44)
          Stack({ alignContent: Alignment.Start }) {
            Row()
              .width('100%')
              .height(6)
              .backgroundColor('#14FFFFFF')
              .borderRadius(999)
            Row()
              .width(item.percent.toString() + '%')
              .height(6)
              .backgroundColor('#50ECA7')
              .borderRadius(999)
          }
          .layoutWeight(1)
          .height(6)
          Text(item.value)
            .fontFamily('Geist Mono')
            .fontSize(11.8)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F7FBF8')
            .width(44)
            .textAlign(TextAlign.End)
        }
        .width('100%')
      }, (item: DistributionItem) => item.label)
    }
    .width('100%')
    .padding(16.3)
    .backgroundColor('#08FFFFFF')
    .borderRadius(25.4)
    .border({ width: 1, color: '#1AFFFFFF' })
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
