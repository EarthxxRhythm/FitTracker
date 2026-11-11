# FitTracker 官网视觉审查（impeccable · 2026-11-11）

> 审查对象：`earthxxrhythm.github.io/FitTracker/`（当前 master `3b3bc5a` 部署）与 `web/src` 源码
> 方法：impeccable `reference/audit.md` 五维度 + 本地源码取证 + 无头 Chrome 实测
> 引擎状态：`impeccable context` 因引擎二进制下载不完整（`Exec format error`）未能运行，按 SKILL 的 fallback 直接读项目上下文
> 本次只出报告，未修改任何代码

## 结论

站点存在一个 **P0 级系统性缺陷**：`web/src/legacy.css` 的 CSS 变量定义块被误删，导致全文 34 个变量引用失效。这不是本次部署引入的，是 `357b9d5`“死类清理”造成的，因为此前从未成功部署到线上，直到 2026-11-11 才第一次暴露。

## 评分

| # | 维度 | 分数 | 关键发现 |
|---|------|------|---------|
| 1 | Accessibility | 2/4 | `prefers-reduced-motion` 用全局 `0.01ms` kill，抹掉全部过渡反馈；其余语义结构良好 |
| 2 | Performance | 3/4 | 代码分割与懒加载到位；主包 382 kB 偏大但已把 Remotion 357 kB 拆出 |
| 3 | Theming | **1/4** | **令牌层脱节：34 个变量未定义**，圆角/过渡/间距/按压全部回退到初始值 |
| 4 | Responsive | 2/4 | 断点齐全（1024/860/720），但 `overflow-x: hidden` 掩盖了真实溢出 |
| 5 | Implementation Integrity | **1/4** | 单一根因造成的全局视觉漂移，且门禁未能捕获 |

## P0 · 令牌定义被整体删除

### 证据

`web/src/legacy.css` 顶部原本有一个 `:root` 令牌块，`357b9d5` 把它整段删除：

```diff
-/* ── 1. 令牌 ─────────────────────────────────────────────────────────────── */
-:root {
-  --bg: #0E100D;  --bg-2: #0F1716;  --surface: #101810;  --surface-2: #1B2A27;
-  --border: #2A3934;
-  --primary: #4CECA4;  --primary-deep: #45C9A1;  --primary-soft: #8CEBCC;  --gold: #B59869;
-  --text: #EDF6F2;  --text-2: #A3B3AD;  --text-3: #7A8D85;  --text-on-primary: #09100F;
-  --ease-motion: ...;  --ease-enter: ...;  --ease-out-duo: ...;  --ease-back-out: ...;
-  --dur-micro: 120ms;  --dur-fast: 150ms;  --dur-base: 250ms;  --dur-enter: 320ms;
-  --dur-stagger: 40ms;  --dur-ring: 1200ms;  --dur-pulse: 1600ms;
-  --press-depth: 4px;
-}
```

而 `web/src/index.css` 定义的是 Tailwind v4 的 `--color-*` 新命名（`--color-ink`、`--color-fg`、`--color-brand`…），两套命名之间**没有别名映射**。

验证（构建产物 `dist/assets/index-DN3xVpnF.css`）：

- `--bg:` 定义数 **0**
- `var(--bg)` 引用 **5** 处
- `var(--text-3)` 引用 **10** 处
- 未定义就被引用的变量共 **34** 个

### 影响

颜色靠 `index.css` 的 `@layer base` 里的 body 规则兜住了，所以页面底色和正文色看起来还对。但**尺寸与动效没有兜底**：

| 变量 | 引用次数 | 失效后果 |
|------|---------|---------|
| `--radius-pill` | 6 | 药丸形圆角 → 直角 |
| `--dur-fast` | 10 | 快速过渡消失（hover 无反馈） |
| `--radius-lg` | 3 | 大圆角 → 直角 |
| `--dur-base` | 2 | 基础过渡消失 |
| `--gutter` / `--maxw` / `--section-y` / `--radius-card` / `--press-depth` | 各 1 | 内边距 / 最大宽度 / 段落间距 / 卡片圆角 / 按压深度 |

