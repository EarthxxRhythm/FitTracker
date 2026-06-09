Set-StrictMode -Version Latest

function Get-HdcTargetEntries {
  param([string]$RawOutput)

  $entries = New-Object 'System.Collections.Generic.List[object]'
  if ([string]::IsNullOrWhiteSpace($RawOutput)) {
    return @()
  }

  $lines = $RawOutput -split "`r?`n"
  for ($index = 0; $index -lt $lines.Length; $index++) {
    $line = $lines[$index].Trim()
    if ($line.Length -eq 0) {
      continue
    }
    if ($line -eq '[Empty]') {
      continue
    }
    if ($line.StartsWith('[List')) {
      continue
    }

    $match = [regex]::Match($line, '^(?<Id>\S+)\s+(?<Transport>\S+)\s+(?<State>\S+)')
    if (-not $match.Success) {
      continue
    }

    $entries.Add([pscustomobject]@{
        Id = $match.Groups['Id'].Value
        Transport = $match.Groups['Transport'].Value
        State = $match.Groups['State'].Value
        Raw = $line
      }) | Out-Null
  }

  return @($entries.ToArray())
}

function Get-HdcTargetSummary {
  param([string]$RawOutput)

  $entries = @(Get-HdcTargetEntries -RawOutput $RawOutput)
  $readyStates = @('Ready', 'Connected')
  $readyTargets = @($entries | Where-Object { $readyStates -contains $_.State })
  $unknownTargets = @($entries | Where-Object { $_.State -eq 'Unknown' })
  $otherTargets = @($entries | Where-Object { $readyStates -notcontains $_.State -and $_.State -ne 'Unknown' })

  return [pscustomobject]@{
    Entries = $entries
    ReadyTargets = $readyTargets
    UnknownTargets = $unknownTargets
    OtherTargets = $otherTargets
  }
}

function Assert-HdcTargetsReady {
  param(
    [string]$RawOutput,
    [string]$DeviceId = ''
  )

  $summary = Get-HdcTargetSummary -RawOutput $RawOutput
  if ($summary.Entries.Count -eq 0) {
    throw 'No HDC targets are listed. Connect a device or start a simulator before running this command.'
  }

  if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
    $matchingTargets = @($summary.Entries | Where-Object { $_.Id -eq $DeviceId })
    if ($matchingTargets.Count -eq 0) {
      throw ("HDC target '" + $DeviceId + "' is not listed. Available targets: " + (($summary.Entries | ForEach-Object { $_.Raw }) -join '; '))
    }

    $readyMatch = @($matchingTargets | Where-Object { $_.State -eq 'Ready' -or $_.State -eq 'Connected' })
    if ($readyMatch.Count -gt 0) {
      return
    }

    throw ("HDC target '" + $DeviceId + "' is listed but not usable yet. Current state: " + (($matchingTargets | ForEach-Object { $_.State }) -join ', ') + '. Wait for the simulator/device to finish booting, then retry.')
  }

  if ($summary.ReadyTargets.Count -gt 0) {
    return
  }

  if ($summary.UnknownTargets.Count -gt 0) {
    throw ('HDC targets are listed but not usable yet: ' + (($summary.UnknownTargets | ForEach-Object { $_.Raw }) -join '; ') + '. Wait for the simulator/device to finish booting, then retry.')
  }

  throw ('HDC targets are listed but not usable yet: ' + (($summary.Entries | ForEach-Object { $_.Raw }) -join '; '))
}
