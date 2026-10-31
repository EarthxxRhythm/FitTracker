import { useEffect, useRef } from 'react'

/* ============================================================================
   PointerFx —— 光标光环 + 全站聚光
   ----------------------------------------------------------------------------
   从 site/assets/site.js 的增强层移植成 React 组件。
   用原生 pointermove + rAF 节流（而不是 framer-motion 的 motion value）：
   这两个效果只是把指针坐标写进 CSS 变量，没有物理插值需求，
   原生实现比 motion value 少一层抽象、且能直接产出带 px 的合法 CSS 值。

   降级：触屏 / 粗指针 / prefers-reduced-motion 时完全不挂载（返回 null）。
   ========================================================================== */

export default function PointerFx() {
  const glowRef = useRef<HTMLDivElement>(null)
  const spotRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const fine = window.matchMedia('(hover: hover) and (pointer: fine)').matches
    const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    if (!fine || reduce) return

    const glow = glowRef.current
    const spot = spotRef.current
    if (!glow || !spot) return

    document.body.classList.add('has-glow')
    spot.classList.add('is-on')

    let raf = 0
    let lastX = -200
    let lastY = -200

    const apply = () => {
      raf = 0
      glow.style.transform = `translate(-50%, -50%) translate3d(${lastX}px, ${lastY}px, 0)`
      spot.style.setProperty('--mx', lastX + 'px')
      spot.style.setProperty('--my', lastY + 'px')
    }

    const onMove = (e: PointerEvent) => {
      lastX = e.clientX
      lastY = e.clientY
      if (raf) return
      raf = requestAnimationFrame(apply)
    }

    // 指针落在可交互元素上时放大光环
    const onOver = (e: PointerEvent) => {
      const target = e.target as Element | null
      const hot = target?.closest?.('a, button, .card, .shot-card')
      glow.classList.toggle('is-hovering', !!hot)
    }

    window.addEventListener('pointermove', onMove, { passive: true })
    document.addEventListener('pointerover', onOver, { passive: true })

    return () => {
      window.removeEventListener('pointermove', onMove)
      document.removeEventListener('pointerover', onOver)
      if (raf) cancelAnimationFrame(raf)
      document.body.classList.remove('has-glow')
    }
  }, [])

  return (
    <>
      <div className="spotlight" ref={spotRef} aria-hidden="true" />
      <div className="cursor-glow" ref={glowRef} aria-hidden="true" />
    </>
  )
}
