# FitTracker UI Final Acceptance Runbook

Last updated: 2026-06-11

> ⚠️ **2026-09-11 校准：本文档引用的工具链已失效，保留仅作方法论参考。**
> 已归档（移入 `docs/archive/legacy-cleanup-2026-09/tools/`，`tools/` 下已不存在）的脚本：`tools/prepare-ui-acceptance.mjs`、`tools/generate-ui-acceptance-record.mjs`、`tools/export-ui-acceptance-samples.mjs`、`tools/live-device-probe.ps1`
> 文中的 `midscene_run/...` 证据路径与 `WorkoutSummaryPage` 等页名同属 pencil 主线之前的体系。
> **当前视觉验收主线**：
> - `design/06_prototype_redraw/ACCEPTANCE-PLAN.md` —— 验收口径
> - `design/06_prototype_redraw/STATUS.md` —— 进度与基线数值
> - `design/06_prototype_redraw/scripts/check_sync.py` —— 上游设计源对账
> - `tools/visual-diff/compare.py` —— 像素对比（`--crop` 内容区口径）
> - 设备侧：`devecocli emulator start "<name>"` → `devecocli run` → `devecocli ui screenshot`

## Purpose

This runbook turns the remaining UI/UX closeout gap into a short, repeatable manual pass.

Use it together with:

- `docs/ui-acceptance-checklist.md`
- `docs/ui-design-review-packet.md`
- `docs/ui-acceptance-record-template.md`
- `node tools/check-closeout-evidence.mjs`
- `node tools/prepare-ui-acceptance.mjs`
- `node tools/generate-ui-acceptance-record.mjs`
- `node tools/export-ui-acceptance-samples.mjs`

## Target Outcome

At the end of this pass, you should be able to answer one question clearly:

> Does the current FitTracker app feel like one coherent, calm, premium training tool across the full main route set?

This pass is not meant to rediscover functional bugs already covered by auth regression and focused smoke. It is meant to confirm final visual consistency, flow clarity, interaction polish, and product tone.

## Prerequisites

Device and environment:

- HarmonyOS device or simulator available at `127.0.0.1:5555`
- Current app build already installed, or installable from the latest unsigned HAP

Recommended precheck:

```powershell
node tools/check-closeout-evidence.mjs
node tools/prepare-ui-acceptance.mjs
node tools/generate-ui-acceptance-record.mjs
node tools/export-ui-acceptance-samples.mjs
```

Proceed only if the result is `passed`.

