# FitTracker dev smoke

`tools/dev-smoke.ps1` is a thin wrapper around `tools/midscene-entrypoints-smoke.ps1`.
By default it runs the current-plan focused smoke target:

- `current-plan`

It also supports the existing focused smoke targets:

- `backup-card`
- `media-card`
- `membership`
- `both`

It does not start `tools/midscene-regression.ps1`.

## Run

Set `MIDSCENE_MODEL_API_KEY` in the current PowerShell session first, then run:

```powershell
powershell -ExecutionPolicy Bypass -File tools/dev-smoke.ps1
```

Common variants:

```powershell
powershell -ExecutionPolicy Bypass -File tools/dev-smoke.ps1 -DeviceId '127.0.0.1:5555'
powershell -ExecutionPolicy Bypass -File tools/dev-smoke.ps1 -SkipInstall
powershell -ExecutionPolicy Bypass -File tools/dev-smoke.ps1 -ResetAppData
powershell -ExecutionPolicy Bypass -File tools/dev-smoke.ps1 -CheckOnly
powershell -ExecutionPolicy Bypass -File tools/dev-smoke.ps1 -Target current-plan
powershell -ExecutionPolicy Bypass -File tools/dev-smoke.ps1 -Target backup-card
powershell -ExecutionPolicy Bypass -File tools/dev-smoke.ps1 -Target media-card
powershell -ExecutionPolicy Bypass -File tools/dev-smoke.ps1 -Target membership
powershell -ExecutionPolicy Bypass -File tools/dev-smoke.ps1 -Target both
```

## Behavior

- Prepares Midscene env with `tools/midscene-env.ps1` by default.
- Delegates execution to `tools/midscene-entrypoints-smoke.ps1`.
- Uses `Target=current-plan` by default, so one daily run only checks `Home -> Preview -> Active`.
- Keeps `Target=membership` available for the commercialization short chain: `Review -> Membership -> local tier preview`.
- Keeps `Target=both` available when you want to cover `backup-card` and `media-card` together.
- In `-CheckOnly` mode, validates script inputs and HAP prerequisites without requiring a ready HDC device.
- Keeps artifacts under `midscene_run/focused/`.

Use `-SkipPrepareEnv` when the current shell already has the required Midscene env vars.
