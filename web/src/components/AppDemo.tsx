import { useEffect, useMemo, useRef, useState } from 'react'

/* ============================================================================
   AppDemo —— Hero 右侧的可交互 App 原型
   ----------------------------------------------------------------------------
   五个屏 + 底部 Tab，全部本地状态：不请求、不写存储、不碰业务数据。
   样式在 src/app-demo.css（540 逻辑基准 + transform 缩放）。

   数据取自 docs/screenshots 的实机截图；折叠态信息量按截图逐项还原。
   ========================================================================== */

type Screen = 'home' | 'plans' | 'workout' | 'review' | 'profile'
type Range = 'week' | 'month'
type Muscle = 'balance' | 'fatigue' | 'strength'



const REVIEW_TEXT: Record<Range, {
  head: string
  tag: string
  big: string
  sub: string
  note: string
  bars: number[]
  counts: [string, string, string]
}> = {
  week: {
    head: '本周 · 10月26 – 11月1日',
    tag: '一掉平',
    big: '状态不错，继续保持。',
    sub: '你比上周多完成了 1 次训练，平均训练时长也提升了 12 分钟。',
    note: '当前计划：五分化 · 已练 1 次',
    bars: [26, 100, 26, 26, 26, 26, 26],
    counts: ['1', '0', '--']
  },
  month: {
    head: '本月 · 10月1日 – 10月31日',
    tag: '稳步升',
    big: '这个月稳住了节奏。',
    sub: '共完成 6 次训练，腿部与背部训练量最高，胸部仍有提升空间。',
    note: '当前计划：五分化 · 本月 6 次',
    bars: [40, 72, 100, 58, 34, 80, 52],
    counts: ['6', '214', '-0.4']
  }
}

const MUSCLE_VIEW: Record<Muscle, [string, string][]> = {
  balance: [['腿部', '高'], ['背部', '中'], ['胸部', '低'], ['手臂', '中']],
  fatigue: [['腿部', '需要休息'], ['背部', '可训练'], ['胸部', '可训练'], ['手臂', '可训练']],
  strength: [['腿部', '进步'], ['背部', '持平'], ['胸部', '待提升'], ['手臂', '进步']]
}

const PLAN_EXERCISES: [string, string, string][] = [
  ['杠铃深蹲', '腿部', '4×8-12'],
  ['罗马尼亚硬拉', '腿部', '3×8-12'],
  ['腿举', '腿部', '3×10-12'],
  ['腿弯举', '腿部', '3×12-15'],
  ['提踵', '腿部', '4×15-20']
]

const WEEK_DAYS: [string, string, boolean][] = [
  ['一', '26', false],
  ['二', '27', true],
  ['三', '28', false],
  ['四', '29', false],
  ['五', '30', false],
  ['六', '31', false],
  ['日', '1', false]
]

function pad(n: number) {
  return n < 10 ? '0' + n : String(n)
}

