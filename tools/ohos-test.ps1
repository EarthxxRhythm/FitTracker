param(
  [string]$DeviceId = "",
  [string]$BundleName = "com.example.fittracker_opencode",
  [string]$ModuleName = "entry_test",
  [string]$TestRunner = "OpenHarmonyTestRunner",
  [Alias('ClassFilter')]
  [string[]]$ClassNames = @(),
  [ValidateSet('backup', 'content-sync', 'full')]
  [string]$Preset = 'content-sync',
  [string]$DefaultHapPath = "entry/build/default/outputs/default/entry-default-unsigned.hap",
  [string]$TestHapPath = "entry/build/default/outputs/ohosTest/entry-ohosTest-unsigned.hap",
  [string]$RunRoot = "",
  [string]$RunTag = "",
  [string]$SummaryFileName = "ohos-test-summary.md",
  [string]$LogFileName = "ohos-test-output.log",
  [int]$WaitTimeSec = 180,
  [int]$BuildTimeoutSec = 600,
  [switch]$SkipBuild,
  [switch]$ForceBuild,
  [switch]$SkipInstall,
  [switch]$CheckOnly,
  [switch]$SkipStopDaemon
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ScriptRoot = $PSScriptRoot
$RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $ScriptRoot ".."))
$DevEcoEnvScriptPath = Join-Path $ScriptRoot "deveco-env.ps1"
$DefaultRunBase = Join-Path $RepoRoot "test_run\ohosTest"

if ([string]::IsNullOrWhiteSpace($RunTag)) {
  $RunTag = (Get-Date -Format "yyyyMMdd-HHmmss") + "-p" + $PID.ToString()
}
if ([string]::IsNullOrWhiteSpace($RunRoot)) {
  $RunRoot = Join-Path $DefaultRunBase $RunTag
}

$RunRoot = [System.IO.Path]::GetFullPath($RunRoot)
$RunSummaryPath = Join-Path $RunRoot $SummaryFileName
$RunLogPath = Join-Path $RunRoot $LogFileName
$HvigorwPath = "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat"

$PresetClassMap = @{
  'backup' = @('UserDataBackupService', 'SystemBackupBridgeService')
  'content-sync' = @('ContentDatabaseService', 'SyncService')
  'full' = @()
}

function New-RunArtifacts {
  New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null
  Set-Content -Path $RunLogPath -Value @() -Encoding utf8
}

function Write-RunLog {
  param([string]$Text)

  Add-Content -Path $RunLogPath -Value $Text -Encoding utf8
}

function Convert-ToCmdLiteral {
  param([string]$Value)

  if ($Value.IndexOf('"') -ge 0) {
    return '"' + $Value.Replace('"', '\"') + '"'
  }
  if ($Value.IndexOf(' ') -ge 0) {
    return '"' + $Value + '"'
  }
  return $Value
}

