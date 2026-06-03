+++
title = "FitTracker 开发日志"
date = 2026-06-03T23:45:00+08:00
draft = false
tags = ["HarmonyOS", "ArkUI", "FitTracker", "开发日志"]
categories = ["项目复盘"]
+++

FitTracker 是一个本地优先的 HarmonyOS ArkUI 健身训练记录应用：用户可以设置训练目标、生成计划、执行训练、记录重量和次数，并在回顾页查看周统计、历史趋势和个人纪录。这个开发日志记录的是项目从基础功能闭环到回归工具化、再到回顾体验增强的阶段变化。

## 开发日志

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
