# FitTracker File Organization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce repository ambiguity by aligning active routes, legacy pages, and service-layer ownership with the current feature-first FitTracker structure without changing product behavior.

**Architecture:** Treat this as a low-risk repository hygiene pass, not a feature rewrite. First classify runtime-active files versus historical or support artifacts, then remove or relocate only files that have no route registration and no import references, and finally update knowledge files so future edits follow the same boundaries.

**Tech Stack:** HarmonyOS Stage Mode, ArkTS/ArkUI, `@kit.ArkData` preferences, PowerShell, `rg`, git.

## Global Constraints

- Current worktree is already dirty on July 20, 2026; do not move, rename, or delete files already listed by `git status --short` unless the user explicitly wants that overlap.
- Keep active main-line routes registered exactly from `entry/src/main/resources/base/profile/main_pages.json`.
- `pages/Index.ets` and `pages/ProfilePage.ets` remain legacy shells and must not be reintroduced into the main route.
- Preserve singleton service exports in `entry/src/main/ets/common/services/*.ets` and `entry/src/main/ets/shared/services/*.ets`.
- Do not hardcode design values; no visual behavior changes are part of this plan.
- Verify route and import reachability before deleting or moving any `.ets` file.

---

## File Structure

Active runtime areas that stay in place:

- `entry/src/main/ets/app/`: startup and route constants.
- `entry/src/main/ets/features/`: main product pages and feature-local bridge services.
- `entry/src/main/ets/shared/`: cross-feature domain/view-model/content services.
- `entry/src/main/ets/common/`: core persistence/auth/profile services and design tokens.
- `entry/src/main/resources/base/profile/main_pages.json`: authoritative main-line route registry.

Files and folders to classify during execution:

- `entry/src/main/ets/pages/ExerciseDetailPage.ets`: appears orphaned because the route and all code references point at `features/exercise/pages/ExerciseDetailPage.ets`.
- `entry/src/main/ets/pages/Index.ets`
- `entry/src/main/ets/pages/ProfilePage.ets`
- `entry/src/main/ets/features/workout/services/WorkoutSessionPersistenceBridgeService.ets`: intentional bridge between legacy persistence and new repository state.
- `0`: stray top-level file with unknown purpose.
- `design/`
- `test_run/`

Documentation files likely needing alignment after cleanup:

- `AGENTS.md`
- `entry/src/main/ets/pages/AGENTS.md`
- `entry/src/main/ets/common/services/AGENTS.md`
- `docs/旧页面治理清单.md`

---

### Task 1: Freeze Baseline and Record Ownership

**Files:**
- Create: `docs/repo-file-audit-2026-07-20.md`
- Inspect: `entry/src/main/resources/base/profile/main_pages.json`
- Inspect: `entry/src/main/ets/app/AppRoutes.ets`
- Inspect: `entry/src/main/ets/pages/AGENTS.md`
- Inspect: `entry/src/main/ets/common/services/AGENTS.md`

**Interfaces:**
- Consumes: current route registry, import graph, and dirty-worktree status.
- Produces: a written baseline that later cleanup tasks can follow without guessing ownership.

- [ ] **Step 1: Capture current dirty-worktree baseline**

Run:

```powershell
git status --short
```

Expected: many existing modified files remain visible; this output becomes the "do not overlap" boundary for the cleanup pass.

- [ ] **Step 2: Capture route authority snapshot**

Run:

```powershell
Get-Content -Path 'entry/src/main/resources/base/profile/main_pages.json'
Get-Content -Path 'entry/src/main/ets/app/AppRoutes.ets'
```

Expected: both files agree that active exercise detail routing points to `features/exercise/pages/ExerciseDetailPage`.

- [ ] **Step 3: Create audit note**

Create `docs/repo-file-audit-2026-07-20.md` with:

