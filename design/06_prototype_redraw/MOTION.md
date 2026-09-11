# FitTracker 界面重建 · 动效规格表（MOTION）

> 从冻结基线各屏 HTML `<style>` 自动提取。还原时按 
> `docs/opendesign-1to1-rules.md` 与 `docs/motion-restore-workflow.md` 映射到 ArkUI；
> 时长/曲线/按压缩放系数统一落到 `common/styles/DesignTokens.ets` MotionTokens。

口径：`transition/animation/transform` 声明 = 映射对象；`:active transform` = 按压反馈；
`@keyframes` = 关键帧序列；循环动画（如 pulse）只核对映射表不逐帧截。

生成：`python design/06_prototype_redraw/scripts/extract_specs.py`

## welcome · fittracker-welcome-home.html · 启动-欢迎页 (screen-welcome)

### transition / animation / transform 规则

| 选择器 | 声明 |
|---|---|
| `/* 欢迎页：430 设计空间 → 390 视口等比缩放 */ .w-frame` | `transform:scale(0.90698)` |
| `.w-cta .btn-primary` | `transition:filter .18s ease, box-shadow .18s ease, transform .12s ease` |
| `.w-cta .btn-primary:active` | `transform:scale(.985)` |
| `.today .btn-primary` | `transition:background .18s ease, box-shadow .18s ease, transform .12s ease` |
| `.today .btn-primary:active` | `transform:scale(.985)` |
| `.today .btn-ghost` | `transition:background .18s ease, border-color .18s ease` |
| `.week-head .count` | `transform:translateY(2px)` |
| `.week-day .dot` | `transition:background .18s ease, border-color .18s ease, box-shadow .18s ease` |
| `.week-day.active .dot::after` | `transform:translateY(-1px) rotate(-45deg)` |
| `.tab` | `transition:background .16s ease, color .16s ease` |
| `.tab-center .pill` | `transition:box-shadow .16s ease, transform .12s ease, filter .16s ease` |
| `.tab-center:active .pill` | `transform:scale(.96)` |

### :active 按压反馈

| 选择器 | 效果 |
|---|---|
| `.w-cta .btn-primary:active` | scale(.985) |
| `.today .btn-primary:active` | scale(.985) |
| `.tab-center:active .pill` | scale(.96) |

## home · fittracker-welcome-home.html · 首页 Tab (screen-home)

### transition / animation / transform 规则

| 选择器 | 声明 |
|---|---|
| `/* 欢迎页：430 设计空间 → 390 视口等比缩放 */ .w-frame` | `transform:scale(0.90698)` |
| `.w-cta .btn-primary` | `transition:filter .18s ease, box-shadow .18s ease, transform .12s ease` |
| `.w-cta .btn-primary:active` | `transform:scale(.985)` |
| `.today .btn-primary` | `transition:background .18s ease, box-shadow .18s ease, transform .12s ease` |
| `.today .btn-primary:active` | `transform:scale(.985)` |
| `.today .btn-ghost` | `transition:background .18s ease, border-color .18s ease` |
| `.week-head .count` | `transform:translateY(2px)` |
| `.week-day .dot` | `transition:background .18s ease, border-color .18s ease, box-shadow .18s ease` |
| `.week-day.active .dot::after` | `transform:translateY(-1px) rotate(-45deg)` |
| `.tab` | `transition:background .16s ease, color .16s ease` |
| `.tab-center .pill` | `transition:box-shadow .16s ease, transform .12s ease, filter .16s ease` |
| `.tab-center:active .pill` | `transform:scale(.96)` |

### :active 按压反馈

| 选择器 | 效果 |
|---|---|
| `.w-cta .btn-primary:active` | scale(.985) |
| `.today .btn-primary:active` | scale(.985) |
| `.tab-center:active .pill` | scale(.96) |

## login · fittracker-auth.html · 登录 (screen-login)

### transition / animation / transform 规则

