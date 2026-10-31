/**
 * 官网「界面」演示 —— 用 Remotion 逐帧合成的 App 界面，不含任何截图。
 *
 * 两种用法：
 *   1) 不传 scene（#gallery 用）：按时间轴自动串联 plan → train → review → body
 *   2) 传 scene（训练闭环用）：固定渲染该场景，内部动效仍按帧推进并循环
 *
 * 配色是与站点令牌同值的本地常量，不依赖页面 CSS 变量继承——Player 可能被
 * 放进任何容器，颜色自己带才不会串味。
 */

import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion'
import { Player } from '@remotion/player'
import type { PlayerRef } from '@remotion/player'
import { COMP_HEIGHT, COMP_WIDTH, SCENE_FRAMES, SCENE_LABELS, TOTAL_FRAMES } from './scenes'
import type { DemoScene } from './scenes'

export type { DemoScene } from './scenes'
export { SCENE_FRAMES, SCENE_LABELS, TOTAL_FRAMES } from './scenes'

const C = {
  bg: '#0E100D',
  surface: '#101810',
  surface2: '#1B2A27',
  line: '#2A3934',
  primary: '#4CECA4',
  primaryDeep: '#45C9A1',
  text: '#EDF6F2',
  text2: '#A3B3AD',
  text3: '#7A8D85',
  onPrimary: '#09100F'
}

const clamp = (frame: number, from: number, to: number, a = 0, b = 1) =>
  interpolate(frame, [from, to], [a, b], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' })

/** 场景通用外壳：状态栏 + 品牌行。 */
const Shell: React.FC<{ title: string; eyebrow?: string; children: React.ReactNode }> = ({
  title,
  eyebrow,
  children
}) => (
  <div
    style={{
      position: 'absolute',
      inset: 0,
      background: `radial-gradient(120% 60% at 50% 0%, #14211c 0%, ${C.bg} 62%)`,
      color: C.text,
      fontFamily: 'system-ui, -apple-system, "HarmonyOS Sans SC", "PingFang SC", sans-serif',
      padding: '34px 30px 30px',
      display: 'flex',
      flexDirection: 'column',
      gap: 20,
      overflow: 'hidden'
    }}
  >
    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 15, fontWeight: 700, opacity: 0.8 }}>
      <span>9:41</span>
      <span style={{ letterSpacing: 2 }}>▮▮▮ ⌁</span>
    </div>

    <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 4 }}>
      <span
        style={{
          width: 22,
          height: 22,
          borderRadius: '50%',
          border: `3px solid ${C.primary}`,
          borderRightColor: 'transparent',
          display: 'inline-block'
        }}
      />
      <span style={{ fontSize: 19, fontWeight: 800 }}>菲特</span>
      <span style={{ fontSize: 13, color: C.text3, fontWeight: 600 }}>FitTracker</span>
    </div>

    {eyebrow ? (
      <div style={{ fontSize: 12, letterSpacing: 2, color: C.primary, fontWeight: 800 }}>{eyebrow}</div>
    ) : null}

    <div style={{ fontSize: 30, fontWeight: 900, letterSpacing: -0.6, lineHeight: 1.15 }}>{title}</div>

    {children}
  </div>
)

const card: React.CSSProperties = {
  background: C.surface,
  border: `1px solid ${C.line}`,
  borderRadius: 20,
  padding: 18
}

