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
  Invoke-Midscene -Title 'connect device' -CommandArgs @('connect')
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
  Invoke-VisualAssert -Title 'assert session recovered' -Prompt 'The app shows either the home page or the goal setup page, which means the saved session has been restored.'

  Invoke-VisualAct -Title 'verify home or goal branch' -Prompt 'Confirm the current screen is either the home page or the goal setup page. If the home page is visible, stop. If the goal setup page is visible, stop. Do not navigate further.'
  Invoke-VisualAssert -Title 'assert home or goal page' -Prompt 'The current screen is a valid FitTracker main page and not the login or register page.'

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
