+++
title = "FitTracker 开发日志"
date = 2026-06-04T10:30:00+08:00
draft = false
tags = ["HarmonyOS", "ArkUI", "FitTracker", "开发日志"]
categories = ["项目复盘"]
+++

FitTracker 是一个本地优先的 HarmonyOS ArkUI 健身训练记录应用：用户可以设置训练目标、生成计划、执行训练、记录重量和次数，并在回顾页查看周统计、历史趋势和个人纪录。这个开发日志记录的是项目从基础功能闭环到回归工具化、再到回顾体验增强的阶段变化。

## 开发进度

- 总体进度：`97%`
- 当前阶段：`Phase 3.5`
- 当前重点：`MVP 内部验收包完成，Phase 4 项保留后续`

```text
Phase 1 基础训练闭环        [██████████] 100%
Phase 2 内容与回归工具化    [██████████] 100%
Phase 3 回顾与修正体验      [██████████] 100%
Phase 3.5 收口与恢复能力    [██████████] 100%
Phase 4 系统化与扩展能力    [░░░░░░░░░░]   0%
```

## 开发日志
### 2026-06-05：MVP 内部验收包收官

这一轮不再继续铺新能力，而是把 FitTracker 真正收成一个可交付、可复跑、可复查的 MVP 内部验收包。交付边界被故意收得很清楚：我们认领的是 unsigned HAP、最终验收记录、运行入口说明和延期项边界，不把“正式签名发布”假装成已经完成的工作。这样做的好处是，项目完成态终于和仓库里的真实工程状态对齐了。

收官验收没有回到那种又长又重的整链路回归，而是沿用这一阶段已经证明更高效的轻量真实验证。最终命令集只保留了 `check-gates`、两条 `hvigorw assembleHap --no-parallel`、一条认证回归、以及两条 focused smoke：`current-plan` 和 `both`。其中 `both` 实际覆盖的是回顾页备份卡和动作详情媒体卡，`current-plan` 则覆盖首页当前计划到训练预览再到训练执行的主入口。这样一来，既能确认项目最关键的几条真实路径没有松掉，又不会把收官节奏重新拖回“每次都从头跑完整回归”的模式。

这轮最重要的工程信号其实有两个。第一个是 `PackageHap -> spawn java ENOENT` 没有在最终验收里复发，说明前面收住的 DevEco 环境修复已经不只是“某一次能过”，而是能支撑这轮正式收官。第二个是 auth、current-plan、backup-card、media-card 四条真实入口都在 summary 文件里明确给出了 `passed` 结果，甚至连 Midscene 偶尔会在 stdout 尾部留下的旧断言噪音，这次也被明确降级为“以 summary 为准”的非决定性信息。对一个已经进入维护期准备态的项目来说，这比再多补一页功能更有价值。

最后新增的 `docs/mvp-closeout.md`，相当于给项目留下了一张工程交接单。它把已交付能力、最终验收矩阵、重跑命令、产物路径和延期项放在一页里说清楚。后面不管是你自己回来看，还是交给另一位开发者继续往 Phase 4 推，都不需要再从开发日志里反复拼线索了。

### 2026-06-05：修通 PackageHap，再把 current-plan 训练链路收成一条短烟雾验证

这一轮的关键不是继续铺新功能，而是把最后几处“明明业务已经能用，但验证和环境还不够稳”的点一口气收住。最直接的卡点是 DevEco 构建环境里反复出现的 `PackageHap -> spawn java ENOENT`。表面上看像是 Java 没配好，实际问题更像是 hvigor 在子进程里看到的 `PATH`、`Path` 和 Node 侧环境并不完全一致。最后的处理没有继续走“手工补 PATH”这条会越来越脆的路，而是把环境准备收敛到 `tools/deveco-env.ps1`，统一规范化 `Path/PATH`，再配合 repo 内的 `tools/java.cmd` 和 `tools/node-java-shim.cjs`，让 hvigor 在 `PackageHap` 阶段拉起 `java` / `javac` 时都能稳定命中 DevEco 自带 JBR。

这件事的价值不只是一条命令终于通过了，而是把“构建环境是否可信”从碰运气，收成了可复用入口。现在只要先跑：

```powershell
powershell -ExecutionPolicy Bypass -File tools/deveco-env.ps1
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleHap --mode module -p module=entry@default -p product=default --no-parallel
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleHap --mode module -p module=entry@ohosTest -p product=default --no-parallel
```

两条构建都已经能重新走到 `PackageHap` 成功。对于一个依赖本地 DevEco 工具链的 ArkUI 项目来说，这一步其实和补一个功能差不多重要，因为后面所有回归、安装和视觉验证都建立在它之上。

