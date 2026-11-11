/**
 * 用户旅程的站点元数据 —— 零依赖，供 App.tsx 静态导入。
 * 真正的 composition（吃 Remotion 体积的那个）在 JourneyFilm.tsx 里，走 lazy。
 */

/**
 * 站点基路径。`vite.config.ts` 里 `base: './'`，构建后为 `./`：
 * - 部署在根域（earthrhythm.cloud）时解析成 `/05-plans.jpg`
 * - 部署在子路径（github.io/FitTracker/）时解析成 `/FitTracker/05-plans.jpg`
 * 直接写 `/05-plans.jpg` 会在子路径部署下 404（图片全丢、布局塌陷）。
 */
const BASE = import.meta.env.BASE_URL

export type JourneyStop = {
  id: string
  /** 时间轴上的短标签 */
  label: string
  /** public 下的设备截图，路径经 BASE 拼接，勿写死前导斜杠 */
  img: string
  title: string
  line: string
}

export const JOURNEY_STOPS: JourneyStop[] = [
  {
    id: 'plan',
    label: '选计划',
    img: `${BASE}05-plans.jpg`,
    title: '先定下这周怎么练',
    line: '三分化、上下肢、推拉腿，展开就是一套完整计划，启用即用。'
  },
  {
    id: 'today',
    label: '今天',
    img: `${BASE}01-home.jpg`,
    title: '打开就知道练什么',
    line: '首页直接给出今天的训练，不用每天重新做决定。'
  },
  {
    id: 'train',
    label: '训练',
    img: `${BASE}02-training.jpg`,
    title: '一组一组记下来',
    line: '重量与次数逐组录入，组间自动计时。中途换动作也不丢已录的分组。'
  },
  {
    id: 'library',
    label: '动作库',
    img: `${BASE}06-library.jpg`,
    title: '想换动作，先看一眼怎么做',
    line: '102 个动作按部位与肌群筛选，每个都有演示与要点；常练的收起来，下次直接翻。'
  },
  {
    id: 'review',
    label: '复盘',
    img: `${BASE}04-review.jpg`,
    title: '练完立刻看得见',
    line: '周趋势、肌肉分布、动作个人纪录，练完自动汇总成一屏。'
  },
  {
    id: 'body',
    label: '身体',
    img: `${BASE}07-body.jpg`,
    title: '三个月后回头看',
    line: '体重、围度、体成分单独成线，和训练量放在同一条时间轴上。'
  },
  {
    id: 'profile',
    label: '资料',
    img: `${BASE}08-profile.jpg`,
    title: '换机也不丢，记录跟着账号走',
    line: '头像与资料在线编辑，登录后整包快照同步到云端。'
  }
]

/** 每个站点的帧数：78 帧 @30fps ≈ 2.6 秒 */
export const FRAMES_PER_STOP = 78
/** 整段旅程总帧数 */
export const JOURNEY_FRAMES = FRAMES_PER_STOP * JOURNEY_STOPS.length
/** 舞台画布尺寸（横向构图，容得下截图 + 说明） */
export const STAGE_WIDTH = 960
export const STAGE_HEIGHT = 600

/** 帧 → 当前站下标（越界 clamp 到首尾站） */
export const activeIndexAt = (frame: number): number =>
  Math.min(Math.max(Math.floor(frame / FRAMES_PER_STOP), 0), JOURNEY_STOPS.length - 1)

/** 帧 → 第 i 站进度 0..1：已过站=1、未到站=0、当前站=站内帧比例 */
export const localProgressAt = (frame: number, i: number): number => {
  const active = activeIndexAt(frame)
  if (i < active) return 1
  if (i > active) return 0
  const inStop = frame - active * FRAMES_PER_STOP
  return Math.min(Math.max(inStop / FRAMES_PER_STOP, 0), 1)
}
