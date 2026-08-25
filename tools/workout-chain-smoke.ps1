param(
  [string]$DeviceId = '127.0.0.1:5555',
  [string]$BundleName = 'com.example.fittracker_opencode',
  [string]$AbilityName = 'EntryAbility',
  [string]$HapPath = 'entry/build/default/outputs/default/entry-default-unsigned.hap',
  [string]$RunRoot = '',
  [string]$RunTag = '',
  [string]$SummaryFileName = 'workout-chain-smoke-summary.md',
  [string]$TestPhone = '13800138000',
  [string]$TestPassword = '12345678',
  [int]$StepDelaySeconds = 2,
  [switch]$ResetAppData,
  [switch]$SkipInstall,
  [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptRoot = $PSScriptRoot
$HdcTargetsScriptPath = Join-Path $ScriptRoot 'hdc-targets.ps1'
if (-not (Test-Path $HdcTargetsScriptPath)) {
  throw ('Required script not found: ' + $HdcTargetsScriptPath)
}
. $HdcTargetsScriptPath

$DefaultRunBase = Join-Path $ScriptRoot '..\midscene_run\workout-chain'
if ([string]::IsNullOrWhiteSpace($RunTag)) {
  $RunTag = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-p' + $PID.ToString()
}
if ([string]::IsNullOrWhiteSpace($RunRoot)) {
  $RunRoot = Join-Path $DefaultRunBase $RunTag
}
$RunRoot = [System.IO.Path]::GetFullPath($RunRoot)
$SummaryPath = Join-Path $RunRoot $SummaryFileName
$RemoteTempRoot = '/data/local/tmp'
$Steps = New-Object System.Collections.Generic.List[string]

$TextStartUse = [string]([char]0x5F00) + [char]0x59CB + [char]0x4F7F + [char]0x7528
$TextRegisterNow = [string]([char]0x7ACB) + [char]0x5373 + [char]0x6CE8 + [char]0x518C
$TextNicknameHint = [string]([char]0x7ED9) + [char]0x81EA + [char]0x5DF1 + [char]0x8D77 + [char]0x4E2A + [char]0x540D + [char]0x5B57
$TestNickname = [string]([char]0x6797) + [char]0x9ED8
$TextRegisterPhoneHint = [string]([char]0x8BF7) + [char]0x8F93 + [char]0x5165 + [char]0x624B + [char]0x673A + [char]0x53F7
$TextLoginPhoneHint = [string]([char]0x8BF7) + [char]0x8F93 + [char]0x5165 + [char]0x624B + [char]0x673A + [char]0x53F7 + [char]0x6216 + [char]0x90AE + [char]0x7BB1
$TextLoginPasswordHint = [string]([char]0x8BF7) + [char]0x8F93 + [char]0x5165 + [char]0x5BC6 + [char]0x7801
$TextPasswordHint = [string]([char]0x5BC6) + [char]0x7801
$TextPasswordEightHint = [string]([char]0x8BBE) + [char]0x7F6E + [char]0x20 + [char]0x38 + [char]0x20 + [char]0x4F4D + [char]0x4EE5 + [char]0x4E0A + [char]0x5BC6 + [char]0x7801
$TextPasswordConfirmHint = [string]([char]0x518D) + [char]0x6B21 + [char]0x8F93 + [char]0x5165 + [char]0x5BC6 + [char]0x7801
$TextRegister = [string]([char]0x6CE8) + [char]0x518C
$TextLogin = [string]([char]0x767B) + [char]0x5F55
$TextGeneratePlan = [string]([char]0x751F) + [char]0x6210 + [char]0x8BAD + [char]0x7EC3 + [char]0x8BA1 + [char]0x5212
$TextStartTraining = [string]([char]0x5F00) + [char]0x59CB + [char]0x8BAD + [char]0x7EC3
$TextSubmit = [string]([char]0x63D0) + [char]0x4EA4
$TextCompleteSet = [string]([char]0x5B8C) + [char]0x6210 + [char]0x672C + [char]0x7EC4
$TextContinue = [string]([char]0x7EE7) + [char]0x7EED
$TextViewReview = [string]([char]0x67E5) + [char]0x770B + [char]0x8BAD + [char]0x7EC3 + [char]0x56DE + [char]0x987E

function Invoke-Hdc {
  param(
    [string]$Title,
    [string[]]$CommandArgs
  )

  Write-Host ('[FitTracker Workout Chain Smoke] ' + $Title)
  $fullArgs = @()
  if ($DeviceId.Length -gt 0) {
    $fullArgs += @('-t', $DeviceId)
  }
  $fullArgs += $CommandArgs
  $output = & hdc @fullArgs 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw ('HDC step failed: ' + $Title + '. ' + (@($output) -join ' '))
  }
  return (@($output) | ForEach-Object { $_.ToString() })
}

function New-RunDirectory {
  New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null
}

function Capture-Layout {
  param(
    [string]$Label,
    [int]$Attempt = 1
  )

  $remote = $RemoteTempRoot + '/fit_chain_' + $Label + '_' + $Attempt.ToString() + '.json'
  $local = Join-Path $RunRoot ($Label + '-layout-' + $Attempt.ToString() + '.json')
  Invoke-Hdc -Title 'dump layout' -CommandArgs @('shell', 'uitest', 'dumpLayout', '-p', $remote) | Out-Null
  Invoke-Hdc -Title 'pull layout' -CommandArgs @('file', 'recv', $remote, $local) | Out-Null
  return $local
}

function Capture-Screen {
  param([string]$Label)

  $remote = $RemoteTempRoot + '/fit_chain_' + $Label + '.jpeg'
  $local = Join-Path $RunRoot ($Label + '.jpeg')
  Invoke-Hdc -Title 'capture screen' -CommandArgs @('shell', 'snapshot_display', '-f', $remote) | Out-Null
  Invoke-Hdc -Title 'pull screen' -CommandArgs @('file', 'recv', $remote, $local) | Out-Null
  return $local
}

$LayoutTool = @'
const fs = require('fs');
const layoutPath = process.argv[1];
const mode = process.argv[2] || 'page';
const target = process.argv[3] || '';
const root = JSON.parse(fs.readFileSync(layoutPath, 'utf8'));
const nodes = [];
function walk(node) {
  if (node && node.attributes) {
    nodes.push(node.attributes);
  }
  if (node && Array.isArray(node.children)) {
    node.children.forEach(walk);
  }
}
walk(root);
const pageNode = nodes.find((item) => typeof item.pagePath === 'string' && item.pagePath.length > 0);
function center(bounds) {
  const match = /^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$/.exec(bounds || '');
  if (!match) {
    return null;
  }
  return {
    x: Math.floor((Number(match[1]) + Number(match[3])) / 2),
    y: Math.floor((Number(match[2]) + Number(match[4])) / 2)
  };
}
if (mode === 'page') {
  process.stdout.write(pageNode ? pageNode.pagePath : '');
  process.exit(0);
}
if (mode === 'text') {
  const exact = nodes.find((item) => item.text === target || item.originalText === target);
  const c = exact ? center(exact.bounds) : null;
  process.stdout.write(JSON.stringify({
    found: !!exact && !!c,
    x: c ? c.x : 0,
    y: c ? c.y : 0,
    pagePath: pageNode ? pageNode.pagePath : ''
  }));
  process.exit(0);
}
if (mode === 'hint') {
  const field = nodes.find((item) => item.type === 'TextInput' && (item.hint === target || item.text === target));
  const c = field ? center(field.bounds) : null;
  process.stdout.write(JSON.stringify({
    found: !!field && !!c,
    x: c ? c.x : 0,
    y: c ? c.y : 0,
    pagePath: pageNode ? pageNode.pagePath : ''
  }));
  process.exit(0);
}
if (mode === 'hasTabs') {
  const labels = ['\u9996\u9875', '\u8ba1\u5212', '\u56de\u987e', '\u6211\u7684'];
  const foundTabs = nodes.filter((item) => labels.indexOf(item.text) >= 0);
  process.stdout.write(JSON.stringify({ count: foundTabs.length, pagePath: pageNode ? pageNode.pagePath : '' }));
  process.exit(0);
}
process.stdout.write('{}');
'@

function Get-LayoutPagePath {
  param([string]$LayoutPath)
  $result = & node -e $LayoutTool $LayoutPath 'page'
  if ($LASTEXITCODE -ne 0) {
    throw 'Failed to read page path from layout.'
  }
  return (@($result) -join '').Trim()
}

function Get-CurrentPagePath {
  param([string]$Label)
  $layout = Capture-Layout -Label $Label
  return Get-LayoutPagePath -LayoutPath $layout
}

function Get-TextAction {
  param(
    [string]$LayoutPath,
    [string]$Text
  )
  $json = & node -e $LayoutTool $LayoutPath 'text' $Text
  if ($LASTEXITCODE -ne 0) {
    throw 'Failed to resolve text action.'
  }
  return ($json | ConvertFrom-Json)
}

function Get-HintAction {
  param(
    [string]$LayoutPath,
    [string]$Hint
  )
  $json = & node -e $LayoutTool $LayoutPath 'hint' $Hint
  if ($LASTEXITCODE -ne 0) {
    throw 'Failed to resolve text input.'
  }
  return ($json | ConvertFrom-Json)
}

function Has-BottomTabs {
  param([string]$LayoutPath)
  $json = & node -e $LayoutTool $LayoutPath 'hasTabs'
  return (($json | ConvertFrom-Json).count -gt 0)
}

function Assert-PagePath {
  param(
    [string]$Actual,
    [string]$Expected,
    [string]$Phase
  )
  if ($Actual -ne $Expected) {
    throw ($Phase + " expected page '" + $Expected + "' but got '" + $Actual + "'.")
  }
}

function Click-Text {
  param(
    [string]$Text,
    [string]$Phase,
    [int]$MaxAttempts = 4
  )

  for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    $layout = Capture-Layout -Label ($Phase + '-before-' + $attempt.ToString())
    $action = Get-TextAction -LayoutPath $layout -Text $Text
    if ($action.found) {
      Invoke-Hdc -Title ($Phase + ' click text') -CommandArgs @('shell', 'uitest', 'uiInput', 'click', $action.x.ToString(), $action.y.ToString()) | Out-Null
      Start-Sleep -Seconds $StepDelaySeconds
      return
    }

    Write-Host ('[FitTracker Workout Chain Smoke] text not found, retry: ' + $attempt.ToString())
    Invoke-Hdc -Title ($Phase + ' reveal') -CommandArgs @('shell', 'uitest', 'uiInput', 'swipe', '660', '2200', '660', '900', '1000') | Out-Null
    Start-Sleep -Seconds $StepDelaySeconds
  }

  throw ('Could not find target text in phase ' + $Phase)
}

