import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { basename, extname, resolve } from 'node:path'
import { spawnSync } from 'node:child_process'

const repoRoot = process.cwd()
const prepScript = resolve(repoRoot, 'tools', 'prepare-ui-acceptance.mjs')
const outputRoot = resolve(repoRoot, 'midscene_run', 'ui_acceptance_samples')
const manifestPath = resolve(outputRoot, 'manifest.json')
const outputJson = process.argv.includes('--json')

const routeExecutionMatchers = {
  LoginPage: [],
  RegisterPage: ['Assert - The register page is visible and shows the phone, password, and confirm password fields.'],
  GoalSetupPage: ['goal setup page'],
  HomePage: ['Assert - The FitTracker home page is visible. It shows the current enabled preset plan'],
  WorkoutPreviewPage: ['Assert - The FitTracker workout preview screen is visible.'],
  ActiveWorkoutPage: ['Assert - The active workout execution screen is visible.'],
  WorkoutSummaryPage: ['Assert - The workout summary page is visible.'],
  ReviewHomePage: ['Assert - The training review page is visible.'],
  ExerciseLibraryPage: ['Assert - The exercise library page is visible.'],
  ExerciseDetailPage: ['Assert - The exercise detail page is visible.', 'Assert - The exercise detail page shows the media section'],
  TrainingPlanDetailPage: ['Assert - The training plan detail page is visible.'],
  MonetizationHubPage: ['Assert - The membership page remains visible and shows that the current entitlement or preview state is Pro.']
}

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

function parseMidsceneImages(html) {
  const imageMap = new Map()
  const regex = /<script type="midscene-image" data-id="([0-9a-f\-]{36})">([\s\S]*?)<\/script>/g
  let match = regex.exec(html)
  while (match !== null) {
    const id = match[1]
    const dataUri = match[2].trim()
    const prefixMatch = dataUri.match(/^data:image\/(png|jpeg);base64,(.+)$/)
    if (prefixMatch) {
      imageMap.set(id, prefixMatch[2])
    }
    match = regex.exec(html)
  }
  return imageMap
}

function collectScreenshotRefsFromTask(task, bucket) {
  if (task.uiContext && isScreenshotRef(task.uiContext.screenshot)) {
    bucket.push(task.uiContext.screenshot)
  }

  if (!Array.isArray(task.recorder)) {
    return
  }

  for (const item of task.recorder) {
    if (item && item.type === 'screenshot' && isScreenshotRef(item.screenshot)) {
      bucket.push(item.screenshot)
    }
  }
}

function isScreenshotRef(value) {
  return (
    value !== null &&
    typeof value === 'object' &&
    value.type === 'midscene_screenshot_ref' &&
    typeof value.id === 'string' &&
    typeof value.mimeType === 'string'
  )
}

function parseWebDumps(html) {
  const regex = /<script type="midscene_web_dump"[^>]*>([\s\S]*?)<\/script>/g
  const dumps = []
  let match = regex.exec(html)

  while (match !== null) {
    const raw = match[1].trim()
    if (raw.startsWith('{')) {
      dumps.push(JSON.parse(raw))
    }
    match = regex.exec(html)
  }

  return dumps
}

function collectOrderedRefs(dumps) {
  const refs = []
  for (const dump of dumps) {
    if (!Array.isArray(dump.executions)) {
      continue
    }

    for (const execution of dump.executions) {
      if (!Array.isArray(execution.tasks)) {
        continue
      }

      for (const task of execution.tasks) {
        collectScreenshotRefsFromTask(task, refs)
      }
    }
  }
  return refs
}

function collectExecutionSamples(dumps, imageMap) {
  const values = []
  for (const dump of dumps) {
    if (!Array.isArray(dump.executions)) {
      continue
    }

    for (const execution of dump.executions) {
      const refs = uniqueRefsWithImages(collectOrderedRefs([{ executions: [execution] }]), imageMap)
      values.push({
        name: execution.name || '',
        refs
      })
    }
  }
  return values
}

function uniqueRefsWithImages(refs, imageMap) {
  const values = []
  const seen = new Set()

  for (const ref of refs) {
    if (seen.has(ref.id)) {
      continue
    }
    if (!imageMap.has(ref.id)) {
      continue
    }
    seen.add(ref.id)
    values.push(ref)
  }

  return values
}

function extensionForMimeType(mimeType) {
  if (mimeType === 'image/png') {
    return 'png'
  }
  return 'jpeg'
}

function safeStem(reportPath) {
  const name = basename(reportPath)
  const suffix = extname(name)
  if (suffix.length === 0) {
    return name
  }
  return name.slice(0, -suffix.length)
}

function exportRefImage(ref, base64, stem, label) {
  const extension = extensionForMimeType(ref.mimeType)
  const fileName = `${stem}-${label}.${extension}`
  const fullPath = resolve(outputRoot, fileName)
  const buffer = Buffer.from(base64, 'base64')
  writeFileSync(fullPath, buffer)
  return fullPath
}

function exportSamplesForReport(reportPath) {
  const html = readFileSync(reportPath, 'utf8')
  const imageMap = parseMidsceneImages(html)
  const dumps = parseWebDumps(html)
  const refs = uniqueRefsWithImages(collectOrderedRefs(dumps), imageMap)
  const executions = collectExecutionSamples(dumps, imageMap)
  const stem = safeStem(reportPath)

  if (refs.length === 0) {
    return {
      reportPath,
      screenshotCount: 0,
      firstImage: null,
      lastImage: null,
      executions
    }
  }

  const firstRef = refs[0]
  const lastRef = refs[refs.length - 1]
  const firstImage = exportRefImage(firstRef, imageMap.get(firstRef.id), stem, 'first')
  const lastImage = exportRefImage(lastRef, imageMap.get(lastRef.id), stem, 'last')

  return {
    reportPath,
    screenshotCount: refs.length,
    firstImage,
    lastImage,
    executions
  }
}

