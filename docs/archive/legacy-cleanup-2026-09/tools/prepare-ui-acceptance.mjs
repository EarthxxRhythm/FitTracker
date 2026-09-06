import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { spawnSync } from 'node:child_process'

const repoRoot = process.cwd()
const closeoutScript = resolve(repoRoot, 'tools', 'check-closeout-evidence.mjs')
const focusedRoot = resolve(repoRoot, 'midscene_run', 'focused')
const outputJson = process.argv.includes('--json')

function runCloseoutEvidence() {
  const result = spawnSync('node', [closeoutScript, '--json'], {
    cwd: repoRoot,
    encoding: 'utf8',
    shell: false
  })

  if (result.status !== 0) {
    throw new Error((result.stderr || result.stdout || 'Failed to run closeout evidence check.').trim())
  }

  return JSON.parse(result.stdout)
}

function findArtifact(checks, name) {
  for (const check of checks) {
    if (check.name === name) {
      return check.artifact ?? null
    }
  }
  return null
}

function walkSummaries(rootDir) {
  const result = spawnSync('powershell', [
    '-NoProfile',
    '-Command',
    `Get-ChildItem -Path '${rootDir}' -Recurse -Filter midscene-entrypoints-smoke-summary.md | Select-Object -ExpandProperty FullName`
  ], {
    cwd: repoRoot,
    encoding: 'utf8',
    shell: false
  })

  if (result.status !== 0) {
    throw new Error((result.stderr || result.stdout || 'Failed to enumerate focused summaries.').trim())
  }

  return result.stdout
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
}

function readSummary(fullPath) {
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

  return {
    fullPath,
    date: fields.date ?? '',
    status: fields.status ?? '',
    target: fields.target ?? '',
    latestHtml: fields['latest html'] ?? ''
  }
}

function findLatestPassingFocusedArtifact(target) {
  const paths = walkSummaries(focusedRoot)
  const summaries = paths.map((fullPath) => readSummary(fullPath))
  const filtered = summaries
    .filter((summary) => summary.status === 'passed' && summary.target === target)
    .sort((left, right) => right.date.localeCompare(left.date))

  if (filtered.length === 0) {
    return null
  }

  return {
    summary: filtered[0].fullPath.replace(`${repoRoot}\\`, '').replace(/\\/g, '/'),
    latestHtml: filtered[0].latestHtml
  }
}

function buildRoutePackets(evidence) {
  const authArtifact = findArtifact(evidence.checks, 'auth-regression')
  const currentPlanArtifact = findArtifact(evidence.checks, 'current-plan-smoke')
  const reviewExerciseArtifact = findArtifact(evidence.checks, 'review-exercise-evidence')
  const latestSummaryArtifact = findLatestPassingFocusedArtifact('summary-page')
  const latestBackupArtifact = findLatestPassingFocusedArtifact('backup-card')
  const latestMediaArtifact = findLatestPassingFocusedArtifact('media-card')
  const latestPlanDetailArtifact = findLatestPassingFocusedArtifact('plan-detail')
  const latestMembershipArtifact = findLatestPassingFocusedArtifact('membership')

  return [
    {
      route: 'LoginPage',
      order: 1,
      focus: ['auth entry feels compact', 'primary CTA is obvious'],
      evidence: [authArtifact]
    },
    {
      route: 'RegisterPage',
      order: 2,
      focus: ['register handoff matches login style', 'validation/status text feels intentional'],
      evidence: [authArtifact]
    },
    {
      route: 'GoalSetupPage',
      order: 3,
      focus: ['grouped choices scan cleanly', 'generate-plan is the terminal CTA'],
      evidence: [authArtifact]
    },
    {
      route: 'HomePage',
      order: 4,
      focus: ['today card dominates', 'preset plans remain secondary'],
      evidence: [currentPlanArtifact]
    },
    {
      route: 'WorkoutPreviewPage',
      order: 5,
      focus: ['preview continues naturally from home', 'start-training CTA dominates'],
      evidence: [currentPlanArtifact]
    },
    {
      route: 'ActiveWorkoutPage',
      order: 6,
      focus: ['execution screen feels focused', 'repeated inputs are visually stable'],
      evidence: [currentPlanArtifact]
    },
    {
      route: 'WorkoutSummaryPage',
      order: 7,
      focus: ['summary is calmer than active workout', 'closure feels intentional'],
      evidence: [latestSummaryArtifact]
    },
    {
      route: 'ReviewHomePage',
      order: 8,
      focus: ['dense but scannable', 'backup and upgrade entry do not compete with review content'],
      evidence: [latestBackupArtifact]
    },
    {
      route: 'ExerciseLibraryPage',
      order: 9,
      focus: ['filters feel practical', 'page still reads as part of the same app'],
      evidence: [latestMediaArtifact, reviewExerciseArtifact]
    },
    {
      route: 'ExerciseDetailPage',
      order: 10,
      focus: ['media card is instructional', 'premium content stays secondary'],
      evidence: [latestMediaArtifact, reviewExerciseArtifact]
    },
    {
      route: 'TrainingPlanDetailPage',
      order: 11,
      focus: ['plan structure is easy to scan', 'default enable path stays clearer than exploration'],
      evidence: [latestPlanDetailArtifact]
    },
    {
      route: 'MonetizationHubPage',
      order: 12,
      focus: ['reads as capability preview, not checkout theater', 'local preview language stays non-production'],
      evidence: [latestMembershipArtifact]
    }
  ]
}

function cleanEvidence(items) {
  const values = []
  for (const item of items) {
    if (item === null || item === undefined) {
      continue
    }
    values.push(item)
  }
  return values
}

function main() {
  const evidence = runCloseoutEvidence()
  const routePackets = buildRoutePackets(evidence).map((packet) => ({
    route: packet.route,
    order: packet.order,
    focus: packet.focus,
    evidence: cleanEvidence(packet.evidence)
  }))

  const payload = {
    status: evidence.status,
    prerequisites: [
      'node tools/check-closeout-evidence.mjs must pass',
      'device or simulator should be available at 127.0.0.1:5555',
      'use docs/ui-final-acceptance-runbook.md during the review',
      'record final results in docs/ui-acceptance-record-template.md'
    ],
    routePackets
  }

  if (outputJson) {
    console.log(JSON.stringify(payload, null, 2))
    return
  }

  console.log('FitTracker UI acceptance prep')
  console.log('')
  console.log(`closeout evidence: ${payload.status}`)
  console.log('')
  console.log('Prerequisites:')
  for (const line of payload.prerequisites) {
    console.log(`- ${line}`)
  }
  console.log('')
  for (const packet of payload.routePackets) {
    console.log(`${packet.order}. ${packet.route}`)
    console.log('  Focus:')
    for (const item of packet.focus) {
      console.log(`  - ${item}`)
    }
    if (packet.evidence.length > 0) {
      console.log('  Evidence:')
      for (const item of packet.evidence) {
        if (item.summary !== undefined) {
          console.log(`  - summary: ${item.summary}`)
        }
        if (item.latestHtml !== undefined) {
          console.log(`  - html: ${item.latestHtml}`)
        }
        if (item.backupSummary !== undefined) {
          console.log(`  - backupSummary: ${item.backupSummary}`)
        }
        if (item.mediaSummary !== undefined) {
          console.log(`  - mediaSummary: ${item.mediaSummary}`)
        }
        if (item.blockerRun !== undefined) {
          console.log(`  - blockerRun: ${item.blockerRun}`)
        }
      }
    }
    console.log('')
  }
}

main()
