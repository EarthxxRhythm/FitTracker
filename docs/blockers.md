# FitTracker Blockers

Use this file to record only the blockers that should change task routing.

## Active

- `midscene.provider_overdue`
  - status: active on 2026-06-11
  - scope: `focused-smoke`, `auth-regression`, closeout evidence refresh
  - note: latest `both` rerun failed with `403 AccountOverdueError` from the external Midscene provider, and fresh AI-assisted `current-plan` / `membership` live-pass attempts on 2026-06-11 were blocked at the startup assertion for the same reason. Treat this as an external evidence-refresh blocker, not as proof of an app regression.
  - tooling (2026-09-11 corrected): this entry used to recommend `tools/live-device-probe.ps1`, which has since been **archived** to `docs/archive/legacy-cleanup-2026-09/tools/`（其断言针对旧页面布局，与 pencil 主线不符）. Provider-independent device probing now uses:
    - `devecocli ui layout`（当前屏可见节点树）+ `devecocli ui screenshot --path <png>`
    - `devecocli log --level E --from 5m --tail 200`（错误日志）
    - `node tools/check-closeout-evidence.mjs`（证据门禁；源目录缺失时返回 `evidence-missing` 并 exit 2，不再抛 ENOENT 栈）
    - 仍然有效的设备脚本：`tools/auth-regression.ps1`、`tools/dev-smoke.ps1`、`tools/seed-review-metrics-device.ps1`

## Inactive / Cleared

- `device.hdc_unavailable`
  - status: cleared on 2026-06-11
  - scope: `performance-lab`, `ohosTest`, `focused-smoke`
  - note: `hdc list targets -v` now reports `127.0.0.1:5555 TCP Connected localhost hdc`, so device-backed validation can resume. Keep using short-chain acceptance first and only restore this blocker if repeated Midscene runs fall back to `Offline` again.

## How to Use

- If a task requires `device`, skip it while `device.hdc_unavailable` is active.
- If a task requires `decision`, skip it until the product choice is made.
- If a task is repo-only, do not let this blocker stop the loop.


## starflow council 在本环境不可用（2026-09-13 实测）

**结论**：星流的 council 阶段在本环境下接近确定性失败，且**增加席位无助于通过、反而有害**。根因在平台层，项目侧无法修复。视觉与发布推进已改用 galaxy + 手工。

### 实测记录

| # | 席位 | 有效 | 法定 | 结果 |
|---|---|---|---|---|
| 1 | 3（默认） | 2 | 2 | ✅ 通过（天权否决：门禁判据死锁） |
| 2 | 3（默认） | 2 | 2 | ✅ 通过（天府否决：tooling 条目前提已证伪） |
| 3 | 3（自定义 seats） | 0 | 2 | ❌ 流会（missing_artifact×3） |
| 4 | 3（默认） | 0 | 2 | ❌ 流会（malformed_json×2 + missing_artifact×1），elapsed 350s |
| 5 | 3（默认） | 0 | 2 | ❌ 流会（malformed_json×2 + missing_artifact×1），elapsed 278s |
| 6 | **5（本次实测）** | **0** | **4** | ❌ **流会（malformed_json×4 + missing_artifact×1）** |

> #4/#5 的 elapsed 来自 `.rivet/starflow/*.json` 的 `elapsedMs`（350149 / 278380），其余来自调用记录。

### 关键发现

1. **席位确实启动并运行**：失败调用耗时 4.6–5.8 分钟，非启动即挂。
2. **与输入无关**：draftItems 由 7 条压到 4 条、去掉全部转义引号后，失败率不变 → 排除输入过大/格式问题。
3. **与 seats 配置无关**：自定义 seats 与默认 seats 均失败。
4. **增加席位无益且有害**：法定人数按 2/3 比例同步提高（5 席 → 需 4 席有效），单席成功率不变时**通过概率反而下降**。实测 5 席 0/5 有效。
5. **同席位非确定性**：tianquan 有时给出高质量否决、有时 malformed_json → 故障在执行环境而非配置。

### 根因

`AGENTS.md:98` 已记录：平台 inter-agent `message` 载荷投递不可靠（spawn/followup/send 会触发回合但内容可能为空）。项目为此立了 `cluster/inbox` 文件信箱协议绕过——但那是给**手工 spawn 的 subagent** 用的；starflow 是框架内置编排，其席位 spawn 走标准 message 路径，**绕不开**。席位拿不到内容 → 无从评审 → 不产出（missing_artifact）或产出乱码（malformed_json）。

**对照证据**：galaxy 的 4 个维度 worker 全部成功执行（337s / 393s / 407s / 272s 且产出实质结果）。差异在于 galaxy 用结构化 `objective` 字段传任务，而 starflow 席位需接收长计划正文。

### 处置

星流不适用于本环境。若后续仍要用，需先确认平台消息通道恢复；在此之前用 galaxy + 手工。