If Midscene is temporarily unavailable but the device is connected, you can still run a short native probe before or during the manual pass:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/live-device-probe.ps1 -Scenario review-membership
powershell -NoProfile -ExecutionPolicy Bypass -File tools/live-device-probe.ps1 -Scenario review-workout-loop
powershell -NoProfile -ExecutionPolicy Bypass -File tools/live-device-probe.ps1 -Scenario review-backup-card
powershell -NoProfile -ExecutionPolicy Bypass -File tools/live-device-probe.ps1 -Scenario review-exercise-detail
powershell -NoProfile -ExecutionPolicy Bypass -File tools/live-device-probe.ps1 -Scenario review-plan-detail
```

This does not replace the broader artifact set, but it gives fresh route evidence for live taps without relying on the AI provider.

## Acceptance Order

Review the routes in this exact order so the product reads as one connected experience:

1. `LoginPage`
2. `RegisterPage`
3. `GoalSetupPage`
4. `PencilHomePage`
5. `PencilPreviewPage`
6. `PencilActivePage`
7. `WorkoutSummaryPage`
8. `PencilReviewPage`
9. `ExerciseLibraryPage`
10. `ExerciseDetailPage`
11. `PencilPlanPage`
12. `MonetizationHubPage`

## Recommended Session Structure

### Pass 1: Core flow read

Goal:

- decide whether the workout lane feels coherent from entry to review

Routes:

- login
- register
- goal setup
- home
- preview
- active
- summary
- review

What to watch:

- whether the primary CTA is obvious within seconds
- whether spacing and typography scale feel stable from page to page
- whether summary feels calmer than active workout
- whether review feels information-rich but still scannable

### Pass 2: Secondary route read

Goal:

- decide whether non-core routes still match the same product language

Routes:

- exercise library
- exercise detail
- training plan detail
- monetization hub

What to watch:

- whether library/detail feel like knowledge tools, not disconnected content pages
- whether preset plan detail feels supportive rather than competing with today's plan
- whether monetization hub stays secondary and clearly non-production

## Route-by-Route Prompts

Use these prompts while reviewing.

### LoginPage

- Does the screen feel lighter than the workout product, not heavier?
- Is the next action obvious without reading every line?

### RegisterPage

- Does the handoff from login to register feel like the same app?
- Are validation and status texts intentional rather than noisy?

### GoalSetupPage

- Are grouped choices easy to scan?
- Does the generate-plan action clearly read as the terminal action?

### PencilHomePage

- Does today's training card dominate the page?
- Do preset plans feel secondary rather than distracting?

### PencilPreviewPage

- Does this feel like a natural continuation from home?
- Is the start-training action visually dominant?

### PencilActivePage

- Does the screen feel operational and focused rather than busy?
- Are the repeated input controls visually stable?

### WorkoutSummaryPage

- Does the page feel calmer than active workout?
- Does it read as reflection/closure instead of more execution?

### PencilReviewPage

- Can you scan the page top-to-bottom without feeling lost?
- Do trends, backup, and upgrade entry coexist without visual competition?

### ExerciseLibraryPage

- Do filters feel practical and quick to scan?
- Does the page still look like part of the main app, not a bolt-on catalog?

### ExerciseDetailPage

- Does the media block feel integrated into instruction?
- Does premium content read as optional extension instead of interruption?

### PencilPlanPage

- Can you scan the structure before committing?
- Is the default enable path still clearer than advanced exploration?

### MonetizationHubPage

- Does this read as capability preview rather than checkout theater?
- Is local preview language clearly non-production?

## Evidence You Already Have

Use existing machine-backed evidence to avoid re-testing what is already proved:

- auth and startup:
  - `midscene_run/auth/20260611-061821-p194800/midscene-auth-regression-summary.md`
- home -> preview -> active:
  - `midscene_run/focused/current_plan-20260611-055030-p164332/midscene-entrypoints-smoke-summary.md`
- review backup + exercise media:
  - `midscene_run/focused/both-20260611-033617-p68784/midscene-entrypoints-smoke-summary.md`
- plan detail:
  - `midscene_run/focused/plan_detail-20260611-050345-p138852/midscene-entrypoints-smoke-summary.md`
- summary page:
  - `midscene_run/focused/summary_page-20260611-045618-p116148/midscene-entrypoints-smoke-summary.md`

Manual acceptance should build on these artifacts rather than duplicate them.

If you want the route order, focus points, and supporting artifacts in one place, run:

```powershell
node tools/prepare-ui-acceptance.mjs
node tools/prepare-ui-acceptance.mjs --json
node tools/generate-ui-acceptance-record.mjs
node tools/export-ui-acceptance-samples.mjs
```

The sample exporter writes representative first/last screenshots for each referenced Midscene report under:

- `midscene_run/ui_acceptance_samples/`
- `midscene_run/ui_acceptance_samples/manifest.json`

## What Counts as Blocking

Mark a route as blocking only if one of these is true:

- it visibly breaks the target calm, premium, operational style
- the primary task path is confusing
- layout overlap, clipping, or accidental jumping is obvious
- a secondary monetization or upgrade surface feels louder than the workout product

Do not block for:

- personal preference without product impact
- tiny wording tweaks
- polish ideas that do not change hierarchy or user trust

## Closeout Decision Rule

UI/UX can be treated as accepted when:

- all routes in the acceptance order have been reviewed
- the record template is filled
- no route has a blocking issue
- any notes left are polish-only

## Expected Output

Record the result in:

- `docs/ui-acceptance-record-template.md`

Once filled, that record becomes the missing human evidence referenced by `docs/closeout-audit.md`.
