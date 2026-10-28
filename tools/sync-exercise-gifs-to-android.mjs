#!/usr/bin/env node
/**
 * sync-exercise-gifs-to-android.mjs —— 把鸿蒙端的「实拍风格动作演示素材」同步到 Android 端。
 *
 * ## 为什么需要这个脚本
 *
 * 鸿蒙端的动作演示素材唯一来源是 free-exercise-db 实拍照合成的实拍素材（101 个）。
 * 旧线稿套系（23 个）已因授权问题从两端移除，其映射同时停用；Android 端此前手抄映射
 * 必然漂移，故做成脚本：以鸿蒙 `ExerciseGifCatalog.ets` 的 `EXERCISE_PHOTO_GIF_GROUPS`
 * 为唯一权威源，一次性产出「素材文件 + Kotlin 映射」两样东西。
 *
 * ## 产出
 *
 *   1. apps/android/app/src/main/assets/exercise-gifs-photo/<gifId>.gif  （101 个）
 *   2. apps/android/.../ui/screens/library/PhotoGifCatalog.kt          （生成文件，勿手改）
 *
 * ## 用法（从仓库根执行）
 *
 *   node tools/sync-exercise-gifs-to-android.mjs            # 执行同步
 *   node tools/sync-exercise-gifs-to-android.mjs --check    # 只校验两端是否一致（CI/抽查）
 *   node tools/sync-exercise-gifs-to-android.mjs --dry-run  # 只报计划，不写盘
 *
 * 退出码：0 = 成功/一致；1 = --check 发现漂移，或执行失败。
 *
 * ## 设计取舍
 *
 * - **两端解析规则一致**：都只查实拍组，未命中回退默认素材。线稿层已整体停用，
 *   不再参与解析（否则会截走本可用的实拍素材）。
 * - **映射按中文名**：Android 内容库的 exerciseId 是 `ex_xxx`，与素材文件名（kebab）
 *   是两套命名空间；其既有解析就是「id 命中 → 中文名命中 → 别名命中」，此处沿用。
 * - **生成 Kotlin 而非 JSON**：Android 运行时读 assets 需要 IO 与解析成本，而其既有
 *   素材映射本就是编译期常量；生成 Kotlin 与 `FtLibraryModel` 现有风格一致。
 */

import fs from 'node:fs'
import path from 'node:path'
import crypto from 'node:crypto'
import { fileURLToPath } from 'node:url'

const HERE = path.dirname(fileURLToPath(import.meta.url))
const REPO_ROOT = path.resolve(HERE, '..')

const HARMONY_CATALOG = path.join(
  REPO_ROOT, 'apps/harmony/entry/src/main/ets/shared/services/ExerciseGifCatalog.ets')
const HARMONY_GIF_DIR = path.join(
  REPO_ROOT, 'apps/harmony/entry/src/main/resources/rawfile/exercise-gifs-photo')
const ANDROID_ASSET_DIR = path.join(
  REPO_ROOT, 'apps/android/app/src/main/assets/exercise-gifs-photo')
const ANDROID_KOTLIN = path.join(
  REPO_ROOT, 'apps/android/app/src/main/java/com/fittracker/app/ui/screens/library/PhotoGifCatalog.kt')

/** 从鸿蒙 catalog 源码里取出实拍组的 gifId -> names。 */
function readHarmonyPhotoGroups() {
  const src = fs.readFileSync(HARMONY_CATALOG, 'utf8').replace(/\r\n/g, '\n')
  const start = src.indexOf('EXERCISE_PHOTO_GIF_GROUPS')
  if (start < 0) throw new Error('鸿蒙 catalog 中未找到 EXERCISE_PHOTO_GIF_GROUPS')
  // marker 后紧跟类型标注 ExerciseGifGroup[]，其 [] 不是数组本体，须从 '= [' 之后取起点。
  const eq = src.indexOf('= [', start)
  if (eq < 0) throw new Error('未找到实拍组的数组赋值')
  let depth = 0
  let end = -1
  for (let p = eq + 2; p < src.length; p++) {
    if (src[p] === '[') depth++
    else if (src[p] === ']') { depth--; if (depth === 0) { end = p; break } }
  }
  const body = src.slice(eq + 2, end + 1)
  const rows = []
  for (const m of body.matchAll(/\{\s*gifId:\s*'([^']+)',\s*names:\s*\[([^\]]*)\]/g)) {
    const names = m[2].split(',')
      .map((s) => s.trim().replace(/^'/, '').replace(/'$/, '').trim())
      .filter(Boolean)
    rows.push({ gifId: m[1], names })
  }
  if (rows.length === 0) throw new Error('实拍组解析结果为空，catalog 结构可能已变')
  return rows
}

