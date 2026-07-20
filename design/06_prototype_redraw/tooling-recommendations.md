# FitTracker 原型设计工具链建议（基于当前 Hermes / 本地环境实际搜索）

## 当前已确认可用

### 1. 已安装且启用的 design / prototype 相关 skills
这些都已经在当前 Hermes 环境里可直接使用：

- `claude-design`
  - 适合：高保真 HTML 原型、交互原型、完整设计产物
  - 价值：最适合这次 "高保真 + 可点击" 的主产出

- `popular-web-designs`
  - 适合：借用成熟产品的视觉语言（Linear / Vercel / Stripe / Figma / Superhuman / VoltAgent 等）
  - 价值：帮助快速拉高视觉完成度，而不是从零乱猜

- `design-md`
  - 适合：整理设计 token / 设计系统 spec
  - 价值：如果后面要把原型沉淀成更正式的 design system，很有用

- `sketch`
  - 适合：在定稿前快速出 2~3 个设计方向变体
  - 价值：适合探索，不适合直接作为最终稿

- `excalidraw`
  - 适合：用户流程图、信息架构图、交互路径图
  - 价值：适合梳理结构，不适合最终高保真视觉稿

- `mobile-app-ui-ux-design`
  - 适合：移动端产品结构、界面、交互、视觉系统方法论
  - 价值：尤其适合 HarmonyOS / ArkUI 设计语境

- `mobile-app-design-review`
  - 适合：从现有 repo 与代码里反推设计问题
  - 价值：对 FitTracker 这种已有工程很重要

### 2. 已确认可用的 Hermes 能力
- 文件写入 / patch / 搜索：可直接生成与维护原型文件
- terminal：可运行本地命令、做结构验证
- image_generate：可做局部视觉探索（不适合整套交互原型主产出）
- native MCP client：Hermes 原生支持 MCP，可接外部设计工具或外部服务

---

## 当前缺失或未接通

### 1. MCP servers：当前未配置
实际检查结果：
- `hermes mcp list` -> **No MCP servers configured**

这意味着：
- 目前还没有接上任何外部 MCP 设计工具
- 如果你本机有 Figma MCP / 设计资产 MCP / 浏览器类 MCP，可以后续接进来

### 2. 浏览器增强插件：当前未启用
实际检查结果显示这些插件存在但未启用：
- `browser-browser-use`
- `browser-browserbase`
- `browser-firecrawl`

这意味着：
- 你现在的浏览器自动化与视觉验证链路不算完整
- 如果要做更强的页面视觉验证、自动打开原型、截图复核，这类插件值得后续接入

### 3. 本地 browser 环境不完整
此前调用 browser 时出现过：
- 本地 Chrome 未找到

这意味着：
- 目前不适合把 `browser_vision` 当成主验证通路
- 需要先补浏览器运行环境，或者改走 HTML + 本地工具验证路线

---

## 对 FitTracker 这次任务最推荐的工具链

## 方案 A（我最推荐）：先用 Hermes 直接产出高保真 HTML 原型
### 组合
- `claude-design`
- `popular-web-designs`
- `mobile-app-ui-ux-design`
- `mobile-app-design-review`

### 适合原因
- 你现在已经有 repo、设计文档、设计 token、页面 specs
- 直接生成 **高保真可点击 HTML 原型**，效率最高
- 不依赖外部账号或第三方设计平台就能先把结果做出来
- 非常适合先把主线流程与视觉语言定住

### 这套组合分别负责什么
- `mobile-app-design-review`
  - 从现有 FitTracker repo 抽取真实结构与问题
- `mobile-app-ui-ux-design`
  - 确保 HarmonyOS / 移动端逻辑不跑偏
- `popular-web-designs`
  - 提供成熟视觉语言参考（比如 Linear / Superhuman / VoltAgent）
- `claude-design`
  - 真正把它做成一个高保真、可点击、可交付的 HTML 原型

### 结论
这是**现在就能开工**、风险最低、最容易拿到成果的路线。

---

## 方案 B：接入 Figma / 即时设计类外部工具，再做最终稿
### 组合
- 方案 A 先做 Hermes 版 HTML 原型
- 再通过 MCP / 外部设计工具同步到 Figma / 即时设计

### 适合原因
- 如果你最终希望：
  - 团队协作
  - 标注交付
  - 设计师继续精修
  - 组件库沉淀
- 那么 Figma / 即时设计是非常适合的下一层

### 当前阻碍
- 现在还没有 MCP server 接进去
- 也还没有确认你本机是否有可接的 Figma MCP / 设计桥接工具

### 结论
这是**第二阶段增强方案**，不是当前最快拿结果的首选。

---

## 方案 C：先做多方向探索，再定一版主稿
### 组合
- `sketch`
- `popular-web-designs`
- `mobile-app-ui-ux-design`

### 适合原因
- 如果你现在还不确定最终风格
- 想先看 2~3 套方向对比

### 不足
- 你当前诉求不是“看看几版”，而是要高保真高精准度最终原型
- 所以这条不是当前主路线，只能作为辅助探索

---

## 我对这次任务的明确建议

### 当前最佳路线
**直接走方案 A。**

也就是：
1. 继续基于现有 repo 和 design docs
2. 用 Hermes 产出一版高保真可点击 HTML 原型
3. 视觉语言借鉴成熟系统，但保留 FitTracker 的高端训练系统定位
4. 等主稿成立后，再决定是否接 Figma / MCP / 设计平台做二次沉淀

---

## 推荐借鉴的设计语言来源
结合 FitTracker 当前黑绿高级感与训练控制台定位，我建议重点参考：

- `Linear`
  - 用于：层级控制、暗色密度、工具感
- `VoltAgent`
  - 用于：黑底 + 绿色能量信号 + 控制台气质
- `Superhuman`
  - 用于：高端感、节制的强调、结果页与回顾页的精修感

不建议直接照搬其中任何一个，而是：
- 用 Linear 的秩序
- 用 VoltAgent 的训练控制台气质
- 用 Superhuman 的高端收束感

---

## 如果后面你要把链路补满，值得追加的能力

### 1. MCP：接 Figma / 设计服务
如果你本机已有 Figma MCP 或其他设计桥接服务，可考虑：
- `hermes mcp add <name> --command ...`
- 或接 HTTP MCP endpoint

### 2. 启用 browser 增强插件
如果你需要更强的页面验证、截图、交互复核：
- `hermes plugins enable browser-browser-use`
- 或根据你的凭据条件启用 Browserbase / Firecrawl

### 3. 补本地 browser 环境
当前 browser 失败的直接原因之一是：
- Chrome 不存在 / 未安装

后续要做更完整视觉验证时，建议先补这个环境。

---

## 最终结论

基于当前本地环境和 repo 状态：

### 立刻可用、最适合这次任务的工具链是：
- `claude-design`
- `popular-web-designs`
- `mobile-app-ui-ux-design`
- `mobile-app-design-review`

### 暂时不适合作为第一主路径的：
- 依赖外部 MCP 的设计协作链（因为还没接）
- 依赖 browser_vision 的强视觉验证链（因为浏览器环境还不完整）

### 最佳执行策略：
先用 Hermes 直接生成 **高保真 + 可点击 HTML 原型**，把主稿做出来；
确认方向后，再决定是否补 Figma / MCP / 浏览器增强验证链。