| 选择器 | 声明 |
|---|---|
| `/* 430 设计空间 → 390 视口等比缩放 */ .auth-frame` | `transform:scale(var(--active-scale))` |
| `.control` | `transition:border-color .18s ease, background .18s ease, box-shadow .18s ease` |
| `.control .toggle` | `transition:color .18s ease` |
| `.auth-link` | `transition:color .18s ease` |
| `.check` | `transition:background .16s ease, border-color .16s ease` |
| `.check:checked::after` | `transform:rotate(-45deg) translateY(-1px)` |
| `/* ─── 主操作 ───────────────────────────────────────────────────────────── */ .auth-cta` | `transition:background .18s ease, box-shadow .18s ease, transform .12s ease` |
| `.auth-cta:active` | `transform:scale(.985)` |
| `.auth-social .soc` | `transition:background .18s ease, border-color .18s ease` |
| `/* ─── 轻量反馈 Toast（置于手机画布内，不随设计空间缩放） ─────────────── */ .auth-toast` | `transform:translateX(-50%) translateY(12px); transition:opacity .18s ease, transform .18s ease` |
| `.auth-toast.show` | `transform:translateX(-50%) translateY(0)` |

### :active 按压反馈

| 选择器 | 效果 |
|---|---|
| `.auth-cta:active` | scale(.985) |

## register · fittracker-auth.html · 注册 (screen-register)

### transition / animation / transform 规则

| 选择器 | 声明 |
|---|---|
| `/* 430 设计空间 → 390 视口等比缩放 */ .auth-frame` | `transform:scale(var(--active-scale))` |
| `.control` | `transition:border-color .18s ease, background .18s ease, box-shadow .18s ease` |
| `.control .toggle` | `transition:color .18s ease` |
| `.auth-link` | `transition:color .18s ease` |
| `.check` | `transition:background .16s ease, border-color .16s ease` |
| `.check:checked::after` | `transform:rotate(-45deg) translateY(-1px)` |
| `/* ─── 主操作 ───────────────────────────────────────────────────────────── */ .auth-cta` | `transition:background .18s ease, box-shadow .18s ease, transform .12s ease` |
| `.auth-cta:active` | `transform:scale(.985)` |
| `.auth-social .soc` | `transition:background .18s ease, border-color .18s ease` |
| `/* ─── 轻量反馈 Toast（置于手机画布内，不随设计空间缩放） ─────────────── */ .auth-toast` | `transform:translateX(-50%) translateY(12px); transition:opacity .18s ease, transform .18s ease` |
| `.auth-toast.show` | `transform:translateX(-50%) translateY(0)` |

### :active 按压反馈

| 选择器 | 效果 |
|---|---|
| `.auth-cta:active` | scale(.985) |

## plan · fittracker-plan.html · 计划 Tab (screen-plan)

### transition / animation / transform 规则

| 选择器 | 声明 |
|---|---|
| `.deck-card.pos-front` | `transform:translateX(0) translateY(0) rotate(0deg) scale(1)` |
| `.deck-card.pos-prev` | `transform:translateX(-86%) translateY(16px) rotate(-6deg) scale(.82)` |
| `.deck-card.pos-next` | `transform:translateX(86%) translateY(16px) rotate(6deg) scale(.82)` |
| `.deck-card.pos-off-l` | `transform:translateX(-110%) rotate(-8deg) scale(.72)` |
| `.deck-card.pos-off-r` | `transform:translateX(110%) rotate(8deg) scale(.72)` |
| `.deck.dragging .pos-front` | `transition:none` |
| `.tab` | `transition:background .16s ease, color .16s ease` |
| `.tab-center .pill` | `transition:box-shadow .16s ease, transform .12s ease, filter .16s ease` |
| `.tab-center:active .pill` | `transform:scale(.96)` |

### :active 按压反馈

| 选择器 | 效果 |
|---|---|
| `.tab-center:active .pill` | scale(.96) |

## workout · fittracker-training-preview.html · 训练 Tab-预览 (screen-training-preview)

### transition / animation / transform 规则

| 选择器 | 声明 |
|---|---|
| `.pv-icon-btn` | `transition:background .18s var(--ease), border-color .18s var(--ease), color .18s var(--ease), transform .12s var(--ease)` |
| `.pv-icon-btn:active` | `transform:scale(.96)` |
| `.pv-eyebrow` | `transform:uppercase` |
| `.pv-btn-primary` | `transition:filter .18s var(--ease), box-shadow .18s var(--ease), transform .12s var(--ease)` |
| `.pv-btn-primary:active` | `transform:scale(.985)` |
| `/* 开始训练的轻量反馈 */ .pv-toast` | `transform:translateX(-50%) translateY(10px); transition:opacity .18s var(--ease), transform .18s var(--ease)` |
| `.pv-toast.show` | `transform:translateX(-50%) translateY(0)` |