function Invoke-LoggedCommand {
  param(
    [string]$Title,
    [string]$FilePath,
    [string[]]$Arguments,
    [int]$TimeoutSec = 0,
    [switch]$AllowFailure
  )

  Write-Host ""
  Write-Host ('[FitTracker OhosTest] ' + $Title)
  Write-RunLog ('')
  Write-RunLog ('## ' + $Title)
  Write-RunLog ('$ ' + $FilePath + ' ' + ($Arguments -join ' '))

  $stdoutPath = [System.IO.Path]::GetTempFileName()
  $stderrPath = [System.IO.Path]::GetTempFileName()
  $exitCode = 0
  $text = ''
  try {
    $resolvedFilePath = $FilePath
    $resolvedArguments = $Arguments
    $extension = [System.IO.Path]::GetExtension($FilePath).ToLowerInvariant()
    if ($extension -eq '.bat' -or $extension -eq '.cmd') {
      $commandParts = New-Object 'System.Collections.Generic.List[string]'
      $commandParts.Add((Convert-ToCmdLiteral -Value $FilePath)) | Out-Null
      for ($index = 0; $index -lt $Arguments.Length; $index++) {
        $commandParts.Add((Convert-ToCmdLiteral -Value $Arguments[$index])) | Out-Null
      }
      $resolvedFilePath = $env:ComSpec
      $resolvedArguments = @('/d', '/c', ($commandParts -join ' '))
    }

    $process = Start-Process -FilePath $resolvedFilePath `
      -ArgumentList $resolvedArguments `
      -WorkingDirectory $RepoRoot `
      -NoNewWindow `
      -PassThru `
      -RedirectStandardOutput $stdoutPath `
      -RedirectStandardError $stderrPath

    if ($TimeoutSec -gt 0) {
      $finished = $process.WaitForExit($TimeoutSec * 1000)
      if (-not $finished) {
        try {
          Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        } catch {
        }
        throw ($Title + ' timed out after ' + $TimeoutSec.ToString() + ' seconds')
      }
    } else {
      $process.WaitForExit()
    }

    $stdoutText = ''
    $stderrText = ''
    if (Test-Path $stdoutPath) {
      $stdoutRaw = Get-Content -Path $stdoutPath -Raw -Encoding UTF8
      if ($null -ne $stdoutRaw) {
        $stdoutText = $stdoutRaw.TrimEnd()
      }
    }
    if (Test-Path $stderrPath) {
      $stderrRaw = Get-Content -Path $stderrPath -Raw -Encoding UTF8
      if ($null -ne $stderrRaw) {
        $stderrText = $stderrRaw.TrimEnd()
      }
    }
    $textParts = @($stdoutText, $stderrText) | Where-Object { $_.Length -gt 0 }
    $text = ($textParts -join [Environment]::NewLine).TrimEnd()
    $process.Refresh()
    if ($process.HasExited) {
      $exitCode = $process.ExitCode
    }
  } finally {
    if (Test-Path $stdoutPath) {
      Remove-Item -LiteralPath $stdoutPath -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $stderrPath) {
      Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue
    }
  }

  if ($text.Length -gt 0) {
    Write-Host $text
    Write-RunLog $text
  }

  if ($null -eq $exitCode) {
    $exitCode = 0
  }

  if (-not $AllowFailure -and $exitCode -ne 0) {
    throw ($Title + ' failed (exit ' + $exitCode.ToString() + ')')
  }

  return @{
    ExitCode = $exitCode
    Output = $text
  }
}

function Get-HdcPrefixArgs {
  $prefix = @()
  if ($DeviceId.Length -gt 0) {
    $prefix += '-t'
    $prefix += $DeviceId
  }
  return $prefix
}

function Invoke-HdcCommand {
  param(
    [string]$Title,
    [string[]]$Arguments,
    [switch]$AllowFailure
  )

  $fullArgs = @()
  $fullArgs += Get-HdcPrefixArgs
  $fullArgs += $Arguments
  return Invoke-LoggedCommand -Title $Title -FilePath 'hdc' -Arguments $fullArgs -AllowFailure:$AllowFailure
}