/** 场景 1：今日训练 —— 卡片与动作行依次入场。 */
const PlanScene: React.FC<{ frame: number; fps: number }> = ({ frame, fps }) => {
  const rows = [
    { name: '杠铃推举', detail: '4 组 × 8-12 次', done: true },
    { name: '哑铃侧平举', detail: '3 组 × 12-15 次', done: false },
    { name: '绳索下压', detail: '3 组 × 12-15 次', done: false }
  ]

  const cardIn = spring({ frame, fps, config: { damping: 200 } })
  const barFill = clamp(frame, 12, 60, 0, 0.42)

  return (
    <Shell title="今天练肩" eyebrow="今日训练">
      <div
        style={{
          ...card,
          opacity: cardIn,
          transform: `translateY(${interpolate(cardIn, [0, 1], [22, 0])}px)`
        }}
      >
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
          <span style={{ fontSize: 16, fontWeight: 800 }}>五分化 · 第 4 天</span>
          <span style={{ fontSize: 11, color: C.text3, fontWeight: 700 }}>本周 1 / 5</span>
        </div>
        <div style={{ height: 6, borderRadius: 3, background: C.surface2, overflow: 'hidden' }}>
          <div style={{ width: `${barFill * 100}%`, height: '100%', background: C.primary, borderRadius: 3 }} />
        </div>
        <div style={{ marginTop: 12, fontSize: 12, color: C.text3 }}>肩部 · 3 个动作 · 预计 38 分钟</div>
      </div>

      <div style={{ display: 'grid', gap: 10, marginTop: 4 }}>
        {rows.map((row, i) => {
          const enter = spring({ frame: frame - 16 - i * 7, fps, config: { damping: 200 } })
          return (
            <div
              key={row.name}
              style={{
                ...card,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                borderRadius: 16,
                padding: '14px 16px',
                opacity: enter,
                transform: `translateX(${interpolate(enter, [0, 1], [16, 0])}px)`
              }}
            >
              <div>
                <div style={{ fontSize: 15, fontWeight: 800 }}>{row.name}</div>
                <div style={{ fontSize: 12, color: C.text3, marginTop: 3 }}>{row.detail}</div>
              </div>
              <span
                style={{
                  width: 26,
                  height: 26,
                  borderRadius: '50%',
                  border: `2px solid ${row.done ? C.primary : C.line}`,
                  background: row.done ? C.primary : 'transparent',
                  color: row.done ? C.onPrimary : C.text3,
                  display: 'grid',
                  placeItems: 'center',
                  fontSize: 13,
                  fontWeight: 900
                }}
              >
                {row.done ? '✓' : ''}
              </span>
            </div>
          )
        })}
      </div>

      <div
        style={{
          marginTop: 'auto',
          background: C.primary,
          color: C.onPrimary,
          borderRadius: 16,
          padding: '16px 0',
          textAlign: 'center',
          fontSize: 16,
          fontWeight: 900,
          opacity: clamp(frame, 44, 64)
        }}
      >
        开始训练
      </div>
    </Shell>
  )
}

/** 场景 2：训练执行 —— 组次输入 + 组间计时环走完一整圈。 */
const TrainScene: React.FC<{ frame: number; fps: number }> = ({ frame, fps }) => {
  const enter = spring({ frame, fps, config: { damping: 200 } })
  const rest = clamp(frame, 20, 112) // 0 → 1 的休息进度
  const radius = 88
  const circumference = 2 * Math.PI * radius

  return (
    <Shell title="哑铃侧平举" eyebrow="训练中 · 第 2 个动作">
      <div style={{ display: 'grid', gap: 14, marginTop: 4 }}>
        <div
          style={{
            ...card,
            display: 'grid',
            gridTemplateColumns: '1fr 1fr',
            gap: 14,
            marginTop: 6,
            opacity: enter
          }}
        >
          {[
            { k: '重量', v: '12', unit: 'kg' },
            { k: '次数', v: '12', unit: '次' }
          ].map((item, i) => (
            <div
              key={item.k}
              style={{
                background: C.surface2,
                borderRadius: 14,
                padding: '14px 12px',
                opacity: clamp(frame, 4 + i * 4, 16 + i * 4)
              }}
            >
              <div style={{ fontSize: 11, color: C.text3, fontWeight: 700 }}>{item.k}</div>
              <div style={{ fontSize: 34, fontWeight: 900, letterSpacing: -1, marginTop: 2 }}>
                {item.v}
                <span style={{ fontSize: 13, fontWeight: 700, color: C.text3, marginLeft: 4 }}>{item.unit}</span>
              </div>
            </div>
          ))}
        </div>

        <div style={{ display: 'grid', placeItems: 'center', marginTop: 6 }}>
          <svg width={210} height={210} style={{ transform: 'rotate(-90deg)' }}>
            <circle cx={105} cy={105} r={radius} fill="none" stroke={C.surface2} strokeWidth={10} />
            <circle
              cx={105}
              cy={105}
              r={radius}
              fill="none"
              stroke={C.primary}
              strokeWidth={10}
              strokeLinecap="round"
              strokeDasharray={circumference}
              strokeDashoffset={circumference * rest}
            />
          </svg>
          <div style={{ marginTop: -128, textAlign: 'center' }}>
            <div style={{ fontSize: 11, color: C.text3, fontWeight: 700, letterSpacing: 2 }}>组间休息</div>
            <div style={{ fontSize: 40, fontWeight: 900, letterSpacing: -1.5 }}>
              {Math.max(0, Math.ceil(90 * (1 - rest)))}
              <span style={{ fontSize: 14, color: C.text3, marginLeft: 3 }}>s</span>
            </div>
          </div>
        </div>

        <div style={{ display: 'flex', gap: 10, marginTop: 78 }}>
          {['已记录 3 组', '本组 12 次'].map((t) => (
            <div
              key={t}
              style={{
                flex: 1,
                textAlign: 'center',
                fontSize: 12,
                fontWeight: 700,
                color: C.text2,
                background: C.surface,
                border: `1px solid ${C.line}`,
                borderRadius: 12,
                padding: '10px 0'
              }}
            >
              {t}
            </div>
          ))}
        </div>
      </div>

      <div
        style={{
          marginTop: 'auto',
          background: C.primaryDeep,
          color: C.onPrimary,
          borderRadius: 16,
          padding: '16px 0',
          textAlign: 'center',
          fontSize: 16,
          fontWeight: 900
        }}
      >
        完成本组
      </div>
    </Shell>
  )
}

