/** BodyDataContent —— 身体数据二级页界面体（对应 body-data.html · screen-body-data，390 直绘）。 */
import { MotionTokens } from '../../../common/styles/DesignTokens'

interface BodyMetricTile {
  label: string
  value: string
  unit: string
  note: string
  noteMuted: boolean
}

interface MeasureRow {
  label: string
  value: string
  delta: string
  deltaDown: boolean
}

interface TrendSeries {
  vals: number[]
  labels: string[]
  cap: string
}

function createMetricTile(label: string, value: string, unit: string, note: string, noteMuted: boolean): BodyMetricTile {
  return {
    label: label,
    value: value,
    unit: unit,
    note: note,
    noteMuted: noteMuted
  }
}

function createMeasure(label: string, value: string, delta: string, deltaDown: boolean): MeasureRow {
  return {
    label: label,
    value: value,
    delta: delta,
    deltaDown: deltaDown
  }
}

@Component
export struct BodyDataContent {
  @State private backPressed: boolean = false
  @State private ctaPressed: boolean = false
  @State private savePressed: boolean = false
  @State private cancelPressed: boolean = false
  @State private sheetOpen: boolean = false
  @State private currentWeight: string = '72.5'
  @State private weightInput: string = '72.5'
  @State private sheetHint: string = ''
  @State private period: string = 'week'
  @State private trendCap: string = '近 7 天 · −0.3 kg'

  private readonly metrics: BodyMetricTile[] = [
    createMetricTile('BMI', '22.9', '', '正常范围', false),
    createMetricTile('骨骼肌', '34.2', 'kg', '标准', true),
    createMetricTile('基础代谢', '1710', 'kcal', '估算值', true),
    createMetricTile('身体水分', '58.2', '%', '正常范围', false)
  ]

  private readonly measures: MeasureRow[] = [
    createMeasure('胸围', '96.0 cm', '+0.5', false),
    createMeasure('腰围', '78.0 cm', '−1.0', true),
    createMeasure('臀围', '92.0 cm', '+0.3', false),
    createMeasure('臂围', '34.5 cm', '+0.2', false),
    createMeasure('大腿围', '54.0 cm', '+0.4', false)
  ]

  private readonly trendX: number[] = [20, 68, 115, 163, 210, 258, 305]

  private readonly weekSeries: TrendSeries = {
    vals: [72.8, 72.6, 72.7, 72.4, 72.6, 72.5, 72.5],
    labels: ['一', '二', '三', '四', '五', '六', '日'],
    cap: '近 7 天 · −0.3 kg'
  }

  private readonly monthSeries: TrendSeries = {
    vals: [71.8, 71.9, 72.2, 72.0, 72.3, 72.4, 72.5],
    labels: ['8周前', '', '', '4周前', '', '', '本周'],
    cap: '近 30 天 · +0.7 kg'
  }

  private readonly yearSeries: TrendSeries = {
    vals: [68.2, 68.9, 69.6, 70.4, 71.0, 71.8, 72.5],
    labels: ['去年9月', '', '', '3月', '', '', '现在'],
    cap: '近 12 个月 · +4.5 kg'
  }

