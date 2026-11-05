# web/src 与 site · 分区边界 / 重复实现审计台账

- 任务：`team:audit-web-site`（只读审计，未修改任何源码）
- 审计对象：`web\src`（18 个文件）+ `site`（19 个文件），另含作为构建口径证据的 `web\public`、`web\dist`、`tools\build-site.mjs`、`tools\check-site.mjs`
- 生成时间：2026-11（worktree HEAD = `23abd74`）
- 台账用途：重构的唯一依据。所有条目均附 file:line 与可复现命令。

## 0. 口径声明（回应计划约束「计数单位不一」）

本台账统一两个单位，**不混用**：

| 记号 | 含义 |
|---|---|
| `N 文件` | 离散文件个数 |
| `N 处` | 离散**引用点**个数（一次 import 行 / 一次 `var()` 引用 / 一次 hex 字面量出现），同一文件内多处分别计数 |

凡出现「处」均按引用点计，可直接用第 0.1 节命令复算。

### 0.1 复现命令（全部已在本 worktree 执行）

```bash
# 内联色值：文件级次数
grep -roE "#[0-9a-fA-F]{3,8}\b" web/src | wc -l                     # → 54
for f in $(grep -rlE "#[0-9a-fA-F]{3,8}\b" web/src); do \
  echo "$(grep -oE "#[0-9a-fA-F]{3,8}\b" $f | wc -l) $f"; done      # → App2/board12/index17/Journey8/legacy15
for f in $(grep -rlE "#[0-9a-fA-F]{3,8}\b" site --include=*.css --include=*.js --include=*.html); do \
  echo "$(grep -oE "#[0-9a-fA-F]{3,8}\b" $f | wc -l) $f"; done      # → app-demo.css 69 等，合计 112

# CSS 变量未定义核对（脚本见 §A2，内联 node -e，无落盘探针）
node -e "…legacy.css var() 集合 − index.css+legacy.css 定义集合…"

# 副本一致性
md5sum site/assets/site.css web/public/assets/site.css site/index.html web/index.html \
       site/privacy.html web/public/legal/privacy.html \
       site/assets/img/logo-ring.svg web/public/logo-ring.svg web/public/assets/img/logo-ring.svg

# CSS 分叉度
diff --strip-trailing-cr web/src/legacy.css site/assets/site.css | grep -c "^[<>]"   # → 1202
```

---

## A. 分区边界

