#!/usr/bin/env node
/**
 * 从 free-exercise-db 取动作实拍照，合成「实拍风格」演示 GIF。
 *
 * 背景：内容库里有 102 条动作，但 rawfile/exercise-gifs 只有 23 组自制线稿演示素材，
 * 其余动作在训练执行页会回退到默认素材（杠铃卧推）。本脚本为缺素材的动作补实拍照。
 *
 * 与既有素材的关系（重要）：
 * - 既有 23 组是**自制人体线稿**，白底已被 build-exercise-gifs-onpage.py 按亮度
 *   软过渡合成到页面底色 #0B0F13，因此能与深色页面无缝。
 * - 实拍照**是全彩矩形实景，没有白底**，无法做同样的合成。故本脚本不做背景处理，
 *   改由消费端的圆角卡片容器承载（见 ActiveContent.demoVisual 的 border 说明）。
 *   这是两套素材的既定差异，不是待修复的缺陷。
 *
 * 源授权：free-exercise-db 主体为 Unlicense（公共领域）；图片授权口径已由项目负责人
 * 确认。接入内容数据层时须同步登记 coverSourceLabel / mediaLicenseText。
 *
 * 产物：entry/src/main/resources/rawfile/exercise-gifs-photo/<gifId>.gif
 * 依赖：ffmpeg 在 PATH 或 FFMPEG 环境变量；源 JSON 见 --input（默认走 ghproxy 拉取）。
 *
 * 用法：
 *   node tools/content/build-exercise-gifs-photo.mjs                  # 全量
 *   node tools/content/build-exercise-gifs-photo.mjs --only ex_dead_bug,ex_farmers_carry
 *   node tools/content/build-exercise-gifs-photo.mjs --input ./fedb.json   # 用本地源 JSON
 *   node tools/content/build-exercise-gifs-photo.mjs --dry-run        # 只报计划不产文件
 *
 * 关于本脚本里的 console.log：那是**面向使用者的 CLI 进度与结果输出**（每个动作的
 * 下载/合成状态、失败明细、体积汇总），与 build-content.mjs 同类，不是调试探针；
 * 退出码 0=全部成功、2=有失败项，供调用方判定。
 */

import fs from 'node:fs'
import path from 'node:path'
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const HERE = path.dirname(fileURLToPath(import.meta.url))
const HARMONY_ROOT = path.resolve(HERE, '..', '..')
const RAW_DIR = path.join(HARMONY_ROOT, 'entry/src/main/resources/rawfile')
const OUT_DIR = path.join(RAW_DIR, 'exercise-gifs-photo')
const CACHE_DIR = path.join(HARMONY_ROOT, '.cache/exercise-photo-src')

// 与消费端容器一致的输出规格：训练执行页 demoVisual 是 180×180 方形容器。
const SIZE = 180
// 三段乒乓的时间参数（秒）。
// - HOLD：每段的驻留时长（不含淡化段）
// - FADE：段间淡化时长
// 总时长 ≈ 3*HOLD + FADE。取 0.42/0.2 ≈ 1.46s，与改前两帧版（1.64s）同量级：
// 三帧结构本身会增加帧数，若沿用原 HOLD=0.65/FADE=0.35 总时长会到 2.3s，
// 实测单文件从 109KB 涨到 188KB（+73%），故压到当前值。
const FADE = 0.2
const HOLD = 0.42
const FPS = 14
// 调色板色数与抖动：180×180 下 192 色足够，体积与观感平衡（实测均值 ~120KB）。
const COLORS = 192
const BAYER = 3

const SOURCE_JSON_URL =
  'https://ghproxy.net/https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json'
const SOURCE_IMG_BASE = 'https://ghproxy.net/https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/'

function parseArgs(argv) {
  const out = { only: null, input: null, dryRun: false, force: false }
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]
    if (a === '--only' && argv[i + 1]) { out.only = argv[++i].split(',').map((s) => s.trim()).filter(Boolean) }
    else if (a === '--input' && argv[i + 1]) { out.input = argv[++i] }
    else if (a === '--dry-run') { out.dryRun = true }
    else if (a === '--force') { out.force = true }
  }
  return out
}

function findFfmpeg() {
  const candidates = [process.env.FFMPEG, 'ffmpeg'].filter(Boolean)
  for (const c of candidates) {
    try {
      execFileSync(c, ['-version'], { stdio: 'pipe' })
      return c
    } catch (e) { /* 试下一个 */ }
  }
  throw new Error('未找到 ffmpeg。请安装并加入 PATH，或用 FFMPEG=<路径> 指定。')
}

function sleep(ms) {
  execFileSync(process.execPath, ['-e', 'setTimeout(()=>{},' + ms + ')'], { stdio: 'pipe' })
}

