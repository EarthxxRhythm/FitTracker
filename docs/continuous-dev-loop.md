# FitTracker Continuous Dev Loop

## Goal

Keep FitTracker moving without waiting for manual task picking each round.

This loop is intentionally small and local-first. It is designed for this
workspace, this Windows machine, and the current Codex + DevEco workflow.

## Core Idea

The development loop is driven by three checked-in artifacts:

1. `tasks/project-queue.json`
2. `docs/blockers.md`
3. `tools/continuous-dev.ps1`

The script does not edit code by itself. It does one simpler job:

- read the queue
- read blockers
- inspect repo state
- select the next ready task
- print a compact execution packet

That packet is what the Delivery Lead or a future supervisor uses to keep work
flowing.

## Default Loop

1. Read `AGENTS.md`, `git status --short`, and recent commits.
2. Read `tasks/project-queue.json`.
3. Filter out:
   - done tasks
   - blocked tasks
   - tasks whose dependencies are not done
4. Pick the highest-priority ready task.
5. Implement only that task.
6. Run the shortest matching validation chain.
7. Update queue state, blockers, and progress notes.
8. Move to the next task.

## Task Rules

Each queue item should define:

- `id`
- `title`
- `lane`
- `status`
- `priority`
- `dependsOn`
- `requires`
- `summary`
- `validation`
- `doneDefinition`

### Status values

- `todo`
- `doing`
- `blocked`
- `done`

### Requires tags

Use short machine-readable tags:

- `repo-only`
- `device`
- `decision`
- `network`

## Blocker Rules

Blockers live in `docs/blockers.md`.

Only use blockers for things that genuinely stop the next task, for example:

- no HDC target connected
- signing material missing
- product decision required
- external account or credential missing

Do not mark normal warnings or optional polish as blockers.

## Validation Ladder

Use the shortest validation chain that matches risk:

1. `node tools/check-gates.mjs`
2. local build
3. `tools/ohos-test.ps1`
4. focused smoke
5. short device validation

Avoid long regression unless the task actually touches a shared risky path.

## Commit Boundary Rules

- One lane at a time when possible.
- Do not mix visual refactor and content-sync changes in one commit.
- Do not include `test_run/`, blog files, Obsidian notes, or screenshots in repo commits.
- If a task is blocked by device state, move to the next ready repo-only task instead of stalling.

## Current FitTracker Priority

Current practical order:

1. repo-only validation/tooling hardening while device state is blocked
2. restore a usable HDC target (`Ready` or `Connected`)
3. rerun final short device-backed acceptance:
   - `tools/auth-regression.ps1`
   - `tools/dev-smoke.ps1 -Target current-plan`
   - `tools/dev-smoke.ps1 -Target both`
4. final closeout audit

## Dry Run Usage

```powershell
powershell -ExecutionPolicy Bypass -File tools/continuous-dev.ps1 -DryRun
```

## Normal Usage

```powershell
powershell -ExecutionPolicy Bypass -File tools/continuous-dev.ps1
```
