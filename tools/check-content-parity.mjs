// check-content-parity.mjs —— 动作内容库三处计数对账（jsonl 权威源 ↔ Android 资产 ↔ seed SQL）
//
// 用法（从仓库根执行）：
//   node tools/check-content-parity.mjs            # 离线对账（jsonl ↔ Android 资产 ↔ seed 产物）
//   node tools/check-content-parity.mjs --remote   # 追加：SSH 到服务器对 cloud 表 COUNT 对账（需凭据）
//
// 计数口径（三处各自计数，同一批 id 才算对齐）：
//   jsonl     : apps/harmony/content/exercises/{muscles,equipment,exercises}.zh-CN.jsonl 行数
//   android   : apps/android/app/src/main/assets/exercise-content.json 的 muscles/equipment/exercises 数组长度
//   seed      : build/content/fittracker-content-seed.sql 中 INSERT INTO {muscles,equipment,exercises} 出现次数
//               （seed 由 apps/harmony/tools/content/export-db-seed.mjs 生成；产物未生成时该列为「未生成」，
//               不算失败——seed 是部署资产，源对账由前两处兜底）
//   cloud(--remote): 服务器 psql SELECT count(*) FROM public.{exercises,muscles,equipment}
//
// 任一可比的数字不一致 → 打印对照表并 exit 1（对账红线；2026-10-16 曾发生鸿蒙 102 vs Android 50 漂移）。
// 本工具是纯函数集合 + main 守卫，node:test 单测见 tools/check-content-parity.test.mjs。

import { existsSync, readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { spawnSync } from 'node:child_process'

export {
  countJsonlRows,
  countAndroidBundle,
  countSeedInserts,
  collectCounts,
  renderComparison,
}

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const HARMONY_CONTENT_DIR = resolve(root, 'apps/harmony/content/exercises')
const ANDROID_ASSET_PATH = resolve(root, 'apps/android/app/src/main/assets/exercise-content.json')
const SEED_PATH = resolve(root, 'apps/harmony/build/content/fittracker-content-seed.sql')

const TABLES = ['muscles', 'equipment', 'exercises']

/** 统计 JSONL 文本的非空行数（跳过空行；行内容不解析——计数对账只需要行数）。 */
function countJsonlRows(text) {
  let count = 0
  for (const line of text.split(/\r?\n/)) {
    if (line.trim().length > 0) {
      count += 1
    }
  }
  return count
}

/** 统计 Android 资产 bundle 的三个数组长度。 */
function countAndroidBundle(bundle) {
  return {
    muscles: Array.isArray(bundle.muscles) ? bundle.muscles.length : null,
    equipment: Array.isArray(bundle.equipment) ? bundle.equipment.length : null,
    exercises: Array.isArray(bundle.exercises) ? bundle.exercises.length : null,
  }
}

/** 统计 seed SQL 里各表 INSERT 出现次数。 */
function countSeedInserts(seedSql) {
  const counts = {}
  for (const table of TABLES) {
    const re = new RegExp(`INSERT\\s+INTO\\s+${table}\\s*\\(`, 'gi')
    const matches = seedSql.match(re)
    counts[table] = matches ? matches.length : 0
  }
  return counts
}

/** 汇总三处计数（seed 未生成时该处为 null）。 */
function collectCounts() {
  const jsonl = {}
  for (const table of TABLES) {
    const text = readFileSync(
      resolve(HARMONY_CONTENT_DIR, `${table}.zh-CN.jsonl`),
      'utf8'
    )
    jsonl[table] = countJsonlRows(text)
  }
  const android = countAndroidBundle(
    JSON.parse(readFileSync(ANDROID_ASSET_PATH, 'utf8'))
  )
  let seed = null
  if (existsSync(SEED_PATH)) {
    seed = countSeedInserts(readFileSync(SEED_PATH, 'utf8'))
  }
  return { jsonl, android, seed }
}

/** 生成对照表（markdown）。 */
function renderComparison(counts) {
  const lines = ['| 表 | jsonl（权威源） | android 资产 | seed SQL |', '|---|---|---|---|']
  for (const table of TABLES) {
    const seedCell = counts.seed === null ? '未生成' : String(counts.seed[table])
    lines.push(
      `| ${table} | ${counts.jsonl[table]} | ${counts.android[table]} | ${seedCell} |`
    )
  }
  return lines.join('\n')
}

/** 可比的数字不一致 → 返回 false；seed 未生成不算失败。 */
function isAligned(counts) {
  for (const table of TABLES) {
    if (counts.jsonl[table] !== counts.android[table]) {
      return false
    }
    if (counts.seed !== null && counts.seed[table] !== counts.jsonl[table]) {
      return false
    }
  }
  return true
}

function remoteCounts() {
  // ssh 到自托管服务器（106.55.37.80）对 public 三表 COUNT。
  const sql =
    "select 'muscles' as t, count(*) from public.muscles union all " +
    "select 'equipment', count(*) from public.equipment union all " +
    "select 'exercises', count(*) from public.exercises;"
  const result = spawnSync(
    'ssh',
    ['ubuntu@106.55.37.80',
      'sg docker -c "docker exec -i supabase-db psql -U postgres -d postgres -t -c ' + `"${sql}"` + '"'],
    { encoding: 'utf8', timeout: 30000 }
  )
  return result
}

function main() {
  const counts = collectCounts()
  console.log(renderComparison(counts))
  if (!isAligned(counts)) {
    console.error('✖ 三处计数不一致（对账红线）')
    process.exitCode = 1
    return
  }
  if (counts.seed === null) {
    console.log('注：seed SQL 未生成（部署资产，不算失败）；源对账 jsonl ↔ android 已一致。')
  }
  console.log('✓ 三处计数一致')
  if (process.argv.includes('--remote')) {
    const result = remoteCounts()
    if (result.status !== 0 || result.error) {
      console.error(`✖ 远程对账失败：${result.error ? result.error.message : result.stderr}`)
      process.exitCode = 1
      return
    }
    console.log('云端计数：\n' + result.stdout)
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main()
}