| ID | 问题类型 | 影响面 | 优先级 | file:line 依据 | 证据 / 结论 |
|---|---|---|---|---|---|
| A1 | 边界模糊：两个完整首页并存 | 官网对外呈现、文档/部署口径 | **P0** | `site\index.html:1-654`（静态，section 在 71/349/375/432/494/533/578）；`web\src\App.tsx:1-419`（React，section=bento/journey/muscle/growth） | 两份**不是同一页面的两种实现**，而是两套版式：site 有「数字条(stats) / 训练闭环 sticky(flow) / 截图画廊(gallery) / 数据与隐私(privacy) / 技术底子」，web 有「JourneyFilm / 肌群矩阵 / 成长路径」，互不覆盖。`site\README.md` 的部署段只同步 `site\`（→ `/opt/fittracker/site/`），`web\README.md` + `web\vite.config.ts:16` 产物落 `web\dist`，**线上到底发哪一份没有单一事实源**。重构前必须先裁定：site 为现网、web 为重写中，或反之。 |
| A2 | **半份副本导致令牌悬空** | web 版官网主色/字号/圆角/间距/动效时长全部静默失效 | **P0** | `web\src\legacy.css:25,57,65,263,285`（`var(--primary)` 首现行）等 121 处；令牌仅 `web\src\index.css:10-40`（只定义 `--color-*` 与 `--ease-*`） | `legacy.css` 是从 `site\assets\site.css` 剪出的副本：剪掉了 `site.css:12-53` 的 `:root` 令牌段（含 `--primary` / `--bg` / `--text*` / `--dur-*` / `--radius-*` / `--maxw` / `--gutter` / `--section-y` / `--press-*`），却保留了全部 `var(--…)` 引用。机械核对结果：**25 种令牌未定义、121 处引用悬空**（`var(--primary)` 33 处、`var(--text)` 11 处、`var(--text-2)` 10 处、`var(--text-3)` 10 处、`var(--dur-fast)` 10 处、`var(--border)` 7 处、`var(--radius-pill)` 6 处、`var(--bg)` 5 处、`var(--text-on-primary)` 5 处，其余见 §A2 明细）。旁证：构建产物 `web\dist\assets\index-DN3xVpnF.css` 中 `var(--primary)` 出现 31 次而 `--primary:` 定义 **0** 次，`--dur-fast` 定义 **0** 次。 |
| A3 | 令牌三套并行且值冲突 | 任意一端改色 → 另一端不跟随；文档站/重写站视觉不可比对 | P1 | `web\src\index.css:12-40`（`--color-*`）；`site\assets\site.css:14-53`（`--bg/--primary/--text/--dur/--radius`）；`web\src\board\board.css:5-20`（`--board-*`，作用域在 `.board` 内） | 冲突实例：底色 `--color-ink:#0E100D` vs `--bg:#09100F`；主色 `--color-brand:#4CECA4` vs `--primary:#50ECA7`；卡片底 `--color-surface:#101810` vs `--surface:#16211F`。`index.css:5-8` 的注释解释了 `#50ECA7→#4CECA4` 的采样校正，但 site 侧从未回写 → 两套值从此永久分叉。 |
| A4 | ✅ 边界良好（确认项） | board 看板 | — | `web\vite.board.config.ts:9-19,64-79`；`web\src\board\main.tsx:6`；`web\src\board\board.css:1-4` | board 与官网完全隔离：独立 config、独立入口 `board.html`、独立产物 `board-dist/`、独立端口 4175/4176、`publicDir:false`（不继承官网 public）、绑定 `127.0.0.1`、无任何跨区 import（全量 import 已核对，`web\src\board\*` 只依赖 `./types`、`./sections/*`）。这是本仓库分区边界的正面样板，重构时应保留。 |
| A5 | 第三份副本无主 | 发布产物体积、法务页版本漂移 | P1 | `web\public\legal\privacy.html`(15224 B) ≠ `site\privacy.html`(15203 B)；`web\public\assets\site.css`(41086 B) ≠ `site\assets\site.css`(40996 B)；截图三份 md5 全同 | `web\public\` 是 site/docs 的第三份拷贝。`tools\build-site.mjs:21` 注释承认「web 构建时传 `--legal-out web/public/legal`」，但产物已与源漂移 21 B；`web\public\assets\site.css` **无任何引用**（`web\index.html` 无 link，`index.css` 只 `@import "./legacy.css"`），却会被 vite 原样发布到 `dist/assets/site.css`。截图 `docs\screenshots\01-home.jpg` = `site\assets\img\01-home.jpg` = `web\public\01-home.jpg`（md5 `fd6df3b1…`，三份相同，属设计上的一源多产物，但无脚本守护）。 |

### A2 明细：legacy.css 中未定义令牌（37 种引用中的 25 种）

```
--primary 33 处(L25 起)   --text 11 处(L9)      --text-2 10 处(L77)   --text-3 10 处(L186)
--dur-fast 10 处(L158)    --border 7 处(L34)    --radius-pill 6 处(L198)  --bg 5 处(L8)
--text-on-primary 5 处(L264)  --primary-deep 3 处(L331)  --radius-lg 3 处(L658)
--primary-soft 2 处(L259) --dur-micro 2 处(L321) --surface 2 处(L663)   --dur-base 2 处(L665)
--maxw 1 处(L43)  --gutter 1 处(L45)  --section-y 1 处(L47)  --dur-enter 1 处(L282)
--gold 1 处(L562) --bg-2 1 处(L663)   --radius-card 1 处(L1178)  --line 1 处(L1185)
--press-depth 1 处(L331)  --press-shift 1 处(L334)
```

排除项（非缺陷）：`--mx/--my/--rx/--ry/--i/--sp` 共 12 处由 JS 在运行时写入（`web\src\App.tsx:149-162` 的 tilt/untilt 写 `--rx/--ry`；`web\src\components\PointerFx.tsx` 写 `--mx/--my`），本就不该由 CSS 定义。故 133 − 12 = **121 处真实悬空**。

---

## B. 重复实现

| ID | 问题类型 | 影响面 | 优先级 | file:line 依据 | 证据 / 结论 |
|---|---|---|---|---|---|
| B1 | 交互层双实现（同一行为两套代码，参数已分叉） | 维护成本、行为不一致 | **P0** | 见下方 B1 对照表 | site.js 的 6 个职责在 web/src 中被重写为 React 组件，但**只有 5 个被覆盖**，且倾斜幅度已分叉（±4° vs ±3°）。 |
| B2 | 着色器双实现 | 极光背景视觉一致性 | P1 | `site\assets\aurora-webgl.js:1-211`；`web\src\components\Aurora.tsx:1-9,13,15-43,110` | `Aurora.tsx:4-7` 注释自承「从 site/assets/aurora-webgl.js 移植成 React 组件：逻辑不变，只是把 getElementById 换成 ref」——即已存在的语义副本。GLSL 字符串 `Aurora.tsx:15-43` 与 `aurora-webgl.js` 内同名 fbm/noise 实现需逐行同步才有视觉一致性，当前无任何门禁守护。 |
| B3 | 品牌标识 5 份 | 品牌一致性、产物体积 | P1 | `site\assets\img\logo-ring.svg`；`web\public\logo-ring.svg`；`web\public\assets\img\logo-ring.svg`（三份 md5 全同 `c9728430…`）；`web\public\favicon.svg`（md5 不同 `1f04b5df…`）；`web\src\App.tsx:30-42`（内联 SVG，`#4CECA4` 硬编码 2 处） | 生成源是 `tools\build-site.mjs` 的 ASSETS 表（`apps\harmony\…\fittracker-logo-ring.svg`）；React 侧又手抄了一份内联 SVG 并写死色值，改品牌色需改 3 处（`index.css` 令牌、`site.css` 令牌、`App.tsx` 内联）。 |
| B4 | CSS 结构双份（17 段中 6 段同名同位） | 样式修复需双写 | P1 | `legacy.css:3 ↔ site.css:56`（2 Reset）；`:153 ↔ :206`（5 顶栏）；`:223 ↔ :276`（6 Hero）；`:379 ↔ :784`（13 页脚）；`:426 ↔ :838`（15 响应式）；`:455 ↔ :871`（16 减弱动效） | `diff --strip-trailing-cr` 后仍有 **1202 行不同**（新增 611 / 删除 591），行数 1209 vs 1230。site 独有 7-12 段（`site.css:490-783`：数字条 / 训练闭环 / 截图画廊 / 数据与隐私 / 技术底子），legacy 侧无对应 → 两份无法合并前必须承认它们是**分叉副本**而非同源。 |
| B5 | 卡片 3D 倾斜三点各写一遍 | 交互手感不一致 | P2 | `site\assets\site.js:271-290`（±4°）；`web\src\App.tsx:149-162`（±3°）；`web\src\legacy.css` 的 `.feat` 规则消费 `--rx/--ry` | 同一交互、两个幅度、两处实现。数值差异无注释说明，属无意的分叉。 |

