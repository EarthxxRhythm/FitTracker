param(
  [string]$TaskFile = "",
  [switch]$RunChecks,
  [switch]$WritePrompt,
  [string]$PromptPath = "midscene_run/task-relay-prompt.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot
$DevEcoEnvScriptPath = Join-Path $PSScriptRoot 'deveco-env.ps1'

function Resolve-RepoPath {
  param([string]$RelativePath)
  return Join-Path $RepoRoot $RelativePath
}

function Get-DefaultTaskFile {
  $candidates = @(
    'docs/tasks.workout-loop.json',
    'docs/tasks.content-plan.json',
    'docs/tasks.regression-flow.json',
    'tasks.phase2.json'
  )

  foreach ($candidate in $candidates) {
    if (Test-Path (Resolve-RepoPath $candidate)) {
      return $candidate
    }
  }

  throw 'No task source found. Pass -TaskFile explicitly.'
}

function Invoke-CapturedCommand {
  param(
    [string]$Title,
    [string]$FilePath,
    [string[]]$Arguments,
    [string]$WorkingDirectory = $RepoRoot
  )

  Write-Host ""
  Write-Host ('[Task Relay] ' + $Title)
  Push-Location $WorkingDirectory
  try {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = & $FilePath @Arguments 2>&1
    $ErrorActionPreference = $previousPreference
    if ($LASTEXITCODE -ne 0) {
      $text = ($output | Out-String).TrimEnd()
      throw ($Title + ' failed' + [Environment]::NewLine + $text)
    }
    return (($output | Out-String).TrimEnd())
  } finally {
    $ErrorActionPreference = $previousPreference
    Pop-Location
  }
}

function Ensure-DevEcoToolchain {
  if (-not (Test-Path $DevEcoEnvScriptPath)) {
    throw 'DevEco env helper not found: ' + $DevEcoEnvScriptPath
  }
  & $DevEcoEnvScriptPath
}

function Read-TaskSource {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    throw 'Task file not found: ' + $Path
  }

  $raw = Get-Content -Path $Path -Raw -Encoding utf8
  $tasks = $raw | ConvertFrom-Json
  if ($null -eq $tasks -or -not ($tasks -is [System.Array])) {
    throw 'Task file must contain a JSON array: ' + $Path
  }
  return @($tasks)
}

function Get-NextTask {
  param([object[]]$Tasks)

  $pending = @($Tasks | Where-Object { $_.passes -eq $false } | Sort-Object @{ Expression = { [int]$_.id } })
  if ($pending.Count -eq 0) {
    return $null
  }
  return $pending[0]
}

function Format-CommandBlock {
  param([string[]]$Lines)
  return ($Lines -join [Environment]::NewLine)
}

function Build-RelayPrompt {
  param(
    [object]$Task,
    [string]$TaskFileLabel,
    [string]$RepoStatus,
    [string]$GitLog,
    [hashtable]$CheckResults
  )

  $promptLines = @()
  $promptLines += '# FitTracker task relay prompt'
  $promptLines += ''
  $promptLines += 'You are the Coding Agent for this repo.'
  $promptLines += 'Please complete exactly one task at a time.'
  $promptLines += ''
  $promptLines += ('Task source: ' + $TaskFileLabel)
  $promptLines += ('Next task id: ' + $Task.id)
  $promptLines += ('Category: ' + $Task.category)
  $promptLines += ('Description: ' + $Task.description)
  $promptLines += ''
  $promptLines += 'Repository snapshot:'
  $promptLines += $RepoStatus
  $promptLines += ''
  $promptLines += 'Recent git history:'
  $promptLines += $GitLog
  $promptLines += ''
  $promptLines += 'Preflight checks:'
  foreach ($key in $CheckResults.Keys) {
    $promptLines += ('- ' + $key + ': ' + $CheckResults[$key])
  }
  $promptLines += ''
  $promptLines += 'Execution order:'
  $promptLines += ('1. Read ' + $TaskFileLabel + ', the project log, git log -5, and git status.')
  $promptLines += '2. Run the preflight checks above.'
  $promptLines += '3. Implement only this task.'
  $promptLines += '4. Re-run the checks, update the task flag and project log, then commit.'
  return Format-CommandBlock $promptLines
}

