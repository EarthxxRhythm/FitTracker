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
  Invoke-Hdc -Title "launch app" -CommandArgs @("shell", "aa", "start", "-a", $AbilityName, "-b", $BundleName)
  Start-Sleep -Seconds 2
  Invoke-Midscene -Title "connect device" -CommandArgs @("connect")
  Invoke-Midscene -Title "capture startup screen" -CommandArgs @("take_screenshot")
  Invoke-VisualAssert -Title "assert startup screen" -Prompt "The screen is not blank and there is no crash dialog."
}

function Ensure-HomeRoute {
  $homeReady = $false
  try {
    Invoke-VisualAssert -Title "assert home route already visible" -Prompt "The current screen is the FitTracker home page and a button labeled 查看训练回顾 is visible."
    $homeReady = $true
  } catch {
    $homeReady = $false
  }

  if ($homeReady) {
    return
  }

  Invoke-VisualAct -Title "prepare home route" -Prompt "Open the FitTracker app and reach the home page. If login or register appears, complete it. If goal setup appears, choose muscle gain, beginner, 3 days per week, and bodyweight or dumbbell equipment, then save. If the workout preview screen is visible, return to the home page. Stop when the home page with the 查看训练回顾 button is visible."
  Invoke-VisualAssert -Title "assert home route ready" -Prompt "The FitTracker home page is visible and a button labeled 查看训练回顾 is visible."
}

function Ensure-WorkoutPreviewRoute {
  $previewReady = $false
  try {
    Invoke-VisualAssert -Title "assert workout preview already visible" -Prompt "The workout preview screen is visible and at least one button labeled 查看动作详情 is present."
    $previewReady = $true
  } catch {
    $previewReady = $false
  }

  if ($previewReady) {
    return
  }

  Invoke-VisualAct -Title "prepare preview route" -Prompt "Reach the FitTracker workout preview screen for today's training. If login or register appears, complete it. If goal setup appears, choose muscle gain, beginner, 3 days per week, and bodyweight or dumbbell equipment, then save. If the home page is visible, tap the main primary training button that opens today's workout preview. Do not open 训练回顾 or 动作库. Stop when the workout preview screen is visible."
  Invoke-VisualAssert -Title "assert workout preview ready" -Prompt "The workout preview screen is visible."
}

function Run-BackupCardSmoke {
  Ensure-HomeRoute
  Invoke-VisualAct -Title "open review page" -Prompt "On the FitTracker home page, tap the button labeled 查看训练回顾. Stop when the 训练回顾 page is visible."
  Invoke-VisualAssert -Title "assert review page" -Prompt "The review page is visible, shows the title 训练回顾, and has no crash dialog."
  Invoke-VisualAct -Title "scroll to backup card" -Prompt "On the 训练回顾 page, scroll until the section titled 数据备份 is fully visible with the backup text area and action buttons."
  Invoke-VisualAssert -Title "assert backup card" -Prompt "The 数据备份 section is visible. It shows a text area with placeholder 导出或粘贴备份 JSON and buttons labeled 生成备份包 and 导入备份包."
}

function Run-MediaCardSmoke {
  Ensure-WorkoutPreviewRoute
  Invoke-VisualAct -Title "locate detail entry" -Prompt "On the workout preview screen, scroll until the first button labeled 查看动作详情 is fully visible. Stop there without tapping anything else."
  Invoke-VisualAssert -Title "assert detail entry visible" -Prompt "A button labeled 查看动作详情 is visible on the workout preview screen."
  Invoke-VisualActWithRetry `
    -Title "open exercise detail" `
    -PrimaryPrompt "Tap the first visible button labeled 查看动作详情 on the workout preview screen. Stop when the 动作详情 page is visible." `
    -PrimaryAssertTitle "assert exercise detail page" `
    -PrimaryAssertPrompt "The 动作详情 page is visible and there is no crash dialog." `
    -RetryPrompt "If the 动作详情 page is not visible yet, tap the first visible 查看动作详情 button again and stop when 动作详情 is visible." `
    -RetryAssertTitle "assert exercise detail page after retry" `
    -RetryAssertPrompt "The 动作详情 page is visible and there is no crash dialog."
  Invoke-VisualAct -Title "scroll to media card" -Prompt "On the 动作详情 page, scroll until the media section is visible. The section may include the title 动作演示, labels such as 封面 or 视频, and metadata rows like 封面路径 or 视频路径."
  Invoke-VisualAssert -Title "assert media card" -Prompt "The 动作详情 page shows the media card area. The section includes 动作演示 and at least one media status or metadata hint such as 已具备封面元数据, 已具备视频元数据, 封面路径, 视频路径, 媒体能力预留中, or 暂无可展示媒体."
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

  Ensure-AppReady

  if ($Target -eq 'backup-card') {
    Run-BackupCardSmoke
  } elseif ($Target -eq 'media-card') {
    Run-MediaCardSmoke
  } else {
    Run-BackupCardSmoke
    Invoke-Hdc -Title "relaunch app between focused targets" -CommandArgs @("shell", "aa", "start", "-a", $AbilityName, "-b", $BundleName)
    Start-Sleep -Seconds 2
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