### :active 按压反馈

| 选择器 | 效果 |
|---|---|
| `.pv-icon-btn:active` | scale(.96) |
| `.pv-btn-primary:active` | scale(.985) |

## plans · fittracker-plan-detail.html · 计划组 (screen-plan-detail)

### transition / animation / transform 规则

| 选择器 | 声明 |
|---|---|
| `.pd-back` | `transition:background .16s ease, color .16s ease` |
| `.pg-card` | `transition:background .16s ease, border-color .16s ease, transform .12s ease` |
| `.pg-card:active` | `transform:scale(.99)` |
| `/* toast */ .pd-toast` | `transform:translateX(-50%) translateY(10px); transition:opacity .18s ease, transform .18s ease` |
| `.pd-toast.show` | `transform:translateX(-50%) translateY(0)` |

### :active 按压反馈

| 选择器 | 效果 |
|---|---|
| `.pg-card:active` | scale(.99) |

## planGroup · fittracker-plan-group-detail.html · 计划组详细 (screen-plan-group-detail)

### transition / animation / transform 规则

| 选择器 | 声明 |
|---|---|
| `.pgd-back` | `transition:background .16s var(--ease), color .16s var(--ease)` |
| `.pgd-back:active` | `transform:scale(.94)` |
| `.pgd-day-tab` | `transition:background .16s var(--ease), border-color .16s var(--ease), color .16s var(--ease), transform .12s var(--ease)` |
| `.pgd-day-tab:active` | `transform:scale(.98)` |
| `.pgd-ex` | `transition:background .16s var(--ease), border-color .16s var(--ease), transform .12s var(--ease)` |
| `.pgd-ex:active` | `transform:scale(.99)` |
| `.pgd-cta` | `transition:filter .16s var(--ease), transform .12s var(--ease)` |
| `.pgd-cta:active` | `transform:scale(.985)` |
| `/* toast */ .pgd-toast` | `transform:translateX(-50%) translateY(10px); transition:opacity .18s var(--ease), transform .18s var(--ease)` |
| `.pgd-toast.show` | `transform:translateX(-50%) translateY(0)` |

### :active 按压反馈

| 选择器 | 效果 |
|---|---|
| `.pgd-back:active` | scale(.94) |
| `.pgd-day-tab:active` | scale(.98) |
| `.pgd-ex:active` | scale(.99) |
| `.pgd-cta:active` | scale(.985) |

## active · fittracker-training.html · 训练执行 (screen-training)

### @keyframes

| 名称 | 关键帧% |
|---|---|
| `livePulse` | 100% |
| `recordIn` | from |
| `backdropIn` | from |
| `modalIn` | from |
| `veilIn` | from |
| `veilOut` | from |
| `confettiFly` | 0% |
| `coreIn` | 0% |
| `markerPop` | from |
| `segPop` | 0% |

### transition / animation / transform 规则

| 选择器 | 声明 |
|---|---|
| `.top-timer .live-dot` | `animation:livePulse 1.6s ease infinite` |
| `.duo-marker` | `transform:translate(-50%, -50%)` |
| `.set-record` | `animation:recordIn .18s var(--ease) both` |
| `.wo-btn-primary` | `transition:filter .18s ease, box-shadow .18s ease, transform .12s ease` |
| `.wo-btn-primary:active` | `transform:scale(.985)` |
| `.btn-ghost` | `transition:background .16s ease` |
| `.modal.open` | `animation:backdropIn .22s ease both` |
| `.modal-card` | `animation:modalIn .22s var(--ease)` |
| `.modal-close` | `transition:background .16s ease, color .16s ease` |
| `.stepper .step` | `transition:background .16s ease` |
| `.celebrate.playing` | `animation:veilIn .22s var(--ease) both` |
| `.celebrate.fading` | `animation:veilOut .3s var(--ease) forwards` |
| `.confetti` | `transform:translate(-50%, -50%) rotate(0deg); animation:confettiFly 1.1s cubic-bezier(.16, .7, .3, 1) both` |
| `.celebrate-core` | `transform:translate(-50%, -50%)` |
| `.celebrate.playing .celebrate-core` | `animation:coreIn .46s var(--ease) .06s both` |
| `/* 进度条填充反馈 */ .duo-marker` | `animation:markerPop .3s var(--ease)` |
| `.duo-seg.just-done` | `animation:segPop .46s var(--ease)` |

