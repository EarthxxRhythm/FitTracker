param(
  [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
  [switch]$SkipDevEco,
  [switch]$RequireDevice,
  [switch]$SkipEmulator,
  [string]$PencilExecutablePath = '',
  [switch]$RequirePencil,
  [int]$MaxWaitSeconds = 90
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$devEcoRoot = 'C:\Program Files\Huawei\DevEco Studio'
$devEcoExecutable = Join-Path $devEcoRoot 'bin\devecostudio64.exe'
$emulatorExecutable = Join-Path $devEcoRoot 'tools\emulator\Emulator.exe'
$environmentScript = Join-Path $PSScriptRoot 'deveco-env.ps1'

function Get-RunningProcessByPath {
  param([string]$ExecutablePath)

  $resolvedPath = [System.IO.Path]::GetFullPath($ExecutablePath)
  return @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
      $_.Path -and ([System.IO.Path]::GetFullPath($_.Path) -ieq $resolvedPath)
    })
}

function Start-InteractiveApplication {
  param(
    [string]$ExecutablePath,
    [string]$Argument = '',
    [string]$WorkingDirectory = ''
  )

  if (-not (Test-Path -LiteralPath $ExecutablePath)) {
    throw ('Application not found: ' + $ExecutablePath)
  }

  $running = @(Get-RunningProcessByPath -ExecutablePath $ExecutablePath)
  if ($running.Count -gt 0) {
    Write-Host ('[FitTracker env] already running: ' + $ExecutablePath)
    return
  }

  $startParameters = @{
    FilePath = $ExecutablePath
    PassThru = $true
  }
  if (-not [string]::IsNullOrWhiteSpace($Argument)) {
    $startParameters.ArgumentList = @($Argument)
  }
  if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
    $startParameters.WorkingDirectory = $WorkingDirectory
  }

  $process = Start-Process @startParameters
  Write-Host ('[FitTracker env] started: ' + $ExecutablePath + ' (PID ' + $process.Id + ')')
}

function Get-HdcOutput {
  $output = & hdc list targets -v 2>&1
  if ($LASTEXITCODE -ne 0) {
    return ''
  }
  return (@($output) | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
}

function Has-ReadyHdcTarget {
  param([string]$RawOutput)

  return $RawOutput -match '(?im)^\S+\s+\S+\s+(Ready|Connected)\b'
}

if (-not (Test-Path -LiteralPath $ProjectRoot)) {
  throw ('Project root not found: ' + $ProjectRoot)
}

if (-not (Test-Path -LiteralPath $environmentScript)) {
  throw ('DevEco environment script not found: ' + $environmentScript)
}

. $environmentScript

if (-not $SkipDevEco) {
  Start-InteractiveApplication -ExecutablePath $devEcoExecutable -Argument $ProjectRoot -WorkingDirectory $ProjectRoot
}

if ($RequireDevice) {
  $hdcOutput = Get-HdcOutput
  if (-not (Has-ReadyHdcTarget -RawOutput $hdcOutput)) {
    if (-not $SkipEmulator) {
      Start-InteractiveApplication -ExecutablePath $emulatorExecutable -WorkingDirectory $ProjectRoot
    }

    $deadline = (Get-Date).AddSeconds($MaxWaitSeconds)
    do {
      Start-Sleep -Seconds 3
      $hdcOutput = Get-HdcOutput
    } while (-not (Has-ReadyHdcTarget -RawOutput $hdcOutput) -and (Get-Date) -lt $deadline)

    if (-not (Has-ReadyHdcTarget -RawOutput $hdcOutput)) {
      throw ('No ready HDC target after ' + $MaxWaitSeconds + ' seconds. Output: ' + $hdcOutput)
    }
  }
  Write-Host '[FitTracker env] HDC target ready.'
}

if ($RequirePencil) {
  if ([string]::IsNullOrWhiteSpace($PencilExecutablePath)) {
    Write-Warning 'Pencil MCP is managed by the desktop app. Pass -PencilExecutablePath when a standalone Pencil executable is installed.'
  } else {
    Start-InteractiveApplication -ExecutablePath $PencilExecutablePath -WorkingDirectory $ProjectRoot
  }
}

Write-Host '[FitTracker env] ready.'