/** 生成 Kotlin 源文件内容（幂等：同样输入必得同样字节）。 */
function renderKotlin(groups) {
  const entries = []
  for (const g of groups) {
    for (const n of g.names) {
      entries.push(`        "${n}" to "${g.gifId}",`)
    }
  }
  entries[entries.length - 1] = entries[entries.length - 1].replace(/,$/, '')
  return `// AUTO-GENERATED FILE — 请勿手工编辑。
// 由 tools/sync-exercise-gifs-to-android.mjs 从鸿蒙端
// apps/harmony/entry/src/main/ets/shared/services/ExerciseGifCatalog.ets
// 的 EXERCISE_PHOTO_GIF_GROUPS 生成，保证两端素材映射同源。
// 要改动请改鸿蒙侧再用脚本重生成。
package com.fittracker.app.ui.screens.library

/**
 * 实拍风格动作演示素材（free-exercise-db 实拍照合成）的「中文名 -> GIF 文件名」映射。
 *
 * 这是 Android 端唯一的一层素材映射：旧线稿层已随授权清理整体停用，
 * [FtLibraryModel.gifAssetFor] 只查本表，未命中回退占位块。
 *
 * 共 ${groups.length} 个素材 / ${entries.length} 个中文名（含别名）。
 */
object PhotoGifCatalog {
    /** 素材在 assets 下的目录名（对应源文件 assets/exercise-gifs-photo/<file>.gif）。 */
    const val ASSET_DIR: String = "exercise-gifs-photo"

    /** 动作中文名 -> GIF 文件名（不含扩展名）。 */
    val BY_NAME: Map<String, String> = mapOf(
${entries.join('\n')}
    )
}
`
}

function listGifFiles(dir) {
  if (!fs.existsSync(dir)) return []
  return fs.readdirSync(dir).filter((f) => f.toLowerCase().endsWith('.gif')).sort()
}

function sha256(file) {
  return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')
}

/** 校验 Android 端素材与映射是否与鸿蒙端一致；返回问题列表（空 = 一致）。 */
function check(groups, expectedKotlin) {
  const problems = []
  const srcFiles = listGifFiles(HARMONY_GIF_DIR)
  const dstFiles = listGifFiles(ANDROID_ASSET_DIR)

  if (srcFiles.length === 0) problems.push('鸿蒙实拍素材目录为空：' + HARMONY_GIF_DIR)

  const missing = srcFiles.filter((f) => !dstFiles.includes(f))
  if (missing.length > 0) problems.push(`Android 缺少 ${missing.length} 个素材：${missing.slice(0, 5).join(', ')}${missing.length > 5 ? ' …' : ''}`)

  const extra = dstFiles.filter((f) => !srcFiles.includes(f))
  if (extra.length > 0) problems.push(`Android 多出 ${extra.length} 个素材（鸿蒙侧已无）：${extra.slice(0, 5).join(', ')}${extra.length > 5 ? ' …' : ''}`)

  const changed = []
  for (const f of srcFiles) {
    if (!dstFiles.includes(f)) continue
    if (sha256(path.join(HARMONY_GIF_DIR, f)) !== sha256(path.join(ANDROID_ASSET_DIR, f))) changed.push(f)
  }
  if (changed.length > 0) problems.push(`${changed.length} 个素材内容不一致：${changed.slice(0, 5).join(', ')}${changed.length > 5 ? ' …' : ''}`)

  const kotlinCurrent = fs.existsSync(ANDROID_KOTLIN) ? fs.readFileSync(ANDROID_KOTLIN, 'utf8') : null
  if (kotlinCurrent === null) problems.push('Android 映射文件不存在：' + path.relative(REPO_ROOT, ANDROID_KOTLIN).replace(/\\/g, '/'))
  else if (kotlinCurrent.replace(/\r\n/g, '\n') !== expectedKotlin) problems.push('Android 映射文件内容与鸿蒙源不一致（需重新生成）')

  return { problems, srcCount: srcFiles.length, dstCount: dstFiles.length }
}

