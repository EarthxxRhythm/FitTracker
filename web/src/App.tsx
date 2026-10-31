import { lazy, Suspense, useEffect, useState } from 'react'
import { motion, useReducedMotion, useScroll, useSpring } from 'framer-motion'
import Aurora from './components/Aurora'
import PointerFx from './components/PointerFx'
import { JOURNEY_STOPS } from './journey/stops'

// 旅程动画（截图 + Remotion 编排）体量约 360 kB，走 lazy：
// 这一段在页面中部，不该阻塞首屏。
const JourneyPlayer = lazy(() => import('./journey/JourneyFilm'))

/* ============================================================================
   官网主体
   ----------------------------------------------------------------------------
   四段，每段一种视觉语法，避免「一节接一节长得一样」：
     Hero（单列居中大字）→ 功能（2×2 能力卡）
     → 肌群（整块亮绿 + 矩阵）→ 成长（竖向时间轴）

   动效分工：
     - 滚动进度条：framer-motion useScroll + useSpring（替代手写 rAF）
     - 区块入场：motion whileInView（替代 IntersectionObserver）
     - 其余微动效仍在 legacy.css（CSS transition，零 JS 成本）
   ========================================================================== */

const GITHUB = 'https://github.com/EarthxxRhythm/FitTracker'

const BRAND_RING = (
  <svg viewBox="0 0 24 24" aria-hidden="true">
    <path
      d="M 18.527 5.473 A 9.231 9.231 0 1 1 5.473 5.473"
      fill="none"
      stroke="#4CECA4"
      strokeWidth="3.538"
      strokeLinecap="round"
    />
    <circle cx="12" cy="2.769" r="2.154" fill="#4CECA4" />
  </svg>
)

type Feature = { title: string; claim: string; points: string[] }
const FEATURES: Feature[] = [
  {
    title: '今日训练',
    claim: '打开就知道练什么，不用每天重新想。',
    points: ['按分化数成套的预置计划', '今天该练哪天，首页直接给', '临时换计划也不丢进度']
  },
  {
    title: '动作库',
    claim: '看得见怎么做，才敢上重量。',
    points: ['部位与肌群双层筛选', '常练的收起来，下次直接翻', '102 个动作，每个都有演示与要点']
  },
  {
    title: '组间计时',
    claim: '歇多久不用自己数。',
    points: ['每组完成自动起表', '到点提醒，不打断节奏']
  },
  {
    title: '身体记录',
    claim: '力量与体重是两件事，分开看。',
    points: ['体重、围度、体成分成线', '和训练量放同一时间轴']
  }
]

type MuscleRow = { group: string; cells: { name: string; level: 0 | 1 | 2 | 3 }[] }
const MUSCLE_ROWS: MuscleRow[] = [
  {
    group: '上肢',
    cells: [
      { name: '胸', level: 3 },
      { name: '背', level: 2 },
      { name: '肩', level: 3 },
      { name: '二头', level: 1 },
      { name: '三头', level: 2 },
      { name: '前臂', level: 1 }
    ]
  },
  {
    group: '核心',
    cells: [
      { name: '腹直肌', level: 2 },
      { name: '腹斜肌', level: 1 },
      { name: '下背', level: 1 },
      { name: '臀', level: 3 },
      { name: '髋', level: 1 },
      { name: '内收', level: 0 }
    ]
  },
  {
    group: '下肢',
    cells: [
      { name: '股四头', level: 3 },
      { name: '腘绳', level: 2 },
      { name: '小腿', level: 1 },
      { name: '胫前', level: 0 },
      { name: '足踝', level: 0 },
      { name: '全身', level: 1 }
    ]
  }
]

type GrowthNode = { phase: string; title: string; line: string; detail: string }
const GROWTH: GrowthNode[] = [
  {
    phase: '第 1 周',
    title: '先把动作做对',
    line: '重量先放一边，姿势比数字重要。',
    detail: '每个动作都有演示与要点，组间计时帮你把休息卡在同一个节奏上。'
  },
  {
    phase: '第 1 个月',
    title: '定下第一条基准',
    line: '起始重量定下来，之后每次都在跟它比。',
    detail: '每个动作的单组最好成绩自动换算成 1RM 参考值，不用自己记表。'
  },
  {
    phase: '第 3 个月',
    title: '趋势开始说话',
    line: '哪些部位练多了、哪些被漏掉，图上很清楚。',
    detail: '周趋势、肌肉分布与进阶洞察，每周自己更新一次，不需要你整理。'
  },
  {
    phase: '第 6 个月',
    title: '回头看得见距离',
    line: '半年前的第一组，和今天的最后一组。',
    detail: '历次训练全留档，任何一场都能翻回去看当时用了多重、做够了几组。'
  }
]