export default function AppDemo() {
  const [active, setActive] = useState<Screen>('home')
  const [setIndex, setSetIndex] = useState(1)      // 1-based：当前待完成的组
  const [completed, setCompleted] = useState(0)
  const [elapsed, setElapsed] = useState(76)       // 与截图一致 01:16
  const [range, setRange] = useState<Range>('week')
  const [muscle, setMuscle] = useState<Muscle>('balance')
  const [toast, setToast] = useState('')
  const [inView, setInView] = useState(false)

  const phoneRef = useRef<HTMLDivElement>(null)
  const appRef = useRef<HTMLDivElement>(null)
  const toastTimer = useRef<number>(0)

  const totalSets = 4
  const running = active === 'workout'

  // 训练计时：只在训练屏跑
  useEffect(() => {
    if (!running) return
    const id = window.setInterval(() => setElapsed((v) => v + 1), 1000)
    return () => window.clearInterval(id)
  }, [running])

  // 提示气泡自动消失
  useEffect(() => {
    if (!toast) return
    window.clearTimeout(toastTimer.current)
    toastTimer.current = window.setTimeout(() => setToast(''), 1700)
    return () => window.clearTimeout(toastTimer.current)
  }, [toast])

  // 540 逻辑基准等比缩放
  useEffect(() => {
    const phone = phoneRef.current
    const app = appRef.current
    if (!phone || !app) return
    const fit = () => {
      const w = phone.clientWidth
      if (w > 0) app.style.setProperty('--k', String(w / 540))
    }
    fit()
    const raf = requestAnimationFrame(fit)
    window.addEventListener('resize', fit, { passive: true })
    const ro = typeof ResizeObserver === 'function' ? new ResizeObserver(fit) : null
    ro?.observe(phone)
    return () => {
      cancelAnimationFrame(raf)
      window.removeEventListener('resize', fit)
      ro?.disconnect()
    }
  }, [])

  // 进度环入场
  useEffect(() => {
    const phone = phoneRef.current
    if (!phone) return
    if (typeof IntersectionObserver !== 'function') {
      setInView(true)
      return
    }
    const io = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)) {
          setInView(true)
          io.disconnect()
        }
      },
      { threshold: 0.35 }
    )
    io.observe(phone)
    return () => io.disconnect()
  }, [])

  const go = (next: Screen) => {
    setActive(next)
    const screen = appRef.current?.querySelector(`[data-screen="${next}"]`) as HTMLElement | null
    if (screen) screen.scrollTop = 0
  }

  const completeSet = () => {
    if (setIndex > totalSets) {
      setToast('本动作 4 组已完成')
      return
    }
    setCompleted((c) => c + 1)
    if (setIndex < totalSets) {
      setSetIndex((i) => i + 1)
      setToast(`已记录第 ${completed + 1} 组`)
    } else {
      setSetIndex(totalSets + 1)
      setToast('杠铃弯举完成 · 4 组')
    }
  }

  const review = REVIEW_TEXT[range]
  const maxBar = useMemo(() => Math.max(...review.bars), [review.bars])

  const tabs: { key: Screen; label: string }[] = [
    { key: 'home', label: '首页' },
    { key: 'plans', label: '计划' },
    { key: 'review', label: '回顾' },
    { key: 'profile', label: '我的' }
  ]

  return (
    <div
      className={'phone app-phone' + (inView ? ' in-view' : '')}
      id="heroPhone"
      ref={phoneRef}
    >
      <div className="app" id="appDemo" data-active={active} ref={appRef}>
        <div className="app-status">
          <span>12:28</span>
          <span className="app-sig">
            <i />
            <i />
            <i />
            <b>82</b>
          </span>
        </div>

        <div className="app-body">
          {/* ── 首页 ───────────────────────────────────────────────── */}
          <section className="app-screen" data-screen="home">
            <p className="app-date">10月28日 周三</p>
            <h2 className="app-h1">下午好，专注训练</h2>

            <div className="app-card app-today">
              <div className="head">
                <div>
                  <div className="app-ear-t">今日训练</div>
                  <h2>
                    周三 腿部 <span className="app-pill gold">推荐</span>
                  </h2>
                  <div className="sub">腿部</div>
                </div>
                <div className="app-ring">
                  <svg viewBox="0 0 100 100" aria-hidden="true">
                    <circle className="rt" cx="50" cy="50" r="44" />
                    <circle className="rf" cx="50" cy="50" r="44" />
                  </svg>
                  <div className="rf-label">
                    <b>20%</b>
                    <span>本周进度</span>
                  </div>
                </div>
              </div>

              <div className="app-legend">训练日 · 建议完成</div>

              <div className="app-3">
                <div className="app-metric">
                  <div className="n">5</div>
                  <div className="k">动作</div>
                </div>
                <div className="app-metric">
                  <div className="n">0</div>
                  <div className="k">分钟</div>
                </div>
                <div className="app-metric">
                  <div className="n">1</div>
                  <div className="k">肌群</div>
                </div>
              </div>

              <button className="app-cta" style={{ marginTop: '.9em' }} onClick={() => go('workout')}>
                开始训练
              </button>
              <button className="app-cta-ghost" onClick={() => go('plans')}>
                查看预览
              </button>
            </div>

            <div className="app-card">
              <div className="app-ear">
                <span className="app-ear-t">本周节奏</span>
                <span className="app-ear-a">1 / 5 次</span>
              </div>
              <div className="app-week">
                {WEEK_DAYS.map(([label, date, done]) => (
                  <div key={date} className={'app-day' + (done ? ' done' : '')}>
                    <i />
                    <span>{label}</span>
                    <b>{date}</b>
                  </div>
                ))}
              </div>
            </div>
          </section>

          {/* ── 计划 ───────────────────────────────────────────────── */}
          <section className="app-screen" data-screen="plans">
            <div className="app-plan-hero">
              <div>
                <div className="app-ear-t">当前计划</div>
                <div className="app-plan-title">五分化</div>
              </div>
              <span className="app-ear-a">中度训练者 · 5 项分化 · 5 天周期</span>
            </div>

            <div className="app-seg">
              <button className="on">第 3 天</button>
              <button>昨天</button>
              <button>周四</button>
            </div>

            <div className="app-card">
              <div className="app-ear">
                <span className="app-plan-title">周三 腿部</span>
                <span className="app-pill">5 个动作</span>
              </div>
              {PLAN_EXERCISES.map(([name, group, volume], i) => (
                <div className="app-row" key={name}>
                  <span className="app-idx">{String(i + 1).padStart(2, '0')}</span>
                  <span className="app-row-main">
                    <span className="app-row-t">{name}</span>
                    <span className="app-row-s">{group}</span>
                  </span>
                  <span className="app-row-v">{volume}</span>
                </div>
              ))}
            </div>

            <button className="app-cta" onClick={() => go('workout')}>
              开始这一天
            </button>
          </section>

          {/* ── 训练执行 ───────────────────────────────────────────── */}
          <section className="app-screen app-workout" data-screen="workout">
            <div className="app-wk-top">
              <span
                className="back"
                role="button"
                tabIndex={0}
                aria-label="退出训练"
                onClick={() => go('home')}
                onKeyDown={(e) => (e.key === 'Enter' || e.key === ' ') && go('home')}
              >
                ⌄
              </span>
              <span className="name">杠铃弯举</span>
              <span className="t">
                总时长 <b>{pad(Math.floor(elapsed / 60))}:{pad(elapsed % 60)}</b>
              </span>
            </div>

            <div className="app-wk-bars">
              {Array.from({ length: totalSets }, (_, i) => {
                const n = i + 1
                const cls = n < setIndex ? 'done' : n === setIndex ? 'on' : ''
                return <i key={n} className={cls} />
              })}
            </div>

            <div className="app-demo-card">
              <span className="badge">动作 1 / 5</span>
              <div className="app-demo-art">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.4"
                     strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                  <path d="M6.5 6.5v11M17.5 6.5v11M3 9v6M21 9v6M6.5 12h11" />
                </svg>
              </div>
              <div className="app-demo-foot">
                <span className="nm">杠铃弯举</span>
                <span className="st">
                  {setIndex > totalSets ? '本动作已完成' : `第 ${setIndex} 组 · 正式组`}
                </span>
              </div>
            </div>

            <div className="app-empty">
              {completed === 0 ? '还没有完成组' : `已完成 ${completed} 组`}
            </div>

            <div className="app-wk-foot">
              <div className="hint">长按「完成」提前结束本动作</div>
              <button className="app-cta" onClick={completeSet}>
                完成
              </button>
            </div>
          </section>

          {/* ── 回顾 ───────────────────────────────────────────────── */}
          <section className="app-screen" data-screen="review">
            <div className="app-seg" style={{ maxWidth: '8.6em', margin: '0 auto .1em' }}>
              <button className={range === 'week' ? 'on' : ''} onClick={() => setRange('week')}>
                周
              </button>
              <button className={range === 'month' ? 'on' : ''} onClick={() => setRange('month')}>
                月
              </button>
            </div>

            <div className="app-card">
              <div className="app-review-hero">
                {review.head} <span className="app-pill">{review.tag}</span>
              </div>
              <div className="app-review-big">{review.big}</div>
              <div className="app-review-sub">{review.sub}</div>
              <div className="app-review-sub" style={{ color: 'var(--primary)', fontWeight: 750, marginTop: '.45em' }}>
                {review.note}
              </div>
            </div>

            <div className="app-card app-3">
              <div className="app-metric">
                <div className="n">{review.counts[0]}</div>
                <div className="k">训练 · 次</div>
              </div>
              <div className="app-metric">
                <div className="n">{review.counts[1]}</div>
                <div className="k">时长 · 分钟</div>
              </div>
              <div className="app-metric">
                <div className="n" style={{ color: 'var(--text-3)' }}>{review.counts[2]}</div>
                <div className="k">体重变化 · kg</div>
              </div>
            </div>

            <div className="app-card">
              <div className="app-ear">
                <span className="app-ear-t">训练节奏</span>
                <span className="app-ear-a">过去 7 天</span>
              </div>
              <div className="app-bars">
                {review.bars.map((h, i) => (
                  <span key={i} className={h === maxBar ? 'hi' : ''} style={{ height: h + '%' }} />
                ))}
              </div>
              <div className="app-bars-x">
                {['一', '二', '三', '四', '五', '六', '日'].map((d) => (
                  <span key={d}>{d}</span>
                ))}
              </div>
            </div>

            <div className="app-card">
              <div className="app-ear">
                <span className="app-ear-t">肌肉地图</span>
                <span className="app-ear-a">近 8 次训练 · 训练量</span>
              </div>
              <div className="app-seg" style={{ marginBottom: '.55em' }}>
                <button className={muscle === 'balance' ? 'on' : ''} onClick={() => setMuscle('balance')}>平衡</button>
                <button className={muscle === 'fatigue' ? 'on' : ''} onClick={() => setMuscle('fatigue')}>疲劳</button>
                <button className={muscle === 'strength' ? 'on' : ''} onClick={() => setMuscle('strength')}>力量</button>
              </div>
              <div className="app-muscle">
                {MUSCLE_VIEW[muscle].map(([part, level]) => (
                  <div key={part}>
                    {part}
                    <b>{level}</b>
                  </div>
                ))}
              </div>
            </div>
          </section>

          {/* ── 我的 ───────────────────────────────────────────────── */}
          <section className="app-screen" data-screen="profile">
            <div className="app-me-head">
              <div className="app-avatar">菲</div>
              <div>
                <div className="nm">健身新手</div>
                <div className="rl">新手 · 已练 1 次</div>
              </div>
              <span className="app-pill" style={{ marginLeft: 'auto' }}>编辑</span>
            </div>

            <div className="app-card">
              <div className="app-ear">
                <span className="app-ear-t">本周概览</span>
                <span className="app-ear-a">10月26 – 11月1日</span>
              </div>
              <div style={{ display: 'flex', alignItems: 'baseline', gap: '.35em' }}>
                <span style={{ fontSize: '2.15em', fontWeight: 900, letterSpacing: '-.04em', color: 'var(--primary)', lineHeight: 1 }}>
                  0
                </span>
                <span style={{ fontSize: '.78em', color: 'var(--text-2)', fontWeight: 700 }}>分钟</span>
              </div>
              <div className="app-ear-a" style={{ margin: '.2em 0 .7em' }}>本周训练时长</div>
              <div className="app-row" style={{ borderBottom: 0, padding: '.3em 0' }}>
                <span className="app-row-s" style={{ fontSize: '.78em', color: 'var(--text-3)' }}>训练</span>
                <span className="app-row-v" style={{ marginLeft: 'auto' }}>
                  <b style={{ fontSize: '1.35em', color: 'var(--text)', fontWeight: 900 }}>1</b> 次
                </span>
              </div>
            </div>

            <div className="app-card">
              <div className="app-ear-t" style={{ marginBottom: '.6em' }}>最近成就</div>
              <div className="app-achievement">
                <span className="ic">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"
                       strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                    <path d="M8 21h8M12 17v4M7 4h10v5a5 5 0 0 1-10 0zM7 6H4v2a3 3 0 0 0 3 3M17 6h3v2a3 3 0 0 1-3 3" />
                  </svg>
                </span>
                <div>
                  <div className="t">重量突破</div>
                  <div className="s">杠铃深蹲 35.0 kg</div>
                </div>
                <span className="d">2026-10-09</span>
              </div>
            </div>

            <div className="app-entries">
              <div className="app-entry" onClick={() => setToast('演示版未包含「身体数据」页')}>
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"
                     strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                  <path d="M12 3v18M5 8h14M8 8l-3 8a3 3 0 0 0 6 0l-3-8M16 8l-3 8a3 3 0 0 0 6 0l-3-8" />
                </svg>
                身体数据
              </div>
              <div className="app-entry" onClick={() => setToast('演示版未包含「动作库」页')}>
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"
                     strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                  <path d="M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h6v6h-6z" />
                </svg>
                动作库
              </div>
            </div>
          </section>
        </div>

        <nav className="app-tabs" aria-label="App 演示导航">
          {tabs.slice(0, 2).map((t) => (
            <button key={t.key} className={active === t.key ? 'is-on' : ''} onClick={() => go(t.key)}>
              {t.label}
            </button>
          ))}
          <button className="app-tab-cta" aria-label="开始训练" onClick={() => go('workout')}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2"
                 strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
              <path d="M6.5 6.5v11M17.5 6.5v11M3 9v6M21 9v6M6.5 12h11" />
            </svg>
          </button>
          {tabs.slice(2).map((t) => (
            <button key={t.key} className={active === t.key ? 'is-on' : ''} onClick={() => go(t.key)}>
              {t.label}
            </button>
          ))}
        </nav>

        <div className={'app-toast' + (toast ? ' on' : '')}>{toast}</div>
      </div>
    </div>
  )
}