用户反馈的“样式全乱了”，观感上就是**卡片变直角、悬停没反应、间距塌陷**。

### 为什么会发生

impeccable 的死类检测按「类名是否在 TSX 中出现」判断，`:root` 里的变量声明不是类名，被一并当作死代码清理。`check-gates.mjs` 的八条门禁里没有一条能发现「CSS 引用了未定义的变量」。

### 修复方向（未执行）

二选一，不要两套并存：

1. **恢复 `:root` 块**（最小改动，`git show 357b9d5^:web/src/legacy.css | head -40` 可取回原值）
2. **建立别名层**，把旧名映射到新令牌，避免再次漂移：
   ```css
   :root {
     --bg: var(--color-ink);
     --text: var(--color-fg);
     --primary: var(--color-brand);
     --radius-pill: 999px;
     --dur-fast: 150ms;
     /* …其余 30 个 */
   }
   ```

推荐 2：单一真源在 `index.css`，`legacy.css` 只做消费。同时应在门禁里加一条「CSS 引用的变量必须有定义」。

## P1 · 减弱动效的降级方式不可接受

`web/src/index.css:74-81`：

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: .01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: .01ms !important;
  }
}
```

`audit.md` 明确把「全局 `0.01ms` kill」列为需要点名的反模式：它连同**有意义的状态反馈**（hover、focus、展开）一起抹掉，而不是给出一个保留状态变化与层级关系的替代方案。

组件侧其实做对了（`Aurora.tsx:109`、`PointerFx.tsx:29` 都在 `reduce` 时直接不挂载），问题只在这条 CSS 全局兜底。

## P2 · `overflow-x: hidden` 掩盖横向溢出

`legacy.css` 与 `index.css` 的 body 规则都设了 `overflow-x: hidden`。它会隐藏真实的横向溢出，让响应式问题在正常情况下不可见。建议改为先定位再修，而不是由 body 兜底。

## 做得好的地方

- **语义结构**：`header / nav / main / section / article / h1–h4` 层级完整，`<h1>` 唯一
- **无障碍属性**：20 处 `aria-*`；`nav aria-label="主导航"`；装饰性 SVG 全部 `aria-hidden`
- **图片**：两处 `<img>` 都有描述性 `alt`，且带 `loading="lazy" decoding="async"`
- **键盘可达**：`:focus-visible { outline: 2px solid var(--color-brand); outline-offset: 3px }`
- **无 div-onclick**：交互元素全部是 `<a>` 或 `<button>`，`<div onClick>` 数量为 0
- **性能**：`JourneyPlayer` 走 `lazy` + `Suspense`，把 357 kB 的 Remotion 编排出主包
- **设计令牌**：`index.css` 的 `@theme` 逐条转录自 `DesignTokens.ets`，注释带源码行号，可追溯

## 建议修复顺序

| 优先级 | 项 | 理由 |
|--------|----|------|
| P0 | 恢复/补齐 34 个变量定义 | 直接决定页面观感，是“全乱”的唯一根因 |
| P1 | 改写 `prefers-reduced-motion` 策略 | 影响可访问性合规 |
| P2 | 移除 `overflow-x: hidden` 兜底并实测窄屏 | 隐藏问题会持续累积 |
| P3 | 门禁增加「CSS 变量必须有定义」检查 | 防止复发，比修一次更有价值 |

## 未覆盖

- 未做真实设备/触摸手势验证（`audit.md` 对 drag 表面的要求未执行）
- 未测对比度数值（`--text-3` 注释称 5.44:1，本轮未独立复算）
- 引擎 detector 未运行，第五维度的自动化发现缺失，仅以人工取证替代
