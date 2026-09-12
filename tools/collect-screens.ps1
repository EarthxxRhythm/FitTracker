# collect-screens.ps1 — 批量采集视觉验收数据
#
# 动机：逐屏手工命令序列（snapshot_display → ui layout → genmask → compare×N）高度同构，
#       是模型推理退化的诱因之一（"sustained short-phrase repetition"）。
#       收敛为单脚本后，一次执行完成全部屏的采集、align 扫描与汇总。
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File tools/collect-screens.ps1
#   powershell -ExecutionPolicy Bypass -File tools/collect-screens.ps1 -Screens plan,review,profile -SkipBuild
#
# 输出：test_run/collect/<屏>.jpeg、<屏>-ui.txt、<屏>-a<align>.md、<屏>-align-scan.txt
#       以及 test_run/collect/SUMMARY.md
param(
  [string[]]$Screens = @('home', 'preview', 'plan', 'review', 'profile', 'settings', 'body', 'library', 'active'),
  [string]$Device    = '127.0.0.1:5555',
  [string]$Bundle    = 'com.earthrhythm.fittracker',
  [string]$Ability   = 'EntryAbility',
  [string]$Seed      = 'demo_data',
  [string]$ProtoRoot = 'design/06_prototype_redraw/src',
  [string]$OutRoot   = 'test_run/collect',
  [int[]]$Aligns     = @(0, 20, 35, 45),
  [switch]$SkipBuild
)
$ErrorActionPreference = 'Stop'
$Hdc  = 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root
New-Item -ItemType Directory -Force -Path $OutRoot | Out-Null

# 底部 tab 中心坐标（设备 1320x2856）。布局变动后需用 `devecocli ui layout` 重新校准。
$TabHome    = @(164, 2640)
$TabPlan    = @(412, 2640)
$TabReview  = @(907, 2640)
$TabProfile = @(1155, 2640)

# 屏 → 原型文件 / frame 序号 / 导航点击序列（序列基于 seed 启动后落在首页这一前提）
$Nav = @{
  home     = @{ Html = "$ProtoRoot/fittracker-welcome-home.html";     Frame = 1; Clicks = @() }
  preview  = @{ Html = "$ProtoRoot/fittracker-training-preview.html"; Frame = 0; Clicks = @($TabHome, @(660, 1789)) }
  active   = @{ Html = "$ProtoRoot/fittracker-training.html";         Frame = 0; Clicks = @($TabHome, @(660, 1789), @(660, 1811)) }
  plan     = @{ Html = "$ProtoRoot/fittracker-plan.html";             Frame = 0; Clicks = @($TabPlan) }
  review   = @{ Html = "$ProtoRoot/fittracker-review.html";           Frame = 0; Clicks = @($TabReview) }
  profile  = @{ Html = "$ProtoRoot/fittracker-personal.html";         Frame = 0; Clicks = @($TabProfile) }
  settings = @{ Html = "$ProtoRoot/fittracker-settings.html";         Frame = 0; Clicks = @($TabProfile, @(1191, 399)) }
  body     = @{ Html = "$ProtoRoot/fittracker-body-data.html";        Frame = 0; Clicks = @($TabProfile, @(350, 2446)) }
  library  = @{ Html = "$ProtoRoot/fittracker-exercise-library.html"; Frame = 0; Clicks = @($TabProfile, @(970, 2446)) }
}

if (-not $SkipBuild) {
  Write-Host '[build] devecocli build --product default'
  devecocli build --product default | Select-Object -Last 2
  & $Hdc install entry/build/default/outputs/default/entry-default-signed.hap | Out-Null
}

$rows = @()
foreach ($name in $Screens) {
  $spec = $Nav[$name]
  if ($null -eq $spec) { Write-Warning "未登记的屏：$name（跳过）"; continue }

  Write-Host "[$name] seed=$Seed 启动 → 导航"
  & $Hdc shell "aa force-stop $Bundle" | Out-Null
  Start-Sleep -Seconds 1
  & $Hdc shell "aa start -a $Ability -b $Bundle --ps devSeed $Seed" | Out-Null
  Start-Sleep -Seconds 13
  foreach ($c in $spec.Clicks) {
    devecocli ui click $c[0] $c[1] | Out-Null
    Start-Sleep -Seconds 2
  }

  $shot = Join-Path $OutRoot "$name.jpeg"
  $dump = Join-Path $OutRoot "$name-ui.txt"
  & $Hdc shell "snapshot_display -f /data/local/tmp/cs-$name.jpeg" | Out-Null
  & $Hdc file recv "/data/local/tmp/cs-$name.jpeg" $shot | Out-Null
  devecocli ui layout --mode simplified > $dump 2>&1

  $proto = Join-Path $OutRoot "$name-proto.png"
  python tools/visual-diff/render-prototype.py $spec.Html $proto --screen $spec.Frame | Out-Null

  # 掩码按物理对齐 35vp 生成（genmask 的第二个参数）
  $maskArgs = @(((python test_run/genmask.py $dump 35) -join ' ') -split ' ')

  $best = $null; $bestPct = 999.0; $lines = @()
  foreach ($a in $Aligns) {
    $rep = Join-Path $OutRoot "$name-a$a.md"
    python tools/visual-diff/compare.py $proto $shot --crop 100,740 --align-y $a $maskArgs --out $rep | Out-Null
    $hit = Select-String -Path $rep -Pattern 'threshold: \*\*([0-9.]+) %' | Select-Object -First 1
    if ($hit) {
      $pct = [double]$hit.Matches[0].Groups[1].Value
      $lines += "align=$a -> $pct%"
      if ($pct -lt $bestPct) { $bestPct = $pct; $best = $a }
    }
  }
  $lines | Out-File (Join-Path $OutRoot "$name-align-scan.txt")
  $verdict = if ($bestPct -le 8) { 'PASS' } else { 'FAIL' }
  $rows += [pscustomobject]@{ Screen = $name; BestAlign = $best; BestPct = $bestPct; Verdict = $verdict }
  Write-Host "[$name] best align=$best -> $bestPct% ($verdict)"
}

$summary = Join-Path $OutRoot 'SUMMARY.md'
'# 批量采集汇总' | Out-File $summary
'' | Out-File -Append $summary
'| 屏 | 最优 align | 超阈% | 判定 |' | Out-File -Append $summary
'|---|---|---|---|' | Out-File -Append $summary
foreach ($r in $rows) {
  "| $($r.Screen) | $($r.BestAlign) | $($r.BestPct)% | $($r.Verdict) |" | Out-File -Append $summary
}
Write-Host "汇总：$summary"
