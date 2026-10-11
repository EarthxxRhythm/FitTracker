/**
 * CanvasScale —— 原型固定画布的响应式缩放口径（430 宽设计画布）。
 *
 * 背景：auth / training-complete / welcome 三组原型使用 430×900（training-complete 为
 *       930.6）固定画布 × SCALE = 0.90698，屏内元素绝对定位。
 *       该定值 = 390 / 430，即「设计基准 390vp 屏」下的等比缩放假设
 *       （见 docs/prototype/opendesign-1to1-rules.md 第 17 条：设计基准 390×844 vp）。
 *       把它硬编码进 ArkUI，会在逻辑宽 ≠ 390vp 的设备上出问题：
 *         窄屏（< 390vp）内容右边缘溢出被裁；宽屏两侧留白。
 *       规则第 19 条要求「宽度 320–430 vp 竖屏：页面不横向溢出」。
 *
 * 口径：scale = 实际屏宽(vp) / 430。
 *   - 390vp 基准屏 → 0.90698（与原硬编码值一致，基准还原不变）
 *   - 窄屏（360/320vp）→ 自动缩小，不溢出
 *   - 宽屏（440vp 等）→ 铺满，不再留白
 *
 * 用法（页面只需两处）：导入后把固定值替换为 currentCanvasScale(this.getUIContext())。
 */

import { display, UIContext } from '@kit.ArkUI'

/** 设计画布宽度（vp）。三个固定画布页面共用。 */
export const CANVAS_WIDTH_VP: number = 430

/** 设计基准屏（390vp）下的缩放系数 = 390 / 430 ≈ 0.90698 —— 原硬编码值，兼作兜底。 */
export const CANVAS_BASE_SCALE: number = 390 / CANVAS_WIDTH_VP

/** 由实际可用宽度（vp）解析画布缩放系数；宽度无效时回落基准值。 */
export function resolveCanvasScale(widthVp: number): number {
  if (!(widthVp > 0)) {
    return CANVAS_BASE_SCALE
  }
  return widthVp / CANVAS_WIDTH_VP
}

let cachedScale: number = 0

/**
 * 当前设备的画布缩放系数（模块级缓存，进程内只解析一次）。
 *
 * 取的是默认显示的物理宽度并经 px2vp 换算；竖屏全屏场景下等于页面可用宽度。
 * 缓存是有意的：build() 可能多次求值，而屏幕宽度在会话内不变
 * （若后续需要支持折叠态/分屏热切换，改为存入 @State 并在 onAreaChange 更新）。
 */
export function currentCanvasScale(uiContext: UIContext): number {
  if (cachedScale > 0) {
    return cachedScale
  }
  try {
    const screen: display.Display = display.getDefaultDisplaySync()
    cachedScale = resolveCanvasScale(uiContext.px2vp(screen.width))
  } catch (error) {
    cachedScale = CANVAS_BASE_SCALE
  }
  return cachedScale
}
