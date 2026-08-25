# Capture the running app's screen from the HarmonyOS emulator as a PNG.
#
# Usage:  .\capture-screenshot.ps1 -Out <out.png>
#
# Flow: hdc snapshot_display (this firmware accepts ONLY a `.jpeg` suffix)
#   -> hdc file recv the .jpeg locally
#   -> convert .jpeg -> .png via Python/Pillow (PowerShell has no native PNG encoder).
param(
    [Parameter(Mandatory = $true)][string]$Out
)

$ErrorActionPreference = 'Stop'

$hdc = "C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"
if (-not (Test-Path -LiteralPath $hdc)) {
    Write-Error "hdc.exe not found at: $hdc"
    exit 1
}

$remote = "/data/local/tmp/visual-diff.jpeg"
$localTmp = Join-Path $env:TEMP ("visual-diff-capture-" + [System.Guid]::NewGuid().ToString('N') + ".jpeg")

# 1. Snapshot on device (firmware requires .jpeg suffix).
& $hdc shell "snapshot_display -f $remote" | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "hdc snapshot_display failed (exit $LASTEXITCODE)"
    exit 1
}

# 2. Pull the file back.
& $hdc file recv $remote $localTmp | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "hdc file recv failed (exit $LASTEXITCODE)"
    exit 1
}

# 3. Convert .jpeg -> .png via Pillow.
$pyScript = Join-Path $env:TEMP "visual-diff-convert.py"
@'
import sys
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
img = Image.open(src)
img.save(dst, 'PNG')
print('converted', img.size, '->', dst)
'@ | Set-Content -Path $pyScript -Encoding UTF8

& python $pyScript $localTmp $Out
if ($LASTEXITCODE -ne 0) {
    Write-Error "python convert failed (exit $LASTEXITCODE)"
    exit 1
}

Remove-Item -LiteralPath $localTmp -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $pyScript -ErrorAction SilentlyContinue

Write-Host "Captured: $Out"
