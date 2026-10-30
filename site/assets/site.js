/* ============================================================================
   FitTracker 官网交互
   ----------------------------------------------------------------------------
   六个职责，全部「脚本缺失时页面仍完整可读」：
     1  标记 .js（CSS 据此才启用初始隐藏态）
     2  顶栏滚动状态
     3  区块错峰入场
     4  数字滚动计数 + 进度环填充
     5  训练闭环 sticky 叙事切换
     6  功能卡聚光 + Hero 截图视差 + 截图画廊放大

   动效时长与曲线取值见 assets/site.css 的 :root（转录自 App 的 MotionTokens）。
   全部写操作无副作用：不读 cookie、不发请求、不写 storage。
   ========================================================================== */
(function () {
  'use strict'

  var root = document.documentElement
  var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  var finePointer = window.matchMedia('(hover: hover) and (pointer: fine)').matches

  // ── 1. 标记 JS 可用 ────────────────────────────────────────────────────
  root.classList.remove('no-js')
  root.classList.add('js')

  // ── 2. 顶栏滚动状态 ────────────────────────────────────────────────────
  var topbar = document.getElementById('topbar')
  var lastStuck = null
  function syncTopbar() {
    var stuck = window.scrollY > 8
    if (stuck !== lastStuck) {
      lastStuck = stuck
      if (topbar) topbar.classList.toggle('is-stuck', stuck)
    }
  }
  syncTopbar()
  window.addEventListener('scroll', syncTopbar, { passive: true })

  // ── 3. 区块入场 ────────────────────────────────────────────────────────
  var revealEls = Array.prototype.slice.call(document.querySelectorAll('.reveal'))
  if (reduceMotion || !('IntersectionObserver' in window)) {
    revealEls.forEach(function (el) { el.classList.add('is-in') })
  } else {
    var revealIO = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return
        entry.target.classList.add('is-in')
        revealIO.unobserve(entry.target)
      })
    }, { rootMargin: '0px 0px -12% 0px', threshold: 0.1 })
    revealEls.forEach(function (el) { revealIO.observe(el) })
  }

  // ── 4. 数字计数 ────────────────────────────────────────────────────────
  var easeOutCubic = function (t) { return 1 - Math.pow(1 - t, 3) }

  function runCounter(el) {
    var target = Number(el.getAttribute('data-count'))
    var suffix = el.getAttribute('data-suffix') || ''
    if (!isFinite(target)) return
    if (reduceMotion || target === 0) {
      el.textContent = target + suffix
      return
    }
    var dur = 1200            // 同 --dur-ring
    var start = 0
    function step(now) {
      if (!start) start = now
      var t = Math.min((now - start) / dur, 1)
      el.textContent = Math.round(target * easeOutCubic(t)) + suffix
      if (t < 1) requestAnimationFrame(step)
    }
    requestAnimationFrame(step)
  }

  var counters = Array.prototype.slice.call(document.querySelectorAll('[data-count]'))
  if (!('IntersectionObserver' in window)) {
    counters.forEach(runCounter)
  } else {
    var countIO = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return
        runCounter(entry.target)
        countIO.unobserve(entry.target)
      })
    }, { threshold: 0.6 })
    counters.forEach(function (el) { countIO.observe(el) })
  }

  // ── 4b. 进度环填充（20% → dashoffset） ─────────────────────────────────
  var ringCard = document.getElementById('ringCard')
  if (ringCard) {
    var RING_C = 2 * Math.PI * 44          // r=44 in viewBox 100x100
    var pct = 20 / 100
    ringCard.style.setProperty('--ring-offset', String(RING_C * (1 - pct)))
    if (reduceMotion || !('IntersectionObserver' in window)) {
      ringCard.classList.add('is-in')
    } else {
      var ringIO = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return
          entry.target.classList.add('is-in')
          ringIO.unobserve(entry.target)
        })
      }, { threshold: 0.4 })
      ringIO.observe(ringCard)
    }
  }

  // ── 5. 训练闭环 sticky 叙事 ────────────────────────────────────────────
  var flowSteps = Array.prototype.slice.call(document.querySelectorAll('.flow-step'))
  var flowShots = Array.prototype.slice.call(document.querySelectorAll('#flowMedia .shot'))

  function activateStep(index) {
    flowSteps.forEach(function (el, i) { el.classList.toggle('is-active', i === index) })
    flowShots.forEach(function (el, i) { el.classList.toggle('is-active', i === index) })
  }

  if (flowSteps.length && 'IntersectionObserver' in window) {
    var stepIO = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return
        activateStep(Number(entry.target.getAttribute('data-shot')))
      })
    }, { rootMargin: '-45% 0px -45% 0px', threshold: 0 })
    flowSteps.forEach(function (el) { stepIO.observe(el) })
  }

  // ── 6a. 功能卡聚光 ─────────────────────────────────────────────────────
  if (finePointer) {
    Array.prototype.slice.call(document.querySelectorAll('.card')).forEach(function (card) {
      var ticking = false
      card.addEventListener('pointermove', function (event) {
        if (ticking) return
        ticking = true
        requestAnimationFrame(function () {
          var rect = card.getBoundingClientRect()
          card.style.setProperty('--mx', (event.clientX - rect.left) + 'px')
          card.style.setProperty('--my', (event.clientY - rect.top) + 'px')
          ticking = false
        })
      }, { passive: true })
    })
  }

  // ── 6b. Hero 截图视差 ──────────────────────────────────────────────────
  var heroPhone = document.getElementById('heroPhone')
  if (heroPhone && finePointer && !reduceMotion) {
    var heroArt = heroPhone.parentElement
    var tiltTicking = false
    heroArt.addEventListener('pointermove', function (event) {
      if (tiltTicking) return
      tiltTicking = true
      requestAnimationFrame(function () {
        var rect = heroArt.getBoundingClientRect()
        var dx = (event.clientX - rect.left) / rect.width - 0.5
        var dy = (event.clientY - rect.top) / rect.height - 0.5
        heroPhone.style.setProperty('--ry', (dx * 10).toFixed(2) + 'deg')
        heroPhone.style.setProperty('--rx', (-dy * 8).toFixed(2) + 'deg')
        tiltTicking = false
      })
    }, { passive: true })
    heroArt.addEventListener('pointerleave', function () {
      heroPhone.style.setProperty('--rx', '0deg')
      heroPhone.style.setProperty('--ry', '0deg')
    })
  }

  // ── 6c. 截图画廊放大 ───────────────────────────────────────────────────
  var modal = document.getElementById('shotModal')
  var modalImg = document.getElementById('modalImg')
  var modalClose = document.getElementById('modalClose')
  var cards = Array.prototype.slice.call(document.querySelectorAll('.shot-card'))

  if (modal && modalImg && typeof modal.showModal === 'function') {
    cards.forEach(function (card) {
      card.addEventListener('click', function () {
        modalImg.src = card.getAttribute('data-src')
        modalImg.alt = card.getAttribute('data-cap') || '界面截图'
        modal.showModal()
      })
    })
    if (modalClose) {
      modalClose.addEventListener('click', function () { modal.close() })
    }
    // 点击遮罩（即 dialog 自身）关闭
    modal.addEventListener('click', function (event) {
      if (event.target === modal) modal.close()
    })
  } else {
    // 不支持 dialog 的浏览器：保持滚动浏览，不做跳转
    cards.forEach(function (card) { card.style.cursor = 'default' })
  }
})();