/** 场景 3：训练回顾 —— 折线逐段绘制 + 肌群格子依次点亮。 */
const ReviewScene: React.FC<{ frame: number }> = ({ frame }) => {
  const pathLength = clamp(frame, 12, 76)
  const cells = Array.from({ length: 18 }, (_, i) => i)
  const hot = new Set([0, 2, 4, 7, 9, 10, 13, 15])

  return (
    <Shell title="这周练得怎么样" eyebrow="训练回顾">
      <div style={{ ...card, marginTop: 4 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 10 }}>
          <span style={{ fontSize: 14, fontWeight: 800 }}>训练量趋势</span>
          <span style={{ fontSize: 11, color: C.primary, fontWeight: 800 }}>↑ 12%</span>
        </div>
        <svg width="100%" height={120} viewBox="0 0 420 120" preserveAspectRatio="none">
          <path
            d="M 10 96 L 78 74 L 146 84 L 214 46 L 282 58 L 350 26 L 410 34"
            fill="none"
            stroke={C.primary}
            strokeWidth={3}
            strokeLinecap="round"
            strokeLinejoin="round"
            pathLength={1}
            strokeDasharray={1}
            strokeDashoffset={1 - pathLength}
          />
          <path
            d="M 10 96 L 78 74 L 146 84 L 214 46 L 282 58 L 350 26 L 410 34 L 410 120 L 10 120 Z"
            fill="rgba(76, 236, 164, 0.12)"
            opacity={pathLength}
          />
        </svg>
      </div>

      <div style={{ ...card }}>
        <div style={{ fontSize: 14, fontWeight: 800, marginBottom: 12 }}>肌肉分布</div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: 6 }}>
          {cells.map((i) => {
            const on = hot.has(i)
            const light = on ? clamp(frame, 20 + i * 2, 34 + i * 2) : 1
            return (
              <div
                key={i}
                style={{
                  height: 30,
                  borderRadius: 7,
                  background: on ? C.primary : C.surface2,
                  opacity: on ? 0.25 + light * 0.75 : 0.5,
                  border: `1px solid ${on ? C.primary : C.line}`
                }}
              />
            )
          })}
        </div>
        <div style={{ marginTop: 12, fontSize: 11, color: C.text3 }}>颜色越亮，这周练得越多</div>
      </div>
    </Shell>
  )
}

