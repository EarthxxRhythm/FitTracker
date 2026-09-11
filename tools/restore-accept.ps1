# restore-accept.ps1 — 单屏验收：渲染参照帧 -> (可选装HAP) -> seed启动 -> 截图 -> crop对比
# 用法：
#   powershell -ExecutionPolicy Bypass -File tools/restore-accept.ps1 `
#     -Html design/06_prototype_redraw/src/fittracker-welcome-home.html `
#     -FrameIndex 1 -Name home -Seed today_flow -Crop 100,740 [-SkipInstall] [-IgnoreRect "620,250,760,330"]
param(
  [string]$Html = '',
  [int]$FrameIndex = 0,
  [string]$Name = 'screen',
  [string]$Seed = 'today_flow',
  [string]$Crop = '100,740',
  [string]$IgnoreRect = '',
  [string]$RunRoot = 'test_run/restore-accept',
  [string]$DeviceId = '127.0.0.1:5555',
  [switch]$SkipInstall
)
$ErrorActionPreference = 'Stop'
$Hdc = 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
if (!(Test-Path $Hdc)) { throw "hdc not found: $Hdc" }
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root
$Hap = 'entry/build/default/outputs/default/entry-default-unsigned.hap'
$Bundle = 'com.example.fittracker_opencode'
$Ability = 'EntryAbility'
$Proto = Join-Path $RunRoot ($Name + '-proto.png')
$ShotRaw = Join-Path $RunRoot ($Name + '-device.jpeg')
$Report = Join-Path $RunRoot ($Name + '-accept.md')
New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null

if (-not $Html) { $Html = "design/06_prototype_redraw/src/fittracker-$Name.html" }
if (-not (Test-Path $Html)) { throw "html not found: $Html" }

Write-Host "[1/4] render prototype frame $FrameIndex <- $Html"
python tools/visual-diff/render-prototype.py $Html $Proto --screen $FrameIndex
if ($LASTEXITCODE -ne 0) { throw 'render failed' }

if (-not $SkipInstall) {
  if (-not (Test-Path $Hap)) { throw "hap missing: $Hap (先 assembleHap)" }
  Write-Host '[2/4] install HAP'
  & $Hdc install $Hap 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'install failed' }
}

Write-Host '[3/4] seed launch -> screenshot'
& $Hdc shell aa force-stop $Bundle 2>&1 | Out-Null
Start-Sleep -Seconds 1
& $Hdc shell aa start -a $Ability -b $Bundle --ps devSeed $Seed 2>&1 | Out-Null
Start-Sleep -Seconds 9
& $Hdc shell snapshot_display -f /data/local/tmp/restore-accept.jpeg 2>&1 | Out-Null
& $Hdc file recv /data/local/tmp/restore-accept.jpeg $ShotRaw 2>&1 | Out-Null
if (-not (Test-Path $ShotRaw)) { throw 'screenshot recv failed' }

Write-Host "[4/4] compare (crop=$Crop)"
$args = @($Proto, $ShotRaw, '--out', $Report, '--crop', $Crop)
if ($IgnoreRect) { $args += @('--ignore-rect', $IgnoreRect) }
python tools/visual-diff/compare.py @args
if ($LASTEXITCODE -ne 0) { throw 'compare failed' }
Write-Host "report: $Report"