### :active 按压反馈

| 选择器 | 效果 |
|---|---|
| `.wo-btn-primary:active` | scale(.985) |

## complete · fittracker-training-complete.html · 训练完成 (screen-training-complete)

### @keyframes

| 名称 | 关键帧% |
|---|---|
| `cf-fall` | 0% |
| `cf-pop` | 0% |
| `cf-rise` | from |

### transition / animation / transform 规则

| 选择器 | 声明 |
|---|---|
| `/* ── 训练完成页（430 设计空间 → 390 视口等比缩放） ─────────── */ .cf-frame` | `transform:scale(var(--scale))` |
| `.cf-badge` | `animation:cf-pop .5s var(--ease) .05s both` |
| `.cf-title` | `animation:cf-rise .45s var(--ease) .16s both` |
| `.cf-sub` | `animation:cf-rise .45s var(--ease) .26s both` |
| `/* ── 连续记录 chip ─────────────────────────────────────────── */ .cf-streak` | `animation:cf-rise .5s var(--ease) .36s both` |
| `/* ── 底部固定操作区 ────────────────────────────────────────── */ .cf-dock` | `animation:cf-rise .5s var(--ease) .6s both` |
| `.cf-btn` | `transition:filter .18s ease, box-shadow .18s ease, background .18s ease, border-color .18s ease, transform .12s ease` |
| `.cf-btn-primary:active` | `transform:scale(.985)` |
| `/* ── confetti（唯一装饰动效，aria-hidden） ──────────────────── */ .confetti-layer` | `transition:opacity .5s ease` |
| `.confetti-piece` | `animation:cf-fall var(--dur, 2.6s) var(--delay, 0s) cubic-bezier(.2, .55, .35, 1) forwards` |
| `/* ── toast ─────────────────────────────────────────────────── */ .cf-toast` | `transform:translateX(-50%) translateY(10px); transition:opacity .18s ease, transform .18s ease` |
| `.cf-toast.show` | `transform:translateX(-50%) translateY(0)` |

### :active 按压反馈

| 选择器 | 效果 |
|---|---|
| `.cf-btn-primary:active` | scale(.985) |

## review · fittracker-review.html · 训练回顾 Tab (screen-review)

### transition / animation / transform 规则

| 选择器 | 声明 |
|---|---|
| `.seg-btn` | `transition:background .18s ease, color .18s ease, transform .12s ease` |
| `.seg-btn:active` | `transform:scale(.97)` |
| `.tab` | `transition:background .16s ease, color .16s ease` |
| `.tab-center .pill` | `transition:box-shadow .16s ease, transform .12s ease, filter .16s ease` |
| `.tab-center:active .pill` | `transform:scale(.96)` |
| `.openstats .seg .seg-btn` | `transition:background .18s ease, color .18s ease` |
| `.openstats .bm-m` | `transition:fill var(--med) var(--ease)` |
| `/* 体重目标按钮 + 弹窗（冷翡翠） */ .goal-btn` | `transition:background .18s ease, color .18s ease, border-color .18s ease` |
| `.goal-btn:active` | `transform:scale(.97)` |

### :active 按压反馈

| 选择器 | 效果 |
|---|---|
| `.seg-btn:active` | scale(.97) |
| `.tab-center:active .pill` | scale(.96) |
| `.goal-btn:active` | scale(.97) |

## library · fittracker-exercise-library.html · 动作库 (screen-exercise-library)

### transition / animation / transform 规则