export default function App() {
  const reduce = useReducedMotion()
  const { scrollYProgress } = useScroll()
  const progress = useSpring(scrollYProgress, { stiffness: 120, damping: 24, restDelta: 0.001 })

  // 顶栏吸顶态：滚动超过 8px 才落半透明底，首屏保持通透让极光透出来。
  // 旧版由 site.js 的 classList.add 完成，React 重写后漏了这一环，
  // 导致 .topbar.is-stuck（legacy.css:215）成了死规则、正文穿透顶栏。
  const [stuck, setStuck] = useState(false)
  useEffect(() => {
    const onScroll = () => setStuck(window.scrollY > 8)
    onScroll()
    window.addEventListener('scroll', onScroll, { passive: true })
    return () => window.removeEventListener('scroll', onScroll)
  }, [])

  // 卡片 3D 倾斜：写 CSS 变量，transform 由 legacy.css 的 .feat 规则消费
  const tilt = (e: React.PointerEvent<HTMLElement>) => {
    if (reduce) return
    const el = e.currentTarget
    const r = el.getBoundingClientRect()
    const dx = (e.clientX - r.left) / r.width - 0.5
    const dy = (e.clientY - r.top) / r.height - 0.5
    el.style.setProperty('--rx', (-dy * 3).toFixed(2) + 'deg')
    el.style.setProperty('--ry', (dx * 3).toFixed(2) + 'deg')
  }
  const untilt = (e: React.PointerEvent<HTMLElement>) => {
    e.currentTarget.style.setProperty('--rx', '0deg')
    e.currentTarget.style.setProperty('--ry', '0deg')
  }

  const fadeUp = {
    initial: reduce ? false : { opacity: 0, y: 24 },
    whileInView: { opacity: 1, y: 0 },
    viewport: { once: true, margin: '0px 0px -12% 0px' },
    transition: { duration: 0.55, ease: [0.2, 0.8, 0.2, 1] as [number, number, number, number] }
  }

  return (
    <>
      <Aurora />
      <PointerFx />
      <div className="grid-lines" aria-hidden="true" />

      {/* 滚动进度条：framer-motion 的 useScroll 直接给到 0→1 的进度 */}
      <motion.div className="scroll-progress" style={{ scaleX: progress }} aria-hidden="true" />

      <header className={'topbar' + (stuck ? ' is-stuck' : '')}>
        <div className="wrap topbar-inner">
          <a className="brand" href="#top">
            {BRAND_RING}
            菲特 <em>FitTracker</em>
          </a>
          <nav className="nav" aria-label="主导航">
            <a href="#bento">功能</a>
            <a href="#journey">旅程</a>
            <a href="#muscle">肌群</a>
            <a href="#growth">成长</a>
          </nav>
          <a className="topbar-cta" href={GITHUB} target="_blank" rel="noopener noreferrer">
            <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
              <path d="M12 .3a12 12 0 0 0-3.8 23.4c.6.1.8-.3.8-.6v-2c-3.3.7-4-1.6-4-1.6-.6-1.4-1.4-1.8-1.4-1.8-1.1-.8.1-.8.1-.8 1.2.1 1.8 1.2 1.8 1.2 1.1 1.9 2.9 1.3 3.6 1 .1-.8.4-1.3.8-1.6-2.7-.3-5.5-1.3-5.5-5.9 0-1.3.5-2.4 1.2-3.2-.1-.3-.5-1.5.1-3.2 0 0 1-.3 3.3 1.2a11.5 11.5 0 0 1 6 0C17.6 4.8 18.6 5.1 18.6 5.1c.6 1.7.2 2.9.1 3.2.8.8 1.2 1.9 1.2 3.2 0 4.6-2.8 5.6-5.5 5.9.4.4.8 1.1.8 2.2v3.3c0 .3.2.7.8.6A12 12 0 0 0 12 .3z" />
            </svg>
            源码
          </a>
        </div>
      </header>

      <main id="top">
        {/* ── Hero ─────────────────────────────────────────────────── */}
        <section className="hero">
          <div className="wrap hero-grid">
            <div className="hero-copy">
              <p className="hero-badge">
                <b>v1.1.0</b> 记录 · 回顾 · 进阶
              </p>

              <h1 className="hero-title">
                <span className="ln">
                  {'练过的每一组，'.split('').map((ch, i) => (
                    <span className="ch" style={{ '--i': i } as React.CSSProperties} key={i}>{ch}</span>
                  ))}
                </span>
                <span className="ln accent">
                  {'都算数。'.split('').map((ch, i) => (
                    <span className="ch" style={{ '--i': i + 7 } as React.CSSProperties} key={i}>{ch}</span>
                  ))}
                </span>
              </h1>

              <p className="hero-sub">
                逐组记下次数与重量，自动估算 1RM，再汇总成周趋势、动作个人纪录与肌肉分布。
                练过的每一组都留下痕迹，三个月后回头看，进步是看得见的。
              </p>

              <div className="hero-actions">
                <a className="btn btn-primary" href={GITHUB} target="_blank" rel="noopener noreferrer">
                  <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                    <path d="M12 .3a12 12 0 0 0-3.8 23.4c.6.1.8-.3.8-.6v-2c-3.3.7-4-1.6-4-1.6-.6-1.4-1.4-1.8-1.4-1.8-1.1-.8.1-.8.1-.8 1.2.1 1.8 1.2 1.8 1.2 1.1 1.9 2.9 1.3 3.6 1 .1-.8.4-1.3.8-1.6-2.7-.3-5.5-1.3-5.5-5.9 0-1.3.5-2.4 1.2-3.2-.1-.3-.5-1.5.1-3.2 0 0 1-.3 3.3 1.2a11.5 11.5 0 0 1 6 0C17.6 4.8 18.6 5.1 18.6 5.1c.6 1.7.2 2.9.1 3.2.8.8 1.2 1.9 1.2 3.2 0 4.6-2.8 5.6-5.5 5.9.4.4.8 1.1.8 2.2v3.3c0 .3.2.7.8.6A12 12 0 0 0 12 .3z" />
                  </svg>
                  即将上架 · 先看代码
                </a>
                <a className="btn btn-ghost" href="#muscle">看肌群</a>
              </div>

              <p className="hero-meta">
                <span>102 个动作</span>
                <span>组间计时</span>
                <span>动作演示</span>
              </p>
            </div>
          </div>
        </section>

        {/* ── 功能 ─────────────────────────────────────────────────── */}
        <section id="bento">
          <div className="wrap">
            <motion.div className="section-head" {...fadeUp}>
              <p className="eyebrow">功能</p>
              <h2 className="h2">四件事做到位，训练就不用再操心</h2>
              <p className="lede">不用先学会用工具，再开始练。打开就能练，练完自动记。</p>
            </motion.div>

            <div className="feat-grid">
              {FEATURES.map((f, i) => (
                <motion.article
                  className="feat"
                  key={f.title}
                  initial={reduce ? false : { opacity: 0, y: 18 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  viewport={{ once: true, margin: '0px 0px -10% 0px' }}
                  transition={{ duration: 0.5, delay: i * 0.05 }}
                  onPointerMove={tilt}
                  onPointerLeave={untilt}
                >
                  <h3>{f.title}</h3>
                  <p className="feat-claim">{f.claim}</p>
                  <ul className="feat-points">
                    {f.points.map((point) => (
                      <li key={point}>{point}</li>
                    ))}
                  </ul>
                </motion.article>
              ))}
            </div>
          </div>
        </section>

        {/* ── 用户旅程 ─────────────────────────────────────────────── */}
        <section id="journey">
          <div className="wrap">
            <motion.div className="section-head" {...fadeUp}>
              <p className="eyebrow">用户旅程</p>
              <h2 className="h2">从选计划到三个月后，一条线走完</h2>
              <p className="lede">下面这段由代码编排真实界面截图：五站依次推进，节奏固定，循环播放。</p>
            </motion.div>

            <div className="journey-stage">
              <Suspense fallback={null}>
                <JourneyPlayer />
              </Suspense>
            </div>

            {/* 窄屏放不下 16:10 的画布，换成竖排图文，数据同源 */}
            <ul className="journey-list">
              {JOURNEY_STOPS.map((stop, i) => (
                <li key={stop.id}>
                  <img src={stop.img} alt="" loading="lazy" decoding="async" />
                  <div>
                    <span className="journey-idx">
                      {i + 1} · {stop.label}
                    </span>
                    <h3>{stop.title}</h3>
                    <p>{stop.line}</p>
                  </div>
                </li>
              ))}
            </ul>
          </div>
        </section>

        {/* ── 肌群覆盖 ─────────────────────────────────────────────── */}
        <section id="muscle" className="muscle-sec">
          <div className="wrap">
            <motion.div className="muscle-band" {...fadeUp}>
              <div className="muscle-copy">
                <p className="muscle-eyebrow">练到了哪里</p>
                <h2 className="muscle-h2">
                  一周下来，
                  <br />
                  哪里被照顾到，哪里被漏掉。
                </h2>
                <p className="muscle-lede">
                  每个动作都标了主练肌群与协同肌群，练完自动汇总成这张覆盖图。
                  颜色越深练得越多，一整格没亮的，就是这周被忘掉的部位。
                </p>
              </div>

              <div className="muscle-matrix">
                {MUSCLE_ROWS.map((row) => (
                  <div className="muscle-row" key={row.group}>
                    <span className="muscle-row-k">{row.group}</span>
                    {row.cells.map((cell) => (
                      <span className={`muscle-cell l${cell.level}`} key={cell.name}>
                        {cell.name}
                      </span>
                    ))}
                  </div>
                ))}
              </div>
            </motion.div>
          </div>
        </section>

        {/* ── 成长路径 ─────────────────────────────────────────────── */}
        <section id="growth">
          <div className="wrap">
            <motion.div className="section-head" {...fadeUp}>
              <p className="eyebrow">成长路径</p>
              <h2 className="h2">从第一次进健身房，到看得见的半年</h2>
              <p className="lede">训练没有速成。但每一步都会留下证据，只是需要有人替你记下来。</p>
            </motion.div>

            <div className="growth-track">
              {GROWTH.map((node, i) => (
                <motion.article
                  className="growth-node"
                  key={node.phase}
                  initial={reduce ? false : { opacity: 0, y: 16 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  viewport={{ once: true, margin: '0px 0px -12% 0px' }}
                  transition={{ duration: 0.5, delay: i * 0.08 }}
                >
                  <div className="growth-dot" aria-hidden="true" />
                  <span className="growth-phase">{node.phase}</span>
                  <h3>{node.title}</h3>
                  <p className="growth-line">{node.line}</p>
                  <p className="growth-detail">{node.detail}</p>
                </motion.article>
              ))}
            </div>
          </div>
        </section>
      </main>

      <footer className="site-foot">
        <div className="wrap">
          <div className="foot-mark" aria-hidden="true">FitTracker</div>
          <div className="foot-grid">
            <div>
              <div className="foot-brand">
                {BRAND_RING}
                菲特 FitTracker
              </div>
              <p className="foot-desc">双端健身训练记录。练过的每一组，都留下痕迹。</p>
            </div>
            <div className="foot-col">
              <h4>产品</h4>
              <a href="#bento">功能</a>
              <a href="#journey">用户旅程</a>
              <a href="#muscle">肌群</a>
              <a href="#growth">成长</a>
            </div>
            <div className="foot-col">
              <h4>资料</h4>
              <a href={GITHUB} target="_blank" rel="noopener noreferrer">源码仓库</a>
              <a href="./legal/privacy.html">隐私政策</a>
              <a href="./legal/terms.html">用户协议</a>
            </div>
          </div>
          <div className="foot-bottom">
            <span>© 2026 EarthRhythm</span>
            <span>版本 1.1.0</span>
            <span>包名 com.earthrhythm.fittracker</span>
            <span className="spacer" />
            <span className="pending" data-pending="icp">ICP 备案号待取得</span>
          </div>
        </div>
      </footer>
    </>
  )
}
