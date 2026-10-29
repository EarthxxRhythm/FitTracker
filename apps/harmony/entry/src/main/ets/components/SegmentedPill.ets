/**
 * SegmentedPill —— 分段控件：互斥选择 + 选中块滑动。
 *
 * ── 为什么存在 ────────────────────────────────────────────────
 * 改造前，选中态是「每个按钮自己的 backgroundColor 随 selectedKey 互换」。
 * 颜色渐变无法表达位移——起点和终点是两个不同元素，任何时刻都不存在
 * 「一个实体从 A 移动到 B」，视觉上是溶解而不是滑动。
 *
 * 本组件把选中底色从「N 个按钮各自的属性」提升为「1 个独立图层 + 几何量」：
 *
 *   Stack
 *     ├─ 层 1  常底网格（showBaseCells，仅 RPE 十格这类刻度选择器）
 *     ├─ 层 2  滑块（ACCENT，offsetX / width 由纯函数算出，动画到新索引）
 *     └─ 层 3  文字按钮行（透明底，onSelect 回调）
 *
 * 层序不可颠倒：滑块必须在常底之上（遮住格底与格边），在文字之下（不遮字）。
 *
 * ── 几何从哪来 ────────────────────────────────────────────────
 * 全部来自 `common/utils/SegmentGeometry.ets` 的纯函数，与 Android
 * `FtSegmentGeometry.kt` 逐行同构。组件自己不算位置——只负责画。
 * 未测量完成 / 索引越界 / 负宽时纯函数返回零矩形，滑块 `opacity(0)` 隐藏，
 * 避免进入页面时出现「从 0 飞到选中项」的假动画。
 *
 * ── 边界 ─────────────────────────────────────────────────────
 * 只做映射与布局，不持有业务状态：`selectedKey` 由调用方的 `@State` 提供，
 * 组件通过 `onSelect(key)` 请求变更。组件内三个 `@State` 都是测量态
 * （按压键 / 轨道宽 / 逐项实测宽），不承载任何业务语义。
 */

import { MotionTokens } from '../common/styles/DesignTokens'
import { PrototypeTokens } from '../common/styles/PrototypeTokens'
import {
  emptySegmentRect,
  resolveEvenIndicator,
  resolveMeasuredIndicator,
  SegmentRect
} from '../common/utils/SegmentGeometry'

/** 一个分段项：key 是状态值，label 是显示文案。 */
export interface SegmentedPillItem {
  key: string
  label: string
}

export function createSegmentedPillItem(key: string, label: string): SegmentedPillItem {
  const item: SegmentedPillItem = { key: key, label: label }
  return item
}

@Component
export struct SegmentedPill {
  @Prop items: SegmentedPillItem[] = []
  @Prop selectedKey: string = ''
  onSelect?: (key: string) => void

  /** 项高。等分场景与自适应场景同高。 */
  itemHeight: number = 36
  /** 水平内边距——**只作用于自适应场景**（等分场景宽度由容器决定，加了会挤字）。 */
  itemPadH: number = 12
  itemFontSize: number = 13
  /** 选中项字重；未选中固定 500（与原型 600/500 口径一致）。 */
  selectedWeight: number = 600
  /** true = 各项等分铺满；false = 按内容宽（周/月、身体数据页签、趋势周期） */
  fillWidth: boolean = true
  /** 项间距。等分场景表示相邻项之间的空隙；自适应场景同样计入偏移。 */
  itemGap: number = 0
  itemRadius: number = 999
  trackRadius: number = 999
  /** 容器底形态：fill = 填充 + 描边；strokeOnly = 只描边；none = 无容器底。 */
  track: 'fill' | 'strokeOnly' | 'none' = 'none'
  /** 容器填充色（仅在 track = 'fill' 时生效）。默认 WHITE_A05；登录页模式切换用 WHITE_A06。 */
  trackFillColor: string = PrototypeTokens.WHITE_A05
  inactiveColor: string = PrototypeTokens.WHITE_A62
  /** 是否绘制「每项常底」（仅 RPE 十格这类刻度选择器；胶囊分段保持 false）。 */
  showBaseCells: boolean = false
  baseCellFill: string = PrototypeTokens.WHITE_A08
  baseCellBorder: string = PrototypeTokens.WHITE_A08

