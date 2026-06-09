param(
  [string]$DeviceId = "",
  [string]$BundleName = "com.example.fittracker_opencode",
  [string]$AbilityName = "EntryAbility",
  [string]$HapPath = "entry/build/default/outputs/default/entry-default-unsigned.hap",
  [string]$RunRoot = "",
  [string]$RunTag = "",
  [string]$SummaryFileName = "midscene-regression-summary.md",
  [switch]$SkipInstall,
  [switch]$SkipDisconnect,
  [switch]$SkipVisualAsserts,
  [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"
$ScriptRoot = $PSScriptRoot
$HdcTargetsScriptPath = Join-Path $ScriptRoot "hdc-targets.ps1"
$DefaultRunBase = Join-Path $ScriptRoot "..\midscene_run\full"
if ([string]::IsNullOrWhiteSpace($RunTag)) {
  $RunTag = (Get-Date -Format "yyyyMMdd-HHmmss") + "-p" + $PID.ToString()
}
if ([string]::IsNullOrWhiteSpace($RunRoot)) {
  $RunRoot = Join-Path $DefaultRunBase $RunTag
}
$RunRoot = [System.IO.Path]::GetFullPath($RunRoot)
$RunSummaryPath = Join-Path $RunRoot $SummaryFileName
$env:MIDSCENE_RUN_DIR = $RunRoot

if (-not (Test-Path $HdcTargetsScriptPath)) {
  throw ('Required script not found: ' + $HdcTargetsScriptPath)
}
. $HdcTargetsScriptPath

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

function Write-RegressionSummary {
  param(
    [string]$Status,
    [string]$FailureReason
  )

  New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null
  $summaryLines = @()
  $summaryLines += "# FitTracker Midscene 回归摘要"
  $summaryLines += ""
  $summaryLines += "- 日期：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
  $summaryLines += "- 状态：$Status"
  $summaryLines += "- 设备 ID：$DeviceId"
  $summaryLines += "- 包名：$BundleName"
  $summaryLines += "- Ability：$AbilityName"
  $summaryLines += "- HAP 路径：$HapPath"
  $summaryLines += "- 运行目录：$RunRoot"
  $summaryLines += "- Midscene 报告目录：$RunRoot\report"
  $summaryLines += "- Midscene 日志目录：$RunRoot\log"
  $summaryLines += "- 最近报告 HTML：$(Get-LatestMidsceneReportHtmlPath)"
  $summaryLines += "- MIDSCENE_MODEL_BASE_URL：$($env:MIDSCENE_MODEL_BASE_URL)"
  $summaryLines += "- MIDSCENE_MODEL_NAME：$($env:MIDSCENE_MODEL_NAME)"
  $summaryLines += "- MIDSCENE_MODEL_FAMILY：$($env:MIDSCENE_MODEL_FAMILY)"
  $summaryLines += ""
  $summaryLines += "## 失败排查"
  if ($FailureReason.Length -gt 0) {
    $summaryLines += "- 失败原因：$FailureReason"
  } else {
    $summaryLines += "- 无"
  }
  $summaryLines += '- 查看 `docs/模拟器视觉回归说明.md` 的失败排查表。'
  $summaryLines += '- 如需复盘节点详情，打开当前运行目录下 `report/` 的最新 HTML 报告。'

  Set-Content -Path $RunSummaryPath -Value $summaryLines -Encoding utf8
}

function Invoke-Step {
  param(
    [string]$Title,
    [string[]]$Command
  )

  Write-Host ""
  Write-Host ('[FitTracker Midscene] ' + $Title)
  $exe = $Command[0]
  $argsList = @($Command | Select-Object -Skip 1)
  $rawOutput = & $exe @argsList 2>&1
  $outputText = (@($rawOutput) | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
  if ($outputText.Length -gt 0) {
    Write-Host $outputText
  }
  if ($LASTEXITCODE -ne 0) {
    throw ('Step failed: ' + $Title)
  }
  return @{
    Output = $outputText
    ExitCode = $LASTEXITCODE
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
    Write-Host ('[FitTracker Midscene] skip visual assert: ' + $Title)
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

if (-not $env:MIDSCENE_REPLANNING_CYCLE_LIMIT) {
  $env:MIDSCENE_REPLANNING_CYCLE_LIMIT = "60"
}
 $runStatus = "failed"
 $failureReason = ""

 try {
  $targetsResult = Invoke-Step -Title "check hdc targets" -Command @("hdc", "list", "targets", "-v")
  Assert-HdcTargetsReady -RawOutput $targetsResult.Output -DeviceId $DeviceId

  if ($CheckOnly) {
    if (-not $SkipInstall -and -not (Test-Path $HapPath)) {
      throw ('HAP not found: ' + $HapPath + '. Build entry@default before running this script.')
    }
    Write-Host ""
    Write-Host '[FitTracker Midscene] Check-only passed. Run without -CheckOnly to execute visual regression.'
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

  Invoke-Hdc -Title "launch app" -CommandArgs @("shell", "aa", "start", "-a", $AbilityName, "-b", $BundleName)
  Start-Sleep -Seconds 2
  Invoke-Midscene -Title "connect device" -CommandArgs @("connect")
  Invoke-Midscene -Title "capture startup screen" -CommandArgs @("take_screenshot")
  Invoke-VisualAssert -Title "assert startup screen" -Prompt "Screen is not blank and has no crash dialog."

  $previewReady = $false
  try {
    Invoke-VisualAssert -Title "assert preview route already visible" -Prompt "The screen already shows the today's training preview with the Day 1 card and the 开始训练 button."
    $previewReady = $true
  } catch {
    $previewReady = $false
  }

  if (-not $previewReady) {
    Invoke-VisualAct -Title "prepare main route" -Prompt "Open the FitTracker app from the home screen or recent apps, then reach the today's training entry. If login/register appears, complete it. If goal setup appears, choose muscle gain, beginner, 3 days/week, bodyweight or dumbbell equipment, then save. If the today's training preview is already visible, stop immediately. Do not open the app drawer or restart the device."
    Invoke-VisualAssert -Title "assert home or goal route" -Prompt "The screen shows home, goal setup, today's training entry, or workout preview."
    Invoke-VisualAct -Title "open today's workout" -Prompt "From the current FitTracker screen, open today's workout or the primary training entry. Stop on the workout preview screen before starting the workout."
    Invoke-VisualAssert -Title "assert workout preview" -Prompt "The workout preview screen is visible."
  }

  Invoke-VisualAct -Title "locate start button" -Prompt "On the workout preview screen, scroll until the large blue button labeled 开始训练 is fully visible in the lower half of the page with a little empty space below it. Stop there without tapping anything."
  Invoke-VisualAssert -Title "assert start button visible" -Prompt "The large blue 开始训练 button is visible on the workout preview screen."
  Start-Sleep -Seconds 3

  Invoke-VisualActWithRetry `
    -Title "tap start button" `
    -PrimaryPrompt "Tap only the large blue button labeled 开始训练 at the bottom of the workout preview screen. Do not tap 查看动作详情 or any exercise card. Stop when the active workout execution screen is visible." `
    -PrimaryAssertTitle "assert active workout" `
    -PrimaryAssertPrompt "The screen shows 训练执行 with a timer, the current exercise, and weight and reps input fields. It is not the training review or summary page." `
    -RetryPrompt "Tap only the large blue button labeled 开始训练 at the bottom of the workout preview screen again. If the screen is already transitioning, wait on this screen and do not tap any other element. Stop when the active workout execution screen is visible." `
    -RetryAssertTitle "assert active workout after retry" `
    -RetryAssertPrompt "The screen shows 训练执行 with a timer, the current exercise, and weight and reps input fields. It is not the training review or summary page."

  Invoke-VisualAct -Title "enter first set weight and reps" -Prompt "On the active workout screen for 哑铃卧推, tap the empty field with placeholder 重量kg in the 第 1 组 row and type 60. Then tap the empty field with placeholder 次数 in the same row and type 10. Stop immediately after the 10 is visible in the 次数 field. Do not wait for additional 1RM updates and do not finish the workout."
  try {
    Invoke-VisualAssert -Title "assert set recorded" -Prompt "The first set of the first exercise shows weight 60 and reps 10, and the 1RM reference updates on the training execution page with no crash dialog."
  } catch {
    Start-Sleep -Seconds 2
    Invoke-Midscene -Title "first set retry screenshot" -CommandArgs @("take_screenshot")
    Invoke-VisualAct -Title "enter first set weight" -Prompt "On the active workout screen for 哑铃卧推, tap the empty field with placeholder 重量kg in the 第 1 组 row and type 60. Stop immediately when 60 is visible in that field. Do not tap the rep field yet."
    Invoke-VisualAssert -Title "assert first set weight entered" -Prompt "The first set row for 哑铃卧推 shows 60 in the 重量kg field and the screen is still the active workout page."
    Invoke-VisualAct -Title "enter first set reps" -Prompt "On the same 第 1 组 row, tap the empty field with placeholder 次数 and type 10. Stop immediately when 10 is visible in that field. Do not finish the workout."
    Invoke-VisualAssert -Title "assert set recorded after retry" -Prompt "The first set of the first exercise shows weight 60 and reps 10, and the 1RM reference updates on the training execution page with no crash dialog."
  }

  Invoke-VisualActWithRetry `
    -Title "finish workout" `
    -PrimaryPrompt "Tap only the button labeled 保存当前进度 on the active workout screen. Do not tap 完成全部并保存 unless 保存当前进度 is not visible. Stop when the workout summary screen is visible." `
    -PrimaryAssertTitle "assert workout summary" `
    -PrimaryAssertPrompt "The workout summary screen is visible." `
    -RetryPrompt "Tap only the button labeled 完成全部并保存 on the active workout screen. Stop when the workout summary screen is visible." `
    -RetryAssertTitle "assert workout summary after retry" `
    -RetryAssertPrompt "The workout summary screen is visible."

  Invoke-VisualAct -Title "open review" -Prompt "Tap the button labeled 查看训练回顾 on the workout summary screen."
  Invoke-VisualAssert -Title "assert review screen" -Prompt "The review dashboard screen with the title 训练回顾 is visible."

  Invoke-VisualAct -Title "open adjust goal" -Prompt "On the review screen, tap the button labeled 调整下次计划. Stop on the goal setup screen."
  Invoke-VisualAssert -Title "assert goal adjustment" -Prompt "The goal setup screen is visible."

  Invoke-Hdc -Title "restart app for routing check" -CommandArgs @("shell", "aa", "start", "-a", $AbilityName, "-b", $BundleName)
  Invoke-Midscene -Title "capture restart screen" -CommandArgs @("take_screenshot")
  Invoke-VisualAssert -Title "assert restart routing" -Prompt "After restart, the screen shows a valid FitTracker page such as home, goal setup, login, or register, and there is no crash dialog."

  Invoke-Midscene -Title "run auth route smoke" -CommandArgs @(
    "act",
    "--prompt",
    "If login/register is visible, complete it and confirm the app returns to a main page. If not, confirm the current screen is a valid FitTracker page."
  )

  Invoke-VisualAssert -Title "assert auth route smoke" -Prompt "The screen remains a valid FitTracker page with no crash dialog."
  $runStatus = "passed"
 }
 catch {
  $failureReason = $_.Exception.Message
  throw
 }
 finally {
  Write-RegressionSummary -Status $runStatus -FailureReason $failureReason
  if (-not $SkipDisconnect) {
    try {
      Invoke-Midscene -Title "disconnect device" -CommandArgs @("disconnect")
    } catch {
      Write-Host ('[FitTracker Midscene] disconnect skipped: ' + $_.Exception.Message)
    }
  }
  Write-Host ""
  Write-Host ('[FitTracker Midscene] Regression summary written to ' + $RunSummaryPath)
 }