### B1 对照表：site.js 职责 → web/src 对应物

| site.js 职责 | site.js 行 | web/src 对应 | 状态 |
|---|---|---|---|
| ①标记 `.js` | `site.js:22-23` | 无（React 无需） | 合理缺席 |
| ②顶栏滚动 `is-stuck` | `site.js:26-37` | `App.tsx:140-147` | 已重写；消费方 `.topbar.is-stuck` 实际在 `legacy.css:162`（`App.tsx:139` 注释仍写「legacy.css:215」——**注释锚点已漂移 53 行**，是本次审计中的一处实锚漂移实例） |
| ③区块入场 IntersectionObserver | `site.js:39-58` | `App.tsx:163-168`（`whileInView`）+ `:261/:361` | 已重写 |
| ④数字计数 + 进度环 | `site.js:60-108` | **无** | web 版删了 stats 区块，代码随之消失 |
| ⑤训练闭环 sticky 叙事 | `site.js:110-127` | **无** | web 版无 flow 区块 |
| ⑥a 功能卡聚光 | `site.js:130-146` | `PointerFx.tsx`（聚光）+ `App.tsx:149-162`（倾斜） | 拆分重写 |
| ⑥b Hero 截图视差 | `site.js:148-165` | **无** | web 版 Hero 无截图 |
| ⑥c 截图画廊放大 | `site.js:167-190` | **无** | web 版无 gallery |
| 滚动进度条 / 视差 | `site.js:220-245` | `App.tsx:134-135,176-178` | 已重写（framer-motion 取代手写 rAF） |
| 光标光环 + 全屏聚光 | `site.js:247-269` | `PointerFx.tsx:22-50+` | 已重写 |
| 卡片倾斜 | `site.js:271-290` | `App.tsx:149-162` | 已重写（幅度分叉） |

