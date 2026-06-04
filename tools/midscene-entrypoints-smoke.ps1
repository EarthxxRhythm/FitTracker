param(
  [ValidateSet('backup-card', 'media-card', 'current-plan', 'both')]
  [string]$Target = 'current-plan',
  [string]$DeviceId = "",
  [string]$BundleName = "com.example.fittracker_opencode",
  [string]$AbilityName = "EntryAbility",
  [string]$HapPath = "entry/build/default/outputs/default/entry-default-unsigned.hap",
  [string]$RunRoot = "",
  [string]$RunTag = "",
  [string]$SummaryFileName = "midscene-entrypoints-smoke-summary.md",
  [switch]$ResetAppData,
  [switch]$SkipInstall,
  [switch]$SkipDisconnect,
  [switch]$SkipVisualAsserts,
  [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"
$ScriptRoot = $PSScriptRoot
$DefaultRunBase = Join-Path $ScriptRoot "..\midscene_run\focused"
$TargetToken = $Target.Replace('-', '_')
if ([string]::IsNullOrWhiteSpace($RunTag)) {
  $RunTag = (Get-Date -Format "yyyyMMdd-HHmmss") + "-p" + $PID.ToString()
}
if ([string]::IsNullOrWhiteSpace($RunRoot)) {
  $RunRoot = Join-Path $DefaultRunBase ($TargetToken + "-" + $RunTag)
}
$RunRoot = [System.IO.Path]::GetFullPath($RunRoot)
$RunSummaryPath = Join-Path $RunRoot $SummaryFileName
$env:MIDSCENE_RUN_DIR = $RunRoot

function Get-LatestMidsceneReportHtmlPath {
  if (-not (Test-Path $RunRoot)) {
    return ""
  }

  $reportDir = Join-Path $RunRoot "report"
  if (-not (Test-Path $reportDir)) {
    return ""
  }

  $latestReport = Get-ChildItem -Path $reportDir -Filter "*.html" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($null -eq $latestReport) {
    return ""
  }

  return $latestReport.FullName
}

function Write-SmokeSummary {
  param(
    [string]$Status,
    [string]$FailureReason
  )

  New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null
  $summaryLines = @()
  $summaryLines += "# FitTracker Midscene focused smoke"
  $summaryLines += ""
  $summaryLines += "- date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
  $summaryLines += "- status: $Status"
  $summaryLines += "- target: $Target"
  $summaryLines += "- device id: $DeviceId"
  $summaryLines += "- bundle: $BundleName"
  $summaryLines += "- ability: $AbilityName"
  $summaryLines += "- hap path: $HapPath"
  $summaryLines += "- run root: $RunRoot"
  $summaryLines += "- report dir: $RunRoot\report"
  $summaryLines += "- log dir: $RunRoot\log"
  $summaryLines += "- reset app data: $ResetAppData"
  $summaryLines += "- latest html: $(Get-LatestMidsceneReportHtmlPath)"
  $summaryLines += "- MIDSCENE_MODEL_BASE_URL: $($env:MIDSCENE_MODEL_BASE_URL)"
  $summaryLines += "- MIDSCENE_MODEL_NAME: $($env:MIDSCENE_MODEL_NAME)"
  $summaryLines += "- MIDSCENE_MODEL_FAMILY: $($env:MIDSCENE_MODEL_FAMILY)"
  $summaryLines += ""
  $summaryLines += "## focused coverage"
  if ($Target -eq 'backup-card') {
    $summaryLines += "- review page backup card"
  } elseif ($Target -eq 'media-card') {
    $summaryLines += "- exercise detail media card"
  } elseif ($Target -eq 'current-plan') {
    $summaryLines += "- home current-plan card to workout preview"
    $summaryLines += "- workout preview to active workout"
  } else {
    $summaryLines += "- review page backup card"
    $summaryLines += "- exercise detail media card"
  }
  $summaryLines += ""
  $summaryLines += "## failure notes"
  if ($FailureReason.Length -gt 0) {
    $summaryLines += "- failure reason: $FailureReason"
  } else {
    $summaryLines += "- none"
  }

  Set-Content -Path $RunSummaryPath -Value $summaryLines -Encoding utf8
}

function Invoke-Step {
  param(
    [string]$Title,
    [string[]]$Command
  )

  Write-Host ""
  Write-Host ('[FitTracker Focused Smoke] ' + $Title)
  $exe = $Command[0]
  $argsList = @($Command | Select-Object -Skip 1)
  & $exe @argsList
  if ($LASTEXITCODE -ne 0) {
    throw ('Step failed: ' + $Title)
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

  $env:MIDSCENE_RUN_DIR = $RunRoot
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
    throw 'Missing Midscene model environment variables. Set MIDSCENE_MODEL_API_KEY, MIDSCENE_MODEL_NAME, MIDSCENE_MODEL_BASE_URL and MIDSCENE_MODEL_FAMILY, or create a local .env file.'
  }
}

function Reset-AppDataIfRequested {
  if (-not $ResetAppData) {
    return
  }

  Invoke-Hdc -Title "clean app data" -CommandArgs @("shell", "bm", "clean", "-n", $BundleName, "-d", "-c", "-u", "0")
  Start-Sleep -Seconds 1
}

function Launch-AppToForeground {
  param(
    [string]$Title = "launch app",
    [int]$PauseSeconds = 2
  )

  Invoke-Hdc -Title $Title -CommandArgs @("shell", "aa", "start", "-a", $AbilityName, "-b", $BundleName)
  Start-Sleep -Seconds $PauseSeconds
}

function Invoke-VisualAssert {
  param(
    [string]$Title,
    [string]$Prompt
  )

  if ($SkipVisualAsserts) {
    Write-Host ""
    Write-Host ('[FitTracker Focused Smoke] skip visual assert: ' + $Title)
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

function Invoke-VisualActWithRetry {
  param(
    [string]$Title,
    [string]$PrimaryPrompt,
    [string]$PrimaryAssertTitle,
    [string]$PrimaryAssertPrompt,
    [string]$RetryPrompt,
    [string]$RetryAssertTitle,
    [string]$RetryAssertPrompt,
    [int]$RetryPauseSeconds = 2
  )

  Invoke-VisualAct -Title $Title -Prompt $PrimaryPrompt
  try {
    Invoke-VisualAssert -Title $PrimaryAssertTitle -Prompt $PrimaryAssertPrompt
    return
  } catch {
    if ($RetryPrompt.Length -eq 0) {
      throw
    }
    Start-Sleep -Seconds $RetryPauseSeconds
    Invoke-Midscene -Title ($Title + " retry screenshot") -CommandArgs @("take_screenshot")
    Invoke-VisualAct -Title ($Title + " retry") -Prompt $RetryPrompt
    Invoke-VisualAssert -Title $RetryAssertTitle -Prompt $RetryAssertPrompt
  }
}

function Ensure-AppReady {
  Launch-AppToForeground -Title "launch app" -PauseSeconds 2
  Invoke-Midscene -Title "connect device" -CommandArgs @("connect")
  Invoke-Midscene -Title "capture startup screen" -CommandArgs @("take_screenshot")
  Invoke-VisualAssert -Title "assert startup screen" -Prompt "The screen is not blank and there is no crash dialog."
}

function Ensure-HomeRoute {
  $homeReady = $false
  try {
    Invoke-VisualAssert -Title "assert home route already visible" -Prompt "The FitTracker home page is visible. It shows the main workout entry with a primary workout button, and there is no crash dialog."
    $homeReady = $true
  } catch {
    $homeReady = $false
  }

  if ($homeReady) {
    return
  }

  Launch-AppToForeground -Title "restore app before home route" -PauseSeconds 2
  Invoke-Midscene -Title "capture pre-home-route screen" -CommandArgs @("take_screenshot")
  Invoke-VisualActWithRetry `
    -Title "prepare home route" `
    -PrimaryPrompt "From the current visible screen, reach the FitTracker home page. If the FitTracker app is already open, stay in it and continue. If the system home screen is visible, return to the currently installed FitTracker app. If login or register appears, complete it. If goal setup appears, choose muscle gain, beginner, 3 days per week, and bodyweight or dumbbell equipment, then save. If workout preview, review, or exercise detail is visible, navigate back to the home page. Stop when the home page shows the main workout entry with a primary workout button." `
    -PrimaryAssertTitle "assert home route ready" `
    -PrimaryAssertPrompt "The FitTracker home page is visible. It shows the main workout entry with a primary workout button, and there is no crash dialog." `
    -RetryPrompt "If the FitTracker home page is still not visible, bring the FitTracker app to the foreground if needed, then navigate back until the home page shows the main workout entry with a primary workout button. If login or goal setup still appears, complete the minimum required flow and stop on the home page." `
    -RetryAssertTitle "assert home route ready after retry" `
    -RetryAssertPrompt "The FitTracker home page is visible. It shows the main workout entry with a primary workout button, and there is no crash dialog."
}

function Ensure-WorkoutPreviewRoute {
  $previewReady = $false
  try {
    Invoke-VisualAssert -Title "assert workout preview already visible" -Prompt "The workout preview screen for today's training is visible."
    $previewReady = $true
  } catch {
    $previewReady = $false
  }

  if ($previewReady) {
    return
  }

  Launch-AppToForeground -Title "restore app before preview route" -PauseSeconds 2
  Invoke-Midscene -Title "capture pre-preview-route screen" -CommandArgs @("take_screenshot")
  Invoke-VisualActWithRetry `
    -Title "prepare preview route" `
    -PrimaryPrompt "From the current visible screen, reach the FitTracker workout preview screen for today's training. If the FitTracker app is already open, stay in it. If the system home screen is visible, return to the currently installed FitTracker app. If login or register appears, complete it. If goal setup appears, choose muscle gain, beginner, 3 days per week, and bodyweight or dumbbell equipment, then save. If the home page is visible, tap the main primary training button that opens today's workout preview. Do not open the training review or exercise library routes. Stop when the workout preview screen is visible." `
    -PrimaryAssertTitle "assert workout preview ready" `
    -PrimaryAssertPrompt "The workout preview screen for today's training is visible." `
    -RetryPrompt "If the workout preview screen is still not visible, bring the FitTracker app to the foreground if needed, then navigate to today's workout preview from the home page. Complete login or goal setup only if they block the route. Stop when the workout preview screen is visible." `
    -RetryAssertTitle "assert workout preview ready after retry" `
    -RetryAssertPrompt "The workout preview screen for today's training is visible."
}

function Ensure-CurrentPlanHomeRoute {
  Ensure-HomeRoute
  Invoke-VisualAssert -Title "assert current plan home card" -Prompt "The FitTracker home page is visible. It shows the current enabled preset plan or today's training entry with a primary start workout button, and there is no crash dialog or blank screen."
}

function Ensure-CurrentPlanPreviewRoute {
  $previewReady = $false
  try {
    Invoke-VisualAssert -Title "assert current plan preview already visible" -Prompt "The FitTracker workout preview screen is visible. It shows the workout preview title, a plan name, and a user-friendly day badge such as 第 5 天. There is no crash dialog."
    $previewReady = $true
  } catch {
    $previewReady = $false
  }

  if ($previewReady) {
    return
  }

  Ensure-CurrentPlanHomeRoute
  Invoke-VisualActWithRetry `
    -Title "open current plan preview" `
    -PrimaryPrompt "On the FitTracker home page, tap the main primary workout button for today's training and stop when the workout preview screen is visible. Do not open the training review or exercise library pages." `
    -PrimaryAssertTitle "assert current plan preview ready" `
    -PrimaryAssertPrompt "The FitTracker workout preview screen is visible. It shows the workout preview title, a plan name, and a user-friendly day badge such as 第 5 天. There is no crash dialog." `
    -RetryPrompt "If the workout preview screen is still not visible, return to the FitTracker home page if needed, then tap the main primary workout button again and stop on the workout preview screen." `
    -RetryAssertTitle "assert current plan preview ready after retry" `
    -RetryAssertPrompt "The FitTracker workout preview screen is visible. It shows the workout preview title, a plan name, and a user-friendly day badge such as 第 5 天. There is no crash dialog."
}

function Ensure-ExerciseLibraryRoute {
  Ensure-HomeRoute
  Invoke-VisualActWithRetry `
    -Title "open exercise library" `
    -PrimaryPrompt "On the FitTracker home page, tap the secondary action button that opens the exercise library. Stop when the exercise library page is visible." `
    -PrimaryAssertTitle "assert exercise library page" `
    -PrimaryAssertPrompt "The exercise library page is visible. It shows an exercise list, search input, and filter chips for muscle groups or equipment, and there is no crash dialog." `
    -RetryPrompt "If the exercise library page is not visible yet, return to the FitTracker home page if needed, then tap the secondary action button that opens the exercise library and stop on that page." `
    -RetryAssertTitle "assert exercise library page after retry" `
    -RetryAssertPrompt "The exercise library page is visible. It shows an exercise list, search input, and filter chips for muscle groups or equipment, and there is no crash dialog."
}

function Run-BackupCardSmoke {
  Ensure-HomeRoute
  Invoke-VisualAct -Title "open review page" -Prompt "On the FitTracker home page, tap the secondary action button that opens the training review page. Stop when the training review page is visible."
  Invoke-VisualAssert -Title "assert review page" -Prompt "The training review page is visible. It shows review content such as history, trends, or records, and there is no crash dialog."
  Invoke-VisualAct -Title "scroll to backup card" -Prompt "On the training review page, scroll until the data backup section is fully visible with the backup text area and action buttons."
  Invoke-VisualAssert -Title "assert backup card" -Prompt "The data backup section is visible. It includes a text area for backup JSON and visible action buttons for creating and importing a backup package, and there is no crash dialog."
}

function Run-MediaCardSmoke {
  Ensure-ExerciseLibraryRoute
  Invoke-VisualActWithRetry `
    -Title "open exercise detail" `
    -PrimaryPrompt "On the exercise library page, open the first visible exercise detail entry. Prefer tapping the large full-width button inside the first exercise card that opens exercise details. If that button is not fully visible, scroll slightly until the first card is complete, then open its detail page. Stop when the exercise detail page is visible." `
    -PrimaryAssertTitle "assert exercise detail page" `
    -PrimaryAssertPrompt "The exercise detail page is visible and there is no crash dialog." `
    -RetryPrompt "If the exercise detail page is not visible yet, return to the exercise library page if needed, make sure the first visible exercise card is fully on screen, tap its detail button again, and stop when the exercise detail page is visible." `
    -RetryAssertTitle "assert exercise detail page after retry" `
    -RetryAssertPrompt "The exercise detail page is visible and there is no crash dialog."
  Invoke-VisualAct -Title "scroll to media card" -Prompt "On the exercise detail page, scroll until the media section is visible. The section may include a media title, cover or video areas, and media metadata rows."
  Invoke-VisualAssert -Title "assert media card" -Prompt "The exercise detail page shows the media section for the exercise, including a media status header plus cover or video metadata rows such as source note, license note, cover metadata, or video metadata."
}

function Run-CurrentPlanSmoke {
  Ensure-CurrentPlanHomeRoute
  Invoke-VisualActWithRetry `
    -Title "home to current plan preview" `
    -PrimaryPrompt "On the FitTracker home page, tap the main primary workout button for today's training and stop on the workout preview screen." `
    -PrimaryAssertTitle "assert current plan preview after home tap" `
    -PrimaryAssertPrompt "The FitTracker workout preview screen is visible. It shows the workout preview title, a plan name, and a user-friendly day badge such as 第 5 天. There is no crash dialog." `
    -RetryPrompt "If the workout preview screen is still not visible, return to the FitTracker home page if needed, then tap the main primary workout button again and stop on the workout preview screen." `
    -RetryAssertTitle "assert current plan preview after retry" `
    -RetryAssertPrompt "The FitTracker workout preview screen is visible. It shows the workout preview title, a plan name, and a user-friendly day badge such as 第 5 天. There is no crash dialog."

  Invoke-VisualActWithRetry `
    -Title "current plan preview to active workout" `
    -PrimaryPrompt "On the workout preview screen, scroll if needed until the 开始训练 button is visible, then tap only that button and stop when the active workout execution screen is visible." `
    -PrimaryAssertTitle "assert active workout from current plan preview" `
    -PrimaryAssertPrompt "The active workout execution screen is visible. It shows the title 训练执行, the current exercise area, and input fields or rows for set weight and reps. There is no crash dialog." `
    -RetryPrompt "If the active workout screen is still not visible, stay on the workout preview screen, scroll until the 开始训练 button is visible, tap only that button again, and stop when the active workout execution screen is visible." `
    -RetryAssertTitle "assert active workout from current plan preview after retry" `
    -RetryAssertPrompt "The active workout execution screen is visible. It shows the title 训练执行, the current exercise area, and input fields or rows for set weight and reps. There is no crash dialog."
}

if (-not $env:MIDSCENE_REPLANNING_CYCLE_LIMIT) {
  $env:MIDSCENE_REPLANNING_CYCLE_LIMIT = "60"
}

$runStatus = "failed"
$failureReason = ""

try {
  Invoke-Step -Title "check hdc targets" -Command @("hdc", "list", "targets")

  if ($CheckOnly) {
    if (-not $SkipInstall -and -not (Test-Path $HapPath)) {
      throw ('HAP not found: ' + $HapPath + '. Build entry@default before running this script.')
    }
    Write-Host ""
    Write-Host ('[FitTracker Focused Smoke] Check-only passed for target ' + $Target + '. Run without -CheckOnly to execute the smoke flow.')
    $runStatus = "check-only"
    return
  }

  Assert-MidsceneEnvironment

  if (-not $SkipInstall) {
    if (-not (Test-Path $HapPath)) {
      throw ('HAP not found: ' + $HapPath + '. Build entry@default before running this script.')
    }
    Invoke-Hdc -Title "install app HAP" -CommandArgs @("install", "-r", $HapPath)
  }

  Reset-AppDataIfRequested

  Ensure-AppReady

  if ($Target -eq 'backup-card') {
    Run-BackupCardSmoke
  } elseif ($Target -eq 'media-card') {
    Run-MediaCardSmoke
  } elseif ($Target -eq 'current-plan') {
    Run-CurrentPlanSmoke
  } else {
    Run-BackupCardSmoke
    Launch-AppToForeground -Title "relaunch app between focused targets" -PauseSeconds 2
    Invoke-Midscene -Title "capture relaunch screen" -CommandArgs @("take_screenshot")
    Run-MediaCardSmoke
  }

  $runStatus = "passed"
}
catch {
  $failureReason = $_.Exception.Message
  throw
}
finally {
  Write-SmokeSummary -Status $runStatus -FailureReason $failureReason
  if (-not $SkipDisconnect) {
    try {
      Invoke-Midscene -Title "disconnect device" -CommandArgs @("disconnect")
    } catch {
      Write-Host ('[FitTracker Focused Smoke] disconnect skipped: ' + $_.Exception.Message)
    }
  }
  Write-Host ""
  Write-Host ('[FitTracker Focused Smoke] Summary written to ' + $RunSummaryPath)
}
