/**
 * cubic-bezier 求值（等价 CSS `cubic-bezier(x1,y1,x2,y2)`）。
 *
 * 为什么需要：ArkUI 的 `curves.cubicBezierCurve(...)` 只能交给动画 API，
 * 而 Canvas 重绘需要「给时间比例 t，反解出进度值」。本文件与
 * `MotionTokens.EASE_MOTION = (0.2, 0.7, 0.2, 1)` 逐值等价，供逐帧渲染使用。
 *
 * 求参用二分：x 轴控制点均在 [0,1] 时曲线在 x 上单调，20 次迭代精度远优于 1e-6。
 */

/** 单轴贝塞尔分量（三次，端点固定为 0 / 1）。 */
function bezierAxis(s: number, p1: number, p2: number): number {
  const inv: number = 1 - s
  return 3 * inv * inv * s * p1 + 3 * inv * s * s * p2 + s * s * s
}

/**
 * 给定时间比例 [t]（0..1），返回缓动后的进度值。
 *
 * 参数 `(x1, y1, x2, y2)` 与 CSS `cubic-bezier(...)` 四值一一对应。
 */
export function cubicBezier(t: number, x1: number, y1: number, x2: number, y2: number): number {
  if (t <= 0) {
    return 0
  }
  if (t >= 1) {
    return 1
  }
  let lo: number = 0
  let hi: number = 1
  let s: number = t
  for (let i = 0; i < 20; i++) {
    s = (lo + hi) / 2
    if (bezierAxis(s, x1, x2) < t) {
      lo = s
    } else {
      hi = s
    }
  }
  return bezierAxis(s, y1, y2)
}
