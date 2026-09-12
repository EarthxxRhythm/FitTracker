# 调研：HTML 原型 → ArkUI 1:1 还原与验收的可复用方案

> 调研日期：2026-09-12　委托：启明星域（探路/照路，只读）
> 问题域：把 HTML 设计稿 1:1 还原为 ArkUI 页面，并做像素/动效验收——业界与官方有无现成方案

## 0. 被调研的四个真实痛点

来自本项目的实际工作（非假设）：

| # | 痛点 | 现状 |
|---|---|---|
| ① | 到达目标屏靠手算坐标点击 | `hdc shell uitest uiInput click <x> <y>`，坐标随布局变化即失效 |
| ② | 动画媒体导致像素不可比 | 手工掩蔽（library 的 GIF 已验证：26.82% → 7.35%） |
| ③ | 差异定位只有行带粒度 | `compare.py` 只给 band/quadrant |
| ④ | 滚动等交互语义无法静态验证 | 此前一直标注「无法验证」 |

## 1. 发现一：`devecocli ui` 是完整的官方 UI 自动化套件（可吸收）

此前项目只用了 `hdc shell uitest`，未意识到 `devecocli` 已封装同层能力且有增益：

| 命令 | 能力 | 对本项目的增益 |
|---|---|---|
| `ui layout --format json` | 结构化节点树 | **替代手工解析 a11y 文本**；字段 `bounds/children/clickable/scrollable/text/type` |
| `ui layout --mode full\|simplified` | 树深度/裁剪模式 | `simplified` 折叠包装容器，`full` 保留完整层级 |
| `ui screenshot` | 官方截图 | 替代 `hdc shell snapshot_display` |
| **`ui swipe` / `fling` / `drag` / `dircfling`** | **手势** | **见发现三——解锁滚动边界验证** |
| `ui click` / `doubleclick` / `longclick` | 点击族 | 等价于 `uitest uiInput click` |
| `ui text <text> [x] [y]` | 文本输入 | 表单类屏（login/register）可脚本化填表 |
| `ui window` | 窗口管理 | 多窗口/弹窗场景 |

**增益点**：`--format json` 比文本解析稳健（含 `clickable`/`scrollable` 结构化标记，不必猜）。

## 2. 发现二：`--id` 节点定位**不可自举**（负结果，诚实记录）

`ui click --id <id>` 与 `ui layout --id <id>` 均声称支持节点 id 定向，但实测：

```
layout --format json --depth 5  →  FIELDS: bounds|children|clickable|scrollable|text|type
                                    ID-like: (none)
layout --format json --mode full --depth 2  →  同样无 id 字段
```

**结论**：`--id` 所需的 id **无法从 CLI 输出获得**，闭环不成立。

**影响**：痛点 ①（坐标失效）**没有官方解法**——仍需坐标点击。
但可缓解：用 `layout --format json` 每次**重新取 bounds**，而非硬编码坐标。

## 3. 发现三：`ui swipe` 解锁「滚动边界验证」（本轮最重要的正面发现）

**实测**：`devecocli ui swipe 660 1800 660 700` → `✔ swipe from (660, 1800) to (660, 700)`

**这解决痛点 ④**。此前我把「滚动边界」列为「静态截图无法验证、需人工」，但它其实可以脚本化：

```text
1. layout --format json  →  记录目标元素 bounds（如页头"下午好"）
2. ui swipe <x1> <y1> <x2> <y2>  →  滚动
3. layout --format json  →  再看该元素 bounds
   ├─ bounds 变化或消失  →  该元素随内容滚动（页头会滚走）
   └─ bounds 不变        →  该元素固定
```

**这正对应本项目的滚动边界判据**（原型 `.pane-scroll` 内的元素应滚走、`flex:0 0 auto` 的应固定）。
可用它**逐屏断言**此前只能靠人眼确认的滚动语义，例如：

- login/register：品牌区+标题应**滚走**（原型 `.auth-scroll` 内含）
- active：demo-card 应**滚走**、`top-bar`/`dock` 应**不动**
- review：周月切换应**滚走**
- plans/planGroup/body/settings：顶部栏应**不动**

**这是本轮调研可立即落地的最大收益。**

## 4. 发现四：外部生态的适用边界

- **`web_search` 在本环境不可用**：两次检索（中/英文技术词）返回的全是官网首页、百科词条、VS Code 下载页，无一条技术内容。**不能用于技术调研**。
- **`web_fetch` 可用**：Playwright API 文档返回 200、965,885 字符。
- **但 Playwright 方案不适用**：其截图选项 `animations: 'disabled'` / `caret: 'hide'` 作用于**网页侧 DOM/CSS 动画**，而本项目的痛点 ② 在**设备侧**（模拟器上的 GIF 帧），**不同层，无法借用**。
- **通用视觉回归框架同样不适用**：backstopjs / reg-suit / Applitools / Percy 均为 **Web-to-Web** 场景。
- **设计稿 → 原生 无成熟方案**：Figma Dev Mode 等只产出代码片段，不保证像素一致；跨渲染器（浏览器 vs ArkUI）的像素对齐没有现成工具。

## 5. 结论

1. **本项目自建方案（`visual-diff` + `render-prototype` + 文本掩码）方向正确**——业界在此场景（HTML→原生、跨渲染器）确无现成替代。
2. **可立即吸收一项官方能力**：`ui swipe` 做滚动边界断言（发现三），把此前「无法验证」的部分变成可脚本化断言。
3. **可顺手替换两项**：`ui layout --format json` 替代文本解析；`ui screenshot` 替代 hdc 截图。
4. **痛点 ①②③ 仍需自建**：①（坐标失效）无官方 id 可借；②（设备侧动画）跨层，Playwright 帮不上；③（细粒度定位）可考虑"节点树 + 原型 DOM 双向比对"，但属自研。

## 6. 调研限制（诚实标注）

- **网络调研受严重限制**：`web_search` 返回无效结果，`web_fetch` 仅验证了 1 个 URL（Playwright）。华为开发者官网、鸿蒙 UI 测试框架（Hypium/uitest）的官方文档**未取得**。
- **`--id` 的负结果**限于当前 devecocli 版本与 `layout` 命令；未尝试 HarmonyOS 原生 `uitest` 的 node id 获取途径。
- **发现三仅验证了 `swipe` 命令可执行**，未完整跑通「三步骤断言」流程（当前屏为 library，非目标验证屏）。
