/**
 * 用户旅程 —— 设备截图 + Remotion 编排
 *
 * 截图本身是静帧，Remotion 负责让它"走起来"：
 *   - 每一站是一次推拉入场（截图从下方浮起、轻微放大）
 *   - 站与站之间靠 Sequence 切换，底部时间轴同步推进
 *   - 文字比截图晚 6 帧入场，形成"先看到界面，再读到说明"的顺序
 *
 * 为什么这次用真实截图而不是纯 CSS 画界面：旅程讲的是"用户实际看到什么"，
 * 真机像素才有说服力；动画只承担节奏与转场，不假装自己是另一个界面。
 *
 * 时间轴已外置为 Player 的兄弟控件，点击可跳站——composition 内部拿不到 seek，
 * 所以 Timeline 不再是 composition 的一部分，改由 PlayerRef 驱动。
 *
 * 默认导出带 <Player> 的封装，供 App.tsx 走 React.lazy 引入。
 */

import { useEffect, useRef, useState } from 'react'
import { AbsoluteFill, interpolate, Sequence, useCurrentFrame, useVideoConfig } from 'remotion'
import { Player } from '@remotion/player'
import type { PlayerRef } from '@remotion/player'
import {
  FRAMES_PER_STOP,
  JOURNEY_FRAMES,
  JOURNEY_STOPS,
  STAGE_HEIGHT,
  STAGE_WIDTH,
  activeIndexAt,
  localProgressAt
} from './stops'
import type { JourneyStop } from './stops'

const C = {
  bg: '#0B0F0D',
  surface: '#101810',
  line: '#2A3934',
  primary: '#4CECA4',
  text: '#EDF6F2',
  text2: '#A3B3AD',
  text3: '#7A8D85',
  onPrimary: '#09100F'
}

const clamp = (frame: number, from: number, to: number, a = 0, b = 1) =>
  interpolate(frame, [from, to], [a, b], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' })

/** 单站：截图推拉入场 + 说明文字晚一步出现 */
const Stop: React.FC<{ stop: JourneyStop; index: number }> = ({ stop, index }) => {
  const frame = useCurrentFrame()

  const enter = clamp(frame, 0, 22)
  const exit = clamp(frame, FRAMES_PER_STOP - 14, FRAMES_PER_STOP, 0, 1)

  // 注意：这里**不做透明度入场**。Sequence 每站都从 frame 0 开始，
  // 若 opacity 从 0 起，站首会整块空白（实测截图就是空的）。
  // 进入的动感交给位移与缩放，画面任何一帧都有内容。
  const imgY = interpolate(enter, [0, 1], [34, 0])
  const imgScale = interpolate(enter, [0, 1], [0.955, 1])
  const imgLift = interpolate(exit, [0, 1], [0, -26])
  const textOut = interpolate(exit, [0, 1], [0, -18])

  const textIn = clamp(frame, 4, 26)
  const textX = interpolate(textIn, [0, 1], [-26, 0])

  return (
    <AbsoluteFill>
      {/* 左：说明 */}
      <div
        style={{
          position: 'absolute',
          left: 72,
          top: 150,
          width: 380,
          transform: `translateX(${textX}px) translateY(${textOut}px)`,
          opacity: 0.35 + 0.65 * textIn,
          fontFamily: 'system-ui, -apple-system, "HarmonyOS Sans SC", "PingFang SC", sans-serif',
          color: C.text
        }}
      >
        <div
          style={{
            display: 'inline-flex',
            alignItems: 'center',
            gap: 10,
            fontSize: 13,
            fontWeight: 800,
            letterSpacing: 2,
            color: C.primary,
            marginBottom: 18
          }}
        >
          <span
            style={{
              display: 'inline-grid',
              placeItems: 'center',
              width: 26,
              height: 26,
              borderRadius: '50%',
              border: `1px solid ${C.primary}`,
              fontSize: 12
            }}
          >
            {index + 1}
          </span>
          {stop.label}
        </div>

        <div style={{ fontSize: 38, fontWeight: 900, lineHeight: 1.18, letterSpacing: -0.8, marginBottom: 16 }}>
          {stop.title}
        </div>

        <div style={{ fontSize: 16, lineHeight: 1.75, color: C.text2 }}>{stop.line}</div>
      </div>

      {/* 右：设备截图，自带手机壳 */}
      <div
        style={{
          position: 'absolute',
          right: 88,
          top: 40,
          width: 236,
          height: 518,
          borderRadius: 30,
          border: `1px solid ${C.line}`,
          background: C.surface,
          boxShadow: '0 40px 90px -40px rgba(0,0,0,.92), 0 0 70px -34px rgba(76,236,164,.32)',
          overflow: 'hidden',
          transform: `translateY(${imgY + imgLift}px) scale(${imgScale})`,
        }}
      >
        <img
          src={stop.img}
          alt={`${stop.label}界面截图`}
          style={{ width: '100%', height: '100%', objectFit: 'cover', objectPosition: 'top' }}
        />
      </div>
    </AbsoluteFill>
  )
}

/** 主 composition */
export const JourneyFilm: React.FC = () => {
  const { fps } = useVideoConfig()
  const frame = useCurrentFrame()

  // 背景极光跟着整段节奏缓慢漂移，避免画面死板
  const drift = interpolate(frame, [0, JOURNEY_FRAMES], [0, 1], { extrapolateRight: 'clamp' })

  return (
    <AbsoluteFill style={{ background: C.bg }}>
      <AbsoluteFill
        style={{
          background: `radial-gradient(72% 90% at ${18 + drift * 22}% ${8 + drift * 12}%, rgba(76, 236, 164, .10), transparent 62%)`
        }}
      />

      {JOURNEY_STOPS.map((stop, i) => (
        <Sequence key={stop.id} from={i * FRAMES_PER_STOP} durationInFrames={FRAMES_PER_STOP}>
          <Stop stop={stop} index={i} />
        </Sequence>
      ))}

      {/* 站与站之间的细碎节拍：底部一条呼吸线，提示"还在走" */}
      <div
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          bottom: 0,
          height: 2,
          background: `linear-gradient(90deg, transparent, ${C.primary}, transparent)`,
          opacity: 0.25 + 0.25 * Math.sin((frame / fps) * 2)
        }}
      />
    </AbsoluteFill>
  )
}