function Input-TextByHint {
  param(
    [string]$Hint,
    [string]$Value,
    [string]$Phase
  )

  $action = $null
  for ($attempt = 1; $attempt -le 4; $attempt++) {
    $layout = Capture-Layout -Label ($Phase + '-' + $attempt.ToString())
    $action = Get-HintAction -LayoutPath $layout -Hint $Hint
    if ($action.found) {
      break
    }
    Invoke-Hdc -Title ($Phase + ' reveal input') -CommandArgs @('shell', 'uitest', 'uiInput', 'swipe', '660', '2200', '660', '900', '1000') | Out-Null
    Start-Sleep -Seconds $StepDelaySeconds
  }
  if ($null -eq $action -or -not $action.found) {
    throw ('Could not find input with hint/text: ' + $Hint)
  }
  Invoke-Hdc -Title ($Phase + ' focus input') -CommandArgs @('shell', 'uitest', 'uiInput', 'click', $action.x.ToString(), $action.y.ToString()) | Out-Null
  Start-Sleep -Milliseconds 400
  Invoke-Hdc -Title ($Phase + ' input text') -CommandArgs @('shell', 'uitest', 'uiInput', 'text', $Value) | Out-Null
  Start-Sleep -Milliseconds 400
}

function Start-App {
  Invoke-Hdc -Title 'force stop app' -CommandArgs @('shell', 'aa', 'force-stop', $BundleName) | Out-Null
  Start-Sleep -Seconds 1
  Invoke-Hdc -Title 'start app' -CommandArgs @('shell', 'aa', 'start', '-a', $AbilityName, '-b', $BundleName) | Out-Null
  Start-Sleep -Seconds $StepDelaySeconds
}