  /** 按压中的项 key —— 仅用于按压缩放反馈。 */
  @State private pressedKey: string = ''
  /** 等分场景的轨道内容宽（实测，单位 vp）。 */
  @State private trackWidth: number = 0
  /** 自适应场景的逐项实测宽（单位 vp）。 */
  @State private measuredWidths: number[] = []

  // ── 几何 ─────────────────────────────────────────────────────────

  private selectedIndex(): number {
    for (let i = 0; i < this.items.length; i++) {
      if (this.items[i].key === this.selectedKey) {
        return i
      }
    }
    // 找不到（含 sessionRpe = 0「未评价」）→ 隐藏滑块，而不是高亮第一项。
    return -1
  }

  private indicatorRect(): SegmentRect {
    const index: number = this.selectedIndex()
    if (index < 0) {
      return emptySegmentRect()
    }
    if (this.fillWidth) {
      return resolveEvenIndicator(this.items.length, this.trackWidth, this.itemGap, index)
    }
    return resolveMeasuredIndicator(this.measuredWidths, this.itemGap, index)
  }

  /** `Area.width` 声明类型是 Length；运行时按 vp 数字返回，字符串形态兜底解析。 */
  private toVp(value: Length): number {
    if (typeof value === 'number') {
      return value
    }
    if (typeof value === 'string') {
      return parseFloat(value as string)
    }
    return 0
  }

  private trackFill(): string {
    return this.track === 'fill' ? this.trackFillColor : PrototypeTokens.TRANSPARENT
  }

  private trackBorderWidth(): number {
    return this.track === 'none' ? 0 : 1
  }

  // ── 交互 ─────────────────────────────────────────────────────────

  private isSelected(key: string): boolean {
    return this.selectedKey === key
  }

  private notifySelect(key: string): void {
    if (this.isSelected(key)) {
      return
    }
    if (this.onSelect !== undefined) {
      this.onSelect(key)
    }
  }

