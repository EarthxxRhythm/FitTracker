param(
  [string]$DeviceId = "",
  [string]$BundleName = "com.example.fittracker_opencode",
  [string]$AbilityName = "EntryAbility",
  [string]$HapPath = "entry/build/default/outputs/default/entry-default-unsigned.hap",
  [switch]$SkipInstall,
  [switch]$SkipDisconnect,
  [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"

function Invoke-Step {
  param(
    [string]$Title,
    [string[]]$Command
  )

  Write-Host ""
  Write-Host "[FitTracker Midscene] $Title"
  & $Command[0] @($Command | Select-Object -Skip 1)
  if ($LASTEXITCODE -ne 0) {
    throw "Step failed: $Title"
  }
}

function Invoke-Hdc {
  param(
    [string]$Title,
    [string[]]$Args
  )

  $fullArgs = @()
  if ($DeviceId.Length -gt 0) {
    $fullArgs += @("-t", $DeviceId)
  }
  $fullArgs += $Args
  Invoke-Step -Title $Title -Command (@("hdc") + $fullArgs)
}

function Invoke-Midscene {
  param(
    [string]$Title,
    [string[]]$Args
  )

  $fullArgs = @("-y", "@midscene/harmony@1") + $Args
  if ($DeviceId.Length -gt 0) {
    $fullArgs += @("--deviceId", $DeviceId)
  }
  Invoke-Step -Title $Title -Command (@("npx.cmd") + $fullArgs)
}

function Assert-MidsceneEnvironment {
  if ($env:MIDSCENE_MODEL_API_KEY.Length -eq 0 -or
    $env:MIDSCENE_MODEL_NAME.Length -eq 0 -or
    $env:MIDSCENE_MODEL_BASE_URL.Length -eq 0 -or
    $env:MIDSCENE_MODEL_FAMILY.Length -eq 0) {
    throw "Missing Midscene model environment variables. Set MIDSCENE_MODEL_API_KEY, MIDSCENE_MODEL_NAME, MIDSCENE_MODEL_BASE_URL and MIDSCENE_MODEL_FAMILY, or create a local .env file."
  }
}

function Invoke-VisualAssert {
  param(
    [string]$Title,
    [string]$Prompt
  )

  Invoke-Midscene -Title $Title -Args @("assert", "--prompt", $Prompt)
}

Assert-MidsceneEnvironment
Invoke-Step -Title "check hdc targets" -Command @("hdc", "list", "targets")

if ($CheckOnly) {
  if (-not $SkipInstall -and -not (Test-Path $HapPath)) {
    throw "HAP not found: $HapPath. Build entry@default before running this script."
  }
  Write-Host ""
  Write-Host "[FitTracker Midscene] Check-only passed. Run without -CheckOnly to execute visual regression."
  exit 0
}

if (-not $SkipInstall) {
  if (-not (Test-Path $HapPath)) {
    throw "HAP not found: $HapPath. Build entry@default before running this script."
  }
  Invoke-Hdc -Title "install app HAP" -Args @("install", "-r", $HapPath)
}

Invoke-Hdc -Title "launch app" -Args @("shell", "aa", "start", "-a", $AbilityName, "-b", $BundleName)
Invoke-Midscene -Title "connect device" -Args @("connect")
Invoke-Midscene -Title "capture startup screen" -Args @("take_screenshot")
Invoke-VisualAssert -Title "assert startup screen" -Prompt "The FitTracker app is visible. The screen is not blank and there is no crash dialog."

Invoke-Midscene -Title "run fixed training loop" -Args @(
  "act",
  "--prompt",
  "Complete this FitTracker regression path in order: startup, goal setup, home, workout preview, active workout, workout summary, review, and adjust goal. If the app starts on login or register, complete local registration or login first. If a goal setup screen appears, select muscle gain or strength, beginner level, three training days per week, bodyweight or dumbbell equipment, then save. From home open today's workout, confirm the workout preview, start training, enter one set with weight 60 and reps 10 if fields are available, finish the workout, continue to the summary, open review, then open adjust goal or regenerate plan."
)

Invoke-VisualAssert -Title "assert training loop result" -Prompt "The screen is still inside FitTracker and shows a review screen, goal adjustment screen, home screen, workout summary, or another completed training-flow result. There is no crash dialog and no blank screen."

Invoke-Hdc -Title "restart app for routing check" -Args @("shell", "aa", "start", "-a", $AbilityName, "-b", $BundleName)
Invoke-Midscene -Title "capture restart screen" -Args @("take_screenshot")
Invoke-VisualAssert -Title "assert restart routing" -Prompt "After restart, FitTracker shows home, goal setup, login, register, or another valid main-route screen. The screen is not blank and there is no crash dialog."

Invoke-Midscene -Title "run auth route smoke" -Args @(
  "act",
  "--prompt",
  "If visible registration or login controls are present, complete one local registration and login flow, then restart or return to confirm the app routes to home or goal setup. If no authentication entry is visible, confirm the current screen remains a valid FitTracker main flow screen."
)

Invoke-VisualAssert -Title "assert auth route smoke" -Prompt "FitTracker remains usable after the authentication-route smoke check. The screen shows home, goal setup, login success, workout entry, review, or another valid main-flow page, with no crash dialog."

if (-not $SkipDisconnect) {
  Invoke-Midscene -Title "disconnect device" -Args @("disconnect")
}

Write-Host ""
Write-Host "[FitTracker Midscene] Regression finished. Review generated reports under midscene_run/."
