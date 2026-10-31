/**
 * 界面演示的场景元数据 —— 与 Remotion 无关的轻量模块。
 *
 * 单独拆出来是为了代码分割：App.tsx 可以静态导入这些常量（零依赖），
 * 而真正吃体积的 <Player> + composition 走 React.lazy 延迟加载，
 * 首屏不必为页面下半部分的一段演示付出几百 KB。
 */

export type DemoScene = 'plan' | 'train' | 'review' | 'body'

export const SCENE_LABELS: { key: DemoScene; label: string }[] = [
  { key: 'plan', label: '今日训练' },
  { key: 'train', label: '训练执行' },
  { key: 'review', label: '训练回顾' },
  { key: 'body', label: '身体数据' }
]

/** 每个场景的帧长：120 帧 @30fps = 4 秒。 */
export const SCENE_FRAMES = 120

/** 四场景串联的总帧数。 */
export const TOTAL_FRAMES = SCENE_FRAMES * SCENE_LABELS.length

/** composition 的画布尺寸，与手机壳 540:1186 对齐。 */
export const COMP_WIDTH = 540
export const COMP_HEIGHT = 1186
