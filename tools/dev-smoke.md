# FitTracker dev smoke

`tools/dev-smoke.ps1` is a thin wrapper around `tools/midscene-entrypoints-smoke.ps1`.
By default it runs only the two focused smoke targets:

- `backup-card`
- `media-card`

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
powershell -ExecutionPolicy Bypass -File tools/dev-smoke.ps1 -Target backup-card
powershell -ExecutionPolicy Bypass -File tools/dev-smoke.ps1 -Target media-card
```

## Behavior

- Prepares Midscene env with `tools/midscene-env.ps1` by default.
- Delegates execution to `tools/midscene-entrypoints-smoke.ps1`.
- Uses `Target=both` by default, so one daily run covers `backup-card` and `media-card`.
- Keeps artifacts under `midscene_run/focused/`.

Use `-SkipPrepareEnv` when the current shell already has the required Midscene env vars.
