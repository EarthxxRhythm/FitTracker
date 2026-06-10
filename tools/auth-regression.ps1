param(
  [string]$DeviceId = "",
  [string]$BundleName = "com.example.fittracker_opencode",
  [string]$AbilityName = "EntryAbility",
  [string]$HapPath = "entry/build/default/outputs/default/entry-default-unsigned.hap",
  [string]$TestPhone = "13800138000",
  [string]$TestPassword = "FitTracker123",
  [string]$RunRoot = "",
  [string]$RunTag = "",
  [string]$SummaryFileName = "midscene-auth-regression-summary.md",
  [switch]$SkipInstall,
  [switch]$SkipDisconnect,
  [switch]$SkipVisualAsserts,
  [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"
$ScriptRoot = $PSScriptRoot
$HdcTargetsScriptPath = Join-Path $ScriptRoot "hdc-targets.ps1"
$DefaultRunBase = Join-Path $ScriptRoot "..\midscene_run\auth"
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
  $summaryLines += "# FitTracker Midscene auth regression summary"
  $summaryLines += ""
  $summaryLines += "- date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
  $summaryLines += "- status: $Status"
  $summaryLines += "- device id: $DeviceId"
  $summaryLines += "- bundle: $BundleName"
  $summaryLines += "- ability: $AbilityName"
  $summaryLines += "- hap path: $HapPath"
  $summaryLines += "- test phone: $TestPhone"
  $summaryLines += "- run root: $RunRoot"
  $summaryLines += "- report dir: $RunRoot\report"
  $summaryLines += "- log dir: $RunRoot\log"
  $summaryLines += "- latest html: $(Get-LatestMidsceneReportHtmlPath)"
  $summaryLines += "- MIDSCENE_MODEL_BASE_URL: $($env:MIDSCENE_MODEL_BASE_URL)"
  $summaryLines += "- MIDSCENE_MODEL_NAME: $($env:MIDSCENE_MODEL_NAME)"
  $summaryLines += "- MIDSCENE_MODEL_FAMILY: $($env:MIDSCENE_MODEL_FAMILY)"
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
  Write-Host ('[FitTracker Midscene Auth] ' + $Title)
  $exe = $Command[0]
  $argsList = @($Command | Select-Object -Skip 1)
  $maxAttempts = 1
  if ($exe -eq 'npx.cmd') {
    $maxAttempts = 3
  }

  for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
    $rawOutput = & $exe @argsList 2>&1
    $outputText = (@($rawOutput) | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    if ($outputText.Length -gt 0) {
      Write-Host $outputText
    }
    if ($LASTEXITCODE -eq 0) {
      return @{
        Output = $outputText
        ExitCode = $LASTEXITCODE
      }
    }

    $isRetryableMidsceneFailure = $exe -eq 'npx.cmd' -and (
      $outputText.IndexOf('Invalid image: failed to decode base64 data', [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or
      $outputText.IndexOf('error while capturing screenshot', [System.StringComparison]::OrdinalIgnoreCase) -ge 0
    )
    if (-not $isRetryableMidsceneFailure -or $attempt -eq $maxAttempts) {
      if ($outputText.Length -gt 0) {
        throw ('Step failed: ' + $Title + '. ' + $outputText)
      }
      throw ('Step failed: ' + $Title)
    }

    Write-Host ('[FitTracker Midscene Auth] retry transient Midscene failure: ' + $Title + ' (attempt ' + ($attempt + 1).ToString() + '/' + $maxAttempts.ToString() + ')')
    Start-Sleep -Seconds 2
  }
}

function Invoke-Hdc {
  param(
    [string]$Title,
    [string[]]$CommandArgs
  )

  $fullArgs = @()
  if ($DeviceId.Length -gt 0) {
    $fullArgs += '-t'
    $fullArgs += $DeviceId
  }
  $fullArgs += $CommandArgs
  Invoke-Step -Title $Title -Command (@('hdc') + $fullArgs)
}

function Invoke-Midscene {
  param(
    [string]$Title,
    [string[]]$CommandArgs
  )

  $fullArgs = @('-y', '@midscene/harmony@1')
  $fullArgs += $CommandArgs
  if ($DeviceId.Length -gt 0) {
    $fullArgs += '--device-id'
    $fullArgs += $DeviceId
  }
  Invoke-Step -Title $Title -Command (@('npx.cmd') + $fullArgs)
}

function Get-HdcTargetsRawOutput {
  $rawOutput = & hdc list targets -v
  if ($LASTEXITCODE -ne 0) {
    throw 'Failed to query HDC targets.'
  }
  return (@($rawOutput) | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
}

function Ensure-HdcReadyForMidscene {
  param(
    [int]$MaxWaitSeconds = 45,
    [int]$PollSeconds = 5
  )

  $rawOutputText = Get-HdcTargetsRawOutput
  try {
    Wait-HdcTargetsReady -DeviceId $DeviceId -InitialRawOutput $rawOutputText -MaxWaitSeconds $MaxWaitSeconds -PollSeconds $PollSeconds | Out-Null
  } catch {
    throw ('HDC target is not ready for Midscene. ' + $_.Exception.Message)
  }
}

function Should-RetryMidsceneConnectFailure {
  param([string]$Message)

  if ([string]::IsNullOrWhiteSpace($Message)) {
    return $false
  }

  return $Message.IndexOf('Unable to connect to device', [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or
    $Message.IndexOf("reading 'match'", [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or
    $Message.IndexOf('device offline', [System.StringComparison]::OrdinalIgnoreCase) -ge 0
}

function Invoke-MidsceneConnect {
  param(
    [string]$Title = 'connect device',
    [int]$MaxAttempts = 3
  )

  for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    Ensure-HdcReadyForMidscene
    try {
      Invoke-Midscene -Title $Title -CommandArgs @('connect')
      return
    } catch {
      $message = $_.Exception.Message
      if ($attempt -eq $MaxAttempts -or -not (Should-RetryMidsceneConnectFailure -Message $message)) {
        throw
      }
      Write-Host ('[FitTracker Midscene Auth] retry Midscene device connect: ' + $attempt.ToString() + '/' + $MaxAttempts.ToString())
      Start-Sleep -Seconds 3
    }
  }
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
    Write-Host ('[FitTracker Midscene Auth] skip visual assert: ' + $Title)
    return
  }

  Invoke-Midscene -Title $Title -CommandArgs @('assert', '--prompt', $Prompt)
}

function Invoke-VisualAct {
  param(
    [string]$Title,
    [string]$Prompt
  )

  Invoke-Midscene -Title $Title -CommandArgs @('act', '--prompt', $Prompt)
}

if (-not $CheckOnly) {
  Assert-MidsceneEnvironment
}

if (-not $env:MIDSCENE_REPLANNING_CYCLE_LIMIT) {
  $env:MIDSCENE_REPLANNING_CYCLE_LIMIT = '60'
}

$runStatus = 'failed'
$failureReason = ''

try {
  $targetsResult = Invoke-Step -Title 'check hdc targets' -Command @('hdc', 'list', 'targets', '-v')
  Assert-HdcTargetsReady -RawOutput $targetsResult.Output -DeviceId $DeviceId

  if ($CheckOnly) {
    if (-not $SkipInstall -and -not (Test-Path $HapPath)) {
      throw ('HAP not found: ' + $HapPath + '. Build entry@default before running this script.')
    }

    Write-Host ""
    Write-Host '[FitTracker Midscene Auth] Check-only passed. Run without -CheckOnly to execute the regression.'
    $runStatus = 'check-only'
    return
  }

  if (-not (Test-Path $HapPath)) {
    throw ('HAP not found: ' + $HapPath + '. Build entry@default before running this script.')
  }

  Invoke-Hdc -Title 'clean app data' -CommandArgs @('shell', 'bm', 'clean', '-n', $BundleName, '-d', '-c', '-u', '0')

  if (-not $SkipInstall) {
    Invoke-Hdc -Title 'install app HAP' -CommandArgs @('install', '-r', $HapPath)
  }

  Invoke-Hdc -Title 'launch app' -CommandArgs @('shell', 'aa', 'start', '-a', $AbilityName, '-b', $BundleName)
  Start-Sleep -Seconds 2
  Invoke-MidsceneConnect -Title 'connect device'
  Invoke-Midscene -Title 'capture startup screen' -CommandArgs @('take_screenshot')
  Invoke-VisualAssert -Title 'assert startup screen' -Prompt 'The screen is not blank and there is no crash dialog.'

  Invoke-VisualAct -Title 'open register page' -Prompt 'If the login page is visible, tap the register link. If the startup page is visible, wait for the login page and then tap register. Stop when the register page is visible.'
  Invoke-VisualAssert -Title 'assert register page' -Prompt 'The register page is visible and shows the phone, password, and confirm password fields.'

  Invoke-VisualAct -Title 'fill register form' -Prompt ('On the register page, enter the phone number ' + $TestPhone + ', password ' + $TestPassword + ', and confirm password ' + $TestPassword + ', then tap register. Stop after the app navigates away from the register page.')
  Invoke-VisualAssert -Title 'assert post register route' -Prompt 'After registration, the app has navigated to the startup or goal setup flow, and there is no crash dialog.'

  Invoke-Hdc -Title 'simulate close and reopen' -CommandArgs @('shell', 'aa', 'start', '-a', $AbilityName, '-b', $BundleName)
  Start-Sleep -Seconds 2
  Invoke-Midscene -Title 'capture reopen screen' -CommandArgs @('take_screenshot')
  Invoke-VisualAssert -Title 'assert reopen screen' -Prompt 'After reopening, the app shows a valid FitTracker screen such as startup, login, goal setup, or home.'

  Invoke-VisualAct -Title 'recover session' -Prompt ('If the startup page is visible, let it continue. If the login page is visible, enter phone ' + $TestPhone + ' and password ' + $TestPassword + ' and tap login. Stop when either the home page or the goal setup page is visible.')
  Invoke-VisualAssert -Title 'assert session recovered' -Prompt 'The app is no longer on the login page or the register page. It shows either the FitTracker home page with today training, current plan, or start training actions, or the goal setup page with training goal, weekly training days, session duration, and the generate training plan action.'

  Invoke-VisualAct -Title 'verify home or goal branch' -Prompt 'Confirm the current screen is either the FitTracker home page or the goal setup page. The home page shows today training, current plan, or start training actions. The goal setup page shows training goal, weekly training days, session duration, or generate training plan. If one of those two pages is visible, stop and do not navigate further.'
  Invoke-VisualAssert -Title 'assert home or goal page' -Prompt 'The current screen is either the FitTracker home page with today training or current plan actions, or the goal setup page with training goal, weekly training days, session duration, or generate training plan. It is not the login page or the register page.'

  $runStatus = 'passed'
}
catch {
  $failureReason = $_.Exception.Message
  throw
}
finally {
  Write-RegressionSummary -Status $runStatus -FailureReason $failureReason
  if (-not $SkipDisconnect) {
    try {
      Invoke-Midscene -Title 'disconnect device' -CommandArgs @('disconnect')
    } catch {
      Write-Host ('[FitTracker Midscene Auth] disconnect skipped: ' + $_.Exception.Message)
    }
  }
  Write-Host ''
  Write-Host ('[FitTracker Midscene Auth] Regression summary written to ' + $RunSummaryPath)
}
