# FitTracker Blockers

Use this file to record only the blockers that should change task routing.

## Active

- `device.hdc_unavailable`
  - status: active
  - scope: `performance-lab`, `ohosTest`, `focused-smoke`
  - note: `hdc list targets -v` is not reaching a usable `Ready` / `Connected` target on this machine right now. Empty output, `Unknown`, and `Offline` targets should all be treated as blocked.

## Inactive / Cleared

- none

## How to Use

- If a task requires `device`, skip it while `device.hdc_unavailable` is active.
- If a task requires `decision`, skip it until the product choice is made.
- If a task is repo-only, do not let this blocker stop the loop.
