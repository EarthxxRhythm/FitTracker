import { MotionTokens } from './DesignTokens'

/**
 * Duolingo 按钮形态别名。
 *
 * ── 为什么还要这一层 ─────────────────────────────────────────────
 * 厚度常量（`PRESS_DEPTH` / `PRESS_SHIFT`）的**唯一真相在 `MotionTokens`**
 * （它们是按压语汇，与 `PRESS_PRIMARY` 等缩放系数同族）。
 * 本类只做别名转发，让「Duolingo 形态」在调用点保持可读的命名，
 * 不重复定义数值——改厚度只需动 `DesignTokens.ets` 一处。
 *
 * ── 边界 ──────────────────────────────────────────────────────
 * 不持有任何颜色。厚底颜色一律取 `ColorTokens.PRIMARY_PRESSED` 或
 * `PrototypeTokens.ACCENT_DEEP`（同值 `#45C9A1`），配色保持原型基线。
 */
export class DuTokens {
  /** 常态底部实心厚度（vp），转发自 `MotionTokens.PRESS_DEPTH` */
  static readonly PRESS_DEPTH: number = MotionTokens.PRESS_DEPTH

  /** 按下时整体下移量（vp），转发自 `MotionTokens.PRESS_SHIFT` */
  static readonly PRESS_SHIFT: number = MotionTokens.PRESS_SHIFT

  /** 次要按钮的厚底厚度（本档未启用，预留） */
  static readonly PRESS_DEPTH_SOFT: number = 3
}
