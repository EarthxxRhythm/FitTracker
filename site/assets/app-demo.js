/* ============================================================================
   Hero 可交互 App 演示
   ----------------------------------------------------------------------------
   五个屏（首页 / 计划 / 训练 / 回顾 / 我的）+ 底部 Tab。
   交互全部是本地状态，不发请求、不写存储、不碰业务数据——
   它是展示用的原型，与真实 App 的数据层无关。

   降级：脚本缺失时 .no-js 规则保证首页可见可读；点击无效但不报错。
   ========================================================================== */
(function () {
  'use strict'

  var app = document.getElementById('appDemo')
  if (!app) return

  var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  var toastEl = document.getElementById('appToast')
  var tabButtons = Array.prototype.slice.call(app.querySelectorAll('.app-tabs button[data-go]'))
  var validScreens = { home: 1, plans: 1, workout: 1, review: 1, profile: 1 }
  var toastTimer = 0

  function toast(message) {
    if (!toastEl) return
    toastEl.textContent = message
    toastEl.classList.add('on')
    window.clearTimeout(toastTimer)
    toastTimer = window.setTimeout(function () {
      toastEl.classList.remove('on')
    }, 1700)
  }

  function go(name) {
    if (!validScreens[name]) return
    app.setAttribute('data-active', name)
    tabButtons.forEach(function (btn) {
      var isCta = btn.classList.contains('app-tab-cta')
      btn.classList.toggle('is-on', !isCta && btn.getAttribute('data-go') === name)
    })
    var screen = app.querySelector('[data-screen="' + name + '"]')
    if (screen) screen.scrollTop = 0
    if (screen) screen.scrollLeft = 0
    if (name === 'workout') startTimer()
  }

  // ── 训练执行：组进度 + 计时 ────────────────────────────────────────────
  var bars = Array.prototype.slice.call(app.querySelectorAll('#wkBars i'))
  var setLabel = document.getElementById('wkSetLabel')
  var emptyBox = document.getElementById('wkEmpty')
  var doneBtn = document.getElementById('wkDone')
  var timerEl = document.getElementById('appTimer')
  var setIndex = 1          // 1-based：当前待完成的组号
  var completed = 0
  var elapsed = 76          // 与截图一致：01:16
  var timerId = 0

  function pad(n) {
    return n < 10 ? '0' + n : String(n)
  }

  function renderTimer() {
    if (!timerEl) return
    timerEl.textContent = pad(Math.floor(elapsed / 60)) + ':' + pad(elapsed % 60)
  }

  function startTimer() {
    if (timerId !== 0) return
    timerId = window.setInterval(function () {
      elapsed += 1
      renderTimer()
    }, 1000)
  }

  function stopTimer() {
    if (timerId === 0) return
    window.clearInterval(timerId)
    timerId = 0
  }

  // 离开训练屏时停表，避免后台空跑
  var observer = new MutationObserver(function () {
    if (app.getAttribute('data-active') !== 'workout') stopTimer()
  })
  observer.observe(app, { attributes: true, attributeFilter: ['data-active'] })
  renderTimer()

  if (doneBtn) {
    doneBtn.addEventListener('click', function () {
      if (setIndex > bars.length) {
        toast('本动作 5 组已完成')
        return
      }
      var bar = bars[setIndex - 1]
      bar.classList.remove('on')
      bar.classList.add('done')
      completed += 1

      if (setIndex < bars.length) {
        bars[setIndex].classList.add('on')
        setIndex += 1
        if (setLabel) setLabel.textContent = '第 ' + setIndex + ' 组 · 正式组'
        if (emptyBox) emptyBox.textContent = '已完成 ' + completed + ' 组'
        toast('已记录第 ' + completed + ' 组')
      } else {
        setIndex = bars.length + 1
        if (setLabel) setLabel.textContent = '本动作已完成'
        if (emptyBox) emptyBox.textContent = '已完成 ' + completed + ' 组 · 全部完成'
        stopTimer()
        toast('杠铃弯举完成 · 5 组')
      }
    })
  }

  // ── 回顾：周/月、肌肉地图三个视角 ──────────────────────────────────────
  var REVIEW_TEXT = {
    week: {
      head: '本周 · 10月26 – 11月1日',
      big: '状态不错，继续保持。',
      sub: '你比上周多完成了 1 次训练，平均训练时长也提升了 12 分钟。',
      note: '当前计划：五分化 · 已练 1 次',
      bars: [26, 100, 26, 26, 26, 26, 26],
      counts: ['1', '0', '--']
    },
    month: {
      head: '本月 · 10月1日 – 10月31日',
      big: '这个月稳住了节奏。',
      sub: '共完成 6 次训练，腿部与背部训练量最高，胸部仍有提升空间。',
      note: '当前计划：五分化 · 本月 6 次',
      bars: [40, 72, 100, 58, 34, 80, 52],
      counts: ['6', '214', '-0.4']
    }
  }

  var MUSCLE_VIEW = {
    balance: [['腿部', '高'], ['背部', '中'], ['胸部', '低'], ['手臂', '中']],
    fatigue: [['腿部', '需要休息'], ['背部', '可训练'], ['胸部', '可训练'], ['手臂', '可训练']],
    strength: [['腿部', '进步'], ['背部', '持平'], ['胸部', '待提升'], ['手臂', '进步']]
  }

  function setSegActive(group, target) {
    var buttons = Array.prototype.slice.call(group.querySelectorAll('button'))
    buttons.forEach(function (btn) { btn.classList.toggle('on', btn === target) })
  }

  app.addEventListener('click', function (event) {
    var goEl = event.target.closest('[data-go]')
    if (goEl) {
      go(goEl.getAttribute('data-go'))
      return
    }

    var rangeBtn = event.target.closest('[data-range]')
    if (rangeBtn) {
      var range = rangeBtn.getAttribute('data-range')
      var data = REVIEW_TEXT[range]
      if (!data) return
      setSegActive(rangeBtn.parentElement, rangeBtn)
      var panel = app.querySelector('[data-screen="review"]')
      var hero = panel.querySelector('.app-review-hero')
      var big = panel.querySelector('.app-review-big')
      var subs = panel.querySelectorAll('.app-review-sub')
      var bars = panel.querySelectorAll('.app-bars span')
      var counts = panel.querySelectorAll('.app-card.app-3 .app-metric .n')
      if (hero) hero.innerHTML = data.head + ' <span class="app-pill">' + (range === 'week' ? '一掉平' : '稳步升') + '</span>'
      if (big) big.textContent = data.big
      if (subs[0]) subs[0].textContent = data.sub
      if (subs[1]) subs[1].textContent = data.note
      data.bars.forEach(function (h, i) {
        if (!bars[i]) return
        bars[i].style.height = h + '%'
        bars[i].classList.toggle('hi', h === Math.max.apply(null, data.bars))
      })
      data.counts.forEach(function (value, i) {
        if (counts[i]) counts[i].textContent = value
      })
      return
    }

    var muscleBtn = event.target.closest('[data-muscle]')
    if (muscleBtn) {
      var view = muscleBtn.getAttribute('data-muscle')
      var rows = MUSCLE_VIEW[view]
      if (!rows) return
      setSegActive(muscleBtn.parentElement, muscleBtn)
      var cells = app.querySelectorAll('[data-screen="review"] .app-muscle div')
      rows.forEach(function (pair, i) {
        if (!cells[i]) return
        cells[i].innerHTML = pair[0] + '<b>' + pair[1] + '</b>'
      })
      return
    }

    // 我的页的两个入口：本演示未实现二级页，给一句明确反馈而不是死链
    var entry = event.target.closest('.app-entry')
    if (entry) {
      toast('演示版未包含「' + entry.textContent.trim() + '」页')
    }
  })

  // 训练屏的 ⌄ 退出（键盘可达）
  Array.prototype.slice.call(app.querySelectorAll('.back[data-go]')).forEach(function (el) {
    el.addEventListener('keydown', function (event) {
      if (event.key === 'Enter' || event.key === ' ') {
        event.preventDefault()
        go(el.getAttribute('data-go'))
      }
    })
  })

  // ── 进度环入场：滚动到可见时再画 ────────────────────────────────────────
  var phone = app.closest('.app-phone')
  if (phone) {
    if (reduceMotion || !('IntersectionObserver' in window)) {
      phone.classList.add('in-view')
    } else {
      var ringObserver = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return
          phone.classList.add('in-view')
          ringObserver.unobserve(phone)
        })
      }, { threshold: 0.35 })
      ringObserver.observe(phone)
    }
  }
})()
