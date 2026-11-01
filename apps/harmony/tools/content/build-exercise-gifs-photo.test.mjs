//
// build-exercise-gifs-photo 的合成法回归测试（TDD 先行）。
//
// 为什么存在：composeShowcaseGif 是「2 照 → 光流插帧 → 乒乓无缝循环 → GIF」的新合成链，
// 其产物不变量（帧块数、时长、无缝循环、尺寸、护栏）必须在每次改动后能被秒级复算。
// 既有 exercise-photo-sources.test.mjs 只守护 app 素材目录的三方一致与乒乓结构，
// 不覆盖 showcase 链——本文件补上这一半。
//
// 判据设计纪律（沿用既有测试注释的教训）：所有阈值/期望值都从 build 脚本常量推导，
// 不做「容易假绿」的宽松阈值；帧级判据用 framemd5 逐帧哈希，
// 防「首帧==末帧但中间是一帧停顿」的假乒乓发绿灯。
//
// fixture：优先复用 apps/harmony/.cache/exercise-photo-src/ 的既有源图（真实素材，
// 内容有差异才测得出插帧）；缓存缺失时用 ffmpeg lavfi 生成两帧带图案样本。
// 不触网络。
//
// 运行：cd apps/harmony && node --test tools/content/build-exercise-gifs-photo.test.mjs

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { readFileSync, existsSync, mkdtempSync, readdirSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, resolve, join } from 'node:path'
import { fileURLToPath } from 'node:url'

import { composeGif, composeShowcaseGif, parseArgs, assertShowcaseOutAllowed } from './build-exercise-gifs-photo.mjs'

const scriptDir = dirname(fileURLToPath(import.meta.url))
const harmonyRoot = resolve(scriptDir, '../..')
const repoRoot = resolve(harmonyRoot, '../..')
const CACHE_DIR = join(harmonyRoot, '.cache/exercise-photo-src')

const HOLD = 0.42
const FADE = 0.2

/** 探测 ffmpeg；缺失返回 null（CI 兼容：不 throw，由各测试 t.skip 降级）。 */
function findFfmpeg() {
  const r = spawnSync('ffmpeg', ['-version'], { stdio: 'pipe' })
  if (r.status === 0) return 'ffmpeg'
  return null
}

/** 临时工作目录（测试结束整体清理）。 */
function makeTmpDir() {
  const d = mkdtempSync(join(tmpdir(), 'gif-synth-test-'))
  return d
}

/** 两帧真实源图（缓存缺失或 ffmpeg 不可用时返回 null，由调用方 skip）。 */
function ensureFramePair(ffmpeg, dir) {
  if (!ffmpeg) return null
  if (existsSync(CACHE_DIR)) {
    const cached = readdirSync(CACHE_DIR).filter((f) => /-\d\.jpg$/.test(f))
    const base = cached[0] && cached[0].replace(/-\d\.jpg$/, '')
    if (base) {
      const a = join(CACHE_DIR, base + '-0.jpg')
      const b = join(CACHE_DIR, base + '-1.jpg')
      if (existsSync(a) && existsSync(b)) return [a, b]
    }
  }
  // 合成：白底 + 位置不同的黑色方块，保证两帧有真实差异。
  const a = join(dir, 'syn-a.png')
  const b = join(dir, 'syn-b.png')
  spawnSync(ffmpeg, ['-y', '-hide_banner', '-loglevel', 'error', '-f', 'lavfi',
    '-i', 'color=c=white:s=480x480', '-frames:v', '1', '-vf', 'drawbox=x=60:y=60:w=120:h=120:color=black:t=fill', a],
    { stdio: 'pipe' })
  spawnSync(ffmpeg, ['-y', '-hide_banner', '-loglevel', 'error', '-f', 'lavfi',
    '-i', 'color=c=white:s=480x480', '-frames:v', '1', '-vf', 'drawbox=x=300:y=300:w=120:h=120:color=black:t=fill', b],
    { stdio: 'pipe' })
  assert.ok(existsSync(a) && existsSync(b), '合成 fixture 失败')
  return [a, b]
}

