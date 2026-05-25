param(
  [string]$DeviceId = "",
  [string]$BundleName = "com.example.fittracker",
  [string]$AbilityName = "EntryAbility",
  [string]$HapPath = "entry/build/default/outputs/default/entry-default-unsigned.hap",
  [switch]$SkipInstall
)

$ErrorActionPreference = "Stop"

function Invoke-Step {
  param(
    [string]$Title,
    [string[]]$Command
  )

  Write-Host ""
  Write-Host "[FitTracker Midscene] $Title"
  & $Command[0] @($Command | Select-Object -Skip 1)
  if ($LASTEXITCODE -ne 0) {
    throw "Step failed: $Title"
  }
}

function Invoke-Midscene {
  param(
    [string[]]$Args
  )

  $fullArgs = @("-y", "@midscene/harmony@1") + $Args
  if ($DeviceId.Length -gt 0) {
    $fullArgs += @("--deviceId", $DeviceId)
  }
  Invoke-Step -Title ("midscene " + ($Args -join " ")) -Command (@("npx.cmd") + $fullArgs)
}

if ($env:MIDSCENE_MODEL_API_KEY.Length -eq 0 -or
  $env:MIDSCENE_MODEL_NAME.Length -eq 0 -or
  $env:MIDSCENE_MODEL_BASE_URL.Length -eq 0 -or
  $env:MIDSCENE_MODEL_FAMILY.Length -eq 0) {
  throw "Missing Midscene model environment variables. Set MIDSCENE_MODEL_API_KEY, MIDSCENE_MODEL_NAME, MIDSCENE_MODEL_BASE_URL and MIDSCENE_MODEL_FAMILY, or create a local .env file."
}

Invoke-Step -Title "check hdc targets" -Command @("hdc", "list", "targets")

if (-not $SkipInstall) {
  if (-not (Test-Path $HapPath)) {
    throw "HAP not found: $HapPath. Build entry@default before running this script."
  }
  Invoke-Step -Title "install app HAP" -Command @("hdc", "install", "-r", $HapPath)
}

Invoke-Step -Title "launch app" -Command @("hdc", "shell", "aa", "start", "-a", $AbilityName, "-b", $BundleName)
Invoke-Midscene -Args @("connect")
Invoke-Midscene -Args @("take_screenshot")

Invoke-Midscene -Args @(
  "act",
  "--prompt",
  "从当前 FitTracker 页面开始完成真实训练闭环：如果看到目标设置页，选择增肌、初学者、每周 3 天、徒手器械并保存；进入首页后打开今日训练，进入训练预览，开始训练，在训练执行页录入第一组重量 60 和次数 10，结束训练进入复盘，再进入回顾页，找到调整目标入口并执行一次目标调整或重新生成计划。"
)

Invoke-Midscene -Args @(
  "assert",
  "--prompt",
  "屏幕显示 FitTracker 的训练回顾、目标调整结果、首页、或目标设置页之一，且没有崩溃弹窗。"
)

Invoke-Step -Title "restart app for session routing check" -Command @("hdc", "shell", "aa", "start", "-a", $AbilityName, "-b", $BundleName)
Invoke-Midscene -Args @("take_screenshot")
Invoke-Midscene -Args @(
  "assert",
  "--prompt",
  "应用重新打开后显示首页或目标设置页，页面没有空白和崩溃弹窗。"
)

Invoke-Midscene -Args @(
  "act",
  "--prompt",
  "如果当前页面提供注册、登录或个人入口，则完成一次本地注册和登录；如果没有认证入口，则确认当前页面可继续进入首页或目标设置主流程。"
)

Invoke-Midscene -Args @(
  "assert",
  "--prompt",
  "屏幕仍处于 FitTracker 应用内，并显示首页、目标设置、训练入口、登录成功后的页面或可继续操作的主流程页面。"
)

Invoke-Midscene -Args @("disconnect")

Write-Host ""
Write-Host "[FitTracker Midscene] Regression finished. Review generated files under midscene_run/."
