param(
  [string]$QueueFile = "tasks/project-queue.json",
  [string]$BlockersFile = "docs/blockers.md",
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

function Read-JsonArray {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    throw ('JSON file not found: ' + $Path)
  }

  $raw = Get-Content -Path $Path -Raw -Encoding utf8
  $items = $raw | ConvertFrom-Json
  if ($null -eq $items -or -not ($items -is [System.Array])) {
    throw ('Expected JSON array: ' + $Path)
  }
  return @($items)
}

function Read-ActiveBlockers {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    return @()
  }

  $matches = Select-String -Path $Path -Pattern '^- `([^`]+)`' -Encoding utf8
  $ids = @()
  foreach ($match in $matches) {
    $ids += $match.Matches[0].Groups[1].Value
  }
  return $ids
}

function Get-TaskMap {
  param([object[]]$Queue)

  $map = @{}
  foreach ($task in $Queue) {
    $map[$task.id] = $task
  }
  return $map
}

function Test-DependenciesDone {
  param(
    [object]$Task,
    [hashtable]$TaskMap
  )

  if ($null -eq $Task.dependsOn) {
    return $true
  }

  foreach ($dependencyId in $Task.dependsOn) {
    if (-not $TaskMap.ContainsKey($dependencyId)) {
      return $false
    }
    if ($TaskMap[$dependencyId].status -ne 'done') {
      return $false
    }
  }
  return $true
}

function Test-TaskBlockedByEnvironment {
  param(
    [object]$Task,
    [string[]]$ActiveBlockers
  )

  if ($Task.status -eq 'blocked') {
    return $true
  }

  if ($null -eq $Task.requires) {
    return $false
  }

  $requires = @($Task.requires)
  if ($requires -contains 'device' -and $ActiveBlockers -contains 'device.hdc_unavailable') {
    return $true
  }
  if ($requires -contains 'decision') {
    return $true
  }
  return $false
}

function Get-ReadyTasks {
  param(
    [object[]]$Queue,
    [string[]]$ActiveBlockers
  )

  $taskMap = Get-TaskMap -Queue $Queue
  $ready = New-Object 'System.Collections.Generic.List[object]'

  foreach ($task in $Queue) {
    if ($task.status -eq 'done') {
      continue
    }
    if (-not (Test-DependenciesDone -Task $task -TaskMap $taskMap)) {
      continue
    }
    if (Test-TaskBlockedByEnvironment -Task $task -ActiveBlockers $ActiveBlockers) {
      continue
    }
    $ready.Add($task) | Out-Null
  }

  return @($ready | Sort-Object @{ Expression = { [int]$_.priority } }, @{ Expression = { $_.id } })
}

function Get-BlockedTasks {
  param(
    [object[]]$Queue,
    [string[]]$ActiveBlockers
  )

  $taskMap = Get-TaskMap -Queue $Queue
  $blocked = New-Object 'System.Collections.Generic.List[object]'

  foreach ($task in $Queue) {
    if ($task.status -eq 'done') {
      continue
    }
    if ((-not (Test-DependenciesDone -Task $task -TaskMap $taskMap)) -or
      (Test-TaskBlockedByEnvironment -Task $task -ActiveBlockers $ActiveBlockers)) {
      $blocked.Add($task) | Out-Null
    }
  }

  return @($blocked.ToArray())
}

function Get-GitSnapshot {
  $status = git status --short
  $log = git log --oneline -5
  return @{
    Status = ($status | Out-String).TrimEnd()
    Log = ($log | Out-String).TrimEnd()
  }
}

$queue = Read-JsonArray -Path $QueueFile
$activeBlockers = @(Read-ActiveBlockers -Path $BlockersFile)
$readyTasks = @(Get-ReadyTasks -Queue $queue -ActiveBlockers $activeBlockers)
$blockedTasks = @(Get-BlockedTasks -Queue $queue -ActiveBlockers $activeBlockers)
$snapshot = Get-GitSnapshot

Write-Host '[Continuous Dev] Queue loaded:'
Write-Host ('- queue file: ' + (Resolve-Path $QueueFile).Path)
Write-Host ('- blockers file: ' + (Resolve-Path $BlockersFile).Path)
Write-Host ('- active blockers: ' + ($(if ($activeBlockers.Count -eq 0) { 'none' } else { $activeBlockers -join ', ' })))
Write-Host ('- ready tasks: ' + $readyTasks.Count)
Write-Host ('- blocked/deferred tasks: ' + $blockedTasks.Count)
Write-Host ''

if ($readyTasks.Count -eq 0) {
  Write-Host '[Continuous Dev] No ready task found.'
  exit 0
}

$nextTask = $readyTasks[0]

Write-Host '[Continuous Dev] Next ready task:'
Write-Host ('- id: ' + $nextTask.id)
Write-Host ('- lane: ' + $nextTask.lane)
Write-Host ('- title: ' + $nextTask.title)
Write-Host ('- priority: ' + $nextTask.priority)
Write-Host ('- summary: ' + $nextTask.summary)
Write-Host ('- requires: ' + (@($nextTask.requires) -join ', '))
Write-Host ''
Write-Host '[Continuous Dev] Validation chain:'
foreach ($step in $nextTask.validation) {
  Write-Host ('- ' + $step)
}
Write-Host ''
Write-Host '[Continuous Dev] Done definition:'
foreach ($item in $nextTask.doneDefinition) {
  Write-Host ('- ' + $item)
}
Write-Host ''
Write-Host '[Continuous Dev] Repo snapshot:'
Write-Host $snapshot.Status
Write-Host ''
Write-Host '[Continuous Dev] Recent commits:'
Write-Host $snapshot.Log

if ($DryRun) {
  Write-Host ''
  Write-Host '[Continuous Dev] Dry-run only. No queue state was modified.'
  exit 0
}

Write-Host ''
Write-Host '[Continuous Dev] Live mode is not mutating queue state yet.'
Write-Host '[Continuous Dev] Use this selection packet to continue the next coding round.'