/** 场景 4：身体数据 —— 数字滚动 + 体重折线。 */
const BodyScene: React.FC<{ frame: number }> = ({ frame }) => {
  const kg = interpolate(clamp(frame, 8, 56), [0, 1], [68, 72.5])
  const pathLength = clamp(frame, 24, 88)

  return (
    <Shell title="身体数据" eyebrow="体重与目标">
      <div style={{ ...card, marginTop: 4 }}>
        <div style={{ fontSize: 12, color: C.text3, fontWeight: 700 }}>当前体重</div>
        <div style={{ fontSize: 62, fontWeight: 900, letterSpacing: -2.5, lineHeight: 1.1 }}>
          {kg.toFixed(1)}
          <span style={{ fontSize: 18, color: C.text3, marginLeft: 6, fontWeight: 700 }}>kg</span>
        </div>
        <div style={{ fontSize: 12, color: C.primary, fontWeight: 800 }}>↓ 较上月 −1.9 kg</div>
      </div>

      <div style={{ ...card }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
          <span style={{ fontSize: 13, fontWeight: 800 }}>近 30 天</span>
          <span style={{ fontSize: 11, color: C.text3 }}>目标 74.0 kg</span>
        </div>
        <svg width="100%" height={132} viewBox="0 0 420 132" preserveAspectRatio="none">
          <path
            d="M 10 40 L 80 62 L 150 50 L 220 88 L 290 74 L 360 96 L 410 90"
            fill="none"
            stroke={C.primary}
            strokeWidth={3}
            strokeLinecap="round"
            strokeLinejoin="round"
            pathLength={1}
            strokeDasharray={1}
            strokeDashoffset={1 - pathLength}
          />
          <line x1="10" y1="22" x2="410" y2="22" stroke={C.line} strokeWidth={1.5} strokeDasharray="6 6" />
        </svg>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10 }}>
        {[
          { k: '骨骼肌', v: '32.1' },
          { k: '体脂', v: '15.8%' },
          { k: 'BMI', v: '22.4' }
        ].map((item, i) => (
          <div
            key={item.k}
            style={{
              ...card,
              borderRadius: 14,
              padding: 12,
              opacity: clamp(frame, 40 + i * 5, 54 + i * 5)
            }}
          >
            <div style={{ fontSize: 10, color: C.text3, fontWeight: 700 }}>{item.k}</div>
            <div style={{ fontSize: 18, fontWeight: 900, marginTop: 2 }}>{item.v}</div>
          </div>
        ))}
      </div>
    </Shell>
  )
}

/**
 * 主 composition。
 * 传 scene 时锁定该场景（帧仍在走，动效循环）；不传时按时间轴串联四场景。
 */
export const AppDemo: React.FC<{ scene?: DemoScene }> = ({ scene }) => {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()

  const fixedIndex = scene ? SCENE_LABELS.findIndex((s) => s.key === scene) : -1
  const activeKey: DemoScene =
    fixedIndex >= 0
      ? SCENE_LABELS[fixedIndex].key
      : SCENE_LABELS[Math.min(Math.floor(frame / SCENE_FRAMES), SCENE_LABELS.length - 1)].key
  // 场景内相对帧：固定场景时用取模，保证动效每 4 秒重来一遍
  const local = fixedIndex >= 0 ? frame % SCENE_FRAMES : frame % SCENE_FRAMES

  return (
    <AbsoluteFill style={{ background: C.bg }}>
      {activeKey === 'plan' && <PlanScene frame={local} fps={fps} />}
      {activeKey === 'train' && <TrainScene frame={local} fps={fps} />}
      {activeKey === 'review' && <ReviewScene frame={local} />}
      {activeKey === 'body' && <BodyScene frame={local} />}
    </AbsoluteFill>
  )
}

/**
 * 默认导出：带 <Player> 的完整演示组件。
 * App.tsx 用 React.lazy 引它，让 Remotion 只在这段进入视口时才加载。
 */
export interface ScenePlayerProps {
  scene?: DemoScene
  durationInFrames?: number
  ref?: React.Ref<PlayerRef>
}

export default function ScenePlayer({ scene, durationInFrames = TOTAL_FRAMES, ref }: ScenePlayerProps) {
  return (
    <Player
      ref={ref}
      component={AppDemo}
      inputProps={scene ? { scene } : {}}
      durationInFrames={durationInFrames}
      fps={30}
      compositionWidth={COMP_WIDTH}
      compositionHeight={COMP_HEIGHT}
      autoPlay
      loop
      controls={false}
      acknowledgeRemotionLicense
      style={{ width: '100%', height: '100%' }}
    />
  )
}