/** 读 GIF 全部 graphic control extension：返回 { blocks, seconds }。 */
function readGifTiming(file) {
  const buf = readFileSync(file)
  let ms = 0
  let blocks = 0
  for (let i = 0; i < buf.length - 8; i++) {
    if (buf[i] === 0x21 && buf[i + 1] === 0xf9 && buf[i + 2] === 0x04) {
      ms += buf.readUInt16LE(i + 4) * 10
      blocks++
    }
  }
  return { blocks, seconds: ms / 1000 }
}

/** 逐帧 md5（ffmpeg framemd5 输出 CSV：stream, dts, pts, dur, size, hash），返回哈希数组。 */
function readFrameHashes(ffmpeg, file) {
  const r = spawnSync(ffmpeg, ['-v', 'error', '-i', file, '-map', '0:v', '-f', 'framemd5', '-'],
    { stdio: ['ignore', 'pipe', 'pipe'] })
  assert.equal(r.status, 0, 'framemd5 解析失败：' + r.stderr.toString())
  const out = r.stdout.toString()
  return [...out.matchAll(/,\s*([0-9a-f]{32})\s*$/gm)].map((m) => m[1])
}

/** 读 GIF 逻辑屏幕宽度（LSW 位于偏移 6-7，小端）。 */
function readGifWidth(file) {
  const buf = readFileSync(file)
  assert.ok(buf.subarray(0, 6).toString('latin1').startsWith('GIF8'), '非 GIF 文件')
  return buf.readUInt16LE(6)
}

const ffmpeg = findFfmpeg()
const tmp = makeTmpDir()

test('showcase GIF：帧块数 ≥16 且总时长 ≥1.5s（插帧生效，非 2 帧乒乓）', function (t) {
  if (!ffmpeg) { t.skip('ffmpeg 缺失（CI 降级）'); return }
  const [a, b] = ensureFramePair(ffmpeg, tmp)
  const out = join(tmp, 'showcase.gif')
  composeShowcaseGif(ffmpeg, [a, b], out, { size: 480 })
  const timing = readGifTiming(out)
  assert.ok(timing.blocks >= 16, `帧块数 ${timing.blocks} 应 ≥16`)
  assert.ok(timing.seconds >= 1.5, `总时长 ${timing.seconds.toFixed(2)}s 应 ≥1.5s`)
})

/** 两帧 PSNR（dB）：GIF 差异编码/抖动会带来少量量化噪声，无缝判据用阈值而非哈希相等。 */
function psnrBetween(ffmpeg, a, b) {
  const r = spawnSync(ffmpeg, ['-hide_banner', '-i', a, '-i', b, '-filter_complex', 'psnr', '-f', 'null', '-'],
    { stdio: ['ignore', 'pipe', 'pipe'] })
  const m = r.stderr.toString().match(/average:([\d.]+)/)
  assert.ok(m, 'PSNR 未输出：' + r.stderr.toString().slice(0, 200))
  return parseFloat(m[1])
}

