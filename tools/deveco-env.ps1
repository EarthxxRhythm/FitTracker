param(
  [string]$DevEcoRoot = "C:\Program Files\Huawei\DevEco Studio"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Get-ExistingPathValue {
  $processPath = [System.Environment]::GetEnvironmentVariable('Path', 'Process')
  if (-not [string]::IsNullOrWhiteSpace($processPath)) {
    return $processPath
  }

  if (-not [string]::IsNullOrWhiteSpace($env:Path)) {
    return $env:Path
  }

  if (-not [string]::IsNullOrWhiteSpace($env:PATH)) {
    return $env:PATH
  }

  return ''
}

function Add-UniquePathSegments {
  param(
    [System.Collections.Generic.List[string]]$Segments,
    [System.Collections.Generic.HashSet[string]]$SeenSegments,
    [string[]]$CandidateSegments
  )

  for ($index = 0; $index -lt $CandidateSegments.Length; $index++) {
    $segment = $CandidateSegments[$index]
    if ([string]::IsNullOrWhiteSpace($segment)) {
      continue
    }
    if (-not (Test-Path $segment)) {
      continue
    }

    $normalizedSegment = [System.IO.Path]::GetFullPath($segment)
    if ($SeenSegments.Add($normalizedSegment)) {
      $Segments.Add($normalizedSegment) | Out-Null
    }
  }
}

$jbrPath = Join-Path $DevEcoRoot 'jbr'
$sdkPath = Join-Path $DevEcoRoot 'sdk'
$hvigorPath = Join-Path $DevEcoRoot 'tools\hvigor\bin'
$toolchainPath = Join-Path $sdkPath 'default\openharmony\toolchains'
$jbrBinPath = Join-Path $jbrPath 'bin'
$javaShimPath = Join-Path $scriptRoot 'java.cmd'
$nodeJavaShimPath = Join-Path $scriptRoot 'node-java-shim.cjs'
$javaExePath = Join-Path $jbrBinPath 'java.exe'
$javacExePath = Join-Path $jbrBinPath 'javac.exe'
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
if (-not (Test-Path $javaShimPath)) {
  throw ('FitTracker java.cmd shim not found: ' + $javaShimPath)
}
if (-not (Test-Path $nodeJavaShimPath)) {
  throw ('FitTracker node-java-shim.cjs not found: ' + $nodeJavaShimPath)
}
if (-not (Test-Path $hvigorwPath)) {
  throw ('DevEco Studio hvigorw.bat not found: ' + $hvigorwPath)
}

$env:JAVA_HOME = $jbrPath
$env:DEVECO_SDK_HOME = $sdkPath

$existingPathValue = Get-ExistingPathValue
$pathSegments = New-Object 'System.Collections.Generic.List[string]'
$seenSegments = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

Add-UniquePathSegments -Segments $pathSegments -SeenSegments $seenSegments -CandidateSegments @(
  $scriptRoot,
  $jbrBinPath,
  $hvigorPath,
  $toolchainPath
)

if (-not [string]::IsNullOrWhiteSpace($existingPathValue)) {
  Add-UniquePathSegments -Segments $pathSegments -SeenSegments $seenSegments -CandidateSegments ($existingPathValue -split ';')
}

$normalizedPath = [string]::Join(';', $pathSegments)
$env:Path = $normalizedPath
$env:PATH = $normalizedPath
$env:path = $normalizedPath
$env:FITTRACKER_JAVA_EXE = $javaExePath
$env:FITTRACKER_JAVAC_EXE = $javacExePath

$nodeRequirePath = $nodeJavaShimPath.Replace('\', '/')
$nodeRequireOption = '--require=' + $nodeRequirePath
$env:NODE_OPTS = $nodeRequireOption
if ([string]::IsNullOrWhiteSpace($env:NODE_OPTIONS)) {
  $env:NODE_OPTIONS = $nodeRequireOption
} elseif ($env:NODE_OPTIONS.IndexOf($nodeJavaShimPath) -lt 0) {
  $env:NODE_OPTIONS = $nodeRequireOption + ' ' + $env:NODE_OPTIONS
}

Write-Host '[FitTracker DevEco] Environment prepared.'
Write-Host ('- JAVA_HOME=' + $env:JAVA_HOME)
Write-Host ('- DEVECO_SDK_HOME=' + $env:DEVECO_SDK_HOME)
Write-Host ('- hvigorw=' + $hvigorwPath)
Write-Host ('- java shim=' + $javaShimPath)
Write-Host ('- node java shim=' + $nodeJavaShimPath)
Write-Host ('- java=' + $javaExePath)
