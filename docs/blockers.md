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
