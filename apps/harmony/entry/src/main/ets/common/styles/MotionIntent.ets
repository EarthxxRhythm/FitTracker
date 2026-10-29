import { MotionTokens } from './DesignTokens'

/** 按压反馈的语义类别：调用方说「这是哪种按钮」，不自己挑缩放系数。 */
export type PressKind = 'cta' | 'card' | 'icon' | 'back' | 'close' | 'chip'

/**
 * 动效意图层。
 *
 * ── 为什么存在 ────────────────────────────────────────────────
 * 本项目同一套按压（0.96 + 120ms + `EASE_MOTION`）在 13+ 处**逐字手写**；遮罩淡入在
 * 4 处出现 160ms / 220ms 两种时长与 `EASE_MOTION` / `Curve.EaseInOut` 两种曲线。
 * 没有这一层时，改一次动效语汇要 grep 全仓逐个改，且必然漏改导致漂移。
 *
 * ── 边界（重要）──────────────────────────────────────────────
 * **只做映射，不封装组件**。调用点仍然是原生的 `.scale()` / `.animation()` /
 * `.transition()`，这里只回答「该用哪个 token」。不引入状态机、不造第二套组件体系——
 * 项目是双端 + 两套 UI 框架，厚抽象会在 ArkUI 与 Compose 之间打架。
 */
export class MotionIntent {

  /** 按压缩放目标值。`card` 与 `chip` 语义相近（0.98 / 0.97），按组件形态取用。 */
  static pressScale(kind: PressKind): number {
    if (kind === 'cta') {
      return MotionTokens.PRESS_PRIMARY
    }
    if (kind === 'chip') {
      return MotionTokens.PRESS_CHIP
    }
    if (kind === 'icon') {
      return MotionTokens.PRESS_ICON
    }
    if (kind === 'back') {
      return MotionTokens.PRESS_BACK
    }
    if (kind === 'close') {
      return MotionTokens.PRESS_CLOSE
    }
    return MotionTokens.PRESS_SHORTCUT
  }

  /** 按压时长（双端同值 120ms，见 `FtMotion.DURATION_PRESS`） */
  static pressDuration(): number {
    return MotionTokens.DURATION_PRESS
  }

  /** 按压曲线 */
  /**
   * 按压回弹曲线：物理弹簧。
   * `SPRING_PRESS` 的既有注释写明它「只用于可中断场景（按压回弹、拖拽松手回位）」——
   * 本方法就是那条注释等待的消费方。注意 `springMotion` 的 duration 不生效，
   * 调用方不要传 duration，时长由物理参数决定。
   */
  static pressSpringCurve(): ICurve {
    return MotionTokens.SPRING_PRESS
  }

  static pressCurve(): ICurve {
    return MotionTokens.EASE_MOTION
  }

  /** 遮罩淡入时长——统一此前 160 / 220 两种取值 */
  static scrimDuration(): number {
    return MotionTokens.DURATION_MODAL_SCRIM
  }

  /** 遮罩曲线——用 Duolingo 线上实测的 ease-out（`cubic-bezier(0.22, 1, 0.36, 1)`）：
   * 淡入需要「起手干脆、收尾缓」，与按压语汇 `EASE_MOTION` 的等速感不同。 */
  static scrimCurve(): ICurve {
    return MotionTokens.EASE_OUT_DUO
  }

  /** 弹层内容进场时长 */
  static panelDuration(): number {
    return MotionTokens.DURATION_MODAL_POP
  }

  /** 弹层内容进场曲线 */
  static panelCurve(): ICurve {
    return MotionTokens.EASE_PANEL
  }

  /**
   * 居中模态弹窗（首页体重 gate）进场曲线：真物理弹簧。
   * 注意 `springMotion` 的 duration 不生效，只接受 curve——调用方不要传 duration。
   */
  static modalEnterCurve(): ICurve {
    return MotionTokens.SPRING_MODAL_IN
  }

  /** 居中模态弹窗进场起始缩放（卡片从该值弹到 1）。 */
  static modalScaleFrom(): number {
    return MotionTokens.MODAL_GATE_SCALE
  }
}