环境收稳之后，这一轮又顺手把 `current-plan` 这条最常走的训练入口固化成了新的 focused smoke 默认路径。之前的 `backup-card` 和 `media-card` 更像是 phase 3.5 两个新入口的补充守门；现在 `Home -> Preview -> Active` 这条链路已经值得单独被当作“每日最短真实验证”。脚本层面，`tools/dev-smoke.ps1` 和 `tools/midscene-entrypoints-smoke.ps1` 都新增了 `current-plan` 目标，断言刻意避开了容易漂移的内部 id，只盯住首页主训练入口、训练预览标题/计划名/训练日文案，以及训练执行页的动作区和组数输入区。

```powershell
powershell -ExecutionPolicy Bypass -File tools/dev-smoke.ps1 -Target current-plan -DeviceId 127.0.0.1:5555
```

这条 2 步链路已经在模拟器上通过，报告落在 `midscene_run/focused/current_plan-20260605-003730-p43936/`。它意味着我们不必每次都重跑整套长回归，也能快速确认“当前启用计划 -> 训练预览 -> 开始训练”这条主线没有被最近的改动带偏。

和前几天相比，项目状态也因此发生了一个挺明确的变化：phase 3.5 不再主要是“补功能”，而是“把已经补到位的功能、验证、环境和文档收成同一个节奏”。训练入口、备份入口、媒体入口、构建环境和 focused smoke 现在终于开始说同一种话了，这比再多长出一页新页面更像真正的收口。
### 2026-06-04：手动备份包先落地，恢复链路先做真实可用

今天这一笔更像 phase 3.5 的第一块地基，而不是新页面。FitTracker 先把“用户最怕丢的东西”圈定下来：训练目标、我的计划、当前计划指针，以及训练记录。围绕这四类数据，新加了 `UserDataBackupService`，支持直接导出带 `schemaVersion` 的 JSON 包，并在应用内重新导入。

这次没有停在“能导出一份文本”这一层，而是把导入后的可见性也一起补齐了。因为当前训练记录真正落地的是旧的持久化 store，而回顾页看的却是共享 `WorkoutRepository`，如果只做导入不做回灌，功能会看起来存在，体验却是空的。于是这轮顺手把 `WorkoutSessionPersistenceBridgeService` 往前推了一步：它现在不仅能把新 session 写回旧持久化层，也能把持久化层里的 session 重新灌回当前仓库。

```ts
const mergedSessions: WorkoutSession[] = this.mergeSessions(existingSessions, backupPackage.sessions)
await WorkoutSessionPersistenceBridgeService.replacePersistedSessions(context, mergedSessions)
await WorkoutSessionPersistenceBridgeService.syncRepositoryFromPersistence(context)
```

这样导入完成后，回顾页里的数据就能立刻刷新出来，而不是留下一份“已经导入成功”的提示，再让用户自己猜数据去了哪里。现在的版本还只是手动 JSON 包 MVP，但至少已经满足一个很朴素的标准：导出、导入、刷新、可见，这条链路是真通的。

### 2026-06-03：从训练闭环走向可复盘、可恢复

最近一轮进展不是简单加页面，而是在已有“目标设置 -> 训练预览 -> 执行训练 -> 总结 -> 回顾”的链路上补齐更细的状态管理。工作区新增了训练草稿服务、训练记录编辑服务，以及回顾洞察服务；这让应用开始处理更真实的训练场景：训练中途退出后能恢复，保存后的记录可以修正，回顾页也不再只展示摘要，而是能按最近 7 天、30 天、全部记录筛选，并按周查看训练趋势。

同一天的另一笔收口，是把“目标调整建议”从一句提示推进到“保存前可预览”的状态。现在回顾页在给出降低压力或提高频率建议时，会先用 `GoalAdjustmentPreviewService` 生成预览目标和预览计划，再把当前安排与调整后安排并排展示出来。这样用户不会只看到“建议减一天训练”这样的抽象结论，而是能直接看到每周天数、动作数量和重点肌群会如何变化。

```ts
const preview = GoalAdjustmentPreviewService.createPreview(
  this.currentGoal,
  currentPlan,
  selection,
  this.currentNow
)
```

这个变化看起来像是 UI 细节，实际意义却更偏产品决策支持：FitTracker 不再只是“自动替你改”，而是开始把“为什么改、改完会怎样”明确交还给用户。

回顾页增强的核心是把“最近训练”和“周趋势”从页面 UI 中抽成纯服务。页面只负责选择筛选项和展示结果，时间窗口、完成率和训练容量计算交给 `ReviewInsightsService`。

```ts
createRecentFilters(sessions: WorkoutSession[], now: number): ReviewRecentSessionFilterOption[] {
  this.currentReferenceTime = now
  const filters: ReviewRecentSessionFilterOption[] = []
  filters.push(this.createFilterOption('recent_7_days', '最近 7 天', '聚焦最近一周训练', sessions, now))
  filters.push(this.createFilterOption('recent_30_days', '最近 30 天', '看近一个月节奏', sessions, now))
  filters.push(this.createFilterOption('all_sessions', '全部记录', '查看所有已保存训练', sessions, now))
  return filters
}
```

训练记录编辑也被拆成独立模型。它不会直接改页面状态，而是从已保存的 `WorkoutSession` 创建编辑态，再根据重量、次数输入重新计算完成组数、总容量和 1RM 估算值。

