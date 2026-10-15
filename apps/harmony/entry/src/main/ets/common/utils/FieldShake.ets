/**
 * FieldShake — 表单字段校验失败的「左右抖动」反馈。
 *
 * 为什么是工具函数而不是组件：抖动要作用在调用方自己的容器上，而驱动它的是调用方的
 * `@State` 偏移量（ArkUI 只有状态变化才会重绘 translate）。故本函数只负责「按衰减序列
 * 推状态」，偏移量归调用方持有。
 *
 * 用法（三步）：
 * 1. 组件声明 `@State shakeOffset: number = 0`
 * 2. 容器上挂 `.translate({ x: <有错误时> this.shakeOffset : 0 })`
 *    —— 用「有错误」门控 translate，保证同页多个字段只有出错的那个在动
 * 3. 校验失败分支里调用 `shakeField(this.getUIContext(), (v: number) => { this.shakeOffset = v })`
 *
 * 静默语义：无动画能力的环境（无障碍关闭动画等）下 keyframeAnimateTo 不生效即跳过，
 * 不得影响校验流程本身。
 */
import { UIContext } from '@kit.ArkUI'
import { MotionTokens } from '../styles/DesignTokens'

/** 抖动的衰减序列（单位：SHAKE_AMPLITUDE 的倍数）。首尾均为 0，保证回到原位。 */
const SHAKE_STEPS: number[] = [-1, 1, -0.6, 0.6, 0]

/**
 * 触发一次左右抖动。
 *
 * @param context 组件所在 UIContext（`this.getUIContext()`）
 * @param setOffset 写入调用方偏移状态的回调——必须是调用方的 `@State` 赋值，
 *                  否则 translate 不会重绘。
 */
export function shakeField(context: UIContext, setOffset: (value: number) => void): void {
  const frames: KeyframeState[] = []
  for (let index = 0; index < SHAKE_STEPS.length; index++) {
    const target: number = SHAKE_STEPS[index] * MotionTokens.SHAKE_AMPLITUDE
    frames.push({
      duration: MotionTokens.DURATION_SHAKE_STEP,
      curve: MotionTokens.EASE_MOTION,
      event: () => {
        setOffset(target)
      }
    })
  }
  context.keyframeAnimateTo({ delay: 0 }, frames)
}