function main() {
  const dryRun = process.argv.includes('--dry-run')
  const checkOnly = process.argv.includes('--check')

  const groups = readHarmonyPhotoGroups()
  const expectedKotlin = renderKotlin(groups)
  const nameCount = groups.reduce((a, g) => a + g.names.length, 0)

  console.log(`鸿蒙实拍映射：${groups.length} 个素材 / ${nameCount} 个中文名`)

  if (checkOnly) {
    const { problems, srcCount, dstCount } = check(groups, expectedKotlin)
    console.log(`鸿蒙素材 ${srcCount} 个 / Android 素材 ${dstCount} 个`)
    if (problems.length === 0) {
      console.log('✓ 两端一致')
      return 0
    }
    console.log('✗ 发现漂移：')
    for (const p of problems) console.log('  - ' + p)
    return 1
  }

  if (dryRun) {
    const srcFiles = listGifFiles(HARMONY_GIF_DIR)
    console.log(`[dry-run] 将复制 ${srcFiles.length} 个素材 -> ${path.relative(REPO_ROOT, ANDROID_ASSET_DIR).replace(/\\/g, '/')}`)
    console.log(`[dry-run] 将写入映射 -> ${path.relative(REPO_ROOT, ANDROID_KOTLIN).replace(/\\/g, '/')}`)
    const { problems } = check(groups, expectedKotlin)
    console.log(`[dry-run] 当前漂移项 ${problems.length} 个`)
    return 0
  }

  // 1) 同步素材：以鸿蒙为准做「复制 + 删除多余」，使两端文件集合与内容严格一致。
  fs.mkdirSync(ANDROID_ASSET_DIR, { recursive: true })
  const srcFiles = listGifFiles(HARMONY_GIF_DIR)
  if (srcFiles.length === 0) throw new Error('鸿蒙实拍素材目录为空，拒绝把空目录同步过去：' + HARMONY_GIF_DIR)

  let copied = 0
  for (const f of srcFiles) {
    const from = path.join(HARMONY_GIF_DIR, f)
    const to = path.join(ANDROID_ASSET_DIR, f)
    const same = fs.existsSync(to) && sha256(from) === sha256(to)
    if (!same) {
      fs.copyFileSync(from, to)
      copied++
    }
  }
  let removed = 0
  for (const f of listGifFiles(ANDROID_ASSET_DIR)) {
    if (!srcFiles.includes(f)) {
      fs.rmSync(path.join(ANDROID_ASSET_DIR, f))
      removed++
    }
  }
  console.log(`素材：复制/更新 ${copied} 个，删除多余 ${removed} 个，共 ${srcFiles.length} 个`)

  // 2) 生成 Kotlin 映射
  const kotlinBefore = fs.existsSync(ANDROID_KOTLIN) ? fs.readFileSync(ANDROID_KOTLIN, 'utf8') : null
  if (kotlinBefore === null || kotlinBefore.replace(/\r\n/g, '\n') !== expectedKotlin) {
    fs.mkdirSync(path.dirname(ANDROID_KOTLIN), { recursive: true })
    fs.writeFileSync(ANDROID_KOTLIN, expectedKotlin, 'utf8')
    console.log('映射：已写入 ' + path.relative(REPO_ROOT, ANDROID_KOTLIN).replace(/\\/g, '/'))
  } else {
    console.log('映射：无变化')
  }

  // 3) 自校验
  const { problems } = check(groups, expectedKotlin)
  if (problems.length > 0) {
    console.log('✗ 同步后校验仍失败：')
    for (const p of problems) console.log('  - ' + p)
    return 1
  }
  console.log('✓ 同步完成，两端一致')
  return 0
}

const isDirectRun = process.argv[1] !== undefined &&
  path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url))

if (isDirectRun) {
  process.exit(main())
}
