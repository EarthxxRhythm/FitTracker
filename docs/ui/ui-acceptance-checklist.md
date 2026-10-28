# 菲特 UI 验收清单

> **层级**：L3 参考
> **最后核对**：2026-10-28
> **上位文档**：`AGENTS.md`（L1）
> **状态**：现行
> **路径基准**：文中路径相对仓库根
> **适用端**：双端

## 目的

本清单把 UI/UX 收口阶段剩下的主观评价缺口，转成一次明确的复核。

它用于工程收口之后的一轮简短人工验收。

使用本清单时同时参照：

- `docs/ui/ui-final-acceptance-runbook.md`（已移除，随设计资产移出主仓，见 FitTracker-design）
- `docs/ui/ui-design-review-packet.md`
- `docs/ui/ui-acceptance-record-template.md`
- `node tools/generate-ui-acceptance-record.mjs`（已归档：现役 `apps/harmony/tools/` 下不存在，历史副本在 `docs/archive/legacy-cleanup-2026-09/tools/`）

## 复核范围

复核以下已注册的用户可见路由：

清单以 `apps/harmony/entry/src/main/resources/base/profile/main_pages.json` 为准（19 条），本处按启动与主壳顺序排列：

- `features/pencil/pages/PencilSplashPage`
- `features/welcome/pages/PencilWelcomePage`
- `features/pencil/pages/PencilLoginPage`
- `features/pencil/pages/PencilRegisterPage`
- `app/PencilAppShell`
- `features/pencil/pages/PencilHomePage`
- `features/pencil/pages/PencilPlanPage`
- `features/pencil/pages/PencilPlansPage`
- `features/pencil/pages/PencilPlanGroupDetailPage`
- `features/pencil/pages/PencilActivePage`
- `features/workout/pages/WorkoutCompletePage`
- `features/pencil/pages/PencilReviewPage`
- `features/exercise/pages/ExerciseLibraryPage`
- `features/exercise/pages/ExerciseDetailPage`
- `features/body/pages/BodyDataPage`
- `features/pencil/pages/PencilProfilePage`
- `features/pencil/pages/PencilProfileEditPage`
- `features/settings/pages/PencilSettingsPage`
- `features/settings/pages/LegalDocPage`

训练预览 `PencilPreviewContent` 不是注册路由（由应用壳以全模态承载），但它属于必验界面，一并纳入 A–D 四节复核。

## 验收标准

只有在本次复核的每条路由都在下面任一检查分节中没有阻塞问题时，UI/UX 目标才视为通过。

阻塞问题的定义：任何使该路由与目标风格明显不一致、影响主任务流程，或留下正常用户很快就能察觉到的观感欠账的问题。

## A 节：视觉一致性

对每条路由确认：

- 首屏范围内页面层级清晰
- 标题、标签与辅助文字使用一致的层级比例
- 卡片、间距与分隔线与 App 其余部分观感一致
- 更新过的界面里没有明显混入旧视觉语言
- 关键操作使用一致的视觉优先级
- 没有只为装饰、不服务于训练工具流程的分节

出现下列任一情况即判该路由不通过：

- 主视觉、分节或卡片样式看起来像另一代产品
- 与相邻路由相比，间距密度明显失衡
- 按钮强调混乱或不一致
- 文字块显得嘈杂、重复或解释过度

## B 节：流程清晰度

对每条路由确认：

- 主操作在 3 秒内可被识别
- 返回 / 下一步的行为无需摸索即可理解
- 页面支持先扫读再细读
- 相关的次级操作归组合理
- 路由不会为完成主任务强行绕路

出现下列任一情况即判该路由不通过：

- 用户必须猜测哪个按钮继续主流程
- 路由把设置、查看与破坏性操作混在一起，没有层级
- 主任务被埋在低优先级内容之下

## C 节：交互打磨

对每条路由确认：

- 没有可见的重叠、裁切或断行错乱
- 没有空白、无响应或误导性的 CTA
- 点击常用控件时没有不稳定的布局抖动
- 加载 / 空态 / 成功 / 警告状态读起来是刻意设计的
- 重复出现的控件在各路由行为一致

出现下列任一情况即判该路由不通过：

- 在常见视口条件下文字截断得很糟
- 重要操作之后缺少状态反馈
- 路由出现让人感觉像意外发生的视觉跳动

## D 节：产品调性

对每条路由确认：

- 应用读起来仍是一件专注的训练工具，而不是营销页
- 视觉设计平静、密度足够、工具感明确
- 进阶能力显得被整合进来，而不是硬贴上去

出现下列任一情况即判该路由不通过：

- 该路由感觉像推广面而不是工具面
- 视觉处理为了炫技牺牲了清晰度

## 路由专项关注点

### 登录 / 注册

- 认证入口应当紧凑、清晰，视觉重量不超过主应用
- 注册交接不应显得像一段断开的流程

### 目标设置

- 分组选项应有结构感，而不是表单噪声
- 生成计划这一操作应保持清晰的终端操作

### 首页

- 今日训练入口必须压过次级目的地
- 预设计划应读作次级探索，而非主任务

### 动作库 / 动作详情

- 动作库筛选应当可扫读、可操作
- 详情媒体卡应融入知识流

### 训练计划详情

- 启用之前，训练计划结构应易于扫读
- 进阶变体应与默认启用流程明确分开

### 训练预览 / 训练执行 / 训练摘要

- 训练预览、训练执行与训练摘要应感觉像同一条连续的产品带
- 训练摘要应比训练执行更平静、更有回看感

### 回顾首页

- 趋势、恢复洞察、备份入口与个人页工具应共存而不显拥挤

## 复核输出模板

最终人工验收使用以下模板：

```text
Route:
Visual consistency: pass | fail
Flow clarity: pass | fail
Interaction polish: pass | fail
Product tone: pass | fail
Notes:
Blocking issue:
```

可在人工复核之前，用以下命令预填机器可核验的证据引用：

```powershell
node tools/generate-ui-acceptance-record.mjs
```

## 收口规则

满足下列条件时，UI/UX 目标视为通过：

- 范围内的每条路由都已复核
- 没有路由存在阻塞问题
- 任何非阻塞备注都只涉及观感打磨，不改变产品方向
