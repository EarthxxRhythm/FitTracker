/**
 * SegmentGeometry —— 分段控件「选中块」几何计算的纯函数层。
 *
 * ── 为什么存在 ────────────────────────────────────────────────
 * 分段控件的滑动指示器需要一个矩形：横向偏移 `offsetX` 与宽度 `width`。
 * 这两个量只取决于「项数 / 各项宽度 / 间距 / 选中索引」，与 ArkUI 渲染无关。
 * 把它们从组件里剥出来有三个好处：
 * 1. 双端（ArkUI / Compose）共用同一套公式——`FtSegmentGeometry.kt` 是逐行同构实现；
 * 2. 能在 JVM 上单测（Android 侧 `FtSegmentGeometryTest.kt` 覆盖同一组用例）；
 * 3. 组件只负责「把纯函数的结果画出来」，不负责算。
 *
 * ── 边界约定 ─────────────────────────────────────────────────
 * 任何无法确定的情况（未测量完成、索引越界、算得负宽）一律返回零矩形
 * （`offsetX = 0, width = 0`）。调用方据此隐藏指示器——**不要**返回「其实也对」
 * 的近似值，否则进入页面时会出现滑块从 0 飞到选中项的假动画。
 */

/** 指示器矩形，单位与调用方坐标一致（ArkUI 为 vp，Compose 为 px）。 */
export interface SegmentRect {
  offsetX: number
  width: number
}

/** 零矩形：表示「几何还不可知」，调用方应隐藏指示器。 */
export function emptySegmentRect(): SegmentRect {
  const rect: SegmentRect = { offsetX: 0, width: 0 }
  return rect
}

/**
 * 等分场景：n 项等宽铺满 `trackWidth`，相邻项间隔 `gap`。
 *
 * 约束 `offsetX(n-1) + width === trackWidth` 恒成立——即最后一项的右边缘正好落在
 * 轨道右边缘（n 项宽 + (n-1) 个间隔 = 轨道宽）。
 */
export function resolveEvenIndicator(n: number, trackWidth: number, gap: number, index: number): SegmentRect {
  if (n <= 0 || index < 0 || index >= n || trackWidth <= 0) {
    return emptySegmentRect()
  }
  const width: number = (trackWidth - gap * (n - 1)) / n
  if (width <= 0) {
    return emptySegmentRect()
  }
  const rect: SegmentRect = { offsetX: (width + gap) * index, width: width }
  return rect
}

/**
 * 自适应场景：各项宽度由内容决定（逐项实测），`itemWidths[i]` 为第 i 项宽度。
 *
 * 偏移是前序项宽与间距的累加——不能用「平均宽 × index」近似，
 * 否则「体重 / 围度与体成分 / 身体档案」这类不等宽分段会错位。
 */
export function resolveMeasuredIndicator(itemWidths: number[], gap: number, index: number): SegmentRect {
  if (index < 0 || index >= itemWidths.length) {
    return emptySegmentRect()
  }
  const width: number = itemWidths[index]
  if (width <= 0) {
    return emptySegmentRect()
  }
  let offsetX: number = 0
  for (let i = 0; i < index; i++) {
    const itemWidth: number = itemWidths[i]
    if (itemWidth <= 0) {
      // 尚有项未测量完成：整体几何不可信，隐藏而不是画在半路。
      return emptySegmentRect()
    }
    offsetX += itemWidth + gap
  }
  const rect: SegmentRect = { offsetX: offsetX, width: width }
  return rect
}
