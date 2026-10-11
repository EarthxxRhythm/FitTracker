param(
  [Parameter(Mandatory = $true)][string]$Name,
  [string]$Action = "settled",
  [int]$TapX = -1,
  [int]$TapY = -1,
  [int]$DelayMs = 0
)

# Captures the current emulator screen. Coordinates are DEVICE pixels (native resolution).
# - Action "settled": plain screenshot.
# - Action "press": hold a press by tapping, wait DelayMs, then screenshot (press feedback).
# - Action "mid": tap, wait DelayMs (about half the animation duration), then screenshot.
$ErrorActionPreference = "Stop"
$hdc = "C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$outDir = Join-Path $root "test_run\device-motion"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$deviceFile = "/data/local/tmp/motion-$Name.jpeg"
$localFile = Join-Path $outDir "$Name.jpeg"

if (($Action -ne "settled") -and ($TapX -ge 0) -and ($TapY -ge 0)) {
  & $hdc shell "uitest uiInput click $TapX $TapY" | Out-Null
  if ($DelayMs -gt 0) {
    Start-Sleep -Milliseconds $DelayMs
  }
}

& $hdc shell "snapshot_display -f $deviceFile" | Out-Null
& $hdc file recv $deviceFile $localFile | Out-Null
Write-Output ("saved {0} ({1} bytes)" -f $localFile, (Get-Item $localFile).Length)