function Resolve-ClassNames {
  $filtered = @($ClassNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  if ($filtered.Count -gt 0) {
    return $filtered
  }
  if ($PresetClassMap.ContainsKey($Preset)) {
    return @($PresetClassMap[$Preset])
  }
  return @()
}

function Test-HdcTargetsAvailable {
  param([string]$RawOutput)

  if ([string]::IsNullOrWhiteSpace($RawOutput)) {
    return $false
  }

  $lines = $RawOutput -split "`r?`n"
  for ($index = 0; $index -lt $lines.Length; $index++) {
    $line = $lines[$index].Trim()
    if ($line.Length -eq 0) {
      continue
    }
    if ($line -eq '[Empty]') {
      continue
    }
    if ($line.StartsWith('[List')) {
      continue
    }
    return $true
  }
  return $false
}

function Ensure-DevEcoEnvironment {
  if (-not (Test-Path $DevEcoEnvScriptPath)) {
    throw ('Required script not found: ' + $DevEcoEnvScriptPath)
  }
  . $DevEcoEnvScriptPath
}

function Ensure-HapExists {
  param(
    [string]$Path,
    [string]$Label
  )

  if (-not (Test-Path $Path)) {
    throw ($Label + ' not found: ' + $Path)
  }
}

function Invoke-HvigorStopDaemon {
  if ($SkipStopDaemon) {
    return
  }

  if (-not (Test-Path $HvigorwPath)) {
    throw ('hvigorw.bat not found: ' + $HvigorwPath)
  }

  Invoke-LoggedCommand -Title 'stop hvigor daemon' -FilePath $HvigorwPath -Arguments @('--stop-daemon') -AllowFailure
}

function Invoke-HvigorBuild {
  param(
    [string]$ModuleTarget,
    [string]$Label,
    [string]$ExpectedHapPath
  )

  if (-not (Test-Path $HvigorwPath)) {
    throw ('hvigorw.bat not found: ' + $HvigorwPath)
  }

  $buildArgs = @(
    'assembleHap',
    '--mode',
    'module',
    '-p',
    ('module=' + $ModuleTarget),
    '-p',
    'product=default',
    '--no-parallel'
  )

  Invoke-HvigorStopDaemon
  $firstAttempt = Invoke-LoggedCommand -Title ('build ' + $Label) -FilePath $HvigorwPath -Arguments $buildArgs -TimeoutSec $BuildTimeoutSec -AllowFailure
  if ($firstAttempt.ExitCode -eq 0) {
    return
  }

  Write-Host ('[FitTracker OhosTest] retrying build after hvigor daemon reset: ' + $Label)
  Invoke-HvigorStopDaemon
  $secondAttempt = Invoke-LoggedCommand -Title ('retry build ' + $Label) -FilePath $HvigorwPath -Arguments $buildArgs -TimeoutSec $BuildTimeoutSec -AllowFailure
  if ($secondAttempt.ExitCode -ne 0) {
    if (Test-Path $ExpectedHapPath) {
      Write-Host ('[FitTracker OhosTest] build fallback: reuse existing HAP for ' + $Label)
      Write-RunLog ('[build fallback] reuse existing HAP: ' + $ExpectedHapPath)
      return
    }
    throw ('Build failed for ' + $Label)
  }
}

function Test-ShouldBuild {
  if ($SkipBuild) {
    return $false
  }
  if ($ForceBuild) {
    return $true
  }
  if (-not (Test-Path $DefaultHapPath)) {
    return $true
  }
  if (-not (Test-Path $TestHapPath)) {
    return $true
  }
  return $false
}

function New-TestReport {
  $report = [ordered]@{
    TestsRun = 0
    FailureCount = 0
    ErrorCount = 0
    PassCount = 0
    IgnoreCount = 0
    FinishedResultCode = ''
    FinishedResultMessage = ''
    FailureCases = New-Object 'System.Collections.Generic.List[object]'
  }
  return $report
}

function Parse-TestOutput {
  param([string]$RawOutput)

  $report = New-TestReport
  $currentClass = ''
  $currentTest = ''
  $currentStream = ''

  if ([string]::IsNullOrWhiteSpace($RawOutput)) {
    return $report
  }

  $lines = $RawOutput -split "`r?`n"
  for ($index = 0; $index -lt $lines.Length; $index++) {
    $line = $lines[$index].Trim()
    if ($line -match '^OHOS_REPORT_STATUS: class=(.*)$') {
      $currentClass = $Matches[1].Trim()
      continue
    }
    if ($line -match '^OHOS_REPORT_STATUS: test=(.*)$') {
      $currentTest = $Matches[1].Trim()
      continue
    }
    if ($line -match '^OHOS_REPORT_STATUS: stream=(.*)$') {
      $currentStream = $Matches[1]
      continue
    }
    if ($line -match '^OHOS_REPORT_STATUS_CODE: (-?\d+)$') {
      $statusCode = [int]$Matches[1]
      if ($statusCode -lt 0) {
        $report.FailureCases.Add([pscustomobject]@{
          ClassName = $currentClass
          TestName = $currentTest
          StatusCode = $statusCode
          Message = $currentStream
        }) | Out-Null
      }
      $currentStream = ''
      continue
    }
    if ($line -match '^OHOS_REPORT_RESULT: stream=Tests run: (\d+), Failure: (\d+), Error: (\d+), Pass: (\d+), Ignore: (\d+)$') {
      $report.TestsRun = [int]$Matches[1]
      $report.FailureCount = [int]$Matches[2]
      $report.ErrorCount = [int]$Matches[3]
      $report.PassCount = [int]$Matches[4]
      $report.IgnoreCount = [int]$Matches[5]
      continue
    }
    if ($line -match '^TestFinished-ResultCode: (-?\d+)$') {
      $report.FinishedResultCode = $Matches[1]
      continue
    }
    if ($line -match '^TestFinished-ResultMsg: (.*)$') {
      $report.FinishedResultMessage = $Matches[1]
      continue
    }
  }

  return $report
}

function Write-TestSummary {
  param(
    [string]$Status,
    [string]$FailureReason,
    [object]$Report
  )

  $summaryLines = @()
  $summaryLines += '# FitTracker ohosTest summary'
  $summaryLines += ''
  $summaryLines += '- date: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
  $summaryLines += '- status: ' + $Status
  $summaryLines += '- device id: ' + $DeviceId
  $summaryLines += '- bundle: ' + $BundleName
  $summaryLines += '- module: ' + $ModuleName
  $summaryLines += '- test runner: ' + $TestRunner
  $summaryLines += '- preset: ' + $Preset
  $summaryLines += '- class filter: ' + ((Resolve-ClassNames) -join ', ')
  $summaryLines += '- default hap: ' + $DefaultHapPath
  $summaryLines += '- test hap: ' + $TestHapPath
  $summaryLines += '- run root: ' + $RunRoot
  $summaryLines += '- raw log: ' + $RunLogPath
  $summaryLines += '- tests run: ' + $Report.TestsRun.ToString()
  $summaryLines += '- pass: ' + $Report.PassCount.ToString()
  $summaryLines += '- failure: ' + $Report.FailureCount.ToString()
  $summaryLines += '- error: ' + $Report.ErrorCount.ToString()
  $summaryLines += '- ignore: ' + $Report.IgnoreCount.ToString()
  $summaryLines += '- result code: ' + $Report.FinishedResultCode
  $summaryLines += '- result message: ' + $Report.FinishedResultMessage
  $summaryLines += ''
  $summaryLines += '## failure notes'
  if ($FailureReason.Length -gt 0) {
    $summaryLines += '- failure reason: ' + $FailureReason
  } else {
    $summaryLines += '- none'
  }
  $summaryLines += ''
  $summaryLines += '## failed cases'
  if ($Report.FailureCases.Count -eq 0) {
    $summaryLines += '- none'
  } else {
    for ($index = 0; $index -lt $Report.FailureCases.Count; $index++) {
      $failureCase = $Report.FailureCases[$index]
      $summaryLines += '- ' + $failureCase.ClassName + ' :: ' + $failureCase.TestName + ' :: code=' + $failureCase.StatusCode.ToString()
      if ($failureCase.Message.Length -gt 0) {
        $summaryLines += '  - ' + $failureCase.Message
      }
    }
  }

  Set-Content -Path $RunSummaryPath -Value $summaryLines -Encoding utf8
}

function Get-RequestedClassFilter {
  $filtered = @(Resolve-ClassNames)
  if ($filtered.Count -eq 0) {
    return ''
  }
  return ($filtered -join ',')
}

New-RunArtifacts

$runStatus = 'failed'
$failureReason = ''
$report = New-TestReport

try {
  Ensure-DevEcoEnvironment
  $targetsResult = Invoke-HdcCommand -Title 'check hdc targets' -Arguments @('list', 'targets')
  if (-not (Test-HdcTargetsAvailable -RawOutput $targetsResult.Output)) {
    throw 'No HDC targets are connected. Connect a device or simulator before running ohosTest.'
  }

  if ($CheckOnly) {
    if (-not $SkipBuild) {
      if (-not (Test-Path $HvigorwPath)) {
        throw ('hvigorw.bat not found: ' + $HvigorwPath)
      }
    }
    if (-not $ForceBuild) {
      Ensure-HapExists -Path $DefaultHapPath -Label 'Default HAP'
      Ensure-HapExists -Path $TestHapPath -Label 'ohosTest HAP'
    }

    Write-Host ""
    Write-Host '[FitTracker OhosTest] Check-only passed. Run without -CheckOnly to execute Hypium tests.'
    $runStatus = 'check-only'
    return
  }

  if (Test-ShouldBuild) {
    Invoke-HvigorBuild -ModuleTarget 'entry@default' -Label 'entry@default' -ExpectedHapPath $DefaultHapPath
    Invoke-HvigorBuild -ModuleTarget 'entry@ohosTest' -Label 'entry@ohosTest' -ExpectedHapPath $TestHapPath
  } else {
    Write-Host '[FitTracker OhosTest] reuse existing HAP artifacts; pass -ForceBuild to rebuild.'
    Write-RunLog '[build] skipped; reusing existing HAP artifacts.'
  }

  Ensure-HapExists -Path $DefaultHapPath -Label 'Default HAP'
  Ensure-HapExists -Path $TestHapPath -Label 'ohosTest HAP'

  if (-not $SkipInstall) {
    Invoke-HdcCommand -Title 'install default hap' -Arguments @('install', '-r', $DefaultHapPath) | Out-Null
    Invoke-HdcCommand -Title 'install ohosTest hap' -Arguments @('install', '-r', $TestHapPath) | Out-Null
  }

  $testArgs = @(
    'shell',
    'aa',
    'test',
    '-b',
    $BundleName,
    '-m',
    $ModuleName,
    '-s',
    'unittest',
    $TestRunner
  )

  $classFilter = Get-RequestedClassFilter
  if ($classFilter.Length -gt 0) {
    $testArgs += '-s'
    $testArgs += 'class'
    $testArgs += $classFilter
  }
  $testArgs += '-w'
  $testArgs += $WaitTimeSec.ToString()

  $testResult = Invoke-HdcCommand -Title 'run ohosTest Hypium suite' -Arguments $testArgs
  $report = Parse-TestOutput -RawOutput $testResult.Output

  if ($report.TestsRun -eq 0 -and $report.FailureCases.Count -eq 0) {
    if ($testResult.Output -match 'Not match target founded') {
      throw 'HDC target was not found while installing or running ohosTest.'
    }
    throw 'No Hypium test result was parsed from aa test output.'
  }

  if ($report.FailureCount -gt 0 -or $report.ErrorCount -gt 0) {
    $failureReason = 'Hypium reported failed or errored cases.'
    $runStatus = 'failed'
  } elseif ($report.FinishedResultCode -ne '' -and $report.FinishedResultCode -ne '0') {
    $failureReason = 'TestFinished-ResultCode=' + $report.FinishedResultCode
    $runStatus = 'failed'
  } else {
    $runStatus = 'passed'
  }
}
catch {
  if ($failureReason.Length -eq 0) {
    $failureReason = $_.Exception.Message
  }
  throw
}
finally {
  Write-TestSummary -Status $runStatus -FailureReason $failureReason -Report $report
  Write-Host ''
  Write-Host ('[FitTracker OhosTest] Summary written to ' + $RunSummaryPath)
}
