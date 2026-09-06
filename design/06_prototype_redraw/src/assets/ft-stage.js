/* FitTracker 连续 App 舞台脚本
   仅在 URL 带 ?stage=1 时生效：隐藏原型文档外壳，只保留指定 frame，
   并把页面内「底部 Tab / 返回 / 主 CTA」转成对父级舞台的跳转消息。 */
(function () {
  if (!/stage=1/.test(location.search)) { return; }
  if (window.__ftStageBooted) { return; }
  window.__ftStageBooted = true;

  var rid = '';
  try {
    rid = new URLSearchParams(location.search).get('frame') || '';
  } catch (e) { /* ignore */ }

  document.documentElement.classList.add('od-stage');

  var css = document.createElement('style');
  css.textContent = [
    'html.od-stage, html.od-stage body { margin:0 !important; padding:0 !important; background:#0B0F13 !important; overflow:hidden !important; }',
    'html.od-stage .page-header, html.od-stage .page-foot, html.od-stage .stage-label, html.od-stage .meta-row { display:none !important; }',
    'html.od-stage .gallery { max-width:none !important; width:100% !important; min-height:100vh !important; margin:0 !important; padding:0 !important; gap:0 !important; display:flex !important; align-items:center !important; justify-content:center !important; }',
    'html.od-stage .frame-card { display:none !important; margin:0 !important; }',
    'html.od-stage .frame-card.od-active { display:block !important; }',
    'html.od-stage .phone { transform:none !important; margin:0 auto !important; border-radius:46px !important; box-shadow:none !important; border-color:rgba(255,255,255,0) !important; }'
  ].join('\n');
  document.head.appendChild(css);

  var cards = document.querySelectorAll('.frame-card');
  var shown = false;
  for (var i = 0; i < cards.length; i += 1) {
    var card = cards[i];
    if (card.getAttribute('data-od-id') === rid) {
      card.classList.add('od-active');
      shown = true;
    } else {
      card.style.display = 'none';
    }
  }
  if (!shown && cards.length > 0) { cards[0].classList.add('od-active'); }

  function post(msg) {
    if (window.parent && window.parent !== window) {
      try { window.parent.postMessage(msg, '*'); } catch (e) { /* ignore */ }
    }
  }

  function notifyReady() {
    post({ type: 'ft-app:ready', payload: { screen: rid } });
  }

  function bootReady() {
    if (document.readyState === 'loading') {
      window.addEventListener('load', function () { notifyReady(); });
    } else {
      window.requestAnimationFrame(notifyReady);
      window.setTimeout(notifyReady, 320);
    }
  }
  bootReady();

  var cfg = window.FT_APP || {};
  var routes = cfg.routes || [];

  function navigate(to) {
    post({ type: 'ft-app:navigate', payload: { to: to } });
  }

  document.addEventListener('click', function (e) {
    var t = e.target;
    if (!t || !t.closest) { return; }

    var tab = t.closest('[data-tab]');
    if (tab) {
      var key = tab.getAttribute('data-tab');
      if (key) {
        var pane = document.querySelector('.pane[data-pane="' + key + '"]');
        var real = pane && !pane.querySelector('.pane-placeholder');
        if (!real) {
          e.preventDefault();
          if (e.stopImmediatePropagation) { e.stopImmediatePropagation(); }
          if (e.stopPropagation) { e.stopPropagation(); }
          var tabMap = { home: 'home', plan: 'plan', workout: 'workout', review: 'review', profile: 'profile' };
          navigate(tabMap[key] || key);
          return;
        }
      }
    }

    for (var i = 0; i < routes.length; i += 1) {
      var hit = t.closest(routes[i][0]);
      if (hit) {
        e.preventDefault();
        if (e.stopImmediatePropagation) { e.stopImmediatePropagation(); }
        if (e.stopPropagation) { e.stopPropagation(); }
        navigate(routes[i][1]);
        return;
      }
    }
  }, true);

  if (cfg.afterAuth) {
    document.addEventListener('submit', function (e) {
      var form = e.target;
      if (!form || !form.closest || !form.closest('.auth-screen')) { return; }
      var screen = form.closest('.auth-screen');
      var toast = screen.querySelector('.auth-toast');
      window.setTimeout(function () {
        if (toast && /成功/.test(toast.textContent)) {
          navigate('home');
        }
      }, 900);
    }, false);
  }

  if (cfg.watchFinish) {
    var finishBtn = document.getElementById('btn-complete');
    if (finishBtn) {
      finishBtn.addEventListener('click', function () {
        window.setTimeout(function () {
          var label = document.querySelector('.progress-label');
          if (label && label.textContent.indexOf('训练完成') >= 0) {
            navigate('complete');
          }
        }, 950);
      });
    }
  }
})();
