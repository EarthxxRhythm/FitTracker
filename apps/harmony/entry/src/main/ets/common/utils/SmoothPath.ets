/**
 * SmoothPath —— 把折线点列转成平滑的二次贝塞尔段序列，并支持按进度截断。
 *
 * 为什么需要：体重弹窗的入场动画要求「曲线从原点画到末点」，而 Canvas 只能整条
 * `stroke`。折线按点截断简单但折角生硬；本文件用中点法把折线平滑成独立二次贝塞尔段，
 * 每段截断有 de Casteljau 闭式解，既平滑又能逐帧截断。
 *
 * 坐标系：所有点均为**归一化坐标**（0..1），与 Canvas 实际像素尺寸解耦——
 * 调用方画的时候再乘宽高。
 */

/** 归一化坐标点（0..1）。 */
export interface NormPoint {
  x: number
  y: number
}

/** 一段二次贝塞尔：起点 / 控制点 / 终点，全部归一化。 */
export interface QuadSegment {
  from: NormPoint
  control: NormPoint
  to: NormPoint
}

function midpoint(a: NormPoint, b: NormPoint): NormPoint {
  return { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 }
}

/**
 * 折线点列 → 平滑的二次贝塞尔段序列（中点法）。
 *
 * 段 i 的终点取 `mid(P[i], P[i+1])`、控制点取 `P[i]`；首段起点用 `P[0]`、
 * 末段终点直接收在 `P[n-1]`。曲线在每个数据点处切线连续。
 *
 * 点数 < 2 时返回空数组（无可画曲线）。
 */
export function toSmoothSegments(points: NormPoint[]): QuadSegment[] {
  const out: QuadSegment[] = []
  if (points.length < 2) {
    return out
  }
  let from: NormPoint = points[0]
  for (let i = 0; i < points.length - 1; i++) {
    const control: NormPoint = points[i]
    const to: NormPoint = i === points.length - 2
      ? points[points.length - 1]
      : midpoint(points[i], points[i + 1])
    out.push({ from: from, control: control, to: to })
    from = to
  }
  return out
}

/**
 * 按进度 [p]（0..1）截断段序列。
 *
 * 返回「已完成的段」+「最后一段在 t 处的部分曲线」。部分曲线用 de Casteljau
 * 在 t 处分段并取第一段：
 *   C' = P0 + t(C - P0)
 *   P1' = (1-t)²P0 + 2(1-t)tC + t²P1
 *
 * `p <= 0` 返回空；`p >= 1` 返回全部段。
 */
export function truncateSegments(segments: QuadSegment[], p: number): QuadSegment[] {
  if (segments.length === 0 || p <= 0) {
    return []
  }
  if (p >= 1) {
    return segments
  }
  const span: number = segments.length * p
  const full: number = Math.floor(span)
  const frac: number = span - full
  const out: QuadSegment[] = []
  for (let i = 0; i < full && i < segments.length; i++) {
    out.push(segments[i])
  }
  if (full < segments.length && frac > 0) {
    const seg: QuadSegment = segments[full]
    const inv: number = 1 - frac
    const control: NormPoint = {
      x: seg.from.x + (seg.control.x - seg.from.x) * frac,
      y: seg.from.y + (seg.control.y - seg.from.y) * frac
    }
    const end: NormPoint = {
      x: inv * inv * seg.from.x + 2 * inv * frac * seg.control.x + frac * frac * seg.to.x,
      y: inv * inv * seg.from.y + 2 * inv * frac * seg.control.y + frac * frac * seg.to.y
    }
    out.push({ from: seg.from, control: control, to: end })
  }
  return out
}

/** 曲线尖端（截断后的终点）；空序列返回 undefined。 */
export function tipOf(segments: QuadSegment[]): NormPoint | undefined {
  if (segments.length === 0) {
    return undefined
  }
  return segments[segments.length - 1].to
}
