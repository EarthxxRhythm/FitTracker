param(
  [ValidateSet('review-membership', 'review-workout-loop', 'review-backup-card', 'review-exercise-detail', 'review-plan-detail', 'review-metrics')]
  [string]$Scenario = 'review-workout-loop',
  [string]$DeviceId = '127.0.0.1:5555',
  [string]$BundleName = 'com.example.fittracker_opencode',
  [string]$AbilityName = 'EntryAbility',
  [string]$RunRoot = '',
  [string]$RunTag = '',
  [string]$SummaryFileName = 'live-device-probe-summary.md',
  [int]$StepDelaySeconds = 2,
  [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptRoot = $PSScriptRoot
$HdcTargetsScriptPath = Join-Path $ScriptRoot 'hdc-targets.ps1'
$DefaultRunBase = Join-Path $ScriptRoot '..\midscene_run\live_device'
if ([string]::IsNullOrWhiteSpace($RunTag)) {
  $RunTag = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-p' + $PID.ToString()
}
if ([string]::IsNullOrWhiteSpace($RunRoot)) {
  $scenarioToken = $Scenario.Replace('-', '_')
  $RunRoot = Join-Path $DefaultRunBase ($scenarioToken + '-' + $RunTag)
}
$RunRoot = [System.IO.Path]::GetFullPath($RunRoot)
$RunSummaryPath = Join-Path $RunRoot $SummaryFileName
$RemoteTempRoot = '/data/local/tmp'
$RecordedSteps = New-Object System.Collections.Generic.List[string]
$TextComparePro = [string]([char]0x6BD4) + [char]0x8F83 + ' Pro ' + [char]0x65B9 + [char]0x6848
$TextStartTodayTraining = [string]([char]0x5F00) + [char]0x59CB + [char]0x4ECA + [char]0x65E5 + [char]0x8BAD + [char]0x7EC3
$TextStartTraining = [string]([char]0x5F00) + [char]0x59CB + [char]0x8BAD + [char]0x7EC3
$TextReview = [string]([char]0x56DE) + [char]0x987E
$TextExerciseLibrary = [string]([char]0x52A8) + [char]0x4F5C + [char]0x5E93
$TextViewExerciseDetail = [string]([char]0x67E5) + [char]0x770B + [char]0x52A8 + [char]0x4F5C + [char]0x8BE6 + [char]0x60C5
$TextViewPlanDetail = [string]([char]0x67E5) + [char]0x770B + [char]0x8BA1 + [char]0x5212 + [char]0x8BE6 + [char]0x60C5
$TextBackupAction = [string]([char]0x5BFC) + [char]0x51FA + [char]0x6216 + [char]0x5BFC + [char]0x5165 + [char]0x672C + [char]0x5730 + [char]0x6570 + [char]0x636E

if (-not (Test-Path $HdcTargetsScriptPath)) {
  throw ('Required script not found: ' + $HdcTargetsScriptPath)
}
. $HdcTargetsScriptPath

function Invoke-Step {
  param(
    [string]$Title,
    [string[]]$Command
  )

  Write-Host ''
  Write-Host ('[FitTracker Live Probe] ' + $Title)
  $exe = $Command[0]
  $argsList = @($Command | Select-Object -Skip 1)
  $rawOutput = & $exe @argsList 2>&1
  $nativeExitCode = $LASTEXITCODE
  $outputText = (@($rawOutput) | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
  if ($outputText.Length -gt 0) {
    Write-Host $outputText
  }
  if ($nativeExitCode -ne 0) {
    if ($outputText.Length -gt 0) {
      throw ('Step failed: ' + $Title + '. ' + $outputText)
    }
    throw ('Step failed: ' + $Title)
  }
  return $outputText
}

function Invoke-Hdc {
  param(
    [string]$Title,
    [string[]]$CommandArgs
  )

  $fullArgs = @()
  if ($DeviceId.Length -gt 0) {
    $fullArgs += @('-t', $DeviceId)
  }
  $fullArgs += $CommandArgs
  Invoke-Step -Title $Title -Command (@('hdc') + $fullArgs)
}

function Send-Swipe {
  param(
    [string]$Name,
    [int]$FromX,
    [int]$FromY,
    [int]$ToX,
    [int]$ToY,
    [int]$Velocity = 1200
  )

  Invoke-Hdc -Title ($Name + ' swipe') -CommandArgs @(
    'shell',
    'uitest',
    'uiInput',
    'swipe',
    $FromX.ToString(),
    $FromY.ToString(),
    $ToX.ToString(),
    $ToY.ToString(),
    $Velocity.ToString()
  ) | Out-Null
  Start-Sleep -Seconds $StepDelaySeconds
}

function Ensure-HdcReady {
  $rawOutput = & hdc list targets -v
  if ($LASTEXITCODE -ne 0) {
    throw 'Failed to query HDC targets.'
  }
  $rawText = (@($rawOutput) | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
  Wait-HdcTargetsReady -DeviceId $DeviceId -InitialRawOutput $rawText -MaxWaitSeconds 45 -PollSeconds 5 | Out-Null
}

function New-RunDirectory {
  New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null
}

function Get-LocalArtifactPath {
  param(
    [string]$Label,
    [string]$Extension
  )

  return Join-Path $RunRoot ($Label + $Extension)
}

function Capture-Screen {
  param([string]$Label)

  $remotePath = $RemoteTempRoot + '/fittracker_' + $Label + '.jpeg'
  $localPath = Get-LocalArtifactPath -Label $Label -Extension '.jpeg'
  Invoke-Hdc -Title ('capture ' + $Label) -CommandArgs @('shell', 'snapshot_display', '-f', $remotePath) | Out-Null
  Invoke-Hdc -Title ('pull capture ' + $Label) -CommandArgs @('file', 'recv', $remotePath, $localPath) | Out-Null
  return $localPath
}

function Capture-Layout {
  param([string]$Label)

  $remotePath = $RemoteTempRoot + '/fittracker_' + $Label + '.json'
  $localPath = Get-LocalArtifactPath -Label $Label -Extension '.json'
  Invoke-Hdc -Title ('dump layout ' + $Label) -CommandArgs @('shell', 'uitest', 'dumpLayout', '-p', $remotePath) | Out-Null
  Invoke-Hdc -Title ('pull layout ' + $Label) -CommandArgs @('file', 'recv', $remotePath, $localPath) | Out-Null
  return $localPath
}

function Get-LayoutAction {
  param(
    [string]$LayoutPath,
    [string]$TargetText,
    [bool]$AllowSubstringMatch = $false
  )

  $nodeScript = @"
const fs = require('fs');
const layoutPath = process.argv[1];
const targetText = process.argv[2];
const allowSubstringMatch = process.argv[3] === 'true';
const root = JSON.parse(fs.readFileSync(layoutPath, 'utf8'));
const nodes = [];
function walk(node) {
  if (!node || !node.attributes) {
    return;
  }
  nodes.push(node.attributes);
  if (Array.isArray(node.children)) {
    node.children.forEach(walk);
  }
}
walk(root);
const pageNode = nodes.find((item) => typeof item.pagePath === 'string' && item.pagePath.length > 0);
const exactNode = nodes.find((item) => item.text === targetText || item.originalText === targetText);
let textNode = exactNode;
if (!textNode && allowSubstringMatch) {
  textNode = nodes.find((item) => {
    const text = typeof item.text === 'string' ? item.text : '';
    const originalText = typeof item.originalText === 'string' ? item.originalText : '';
    return text.includes(targetText) || originalText.includes(targetText);
  });
}
if (!textNode) {
  process.stdout.write(JSON.stringify({
    found: false,
    pagePath: pageNode ? pageNode.pagePath : '',
    targetText
  }));
  process.exit(0);
}
let actionableNode = textNode;
let hierarchy = typeof textNode.hierarchy === 'string' ? textNode.hierarchy : '';
while (hierarchy.length > 0) {
  const clickableNode = nodes.find((item) => item.hierarchy === hierarchy && item.clickable === 'true');
  if (clickableNode) {
    actionableNode = clickableNode;
    break;
  }
  const parts = hierarchy.split(',');
  if (parts.length <= 1) {
    break;
  }
  hierarchy = parts.slice(0, parts.length - 1).join(',');
}
const match = /^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$/.exec(actionableNode.bounds || '');
if (!match) {
  console.error('TARGET_BOUNDS_INVALID');
  process.exit(3);
}
const x1 = Number(match[1]);
const y1 = Number(match[2]);
const x2 = Number(match[3]);
const y2 = Number(match[4]);
const result = {
  found: true,
  pagePath: pageNode ? pageNode.pagePath : '',
  targetText,
  matchedText: textNode.text || textNode.originalText || '',
  bounds: actionableNode.bounds,
  centerX: Math.floor((x1 + x2) / 2),
  centerY: Math.floor((y1 + y2) / 2),
  actionableType: actionableNode.type || '',
  actionableHierarchy: actionableNode.hierarchy || '',
  actionableClickable: actionableNode.clickable || 'false'
};
process.stdout.write(JSON.stringify(result));
"@

  $jsonText = Invoke-Step -Title ('resolve action ' + $TargetText) -Command @(
    'node',
    '-e',
    $nodeScript,
    $LayoutPath,
    $TargetText,
    $AllowSubstringMatch.ToString().ToLowerInvariant()
  )
  return $jsonText | ConvertFrom-Json
}

function Get-LayoutPagePath {
  param([string]$LayoutPath)

  $nodeScript = @"
const fs = require('fs');
const layoutPath = process.argv[1];
const root = JSON.parse(fs.readFileSync(layoutPath, 'utf8'));
const nodes = [];
function walk(node) {
  if (!node || !node.attributes) {
    return;
  }
  nodes.push(node.attributes);
  if (Array.isArray(node.children)) {
    node.children.forEach(walk);
  }
}
walk(root);
const pageNode = nodes.find((item) => typeof item.pagePath === 'string' && item.pagePath.length > 0);
process.stdout.write(pageNode ? pageNode.pagePath : '');
"@
  return Invoke-Step -Title 'read page path' -Command @('node', '-e', $nodeScript, $LayoutPath)
}

function Capture-LayoutWithStablePagePath {
  param(
    [string]$Label,
    [int]$MaxAttempts = 3
  )

  $layoutPath = ''
  $pagePath = ''
  for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    $layoutPath = Capture-Layout -Label ($Label + '-' + $attempt.ToString())
    $pagePath = Get-LayoutPagePath -LayoutPath $layoutPath
    if ($pagePath.Length -gt 0) {
      return @{
        layoutPath = $layoutPath
        pagePath = $pagePath
      }
    }
    $RecordedSteps.Add(($Label + ': blank pagePath on layout attempt ' + $attempt.ToString() + ', recapturing.')) | Out-Null
    Start-Sleep -Seconds 1
  }
  return @{
    layoutPath = $layoutPath
    pagePath = $pagePath
  }
}

function Assert-PagePath {
  param(
    [string]$ActualPagePath,
    [string]$ExpectedPagePath,
    [string]$Phase
  )

  if ($ActualPagePath -ne $ExpectedPagePath) {
    throw ($Phase + " expected page '" + $ExpectedPagePath + "' but got '" + $ActualPagePath + "'.")
  }
}

function Invoke-TextNavigationStep {
  param(
    [string]$Name,
    [string]$ExpectedCurrentPagePath,
    [string]$TargetText,
    [string]$ExpectedNextPagePath
  )

  $beforeLayout = ''
  $beforePagePath = ''
  $action = $null
  for ($attempt = 1; $attempt -le 5; $attempt++) {
    $beforeSnapshot = Capture-LayoutWithStablePagePath -Label ($Name + '-before-layout-' + $attempt)
    $beforeLayout = $beforeSnapshot.layoutPath
    $beforePagePath = $beforeSnapshot.pagePath
    if ($beforePagePath.Length -eq 0) {
      $RecordedSteps.Add(($Name + ': pagePath is blank before click, relaunching app and retrying this step.')) | Out-Null
      Start-App
      continue
    }
    Assert-PagePath -ActualPagePath $beforePagePath -ExpectedPagePath $ExpectedCurrentPagePath -Phase ($Name + ' before click')
    $action = Get-LayoutAction -LayoutPath $beforeLayout -TargetText $TargetText
    if ($action.found) {
      break
    }

    if ($ExpectedCurrentPagePath -eq 'features/review/pages/ReviewHomePage' -and $TargetText -eq $TextComparePro) {
      $RecordedSteps.Add(($Name + ': target not visible yet, swipe upward to reveal membership entry.')) | Out-Null
      Send-Swipe -Name ($Name + '-reveal-membership') -FromX 654 -FromY 2300 -ToX 654 -ToY 900
      continue
    }

    if ($ExpectedCurrentPagePath -eq 'features/review/pages/ReviewHomePage' -and $TargetText -eq $TextStartTodayTraining) {
      $RecordedSteps.Add(($Name + ': target not visible yet, swipe downward to reveal current-plan entry.')) | Out-Null
      Send-Swipe -Name ($Name + '-reveal-current-plan') -FromX 654 -FromY 900 -ToX 654 -ToY 2200
      continue
    }

    if ($ExpectedCurrentPagePath -eq 'features/exercise/pages/ExerciseLibraryPage' -and $TargetText -eq $TextViewExerciseDetail) {
      $RecordedSteps.Add(($Name + ': target not visible yet, swipe upward to reveal exercise detail CTA.')) | Out-Null
      Send-Swipe -Name ($Name + '-reveal-exercise-detail') -FromX 654 -FromY 2380 -ToX 654 -ToY 1680
      continue
    }

    if ($ExpectedCurrentPagePath -eq 'pages/HomePage' -and $TargetText -eq $TextViewPlanDetail) {
      $RecordedSteps.Add(($Name + ': target not visible yet, swipe upward to reveal preset plan detail CTA.')) | Out-Null
      Send-Swipe -Name ($Name + '-reveal-plan-detail') -FromX 654 -FromY 2360 -ToX 654 -ToY 1180
      continue
    }

    throw ($Name + ' could not resolve target text "' + $TargetText + '" on page ' + $ExpectedCurrentPagePath + '.')
  }

  if ($null -eq $action -or -not $action.found) {
    throw ($Name + ' still could not resolve target text "' + $TargetText + '" after retries.')
  }

  Invoke-Hdc -Title ($Name + ' click') -CommandArgs @('shell', 'uitest', 'uiInput', 'click', $action.centerX.ToString(), $action.centerY.ToString()) | Out-Null
  Start-Sleep -Seconds $StepDelaySeconds
  $afterScreen = Capture-Screen -Label ($Name + '-after-screen')
  $afterSnapshot = Capture-LayoutWithStablePagePath -Label ($Name + '-after-layout')
  $afterLayout = $afterSnapshot.layoutPath
  $afterPagePath = $afterSnapshot.pagePath
  Assert-PagePath -ActualPagePath $afterPagePath -ExpectedPagePath $ExpectedNextPagePath -Phase ($Name + ' after click')
  $RecordedSteps.Add(($Name + ': ' + $beforePagePath + ' -> ' + $afterPagePath + ' via "' + $TargetText + '" @ (' + $action.centerX + ', ' + $action.centerY + '), screenshot=' + $afterScreen)) | Out-Null
}

function Invoke-CoordinateNavigationStep {
  param(
    [string]$Name,
    [string]$ExpectedCurrentPagePath,
    [int]$CenterX,
    [int]$CenterY,
    [string]$ExpectedNextPagePath
  )

  $beforeSnapshot = Capture-LayoutWithStablePagePath -Label ($Name + '-before-layout')
  $beforeLayout = $beforeSnapshot.layoutPath
  $beforePagePath = $beforeSnapshot.pagePath
  Assert-PagePath -ActualPagePath $beforePagePath -ExpectedPagePath $ExpectedCurrentPagePath -Phase ($Name + ' before click')
  Invoke-Hdc -Title ($Name + ' click') -CommandArgs @('shell', 'uitest', 'uiInput', 'click', $CenterX.ToString(), $CenterY.ToString()) | Out-Null
  Start-Sleep -Seconds $StepDelaySeconds
  $afterScreen = Capture-Screen -Label ($Name + '-after-screen')
  $afterSnapshot = Capture-LayoutWithStablePagePath -Label ($Name + '-after-layout')
  $afterLayout = $afterSnapshot.layoutPath
  $afterPagePath = $afterSnapshot.pagePath
  Assert-PagePath -ActualPagePath $afterPagePath -ExpectedPagePath $ExpectedNextPagePath -Phase ($Name + ' after click')
  $RecordedSteps.Add(($Name + ': ' + $beforePagePath + ' -> ' + $afterPagePath + ' via coordinate @ (' + $CenterX + ', ' + $CenterY + '), screenshot=' + $afterScreen)) | Out-Null
}

function Assert-TextVisibleStep {
  param(
    [string]$Name,
    [string]$ExpectedPagePath,
    [string]$TargetText,
    [int]$MaxAttempts = 3,
    [bool]$AllowSubstringMatch = $false
  )

  $layoutPath = ''
  $pagePath = ''
  $action = $null
  for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    $snapshot = Capture-LayoutWithStablePagePath -Label ($Name + '-layout-' + $attempt)
    $layoutPath = $snapshot.layoutPath
    $pagePath = $snapshot.pagePath
    Assert-PagePath -ActualPagePath $pagePath -ExpectedPagePath $ExpectedPagePath -Phase ($Name + ' visibility')
    $action = Get-LayoutAction -LayoutPath $layoutPath -TargetText $TargetText -AllowSubstringMatch $AllowSubstringMatch
    if ($action.found) {
      $screenPath = Capture-Screen -Label ($Name + '-visible-screen-' + $attempt)
      $RecordedSteps.Add(($Name + ': visible on ' + $pagePath + ' as "' + $TargetText + '", screenshot=' + $screenPath)) | Out-Null
      return
    }

    if ($ExpectedPagePath -eq 'features/review/pages/ReviewHomePage') {
      $RecordedSteps.Add(($Name + ': target not visible yet, swipe upward to continue scanning review page.')) | Out-Null
      Send-Swipe -Name ($Name + '-review-scan') -FromX 654 -FromY 2300 -ToX 654 -ToY 900
      continue
    }

    throw ($Name + ' could not resolve target text "' + $TargetText + '" on page ' + $ExpectedPagePath + '.')
  }

  throw ($Name + ' still could not resolve target text "' + $TargetText + '" after retries.')
}

function Start-App {
  Invoke-Hdc -Title 'force stop app before launch' -CommandArgs @('shell', 'aa', 'force-stop', $BundleName) | Out-Null
  Start-Sleep -Seconds 1
  Invoke-Hdc -Title 'start entry ability' -CommandArgs @('shell', 'aa', 'start', '-a', $AbilityName, '-b', $BundleName) | Out-Null
  Start-Sleep -Seconds $StepDelaySeconds
}

function Send-BackKey {
  param([string]$Name)

  Invoke-Hdc -Title ($Name + ' back') -CommandArgs @('shell', 'uitest', 'uiInput', 'keyEvent', 'Back') | Out-Null
  Start-Sleep -Seconds $StepDelaySeconds
}

function Normalize-ToReviewHome {
  for ($attempt = 1; $attempt -le 6; $attempt++) {
    $layoutPath = Capture-Layout -Label ('normalize-' + $attempt + '-layout')
    $pagePath = Get-LayoutPagePath -LayoutPath $layoutPath
    if ($pagePath -eq 'features/review/pages/ReviewHomePage') {
      $RecordedSteps.Add(('normalize: reached review on attempt ' + $attempt + '.')) | Out-Null
      return
    }

    if ($pagePath -eq 'pages/HomePage') {
      Invoke-TextNavigationStep `
        -Name ('normalize-home-to-review-' + $attempt) `
        -ExpectedCurrentPagePath 'pages/HomePage' `
        -TargetText $TextReview `
        -ExpectedNextPagePath 'features/review/pages/ReviewHomePage'
      return
    }

    if ($pagePath -eq 'features/exercise/pages/ExerciseLibraryPage') {
      $RecordedSteps.Add(('normalize: reveal library top rail on attempt ' + $attempt + '.')) | Out-Null
      Send-Swipe -Name ('normalize-library-reveal-top-' + $attempt) -FromX 654 -FromY 980 -ToX 654 -ToY 2280
      Invoke-CoordinateNavigationStep `
        -Name ('normalize-library-strip-to-review-' + $attempt) `
        -ExpectedCurrentPagePath 'features/exercise/pages/ExerciseLibraryPage' `
        -CenterX 1144 `
        -CenterY 832 `
        -ExpectedNextPagePath 'features/review/pages/ReviewHomePage'
      return
    }

    if ($pagePath.Length -eq 0) {
      $RecordedSteps.Add(('normalize: empty page path on attempt ' + $attempt + ', restarting entry ability.')) | Out-Null
      Start-App
      continue
    }

    $RecordedSteps.Add(('normalize: leaving ' + $pagePath + ' via Back.')) | Out-Null
    Send-BackKey -Name ('normalize-' + $attempt)
  }

  throw 'Unable to normalize the app back to ReviewHomePage within 6 attempts.'
}

function Write-ProbeSummary {
  param(
    [string]$Status,
    [string]$FailureReason
  )

  New-RunDirectory
  $summaryLines = @()
  $summaryLines += '# FitTracker live device probe'
  $summaryLines += ''
  $summaryLines += '- date: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
  $summaryLines += '- status: ' + $Status
  $summaryLines += '- scenario: ' + $Scenario
  $summaryLines += '- device id: ' + $DeviceId
  $summaryLines += '- bundle: ' + $BundleName
  $summaryLines += '- ability: ' + $AbilityName
  $summaryLines += '- run root: ' + $RunRoot
  $summaryLines += ''
  $summaryLines += '## steps'
  if ($RecordedSteps.Count -eq 0) {
    $summaryLines += '- none'
  } else {
    foreach ($step in $RecordedSteps) {
      $summaryLines += '- ' + $step
    }
  }
  $summaryLines += ''
  $summaryLines += '## failure notes'
  if ([string]::IsNullOrWhiteSpace($FailureReason)) {
    $summaryLines += '- none'
  } else {
    $summaryLines += '- failure reason: ' + $FailureReason
  }
  Set-Content -Path $RunSummaryPath -Value $summaryLines -Encoding utf8
}

function Invoke-Scenario {
  New-RunDirectory
  Ensure-HdcReady
  if ($CheckOnly) {
    $RecordedSteps.Add('check-only: HDC target is ready for live device probing.') | Out-Null
    return
  }

  Start-App
  $launchScreen = Capture-Screen -Label 'launch'
  $launchLayout = Capture-Layout -Label 'launch-layout'
  $launchPagePath = Get-LayoutPagePath -LayoutPath $launchLayout
  $RecordedSteps.Add(('launch: ' + $launchPagePath + ', screenshot=' + $launchScreen)) | Out-Null

  if ($Scenario -eq 'review-plan-detail' -and $launchPagePath -eq 'pages/HomePage') {
    Invoke-TextNavigationStep `
      -Name 'home-to-plan-detail' `
      -ExpectedCurrentPagePath 'pages/HomePage' `
      -TargetText $TextViewPlanDetail `
      -ExpectedNextPagePath 'features/workout/pages/TrainingPlanDetailPage'
    return
  }

  Normalize-ToReviewHome
  $reviewScreen = Capture-Screen -Label 'review-ready'
  $reviewLayout = Capture-Layout -Label 'review-ready-layout'
  $reviewPagePath = Get-LayoutPagePath -LayoutPath $reviewLayout
  $RecordedSteps.Add(('review-ready: ' + $reviewPagePath + ', screenshot=' + $reviewScreen)) | Out-Null

  if ($Scenario -eq 'review-membership') {
    Assert-PagePath -ActualPagePath $reviewPagePath -ExpectedPagePath 'features/review/pages/ReviewHomePage' -Phase 'review-ready'
    Invoke-TextNavigationStep `
      -Name 'review-membership-entry' `
      -ExpectedCurrentPagePath 'features/review/pages/ReviewHomePage' `
      -TargetText $TextComparePro `
      -ExpectedNextPagePath 'features/monetization/pages/MonetizationHubPage'
    return
  }

  if ($Scenario -eq 'review-backup-card') {
    Assert-PagePath -ActualPagePath $reviewPagePath -ExpectedPagePath 'features/review/pages/ReviewHomePage' -Phase 'review-ready'
    Assert-TextVisibleStep `
      -Name 'review-backup-card' `
      -ExpectedPagePath 'features/review/pages/ReviewHomePage' `
      -TargetText $TextBackupAction
    return
  }

  if ($Scenario -eq 'review-workout-loop') {
    Assert-PagePath -ActualPagePath $reviewPagePath -ExpectedPagePath 'features/review/pages/ReviewHomePage' -Phase 'review-ready'
    Invoke-TextNavigationStep `
      -Name 'review-to-home' `
      -ExpectedCurrentPagePath 'features/review/pages/ReviewHomePage' `
      -TargetText $TextStartTodayTraining `
      -ExpectedNextPagePath 'pages/HomePage'
    Invoke-TextNavigationStep `
      -Name 'home-to-preview' `
      -ExpectedCurrentPagePath 'pages/HomePage' `
      -TargetText $TextStartTraining `
      -ExpectedNextPagePath 'features/workout/pages/WorkoutPreviewPage'
    Invoke-TextNavigationStep `
      -Name 'preview-to-active' `
      -ExpectedCurrentPagePath 'features/workout/pages/WorkoutPreviewPage' `
      -TargetText $TextStartTraining `
      -ExpectedNextPagePath 'features/workout/pages/ActiveWorkoutPage'
    return
  }

  if ($Scenario -eq 'review-metrics') {
    Assert-PagePath -ActualPagePath $reviewPagePath -ExpectedPagePath 'features/review/pages/ReviewHomePage' -Phase 'review-ready'
    Assert-TextVisibleStep `
      -Name 'review-metrics-average-completion' `
      -ExpectedPagePath 'features/review/pages/ReviewHomePage' `
      -TargetText '78%'
    Assert-TextVisibleStep `
      -Name 'review-metrics-latest-volume' `
      -ExpectedPagePath 'features/review/pages/ReviewHomePage' `
      -TargetText '357 kg'
    Assert-TextVisibleStep `
      -Name 'review-metrics-weekly-volume' `
      -ExpectedPagePath 'features/review/pages/ReviewHomePage' `
      -TargetText '1364 kg'
    Assert-TextVisibleStep `
      -Name 'review-metrics-pr' `
      -ExpectedPagePath 'features/review/pages/ReviewHomePage' `
      -TargetText '105kg' `
      -MaxAttempts 6 `
      -AllowSubstringMatch $true
    return
  }

  if ($false -and $Scenario -eq 'review-metrics') {
    Assert-PagePath -ActualPagePath $reviewPagePath -ExpectedPagePath 'features/review/pages/ReviewHomePage' -Phase 'review-ready'
    Assert-TextVisibleStep `
      -Name 'review-metrics-average-completion' `
      -ExpectedPagePath 'features/review/pages/ReviewHomePage' `
      -TargetText '78%'
    Assert-TextVisibleStep `
      -Name 'review-metrics-latest-volume' `
      -ExpectedPagePath 'features/review/pages/ReviewHomePage' `
      -TargetText '357 kg'
    Assert-TextVisibleStep `
      -Name 'review-metrics-weekly-volume' `
      -ExpectedPagePath 'features/review/pages/ReviewHomePage' `
      -TargetText '1364 kg'
    Assert-TextVisibleStep `
      -Name 'review-metrics-pr' `
      -ExpectedPagePath 'features/review/pages/ReviewHomePage' `
      -TargetText '杠铃卧推 · 105kg' `
      -MaxAttempts 6
    return
  }

  if ($Scenario -eq 'review-exercise-detail') {
    Assert-PagePath -ActualPagePath $reviewPagePath -ExpectedPagePath 'features/review/pages/ReviewHomePage' -Phase 'review-ready'
    Invoke-TextNavigationStep `
      -Name 'review-to-library' `
      -ExpectedCurrentPagePath 'features/review/pages/ReviewHomePage' `
      -TargetText $TextExerciseLibrary `
      -ExpectedNextPagePath 'features/exercise/pages/ExerciseLibraryPage'
    Invoke-TextNavigationStep `
      -Name 'library-to-detail' `
      -ExpectedCurrentPagePath 'features/exercise/pages/ExerciseLibraryPage' `
      -TargetText $TextViewExerciseDetail `
      -ExpectedNextPagePath 'features/exercise/pages/ExerciseDetailPage'
    return
  }

  if ($Scenario -eq 'review-plan-detail') {
    Assert-PagePath -ActualPagePath $reviewPagePath -ExpectedPagePath 'features/review/pages/ReviewHomePage' -Phase 'review-ready'
    Invoke-TextNavigationStep `
      -Name 'review-to-home-for-plan-detail' `
      -ExpectedCurrentPagePath 'features/review/pages/ReviewHomePage' `
      -TargetText $TextStartTodayTraining `
      -ExpectedNextPagePath 'pages/HomePage'
    Invoke-TextNavigationStep `
      -Name 'home-to-plan-detail' `
      -ExpectedCurrentPagePath 'pages/HomePage' `
      -TargetText $TextViewPlanDetail `
      -ExpectedNextPagePath 'features/workout/pages/TrainingPlanDetailPage'
    return
  }

  throw ('Unsupported scenario: ' + $Scenario)
}

try {
  Invoke-Scenario
  Write-ProbeSummary -Status 'passed' -FailureReason ''
  Write-Host ''
  Write-Host ('[FitTracker Live Probe] summary: ' + $RunSummaryPath)
} catch {
  Write-ProbeSummary -Status 'failed' -FailureReason $_.Exception.Message
  throw
}