/* ============================================================================
   增强层（第二个 IIFE）：滚动进度、滚动视差、全屏聚光、光标光环、卡片倾斜
   与基础层同一降级纪律：JS 缺失时全部效果缺席，内容不受影响。
   ========================================================================== */
(function () {
  'use strict'
  var body = document.body
  var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  var finePointer = window.matchMedia('(hover: hover) and (pointer: fine)').matches

  // ── 滚动进度条 + 视差（统一 rAF，只写 transform / CSS 变量） ────────────
  var progress = document.querySelector('.scroll-progress')
  var aurora = document.querySelector('.aurora')
  var heroCopy = document.querySelector('.hero-copy')
  var heroArt = document.querySelector('.hero-art')

  if (reduceMotion) {
    if (progress) progress.style.display = 'none'
  } else {
    var ticking = false
    function onScroll() {
      if (ticking) return
      ticking = true
      requestAnimationFrame(function () {
        var y = window.scrollY
        var max = Math.max(document.documentElement.scrollHeight - window.innerHeight, 1)
        if (progress) {
          progress.style.setProperty('--sp', String(Math.min(y / max, 1)))
        }
        if (aurora) {
          aurora.style.transform = 'translate3d(0, ' + (y * 0.12).toFixed(1) + 'px, 0)'
        }
        if (heroCopy) {
          heroCopy.style.transform = 'translate3d(0, ' + (-y * 0.05).toFixed(1) + 'px, 0)'
        }
        if (heroArt) {
          heroArt.style.transform = 'translate3d(0, ' + (y * 0.04).toFixed(1) + 'px, 0)'
        }
        ticking = false
      })
    }
    onScroll()
    window.addEventListener('scroll', onScroll, { passive: true })
  }

  // ── 全屏聚光 + 光标光环（仅精确指针；保留原生光标） ────────────────────
  var spotlight = document.querySelector('.spotlight')
  var glow = document.querySelector('.cursor-glow')
  if (finePointer && !reduceMotion && glow) {
    body.classList.add('has-glow')
    var lastX = -200
    var lastY = -200
    var raf = 0
    document.addEventListener('pointermove', function (event) {
      lastX = event.clientX
      lastY = event.clientY
      if (raf) return
      raf = requestAnimationFrame(function () {
        raf = 0
        glow.style.transform =
          'translate(-50%, -50%) translate3d(' + lastX + 'px, ' + lastY + 'px, 0)'
        if (spotlight) {
          spotlight.style.setProperty('--mx', lastX + 'px')
          spotlight.style.setProperty('--my', lastY + 'px')
        }
      })
    }, { passive: true })
    document.addEventListener('pointerover', function (event) {
      var hot = event.target && event.target.closest
        ? event.target.closest('a, button, .card, .shot-card')
        : null
      glow.classList.toggle('is-hovering', !!hot)
    }, { passive: true })
    if (spotlight) spotlight.classList.add('is-on')
  }

  // ── 卡片 3D 倾斜（±4deg，离开回正） ─────────────────────────────────────
  if (finePointer && !reduceMotion) {
    Array.prototype.slice.call(document.querySelectorAll('.card')).forEach(function (card) {
      card.classList.add('tilting')
      var ticking = false
      card.addEventListener('pointermove', function (event) {
        if (ticking) return
        ticking = true
        requestAnimationFrame(function () {
          var rect = card.getBoundingClientRect()
          var dx = (event.clientX - rect.left) / rect.width - 0.5
          var dy = (event.clientY - rect.top) / rect.height - 0.5
          card.style.setProperty('--rx', (-dy * 4).toFixed(2) + 'deg')
          card.style.setProperty('--ry', (dx * 4).toFixed(2) + 'deg')
          ticking = false
        })
      }, { passive: true })
      card.addEventListener('pointerleave', function () {
        card.style.setProperty('--rx', '0deg')
        card.style.setProperty('--ry', '0deg')
      })
    })
  }
})()