/** 下载单文件，带重试（ghproxy 有 429 限流，退避后重试）。 */
function download(url, dest) {
  for (let attempt = 1; attempt <= 4; attempt++) {
    try {
      execFileSync('curl', ['-sS', '-f', '-L', '-o', dest, '--max-time', '60', url], { stdio: 'pipe' })
      const size = fs.statSync(dest).size
      if (size < 2000) throw new Error('响应过小 (' + size + ' 字节)，疑似限流')
      return size
    } catch (err) {
      fs.rmSync(dest, { force: true })
      if (attempt === 4) throw err
      const wait = 4000 * attempt
      console.log('      重试 ' + attempt + '/3（' + wait + 'ms 后）')
      sleep(wait)
    }
  }
  return 0
}

/**
 * 两帧源图 -> 三帧乒乓循环 -> 调色板量化 -> GIF。
 *
 * 为什么是乒乓而不是"混合出第三个姿态"：
 * free-exercise-db 每个动作只有 2 张照片（实测 876 条中 873 条恰为 2 张，无一条有 3 张），
 * 所以"第三个不同姿态"在素材层不存在。曾试过用 blend=average 把两图各 50% 合成中间帧，
 * 结果是**双重曝光鬼影**（两个半透明人影叠在一起），放大到 180×180 一眼可见，不可用。
 * 乒乓则是 A -> B -> A 的三段编排：两端都是清晰原图，零鬼影，同时修掉了原实现
 * 「B 直接跳回 A」的突兀（原版 loop 回跳是硬切）。
 *
 * 代价（如实记录）：不同画面仍是 2 个，只是时段变成 3 段。若日后要真正的 3 个不同姿态，
 * 只能换素材源（需每个动作 3 张照片的源，或自制拍摄）。
 *
 * 分两步：先出中间 mp4，再 palettegen/paletteuse（单步滤镜链会与 filter_complex 冲突）。
 */