  private trendSettings: RenderingContextSettings = new RenderingContextSettings(true)
  private trendContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.trendSettings)

  private handleBack(): void {
    this.getUIContext().getRouter().back()
  }

  private openSheet(): void {
    this.weightInput = this.currentWeight
    this.sheetHint = ''
    this.sheetOpen = true
  }

  private closeSheet(): void {
    this.sheetOpen = false
    this.sheetHint = ''
  }

  private saveWeight(): void {
    const parsed: number = Number(this.weightInput)
    if (Number.isNaN(parsed) || parsed <= 0 || parsed > 500) {
      this.sheetHint = '请输入 0–500 之间的有效体重'
      return
    }
    this.currentWeight = parsed.toFixed(1)
    this.closeSheet()
  }

  private getTrendSeries(key: string): TrendSeries {
    if (key === 'month') {
      return this.monthSeries
    }
    if (key === 'year') {
      return this.yearSeries
    }
    return this.weekSeries
  }

  private selectPeriod(key: string): void {
    this.period = key
    this.trendCap = this.getTrendSeries(key).cap
    this.drawTrendChart()
  }

  private drawTrendChart(): void {
    const ctx: CanvasRenderingContext2D = this.trendContext
    const width: number = ctx.width
    const height: number = ctx.height
    if (width <= 0 || height <= 0) {
      return
    }
    const s: TrendSeries = this.getTrendSeries(this.period)
    ctx.clearRect(0, 0, width, height)
    const scaleX: number = width / 326
    const scaleY: number = height / 140
    ctx.save()
    ctx.scale(scaleX, scaleY)

    ctx.strokeStyle = 'rgba(255,255,255,0.06)'
    ctx.lineWidth = 1
    ctx.beginPath()
    ctx.moveTo(20, 20)
    ctx.lineTo(305, 20)
    ctx.stroke()

    ctx.strokeStyle = 'rgba(255,255,255,0.10)'
    ctx.beginPath()
    ctx.moveTo(20, 100)
    ctx.lineTo(305, 100)
    ctx.stroke()

    let lo: number = s.vals[0]
    let hi: number = s.vals[0]
    for (let i = 1; i < s.vals.length; i++) {
      if (s.vals[i] < lo) {
        lo = s.vals[i]
      }
      if (s.vals[i] > hi) {
        hi = s.vals[i]
      }
    }
    const span: number = hi - lo
    const pointsY: number[] = []
    for (let i = 0; i < s.vals.length; i++) {
      const ratio: number = span > 0 ? (s.vals[i] - lo) / span : 0.5
      pointsY.push(100 - ratio * (100 - 18))
    }

    const gradient: CanvasGradient = ctx.createLinearGradient(0, 0, 0, 140)
    gradient.addColorStop(0, 'rgba(80,236,167,0.18)')
    gradient.addColorStop(1, 'rgba(80,236,167,0)')
    ctx.fillStyle = gradient
    ctx.beginPath()
    ctx.moveTo(this.trendX[0], 112)
    for (let i = 0; i < this.trendX.length; i++) {
      ctx.lineTo(this.trendX[i], pointsY[i])
    }
    ctx.lineTo(this.trendX[this.trendX.length - 1], 112)
    ctx.closePath()
    ctx.fill()

    ctx.strokeStyle = '#50ECA7'
    ctx.lineWidth = 2
    ctx.lineCap = 'round'
    ctx.lineJoin = 'round'
    ctx.beginPath()
    ctx.moveTo(this.trendX[0], pointsY[0])
    for (let i = 1; i < this.trendX.length; i++) {
      ctx.lineTo(this.trendX[i], pointsY[i])
    }
    ctx.stroke()

    for (let i = 0; i < this.trendX.length; i++) {
      const isLast: boolean = i === this.trendX.length - 1
      const radius: number = isLast ? 4.5 : 3
      ctx.beginPath()
      ctx.arc(this.trendX[i], pointsY[i], radius, 0, Math.PI * 2)
      ctx.fillStyle = isLast ? '#50ECA7' : '#0B0F13'
      ctx.fill()
      ctx.strokeStyle = '#50ECA7'
      ctx.lineWidth = 1.5
      ctx.stroke()
    }

    ctx.fillStyle = 'rgba(255,255,255,0.5)'
    ctx.font = '9px Inter'
    ctx.textAlign = 'center'
    for (let i = 0; i < s.labels.length; i++) {
      if (s.labels[i].length > 0) {
        ctx.fillText(s.labels[i], this.trendX[i], 126)
      }
    }

    ctx.restore()
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 180, colors: [['#0B0F13', 0], ['#0A0D12', 1]] })

      Column() {
        Row({ space: 10 }) {
          Row() {
            Path()
              .width(20)
              .height(20)
              .commands('M14 6 L8 12 L14 18')
              .fillOpacity(0)
              .stroke('#B3FFFFFF')
              .strokeWidth(2)
          }
          .width(44)
            .height(44)
            .borderRadius(22)
            .backgroundColor('#0CFFFFFF')
            .border({ width: 1, color: '#14FFFFFF' })
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .scale({ x: this.backPressed ? MotionTokens.PRESS_BACK : 1, y: this.backPressed ? MotionTokens.PRESS_BACK : 1 })
            .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.backPressed = true
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.backPressed = false
              }
            })
            .onClick(() => {
              this.handleBack()
            })
          Text('身体数据')
            .fontFamily('Noto Sans SC')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F7FBF8')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Column() {
            Text('21')
              .fontFamily('Inter')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#B3FFFFFF')
              .lineHeight(13)
            Text('8月')
              .fontFamily('Noto Sans SC')
              .fontSize(11)
              .fontColor('#8AFFFFFF')
              .lineHeight(11)
              .margin({ top: 2 })
          }
          .width(44)
          .alignItems(HorizontalAlign.Center)
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .padding({ top: 52, bottom: 12, left: 16, right: 16 })
        .alignItems(VerticalAlign.Center)

        Scroll() {
          Column({ space: 14 }) {
            this.weightSummaryCard()
            this.compositionCard()
            this.trendCard()
            this.measurementsCard()

            Button('记录今日体重')
              .width('100%')
              .height(54)
              .padding(0)
              .fontFamily('Noto Sans SC')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#07100B')
              .backgroundColor('#50ECA7')
              .borderRadius(17)
              .shadow({ radius: 28, color: '#52000000', offsetX: 0, offsetY: 12 })
              .scale({ x: this.ctaPressed ? MotionTokens.PRESS_SHORTCUT : 1, y: this.ctaPressed ? MotionTokens.PRESS_SHORTCUT : 1 })
              .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
              .onTouch((event: TouchEvent) => {
                if (event.type === TouchType.Down) {
                  this.ctaPressed = true
                } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                  this.ctaPressed = false
                }
              })
              .onClick(() => {
                this.openSheet()
              })

            Text('身体数据仅保存在本机；单位可在「设置」中切换为磅（lbs）。本页数值为界面示例，用于展示信息层级与交互。')
              .fontFamily('Noto Sans SC')
              .fontSize(11)
              .fontColor('#66FFFFFF')
              .lineHeight(18)
              .padding({ left: 4, right: 4 })
              .width('100%')
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 6, bottom: 30 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')

      if (this.sheetOpen) {
        Column() {
          Blank()
            .width('100%')
            .layoutWeight(1)
            .onClick(() => {
              this.closeSheet()
            })
          Column() {
            Row()
              .width(40)
              .height(4)
              .borderRadius(999)
              .backgroundColor('#52FFFFFF')
            Text('记录今日体重')
              .fontFamily('Noto Sans SC')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F7FBF8')
              .textAlign(TextAlign.Center)
              .width('100%')
              .margin({ top: 18 })
            Text('每次记录都会被纳入体重趋势')
              .fontFamily('Noto Sans SC')
              .fontSize(12)
              .fontColor('#8AFFFFFF')
              .textAlign(TextAlign.Center)
              .width('100%')
              .margin({ top: 5 })
            Row({ space: 8 }) {
              TextInput({ text: this.weightInput, placeholder: '72.5' })
                .type(InputType.NUMBER_DECIMAL)
                .fontFamily('Inter')
                .fontSize(40)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F7FBF8')
                .placeholderColor('#52FFFFFF')
                .backgroundColor('#0FFFFFFF')
                .border({ width: 1, color: '#14FFFFFF' })
                .borderRadius(18)
                .width(140)
                .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                .textAlign(TextAlign.Center)
                .onChange((value: string) => {
                  this.weightInput = value
                })
              Text('kg')
                .fontFamily('Inter')
                .fontSize(16)
                .fontColor('#9EFFFFFF')
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .margin({ top: 20 })
            Text(this.sheetHint)
              .fontFamily('Noto Sans SC')
              .fontSize(11.5)
              .fontColor('#50ECA7')
              .textAlign(TextAlign.Center)
              .width('100%')
              .height(16)
              .margin({ top: 14 })
            Row({ space: 10 }) {
              Button('取消')
                .layoutWeight(1)
                .height(50)
                .padding(0)
                .fontFamily('Noto Sans SC')
                .fontSize(14.5)
                .fontWeight(FontWeight.Medium)
                .fontColor('#B3FFFFFF')
                .backgroundColor('#0FFFFFFF')
                .border({ width: 1, color: '#14FFFFFF' })
                .borderRadius(16)
                .onClick(() => {
                  this.closeSheet()
                })
              Button('保存')
                .layoutWeight(1)
                .height(50)
                .padding(0)
                .fontFamily('Noto Sans SC')
                .fontSize(14.5)
                .fontWeight(FontWeight.Medium)
                .fontColor('#07100B')
                .backgroundColor('#50ECA7')
                .borderRadius(16)
                .onClick(() => {
                  this.saveWeight()
                })
            }
            .width('100%')
            .margin({ top: 20 })
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 12, bottom: 30 })
          .backgroundColor('#0A0D12')
          .border({ width: { top: 1 }, color: '#1AFFFFFF' })
          .borderRadius({ topLeft: 28, topRight: 28 })
          .shadow({ radius: 60, color: '#73000000', offsetX: 0, offsetY: -24 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#80000000')
        .transition(TransitionEffect.OPACITY.animation({ duration: MotionTokens.DURATION_OVERLAY, curve: MotionTokens.EASE_MOTION }))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0B0F13')
  }

  @Builder
  private weightSummaryCard() {
    Column() {
      Row() {
        Text('当前体重')
          .fontFamily('Noto Sans SC')
          .fontSize(12)
          .fontColor('#9EFFFFFF')
        Text('今日 · 更新于 07:40')
          .fontFamily('Inter')
          .fontSize(11)
          .fontColor('#8AFFFFFF')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Row({ space: 7 }) {
        Text(this.currentWeight)
          .fontFamily('Inter')
          .fontSize(56)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
          .letterSpacing(-1.1)
          .margin({ top: 10 })
        Text('kg')
          .fontFamily('Inter')
          .fontSize(16)
          .fontColor('#9EFFFFFF')
          .margin({ top: 10 })
      }
      .width('100%')

      Row({ space: 5 }) {
        Path()
          .width(13)
          .height(13)
          .commands('M6.5 1 L6.5 10.5 M2.5 6.5 L6.5 10.5 L10.5 6.5')
          .fillOpacity(0)
          .stroke('#50ECA7')
          .strokeWidth(2)
          .strokeLineCap(LineCapStyle.Round)
          .strokeLineJoin(LineJoinStyle.Round)
        Text('较上周 −0.3 kg')
          .fontFamily('Noto Sans SC')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#50ECA7')
      }
      .padding({ left: 11, right: 11, top: 5, bottom: 5 })
      .backgroundColor('#1A50ECA7')
      .borderRadius(999)
      .margin({ top: 12 })

      Row()
        .width('100%')
        .height(1)
        .backgroundColor('#0FFFFFFF')
        .margin({ top: 16 })

      Row() {
        Text('增肌目标 74.0 kg')
          .fontFamily('Noto Sans SC')
          .fontSize(12)
          .fontColor('#9EFFFFFF')
        Text('还差 1.5 kg')
          .fontFamily('Inter')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F7FBF8')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 15 })

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(7)
          .backgroundColor('#14FFFFFF')
          .borderRadius(999)
        Row()
          .width('98%')
          .height(7)
          .backgroundColor('#50ECA7')
          .borderRadius(999)
          .animation({ duration: MotionTokens.DURATION_PROGRESS, curve: MotionTokens.EASE_PANEL })
      }
      .width('100%')
      .height(7)
      .margin({ top: 10 })
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#0F50ECA7')
    .border({ width: 1, color: '#3850ECA7' })
    .borderRadius(26)
    .shadow({ radius: 40, color: '#38000000', offsetX: 0, offsetY: 20 })
  }

  @Builder
  private compositionCard() {
    Column() {
      Row() {
        Text('身体成分')
          .fontFamily('Noto Sans SC')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text('目标 · 增肌')
          .fontFamily('Noto Sans SC')
          .fontSize(11)
          .fontColor('#9EFFFFFF')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Row() {
        Row({ space: 0 }) {
          Text('16.2')
            .fontFamily('Inter')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#50ECA7')
          Text('%')
            .fontFamily('Inter')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#9EFFFFFF')
        }
        .alignItems(VerticalAlign.Bottom)
        Blank()
        Text('体脂率 · 健康区间 10–20%')
          .fontFamily('Noto Sans SC')
          .fontSize(11)
          .fontColor('#9EFFFFFF')
      }
      .width('100%')
      .margin({ top: 14, bottom: 8 })

      Stack({ alignContent: Alignment.TopStart }) {
        Row()
          .width('100%')
          .height(8)
          .backgroundColor('#14FFFFFF')
          .borderRadius(999)
          .position({ x: 0, y: 11 })
        Row()
          .width('50%')
          .height(8)
          .backgroundColor('#3350ECA7')
          .borderRadius(999)
          .position({ x: 82, y: 11 })
        Row()
          .width(20)
          .height(20)
          .borderRadius(10)
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: '#8050ECA7' })
          .position({ x: 173, y: 5 })
        Row()
          .width(18)
          .height(18)
          .borderRadius(9)
          .backgroundColor('#50ECA7')
          .border({ width: 3, color: '#0B0F13' })
          .position({ x: 174, y: 6 })
      }
      .width('100%')
      .height(30)
      .margin({ top: 8 })

      Row() {
        Text('偏低')
          .fontFamily('Inter')
          .fontSize(10)
          .fontColor('#66FFFFFF')
        Text('健康')
          .fontFamily('Inter')
          .fontSize(10)
          .fontColor('#66FFFFFF')
        Text('偏高')
          .fontFamily('Inter')
          .fontSize(10)
          .fontColor('#66FFFFFF')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 4 })

      Grid() {
        ForEach(this.metrics, (tile: BodyMetricTile) => {
          GridItem() {
            Column() {
              Text(tile.label)
                .fontFamily('Noto Sans SC')
                .fontSize(11.5)
                .fontColor('#9EFFFFFF')
              Row({ space: 3 }) {
                Text(tile.value)
                  .fontFamily('Inter')
                  .fontSize(21)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#F7FBF8')
                if (tile.unit.length > 0) {
                  Text(tile.unit)
                    .fontFamily('Inter')
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#9EFFFFFF')
                }
              }
              .margin({ top: 7 })
              Text(tile.note)
                .fontFamily('Noto Sans SC')
                .fontSize(10.5)
                .fontColor(tile.noteMuted ? '#66FFFFFF' : '#50ECA7')
                .margin({ top: 6 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ top: 13, bottom: 13, left: 14, right: 14 })
            .backgroundColor('#06FFFFFF')
            .border({ width: 1, color: '#0FFFFFFF' })
            .borderRadius(16)
          }
        }, (tile: BodyMetricTile) => tile.label + tile.unit)
      }
      .columnsTemplate('1fr 1fr')
      .columnsGap(10)
      .rowsGap(10)
      .width('100%')
      .margin({ top: 16 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#08FFFFFF')
    .border({ width: 1, color: '#1AFFFFFF' })
    .borderRadius(22)
  }

  @Builder
  private trendCard() {
    Column() {
      Row() {
        Column() {
          Text('体重趋势')
            .fontFamily('Noto Sans SC')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F7FBF8')
          Text(this.trendCap)
            .fontFamily('Inter')
            .fontSize(11)
            .fontColor('#8AFFFFFF')
            .margin({ top: 3 })
        }
        Row({ space: 2 }) {
          this.periodButton('周', 'week')
          this.periodButton('月', 'month')
          this.periodButton('年', 'year')
        }
        .padding(3)
        .backgroundColor('#0FFFFFFF')
        .border({ width: 1, color: '#1AFFFFFF' })
        .borderRadius(12)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: 14 })

      Canvas(this.trendContext)
        .width('100%')
        .aspectRatio(326 / 140)
        .margin({ top: 4 })
        .onReady(() => {
          this.drawTrendChart()
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#08FFFFFF')
    .border({ width: 1, color: '#1AFFFFFF' })
    .borderRadius(22)
  }

  @Builder
  private periodButton(label: string, key: string) {
    Button(label)
      .height(30)
      .padding({ left: 14, right: 14 })
      .fontFamily('Noto Sans SC')
      .fontSize(12.5)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.period === key ? '#07100B' : '#9EFFFFFF')
      .backgroundColor(this.period === key ? '#50ECA7' : Color.Transparent)
      .borderRadius(9)
      .animation({ duration: MotionTokens.DURATION_COLOR_FAST, curve: MotionTokens.EASE_MOTION })
      .onClick(() => {
        this.selectPeriod(key)
      })
  }

  @Builder
  private measurementsCard() {
    Column() {
      Row() {
        Text('围度记录')
          .fontFamily('Noto Sans SC')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text('较上月')
          .fontFamily('Noto Sans SC')
          .fontSize(11)
          .fontColor('#9EFFFFFF')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: 14 })

      ForEach(this.measures, (row: MeasureRow, index: number) => {
        Row() {
          Text(row.label)
            .fontFamily('Noto Sans SC')
            .fontSize(13.5)
            .fontColor('#B3FFFFFF')
          Blank()
          Text(row.value)
            .fontFamily('Inter')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#F7FBF8')
          Text(row.delta)
            .fontFamily('Inter')
            .fontSize(11.5)
            .fontColor(row.deltaDown ? '#8AFFFFFF' : '#50ECA7')
            .width(44)
            .textAlign(TextAlign.End)
        }
        .width('100%')
        .padding({ top: 13, bottom: 13 })
        .border({ width: { top: index === 0 ? 0 : 1 }, color: '#0FFFFFFF' })
      }, (row: MeasureRow) => row.label)
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#08FFFFFF')
    .border({ width: 1, color: '#1AFFFFFF' })
    .borderRadius(22)
  }
}
