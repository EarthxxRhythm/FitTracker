//
// exercise-photo-sources / build-exercise-gifs-photo 的回归测试。
//
// 背景：内容库 102 条动作中原本只有 42 条有演示素材（自制线稿），其余在训练执行页
// 回退到默认卧推演示。本管线用 free-exercise-db 实拍照补齐缺口，产物为
// rawfile/exercise-gifs-photo/*.gif，由 ExerciseGifCatalog 的实拍组消费。
//
// 为什么这么测：映射表是人工核对的**数据契约**，素材是**离线产物**——两者都容易在
// 后续维护中悄悄漂移（改了映射忘了重跑、删了素材忘了改映射）。因此断言落在
// 「映射 <-> 素材文件 <-> catalog 表」三方一致与关键解析语义上，而不是跑一遍下载
// （那需要网络与限流，不适合作为门禁）。
//
// 覆盖的三个真实风险：
//   1. 映射条目指向不存在的素材文件（消费端会回退，缺口被静默掩盖）
//   2. catalog 的实拍组与映射表脱节（新增映射但没重新生成 catalog）
//   3. 线稿优先的解析顺序被破坏（老动作被实拍素材顶替，视觉回归）
//
// 与 ohosTest 的 ExerciseGifCatalog.test.ets 分工：那边验证 ArkTS 解析函数的运行时语义，
// 这边验证构建期数据与磁盘产物的一致性——两边都不能省。
//
// 运行：node --test tools/content/exercise-photo-sources.test.mjs

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync, readdirSync, existsSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptDir = dirname(fileURLToPath(import.meta.url))
const harmonyRoot = resolve(scriptDir, '../..')
const repoRoot = resolve(harmonyRoot, '../..')

const MAP_PATH = resolve(scriptDir, 'exercise-photo-sources.json')
const CATALOG_PATH = resolve(harmonyRoot, 'entry/src/main/ets/shared/services/ExerciseGifCatalog.ets')
const JSONL_PATH = resolve(harmonyRoot, 'content/exercises/exercises.zh-CN.jsonl')
const PHOTO_DIR = resolve(harmonyRoot, 'entry/src/main/resources/rawfile/exercise-gifs-photo')
const LINE_DIR = resolve(harmonyRoot, 'entry/src/main/resources/rawfile/exercise-gifs-onpage')

/** 内容库 exerciseId(ex_xxx_yyy) -> 素材文件名(xxx-yyy)，与 catalog 实现同一规则。 */
function gifIdOf(exerciseId) {
  return exerciseId.replace(/^ex_/, '').replace(/_/g, '-')
}

const map = JSON.parse(readFileSync(MAP_PATH, 'utf8'))
const usable = map.sources.filter((s) => s.available !== false && s.fedbId)
const skipped = map.sources.filter((s) => s.available === false || !s.fedbId)
const catalogSrc = readFileSync(CATALOG_PATH, 'utf8').replace(/\r\n/g, '\n')
const lib = readFileSync(JSONL_PATH, 'utf8').trim().split('\n').map((l) => JSON.parse(l))
const libById = new Map(lib.map((e) => [e.exerciseId, e]))
const photoFiles = new Set(readdirSync(PHOTO_DIR).map((f) => f.replace(/\.gif$/, '')))
const lineFiles = new Set(readdirSync(LINE_DIR).map((f) => f.replace(/\.gif$/, '')))

/** 从 catalog 源码里取出某个分组的 gifId -> names。 */
function parseGroups(marker) {
  const start = catalogSrc.indexOf(marker)
  assert.ok(start >= 0, 'catalog 中未找到分组: ' + marker)
  // marker 后紧跟类型标注 ExerciseGifGroup[]，其 [] 不是数组本体，须从 '= [' 起取。
  const open = catalogSrc.indexOf('= [', start) + 2
  assert.ok(open > 1, 'catalog 分组未找到数组起点: ' + marker)
  let depth = 0, end = -1
  for (let p = open; p < catalogSrc.length; p++) {
    if (catalogSrc[p] === '[') depth++
    else if (catalogSrc[p] === ']') { depth--; if (depth === 0) { end = p; break } }
  }
  const body = catalogSrc.slice(open, end + 1)
  const out = []
  for (const m of body.matchAll(/\{\s*gifId:\s*'([^']+)',\s*names:\s*\[([^\]]*)\]/g)) {
    out.push({
      gifId: m[1],
      names: m[2].split(',').map((s) => s.trim().replace(/^'/, '').replace(/'$/, '').trim()).filter(Boolean),
    })
  }
  return out
}