function collectReportPaths(prep) {
  const values = []
  const seen = new Set()

  for (const packet of prep.routePackets) {
    for (const evidence of packet.evidence) {
      const htmlCandidates = []
      if (typeof evidence.latestHtml === 'string' && evidence.latestHtml.length > 0) {
        htmlCandidates.push(evidence.latestHtml)
      }
      if (typeof evidence.backupLatestHtml === 'string' && evidence.backupLatestHtml.length > 0) {
        htmlCandidates.push(evidence.backupLatestHtml)
      }
      if (typeof evidence.mediaLatestHtml === 'string' && evidence.mediaLatestHtml.length > 0) {
        htmlCandidates.push(evidence.mediaLatestHtml)
      }

      for (const htmlPath of htmlCandidates) {
        if (seen.has(htmlPath)) {
          continue
        }
        seen.add(htmlPath)
        values.push(htmlPath)
      }
    }
  }

  return values
}

function buildRouteSamples(prep, reportManifest) {
  const reportMap = new Map()
  for (const item of reportManifest) {
    reportMap.set(item.reportPath, item)
  }

  return prep.routePackets.map((packet) => {
    let sample = null
    for (const evidence of packet.evidence) {
      const htmlCandidates = []
      if (typeof evidence.latestHtml === 'string' && evidence.latestHtml.length > 0) {
        htmlCandidates.push(evidence.latestHtml)
      }
      if (typeof evidence.backupLatestHtml === 'string' && evidence.backupLatestHtml.length > 0) {
        htmlCandidates.push(evidence.backupLatestHtml)
      }
      if (typeof evidence.mediaLatestHtml === 'string' && evidence.mediaLatestHtml.length > 0) {
        htmlCandidates.push(evidence.mediaLatestHtml)
      }

      for (const htmlPath of htmlCandidates) {
        if (reportMap.has(htmlPath)) {
          sample = reportMap.get(htmlPath)
          break
        }
      }

      if (sample !== null) {
        break
      }
    }

    return {
      route: packet.route,
      order: packet.order,
      firstImage: sample ? pickRouteImage(packet.route, sample, 'first') : null,
      lastImage: sample ? pickRouteImage(packet.route, sample, 'last') : null,
      screenshotCount: sample ? sample.screenshotCount : 0,
      matchedExecutionName: sample ? findMatchingExecutionName(packet.route, sample) : null
    }
  })
}

function findMatchingExecution(route, reportSample) {
  const matchers = routeExecutionMatchers[route] ?? []
  if (matchers.length === 0 || !Array.isArray(reportSample.executions)) {
    return null
  }

  for (const execution of reportSample.executions) {
    for (const matcher of matchers) {
      if (execution.name.includes(matcher) && execution.refs.length > 0) {
        return execution
      }
    }
  }

  return null
}

function findMatchingExecutionName(route, reportSample) {
  const execution = findMatchingExecution(route, reportSample)
  return execution === null ? null : execution.name
}

function pickRouteImage(route, reportSample, edge) {
  const execution = findMatchingExecution(route, reportSample)
  if (execution === null) {
    return edge === 'first' ? reportSample.firstImage : reportSample.lastImage
  }

  const ref = edge === 'first' ? execution.refs[0] : execution.refs[execution.refs.length - 1]
  const imageMap = new Map()
  imageMap.set(ref.id, null)
  const stem = safeStem(reportSample.reportPath)
  const label = `${route}-${edge}`
  const html = readFileSync(reportSample.reportPath, 'utf8')
  const fullImageMap = parseMidsceneImages(html)
  return exportRefImage(ref, fullImageMap.get(ref.id), stem, label)
}

function main() {
  mkdirSync(outputRoot, { recursive: true })

  const prep = runAcceptancePrep()
  const reportManifest = collectReportPaths(prep).map((reportPath) => exportSamplesForReport(reportPath))
  const routeSamples = buildRouteSamples(prep, reportManifest)
  const compactReports = reportManifest.map((item) => ({
    reportPath: item.reportPath,
    screenshotCount: item.screenshotCount,
    firstImage: item.firstImage,
    lastImage: item.lastImage,
    executionCount: Array.isArray(item.executions) ? item.executions.length : 0
  }))

  const payload = {
    status: prep.status,
    outputRoot,
    manifestPath,
    reports: compactReports,
    routes: routeSamples
  }

  writeFileSync(manifestPath, `${JSON.stringify(payload, null, 2)}\n`, 'utf8')

  if (outputJson) {
    console.log(JSON.stringify(payload, null, 2))
    return
  }

  console.log('FitTracker UI acceptance samples')
  console.log(`status: ${payload.status}`)
  console.log(`output: ${outputRoot}`)
  console.log('')

  for (const route of routeSamples) {
    console.log(`${route.order}. ${route.route}`)
    console.log(`  screenshots: ${route.screenshotCount}`)
    if (route.firstImage !== null) {
      console.log(`  first: ${route.firstImage}`)
    }
    if (route.lastImage !== null) {
      console.log(`  last: ${route.lastImage}`)
    }
  }
}

main()
