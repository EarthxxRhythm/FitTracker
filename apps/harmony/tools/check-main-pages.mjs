import { existsSync, readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const pagesProfilePath = resolve(root, 'entry/src/main/resources/base/profile/main_pages.json')
const sourceRoot = resolve(root, 'entry/src/main/ets')

function fail(message) {
  throw new Error(`[main_pages] ${message}`)
}

function readMainPages() {
  const text = readFileSync(pagesProfilePath, 'utf8')
  const profile = JSON.parse(text)
  if (!Array.isArray(profile.src)) {
    fail(`${pagesProfilePath} must contain a src array`)
  }
  return profile.src
}

function countEntryDecorators(text) {
  const matches = text.match(/@Entry\b/g)
  return matches === null ? 0 : matches.length
}

const pages = readMainPages()
for (const page of pages) {
  if (typeof page !== 'string' || page.trim().length === 0) {
    fail('src entries must be non-empty strings')
  }

  const pagePath = resolve(sourceRoot, `${page}.ets`)
  if (!existsSync(pagePath)) {
    fail(`${page} points to missing file ${pagePath}`)
  }

  const text = readFileSync(pagePath, 'utf8')
  const entryCount = countEntryDecorators(text)
  if (entryCount !== 1) {
    fail(`${pagePath} must have exactly one @Entry decorator, found ${entryCount}`)
  }
}

console.log(`Checked ${pages.length} registered pages in ${pagesProfilePath}`)