const lineGroups = parseGroups('EXERCISE_GIF_GROUPS: ExerciseGifGroup[] = [')
const photoGroups = parseGroups('EXERCISE_PHOTO_GIF_GROUPS: ExerciseGifGroup[] = [')

const findIn = (groups, name) => {
  for (const g of groups) if (g.names.indexOf(name) >= 0) return g.gifId
  return ''
}
/** 与 catalog 的 resolveDemoSource 同构：线稿优先，实拍兜底，最后默认素材。 */
const resolveSource = (name) => {
  const n = String(name).trim()
  if (!n) return 'exercise-gifs-onpage/barbell-bench-press.gif'
  const a = findIn(lineGroups, n)
  if (a) return 'exercise-gifs-onpage/' + a + '.gif'
  const b = findIn(photoGroups, n)
  if (b) return 'exercise-gifs-photo/' + b + '.gif'
  return 'exercise-gifs-onpage/barbell-bench-press.gif'
}

test('映射表的每条可用条目都能在内容库里找到，且互不重复', function () {
  const seen = new Set()
  for (const s of usable) {
    assert.ok(libById.has(s.exerciseId), '内容库无此 exerciseId: ' + s.exerciseId)
    assert.ok(!seen.has(s.exerciseId), 'exerciseId 重复: ' + s.exerciseId)
    seen.add(s.exerciseId)
  }
  // 跳过的条目必须写明原因，避免「静默缺失」被当成已完成。
  for (const s of skipped) {
    assert.ok(s.note && s.note.length > 0, '标记 unavailable 的条目缺少原因说明: ' + s.exerciseId)
  }
  assert.ok(usable.length >= 59, '可用映射条目数异常偏少: ' + usable.length)
})

test('每条映射对应一个真实存在的素材文件（无缺口、无孤儿）', function () {
  const missing = usable.filter((s) => !photoFiles.has(gifIdOf(s.exerciseId))).map((s) => gifIdOf(s.exerciseId))
  assert.deepEqual(missing, [], '映射有、素材文件缺失: ' + missing.join(', '))

  const expected = new Set(usable.map((s) => gifIdOf(s.exerciseId)))
  const orphan = [...photoFiles].filter((f) => !expected.has(f))
  assert.deepEqual(orphan, [], '素材目录有、映射表无（孤儿文件）: ' + orphan.join(', '))
})

test('catalog 的实拍组与映射表逐一对应，不多不少', function () {
  assert.equal(photoGroups.length, usable.length,
    `catalog 实拍组 ${photoGroups.length} 条 vs 映射表 ${usable.length} 条——改了映射须重新生成 catalog`)
  const catalogIds = photoGroups.map((g) => g.gifId).sort()
  const mapIds = usable.map((s) => gifIdOf(s.exerciseId)).sort()
  assert.deepEqual(catalogIds, mapIds, 'catalog 实拍组的 gifId 集合与映射表不一致')
})

test('catalog 实拍组的每个条目都至少有一个中文名', function () {
  for (const g of photoGroups) {
    assert.ok(g.names.length > 0, '实拍组条目无中文名: ' + g.gifId)
    assert.ok(g.names[0].trim().length > 0, '实拍组条目首个中文名为空: ' + g.gifId)
  }
})