test('showcase GIF：首末帧无缝（PSNR ≥40dB）且无连续 3 帧停顿', function (t) {
  if (!ffmpeg) { t.skip('ffmpeg 缺失（CI 降级）'); return }
  const [a, b] = ensureFramePair(ffmpeg, tmp)
  const out = join(tmp, 'showcase-loop.gif')
  composeShowcaseGif(ffmpeg, [a, b], out, { size: 480 })
  const hashes = readFrameHashes(ffmpeg, out)
  assert.ok(hashes.length >= 16, `帧数 ${hashes.length} 应 ≥16`)
  // 循环无缝：reverse 拼接保证源视频首末同帧，GIF 层允许量化噪声，40dB ≈ 不可感知。
  const first = join(tmp, 'loop-first.png')
  const last = join(tmp, 'loop-last.png')
  spawnSync(ffmpeg, ['-v', 'error', '-i', out, '-frames:v', '1', first], { stdio: 'pipe' })
  spawnSync(ffmpeg, ['-v', 'error', '-sseof', '-0.05', '-i', out, '-frames:v', '1', last], { stdio: 'pipe' })
  assert.ok(existsSync(first) && existsSync(last), '首末帧导出失败')
  const psnr = psnrBetween(ffmpeg, first, last)
  assert.ok(psnr >= 40, `首末帧 PSNR ${psnr.toFixed(2)}dB 应 ≥40dB（循环有跳变）`)
  // 防「单帧停顿式假乒乓」：不允许连续 3 帧完全相同。
  for (let i = 0; i + 2 < hashes.length; i++) {
    assert.ok(!(hashes[i] === hashes[i + 1] && hashes[i + 1] === hashes[i + 2]),
      `第 ${i} 帧起连续 3 帧相同——疑似单帧停顿式假乒乓`)
  }
})

test('showcase GIF：尺寸 == --size（默认 480）', function (t) {
  if (!ffmpeg) { t.skip('ffmpeg 缺失（CI 降级）'); return }
  const [a, b] = ensureFramePair(ffmpeg, tmp)
  const out = join(tmp, 'showcase-size.gif')
  composeShowcaseGif(ffmpeg, [a, b], out, { size: 480 })
  assert.equal(readGifWidth(out), 480, '宽度应 480')
})

test('app profile：产物时长与 HOLD/FADE 三段公式等值（现状回归）', function (t) {
  if (!ffmpeg) { t.skip('ffmpeg 缺失（CI 降级）'); return }
  const [a, b] = ensureFramePair(ffmpeg, tmp)
  const out = join(tmp, 'app.gif')
  composeGif(ffmpeg, [a, b], out)
  const timing2 = readGifTiming(out)
  const expected = HOLD * 3 + FADE
  assert.ok(Math.abs(timing2.seconds - expected) <= 0.12,
    `实际 ${timing2.seconds.toFixed(2)}s，三段期望 ${expected.toFixed(2)}s`)
})

test('--bg white：python+rembg 缺失时降级（不抛错）', function (t) {
  if (!ffmpeg) { t.skip('ffmpeg 缺失（CI 降级）'); return }
  const probe = spawnSync('python', ['-c', 'import rembg'], { stdio: 'pipe' })
  if (probe.status === 0) {
    t.skip('本机有 python+rembg，白底降级路径不适用')
    return
  }
  const opts = parseArgs(['--profile', 'showcase', '--bg', 'white', '--dry-run'])
  assert.equal(opts.bg, 'white', '参数应被解析')
  // 白底在 composeShowcaseGif 内探测环境后降级：直接跑一次，要求不抛错即可。
  const [a, b] = ensureFramePair(ffmpeg, tmp)
  const out = join(tmp, 'showcase-bg.gif')
  assert.doesNotThrow(function () {
    composeShowcaseGif(ffmpeg, [a, b], out, { size: 480, bg: 'white' })
  }, '白底降级路径不应抛错')
})

test('--out 白名单护栏：拒绝仓库素材目录', function () {
  assert.equal(assertShowcaseOutAllowed(join(repoRoot, 'test_run/showcase-gifs')), true,
    'test_run/ 下必须允许')
  assert.equal(assertShowcaseOutAllowed(join(harmonyRoot, 'entry/src/main/resources/rawfile')), false,
    'resources/ 下必须拒绝')
  assert.equal(assertShowcaseOutAllowed(join(repoRoot, 'apps/android/app/src/main/assets')), false,
    'Android assets/ 下必须拒绝')
})

test('接口契约：脚本导出合成函数且 import 不触发 main', function () {
  assert.equal(typeof composeGif, 'function')
  assert.equal(typeof composeShowcaseGif, 'function')
  assert.equal(typeof parseArgs, 'function')
})

test('收尾：清理临时目录', function () {
  rmSync(tmp, { recursive: true, force: true })
  assert.ok(!existsSync(tmp))
})