  private observePress(key: string, event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      this.pressedKey = key
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.pressedKey = ''
    }
  }

  private recordWidth(key: string, width: number): void {
    let index: number = -1
    for (let i = 0; i < this.items.length; i++) {
      if (this.items[i].key === key) {
        index = i
      }
    }
    if (index < 0) {
      return
    }
    const next: number[] = this.measuredWidths.slice()
    next[index] = width
    this.measuredWidths = next
  }

  // ── 局部视图 ─────────────────────────────────────────────────────

  /** 层 2：滑块。width 与 offset 共用一条 animation，保证同时起止。 */
  @Builder
  private slider() {
    Row()
      .width(this.indicatorRect().width)
      .height(this.itemHeight)
      .backgroundColor(PrototypeTokens.ACCENT)
      .borderRadius(this.itemRadius)
      .offset({ x: this.indicatorRect().offsetX })
      .opacity(this.indicatorRect().width > 0 ? 1 : 0)
      .animation({ duration: MotionTokens.DURATION_SEG_SLIDE, curve: MotionTokens.EASE_PANEL })
  }

  /** 层 1：每项常底（仅刻度选择器）。宽度与项一一对应，滑块盖上时自然遮住。 */
  @Builder
  private baseCells() {
    Row({ space: this.itemGap }) {
      ForEach(this.items, (item: SegmentedPillItem) => {
        Row()
          .height(this.itemHeight)
          .layoutWeight(1)
          .backgroundColor(this.baseCellFill)
          .borderRadius(this.itemRadius)
          .border({ width: 1, color: this.baseCellBorder })
      }, (item: SegmentedPillItem) => item.key)
    }
    .width('100%')
  }

  /** 层 3-a：等分按钮行。轨道宽从这一行的 onAreaChange 取（已扣除容器 padding）。 */
  @Builder
  private evenLabels() {
    Row({ space: this.itemGap }) {
      ForEach(this.items, (item: SegmentedPillItem) => {
        Text(item.label)
          .fontFamily('Noto Sans SC')
          .fontSize(this.itemFontSize)
          .fontWeight(this.isSelected(item.key) ? this.selectedWeight : 500)
          .fontColor(this.isSelected(item.key) ? PrototypeTokens.TEXT_ON_ACCENT : this.inactiveColor)
          .textAlign(TextAlign.Center)
          .height(this.itemHeight)
          .layoutWeight(1)
          .scale({
            x: this.pressedKey === item.key ? MotionTokens.PRESS_SEGMENT : 1,
            y: this.pressedKey === item.key ? MotionTokens.PRESS_SEGMENT : 1
          })
          .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
          .onTouch((event: TouchEvent) => {
            this.observePress(item.key, event)
          })
          .onClick(() => {
            this.notifySelect(item.key)
          })
      }, (item: SegmentedPillItem) => item.key)
    }
    .width('100%')
    .onAreaChange((oldArea: Area, newArea: Area) => {
      const width: number = this.toVp(newArea.width)
      if (width !== this.trackWidth) {
        this.trackWidth = width
      }
    })
  }

  /** 层 3-b：自适应按钮行。逐项测宽，几何由累加得出（不是平均宽 × index）。 */
  @Builder
  private fitLabels() {
    Row({ space: this.itemGap }) {
      ForEach(this.items, (item: SegmentedPillItem) => {
        Text(item.label)
          .fontFamily('Noto Sans SC')
          .fontSize(this.itemFontSize)
          .fontWeight(this.isSelected(item.key) ? this.selectedWeight : 500)
          .fontColor(this.isSelected(item.key) ? PrototypeTokens.TEXT_ON_ACCENT : this.inactiveColor)
          .textAlign(TextAlign.Center)
          .height(this.itemHeight)
          .padding({ left: this.itemPadH, right: this.itemPadH })
          .scale({
            x: this.pressedKey === item.key ? MotionTokens.PRESS_SEGMENT : 1,
            y: this.pressedKey === item.key ? MotionTokens.PRESS_SEGMENT : 1
          })
          .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
          .onTouch((event: TouchEvent) => {
            this.observePress(item.key, event)
          })
          .onClick(() => {
            this.notifySelect(item.key)
          })
          .onAreaChange((oldArea: Area, newArea: Area) => {
            // 真机实测：`Area.width` 是**文字内容宽**，不含左右 padding。
            // 滑块要盖住整项（否则选中项的深色字会落到容器底上、看不见），
            // 必须补回两侧内边距。此处若改成含 padding 的口径，滑块会宽出一倍。
            this.recordWidth(item.key, this.toVp(newArea.width) + this.itemPadH * 2)
          })
      }, (item: SegmentedPillItem) => item.key)
    }
  }

  /** 三层内容（常底 / 滑块 / 按钮行）——两个 build 分支共用，只有外层宽度策略不同。 */
  @Builder
  private pillBody() {
    if (this.showBaseCells) {
      this.baseCells()
    }
    this.slider()
    if (this.fillWidth) {
      this.evenLabels()
    } else {
      this.fitLabels()
    }
  }

  build() {
    // ArkUI 没有「条件不设宽度」的修饰符：等分场景必须显式铺满父宽，
    // 自适应场景必须完全不设 width（否则容器撑满、胶囊失去包裹感）。
    // 故两个分支各写一次修饰器链，内容由 pillBody 复用。
    if (this.fillWidth) {
      Stack({ alignContent: Alignment.Start }) {
        this.pillBody()
      }
      .width('100%')
      .padding(this.track === 'none' ? 0 : 3)
      .backgroundColor(this.trackFill())
      .borderRadius(this.trackRadius)
      .border({ width: this.trackBorderWidth(), color: PrototypeTokens.WHITE_A10 })
    } else {
      Stack({ alignContent: Alignment.Start }) {
        this.pillBody()
      }
      .padding(this.track === 'none' ? 0 : 3)
      .backgroundColor(this.trackFill())
      .borderRadius(this.trackRadius)
      .border({ width: this.trackBorderWidth(), color: PrototypeTokens.WHITE_A10 })
    }
  }
}