| 选择器 | 声明 |
|---|---|
| `.st-back` | `transition:background .18s var(--ease), border-color .18s var(--ease), color .18s var(--ease), transform .12s var(--ease)` |
| `.st-back:active` | `transform:scale(.94)` |
| `/* ── 动作库组件 ────────────────────────────────────────────────────────── */ .lib-fav-filter` | `transition:background .18s var(--ease), border-color .18s var(--ease), color .18s var(--ease), transform .12s var(--ease)` |
| `.lib-fav-filter:active` | `transform:scale(.94)` |
| `.lib-search` | `transition:border-color .18s var(--ease), background .18s var(--ease)` |
| `.cat-chip` | `transition:background .16s var(--ease), border-color .16s var(--ease), color .16s var(--ease)` |
| `.lib-card` | `transition:background .18s var(--ease), border-color .18s var(--ease), transform .12s var(--ease)` |
| `.lib-card:active` | `transform:scale(.985)` |
| `.lib-fav` | `transition:color .16s var(--ease), background .16s var(--ease), border-color .16s var(--ease), transform .12s var(--ease)` |
| `.lib-fav:active` | `transform:scale(.9)` |
| `.lib-sheet-backdrop` | `transition:opacity .22s var(--ease)` |
| `.lib-sheet-card` | `transform:translateY(100%); transition:transform .28s cubic-bezier(.32, .72, .3, 1)` |
| `.lib-sheet.open .lib-sheet-card` | `transform:translateY(0)` |
| `.lib-sheet-close` | `transition:background .16s var(--ease), color .16s var(--ease)` |
| `.lib-sheet-cta` | `transition:filter .16s var(--ease), transform .12s var(--ease)` |
| `.lib-sheet-cta:active` | `transform:scale(.985)` |
| `.st-toast` | `transform:translateX(-50%) translateY(10px); transition:opacity .18s var(--ease), transform .18s var(--ease)` |
| `.st-toast.show` | `transform:translateX(-50%) translateY(0)` |

### :active 按压反馈

| 选择器 | 效果 |
|---|---|
| `.st-back:active` | scale(.94) |
| `.lib-fav-filter:active` | scale(.94) |
| `.lib-card:active` | scale(.985) |
| `.lib-fav:active` | scale(.9) |
| `.lib-sheet-cta:active` | scale(.985) |

## body · fittracker-body-data.html · 身体数据 (screen-body-data)

### transition / animation / transform 规则

| 选择器 | 声明 |
|---|---|
| `.bd-back` | `transition:background .18s ease, border-color .18s ease, color .18s ease, transform .12s ease` |
| `.bd-back:active` | `transform:scale(.94)` |
| `.goal-fill` | `transition:width .35s var(--ease, cubic-bezier(.32,.72,.3,1))` |
| `.fat-marker` | `transform:translateX(-50%)` |
| `.seg button` | `transition:background .16s ease, color .16s ease` |
| `/* ── 主操作 ───────────────────────────────────────────────────────── */ .bd-cta` | `transition:filter .16s ease, transform .12s ease, box-shadow .16s ease` |
| `.bd-cta:active` | `transform:scale(.98)` |
| `.sheet-backdrop` | `transition:opacity .2s ease` |
| `.sheet` | `transform:translateY(102%); transition:transform .3s cubic-bezier(.32,.72,.3,1)` |
| `.sheet-layer.open .sheet` | `transform:translateY(0)` |
| `.sheet-save` | `transition:filter .16s ease, transform .12s ease` |
| `.sheet-cancel` | `transition:background .16s ease, color .16s ease` |

### :active 按压反馈

| 选择器 | 效果 |
|---|---|
| `.bd-back:active` | scale(.94) |
| `.bd-cta:active` | scale(.98) |

## profile · fittracker-personal.html · 我的 Tab (screen-personal)

### transition / animation / transform 规则

