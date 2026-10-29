/**
 * WeightRecordDialog —— 首页「开始训练」前置的体重记录底部面板。
 *
 * 形态与动效（对齐 2026-10-28 手绘原型）：
 *  - 面板自屏幕下方升起，0.5s，`cubic-bezier(.2,.7,.2,1)`（= MotionTokens.EASE_MOTION）；
 *  - 遮罩同步淡入到 40% 黑；
 *  - 平滑体重曲线在 1.2s 内从原点画到末点，末端数值随曲线尖端从 0 滚到最新体重。
 *
 * 图表语言与回顾页 `ReviewContent.drawWeightChart` 同源（342×132 逻辑视口、绘图区
 * x 12–330 / y 16–100、4 条 0.06 白网格、面积基线 y=120）：两屏是同一份数据，
 * 曲线形状不该因所在容器不同而变形。
 *
 * 大数字区域是**空输入条**（不预填历史值、不参与动画），用户在此手输今日体重。
 * 曲线右上方的「体重数据」标签按需求删除，不留替代文案。
 *
 * 由 `PencilAppShell` 条件渲染（与训练预览覆盖层同构，不用 `bindContentCover`）。
 * 关闭出口：点遮罩空白处、点「取消」——**没有 × 按钮**。
 */
import { Context } from '@kit.AbilityKit'
import { MotionTokens } from '../../../common/styles/DesignTokens'
import { PrototypeTokens } from '../../../common/styles/PrototypeTokens'
import { DuTokens } from '../../../common/styles/DuTokens'
import UserProfileService, { WeightUnit } from '../../../common/services/UserProfileService'
import SettingsService from '../../../common/services/SettingsService'
import { kgToDisplay, displayToKg, weightUnitLabel, formatWeight } from '../../../common/utils/WeightUtils'
import { shakeField } from '../../../common/utils/FieldShake'
import { cubicBezier } from '../../../common/utils/Easing'
import { NormPoint, QuadSegment, toSmoothSegments, truncateSegments, tipOf } from '../../../common/utils/SmoothPath'
import BodyRecordService from '../../../shared/services/BodyRecordService'
import { WeightRecord } from '../../../shared/models/BodyModels'

@Component
export struct WeightRecordDialog {
  /** 遮罩：40% 黑（原型「背景压暗到 40%」）。 */
  private static readonly SCRIM_COLOR: string = '#66000000'
  /** 面板不透明中性玻璃面：蒙层之下用半透明白会把首页内容透进面板。 */
  private static readonly CARD_FILL: string = '#13161A'
  /** 面板升起时长（用户指定 0.5s）。 */
  private static readonly PANEL_DURATION: number = 500
  /** 曲线绘制 / 末端数字滚动时长（用户指定 1.2s）。 */
  private static readonly CHART_DURATION: number = 1200
  /** 面板收起时的下移量（覆盖面板高度，保证首帧完全在屏外）。 */
  private static readonly PANEL_OFFSET: number = 560

  /** 图表逻辑视口（与 `ReviewContent.drawWeightChart` 同基准）。 */
  private static readonly VIEW_W: number = 342
  private static readonly VIEW_H: number = 132
  /** 绘图区边界（回顾页同值：x 12–330、y 16–100）。 */
  private static readonly PLOT_X0: number = 12
  private static readonly PLOT_X1: number = 330
  private static readonly PLOT_Y_TOP: number = 16
  private static readonly PLOT_Y_BOTTOM: number = 100
  /** 渐变面积下延基线（回顾页同值）。 */
  private static readonly AREA_BASE_Y: number = 120
  /** 网格横线（回顾页同 4 条）。 */
  private static readonly GRID_ROWS: number[] = [16, 44, 72, 100]
  /** 曲线取最近多少条记录。 */
  private static readonly MAX_POINTS: number = 14

  /** 点遮罩空白 / 「取消」：关闭面板，不进预览。 */
  onCancel?: () => void
  /** 体重已落盘：关闭面板并进入训练预览。 */
  onConfirmed?: () => void

