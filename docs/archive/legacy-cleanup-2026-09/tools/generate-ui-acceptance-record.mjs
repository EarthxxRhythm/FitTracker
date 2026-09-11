import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { spawnSync } from 'node:child_process'

const repoRoot = process.cwd()
const prepScript = resolve(repoRoot, 'tools', 'prepare-ui-acceptance.mjs')
const sampleExportScript = resolve(repoRoot, 'tools', 'export-ui-acceptance-samples.mjs')
const outputJson = process.argv.includes('--json')

function runAcceptancePrep() {
  const result = spawnSync('node', [prepScript, '--json'], {
    cwd: repoRoot,
    encoding: 'utf8',
    shell: false
  })

  if (result.status !== 0) {
    throw new Error((result.stderr || result.stdout || 'Failed to run acceptance prep.').trim())
  }

  return JSON.parse(result.stdout)
}

function runSampleExport() {
  const result = spawnSync('node', [sampleExportScript, '--json'], {
    cwd: repoRoot,
    encoding: 'utf8',
    shell: false
  })

  if (result.status !== 0) {
    throw new Error((result.stderr || result.stdout || 'Failed to export acceptance samples.').trim())
  }

  return JSON.parse(result.stdout)
}

function summaryLine(items) {
  if (items.length === 0) {
    return '- evidence summary: none'
  }

  if (items.length === 1) {
    return `- evidence summary: ${items[0]}`
  }

  return `- evidence summary: ${items.join(' | ')}`
}

function htmlLine(items) {
  if (items.length === 0) {
    return '- evidence html: none'
  }

  if (items.length === 1) {
    return `- evidence html: ${items[0]}`
  }

  return `- evidence html: ${items.join(' | ')}`
}

function focusLine(items) {
  if (items.length === 0) {
    return '- review focus: none'
  }
  return `- review focus: ${items.join(' ; ')}`
}

function collectEvidence(packet) {
  const summaries = []
  const htmls = []

  for (const item of packet.evidence) {
    if (typeof item.summary === 'string' && item.summary.length > 0) {
      summaries.push(item.summary)
    }
    if (typeof item.backupSummary === 'string' && item.backupSummary.length > 0) {
      summaries.push(item.backupSummary)
    }
    if (typeof item.mediaSummary === 'string' && item.mediaSummary.length > 0) {
      summaries.push(item.mediaSummary)
    }
    if (typeof item.latestHtml === 'string' && item.latestHtml.length > 0) {
      htmls.push(item.latestHtml)
    }
    if (typeof item.blockerRun === 'string' && item.blockerRun.length > 0) {
      summaries.push(`blocked refresh reference: ${item.blockerRun}`)
    }
  }

  return {
    summaries,
    htmls
  }
}

function routeSection(packet) {
  const evidence = collectEvidence(packet)
  return [
    `### ${packet.route}`,
    '',
    '- visual consistency: pending human review',
    '- flow clarity: pending human review',
    '- interaction polish: pending human review',
    '- product tone: pending human review',
    focusLine(packet.focus),
    summaryLine(evidence.summaries),
    htmlLine(evidence.htmls),
    `- sample first image: ${packet.sampleFirstImage ?? 'none'}`,
    `- sample last image: ${packet.sampleLastImage ?? 'none'}`,
    `- matched execution: ${packet.matchedExecutionName ?? 'none'}`,
    '- machine evidence status: backed by existing closeout artifacts',
    '- notes:',
    '- blocking issue:',
    ''
  ].join('\n')
}

function buildRecord(prep) {
  const lines = []
  lines.push('# FitTracker UI Acceptance Record')
  lines.push('')
  lines.push('Date: pending')
  lines.push('Reviewer: pending')
  lines.push('Device: 127.0.0.1:5555 or equivalent HarmonyOS device/simulator')
  lines.push('Build: latest internal closeout unsigned HAP')
  lines.push('')
  lines.push('## Overall Decision')
  lines.push('')
  lines.push('- overall result: pending human review')
  lines.push('- blocking issues count: pending')
  lines.push('- non-blocking notes count: pending')
  lines.push('- prerequisite evidence gate: passed via `node tools/check-closeout-evidence.mjs`')
  lines.push('- generated from: `node tools/generate-ui-acceptance-record.mjs`')
  lines.push('')
  lines.push('## Route Records')
  lines.push('')

  for (const packet of prep.routePackets) {
    lines.push(routeSection(packet))
  }

  lines.push('## Final Notes')
  lines.push('')
  lines.push('- strongest route:')
  lines.push('- weakest route:')
  lines.push('- is the app visually coherent end-to-end: pending human review')
  lines.push('- does the monetization surface remain secondary: pending human review')
  lines.push('- does the app feel ready for closeout: pending human review')
  lines.push('')
  lines.push('## Reviewer Instructions')
  lines.push('')
  lines.push('- fill only the human-review fields above')
  lines.push('- if no blocking issue is found on a route, leave `blocking issue:` blank')
  lines.push('- keep notes limited to visible hierarchy, flow, and polish observations')
  return `${lines.join('\n')}\n`
}

function main() {
  const prep = runAcceptancePrep()
  const samples = runSampleExport()
  const sampleMap = new Map()
  for (const route of samples.routes) {
    sampleMap.set(route.route, route)
  }
  const prepWithSamples = {
    ...prep,
    routePackets: prep.routePackets.map((packet) => ({
      ...packet,
      sampleFirstImage: sampleMap.has(packet.route) ? sampleMap.get(packet.route).firstImage : null,
      sampleLastImage: sampleMap.has(packet.route) ? sampleMap.get(packet.route).lastImage : null,
      matchedExecutionName: sampleMap.has(packet.route) ? sampleMap.get(packet.route).matchedExecutionName : null
    }))
  }
  const record = buildRecord(prepWithSamples)

  if (outputJson) {
    console.log(
      JSON.stringify(
        {
          status: prep.status,
          record
        },
        null,
        2
      )
    )
    return
  }

  process.stdout.write(record)
}

main()