| 选择器 | 声明 |
|---|---|
| `.p-settings` | `transition:background .18s ease, border-color .18s ease, color .18s ease, transform .12s ease` |
| `.p-settings:active` | `transform:scale(.96)` |
| `.shortcut` | `transition:background .18s ease, border-color .18s ease, transform .12s ease` |
| `.shortcut:active` | `transform:scale(.98)` |
| `.tab` | `transition:background .16s ease, color .16s ease` |
| `.tab-center .pill` | `transition:box-shadow .16s ease, transform .12s ease, filter .16s ease` |
| `.tab-center:active .pill` | `transform:scale(.96)` |
| `.subpage` | `transform:translateX(100%); transition:transform .28s cubic-bezier(.32, .72, .3, 1), visibility 0s linear .28s` |
| `.subpage.open` | `transform:translateX(0); transition:transform .28s cubic-bezier(.32, .72, .3, 1)` |
| `.sub-back` | `transition:background .18s ease, border-color .18s ease, color .18s ease, transform .12s ease` |
| `.sub-back:active` | `transform:scale(.94)` |
| `.sr-value` | `transition:color .16s ease` |
| `.seg button` | `transition:background .16s ease, color .16s ease` |
| `.switch` | `transition:background .18s ease, border-color .18s ease` |
| `.switch::after` | `transition:transform .18s cubic-bezier(.32, .72, .3, 1), background .18s ease` |
| `.switch.on::after` | `transform:translateX(18px)` |
| `/* ── 动作库 ────────────────────────────────────────────────────────────── */ .lib-fav-filter` | `transition:background .18s ease, border-color .18s ease, color .18s ease, transform .12s ease` |
| `.lib-fav-filter:active` | `transform:scale(.94)` |
| `.lib-search` | `transition:border-color .18s ease, background .18s ease` |
| `.lib-chip` | `transition:background .16s ease, border-color .16s ease, color .16s ease` |
| `.lib-card` | `transition:background .18s ease, border-color .18s ease, transform .12s ease` |
| `.lib-card:active` | `transform:scale(.985)` |
| `.lib-fav` | `transition:color .16s ease, background .16s ease, border-color .16s ease, transform .12s ease` |
| `.lib-fav:active` | `transform:scale(.9)` |
| `.lib-sheet-backdrop` | `transition:opacity .22s ease` |
| `.lib-sheet-card` | `transform:translateY(100%); transition:transform .28s cubic-bezier(.32, .72, .3, 1)` |
| `.lib-sheet.open .lib-sheet-card` | `transform:translateY(0)` |
| `.lib-sheet-close` | `transition:background .16s ease, color .16s ease` |
| `.lib-sheet-cta` | `transition:filter .16s ease, transform .12s ease` |
| `.lib-sheet-cta:active` | `transform:scale(.985)` |
| `.cat-chip` | `transition:background .16s ease, border-color .16s ease, color .16s ease` |
| `.lib-card` | `transition:background .18s ease, border-color .18s ease, transform .12s ease` |
| `.lib-card:active` | `transform:scale(.985)` |
| `.lib-fav` | `transition:color .16s ease, background .16s ease, border-color .16s ease, transform .12s ease` |
| `.lib-fav:active` | `transform:scale(.9)` |
| `.lib-sheet-backdrop` | `transition:opacity .22s ease` |
| `.lib-sheet-card` | `transform:translateY(100%); transition:transform .28s cubic-bezier(.32, .72, .3, 1)` |
| `.lib-sheet.open .lib-sheet-card` | `transform:translateY(0)` |
| `.lib-sheet-close` | `transition:background .16s ease, color .16s ease` |
| `.lib-sheet-cta` | `transition:filter .16s ease, transform .12s ease` |
| `.lib-sheet-cta:active` | `transform:scale(.985)` |
| `.lib-toast` | `transform:translateX(-50%) translateY(10px); transition:opacity .18s ease, transform .18s ease` |
| `.lib-toast.show` | `transform:translateX(-50%) translateY(0)` |

### :active 按压反馈

| 选择器 | 效果 |
|---|---|
| `.p-settings:active` | scale(.96) |
| `.shortcut:active` | scale(.98) |
| `.tab-center:active .pill` | scale(.96) |
| `.sub-back:active` | scale(.94) |
| `.lib-fav-filter:active` | scale(.94) |
| `.lib-card:active` | scale(.985) |
| `.lib-fav:active` | scale(.9) |
| `.lib-sheet-cta:active` | scale(.985) |
| `.lib-card:active` | scale(.985) |
| `.lib-fav:active` | scale(.9) |
| `.lib-sheet-cta:active` | scale(.985) |

## settings · fittracker-settings.html · 设置 (screen-settings)

### transition / animation / transform 规则

| 选择器 | 声明 |
|---|---|
| `.st-back` | `transition:background .18s var(--ease), border-color .18s var(--ease), color .18s var(--ease), transform .12s var(--ease)` |
| `.st-back:active` | `transform:scale(.94)` |
| `.sr-value` | `transition:color .16s var(--ease)` |
| `.sr-chev` | `transition:color .16s var(--ease)` |
| `.seg button` | `transition:background .16s var(--ease), color .16s var(--ease)` |
| `.switch` | `transition:background .18s var(--ease), border-color .18s var(--ease)` |
| `.switch::after` | `transition:transform .18s var(--ease), background .18s var(--ease)` |
| `.switch.on::after` | `transform:translateX(18px)` |
| `/* 轻量反馈 */ .st-toast` | `transform:translateX(-50%) translateY(10px); transition:opacity .18s var(--ease), transform .18s var(--ease)` |
| `.st-toast.show` | `transform:translateX(-50%) translateY(0)` |

### :active 按压反馈

| 选择器 | 效果 |
|---|---|
| `.st-back:active` | scale(.94) |

