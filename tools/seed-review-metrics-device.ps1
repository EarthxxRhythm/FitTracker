param(
  [string]$DeviceId = '127.0.0.1:5555',
  [string]$BundleName = 'com.example.fittracker_opencode',
  [string]$AbilityName = 'EntryAbility',
  [string]$RemotePreferenceDir = '/data/app/el2/100/base/com.example.fittracker_opencode/haps/entry/preferences'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptRoot = $PSScriptRoot
$HdcTargetsScriptPath = Join-Path $ScriptRoot 'hdc-targets.ps1'
$TempRoot = Join-Path $ScriptRoot '..\test_run\device_seed'
$RunTag = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-p' + $PID.ToString()
$RunRoot = [System.IO.Path]::GetFullPath((Join-Path $TempRoot $RunTag))

if (-not (Test-Path $HdcTargetsScriptPath)) {
  throw ('Required script not found: ' + $HdcTargetsScriptPath)
}
. $HdcTargetsScriptPath

function New-RunRoot {
  New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null
}

function Save-RunArtifact {
  param(
    [string]$FileName,
    [string]$Content
  )

  $filePath = Join-Path $RunRoot $FileName
  Set-Content -LiteralPath $filePath -Value $Content -Encoding UTF8
  return $filePath
}

function Invoke-Hdc {
  param(
    [string]$Title,
    [string[]]$Arguments
  )

  Write-Host ''
  Write-Host ('[FitTracker Device Seed] ' + $Title)
  $fullArgs = @()
  if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
    $fullArgs += @('-t', $DeviceId)
  }
  $fullArgs += $Arguments
  $output = & hdc @fullArgs 2>&1
  $outputText = (@($output) | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
  if ($output) {
    Write-Host $outputText
  }
  if ($LASTEXITCODE -ne 0 -or $outputText.IndexOf('[Fail]', [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
    throw ('HDC step failed: ' + $Title)
  }
  return $outputText
}

function Read-RemotePreferenceFile {
  param([string]$FileName)

  $rawXml = Invoke-Hdc -Title ('read ' + $FileName) -Arguments @('shell', 'cat', ($RemotePreferenceDir + '/' + $FileName))
  Save-RunArtifact -FileName ($FileName + '.xml') -Content $rawXml | Out-Null
  return $rawXml
}

function Get-PreferenceStringValue {
  param(
    [string]$RawXml,
    [string]$Key
  )

  try {
    [xml]$document = $RawXml
    $node = $document.SelectSingleNode("/preferences/string[@key='$Key']")
    if ($null -eq $node) {
      throw ('Missing preference key: ' + $Key)
    }
    return $node.InnerText
  } catch {
    throw ('Failed to parse preference key ' + $Key + ': ' + $_.Exception.Message)
  }
}

function ConvertFrom-JsonStrict {
  param(
    [string]$RawJson,
    [string]$Label
  )

  try {
    $parsed = $RawJson | ConvertFrom-Json
    Write-Output $parsed
  } catch {
    throw ('Failed to parse ' + $Label + ' JSON: ' + $_.Exception.Message)
  }
}

function Wait-ForPreferenceVerification {
  param(
    [string]$Title,
    [scriptblock]$Validator,
    [int]$MaxAttempts = 8,
    [int]$PollSeconds = 2
  )

  $lastErrorMessage = ''
  for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    try {
      return & $Validator
    } catch {
      $lastErrorMessage = $_.Exception.Message
      if ($attempt -eq $MaxAttempts) {
        throw ($Title + ' verification failed: ' + $lastErrorMessage)
      }
      Start-Sleep -Seconds $PollSeconds
    }
  }

  throw ($Title + ' verification failed: ' + $lastErrorMessage)
}

function Write-Summary {
  param(
    [string]$TokenValue,
    [pscustomobject]$Goal,
    [System.Object[]]$Entitlements,
    [System.Object[]]$Sessions
  )

  $summaryLines = @(
    '# FitTracker device seed summary',
    '',
    '- status: passed',
    ('- date: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')),
    ('- device id: ' + $DeviceId),
    ('- bundle: ' + $BundleName),
    ('- run root: ' + $RunRoot),
    '',
    '## verified stores',
    ('- auth token: present, length=' + $TokenValue.Length.ToString()),
    ('- goal: ' + $Goal.goalId + ' / ' + $Goal.weeklyDays.ToString() + ' days / ' + $Goal.sessionMinutes.ToString() + ' min'),
    ('- entitlement: ' + $Entitlements[0].userId + ' / ' + $Entitlements[0].tier + ' / ' + $Entitlements[0].source),
    ('- sessions: ' + $Sessions.Count.ToString() + ' (' + (($Sessions | ForEach-Object { $_.id }) -join ', ') + ')'),
    '',
    '## expected downstream review signals',
    '- average completion: 78%',
    '- latest session volume: 357 kg',
    '- weekly total volume: 1364 kg',
    '- PR: 105 kg for ex_barbell_bench_press'
  )
  Save-RunArtifact -FileName 'seed-summary.md' -Content ($summaryLines -join [Environment]::NewLine) | Out-Null
}

New-RunRoot
Wait-HdcTargetsReady -DeviceId $DeviceId | Out-Null
Invoke-Hdc -Title 'stop app before seeding' -Arguments @('shell', 'aa', 'force-stop', $BundleName)
Invoke-Hdc -Title 'launch app-owned review metrics seed' -Arguments @(
  'shell',
  'aa',
  'start',
  '-a',
  $AbilityName,
  '-b',
  $BundleName,
  '--ps',
  'devSeed',
  'review_metrics'
)
Start-Sleep -Seconds 3

$tokenValue = Wait-ForPreferenceVerification -Title 'auth token store' -Validator {
  $rawXml = Read-RemotePreferenceFile -FileName 'fit_tracker_session'
  $token = Get-PreferenceStringValue -RawXml $rawXml -Key 'auth_token'
  if ([string]::IsNullOrWhiteSpace($token) -or $token.Length -lt 40) {
    throw 'auth token is missing or too short'
  }
  if ($token -notmatch '^[A-Za-z0-9+/=._-]+$') {
    throw 'auth token shape is invalid'
  }
  return $token
}

$goal = Wait-ForPreferenceVerification -Title 'goal store' -Validator {
  $rawXml = Read-RemotePreferenceFile -FileName 'fit_tracker_goal'
  $goalValue = Get-PreferenceStringValue -RawXml $rawXml -Key 'current_goal'
  $goalObject = ConvertFrom-JsonStrict -RawJson $goalValue -Label 'goal'
  if ($goalObject.goalId -ne 'goal_review_metrics') {
    throw ('unexpected goalId: ' + $goalObject.goalId)
  }
  if ($goalObject.weeklyDays -ne 3) {
    throw ('unexpected weeklyDays: ' + $goalObject.weeklyDays.ToString())
  }
  if ($goalObject.sessionMinutes -ne 45) {
    throw ('unexpected sessionMinutes: ' + $goalObject.sessionMinutes.ToString())
  }
  return $goalObject
}

$entitlements = Wait-ForPreferenceVerification -Title 'entitlement store' -Validator {
  $rawXml = Read-RemotePreferenceFile -FileName 'fit_tracker_entitlement'
  $entitlementValue = Get-PreferenceStringValue -RawXml $rawXml -Key 'user_entitlements'
  $entitlementList = @(ConvertFrom-JsonStrict -RawJson $entitlementValue -Label 'entitlement')
  if ($entitlementList.Count -lt 1) {
    throw 'entitlement list is empty'
  }
  if ($entitlementList[0].userId -ne '13900009999') {
    throw ('unexpected entitlement userId: ' + $entitlementList[0].userId)
  }
  if ($entitlementList[0].tier -ne 'pro') {
    throw ('unexpected entitlement tier: ' + $entitlementList[0].tier)
  }
  if ($entitlementList[0].source -ne 'debug_override') {
    throw ('unexpected entitlement source: ' + $entitlementList[0].source)
  }
  if ($entitlementList[0].status -ne 'active') {
    throw ('unexpected entitlement status: ' + $entitlementList[0].status)
  }
  return $entitlementList
}

$sessions = Wait-ForPreferenceVerification -Title 'workout session store' -Validator {
  $rawXml = Read-RemotePreferenceFile -FileName 'fit_tracker_sessions'
  $sessionValue = Get-PreferenceStringValue -RawXml $rawXml -Key 'sessions'
  $sessionList = @(ConvertFrom-JsonStrict -RawJson $sessionValue -Label 'sessions')
  if ($sessionList.Count -ne 2) {
    throw ('unexpected session count: ' + $sessionList.Count.ToString())
  }
  if ($sessionList[0].id -ne 'session_review_metrics_1') {
    throw ('unexpected first session id: ' + $sessionList[0].id)
  }
  if ($sessionList[1].id -ne 'session_review_metrics_2') {
    throw ('unexpected second session id: ' + $sessionList[1].id)
  }
  if ($sessionList[0].totalVolume -ne 1007) {
    throw ('unexpected first session totalVolume: ' + $sessionList[0].totalVolume.ToString())
  }
  if ($sessionList[1].notes -ne 'completed_sets=3;target_sets=4') {
    throw ('unexpected second session notes: ' + $sessionList[1].notes)
  }
  if ($sessionList[1].exercises[0].sets[0].weight -ne 51 -or $sessionList[1].exercises[0].sets[0].reps -ne 7) {
    throw 'second session set payload is invalid'
  }
  return $sessionList
}

Invoke-Hdc -Title 'stop app after seeding' -Arguments @('shell', 'aa', 'force-stop', $BundleName)
Write-Summary -TokenValue $tokenValue -Goal $goal -Entitlements $entitlements -Sessions $sessions

Write-Host ''
Write-Host '[FitTracker Device Seed] Seeded deterministic review metrics data through app-owned launch hook.'
Write-Host ('[FitTracker Device Seed] Expected review values: 78%, 357 kg, 1364 kg, 105 kg with Pro review insights enabled')
Write-Host ('[FitTracker Device Seed] Run root: ' + $RunRoot)
