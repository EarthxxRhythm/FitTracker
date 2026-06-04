param(
  [ValidateSet('backup-card', 'media-card', 'both')]
  [string]$Target = 'both',
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
    Invoke-VisualAssert -Title "assert home route already visible" -Prompt "The FitTracker home page is visible. It shows a primary workout button labeled 开始训练, plus separate buttons for training review and exercise library, and there is no crash dialog."
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
    -PrimaryPrompt "From the current visible screen, reach the FitTracker home page. If the FitTracker app is already open, stay in it and continue. If the system home screen is visible, return to the currently installed FitTracker app. If login or register appears, complete it. If goal setup appears, choose muscle gain, beginner, 3 days per week, and bodyweight or dumbbell equipment, then save. If workout preview, review, or exercise detail is visible, navigate back to the home page. Stop when the FitTracker home page shows the main workout button plus the training review and exercise library buttons." `
    -PrimaryAssertTitle "assert home route ready" `
    -PrimaryAssertPrompt "The FitTracker home page is visible. It shows a primary workout button labeled 开始训练, plus separate buttons for training review and exercise library, and there is no crash dialog." `
    -RetryPrompt "If the FitTracker home page is still not visible, bring the FitTracker app to the foreground if needed, then navigate back until the home page shows the main workout button plus the training review and exercise library buttons. If login or goal setup still appears, complete the minimum required flow and stop on the home page." `
    -RetryAssertTitle "assert home route ready after retry" `
    -RetryAssertPrompt "The FitTracker home page is visible. It shows a primary workout button labeled 开始训练, plus separate buttons for training review and exercise library, and there is no crash dialog."
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

function Run-BackupCardSmoke {
  Ensure-HomeRoute
  Invoke-VisualAct -Title "open review page" -Prompt "On the FitTracker home page, tap the secondary action button that opens the training review page. Stop when the training review page is visible."
  Invoke-VisualAssert -Title "assert review page" -Prompt "The training review page is visible. It shows review content such as history, trends, or records, and there is no crash dialog."
  Invoke-VisualAct -Title "scroll to backup card" -Prompt "On the training review page, scroll until the data backup section is fully visible with the backup text area and action buttons."
  Invoke-VisualAssert -Title "assert backup card" -Prompt "The 数据备份 section is visible. It shows a text area for backup JSON and buttons labeled 生成备份包 and 导入备份包."
}

function Run-MediaCardSmoke {
  Ensure-WorkoutPreviewRoute
  Invoke-VisualAct -Title "locate detail entry" -Prompt "On the workout preview screen, scroll until the first exercise detail button is fully visible. Stop there without tapping anything else."
  Invoke-VisualActWithRetry `
    -Title "open exercise detail" `
    -PrimaryPrompt "On the workout preview screen, tap the first visible exercise detail button. If the button is not fully visible yet, scroll slightly until it is visible, then tap it. Stop when the exercise detail page is visible." `
    -PrimaryAssertTitle "assert exercise detail page" `
    -PrimaryAssertPrompt "The exercise detail page is visible and there is no crash dialog." `
    -RetryPrompt "If the exercise detail page is not visible yet, return to the workout preview list if needed, make sure the first exercise detail button is visible, tap it again, and stop when the exercise detail page is visible." `
    -RetryAssertTitle "assert exercise detail page after retry" `
    -RetryAssertPrompt "The exercise detail page is visible and there is no crash dialog."
  Invoke-VisualAct -Title "scroll to media card" -Prompt "On the exercise detail page, scroll until the media section is visible. The section may include a media title, cover or video areas, and media metadata rows."
  Invoke-VisualAssert -Title "assert media card" -Prompt "The exercise detail page shows the media card area, including exercise media or media metadata such as cover metadata, video metadata, or media reference information."
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