function composeGif(ffmpeg, framePaths, outPath) {
  const mp4 = outPath.replace(/\.gif$/, '.tmp.mp4')
  const scaleTo = (inputIndex, label) =>
    '[' + inputIndex + ':v]scale=' + SIZE + ':' + SIZE + ':force_original_aspect_ratio=increase,' +
    'crop=' + SIZE + ':' + SIZE + ',setsar=1[' + label + ']'
  // 第一张图要用两次（开场与回程），故 split；第二张用一次。
  const filter =
    scaleTo(0, 'src0') + ';' +
    scaleTo(1, 'src1') + ';' +
    '[src0]split[a0][a2];' +
    // 每段驻留 HOLD 秒，段间以 FADE 秒淡化衔接：
    // 段1 A(0..HOLD) -> fade -> 段2 B -> fade -> 段3 A
    '[a0]fps=' + FPS + ',trim=duration=' + (HOLD + FADE) + ',setpts=PTS-STARTPTS[seg1];' +
    '[src1]fps=' + FPS + ',trim=duration=' + (HOLD + FADE) + ',setpts=PTS-STARTPTS[seg2];' +
    '[a2]fps=' + FPS + ',trim=duration=' + (HOLD + FADE) + ',setpts=PTS-STARTPTS[seg3];' +
    '[seg1][seg2]xfade=transition=fade:duration=' + FADE + ':offset=' + HOLD + '[x1];' +
    '[x1][seg3]xfade=transition=fade:duration=' + FADE + ':offset=' + (HOLD * 2) + '[v]'
  execFileSync(ffmpeg, ['-y', '-hide_banner', '-loglevel', 'error',
    '-loop', '1', '-t', '1', '-i', framePaths[0],
    '-loop', '1', '-t', '1', '-i', framePaths[1],
    '-filter_complex', filter,
    '-map', '[v]', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', mp4], { stdio: 'pipe' })
  execFileSync(ffmpeg, ['-y', '-hide_banner', '-loglevel', 'error', '-i', mp4,
    '-vf', 'split[s0][s1];[s0]palettegen=max_colors=' + COLORS + '[p];' +
      '[s1][p]paletteuse=dither=bayer:bayer_scale=' + BAYER,
    '-loop', '0', outPath], { stdio: 'pipe' })
  fs.rmSync(mp4, { force: true })
}

function countFrameBlocks(buf) {
  let n = 0
  for (let i = 0; i < buf.length - 2; i++) {
    if (buf[i] === 0x21 && buf[i + 1] === 0xf9 && buf[i + 2] === 0x04) n++
  }
  return n
}

function main() {
  const opts = parseArgs(process.argv.slice(2))
  const mapPath = path.join(HERE, 'exercise-photo-sources.json')
  const map = JSON.parse(fs.readFileSync(mapPath, 'utf8'))
  let sources = map.sources
  if (opts.only) {
    sources = sources.filter((s) => opts.only.includes(s.exerciseId) || opts.only.includes(s.fedbId))
    if (sources.length === 0) {
      console.error('--only 未匹配到任何条目')
      return 1
    }
  }

  const usable = sources.filter((s) => s.available !== false && s.fedbId)
  const skipped = sources.filter((s) => s.available === false || !s.fedbId)
  console.log('映射条目 ' + sources.length + '，可产素材 ' + usable.length + '，跳过 ' + skipped.length)
  for (const s of skipped) console.log('  跳过 ' + s.nameZh + '：' + (s.note || '无 fedbId'))

  if (opts.dryRun) {
    console.log('\n[dry-run] 将处理：')
    for (const s of usable) console.log('  ' + s.exerciseId + ' -> ' + s.fedbId)
    return 0
  }

  // 源元数据：优先本地，否则走代理拉取（带缓存）。
  let db
  if (opts.input) {
    db = JSON.parse(fs.readFileSync(opts.input, 'utf8'))
    console.log('源元数据：' + opts.input + '（' + db.length + ' 条）')
  } else {
    const cached = path.join(CACHE_DIR, 'exercises.json')
    fs.mkdirSync(CACHE_DIR, { recursive: true })
    if (!fs.existsSync(cached) || opts.force) {
      console.log('拉取源元数据…')
      download(SOURCE_JSON_URL, cached)
    }
    db = JSON.parse(fs.readFileSync(cached, 'utf8'))
    console.log('源元数据：缓存（' + db.length + ' 条）')
  }

  const ffmpeg = findFfmpeg()
  fs.mkdirSync(OUT_DIR, { recursive: true })
  fs.mkdirSync(CACHE_DIR, { recursive: true })

  const report = []
  const failures = []
  for (const item of usable) {
    const entry = db.find((x) => x.id === item.fedbId)
    if (!entry) {
      console.error('✗ 源中无 id：' + item.fedbId + '（' + item.nameZh + '）')
      failures.push({ ...item, reason: '源中无此 id' })
      continue
    }
    const rels = entry.images || []
    if (rels.length < 2) {
      console.error('✗ 源图不足两帧：' + item.fedbId + '（' + rels.length + '）')
      failures.push({ ...item, reason: '源图不足两帧' })
      continue
    }

    const gifId = item.exerciseId.replace(/^ex_/, '').replace(/_/g, '-')
    const outPath = path.join(OUT_DIR, gifId + '.gif')
    if (fs.existsSync(outPath) && !opts.force) {
      const size = fs.statSync(outPath).size
      console.log('  = ' + gifId + ' 已存在，跳过（' + (size / 1024).toFixed(1) + ' KB）')
      report.push({ gifId, fedbId: item.fedbId, bytes: size, reused: true })
      continue
    }

    const frames = []
    let ok = true
    for (let i = 0; i < 2; i++) {
      const dest = path.join(CACHE_DIR, item.fedbId + '-' + i + '.jpg')
      if (!fs.existsSync(dest) || opts.force) {
        try {
          const size = download(SOURCE_IMG_BASE + 'exercises/' + rels[i], dest)
          console.log('    ' + item.fedbId + ' 帧' + i + ' ' + (size / 1024).toFixed(1) + ' KB')
          sleep(2500)
        } catch (err) {
          console.error('✗ 下载失败 ' + rels[i] + '：' + String(err.message).slice(0, 80))
          failures.push({ ...item, reason: '下载失败' })
          ok = false
          break
        }
      }
      frames.push(dest)
    }
    if (!ok) continue

    try {
      composeGif(ffmpeg, frames, outPath)
    } catch (err) {
      console.error('✗ 合成失败 ' + gifId + '：' + String(err.message).slice(0, 120))
      failures.push({ ...item, reason: '合成失败' })
      continue
    }
    const buf = fs.readFileSync(outPath)
    const size = buf.length
    const frames_n = countFrameBlocks(buf)
    const head = buf.subarray(0, 6).toString('latin1')
    console.log('  ✓ ' + gifId + '.gif  ' + (size / 1024).toFixed(1) + ' KB  帧块=' + frames_n + '  头=' + head)
    report.push({ gifId, fedbId: item.fedbId, bytes: size, frames: frames_n, head })
  }

  const produced = report.filter((r) => !r.reused)
  const totalBytes = report.reduce((a, b) => a + b.bytes, 0)
  console.log('\n=== 汇总 ===')
  console.log('产出 ' + produced.length + ' 个，跳过/复用 ' + report.filter((r) => r.reused).length +
    ' 个，失败 ' + failures.length + ' 个')
  if (report.length > 0) {
    console.log('平均体积 ' + (totalBytes / report.length / 1024).toFixed(1) + ' KB' +
      '，目录总计 ' + (totalBytes / 1048576).toFixed(2) + ' MB')
  }
  console.log('输出目录 ' + path.relative(HARMONY_ROOT, OUT_DIR).replace(/\\/g, '/'))
  if (failures.length > 0) {
    console.log('\n失败明细：')
    for (const f of failures) console.log('  ' + f.nameZh + '（' + f.exerciseId + '）：' + f.reason)
  }
  fs.writeFileSync(path.join(CACHE_DIR, 'last-report.json'),
    JSON.stringify({ generatedAt: new Date().toISOString(), report, failures }, null, 2))
  return failures.length > 0 ? 2 : 0
}

process.exit(main())