> 结论：`site\assets\site.js`（295 行）约 **4 个职责（60-190 行，约 130 行）在 web 侧彻底无对应**——不是重复实现，而是 **site 独有资产**，删 site 即丢失。这一点决定了「能不能直接删 site/ 改发 web/dist」的答案是否定的。

---

## C. 孤儿与漂移资产

| ID | 问题类型 | 影响面 | 优先级 | file:line 依据 | 证据 |
|---|---|---|---|---|---|
| C1 | 无引用孤儿文件 | 发布体积、误导后续重构 | P1 | `web\public\assets\site.css`（41086 B） | 全仓引用检索仅 `site\index.html:10` 命中 `assets/site.css`（相对 `site/` 自身），无一指向 `web\public`。文件仍会被 vite 复制进 `dist/assets/`。 |
| C2 | 生成物与源漂移（无门禁） | 法务页版本不一致 | P1 | `tools\build-site.mjs:21,28,35`；`site\privacy.html` vs `web\public\legal\privacy.html` | 大小差 21 B，说明 `--legal-out web/public/legal` 的产物是**某次旧构建**留下且从未再生成。`tools\check-site.mjs` 只覆盖 `site\`（默认 root），不覆盖 `web\public`；`tools\build-site.mjs --check` 也只校验 render 目标。 |
| C3 | 构建产物不在库内（确认项） | — | — | `git ls-files web/dist` → 0；`web/public` → 13；`site` → 19 | `web\dist` 与 `web\board-dist` 均未入库，符合约束。台账中引用的 `web\dist\assets\index-DN3xVpnF.css` 仅作 A2 的旁证，不是事实源（事实源为 `index.css` + `legacy.css` 源文件本身）。 |

---

## D. 预设数字对账（回应计划约束「38/3/4 三组数字来源」）

**结论：三组预设数字来源不明，实测无法复现，已按待证伪假设处理并证伪。**

| 预设值 | 实测 | 判定 |
|---|---|---|
| 「38 处内联色值」 | `web\src` hex 字面量出现 **54 次**（其中令牌定义 28 次：`index.css` 17 + `board.css` 11；真·内联 26 次：`legacy.css` 15 + `JourneyFilm.tsx` 8 + `App.tsx` 2 + `board.css:22` 1）；`site` 侧 **112 次**（`app-demo.css` 69、`site.css` 23、`index.html` 5、`privacy` 5、`terms` 5、`404` 3、`aurora-webgl.js` 2） | **证伪**：38 不等于 54、26、28 或 112。四个可能口径均对不上，说明 38 来自另一范围（可能含 apps/harmony 或 apps/android）或为估计值。本台账一律采用实测值。 |
| 「3 处 shared→features」 | 本任务范围内（`web\src`、`site`）无 `shared/`、`features/` 目录，无此类 import | **不适用**（属鸿蒙 ArkTS 范围，非本任务） |
| 「4 处 common→shared」 | 同上 | **不适用** |

**方法论保证**：本台账未把 38/3/4 任何一组当作预期值；所有条目均由机械检索产出后再对账。凡与预设不一致处以实测为准，偏差已记录于此表。

---

## E. 保护项 / 禁动项（供下游重构）

| 保护对象 | 理由 | file:line |
|---|---|---|
| `site\` 全目录 | 现网发布口径（`site\README.md` 部署段）；含 web 侧无对应的独有资产（B1 表） | `site\README.md`；`site\assets\site.js:60-190` |
| `site\assets\app-demo.css` / `app-demo.js` | 手机端 UI 模拟，web 侧**无任何等价实现**，是 site 独有能力（69 处内联色值为其内部体系，不可并入官网令牌） | `site\assets\app-demo.css:1-406`、`app-demo.js:1-252`、`site\index.html:113/160/191/222/272` |
| `web\src\board\*` | 边界样板（A4），改动会破坏与官网的隔离 | `web\vite.board.config.ts`、`web\src\board\board.css:1-4` |
| `web\src\board\board.css` 的 `--board-*` 局部令牌 | 有意的独立命名空间，不应并入官网令牌 | `web\src\board\board.css:5-20` |

### 暂缓项着落（本任务范围内可判定的部分）

| 暂缓项 | 着落 |
|---|---|
| 「38/3/4 三组预设数字来源」 | **已裁决**：见 §D，38 被证伪，3/4 不属本范围。 |
| 「`WorkoutSessionPersistenceBridgeService` 精确落点未确认」 | **不适用于本任务范围**：`web\src` 与 `site` 全量检索无 `WorkoutSessionPersistence*` 命中（`grep -rn "WorkoutSessionPersistence" web/src site` → 空）。该项属鸿蒙审计范围，本台账不作断言。 |
| 「禁动项是否也需填全『问题类型/影响面/优先级』」 | **已采纳**：§E 保护项表补齐「理由 + file:line」，但因它们无缺陷属性，「问题类型」以「保护/禁动」标注、「优先级」留空（不适用）。 |
| 「计数单位口径不一」 | **已采纳并成文**：见 §0 口径声明。 |
| 「契约基线 §1-§6 漏 §7」 | **不适用于本任务**：本审计不涉及 `contracts/README.md` 漂移比对，不作断言，留待契约审计任务。 |
| 「audit-server-functions 的 deploy/migrations 禁动区未产出 file:line」 | **不适用于本任务**：`server\` 不在范围内。 |
| 高危风险「台账摘录密钥」 | **已采纳**：对 `site` 与 `web\src` 做凭据关键字扫描（`accesskey|appsecret|secret|password|bearer|supabase|apikey|publishable`），`web\src` **0 命中**；`site` 命中的 17 条全部是隐私政策/技术底子段落的**文案**（如 `site\privacy.html:44,53,85`、`site\index.html:478,570`），**不含任何凭据值**。台账未复制任何密钥。 |

---

## F. 优先级汇总（下游取用顺序）

| 优先级 | 条目 |
|---|---|
| **P0** | A1 双首页并存无单一事实源 · A2 25 种令牌/121 处引用悬空 · B1 交互层双实现且已分叉 |
| P1 | A3 令牌三套且值冲突 · A5/public 第三份副本漂移 · B2 着色器双实现 · B3 品牌标识 5 份 · B4 CSS 结构双份 · C1 孤儿 site.css · C2 生成物漂移无门禁 |
| P2 | B5 倾斜幅度三点分叉 |
| 确认项 | A4 board 边界良好 · C3 构建产物未入库 |

## G. 未验证 / 边界声明

- 本台账**未执行** `web` 构建验证（`web` 无 `node_modules`，根目录依赖不保证与 web 锁定版本一致）。A2 的「令牌悬空」结论由**源文件集合运算**直接得出（事实源），`web\dist` 产物仅作旁证，不依赖构建可复现性。
- **未做**跨端（apps/harmony、apps/android）比对 —— 超出本任务范围。
- `tools\check-site.mjs` 已实跑并通过（`[check-site] 6 项检查全部通过（4 页）`），但它仅覆盖 `site\` 的引用完整性/外链/alt，**不覆盖** CSS 变量完整性、web/site 重复度、public 副本漂移 —— §A2/§A5/§C1/§C2 目前无任何门禁守护，属门禁盲区。
- 未修改任何源码；未产生探针残留（所有核对用 `node -e` 内联执行，未落盘）。