```markdown
# Repo File Audit - 2026-07-20

## Active Main-Line Pages

- `app/StartupPage`
- `pages/LoginPage`
- `pages/RegisterPage`
- `features/onboarding/pages/GoalSetupPage`
- `pages/HomePage`
- `features/exercise/pages/ExerciseLibraryPage`
- `features/exercise/pages/ExerciseDetailPage`
- `features/monetization/pages/MonetizationHubPage`
- `features/workout/pages/TrainingPlanDetailPage`
- `features/workout/pages/WorkoutPreviewPage`
- `features/workout/pages/ActiveWorkoutPage`
- `features/workout/pages/WorkoutSummaryPage`
- `features/review/pages/ReviewHomePage`

## Legacy or Suspect Files

- `entry/src/main/ets/pages/Index.ets`
- `entry/src/main/ets/pages/ProfilePage.ets`
- `entry/src/main/ets/pages/ExerciseDetailPage.ets`
- `0`

## Service Boundary Notes

- `common/services`: persistence, auth, user profile, stable app-level stores.
- `shared/services`: cross-feature content, plan, review, backup, sync, and derived view-model logic.
- `features/workout/services`: compatibility bridges and workout-page-specific orchestration.
```

- [ ] **Step 4: Verify the audit note is the only new artifact**

Run:

```powershell
git status --short docs/repo-file-audit-2026-07-20.md
```

Expected: only the new audit note appears for this task.

- [ ] **Step 5: Commit**

```powershell
git add docs/repo-file-audit-2026-07-20.md
git commit -m "docs: add repo file audit baseline"
```

---

### Task 2: Retire the Orphaned Legacy Exercise Detail Page

**Files:**
- Delete: `entry/src/main/ets/pages/ExerciseDetailPage.ets`
- Modify: `entry/src/main/ets/pages/AGENTS.md`
- Modify: `docs/旧页面治理清单.md`

**Interfaces:**
- Consumes: proof that `entry/src/main/ets/pages/ExerciseDetailPage.ets` has no route registration and no import references.
- Produces: a `pages/` directory that contains only auth pages, `HomePage`, and explicit legacy shells.

- [ ] **Step 1: Prove the file is orphaned**

Run:

```powershell
rg -n "pages/ExerciseDetailPage|ExerciseDetailPage\.ets" entry/src/main/resources/base/profile/main_pages.json entry/src/main/ets
```

Expected: matches only show `features/exercise/pages/ExerciseDetailPage` and no runtime reference to `pages/ExerciseDetailPage.ets`.

- [ ] **Step 2: Update the pages knowledge file before deletion**

In `entry/src/main/ets/pages/AGENTS.md`, ensure the structure list contains only:

```markdown
- `RegisterPage.ets`
- `LoginPage.ets`
- `HomePage.ets`
- `Index.ets`
- `ProfilePage.ets`
```

And remove any stale mention that suggests there is a page-level `ExerciseDetailPage` under `pages/`.

- [ ] **Step 3: Update the legacy governance note**

In `docs/旧页面治理清单.md`, add one line under the deleted pages section:

```markdown
- `pages/ExerciseDetailPage.ets`（旧版页面，已由 `features/exercise/pages/ExerciseDetailPage.ets` 完全替代）
```

- [ ] **Step 4: Delete the orphaned file**

Run:

```powershell
Remove-Item -LiteralPath 'entry/src/main/ets/pages/ExerciseDetailPage.ets'
```

Expected: the file is removed and no route registration changes are needed.

- [ ] **Step 5: Verify no references remain**

Run:

```powershell
rg -n "pages/ExerciseDetailPage|ExerciseDetailPage\.ets" entry/src/main/resources/base/profile/main_pages.json entry/src/main/ets docs
```

Expected: only references to `features/exercise/pages/ExerciseDetailPage` remain, plus the historical note in `docs/旧页面治理清单.md`.

- [ ] **Step 6: Commit**

```powershell
git add entry/src/main/ets/pages/AGENTS.md docs/旧页面治理清单.md entry/src/main/ets/pages/ExerciseDetailPage.ets
git commit -m "refactor: remove orphaned legacy exercise detail page"
```

