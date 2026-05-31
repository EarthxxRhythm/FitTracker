param(
  [string]$DeviceId = "",
  [string]$BundleName = "com.example.fittracker_opencode",
  [string]$AbilityName = "EntryAbility",
  [string]$HapPath = "entry/build/default/outputs/default/entry-default-unsigned.hap",
  [switch]$SkipInstall,
  [switch]$SkipDisconnect,
  [switch]$SkipVisualAsserts,
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
  $exe = $Command[0]
  $argsList = @($Command | Select-Object -Skip 1)
  & $exe @argsList
  if ($LASTEXITCODE -ne 0) {
    throw "Step failed: $Title"
  }
}

function Invoke-Hdc {
  param(
    [string]$Title,
    [string[]]$CommandArgs
  )

  $fullArgs = @()
  if ($DeviceId.Length -gt 0) {
    $fullArgs += @("-t", $DeviceId)
  }
  $fullArgs += $CommandArgs
  Invoke-Step -Title $Title -Command (@("hdc") + $fullArgs)
}

function Invoke-Midscene {
  param(
    [string]$Title,
    [string[]]$CommandArgs
  )

  $fullArgs = @("-y", "@midscene/harmony@1") + $CommandArgs
  if ($DeviceId.Length -gt 0) {
    $fullArgs += @("--device-id", $DeviceId)
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

  if ($SkipVisualAsserts) {
    Write-Host ""
    Write-Host "[FitTracker Midscene] skip visual assert: $Title"
    return
  }

  Invoke-Midscene -Title $Title -CommandArgs @("assert", "--prompt", $Prompt)
}

function Invoke-VisualAct {
  param(
    [string]$Title,
    [string]$Prompt
  )

  Invoke-Midscene -Title $Title -CommandArgs @("act", "--prompt", $Prompt)
}

Assert-MidsceneEnvironment
if (-not $env:MIDSCENE_REPLANNING_CYCLE_LIMIT) {
  $env:MIDSCENE_REPLANNING_CYCLE_LIMIT = "40"
}
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
  Invoke-Hdc -Title "install app HAP" -CommandArgs @("install", "-r", $HapPath)
}

Invoke-Hdc -Title "launch app" -CommandArgs @("shell", "aa", "start", "-a", $AbilityName, "-b", $BundleName)
Invoke-Midscene -Title "connect device" -CommandArgs @("connect")
Invoke-Midscene -Title "capture startup screen" -CommandArgs @("take_screenshot")
Invoke-VisualAssert -Title "assert startup screen" -Prompt "Screen is not blank and has no crash dialog."

Invoke-VisualAct -Title "prepare main route" -Prompt "Reach the today's training entry. If login/register appears, complete it. If goal setup appears, choose muscle gain, beginner, 3 days/week, bodyweight or dumbbell, then save."
Invoke-VisualAssert -Title "assert home or goal route" -Prompt "The screen shows home, goal setup, today's training entry, or workout preview."

Invoke-VisualAct -Title "open today's workout" -Prompt "Open today's workout and stop on the preview screen."
Invoke-VisualAssert -Title "assert workout preview" -Prompt "The workout preview screen is visible."

Invoke-VisualAct -Title "start workout" -Prompt "Tap start training and stop on the active workout screen."
Invoke-VisualAssert -Title "assert active workout" -Prompt "The active workout screen is visible."

Invoke-VisualAct -Title "record one set" -Prompt "Enter one set with weight 60 and reps 10, then stay on the active workout screen."
Invoke-VisualAssert -Title "assert set recorded" -Prompt "The set is recorded and no crash dialog is shown."

Invoke-VisualAct -Title "finish workout" -Prompt "Finish the workout and stop on the summary screen."
Invoke-VisualAssert -Title "assert workout summary" -Prompt "The workout summary screen is visible."

Invoke-VisualAct -Title "open review" -Prompt "Open the review or training history page."
Invoke-VisualAssert -Title "assert review screen" -Prompt "The review or history screen is visible."

Invoke-VisualAct -Title "open adjust goal" -Prompt "On the review screen, tap the button labeled 调整目标, 目标设置, or 重新生成计划. Stop on the goal setup screen."
Invoke-VisualAssert -Title "assert goal adjustment" -Prompt "The goal setup or goal adjustment screen is visible."

Invoke-Hdc -Title "restart app for routing check" -CommandArgs @("shell", "aa", "start", "-a", $AbilityName, "-b", $BundleName)
Invoke-Midscene -Title "capture restart screen" -CommandArgs @("take_screenshot")
Invoke-VisualAssert -Title "assert restart routing" -Prompt "After restart, the screen shows a valid FitTracker main page."

Invoke-Midscene -Title "run auth route smoke" -CommandArgs @(
  "act",
  "--prompt",
  "If login/register is visible, complete it and confirm the app returns to a main page. If not, confirm the current screen is a valid FitTracker page."
)

Invoke-VisualAssert -Title "assert auth route smoke" -Prompt "The screen remains a valid FitTracker page with no crash dialog."

if (-not $SkipDisconnect) {
  Invoke-Midscene -Title "disconnect device" -CommandArgs @("disconnect")
}

Write-Host ""
Write-Host "[FitTracker Midscene] Regression finished. Review generated reports under midscene_run/."