```ts
createEditModel(session: WorkoutSession): WorkoutSessionEditModel {
  const parsedNotes: ParsedSessionNotes = this.parseSessionNotes(session.notes, session.totalSets)
  const sets: WorkoutSessionEditSet[] = this.createEditSets(session.sets)
  const model: WorkoutSessionEditModel = {
    sessionId: session.sessionId,
    planId: session.planId,
    dayId: session.dayId,
    startedAt: session.startedAt,
    endedAt: session.endedAt,
    durationSeconds: session.durationSeconds,
    fatigueScore: session.fatigueScore,
    targetSets: parsedNotes.targetSets,
    completedSets: this.countCompletedSets(sets),
    customNotes: parsedNotes.customNotes,
    sets: sets
  }
  return model
}
```

训练草稿则采用 Preferences 持久化，保存的是一个完整但轻量的快照。这里比较关键的是校验：草稿恢复前先确认字段形状，避免把损坏 JSON 当成训练状态重新载入。

```ts
export function hasWorkoutDraftProgress(source: WorkoutDraftSnapshot): boolean {
  if (source.completedSets > 0) {
    return true
  }
  for (let exerciseIndex = 0; exerciseIndex < source.exercises.length; exerciseIndex++) {
    const exercise: WorkoutExerciseDraft = source.exercises[exerciseIndex]
    for (let setIndex = 0; setIndex < exercise.sets.length; setIndex++) {
      const setDraft: WorkoutSetDraft = exercise.sets[setIndex]
      if (setDraft.isComplete || setDraft.weightText.length > 0 || setDraft.repsText.length > 0) {
        return true
      }
    }
  }
  return false
}
```

这一阶段的判断是：FitTracker 已经不只是“能完成一次训练”的 demo，而是在补齐用户真正会遇到的边界条件。记录会被改、训练会中断、回顾需要切片，这些都是本地训练应用必须面对的细节。

### 2026-06-01 至 2026-06-03：回归脚本开始成为开发节奏的一部分

自动化回归也有明显变化。2026-06-01 的认证回归在 DevEco 模拟器上通过，覆盖注册、重启后会话恢复，以及登录态下首页和目标页的分流。2026-06-03 的 Midscene 摘要进入 check-only 状态，用于确认 HAP 路径、报告目录、模型配置和失败排查入口是否仍然有效。

这张截图来自最近的 Midscene 报告素材，展示的是动作详情页。它说明内容库已经能把动作名称、目标肌群、器械、步骤、注意事项、替代动作和训练提示呈现出来；后续如果接入媒体资源，也会优先围绕这个详情页做最小闭环。

![FitTracker 动作详情页回归截图](/images/fittracker/devlog/2026-06-01-exercise-detail.jpeg)

回归工作最大的收益不是“多了一个脚本”，而是开发节奏被固定下来：每次功能收口后，都能用相同入口检查构建产物、模拟器连接、报告输出和失败说明。对于 ArkUI 项目来说，这比只看编译结果更可靠，因为很多问题只有真实页面流转后才会暴露。

### 2026-06-02：Phase 3.5 范围收敛

Phase 3 文档把后续方向收敛成两条低耦合路线：本地备份/恢复 MVP，以及动作详情媒体能力的最小闭环。这个判断很重要，因为 FitTracker 当前是本地优先、无后端、无账号体系的应用，最需要优先保护的是用户自有数据：目标、计划、当前计划指针和训练记录。

内容库和媒体资源暂时不适合整体备份。动作种子内容可以重新导入，本地内容数据库也可以重建；真正不能轻易丢的是用户在训练过程中生成的数据。因此，后续更合理的路线是先做应用内手动导出/导入 JSON 包，再评估是否挂载到系统级 `EntryBackupAbility`。

动作详情媒体化也被拆成更小的步骤：先补齐资源字段、授权信息、占位和降级策略，再考虑轻量播放器。这样可以避免一上来把播放器、缓存、版权、包体和离线资源全部混在一起。

### 2026-05 下旬至 2026-06-01：基础训练产品闭环

在更早的阶段，项目已经完成了启动路由、目标设置、计划生成、训练预览、训练执行、训练总结、回顾统计和动作详情等主链路。动作内容库从 35 条扩充到 50 条，并引入覆盖校验；PlanEngine 也加入了候选评分、难度/器械兜底和预览解释，让计划生成结果更容易理解。

本地存储方面，目标、计划和训练记录都落在 Preferences 中；内容库则从 JSONL 种子数据逐步走向本地数据库适配。这个结构保持了“用户数据本地保存、内容数据可重建”的边界，也为后续备份恢复范围划定提供了依据。

到这里，FitTracker 的阶段定位很清楚：第一阶段做出训练应用的完整可用链路；第二阶段用内容库、计划解释和回归脚本提高可信度；第三阶段开始处理恢复、修正、复盘这些真实使用中的长期体验。
