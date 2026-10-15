/**
 * FieldShake — 表单字段校验失败的「左右抖动」反馈。
 *
 * 为什么是工具函数而不是组件：抖动要作用在调用方自己的容器上，而驱动它的是调用方的
 * `@State` 偏移量（ArkUI 只有状态变化才会重绘 translate）。故本函数只负责「按关键帧
 * 序列推状态」，偏移量归调用方持有。
 *
 * 用法（三步）：
 * 1. 组件声明 `@State shakeOffset: number = 0`
 * 2. 容器上挂 `.translate({ x: <有错误时> this.shakeOffset : 0 })`
 *    —— 用「有错误」门控 translate，保证同页多个字段只有出错的那个在动
 * 3. 校验失败分支里调用 `shakeField(this.getUIContext(), (v: number) => { this.shakeOffset = v })`
 *
 * 静默语义：本函数不依赖动画是否真正播放——即使 keyframeAnimateTo 不生效（无动画
 * 能力的环境），也只是一次状态赋值，校验流程本身不受影响。
 * 注：ArkUI 是否有等价于 CSS `prefers-reduced-motion` 的自动降级能力，本文件未做探测
 * 与实测，故不对「系统关闭动画时会自动跳过」作断言。
 */
import { UIContext } from '@kit.ArkUI'
import { MotionTokens } from '../styles/DesignTokens'

/**
 * 抖动的位移序列（单位：SHAKE_AMPLITUDE 的倍数），逐段对应设计给出的 CSS
 * `@keyframes shake`（总 500ms = 10 段 × 50ms）：
 *
 *   10%→-1  20%→+1  30%→-0.8  40%→+0.6  50%→-1
 *   60%→+1  70%→-0.8  80%→+0.6  90%→-0.4  100%→0
 *
 * 注意 50% 处回到满幅 -1——CSS 是「两轮满幅 + 尾部收敛」，不是单向衰减。
 * 末项为 0，保证动画结束回到原位（起点即 0，无需首帧）。
 */
const SHAKE_STEPS: number[] = [-1, 1, -0.8, 0.6, -1, 1, -0.8, 0.6, -0.4, 0]

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
      curve: MotionTokens.EASE_SHAKE,
      event: () => {
        setOffset(target)
      }
    })
  }
  context.keyframeAnimateTo({ delay: 0 }, frames)
}