test('线稿优先：既有素材对应的动作不被实拍素材顶替', function () {
  // 「杠铃划船」「腿弯举」在两个分组里都存在（内容库与 free-exercise-db 指向同一动作）。
  // 解析顺序若被颠倒，老动作的演示图会被悄悄换掉——这是视觉回归，必须锁死。
  assert.equal(resolveSource('杠铃划船'), 'exercise-gifs-onpage/barbell-row.gif')
  assert.equal(resolveSource('腿弯举'), 'exercise-gifs-onpage/leg-curl.gif')
  assert.equal(resolveSource('深蹲'), 'exercise-gifs-onpage/squat.gif')
  assert.equal(resolveSource('杠铃卧推'), 'exercise-gifs-onpage/barbell-bench-press.gif')
})

test('实拍兜底：线稿未覆盖的动作解析到实拍目录', function () {
  assert.equal(resolveSource('罗马尼亚硬拉'), 'exercise-gifs-photo/romanian-deadlift.gif')
  assert.equal(resolveSource('农夫走'), 'exercise-gifs-photo/farmers-carry.gif')
  assert.equal(resolveSource('死虫式'), 'exercise-gifs-photo/dead-bug.gif')
})

test('未命中与空串回退到默认演示素材', function () {
  assert.equal(resolveSource('不存在的动作名'), 'exercise-gifs-onpage/barbell-bench-press.gif')
  assert.equal(resolveSource(''), 'exercise-gifs-onpage/barbell-bench-press.gif')
  assert.equal(resolveSource('   '), 'exercise-gifs-onpage/barbell-bench-press.gif')
})

test('内容库覆盖率不低于 101/102（本管线的核心收益）', function () {
  let lineHit = 0, photoHit = 0
  const miss = []
  for (const e of lib) {
    const n = e.nameZh.trim()
    if (findIn(lineGroups, n)) lineHit++
    else if (findIn(photoGroups, n)) photoHit++
    else miss.push(e.exerciseId + '/' + e.nameZh)
  }
  assert.equal(lineHit + photoHit, 101,
    `覆盖率 ${lineHit + photoHit}/102（线稿 ${lineHit} + 实拍 ${photoHit}）；未覆盖: ${miss.join(', ')}`)
  // 唯一允许的缺口必须是源库确实没有的动作。
  assert.deepEqual(miss, ['ex_bird_dog/鸟狗式'],
    '未覆盖集合与预期不符（源库无鸟狗式，其余应全部覆盖）')
})

test('两个素材目录的文件与各自目录常量声明一致', function () {
  // 目录名是 catalog 的导出常量，若被改名而素材未迁移会全线失效。
  assert.ok(catalogSrc.includes("export const PHOTO_GIF_DIRECTORY: string = 'exercise-gifs-photo/'"),
    'PHOTO_GIF_DIRECTORY 常量缺失或与素材目录不符')
  assert.ok(catalogSrc.includes("export const DEMO_GIF_DIRECTORY: string = 'exercise-gifs-onpage/'"),
    'DEMO_GIF_DIRECTORY 常量缺失或与素材目录不符')
  assert.ok(existsSync(PHOTO_DIR), '实拍素材目录不存在')
  assert.ok(existsSync(LINE_DIR), '线稿素材目录不存在')
  assert.equal(lineFiles.size, lineGroups.length,
    `线稿目录 ${lineFiles.size} 个文件 vs catalog ${lineGroups.length} 条`)
  assert.ok(lineGroups.length > 0 && photoGroups.length > 0, '分组解析结果为空，catalog 结构可能已变')
})

test('映射表声明了素材来源与授权口径', function () {
  // 项目原则：不引入未经授权的素材，接入时须登记来源与许可。
  const readme = (map._readme || []).join(' ')
  assert.ok(readme.includes('free-exercise-db'), '映射表未声明素材来源')
  assert.ok(readme.includes('Unlicense'), '映射表未声明许可类型')
  assert.ok(readme.includes('coverSourceLabel'), '映射表未记录接入时需登记来源字段')
  // 每条可用条目的 fedbId 都应非空（空值会让构建脚本静默跳过）。
  for (const s of usable) {
    assert.ok(s.fedbId && s.fedbId.length > 0, '可用条目缺少 fedbId: ' + s.exerciseId)
  }
})
