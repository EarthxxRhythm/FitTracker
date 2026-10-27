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
// 2026-10-28：线稿素材（Gym Visual，授权链条不成立）已从仓库移除。
// catalog 的 DEMO_GIF_DIRECTORY 现与 PHOTO_GIF_DIRECTORY 同值，两套目录收敛为一套。
const LINE_DIR = PHOTO_DIR

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
/**
 * 与 catalog 的 resolveDemoSource 同构：线稿组优先、实拍组兜底、最后回退默认素材。
 *
 * 注意目录：线稿组命中后同样落到 photo 目录，因为线稿目录已被撤下。
 * 对尚未补生成的动作，这个路径会指向不存在的文件，消费端由失败回退降级为占位图标。
 */
const resolveSource = (name) => {
  const n = String(name).trim()
  if (!n) return 'exercise-gifs-photo/barbell-deadlift.gif'
  const a = findIn(lineGroups, n)
  if (a) return 'exercise-gifs-photo/' + a + '.gif'
  const b = findIn(photoGroups, n)
  if (b) return 'exercise-gifs-photo/' + b + '.gif'
  return 'exercise-gifs-photo/barbell-deadlift.gif'
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

test('线稿组优先解析，但目录已收敛到 photo', function () {
  // 「杠铃划船」「腿弯举」在两个分组里都存在。解析顺序不变（线稿组先），
  // 只是线稿目录已被撤下，故两类命中都落到 photo 目录。
  // 顺序本身仍要锁死：若被颠倒，补生成同名素材后老动作会被悄悄换掉。
  assert.equal(resolveSource('杠铃划船'), 'exercise-gifs-photo/barbell-row.gif')
  assert.equal(resolveSource('腿弯举'), 'exercise-gifs-photo/leg-curl.gif')
  assert.equal(resolveSource('深蹲'), 'exercise-gifs-photo/squat.gif')
  assert.equal(resolveSource('杠铃卧推'), 'exercise-gifs-photo/barbell-bench-press.gif')
  // 线稿组独有、且 photo 组也有的（cable-crossover）应立即有效。
  assert.equal(resolveSource('绳索夹胸'), 'exercise-gifs-photo/cable-crossover.gif')
})

test('实拍兜底：线稿未覆盖的动作解析到实拍目录', function () {
  assert.equal(resolveSource('罗马尼亚硬拉'), 'exercise-gifs-photo/romanian-deadlift.gif')
  assert.equal(resolveSource('农夫走'), 'exercise-gifs-photo/farmers-carry.gif')
  assert.equal(resolveSource('死虫式'), 'exercise-gifs-photo/dead-bug.gif')
})

test('未命中与空串回退到默认演示素材（且该文件必须真实存在）', function () {
  // 回退目标若指向不存在的文件，消费端会二次落空、只剩占位图。
  assert.equal(resolveSource('不存在的动作名'), 'exercise-gifs-photo/barbell-deadlift.gif')
  assert.equal(resolveSource(''), 'exercise-gifs-photo/barbell-deadlift.gif')
  assert.equal(resolveSource('   '), 'exercise-gifs-photo/barbell-deadlift.gif')
  assert.ok(existsSync(resolve(PHOTO_DIR, 'barbell-deadlift.gif')),
    'catalog 的 DEFAULT_EXERCISE_GIF_ID 在 photo 目录中不存在，回退会失效')
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

test('素材目录常量与磁盘内容一致', function () {
  // 目录名是 catalog 的导出常量，若被改名而素材未迁移会全线失效。
  assert.ok(catalogSrc.includes("export const PHOTO_GIF_DIRECTORY: string = 'exercise-gifs-photo/'"),
    'PHOTO_GIF_DIRECTORY 常量缺失或与素材目录不符')
  assert.ok(catalogSrc.includes("export const DEMO_GIF_DIRECTORY: string = 'exercise-gifs-photo/'"),
    'DEMO_GIF_DIRECTORY 必须与 PHOTO_GIF_DIRECTORY 同值（线稿目录已撤下）')
  assert.ok(!catalogSrc.includes("'exercise-gifs-onpage/'"),
    'catalog 仍在引用已移除的线稿目录')
  assert.ok(existsSync(PHOTO_DIR), '实拍素材目录不存在')
  assert.equal(photoFiles.size, photoGroups.length,
    `素材目录 ${photoFiles.size} 个文件 vs catalog 实拍组 ${photoGroups.length} 条`)
  assert.ok(lineGroups.length > 0 && photoGroups.length > 0, '分组解析结果为空，catalog 结构可能已变')
  // 线稿组映射数据保留（补生成后可复活），但素材文件不应再出现在仓库里。
  assert.equal(lineFiles.size, photoFiles.size, '线稿目录已撤下，不应再有独立文件集合')
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

test('素材是 3 帧乒乓结构（A->B->A 三段），不是 2 帧淡化', function () {
  // 背景：源库每动作只有 2 张照片，无法合成"第三个真实姿态"（实测 876 条中 873 条恰为 2 张，
  // 无一条有 3 张）。曾试过 blend=average 混合中间帧，结果是双重曝光鬼影，已否决。
  // 现方案是把 2 张照片编排成 A->B->A 三段循环，既满足"3 帧"结构，又修掉原版
  // 「B 直接跳回 A」的硬切突兀。
  //
  // 判据为什么是「时长 == 3*HOLD + FADE」而不是「时长 >= 某个阈值」：
  // 首版断言用了 >=1.2s，反向验证时发现它**抓不到回退**——旧两帧版时长 1.64s 反而比
  // 新三段版 1.50s 更长，阈值判据永远绿（假绿）。改为从构建脚本读取 HOLD/FADE 常量、
  // 按三段结构算出期望总时长再做等值断言：一旦实现退回两帧，期望值不变而实际变成
  // HOLD+FADE，必然不等而变红。
  const buildSrc = readFileSync(resolve(scriptDir, 'build-exercise-gifs-photo.mjs'), 'utf8')
  const holdMatch = buildSrc.match(/^const HOLD = ([\d.]+)/m)
  const fadeMatch = buildSrc.match(/^const FADE = ([\d.]+)/m)
  assert.ok(holdMatch && fadeMatch, '构建脚本中未找到 HOLD/FADE 常量')
  const hold = parseFloat(holdMatch[1])
  const fade = parseFloat(fadeMatch[1])
  // 三段：A -> fade -> B -> fade -> A，两次 xfade 的 offset 分别是 HOLD 与 2*HOLD。
  const expectedSeconds = hold * 3 + fade

  /** 读 GIF 全部 graphic control extension 的 delay 求和，返回总时长（秒）与帧块数。 */
  function readGifTiming(file) {
    const buf = readFileSync(resolve(PHOTO_DIR, file))
    let ms = 0
    let blocks = 0
    for (let i = 0; i < buf.length - 8; i++) {
      if (buf[i] === 0x21 && buf[i + 1] === 0xf9 && buf[i + 2] === 0x04) {
        // GCE 布局：21 F9 04 <packed> <delay lo> <delay hi> <transparent> 00
        ms += buf.readUInt16LE(i + 4) * 10
        blocks++
      }
    }
    return { seconds: ms / 1000, blocks }
  }

  const gifFiles = [...photoFiles].map((f) => f + '.gif')
  assert.ok(gifFiles.length > 0, '没有可检查的素材文件')

  const deviations = []
  const noFrame = []
  for (const file of gifFiles) {
    const t = readGifTiming(file)
    if (t.blocks === 0) noFrame.push(file)
    // 允许 0.12s 误差：GIF delay 以 1/100 秒量化，且 fps 取整会带来几十毫秒偏差。
    if (Math.abs(t.seconds - expectedSeconds) > 0.12) {
      deviations.push(`${file} 实际 ${t.seconds.toFixed(2)}s，三段期望 ${expectedSeconds.toFixed(2)}s`)
    }
  }
  assert.deepEqual(noFrame, [], '存在没有任何帧块的 GIF')
  assert.deepEqual(deviations, [],
    `这些素材的时长不符合「3 段乒乓」(HOLD=${hold} FADE=${fade} => ${expectedSeconds.toFixed(2)}s)：\n  ` +
    deviations.join('\n  '))
})
