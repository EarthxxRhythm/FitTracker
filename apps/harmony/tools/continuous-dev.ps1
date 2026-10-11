param(
  [string]$QueueFile = "tasks/project-queue.json",
  [string]$BlockersFile = "docs/blockers.md",
  [ValidateSet('text', 'json')]
  [string]$OutputFormat = 'text',
  [switch]$DryRun,
  [switch]$MarkDoing
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

function Write-JsonArray {
  param(
    [string]$Path,
    [object[]]$Items
  )

  $json = $Items | ConvertTo-Json -Depth 8
  Set-Content -Path $Path -Value $json -Encoding utf8
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

function Get-BlockedReason {
  param(
    [object]$Task,
    [hashtable]$TaskMap,
    [string[]]$ActiveBlockers
  )

  if ($task.status -eq 'blocked') {
    return 'task_status_blocked'
  }

  if (-not (Test-DependenciesDone -Task $task -TaskMap $TaskMap)) {
    return 'dependency_not_done'
  }

  if ($null -ne $Task.requires) {
    $requires = @($Task.requires)
    if ($requires -contains 'device' -and $ActiveBlockers -contains 'device.hdc_unavailable') {
      return 'device_blocked'
    }
    if ($requires -contains 'decision') {
      return 'decision_required'
    }
  }

  return 'unknown'
}

function New-ExecutionPacket {
  param(
    [object]$Task,
    [object[]]$ReadyTasks,
    [object[]]$BlockedTasks,
    [string[]]$ActiveBlockers,
    [hashtable]$GitSnapshot,
    [hashtable]$TaskMap
  )

  $fallbackTask = $null
  foreach ($candidate in $ReadyTasks) {
    if ($candidate.id -ne $Task.id) {
      $fallbackTask = $candidate
      break
    }
  }

  $blockedSummaries = @()
  foreach ($blockedTask in $BlockedTasks) {
    $blockedSummaries += @{
      id = $blockedTask.id
      lane = $blockedTask.lane
      status = $blockedTask.status
      reason = Get-BlockedReason -Task $blockedTask -TaskMap $TaskMap -ActiveBlockers $ActiveBlockers
    }
  }

  return @{
    queueFile = (Resolve-Path $QueueFile).Path
    blockersFile = (Resolve-Path $BlockersFile).Path
    activeBlockers = @($ActiveBlockers)
    nextTask = @{
      id = $Task.id
      lane = $Task.lane
      title = $Task.title
      priority = [int]$Task.priority
      summary = $Task.summary
      requires = @($Task.requires)
      validation = @($Task.validation)
      doneDefinition = @($Task.doneDefinition)
    }
    fallbackTask = $(if ($null -eq $fallbackTask) {
      $null
    } else {
      @{
        id = $fallbackTask.id
        lane = $fallbackTask.lane
        title = $fallbackTask.title
        priority = [int]$fallbackTask.priority
      }
    })
    blockedTasks = $blockedSummaries
    repoSnapshot = @{
      status = $GitSnapshot.Status
      recentCommits = $GitSnapshot.Log
    }
  }
}

function Write-ExecutionPacketText {
  param([hashtable]$Packet)

  Write-Host '[Continuous Dev] Queue loaded:'
  Write-Host ('- queue file: ' + $Packet.queueFile)
  Write-Host ('- blockers file: ' + $Packet.blockersFile)
  Write-Host ('- active blockers: ' + $(if ($Packet.activeBlockers.Count -eq 0) { 'none' } else { $Packet.activeBlockers -join ', ' }))
  Write-Host ('- blocked/deferred tasks: ' + $Packet.blockedTasks.Count)
  Write-Host ''

  Write-Host '[Continuous Dev] Next ready task:'
  Write-Host ('- id: ' + $Packet.nextTask.id)
  Write-Host ('- lane: ' + $Packet.nextTask.lane)
  Write-Host ('- title: ' + $Packet.nextTask.title)
  Write-Host ('- priority: ' + $Packet.nextTask.priority)
  Write-Host ('- summary: ' + $Packet.nextTask.summary)
  Write-Host ('- requires: ' + ($Packet.nextTask.requires -join ', '))
  Write-Host ''

  if ($null -ne $Packet.fallbackTask) {
    Write-Host '[Continuous Dev] Fallback ready task:'
    Write-Host ('- id: ' + $Packet.fallbackTask.id)
    Write-Host ('- lane: ' + $Packet.fallbackTask.lane)
    Write-Host ('- title: ' + $Packet.fallbackTask.title)
    Write-Host ('- priority: ' + $Packet.fallbackTask.priority)
    Write-Host ''
  }

  Write-Host '[Continuous Dev] Validation chain:'
  foreach ($step in $Packet.nextTask.validation) {
    Write-Host ('- ' + $step)
  }
  Write-Host ''

  Write-Host '[Continuous Dev] Done definition:'
  foreach ($item in $Packet.nextTask.doneDefinition) {
    Write-Host ('- ' + $item)
  }
  Write-Host ''

  if ($Packet.blockedTasks.Count -gt 0) {
    Write-Host '[Continuous Dev] Blocked/deferred tasks:'
    foreach ($blockedTask in $Packet.blockedTasks) {
      Write-Host ('- ' + $blockedTask.id + ' [' + $blockedTask.reason + ']')
    }
    Write-Host ''
  }

  Write-Host '[Continuous Dev] Repo snapshot:'
  Write-Host $Packet.repoSnapshot.status
  Write-Host ''
  Write-Host '[Continuous Dev] Recent commits:'
  Write-Host $Packet.repoSnapshot.recentCommits
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
$taskMap = Get-TaskMap -Queue $queue

if ($readyTasks.Count -eq 0) {
  if ($OutputFormat -eq 'json') {
    @{
      queueFile = (Resolve-Path $QueueFile).Path
      blockersFile = (Resolve-Path $BlockersFile).Path
      activeBlockers = @($activeBlockers)
      nextTask = $null
      blockedTasks = @($blockedTasks | ForEach-Object {
        @{
          id = $_.id
          lane = $_.lane
          status = $_.status
          reason = Get-BlockedReason -Task $_ -TaskMap $taskMap -ActiveBlockers $activeBlockers
        }
      })
      repoSnapshot = @{
        status = $snapshot.Status
        recentCommits = $snapshot.Log
      }
    } | ConvertTo-Json -Depth 8
  } else {
    Write-Host '[Continuous Dev] No ready task found.'
  }
  exit 0
}

$nextTask = $readyTasks[0]
$packet = New-ExecutionPacket -Task $nextTask -ReadyTasks $readyTasks -BlockedTasks $blockedTasks -ActiveBlockers $activeBlockers -GitSnapshot $snapshot -TaskMap $taskMap

if ($MarkDoing) {
  foreach ($task in $queue) {
    if ($task.id -eq $nextTask.id) {
      $task.status = 'doing'
    }
  }
  Write-JsonArray -Path $QueueFile -Items $queue
}

if ($OutputFormat -eq 'json') {
  $packet | ConvertTo-Json -Depth 8
} else {
  Write-ExecutionPacketText -Packet $packet
}

if ($DryRun) {
  Write-Host ''
  Write-Host '[Continuous Dev] Dry-run only. No queue state was modified.'
  exit 0
}

Write-Host ''
if ($MarkDoing) {
  Write-Host ('[Continuous Dev] Marked task as doing: ' + $nextTask.id)
} else {
  Write-Host '[Continuous Dev] Queue state unchanged. Re-run with -MarkDoing to claim the task.'
}
