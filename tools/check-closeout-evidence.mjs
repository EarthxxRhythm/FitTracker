import { readdirSync, readFileSync, statSync } from 'node:fs'
import { join, relative, resolve } from 'node:path'

const repoRoot = process.cwd()
const authRoot = resolve(repoRoot, 'midscene_run', 'auth')
const focusedRoot = resolve(repoRoot, 'midscene_run', 'focused')
const outputJson = process.argv.includes('--json')

function walkFiles(rootDir, fileName) {
  const results = []

  function walk(currentDir) {
    const entries = readdirSync(currentDir, { withFileTypes: true })
    for (const entry of entries) {
      if (entry.name === '.' || entry.name === '..') {
        continue
      }

      const fullPath = join(currentDir, entry.name)
      if (entry.isDirectory()) {
        walk(fullPath)
        continue
      }

      if (entry.isFile() && entry.name === fileName) {
        results.push(fullPath)
      }
    }
  }

  walk(rootDir)
  return results
}

function readSummary(fullPath, kind) {
  const raw = readFileSync(fullPath, 'utf8')
  const lines = raw.split(/\r?\n/)
  const fields = {}

  for (const line of lines) {
    const match = line.match(/^- ([^:]+):\s*(.*)$/)
    if (!match) {
      continue
    }
    fields[match[1].trim().toLowerCase()] = match[2].trim()
  }

  const failureSection = raw.split('## failure notes')[1] ?? ''
  const failureText = failureSection.trim()
  const externalProviderBlocked = /AccountOverdueError|overdue balance|PermissionDeniedError|failed to call AI model service/i.test(
    failureText
  )

  return {
    kind,
    fullPath,
    relativePath: relative(repoRoot, fullPath).replace(/\\/g, '/'),
    mtimeMs: statSync(fullPath).mtimeMs,
    date: fields.date ?? '',
    status: fields.status ?? '',
    target: fields.target ?? '',
    latestHtml: fields['latest html'] ?? '',
    failureText,
    externalProviderBlocked
  }
}

function getSummaries(rootDir, fileName, kind) {
  const paths = walkFiles(rootDir, fileName)
  const summaries = []
  for (const fullPath of paths) {
    summaries.push(readSummary(fullPath, kind))
  }
  summaries.sort((left, right) => right.mtimeMs - left.mtimeMs)
  return summaries
}

function findLatestPassing(summaries, target = '') {
  for (const summary of summaries) {
    if (summary.status !== 'passed') {
      continue
    }
    if (target !== '' && summary.target !== target) {
      continue
    }
    return summary
  }
  return null
}

function findLatest(summaries, target = '') {
  for (const summary of summaries) {
    if (target !== '' && summary.target !== target) {
      continue
    }
    return summary
  }
  return null
}

function buildCheck(level, name, ok, detail, artifact = null) {
  return {
    level,
    name,
    ok,
    detail,
    artifact
  }
}

function artifactFor(summary) {
  if (summary === null) {
    return null
  }
  return {
    summary: summary.relativePath,
    latestHtml: summary.latestHtml
  }
}

function main() {
  const authSummaries = getSummaries(authRoot, 'midscene-auth-regression-summary.md', 'auth')
  const focusedSummaries = getSummaries(focusedRoot, 'midscene-entrypoints-smoke-summary.md', 'focused')

  const latestAuthPass = findLatestPassing(authSummaries)
  const latestCurrentPlanPass = findLatestPassing(focusedSummaries, 'current-plan')
  const latestBothPass = findLatestPassing(focusedSummaries, 'both')
  const latestBothRun = findLatest(focusedSummaries, 'both')
  const latestBackupPass = findLatestPassing(focusedSummaries, 'backup-card')
  const latestMediaPass = findLatestPassing(focusedSummaries, 'media-card')

  const checks = []

  checks.push(
    latestAuthPass === null
      ? buildCheck('FAIL', 'auth-regression', false, 'No passing auth regression summary was found.')
      : buildCheck(
          'PASS',
          'auth-regression',
          true,
          `Latest passing auth regression: ${latestAuthPass.date}`,
          artifactFor(latestAuthPass)
        )
  )

  checks.push(
    latestCurrentPlanPass === null
      ? buildCheck('FAIL', 'current-plan-smoke', false, 'No passing current-plan focused smoke summary was found.')
      : buildCheck(
          'PASS',
          'current-plan-smoke',
          true,
          `Latest passing current-plan focused smoke: ${latestCurrentPlanPass.date}`,
          artifactFor(latestCurrentPlanPass)
        )
  )

  if (
    latestBothRun !== null &&
    latestBothRun.status === 'failed' &&
    latestBothRun.externalProviderBlocked &&
    latestBackupPass !== null &&
    latestMediaPass !== null
  ) {
    checks.push(
      buildCheck(
        'PASS',
        'review-exercise-evidence',
        true,
        `Latest both smoke is externally blocked by the Midscene provider; accepted split evidence from backup-card (${latestBackupPass.date}) and media-card (${latestMediaPass.date}).`,
        {
          blockerRun: latestBothRun.relativePath,
          backupSummary: latestBackupPass.relativePath,
          mediaSummary: latestMediaPass.relativePath
        }
      )
    )
  } else if (latestBothPass !== null) {
    checks.push(
      buildCheck(
        'PASS',
        'review-exercise-evidence',
        true,
        `Satisfied by a passing both smoke run from ${latestBothPass.date}.`,
        artifactFor(latestBothPass)
      )
    )
  } else {
    checks.push(
      buildCheck(
        'FAIL',
        'review-exercise-evidence',
        false,
        'Neither a passing both smoke run nor an accepted split backup/media evidence set is available.'
      )
    )
  }

  if (latestBothRun !== null && latestBothRun.status === 'failed' && latestBothRun.externalProviderBlocked) {
    checks.push(
      buildCheck(
        'WARN',
        'latest-both-run',
        false,
        'Latest both smoke failed because the external Midscene provider returned an overdue/403 error.',
        artifactFor(latestBothRun)
      )
    )
  } else if (latestBothRun !== null) {
    checks.push(
      buildCheck(
        latestBothRun.status === 'passed' ? 'PASS' : 'WARN',
        'latest-both-run',
        latestBothRun.status === 'passed',
        `Latest both smoke status: ${latestBothRun.status}.`,
        artifactFor(latestBothRun)
      )
    )
  }

  const overallPass = checks.filter((item) => item.level === 'FAIL').length === 0
  const payload = {
    status: overallPass ? 'passed' : 'failed',
    checks
  }

  if (outputJson) {
    console.log(JSON.stringify(payload, null, 2))
  } else {
    console.log('FitTracker closeout evidence')
    console.log('')
    for (const check of checks) {
      console.log(`[${check.level}] ${check.name}`)
      console.log(`  ${check.detail}`)
      if (check.artifact !== null) {
        for (const [key, value] of Object.entries(check.artifact)) {
          console.log(`  ${key}: ${value}`)
        }
      }
    }
    console.log('')
    console.log(`Conclusion: ${payload.status}`)
  }

  process.exit(overallPass ? 0 : 1)
}

main()