/** 外置时间轴：兄弟组件，自行订阅帧推进，避免父级每帧重渲染 Player。
 *  帧映射一律消费 stops.ts 的 activeIndexAt / localProgressAt——不内联重算。 */
const Timeline: React.FC<{ playerRef: React.RefObject<PlayerRef | null> }> = ({ playerRef }) => {
  const [frame, setFrame] = useState(0)

  useEffect(() => {
    const player = playerRef.current
    if (!player) return
    const sync = () => setFrame(player.getCurrentFrame())
    player.addEventListener('frameupdate', sync) // 主通道：30fps 平滑
    let alive = true
    let raf = 0
    let timer = 0
    const poll = () => { // 兜底通道：100ms 轮询，跨版本稳定
      if (!alive) return // 卸载守卫：已入队的回调不再续排
      sync()
      timer = window.setTimeout(() => {
        raf = window.requestAnimationFrame(poll)
      }, 100)
    }
    raf = window.requestAnimationFrame(poll)
    return () => {
      alive = false
      player.removeEventListener('frameupdate', sync)
      cancelAnimationFrame(raf)
      clearTimeout(timer) // 双清理：raf 与 timer 都要清，否则卸载后永久轮询
    }
  }, [playerRef])

  const active = activeIndexAt(frame)

  return (
    <div className="journey-timeline" role="tablist" aria-label="旅程站点">
      {JOURNEY_STOPS.map((stop, i) => {
        const p = localProgressAt(frame, i)
        return (
          <button
            key={stop.id}
            type="button"
            role="tab"
            aria-selected={i === active}
            aria-label={`第 ${i + 1} 站：${stop.label}`}
            className={'journey-tab' + (i === active ? ' is-active' : '')}
            onClick={() => {
              setFrame(i * FRAMES_PER_STOP) // 立即反馈，不等事件
              playerRef.current?.seekTo(i * FRAMES_PER_STOP)
            }}
          >
            <span className="journey-tab-bar">
              <i style={{ width: `${p * 100}%` }} />
            </span>
            <span className="journey-tab-label">{stop.label}</span>
          </button>
        )
      })}
    </div>
  )
}

/** 默认导出：带 <Player> 的封装，App.tsx 用 React.lazy 引它 */
export default function JourneyPlayer() {
  const playerRef = useRef<PlayerRef>(null)
  return (
    <div className="journey-wrap">
      <Player
        ref={playerRef}
        component={JourneyFilm}
        durationInFrames={JOURNEY_FRAMES}
        fps={30}
        compositionWidth={STAGE_WIDTH}
        compositionHeight={STAGE_HEIGHT}
        autoPlay
        loop
        controls={false}
        acknowledgeRemotionLicense
        style={{ width: '100%', height: '100%' }}
      />
      <Timeline playerRef={playerRef} />
    </div>
  )
}