---

### Task 3: Clarify Service Ownership Without Moving Dirty Files

**Files:**
- Create: `entry/src/main/ets/shared/AGENTS.md`
- Create: `entry/src/main/ets/features/workout/services/AGENTS.md`
- Modify: `entry/src/main/ets/common/services/AGENTS.md`

**Interfaces:**
- Consumes: current import graph showing `common/services` and `shared/services` intentionally coexist.
- Produces: durable ownership rules so future cleanup can move files with less guesswork.

- [ ] **Step 1: Capture the current coupling points**

Run:

```powershell
rg -n "TrainingPlanService|WorkoutSessionService|ContentRepository|WorkoutRepository|PlanEngine|ReviewService" entry/src/main/ets/pages entry/src/main/ets/features entry/src/main/ets/shared entry/src/main/ets/common
```

Expected: output shows `common/services` still owns persistence-heavy APIs while `shared/services` owns content, planning, and review logic.

- [ ] **Step 2: Create shared service ownership note**

Create `entry/src/main/ets/shared/AGENTS.md` with:

```markdown
# Shared Services - Knowledge Base

## OVERVIEW

`shared/services/` owns cross-feature domain logic, content access, derived view-models, sync state, backup composition, and in-memory repositories used by the current feature-first flow.

## OWNERSHIP

- `ContentRepository`, `ContentDataSource`, `DatabaseContentDataSource`, `JsonlSeedContentDataSource`: content read path
- `PlanEngine`, `GoalSetupService`, `GoalAdjustmentPreviewService`, `HomePlanService`: plan and goal derivation
- `ReviewService`, `ReviewDashboardService`, `ReviewInsightsService`, `WorkoutSummaryService`, `PersonalRecordService`: review and analytics
- `WorkoutRepository`: in-memory workout session state for the new flow
- `SyncService`, `StartupContentSyncService`, `ContentDatabaseService`: content source and sync state
- `UserDataBackupService`, `SystemBackupBridgeService`, `PersistenceFallbackService`: backup and fallback composition

## ANTI-PATTERNS

- Do not add preferences-backed auth or profile persistence here.
- Do not move dirty files out of this folder until the user isolates ongoing feature work.
```

- [ ] **Step 3: Create workout bridge ownership note**

Create `entry/src/main/ets/features/workout/services/AGENTS.md` with:

```markdown
# Workout Feature Services - Knowledge Base

## OVERVIEW

`features/workout/services/` is reserved for workout-flow orchestration that is too specific to live in `shared/services/`, especially compatibility bridges between the legacy persistence model and the current workout pages.

## OWNERSHIP

- `WorkoutSessionPersistenceBridgeService.ets`: syncs `WorkoutRepository` state with `common/services/WorkoutSessionService`
- `WorkoutSessionEditService.ets`: workout summary editing helpers scoped to the workout feature

## ANTI-PATTERNS

- Do not duplicate plan, review, or content lookup logic here.
- Do not add generic repositories here when they are used by multiple features.
```

- [ ] **Step 4: Update the common service ownership note**

Add this section to `entry/src/main/ets/common/services/AGENTS.md`:

