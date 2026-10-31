import { useEffect, useRef } from 'react'

/* ============================================================================
   PointerFx —— 自定义指针（替代系统光标）
   ----------------------------------------------------------------------------
   原生光标被隐藏，屏幕上看到的三层就是"鼠标本身"：
     层 1  .cursor-dot   8px 实心绿点：指针主体，几乎硬跟（lerp 0.5），要跟手
     层 2  .cursor-glow  26px 环：主体的可点区提示，稍慢（lerp 0.18）
     层 3  .spotlight    全屏柔光：最慢（lerp 0.07），当作背景打光

   为什么保留轻微 lerp 而不是 1:1 硬跟：完全硬跟会显得"贴纸"，0.5 的插值
   在高速移动时只差 1-2 帧，静止瞬间即可归位，手感仍是跟手的。

   可用性：
     - 文本框 / 可编辑区保留原生 caret（CSS 里 cursor: text），否则没法选中文字
     - 触屏 / 粗指针 / prefers-reduced-motion 时完全不挂载，系统光标照常
     - 首次 pointermove 之前不显示，避免在左上角闪一下

   降级：上述任一条件不满足即 return null，body 不加 has-cursor-fx 类。
   ========================================================================== */

export default function PointerFx() {
  const dotRef = useRef<HTMLDivElement>(null)
  const glowRef = useRef<HTMLDivElement>(null)
  const spotRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const fine = window.matchMedia('(hover: hover) and (pointer: fine)').matches
    const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    if (!fine || reduce) return

    const dot = dotRef.current
    const glow = glowRef.current
    const spot = spotRef.current
    if (!dot || !glow || !spot) return

    document.documentElement.classList.add('has-cursor-fx')
    spot.classList.add('is-on')

    // tx/ty 是指针真实位置；三条轨迹各自向它收敛
    let tx = -200
    let ty = -200
    let dx = -200
    let dy = -200
    let gx = -200
    let gy = -200
    let sx = -200
    let sy = -200
    let raf = 0
    let shown = false

    const EASE_DOT = 0.5
    const EASE_GLOW = 0.18
    const EASE_SPOT = 0.07
    const EPS = 0.3

    const loop = () => {
      dx += (tx - dx) * EASE_DOT
      dy += (ty - dy) * EASE_DOT
      gx += (tx - gx) * EASE_GLOW
      gy += (ty - gy) * EASE_GLOW
      sx += (tx - sx) * EASE_SPOT
      sy += (ty - sy) * EASE_SPOT

      dot.style.transform = `translate3d(${dx.toFixed(2)}px, ${dy.toFixed(2)}px, 0)`
      glow.style.transform = `translate(-50%, -50%) translate3d(${gx.toFixed(2)}px, ${gy.toFixed(2)}px, 0)`
      spot.style.setProperty('--mx', sx.toFixed(2) + 'px')
      spot.style.setProperty('--my', sy.toFixed(2) + 'px')

      const settled =
        Math.abs(tx - dx) < EPS &&
        Math.abs(ty - dy) < EPS &&
        Math.abs(tx - gx) < EPS &&
        Math.abs(ty - gy) < EPS &&
        Math.abs(tx - sx) < EPS &&
        Math.abs(ty - sy) < EPS
      // 全部归位后停掉循环，指针一动再从 onMove 点火
      raf = settled ? 0 : requestAnimationFrame(loop)
    }

    const onMove = (e: PointerEvent) => {
      tx = e.clientX
      ty = e.clientY
      if (!shown) {
        shown = true
        // 第一次移动直接把三层放到指针位置，避免从左上角飞过来
        dx = gx = sx = tx
        dy = gy = sy = ty
        document.documentElement.classList.add('cursor-fx-ready')
      }
      if (!raf) raf = requestAnimationFrame(loop)
    }

    // 悬停可交互元素：环扩张成填充态，点缩小让位
    const onOver = (e: PointerEvent) => {
      const target = e.target as Element | null
      const hot = target?.closest?.('a, button, .feat, .muscle-cell, .nav a, .topbar-cta')
      glow.classList.toggle('is-hovering', !!hot)
    }

    // 按压反馈：pointer-events:none 的元素收不到事件，只能挂在 window 上
    const onDown = () => glow.classList.add('is-pressed')
    const onUp = () => glow.classList.remove('is-pressed')
    const onLeave = () => {
      glow.classList.remove('is-hovering')
      document.documentElement.classList.remove('cursor-fx-ready')
      shown = false
    }
    const onEnter = () => {
      document.documentElement.classList.add('cursor-fx-ready')
      shown = true
    }

    window.addEventListener('pointermove', onMove, { passive: true })
    document.addEventListener('pointerover', onOver, { passive: true })
    window.addEventListener('pointerdown', onDown, { passive: true })
    window.addEventListener('pointerup', onUp, { passive: true })
    document.addEventListener('pointerleave', onLeave, { passive: true })
    document.addEventListener('pointerenter', onEnter, { passive: true })

    return () => {
      window.removeEventListener('pointermove', onMove)
      document.removeEventListener('pointerover', onOver)
      window.removeEventListener('pointerdown', onDown)
      window.removeEventListener('pointerup', onUp)
      document.removeEventListener('pointerleave', onLeave)
      document.removeEventListener('pointerenter', onEnter)
      if (raf) cancelAnimationFrame(raf)
      document.documentElement.classList.remove('has-cursor-fx', 'cursor-fx-ready')
    }
  }, [])

  return (
    <>
      <div className="spotlight" ref={spotRef} aria-hidden="true" />
      <div className="cursor-glow" ref={glowRef} aria-hidden="true" />
      <div className="cursor-dot" ref={dotRef} aria-hidden="true" />
    </>
  )
}