function Ensure-HdcReadyForChain {
  $raw = & hdc list targets -v
  if ($LASTEXITCODE -ne 0) {
    throw 'Failed to query HDC targets.'
  }
  $text = (@($raw) | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
  Wait-HdcTargetsReady -DeviceId $DeviceId -InitialRawOutput $text -MaxWaitSeconds 45 -PollSeconds 5 | Out-Null
}

function Reset-AppDataIfRequested {
  if (-not $ResetAppData) {
    return
  }
  Invoke-Hdc -Title 'clean app data' -CommandArgs @('shell', 'bm', 'clean', '-n', $BundleName, '-d', '-c', '-u', '0') | Out-Null
  Start-Sleep -Seconds 1
}

function Write-Summary {
  param(
    [string]$Status,
    [string]$FailureReason
  )

  New-RunDirectory
  $lines = @()
  $lines += '# FitTracker Workout Chain Smoke'
  $lines += ''
  $lines += '- date: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
  $lines += '- status: ' + $Status
  $lines += '- device id: ' + $DeviceId
  $lines += '- bundle: ' + $BundleName
  $lines += '- ability: ' + $AbilityName
  $lines += '- run root: ' + $RunRoot
  $lines += ''
  $lines += '## steps'
  if ($Steps.Count -eq 0) {
    $lines += '- none'
  } else {
    foreach ($step in $Steps) {
      $lines += '- ' + $step
    }
  }
  $lines += ''
  $lines += '## failure notes'
  if ([string]::IsNullOrWhiteSpace($FailureReason)) {
    $lines += '- none'
  } else {
    $lines += '- ' + $FailureReason
  }
  Set-Content -Path $SummaryPath -Value $lines -Encoding utf8
}

function Run-WorkoutChain {
  New-RunDirectory
  Ensure-HdcReadyForChain

  if ($CheckOnly) {
    if (-not $SkipInstall -and -not (Test-Path $HapPath)) {
      throw ('HAP not found: ' + $HapPath)
    }
    $Steps.Add('check-only passed') | Out-Null
    return
  }

  if (-not $SkipInstall) {
    if (-not (Test-Path $HapPath)) {
      throw ('HAP not found: ' + $HapPath)
    }
    Invoke-Hdc -Title 'install app HAP' -CommandArgs @('install', '-r', $HapPath) | Out-Null
  }

  Reset-AppDataIfRequested
  Start-App

  $page = Get-CurrentPagePath -Label 'welcome'
  $welcomeAttempts = 0
  while (($page -eq 'features/pencil/PencilSplashPage' -or $page.Length -eq 0) -and $welcomeAttempts -lt 6) {
    Start-Sleep -Seconds 1
    $welcomeAttempts += 1
    $page = Get-CurrentPagePath -Label ('welcome-wait-' + $welcomeAttempts.ToString())
  }
  Assert-PagePath -Actual $page -Expected 'features/welcome/pages/PencilWelcomePage' -Phase 'welcome'
  Capture-Screen -Label 'welcome'
  $Steps.Add('welcome -> login') | Out-Null
  Click-Text -Text $TextStartUse -Phase 'welcome-to-login'
  $page = Get-CurrentPagePath -Label 'login'
  Assert-PagePath -Actual $page -Expected 'features/pencil/PencilLoginPage' -Phase 'login'
  Capture-Screen -Label 'login'

  Click-Text -Text $TextRegisterNow -Phase 'login-to-register'
  $page = Get-CurrentPagePath -Label 'register'
  Assert-PagePath -Actual $page -Expected 'features/pencil/PencilRegisterPage' -Phase 'register'
  Capture-Screen -Label 'register'

  Input-TextByHint -Hint $TextNicknameHint -Value $TestNickname -Phase 'register-nickname'
  Input-TextByHint -Hint $TextRegisterPhoneHint -Value $TestPhone -Phase 'register-phone'
  Input-TextByHint -Hint $TextPasswordEightHint -Value $TestPassword -Phase 'register-password'
  Invoke-Hdc -Title 'hide keyboard after password' -CommandArgs @('shell', 'uitest', 'uiInput', 'keyEvent', 'Back') | Out-Null
  Start-Sleep -Seconds 1
  Input-TextByHint -Hint $TextPasswordConfirmHint -Value $TestPassword -Phase 'register-confirm'
  Invoke-Hdc -Title 'hide keyboard' -CommandArgs @('shell', 'uitest', 'uiInput', 'keyEvent', 'Back') | Out-Null
  Start-Sleep -Seconds 1
  Click-Text -Text $TextRegister -Phase 'register-submit'
  $page = Get-CurrentPagePath -Label 'login-after-register'
  Assert-PagePath -Actual $page -Expected 'features/pencil/PencilLoginPage' -Phase 'login-after-register'

  Input-TextByHint -Hint $TextLoginPhoneHint -Value $TestPhone -Phase 'login-phone'
  Input-TextByHint -Hint $TextLoginPasswordHint -Value $TestPassword -Phase 'login-password'
  Invoke-Hdc -Title 'hide login keyboard' -CommandArgs @('shell', 'uitest', 'uiInput', 'keyEvent', 'Back') | Out-Null
  Start-Sleep -Seconds 1
  Click-Text -Text $TextLogin -Phase 'login-submit'
  Start-Sleep -Seconds ($StepDelaySeconds + 1)
  $page = Get-CurrentPagePath -Label 'after-login'
  if ($page -eq 'features/onboarding/pages/GoalSetupPage') {
    Capture-Screen -Label 'goal-setup'
    Click-Text -Text $TextGeneratePlan -Phase 'goal-save'
    $page = Get-CurrentPagePath -Label 'app-shell-after-goal'
    Assert-PagePath -Actual $page -Expected 'app/PencilAppShell' -Phase 'goal-to-app-shell'
  } elseif ($page -ne 'app/PencilAppShell') {
    throw ('Unexpected page after login: ' + $page)
  }
  Capture-Screen -Label 'home'

  Click-Text -Text $TextStartTraining -Phase 'home-to-preview'
  $page = Get-CurrentPagePath -Label 'preview'
  Assert-PagePath -Actual $page -Expected 'features/pencil/PencilPreviewPage' -Phase 'home-to-preview'
  Capture-Screen -Label 'preview'

  Click-Text -Text $TextStartTraining -Phase 'preview-to-active'
  $page = Get-CurrentPagePath -Label 'active'
  Assert-PagePath -Actual $page -Expected 'features/pencil/PencilActivePage' -Phase 'preview-to-active'
  $activeLayout = Capture-Layout -Label 'active'
  if (Has-BottomTabs -LayoutPath $activeLayout) {
    throw 'Bottom navigation tabs are visible on the standalone active workout page.'
  }
  Capture-Screen -Label 'active'

  for ($setIndex = 1; $setIndex -le 6; $setIndex++) {
    $clickPhase = 'active-set-' + $setIndex.ToString()
    Click-Text -Text $TextSubmit -Phase $clickPhase
    Click-Text -Text $TextCompleteSet -Phase ($clickPhase + '-complete')
    if ($setIndex -lt 6) {
      $page = Get-CurrentPagePath -Label ($clickPhase + '-still-active')
      if ($page -ne 'features/pencil/PencilActivePage') {
        throw ('Unexpected page after set ' + $setIndex.ToString() + ': ' + $page)
      }
    }
  }
  Start-Sleep -Seconds 1
  $page = Get-CurrentPagePath -Label 'complete'
  Assert-PagePath -Actual $page -Expected 'features/workout/pages/WorkoutCompletePage' -Phase 'active-to-complete'
  Capture-Screen -Label 'complete'

  Click-Text -Text $TextContinue -Phase 'complete-to-home'
  $page = Get-CurrentPagePath -Label 'home-after-complete'
  Assert-PagePath -Actual $page -Expected 'app/PencilAppShell' -Phase 'complete-to-home'
  Capture-Screen -Label 'home-after-complete'
  $Steps.Add('workout chain passed') | Out-Null
}

try {
  Run-WorkoutChain
  Write-Summary -Status 'passed' -FailureReason ''
  Write-Host ''
  Write-Host ('[FitTracker Workout Chain Smoke] summary: ' + $SummaryPath)
} catch {
  Write-Summary -Status 'failed' -FailureReason $_.Exception.Message
  throw
}
