/**
 * Hero 里的在线体验挂载点。
 *
 * 做法参照 opengym.ch 的 #demo（site.js:220-240）：
 *   1. 先只渲染一个空 slot，不创建 iframe —— 首屏不为 app 的九屏 UI 付运行时成本；
 *   2. IntersectionObserver 提前 600px 观察，快滚到时才挂 iframe；
 *   3. 容器不可见（offsetParent 为 null）时直接跳过，等 resize 后再补挂；
 *   4. iframe loading="lazy"，圆角与手机壳对齐。
 *
 * 比原方案多两件事：
 *   - 加载态骨架：iframe 首次加载会有一段时间是空的，给个深色底 + 提示，避免看起来像坏了；
 *   - 超时兜底：12s 还没 onLoad 就给出口（新标签打开 / 重试），不让用户对着空白等。
 *
 * 注意：iframe 内是独立文档，官网的 CSS 与 React 状态都不共享——
 * 这正是选它的理由（隔离），也是它的代价（主题/登录态要各管各的）。
 */

import { useEffect, useRef, useState } from 'react'

import './demo-slot.css'

/** dev 与 build 都成立：dev 下 Vite 直接服务 /app/，build 后是 dist/app/。 */
const DEMO_SRC = './app/'

type Status = 'idle' | 'loading' | 'ready' | 'failed'

export default function DemoSlot() {
  const slotRef = useRef<HTMLDivElement>(null)
  const [mounted, setMounted] = useState(false)
  const [status, setStatus] = useState<Status>('idle')

  useEffect(() => {
    const slot = slotRef.current
    if (!slot) return

    const mount = () => {
      if (slot.dataset.mounted === '1') return
      // frame hidden: 容器被 CSS 隐藏时不挂载，省一次完整 app 的加载
      if (!slot.offsetParent) return
      slot.dataset.mounted = '1'
      setMounted(true)
      setStatus('loading')
    }

    const io = new IntersectionObserver(
      (entries, observer) => {
        for (const entry of entries) {
          if (entry.isIntersecting) {
            mount()
            observer.disconnect()
          }
        }
      },
      { rootMargin: '600px' }
    )
    io.observe(slot)

    // 旋转屏幕或改窗口大小可能让原本隐藏的容器显形，补一次
    window.addEventListener('resize', mount, { passive: true })
    return () => {
      io.disconnect()
      window.removeEventListener('resize', mount)
    }
  }, [])

  // 超时兜底：12 秒还没加载完，就别让用户对着空白等
  useEffect(() => {
    if (status !== 'loading') return
    const id = window.setTimeout(() => {
      setStatus((prev) => (prev === 'ready' ? prev : 'failed'))
    }, 12_000)
    return () => window.clearTimeout(id)
  }, [status])

  return (
    <div className="demo-slot" ref={slotRef}>
      {mounted && status !== 'failed' && (
        <iframe
          className="demo-frame"
          src={DEMO_SRC}
          title="FitTracker 在线体验"
          loading="lazy"
          onLoad={() => setStatus('ready')}
        />
      )}

      {status === 'loading' && (
        <div className="demo-skeleton" aria-hidden="true">
          <span className="demo-skel-dot" />
          <span>正在加载体验…</span>
        </div>
      )}

      {status === 'failed' && (
        <div className="demo-fallback">
          <p className="demo-fallback-title">体验没能加载出来</p>
          <p className="demo-fallback-body">
            可能是网络或浏览器拦截了内嵌页面。换个方式一样能试：
          </p>
          <a className="demo-fallback-btn" href={DEMO_SRC} target="_blank" rel="noopener noreferrer">
            在新标签打开 →
          </a>
          <button
            className="demo-fallback-retry"
            onClick={() => {
              setStatus('loading')
              setMounted(false)
              const slot = slotRef.current
              if (slot) delete slot.dataset.mounted
              window.setTimeout(() => {
                if (!slot) return
                slot.dataset.mounted = '1'
                setMounted(true)
              }, 30)
            }}
          >
            重试
          </button>
        </div>
      )}
    </div>
  )
}
