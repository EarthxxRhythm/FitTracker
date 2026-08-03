# FitTracker Pencil 全页面几何规格

来源：Pencil MCP 当前活动文档 `C:/Users/Administrator/.pencil/documents/795de57e-5aaa-452a-9b7e-f35f95cb6277/pencil-welcome-desktop.pen`。

## 统一规则

- Pencil MCP 源色值为 `#RRGGBBAA`；ArkUI 实现统一转换为 `#AARRGGBB`。
- 原型中的手机外框、圆角设备壳、Notch、伪状态栏、设备阴影均不实现；设备真实状态栏属于宿主设备。
- 目标应用 viewport 固定为 `390 x 844`，不添加响应式断点、不按设备宽度重新排版。
- 430 宽设计坐标按 `390 / 430 = 0.9069767442` 固定缩放；页面内部 padding、gap、圆角、字号全部按同一比例映射。
- 屏幕截图中的真实设备状态栏和底部手势条不计入应用层 z-order。

## 页面索引

| Pencil 节点 | 源尺寸 | 可见应用层根内容 | ArkUI 实现 |
|---|---:|---|---|
| `n3Xd5` FitTracker Splash | 430 x 844 | 居中品牌锁定、背景渐变 | `features/pencil/PencilSplashPage.ets` |
| `x8cHBq` FitTracker Welcome | 430 x 900 | 品牌、标题、说明、训练视觉、主 CTA、页脚 | `features/welcome/pages/PencilWelcomePage.ets` |
| `NFOSZ` FitTracker Login | 430 x 844 | 品牌头、登录卡片、手机号、密码、登录 CTA、注册入口 | `features/pencil/PencilLoginPage.ets` |
| `R3xJMP` FitTracker Home | 430 x 1460 | 今日头部、训练 Hero、周面板、边界面板、底部导航 | `features/pencil/PencilHomePage.ets` |
| `RDOOY` FitTracker Plan | 430 x 1460 | 页面标题、计划 Hero、周安排、主 CTA、底部导航 | `features/pencil/PencilPlanPage.ets` |
| `nOkrv` FitTracker Workout Preview | 430 x 844 | 开始前确认、训练预览、热身组、主动作组、操作面板 | `features/pencil/PencilPreviewPage.ets` |
| `LtqJz` FitTracker Active Workout V2 | 430 x 844 | 训练状态、动作标题、进度环/进度条、输入卡、完成操作 | `features/pencil/PencilActivePage.ets` |
| `sS03p` Active Workout · Rest | 430 x 844 | 休息状态、倒计时、跳过休息、结束训练 | `features/pencil/PencilActivePage.ets` 状态 `rest=true` |
| `i15gXf` FitTracker Profile | 430 x 844 | 个人头部、设置项、数据说明、返回首页 | `features/pencil/PencilProfilePage.ets` |
| `GuVxb` FitTracker Review | 430 x 1460 | 回顾标题、周统计、节奏、个人记录、返回首页 | `features/pencil/PencilReviewPage.ets` |

## `R3xJMP` Home 精确结构摘录

- 根 frame：`430 x 1460`，`layout=none`，clip，根渐变为线性 `#0B0F13 -> #0A0D12`，顶部 radial accent；根圆角和设备 stroke 属于原型壳，忽略。
- `Home Content`：`x=0,y=0,width=430,height=1266`，vertical，`padding=[58,18,40,18]`，`gap=22`。
- `Today Card`：`width=fill_container=394,height=466,padding=20,gap=16,radius=28,stroke=#FFFFFF10`；内部 `Hero Top`、1px Divider、Metrics、两个 44 高动作按钮。
- `Week Panel`：`width=394,height=248,padding=18,gap=16,radius=30`；内部 Header、7 天横向列、进度区。
- `Boundary Panel`：`width=394,height=308,padding=18,gap=14,radius=30`；内部 Header 与 `gap=12` 的边界行。
- `Bottom Nav`：`x=0,y=1364,width=430,height=80,padding=[7,12,9,12]`；五个 tab，每个 `height=56,radius=16,gap=4`；训练 tab 使用绿色渐变和 `#50ECA71A` stroke。
- 文字：Greeting `40px/0.98/700`；卡片标题 `14px/700`；指标值 `30px/0.95/700`；底部标签 `11px`。

## `RDOOY` Plan 结构

- 根 `430 x 1460`，内容 `Plan Content` 为 vertical，`padding=[58,18,118,18]`，`gap=18`。
- 顶部 `Status Row` 为 `fill_container`，应用层只保留页面内容，不绘制状态栏。
- `Today Nav` 与计划标题垂直排列，标题使用 `28px/700`，副标题 `13px/600`。
- `Today Card` 与 Home 同一玻璃渐变策略，`radius=28`。
- 底部导航 `width=394,height=80,padding=[7,12,9,12]`，固定在内容底部。

## `nOkrv` Preview 结构

- 根 `430 x 844`，`Preview Content` vertical，`padding=[58,18,18,18]`，`gap=20`，`justifyContent=space_between`。
- Hero：Eyebrow `12px/700`、Title `28px/700`、Subtitle `13px/600`，三者 gap `6`。
- `Exercise Section` height `497`；Header height `48`；热身组 `x=0,y=74,width=394,height=123,radius=22`；主动作组 `x=0,y=215,width=394,height=282,radius=24`。
- `Action Section` 顶部 padding `8`，内部 `Action Panel` padding `14,radius=30,gap=10`；主按钮为 44/48 高绿色渐变按钮。

## `LtqJz` / `sS03p` Active Workout 结构

- 两个 Pencil frame 均为 `430 x 844`，共享同一 root gradient 和页面 padding `18`。
- Active 状态：顶部状态行、动作标题、目标处方、中心进度视觉、两列数据输入、完成本组按钮。
- Rest 状态：中心状态改为休息计时，隐藏输入卡，保留跳过休息和结束训练按钮。
- 进度视觉 z-order：底层轨道 -> 绿色进度 -> 内圈 -> 中央数值/标签 -> 操作面板。

## `NFOSZ` Login 结构

- 根 `430 x 844`，`padding=[0,18,28,18]`，vertical，`justifyContent=space_between`。
- Login Content vertical，内部 Brand Header、Login Form、Social Login；内容组 gap `24`，表单控件 gap `14`。
- 表单输入卡使用 `radius=16`、半透明白底、`52` 高；登录主 CTA 使用 `radius=18`、绿色渐变。
- 底部注册提示 `height=24`，文字 `12px`，链接绿色 `700`。

## `i15gXf` Profile 与 `GuVxb` Review

- Profile 为 `430 x 844`，内容 padding `[58,18,28,18]`；用户信息卡 `radius=24`，设置行 `radius=18`、`padding=16`。
- Review 为 `430 x 1460`，滚动内容 padding `[58,18,40,18]`，段间距 `18`；统计卡、周节奏卡、个人记录卡均使用 `#FFFFFF08` 玻璃底和细边框。
- Review 统计值 `24px/700`，记录标题 `14px/500`，变化值 `13px/700` 绿色。

## z-order 约定

1. 应用根背景渐变。
2. 页面内容卡片和边框。
3. 卡片内部渐变、环形进度和装饰图形。
4. 文字与操作控件。
5. 宿主设备系统栏不属于应用层，不能在 ETS 中重建。

## Register 视觉补充

- Register 与 Login 共享 430 x 844 根画布、padding=[0,18,28,18]、输入控件 52 高、卡片 adius=24、CTA adius=18。
- Register 不属于 Pencil 顶层节点，但为保证完整链路使用同一套视觉 token，避免回退到旧版浅色/黄色卡片。

