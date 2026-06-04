param(
  [string]$DevEcoRoot = "C:\Program Files\Huawei\DevEco Studio"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Add-PathSegment {
  param([string]$Segment)

  if ([string]::IsNullOrWhiteSpace($Segment)) {
    return
  }
  if (-not (Test-Path $Segment)) {
    return
  }

  $currentSegments = @($env:PATH -split ';')
  if ($currentSegments -contains $Segment) {
    return
  }
  $env:PATH = $Segment + ';' + $env:PATH
}

$jbrPath = Join-Path $DevEcoRoot 'jbr'
$sdkPath = Join-Path $DevEcoRoot 'sdk'
$hvigorPath = Join-Path $DevEcoRoot 'tools\hvigor\bin'
$toolchainPath = Join-Path $sdkPath 'default\openharmony\toolchains'
$jbrBinPath = Join-Path $jbrPath 'bin'
$javaExePath = Join-Path $jbrBinPath 'java.exe'
$hvigorwPath = Join-Path $hvigorPath 'hvigorw.bat'

if (-not (Test-Path $jbrPath)) {
  throw ('DevEco Studio JBR not found: ' + $jbrPath)
}
if (-not (Test-Path $sdkPath)) {
  throw ('DevEco Studio SDK not found: ' + $sdkPath)
}
if (-not (Test-Path $javaExePath)) {
  throw ('DevEco Studio java.exe not found: ' + $javaExePath)
}
if (-not (Test-Path $hvigorwPath)) {
  throw ('DevEco Studio hvigorw.bat not found: ' + $hvigorwPath)
}

$env:JAVA_HOME = $jbrPath
$env:DEVECO_SDK_HOME = $sdkPath

Add-PathSegment -Segment $jbrBinPath
Add-PathSegment -Segment $hvigorPath
Add-PathSegment -Segment $toolchainPath

Write-Host '[FitTracker DevEco] Environment prepared.'
Write-Host ('- JAVA_HOME=' + $env:JAVA_HOME)
Write-Host ('- DEVECO_SDK_HOME=' + $env:DEVECO_SDK_HOME)
Write-Host ('- hvigorw=' + $hvigorwPath)
Write-Host ('- java=' + $javaExePath)
