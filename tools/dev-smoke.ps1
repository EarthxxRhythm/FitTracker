param(
  [ValidateSet('backup-card', 'media-card', 'current-plan', 'summary-page', 'membership', 'both')]
  [string]$Target = 'current-plan',
  [string]$DeviceId = "",
  [string]$BundleName = "com.example.fittracker_opencode",
  [string]$AbilityName = "EntryAbility",
  [string]$HapPath = "entry/build/default/outputs/default/entry-default-unsigned.hap",
  [string]$RunRoot = "",
  [string]$RunTag = "",
  [string]$SummaryFileName = "midscene-entrypoints-smoke-summary.md",
  [string]$ModelName = "doubao-seed-2-0-lite-260215",
  [string]$ModelFamily = "doubao-seed",
  [string]$BaseUrl = "https://ark.cn-beijing.volces.com/api/v3",
  [int]$ReplanningCycleLimit = 60,
  [switch]$ResetAppData,
  [switch]$SkipInstall,
  [switch]$SkipDisconnect,
  [switch]$SkipVisualAsserts,
  [switch]$CheckOnly,
  [switch]$SkipPrepareEnv,
  [switch]$CheckHdc
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ScriptRoot = $PSScriptRoot
$EnvScriptPath = Join-Path $ScriptRoot "midscene-env.ps1"
$SmokeScriptPath = Join-Path $ScriptRoot "midscene-entrypoints-smoke.ps1"
$HdcTargetsScriptPath = Join-Path $ScriptRoot "hdc-targets.ps1"

if (-not (Test-Path $EnvScriptPath)) {
  throw ('Required script not found: ' + $EnvScriptPath)
}

if (-not (Test-Path $SmokeScriptPath)) {
  throw ('Required script not found: ' + $SmokeScriptPath)
}

if (-not (Test-Path $HdcTargetsScriptPath)) {
  throw ('Required script not found: ' + $HdcTargetsScriptPath)
}
. $HdcTargetsScriptPath

$hdcRawOutput = & hdc list targets -v
if ($LASTEXITCODE -ne 0) {
  throw 'Failed to query HDC targets.'
}
$hdcText = (@($hdcRawOutput) | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
if (-not $CheckOnly) {
  $hdcText = Wait-HdcTargetsReady -DeviceId $DeviceId -InitialRawOutput $hdcText -MaxWaitSeconds 90 -PollSeconds 5
}

if (-not $SkipPrepareEnv) {
  & $EnvScriptPath `
    -ModelName $ModelName `
    -ModelFamily $ModelFamily `
    -BaseUrl $BaseUrl `
    -ReplanningCycleLimit $ReplanningCycleLimit `
    -CheckHdc:$CheckHdc
}

$smokeParams = @{
  Target = $Target
  DeviceId = $DeviceId
  BundleName = $BundleName
  AbilityName = $AbilityName
  HapPath = $HapPath
  SummaryFileName = $SummaryFileName
  ResetAppData = $ResetAppData
  SkipInstall = $SkipInstall
  SkipDisconnect = $SkipDisconnect
  SkipVisualAsserts = $SkipVisualAsserts
  CheckOnly = $CheckOnly
}

if (-not [string]::IsNullOrWhiteSpace($RunRoot)) {
  $smokeParams["RunRoot"] = $RunRoot
}

if (-not [string]::IsNullOrWhiteSpace($RunTag)) {
  $smokeParams["RunTag"] = $RunTag
}

Write-Host ""
Write-Host ("[FitTracker Dev Smoke] Focused target: " + $Target)
Write-Host "[FitTracker Dev Smoke] This entry runs the focused smoke only and does not start the full regression."

& $SmokeScriptPath @smokeParams
