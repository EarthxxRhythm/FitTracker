/**
 * 用户旅程的站点元数据 —— 零依赖，供 App.tsx 静态导入。
 * 真正的 composition（吃 Remotion 体积的那个）在 JourneyFilm.tsx 里，走 lazy。
 */

export type JourneyStop = {
  id: string
  /** 时间轴上的短标签 */
  label: string
  /** public 下的设备截图，路径相对站点根 */
  img: string
  title: string
  line: string
}

export const JOURNEY_STOPS: JourneyStop[] = [
  {
    id: 'plan',
    label: '选计划',
    img: '/05-plans.jpg',
    title: '先定下这周怎么练',
    line: '三分化、上下肢、推拉腿，展开就是一套完整计划，启用即用。'
  },
  {
    id: 'today',
    label: '今天',
    img: '/01-home.jpg',
    title: '打开就知道练什么',
    line: '首页直接给出今天的训练，不用每天重新做决定。'
  },
  {
    id: 'train',
    label: '训练',
    img: '/02-training.jpg',
    title: '一组一组记下来',
    line: '重量与次数逐组录入，组间自动计时。中途换动作也不丢已录的分组。'
  },
  {
    id: 'review',
    label: '复盘',
    img: '/04-review.jpg',
    title: '练完立刻看得见',
    line: '周趋势、肌肉分布、动作个人纪录，练完自动汇总成一屏。'
  },
  {
    id: 'body',
    label: '身体',
    img: '/07-body.jpg',
    title: '三个月后回头看',
    line: '体重、围度、体成分单独成线，和训练量放在同一条时间轴上。'
  }
]

/** 每个站点的帧数：78 帧 @30fps ≈ 2.6 秒 */
export const FRAMES_PER_STOP = 78
/** 整段旅程总帧数 */
export const JOURNEY_FRAMES = FRAMES_PER_STOP * JOURNEY_STOPS.length
/** 舞台画布尺寸（横向构图，容得下截图 + 说明） */
export const STAGE_WIDTH = 960
export const STAGE_HEIGHT = 600
