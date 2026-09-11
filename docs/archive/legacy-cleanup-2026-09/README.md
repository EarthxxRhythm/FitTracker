# legacy-cleanup-2026-09（历史遗留归档）

本目录收纳 2026-09 清理出的"旧版本 / 与当前主线无关"文件，全部经 `git mv` 移动，内容未删除。

## 分类说明

| 子目录 | 内容 | 处置原因 |
|---|---|---|
| `planning/` | 根级旧规划文件：`features.json`、`tasks*.json`、`init.sh`、`项目开发日志.txt` | 已被 AGENTS.md 与 `docs/tasks.*.json` 取代，0 活跃引用（`task-relay.ps1` 候选已更新） |
| `tools/` | 旧 UI 验收工具族：`live-device-probe.ps1`、`prepare-ui-acceptance.mjs`、`export-ui-acceptance-samples.mjs`、`generate-ui-acceptance-record.mjs` | 断言已归档布局（`features/review/...`、旧 workout 页名），与 pencil 主线不符，仅被历史验收文档引用 |
| `components/` | 死代码组件：`AppInput.ets`、`SearchBar.ets`、`PrimaryDestinationStrip.ets` | 全 ets 零引用 |
| `agent-state/` | 被误提交的代理状态：`.opencode` 运行时 db/截图/研究素材、`.sisyphus` 整套规划笔记 | 运行时/规划状态不属于产品源码；`.opencode/data|screenshot`、`/.sisyphus/` 已加入 `.gitignore` 防再提交 |
| `devlog/` | 孤儿内容：`content/post/fittracker-devlog.md`、`static` devlog 配图 | 全库无任何代码/文档引用 |

## 保留说明（未动）

- `content/exercises/*`：动作库种子，仍被内容构建链路消费，活跃。
- `tools/seed-review-metrics-device.ps1`、`capture-*motion*`、`compare-*`、`render-*`：属于当前视觉主线/运动恢复工作流。
- `.opencode/skills|commands|docs/rules.md`：代理能力与仓库规则，仍在用。
