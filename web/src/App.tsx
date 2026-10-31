import { motion, useReducedMotion, useScroll, useSpring } from 'framer-motion'
import Aurora from './components/Aurora'
import AppDemo from './components/AppDemo'
import PointerFx from './components/PointerFx'

/* ============================================================================
   官网主体
   ----------------------------------------------------------------------------
   结构沿用 site/index.html，class 复用 legacy.css（不重写样式，避免视觉回归）；
   新增能力用 Tailwind / framer-motion。

   动效分工：
     - 滚动进度条：framer-motion useScroll + useSpring（替代手写 rAF）
     - 区块入场：motion.section whileInView（替代 IntersectionObserver）
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

const STATS: [string, string][] = [
  ['102', '个'],
  ['2', '端'],
  ['2', '项'],
  ['0', '个']
]
const STAT_LABELS = ['内置动作', '原生实现', '系统权限', '广告与埋点 SDK']

const FLOW_STEPS: [string, string, number][] = [
  ['选计划', '按分化数成套的预置计划组，例如三分化。启用后落到本地库，首页直接给出「今日训练」，不用每天重新想练什么。', 0],
  ['逐组录入', '次数与重量逐组记，组间自动计时。中途换动作也不丢已录的分组——这一点两端行为一致。', 1],
  ['回顾趋势', '周趋势、动作个人纪录下钻、肌肉分布与进阶洞察。练了三周还是一条平线，你会立刻看见。', 2],
  ['记身体数据', '体重、围度与体成分单独成线。力量涨了但体重没动，和两者一起涨，是两件不同的事。', 3]
]
const FLOW_SHOTS = ['05-plans', '02-training', '04-review', '07-body']

type Card = { title: string; body: string; tag?: string; span: 'wide' | 'normal' | 'full' }
const BENTO: Card[] = [
  {
    title: '训练流',
    body: '训练预览 → 执行（组次录入、组间计时、切动作保留分组）→ 完成摘要。中途退出也能从草稿接着练。',
    tag: '组间计时',
    span: 'wide'
  },
  {
    title: '训练回顾',
    body: '历史训练、周趋势、动作 PR 下钻、肌肉分布与进阶洞察。数据不是记完就沉底，而是每周自己开口说话。',
    tag: '肌肉分布',
    span: 'wide'
  },
  { title: '训练计划', body: '按分化数成套的预置计划组，可启用落库，首页直接呈现今日训练。', span: 'normal' },
  { title: '动作库', body: '列表、筛选、收藏与详情，102 个动作内置演示素材，不联网也看得到。', span: 'normal' },
  { title: '身体数据', body: '体重、围度与体成分趋势，和训练量放在同一时间轴上对照。', span: 'normal' }
]

const GALLERY: [string, string][] = [
  ['02-training', '训练执行'],
  ['04-review', '训练回顾'],
  ['05-plans', '训练计划'],
  ['06-library', '动作库'],
  ['07-body', '身体数据'],
  ['08-profile', '个人']
]

const PLEDGES = [
  ['数据默认留在本机', '训练计划、记录与身体数据写入应用私有沙箱，其他应用无法直接读取。'],
  ['只申请两项权限', '网络访问（登录与同步）与振动（完成一组时的触觉反馈）。不碰位置、通讯录、短信、相机、麦克风、相册。'],
  ['没有广告，也没有埋点', '不集成广告 SDK、第三方统计 SDK、第三方分享或支付 SDK。不采集设备标识、位置与使用行为。'],
  ['云端只有你自己的数据', '自托管 Supabase 部署在自己的境内服务器上，行级安全策略限定仅数据创建者读写。']
]

const TECH: [string, string, string][] = [
  ['双端原生', 'ArkTS / ArkUI · Kotlin / Compose', '各自独立实现，不共享 UI 层'],
  ['统一契约', 'contracts/ 定义快照字段', '任一端漂移，另一端解析直接失败'],
  ['八道门禁', '内容 → 路由 → 死链 → 对等 → 编译', '任一红即停，提交前必过']
]

export default function App() {
  const reduce = useReducedMotion()
  const { scrollYProgress } = useScroll()
  const progress = useSpring(scrollYProgress, { stiffness: 120, damping: 24, restDelta: 0.001 })

  // 卡片 3D 倾斜：写 CSS 变量，transform 由 legacy.css 的 .card 规则消费
  const tilt = (e: React.PointerEvent<HTMLElement>) => {
    if (reduce) return
    const el = e.currentTarget
    const r = el.getBoundingClientRect()
    const dx = (e.clientX - r.left) / r.width - 0.5
    const dy = (e.clientY - r.top) / r.height - 0.5
    el.style.setProperty('--rx', (-dy * 4).toFixed(2) + 'deg')
    el.style.setProperty('--ry', (dx * 4).toFixed(2) + 'deg')
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

      <header className="topbar">
        <div className="wrap topbar-inner">
          <a className="brand" href="#top">
            {BRAND_RING}
            菲特 <em>FitTracker</em>
          </a>
          <nav className="nav" aria-label="主导航">
            <a href="#flow">训练闭环</a>
            <a href="#bento">功能</a>
            <a href="#gallery">界面</a>
            <a href="#privacy">数据与隐私</a>
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
                <b>v1.1.0</b> 双端原生 · HarmonyOS &amp; Android
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
                逐组记下次数与重量，按 <b>Epley 公式</b>估算 1RM，再汇总成周趋势、动作个人纪录与肌肉分布。
                两端各自原生实现，数据默认留在你的设备上。
              </p>

              <div className="hero-actions">
                <a className="btn btn-primary" href={GITHUB} target="_blank" rel="noopener noreferrer">
                  <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                    <path d="M12 .3a12 12 0 0 0-3.8 23.4c.6.1.8-.3.8-.6v-2c-3.3.7-4-1.6-4-1.6-.6-1.4-1.4-1.8-1.4-1.8-1.1-.8.1-.8.1-.8 1.2.1 1.8 1.2 1.8 1.2 1.1 1.9 2.9 1.3 3.6 1 .1-.8.4-1.3.8-1.6-2.7-.3-5.5-1.3-5.5-5.9 0-1.3.5-2.4 1.2-3.2-.1-.3-.5-1.5.1-3.2 0 0 1-.3 3.3 1.2a11.5 11.5 0 0 1 6 0C17.6 4.8 18.6 5.1 18.6 5.1c.6 1.7.2 2.9.1 3.2.8.8 1.2 1.9 1.2 3.2 0 4.6-2.8 5.6-5.5 5.9.4.4.8 1.1.8 2.2v3.3c0 .3.2.7.8.6A12 12 0 0 0 12 .3z" />
                  </svg>
                  即将上架 · 先看代码
                </a>
                <a className="btn btn-ghost" href="#gallery">看界面</a>
              </div>

              <p className="hero-meta">
                <span>102 个动作</span>
                <span>组间计时</span>
                <span>登录后自动同步</span>
              </p>
            </div>

            <div className="hero-art">
              <AppDemo />
            </div>
          </div>
        </section>

        {/* ── 数字条 ───────────────────────────────────────────────── */}
        <section className="stats" aria-label="产品概况">
          <div className="wrap">
            <motion.div className="stats-band" {...fadeUp}>
              <div className="stats-grid">
                {STATS.map(([n, unit], i) => (
                  <div className="stat" key={STAT_LABELS[i]}>
                    <div className="n">
                      {n}
                      <small>{unit}</small>
                    </div>
                    <div className="k">{STAT_LABELS[i]}</div>
                  </div>
                ))}
              </div>
            </motion.div>
          </div>
        </section>

        {/* ── 训练闭环 ─────────────────────────────────────────────── */}
        <section id="flow">
          <div className="wrap">
            <motion.div className="section-head" {...fadeUp}>
              <p className="eyebrow">训练闭环</p>
              <h2 className="h2">从选计划到看得见进步，四步闭合</h2>
              <p className="lede">纸质本记得下数字，但算不出趋势，也拼不出肌肉分布。菲特把这条链一次接起来。</p>
            </motion.div>

            <div className="flow-grid">
              <div className="flow-steps">
                {FLOW_STEPS.map(([title, body], i) => (
                  <motion.article
                    className={'flow-step' + (i === 0 ? ' is-active' : '')}
                    key={title}
                    initial={reduce ? false : { opacity: 0.35, x: -6 }}
                    whileInView={{ opacity: 1, x: 0 }}
                    viewport={{ margin: '-45% 0px -45% 0px' }}
                    transition={{ duration: 0.45, ease: [0.2, 0.8, 0.2, 1] as [number, number, number, number] }}
                  >
                    <div className="flow-idx">{i + 1}</div>
                    <h3>{title}</h3>
                    <p>{body}</p>
                  </motion.article>
                ))}
              </div>

              <div className="flow-media">
                <div className="phone">
                  {FLOW_SHOTS.map((shot, i) => (
                    <div className={'shot' + (i === 0 ? ' is-active' : '')} key={shot}>
                      <img
                        src={`./${shot}.jpg`}
                        width={540}
                        height={1186}
                        loading="lazy"
                        decoding="async"
                        alt={`${FLOW_STEPS[i][0]}界面`}
                      />
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* ── 功能 Bento ───────────────────────────────────────────── */}
        <section id="bento">
          <div className="wrap">
            <motion.div className="section-head" {...fadeUp}>
              <p className="eyebrow">功能</p>
              <h2 className="h2">六个模块，一个都不断线</h2>
              <p className="lede">记录、计划、回顾、内容、身体、同步——各自独立，但共用同一份数据契约。</p>
            </motion.div>

            <div className="bento">
              {BENTO.map((card, i) => (
                <motion.article
                  className={'card ' + (card.span === 'wide' ? 'wide' : card.span === 'full' ? 'full' : '')}
                  key={card.title}
                  initial={reduce ? false : { opacity: 0 }}
                  whileInView={{ opacity: 1 }}
                  viewport={{ once: true, margin: '0px 0px -10% 0px' }}
                  transition={{ duration: 0.5, delay: i * 0.04 }}
                  onPointerMove={tilt}
                  onPointerLeave={untilt}
                >
                  <h3>{card.title}</h3>
                  <p>{card.body}</p>
                  {card.tag && <span className="tag">{card.tag}</span>}
                </motion.article>
              ))}

              <motion.article className="card full" {...fadeUp}>
                <div className="split">
                  <div>
                    <h3>账号与云同步</h3>
                    <p>两端共用同一套自托管 Supabase：认证服务 + Postgres 整包快照。换设备不必重新开始。</p>
                  </div>
                  <div className="tech-item" style={{ margin: 0 }}>
                    <div className="k">数据边界</div>
                    <div className="v">
                      快照按 user_id 单行 upsert
                      <small>行级安全策略限定「仅数据创建者读写」，刻意不建 delete 策略。</small>
                    </div>
                  </div>
                </div>
              </motion.article>
            </div>
          </div>
        </section>

        {/* ── 截图画廊 ─────────────────────────────────────────────── */}
        <section id="gallery">
          <div className="wrap">
            <motion.div className="section-head" {...fadeUp}>
              <p className="eyebrow">界面</p>
              <h2 className="h2">真实设备截图，不是效果图</h2>
              <p className="lede">下面每一张都来自实机。点开可以放大看细节。</p>
            </motion.div>

            <div className="gallery">
              {GALLERY.map(([file, label]) => (
                <figure className="shot-card" key={file}>
                  <img src={`./${file}.jpg`} width={540} height={1186} loading="lazy" decoding="async" alt={`${label}截图`} />
                  <figcaption>{label}</figcaption>
                </figure>
              ))}
            </div>
          </div>
        </section>

        {/* ── 数据与隐私 ───────────────────────────────────────────── */}
        <section id="privacy">
          <div className="wrap">
            <motion.div className="section-head" {...fadeUp}>
              <p className="eyebrow">数据与隐私</p>
              <h2 className="h2">只声明已经做到的事</h2>
              <p className="lede">隐私政策里的每一项陈述都与当前代码和配置一一对应。做不到的，不写。</p>
            </motion.div>

            <div className="privacy-grid">
              {PLEDGES.map(([title, body], i) => (
                <motion.article
                  className="pledge"
                  key={title}
                  initial={reduce ? false : { opacity: 0, y: 20 }}
                  whileInView={{ opacity: 1 }}
                  viewport={{ once: true }}
                  transition={{ duration: 0.45, delay: i * 0.05, ease: [0.2, 0.8, 0.2, 1] as [number, number, number, number] }}
                >
                  <div>
                    <h3>{title}</h3>
                    <p>{body}</p>
                  </div>
                </motion.article>
              ))}
            </div>
          </div>
        </section>

        {/* ── 技术底子 ─────────────────────────────────────────────── */}
        <section>
          <div className="wrap">
            <motion.div className="section-head" {...fadeUp}>
              <p className="eyebrow">技术底子</p>
              <h2 className="h2">两套原生 UI，一份数据契约</h2>
              <p className="lede">这不是一个套壳应用。两端各自原生实现，快照的字段、类型与语义由契约层统一，改一处必须同步另一端。</p>
            </motion.div>

            <motion.div className="tech-row" {...fadeUp}>
              {TECH.map(([k, v, small]) => (
                <div className="tech-item" key={k}>
                  <div className="k">{k}</div>
                  <div className="v">
                    {v}
                    <small>{small}</small>
                  </div>
                </div>
              ))}
            </motion.div>
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
              <p className="foot-desc">双端原生健身训练记录。数据默认留在本机，登录后自动同步。</p>
            </div>
            <div className="foot-col">
              <h4>产品</h4>
              <a href="#flow">训练闭环</a>
              <a href="#bento">功能</a>
              <a href="#gallery">界面</a>
              <a href="#privacy">数据与隐私</a>
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