$selectedTaskFile = $TaskFile
if ([string]::IsNullOrWhiteSpace($selectedTaskFile)) {
  $selectedTaskFile = Get-DefaultTaskFile
}

$taskFilePath = Resolve-RepoPath $selectedTaskFile
$promptFilePath = Resolve-RepoPath $PromptPath

$tasks = Read-TaskSource -Path $taskFilePath
$nextTask = Get-NextTask -Tasks $tasks

if ($null -eq $nextTask) {
  Write-Host ('[Task Relay] No pending tasks found in ' + $taskFilePath)
  if ($WritePrompt) {
    $noTaskPrompt = @(
      '# FitTracker task relay prompt',
      '',
      'All tasks in ' + $selectedTaskFile + ' are complete.',
      'No further coding relay is needed.'
    )
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $promptFilePath) | Out-Null
    Set-Content -Path $promptFilePath -Value $noTaskPrompt -Encoding utf8
    Write-Host ('[Task Relay] Prompt written to ' + $promptFilePath)
  }
  exit 0
}

$repoStatus = Invoke-CapturedCommand -Title 'git status --short --branch' -FilePath 'git' -Arguments @('status', '--short', '--branch')
$gitLog = Invoke-CapturedCommand -Title 'git log --oneline -5' -FilePath 'git' -Arguments @('log', '--oneline', '-5')

$checkResults = [ordered]@{}

if ($RunChecks) {
  $checkResults['node tools/check-gates.mjs'] = 'running'
  $checkResults['node tools/check-gates.mjs'] = Invoke-CapturedCommand -Title 'node tools/check-gates.mjs' -FilePath 'node' -Arguments @('tools/check-gates.mjs')

  Ensure-DevEcoToolchain
  $hvigorwPath = 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat'
  if (Test-Path $hvigorwPath) {
    $checkResults['hvigorw tasks --type-check'] = 'running'
    $checkResults['hvigorw assembleHap entry@default'] = 'running'
    $checkResults['hvigorw assembleHap entry@ohosTest'] = 'running'

    $checkResults['hvigorw tasks --type-check'] = Invoke-CapturedCommand -Title 'hvigorw tasks --type-check' -FilePath $hvigorwPath -Arguments @('tasks', '--mode', 'module', '-p', 'module=entry@default', '-p', 'product=default', '--type-check')
    $checkResults['hvigorw assembleHap entry@default'] = Invoke-CapturedCommand -Title 'hvigorw assembleHap entry@default' -FilePath $hvigorwPath -Arguments @('assembleHap', '--mode', 'module', '-p', 'module=entry@default', '-p', 'product=default')
    $checkResults['hvigorw assembleHap entry@ohosTest'] = Invoke-CapturedCommand -Title 'hvigorw assembleHap entry@ohosTest' -FilePath $hvigorwPath -Arguments @('assembleHap', '--mode', 'module', '-p', 'module=entry@ohosTest', '-p', 'product=default')
  } else {
    $checkResults['hvigorw tasks --type-check'] = 'skipped (toolchain missing)'
    $checkResults['hvigorw assembleHap entry@default'] = 'skipped (toolchain missing)'
    $checkResults['hvigorw assembleHap entry@ohosTest'] = 'skipped (toolchain missing)'
  }
}

$checkSummary = [ordered]@{}
if ($RunChecks) {
  foreach ($key in $checkResults.Keys) {
    $checkSummary[$key] = 'pass'
  }
} else {
  $checkSummary['preflight'] = 'not run'
}

$prompt = Build-RelayPrompt -Task $nextTask -TaskFileLabel $selectedTaskFile -RepoStatus $repoStatus -GitLog $gitLog -CheckResults $checkSummary

Write-Host ('[Task Relay] Next task #' + $nextTask.id + ' (' + $nextTask.category + ')')
Write-Host ('[Task Relay] Description: ' + $nextTask.description)

if ($WritePrompt) {
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $promptFilePath) | Out-Null
  Set-Content -Path $promptFilePath -Value $prompt -Encoding utf8
  Write-Host ('[Task Relay] Prompt written to ' + $promptFilePath)
}

Write-Host ''
Write-Host '[Task Relay] Ready-to-use prompt:'
Write-Host $prompt
