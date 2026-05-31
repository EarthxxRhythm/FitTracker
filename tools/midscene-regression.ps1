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
Invoke-VisualAssert -Title "assert startup screen" -Prompt "The current screen is not blank and there is no crash dialog. It shows a fitness training app screen such as today's training entry, home, or a goal-related page."

Invoke-VisualAct -Title "prepare main route" -Prompt "Make FitTracker reach a valid main training route. If login or registration is shown, complete a local registration or login with test values. If goal setup is shown, select muscle gain or strength, beginner level, three training days per week, bodyweight or dumbbell equipment, then save. Stop when the home screen or a today's training entry is visible."
Invoke-VisualAssert -Title "assert home or goal route" -Prompt "FitTracker shows the home screen, goal setup completion result, or a visible today's training entry. The screen is not blank and there is no crash dialog."

Invoke-VisualAct -Title "open today's workout" -Prompt "From the current FitTracker screen, open today's workout or the primary training entry. Stop on the workout preview screen before starting the workout."
Invoke-VisualAssert -Title "assert workout preview" -Prompt "FitTracker shows a workout preview or training plan detail screen. There is no crash dialog and the screen is not blank."

Invoke-VisualAct -Title "start workout" -Prompt "On the FitTracker workout preview screen, tap the start training action. Stop when the active workout execution screen is visible."
Invoke-VisualAssert -Title "assert active workout" -Prompt "FitTracker shows an active workout execution screen, with exercise information or fields/actions for recording a set. There is no crash dialog."

Invoke-VisualAct -Title "record one set" -Prompt "On the active workout screen, enter one training set if fields are available. Use weight 60 and reps 10 if those fields are present. Stop after the set is saved and the active workout screen is still visible."
Invoke-VisualAssert -Title "assert set recorded" -Prompt "FitTracker remains on the active workout screen or shows the recorded set result. There is no crash dialog."

Invoke-VisualAct -Title "finish workout" -Prompt "From the active workout screen, tap the finish, complete, submit, or end workout action. Stop on the workout summary, review transition, or training completion screen."
Invoke-VisualAssert -Title "assert workout summary" -Prompt "FitTracker shows a workout summary, completion,复盘, or training result screen. There is no crash dialog."

Invoke-VisualAct -Title "open review" -Prompt "From the workout summary or current FitTracker screen, open the review or training history page. Stop when a review page or recent training record is visible."
Invoke-VisualAssert -Title "assert review screen" -Prompt "FitTracker shows a review, history, recent training, or progress screen. There is no crash dialog."

Invoke-VisualAct -Title "open adjust goal" -Prompt "From the current review or FitTracker main flow screen, open adjust goal, regenerate plan, or goal settings. Stop when the goal adjustment screen or goal setup screen is visible."
Invoke-VisualAssert -Title "assert goal adjustment" -Prompt "FitTracker shows a goal adjustment, goal setup, regenerate plan, home, or another valid completed training-flow result. There is no crash dialog and no blank screen."

Invoke-Hdc -Title "restart app for routing check" -CommandArgs @("shell", "aa", "start", "-a", $AbilityName, "-b", $BundleName)
Invoke-Midscene -Title "capture restart screen" -CommandArgs @("take_screenshot")
Invoke-VisualAssert -Title "assert restart routing" -Prompt "After restart, FitTracker shows home, goal setup, login, register, or another valid main-route screen. The screen is not blank and there is no crash dialog."

Invoke-Midscene -Title "run auth route smoke" -CommandArgs @(
  "act",
  "--prompt",
  "If visible registration or login controls are present, complete one local registration and login flow, then restart or return to confirm the app routes to home or goal setup. If no authentication entry is visible, confirm the current screen remains a valid FitTracker main flow screen."
)

Invoke-VisualAssert -Title "assert auth route smoke" -Prompt "FitTracker remains usable after the authentication-route smoke check. The screen shows home, goal setup, login success, workout entry, review, or another valid main-flow page, with no crash dialog."

if (-not $SkipDisconnect) {
  Invoke-Midscene -Title "disconnect device" -CommandArgs @("disconnect")
}

Write-Host ""
Write-Host "[FitTracker Midscene] Regression finished. Review generated reports under midscene_run/."