  /** 大数字输入条：**空**，用户手输今日体重（不预填、不被动画覆盖）。 */
  @State private weightInput: string = ''
  @State private displayUnit: WeightUnit = 'kg'
  @State private latestKg: number = 0
  @State private hasRecords: boolean = false
  @State private goalKg: number = 0
  /** 0→1：同时驱动曲线截断与末端数值滚动。 */
  @State @Watch('onProgressChanged') private progress: number = 0
  @State private hint: string = ''
  @State private saving: boolean = false
  @State private shakeOffset: number = 0
  @State private cancelPressed: boolean = false
  @State private confirmPressed: boolean = false
  /** 输入框聚焦：驱动下划线由 76 展开到 96 并提亮（移动端没有 hover，聚焦即「在场」。 */
  @State private inputFocused: boolean = false
  /** 面板入场开关：首帧 false（屏外）→ 置 true 触发位移动画。 */
  @State private panelIn: boolean = false

  private segments: QuadSegment[] = []
  private chartLo: number = 0
  private chartHi: number = 0
  private chartCtx: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true))
  private animTimer: number = -1
  private enterTimer: number = -1

  async aboutToAppear(): Promise<void> {
    const context: Context | null = this.contextOrNull()
    if (context === null) {
      return
    }
    try {
      const profile = await UserProfileService.loadProfile(context)
      this.displayUnit = profile.weightUnit
      const settings = await SettingsService.loadSettings(context)
      this.goalKg = settings.weightGoalKg
      const records: WeightRecord[] = await BodyRecordService.loadRecords(context)
      const latest: number | undefined = BodyRecordService.latestKg(records)
      if (latest !== undefined) {
        this.latestKg = latest
        this.hasRecords = true
        // 用真实记录序列（最近 14 条）：周趋势会前向填充，记录少时整条曲线被铺成平线
        this.segments = this.buildSegments(records)
      }
    } catch (error) {
      // 读不到单位/历史记录时留在空态：用户仍可手输今日体重，不阻断流程。
      this.hint = ''
    }
    this.startEnterAnimation()
    this.startChartAnimation()
  }

  aboutToDisappear(): void {
    if (this.animTimer >= 0) {
      clearInterval(this.animTimer)
      this.animTimer = -1
    }
    if (this.enterTimer >= 0) {
      clearTimeout(this.enterTimer)
      this.enterTimer = -1
    }
  }

  private contextOrNull(): Context | null {
    const host: Context | undefined = this.getUIContext().getHostContext()
    return host === undefined ? null : host
  }

  /**
   * 输入框宽度随内容自适应。
   *
   * ArkUI 的 `TextInput` 默认撑满父宽度——固定宽度时数字在框内居中、单位被推到框右边缘，
   * 两者会离得很远。按 56fp Inter 数字的近似字宽（≈32vp/字符）估宽，空态给 3 字符宽，
   * 保证「数字 + 单位」紧邻。单位间距由自身 `offset` 承担，宽度不再额外留白。
   */
  private inputWidthVp(): number {
    const chars: number = this.weightInput.length > 3 ? this.weightInput.length : 3
    return chars * 32
  }

  /** 下一帧再置 true，保证首帧先以「屏外」位置渲染，位移才有动画。 */
  private startEnterAnimation(): void {
    this.enterTimer = setTimeout(() => {
      this.panelIn = true
      this.enterTimer = -1
    }, 20)
  }

  private startChartAnimation(): void {
    const startAt: number = Date.now()
    this.animTimer = setInterval(() => {
      const elapsed: number = Date.now() - startAt
      const t: number = elapsed >= WeightRecordDialog.CHART_DURATION
        ? 1
        : elapsed / WeightRecordDialog.CHART_DURATION
      this.progress = cubicBezier(t, 0.2, 0.7, 0.2, 1)
      if (t >= 1 && this.animTimer >= 0) {
        clearInterval(this.animTimer)
        this.animTimer = -1
      }
    }, 16)
  }

  onProgressChanged(): void {
    this.drawChart()
  }

  /**
   * 最近 N 条真实记录 → 归一化点列 → 平滑段。
   *
   * 量程并入目标值：保证目标虚线始终落在图内；全等时 span 取 1（单点补原点，
   * 否则 toSmoothSegments 返回空、曲线不画）。
   */
  private buildSegments(records: WeightRecord[]): QuadSegment[] {
    if (records.length === 0) {
      return []
    }
    const start: number = records.length > WeightRecordDialog.MAX_POINTS
      ? records.length - WeightRecordDialog.MAX_POINTS
      : 0
    const values: number[] = []
    for (let i = start; i < records.length; i++) {
      values.push(records[i].kg)
    }
    let lo: number = values[0]
    let hi: number = values[0]
    for (let i = 1; i < values.length; i++) {
      lo = Math.min(lo, values[i])
      hi = Math.max(hi, values[i])
    }
    if (this.goalKg > 0) {
      lo = Math.min(lo, this.goalKg)
      hi = Math.max(hi, this.goalKg)
    }
    this.chartLo = lo
    this.chartHi = hi
    const span: number = hi - lo === 0 ? 1 : hi - lo
    const points: NormPoint[] = []
    if (values.length === 1) {
      points.push({ x: 0, y: 0.92 })
      points.push({ x: 1, y: (hi - values[0]) / span })
      return toSmoothSegments(points)
    }
    for (let i = 0; i < values.length; i++) {
      points.push({ x: i / (values.length - 1), y: (hi - values[i]) / span })
    }
    return toSmoothSegments(points)
  }

  /** 目标线在归一化视口内的 y；无目标 / 无记录 / 越界返回 -1（不画）。 */
  private goalRatio(): number {
    if (this.goalKg <= 0 || !this.hasRecords || this.chartHi <= this.chartLo) {
      return -1
    }
    if (this.goalKg > this.chartHi || this.goalKg < this.chartLo) {
      return -1
    }
    return (this.chartHi - this.goalKg) / (this.chartHi - this.chartLo)
  }

  /** 归一化 x（0..1）→ 逻辑视口 x。 */
  private plotX(nx: number): number {
    return WeightRecordDialog.PLOT_X0 + nx * (WeightRecordDialog.PLOT_X1 - WeightRecordDialog.PLOT_X0)
  }

  /** 归一化 y（0..1，0 = 量程上界）→ 逻辑视口 y。 */
  private plotY(ny: number): number {
    return WeightRecordDialog.PLOT_Y_TOP + ny * (WeightRecordDialog.PLOT_Y_BOTTOM - WeightRecordDialog.PLOT_Y_TOP)
  }

  /** 末端数值：随曲线进度从 0 滚到最新体重（按显示单位 1 位小数）。 */
  private tipLabel(): string {
    if (!this.hasRecords) {
      return ''
    }
    return formatWeight(this.latestKg * this.progress, this.displayUnit)
  }

  private drawChart(): void {
    const ctx: CanvasRenderingContext2D = this.chartCtx
    const width: number = ctx.width
    const height: number = ctx.height
    if (width <= 0 || height <= 0) {
      return
    }
    ctx.clearRect(0, 0, width, height)
    ctx.save()
    // Canvas 由 `aspectRatio(VIEW_W / VIEW_H)` 约束，x/y 同倍率：
    // 曲线形状与回顾页一致，不会被容器高度拉伸。
    ctx.scale(width / WeightRecordDialog.VIEW_W, height / WeightRecordDialog.VIEW_H)

    // 网格先画且与有无数据无关：空态保留坐标系，否则整块是纯黑、看起来像渲染失败
    ctx.strokeStyle = 'rgba(255,255,255,0.06)'
    ctx.lineWidth = 1
    for (let i = 0; i < WeightRecordDialog.GRID_ROWS.length; i++) {
      const rowY: number = WeightRecordDialog.GRID_ROWS[i]
      ctx.beginPath()
      ctx.moveTo(WeightRecordDialog.PLOT_X0, rowY)
      ctx.lineTo(WeightRecordDialog.PLOT_X1, rowY)
      ctx.stroke()
    }

    // 目标水平虚线（右端标目标值）
    const ratio: number = this.goalRatio()
    if (ratio >= 0) {
      const goalY: number = this.plotY(ratio)
      ctx.strokeStyle = 'rgba(255,255,255,0.32)'
      ctx.lineWidth = 1
      ctx.setLineDash([4, 4])
      ctx.beginPath()
      ctx.moveTo(WeightRecordDialog.PLOT_X0, goalY)
      ctx.lineTo(WeightRecordDialog.PLOT_X1, goalY)
      ctx.stroke()
      ctx.setLineDash([])
      // 目标值右对齐到绘图区右缘：不压曲线、不越出画布
      ctx.textAlign = 'right'
      ctx.fillStyle = 'rgba(255,255,255,0.70)'
      ctx.font = '400 13px Inter'
      ctx.fillText(this.goalValueLabel(), WeightRecordDialog.PLOT_X1 - 2, goalY - 8)
      ctx.textAlign = 'left'
    }

    const drawn: QuadSegment[] = truncateSegments(this.segments, this.progress)
    if (drawn.length > 0) {
      const first: QuadSegment = drawn[0]
      const last: QuadSegment = drawn[drawn.length - 1]

      // 渐变面积：取回顾页的面积色，但在小图上收尾到透明，不留一条硬边
      const grad: CanvasGradient = ctx.createLinearGradient(
        0, WeightRecordDialog.PLOT_Y_TOP, 0, WeightRecordDialog.AREA_BASE_Y)
      grad.addColorStop(0, 'rgba(80,236,167,0.12)')
      grad.addColorStop(1, 'rgba(80,236,167,0)')
      ctx.fillStyle = grad
      ctx.beginPath()
      ctx.moveTo(this.plotX(first.from.x), this.plotY(first.from.y))
      for (let i = 0; i < drawn.length; i++) {
        ctx.quadraticCurveTo(
          this.plotX(drawn[i].control.x),
          this.plotY(drawn[i].control.y),
          this.plotX(drawn[i].to.x),
          this.plotY(drawn[i].to.y)
        )
      }
      ctx.lineTo(this.plotX(last.to.x), WeightRecordDialog.AREA_BASE_Y)
      ctx.lineTo(this.plotX(first.from.x), WeightRecordDialog.AREA_BASE_Y)
      ctx.closePath()
      ctx.fill()

      // 曲线
      ctx.strokeStyle = PrototypeTokens.ACCENT
      ctx.lineWidth = 2.5
      ctx.lineCap = 'round'
      ctx.lineJoin = 'round'
      ctx.beginPath()
      ctx.moveTo(this.plotX(first.from.x), this.plotY(first.from.y))
      for (let i = 0; i < drawn.length; i++) {
        ctx.quadraticCurveTo(
          this.plotX(drawn[i].control.x),
          this.plotY(drawn[i].control.y),
          this.plotX(drawn[i].to.x),
          this.plotY(drawn[i].to.y)
        )
      }
      ctx.stroke()

      const tip: NormPoint | undefined = tipOf(drawn)
      if (tip !== undefined) {
        const tipX: number = this.plotX(tip.x)
        const tipY: number = this.plotY(tip.y)
        // 光晕 → 实心点：3px 的点在小图上太弱，加一圈低透明度底色把它点亮
        ctx.fillStyle = 'rgba(80,236,167,0.22)'
        ctx.beginPath()
        ctx.arc(tipX, tipY, 7, 0, Math.PI * 2)
        ctx.fill()
        ctx.fillStyle = PrototypeTokens.ACCENT
        ctx.beginPath()
        ctx.arc(tipX, tipY, 3, 0, Math.PI * 2)
        ctx.fill()
        // 尖端是「最新一条」，永远落在最右侧：数值必须画在内侧，往右画必被画布裁掉
        const onLeft: boolean = tip.x > 0.55
        // 尖端贴近下界时把数值翻到上方：画的是基线，让文字整体压在尖端之上
        const above: boolean = tip.y > 0.6
        ctx.textAlign = onLeft ? 'right' : 'left'
        ctx.fillStyle = PrototypeTokens.ACCENT
        ctx.font = '600 18px Inter'
        ctx.fillText(this.tipLabel(), onLeft ? tipX - 10 : tipX + 10, above ? tipY - 10 : tipY + 6)
        ctx.textAlign = 'left'
      }
    }
    ctx.restore()
  }

  /** 目标标签：按显示单位、整数值（与回顾页口径一致）+ 单位，与 header 同一口径。 */
  private goalValueLabel(): string {
    const display: number = kgToDisplay(this.goalKg, this.displayUnit)
    return Math.round(display).toString() + weightUnitLabel(this.displayUnit).toUpperCase()
  }

  private latestValueLabel(): string {
    if (!this.hasRecords) {
      return ''
    }
    return formatWeight(this.latestKg, this.displayUnit) + weightUnitLabel(this.displayUnit)
  }

  private cancel(): void {
    if (this.saving) {
      return
    }
    if (this.onCancel !== undefined) {
      this.onCancel()
    }
  }

  private async confirm(): Promise<void> {
    if (this.saving) {
      return
    }
    const context: Context | null = this.contextOrNull()
    if (context === null) {
      return
    }
    const parsed: number = Number(this.weightInput)
    // 校验口径按**显示单位**（原型脚本 `v <= 0 || v > 500` 判的是输入值本身）。
    // 旧实现 `parsed <= 0` 混用 `kg > 500`：lbs 下 500 以上的输入会被放行。
    if (this.weightInput.length === 0 || Number.isNaN(parsed) || parsed <= 0 || parsed > 500) {
      this.hint = '请输入 0–500 之间的有效体重'
      shakeField(this.getUIContext(), (value: number) => {
        this.shakeOffset = value
      })
      return
    }
    const kg: number = displayToKg(parsed, this.displayUnit)
    this.saving = true
    await BodyRecordService.addRecord(context, { dateMillis: Date.now(), kg: kg })
    this.saving = false
    if (this.onConfirmed !== undefined) {
      this.onConfirmed()
    }
  }

  /** 顶部抓手：底部面板的惯例 affordance，说明这块是可升起的表层而不是卡片。 */
  @Builder
  private grabber() {
    Row() {
      Row()
        .width(40)
        .height(4)
        .borderRadius(2)
        .backgroundColor(PrototypeTokens.WHITE_A10)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .margin({ bottom: 14 })
  }

  /** 上下文行：标签弱（12 / 0.40）、数值强（13 / 0.87 或强调色）。 */
  @Builder
  private headerRow() {
    Row() {
      Row({ space: 6 }) {
        Text('上一次')
          .fontFamily('Noto Sans SC')
          .fontSize(12)
          .fontColor(PrototypeTokens.WHITE_A40)
        Text(this.hasRecords ? this.latestValueLabel() : '暂无记录')
          .fontFamily('Noto Sans SC')
          .fontSize(13)
          .fontWeight(this.hasRecords ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.hasRecords ? PrototypeTokens.WHITE_A87 : PrototypeTokens.WHITE_A40)
      }
      Blank()
      if (this.goalKg > 0) {
        Row({ space: 6 }) {
          Text('目标')
            .fontFamily('Noto Sans SC')
            .fontSize(12)
            .fontColor(PrototypeTokens.WHITE_A40)
          Text(this.goalValueLabel())
            .fontFamily('Noto Sans SC')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(PrototypeTokens.ACCENT)
        }
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private inputRow() {
    Column() {
      Row({ space: 0 }) {
        TextInput({ text: this.weightInput })
          .type(InputType.NUMBER_DECIMAL)
          .fontFamily('Inter')
          .fontSize(56)
          .fontWeight(FontWeight.Bold)
          .fontColor(PrototypeTokens.TEXT_HI)
          .backgroundColor(Color.Transparent)
          .borderRadius(0)
          .width(this.inputWidthVp())
          .textAlign(TextAlign.Center)
          .padding(0)
          .onFocus(() => {
            this.inputFocused = true
          })
          .onBlur(() => {
            this.inputFocused = false
          })
          .onChange((next: string) => {
            this.weightInput = next
            this.hint = ''
          })
        Text(weightUnitLabel(this.displayUnit).toUpperCase())
          .fontFamily('Inter')
          .fontSize(18)
          .fontColor(PrototypeTokens.WHITE_A65)
          // 单位往右压一点、略微下沉：与 56fp 数字的视觉基线对齐
          .offset({ x: 10, y: 6 })
      }
      .width('100%')
      .height(76)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)

      // 聚焦即展开并提亮：移动端没有 hover，焦点是唯一现成的「在场」通道
      Row()
        .width(this.inputFocused ? 96 : 76)
        .height(2)
        .backgroundColor(PrototypeTokens.ACCENT)
        .opacity(this.inputFocused ? 1 : 0.5)
        .borderRadius(1)
        .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .margin({ top: 6 })
    .translate({ x: this.shakeOffset })
  }

  @Builder
  private chartArea() {
    Canvas(this.chartCtx)
      .width('100%')
      // 等比约束：宽高比锁定回顾页视口，曲线不被容器高度拉伸
      .aspectRatio(WeightRecordDialog.VIEW_W / WeightRecordDialog.VIEW_H)
      .onReady(() => {
        this.drawChart()
      })
      .onAreaChange(() => {
        this.drawChart()
      })
  }

  @Builder
  private actionRow() {
    Row({ space: 12 }) {
      Button('取消')
        .layoutWeight(1)
        .height(48)
        .padding(0)
        .fontFamily('Noto Sans SC')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(PrototypeTokens.TEXT_HI)
        .backgroundColor(PrototypeTokens.WHITE_A06)
        .border({ width: 1, color: PrototypeTokens.WHITE_A10 })
        .borderRadius(16)
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.cancelPressed = true
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.cancelPressed = false
          }
        })
        .opacity(this.saving ? 0.4 : (this.cancelPressed ? 0.6 : 1))
        .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
        .onClick(() => {
          this.cancel()
        })

      Button(this.saving ? '记录中…' : '记录并开始')
        .layoutWeight(1)
        .height(48)
        .padding(0)
        .fontFamily('Noto Sans SC')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(PrototypeTokens.TEXT_ON_ACCENT)
        .backgroundColor(PrototypeTokens.ACCENT)
        .borderRadius(16)
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.confirmPressed = true
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.confirmPressed = false
          }
        })
        // Duolingo 硬边厚底：与首页主 CTA、训练页「完成本组」同一套按压语汇。
        // 落盘中（saving）与按下态一致地「压进去」，让等待有物理反馈而不是静止的亮按钮。
        .border({
          width: { bottom: this.confirmPressed || this.saving ? 0 : DuTokens.PRESS_DEPTH },
          color: { bottom: PrototypeTokens.ACCENT_DEEP }
        })
        .translate({ y: this.confirmPressed || this.saving ? DuTokens.PRESS_SHIFT : 0 })
        .opacity(this.saving ? 0.72 : 1)
        .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
        .onClick(() => {
          this.confirm()
        })
    }
    .width('100%')
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 遮罩：与面板同时长淡入到 40% 黑
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(WeightRecordDialog.SCRIM_COLOR)
        .opacity(this.panelIn ? 1 : 0)
        .animation({ duration: WeightRecordDialog.PANEL_DURATION, curve: MotionTokens.EASE_MOTION })
        .onClick(() => {
          this.cancel()
        })

      // 底部面板：translateY 由屏外升到位
      Column() {
        // 正文卡片：两个按钮不在里面
        Column() {
          this.grabber()
          this.headerRow()
          this.inputRow()
          this.chartArea()
          Text(this.hint)
            .fontFamily('Noto Sans SC')
            .fontSize(12)
            .fontColor(PrototypeTokens.ACCENT)
            .width('100%')
            .height(16)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 12, bottom: 16 })
        .backgroundColor(WeightRecordDialog.CARD_FILL)
        .borderRadius(28)
        .border({ width: 1, color: PrototypeTokens.WHITE_A10 })
        // 吃掉卡片内的空白点击：否则点击会穿透到下层遮罩，把用户输入直接关掉
        .onClick(() => {
        })

        Row().height(16)

        this.actionRow()
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 36 })
      .translate({ y: this.panelIn ? 0 : WeightRecordDialog.PANEL_OFFSET })
      .animation({ duration: WeightRecordDialog.PANEL_DURATION, curve: MotionTokens.EASE_MOTION })
    }
    .width('100%')
    .height('100%')
  }
}