```markdown
## BOUNDARY WITH SHARED SERVICES

- Keep preferences-backed app persistence in `common/services/`.
- Keep auth, session token management, and user profile persistence in `common/services/`.
- Use `shared/services/` for feature-first domain logic, content catalogs, review calculations, and in-memory repositories.
- Use `features/*/services/` only for feature-scoped orchestration or compatibility bridges.
```

- [ ] **Step 5: Commit**

```powershell
git add entry/src/main/ets/shared/AGENTS.md entry/src/main/ets/features/workout/services/AGENTS.md entry/src/main/ets/common/services/AGENTS.md
git commit -m "docs: clarify service layer ownership"
```

---

### Task 4: Classify Top-Level Non-Source Artifacts

**Files:**
- Inspect: `0`
- Inspect: `design/`
- Inspect: `test_run/`
- Modify: `.gitignore` (only if currently unmodified; otherwise defer)
- Modify: `docs/repo-file-audit-2026-07-20.md`

**Interfaces:**
- Consumes: top-level artifact inventory.
- Produces: a decision for each stray artifact: keep, ignore, move, or delete.

- [ ] **Step 1: Inspect the stray top-level file**

Run:

```powershell
Get-Item '0' | Format-List *
Get-Content -Path '0'
```

Expected: either the file proves to be junk and can be deleted, or it contains meaningful notes that should be moved into `docs/`.

- [ ] **Step 2: Inspect non-source support folders**

Run:

```powershell
Get-ChildItem -Path 'design' -Force
Get-ChildItem -Path 'test_run' -Force
```

Expected: each folder is classified as committed project asset, generated output, or local scratch space.

- [ ] **Step 3: Record a decision in the audit note**

Append to `docs/repo-file-audit-2026-07-20.md`:

```markdown
## Top-Level Artifact Decisions

- Record one bullet for `0` with the exact decision and one-sentence reason.
- Record one bullet for `design/` with the exact decision and one-sentence reason.
- Record one bullet for `test_run/` with the exact decision and one-sentence reason.
```

- [ ] **Step 4: Update ignore rules only if safe**

Run:

```powershell
git status --short .gitignore
```

Expected: if `.gitignore` is clean, update it for generated-only directories; if `.gitignore` is already modified, defer the ignore-rule change and record that deferral in the audit note.

- [ ] **Step 5: Commit**

```powershell
git add docs/repo-file-audit-2026-07-20.md .gitignore
git commit -m "chore: classify top-level repo artifacts"
```

---

### Task 5: Validate the Cleanup Boundary

**Files:**
- Modify: `docs/repo-file-audit-2026-07-20.md`

**Interfaces:**
- Consumes: outputs from Tasks 1-4.
- Produces: a final go/no-go summary for any later physical file moves inside dirty feature areas.

- [ ] **Step 1: Run static reachability checks**

Run:

```powershell
git diff --check
rg -n "Index\.ets|ProfilePage\.ets|pages/ExerciseDetailPage|features/exercise/pages/ExerciseDetailPage" entry/src/main/resources/base/profile/main_pages.json entry/src/main/ets docs
```

Expected: no whitespace issues; only approved legacy references remain.

- [ ] **Step 2: Run build validation if toolchain is available**

Run:

```powershell
hvigorw assembleHap --mode module -p product=default
```

Expected: build succeeds, or the first failure is unrelated to the cleanup and is recorded with exact file and line context in `docs/repo-file-audit-2026-07-20.md`.

- [ ] **Step 3: Add final boundary summary**

Append to `docs/repo-file-audit-2026-07-20.md`:

```markdown
## Final Boundary Summary

- Add a `Safe to clean now` list containing only files proven to be unregistered and unreferenced.
- Add a `Must wait until current dirty feature work is isolated` list containing dirty files or folders that overlap active changes.
- Add a `Follow-up candidates after the workspace is clean` list containing structural cleanup items that still need a second pass.
```

- [ ] **Step 4: Commit**

```powershell
git add docs/repo-file-audit-2026-07-20.md
git commit -m "docs: record cleanup boundary summary"
```

## Self-Review

Spec coverage:

- Active route ownership is covered by Task 1.
- Legacy page retirement is covered by Task 2.
- Service boundary clarification is covered by Task 3.
- Root-level artifact cleanup is covered by Task 4.
- Validation and deferred-risk documentation are covered by Task 5.

Placeholder scan:

- Every task names exact files and commands.
- The only `KEEP | MOVE | DELETE` placeholders exist inside a deliberate decision template that must be replaced during execution.

Type consistency:

- All route references use the same paths discovered in `main_pages.json` and `AppRoutes.ets`.
- Service-layer terminology is consistent across `common/services`, `shared/services`, and `features/workout/services`.
