//
// build-exercise-gifs-3d 的合成法回归测试（TDD 先行）。
//
// 守护 3D 演示 GIF 工作流的不变量：帧结构（25fps/40ms 定版 50 帧）、无缝循环、
// 白底、尺寸、画面保真。判据全部从脚本常量推导；
// isSeamlessLoop 抽成纯函数并附四反例，反例必须 false（可证伪性由反例保证）。
//
// 编码/解码 oracle = ffmpeg（2026-11-01 四 oracle 实测后的决策：自写 LZW 与 gifenc
// 的码流在 GDI+/Chrome 下静默解出错误画面，ffmpeg 产出的 app 素材三 oracle 全兼容，
// 故编码与像素断言统一走 ffmpeg；GDI+/Chrome 兼容由「与 app 素材同源」背书）。
// ffmpeg 缺失时相关测试显式 skip（CI 兼容，与 photo 测试同模式）。
//
// 运行：cd apps/harmony && node --test tools/content/build-exercise-gifs-3d.test.mjs

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { readFileSync, existsSync, mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, resolve, join } from 'node:path'
import { fileURLToPath } from 'node:url'

import {
  isSeamlessLoop,
  renderPoseFrames,
  encodeGif,
  indicesToRgb,
  FRAME_COUNT,
  FRAME_DELAY_CS,
  SIZE
} from './3d/engine.mjs'

const scriptDir = dirname(fileURLToPath(import.meta.url))

function findFfmpeg() {
  const r = spawnSync('ffmpeg', ['-version'], { stdio: 'pipe' })
  return r.status === 0 ? 'ffmpeg' : null
}

const ffmpeg = findFfmpeg()

// ── 纯函数组：isSeamlessLoop 四反例 ──────────────────────────────

test('isSeamlessLoop：正常乒乓序列通过（正例）', function () {
  const frames = []
  for (let i = 0; i < FRAME_COUNT; i++) {
    frames.push(i <= 25 ? i : 50 - i)
  }
  assert.equal(isSeamlessLoop(frames), true, '正常乒乓应通过')
})

test('isSeamlessLoop 反例1：wrap 跳变必须 false', function () {
  const frames = []
  for (let i = 0; i < FRAME_COUNT; i++) {
    frames.push(i <= 25 ? i : 50 - i)
  }
  frames[49] = 25
  assert.equal(isSeamlessLoop(frames), false, 'wrap 跳变必须被拦')
})

test('isSeamlessLoop 反例2：全静止序列必须 false', function () {
  const frames = new Array(FRAME_COUNT).fill(5)
  assert.equal(isSeamlessLoop(frames), false, '全静止必须被拦（活动性前置）')
})

test('isSeamlessLoop 反例3：端点重复停顿必须 false', function () {
  const frames = []
  for (let i = 0; i < FRAME_COUNT; i++) {
    frames.push(i <= 25 ? i : 49 - i)
  }
  frames[49] = frames[0]
  assert.equal(isSeamlessLoop(frames), false, '端点重复停顿必须被拦')
})

test('isSeamlessLoop 反例4：硬切无插值必须 false', function () {
  const frames = new Array(FRAME_COUNT).fill(0)
  for (let i = 20; i < FRAME_COUNT; i++) frames[i] = 100
  assert.equal(isSeamlessLoop(frames), false, '硬切无插值必须被拦')
})

// ── ffmpeg 解码 helper ─────────────────────────────────────────

/** 用 ffmpeg 把 GIF 解码为 rawvideo RGB，返回每帧 Buffer。 */
function decodeWithFfmpeg(gifPath, size) {
  const r = spawnSync('ffmpeg', ['-v', 'error', '-i', gifPath, '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'],
    { stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 128 * 1024 * 1024 })
  assert.equal(r.status, 0, 'ffmpeg 解码失败：' + r.stderr.toString().slice(0, 200))
  const total = r.stdout.length
  const frameBytes = size * size * 3
  assert.equal(total % frameBytes, 0, '解码输出长度与帧尺寸不符')
  const n = total / frameBytes
  const frames = []
  for (let i = 0; i < n; i++) frames.push(r.stdout.subarray(i * frameBytes, (i + 1) * frameBytes))
  return frames
}

// ── 产物组：测试内自渲染（mkdtemp tmpdir，绝不读 test_run/）─────

test('自渲染产物：帧块 50 / 总时长 2000ms / 尺寸 480 / 白底四角 / 无缝 / 画面保真', function (t) {
  if (!ffmpeg) { t.skip('ffmpeg 缺失（CI 降级）'); return }
  const tmp = mkdtempSync(join(tmpdir(), 'gif3d-test-'))
  try {
    const out = join(tmp, 'probe.gif')
    const frames = renderPoseFrames(posesForProbe(), { size: SIZE })
    assert.equal(frames.length, FRAME_COUNT, `应渲染 ${FRAME_COUNT} 帧`)
    encodeGif(frames, { width: SIZE, height: SIZE, delays: frames.map(() => FRAME_DELAY_CS), outPath: out })
    assert.ok(existsSync(out), 'GIF 未落盘')

    const buf = readFileSync(out)
    // 尺寸：LSW 在偏移 6-7
    assert.equal(buf.readUInt16LE(6), SIZE, '宽度应 480')
    // 帧块与总时长：GCE 扫描
    let blocks = 0
    let ms = 0
    for (let i = 0; i < buf.length - 8; i++) {
      if (buf[i] === 0x21 && buf[i + 1] === 0xf9 && buf[i + 2] === 0x04) {
        ms += buf.readUInt16LE(i + 4) * 10
        blocks++
      }
    }
    assert.ok(Math.abs(blocks - FRAME_COUNT) <= FRAME_COUNT * 0.1, `帧块 ${blocks} 应 ≈${FRAME_COUNT}`)
    assert.ok(Math.abs(ms - FRAME_COUNT * FRAME_DELAY_CS * 10) <= 50, `总时长 ${ms}ms 应 ≈2000ms`)

    // ffmpeg 解码回读（编解码同源 oracle；GDI+/Chrome 兼容由 app 素材同源背书）
    const decoded = decodeWithFfmpeg(out, SIZE)
    assert.equal(decoded.length, FRAME_COUNT, `应解出 ${FRAME_COUNT} 帧`)

    // 白底四角：四角 RGB 接近纯白（调色板量化容差）
    const first = decoded[0]
    const corners = [0, (SIZE - 1) * 3, (SIZE - 1) * SIZE * 3, ((SIZE - 1) * SIZE + SIZE - 1) * 3]
    for (const c of corners) {
      const sum = first[c] + first[c + 1] + first[c + 2]
      assert.ok(sum >= 750, `四角 RGB 和 ${sum} 应 ≥750（白底）`)
    }

    // 无缝与对称（像素差判据，同构 isSeamlessLoop）
    const diffs = []
    for (let i = 0; i + 1 < decoded.length; i++) diffs.push(rgbDiff(decoded[i], decoded[i + 1]))
    const wrap = rgbDiff(decoded[decoded.length - 1], decoded[0])
    const sorted = [...diffs].sort((a, b) => a - b)
    const median = sorted[Math.floor(sorted.length / 2)]
    assert.ok(diffs.filter((d) => d !== 0).length >= decoded.length * 0.5, '活动性不足（疑似全静止）')
    assert.ok(wrap >= 0.5 * median && wrap <= 2 * median,
      `wrap 像素差 ${wrap} 应 ∈ [${(0.5 * median).toFixed(0)}, ${(2 * median).toFixed(0)}]`)
    for (let i = 1; i < decoded.length / 2; i++) {
      const agree = rgbAgree(decoded[i], decoded[decoded.length - i])
      assert.ok(agree >= 0.9, `帧 ${i} 与 ${decoded.length - i} 对称性 ${agree.toFixed(2)} < 0.9`)
    }

    // 画面保真：ffmpeg 解码回读首帧 vs 源首帧 RGB（量化容差：平均每通道差 < 30）
    const src = indicesToRgb(frames)
    const firstLen = decoded[0].length
    let acc = 0
    for (let p = 0; p < firstLen; p++) acc += Math.abs(src[p] - decoded[0][p])
    const avg = acc / firstLen
    assert.ok(avg < 30, `画面平均通道差 ${avg.toFixed(1)} 应 <30（保真）`)
  } finally {
    rmSync(tmp, { recursive: true, force: true })
  }
})

// ── 辅助 ─────────────────────────────────────────────────────

function posesForProbe() {
  return {
    name: 'probe-squat',
    poseA: { root: [240, 440], segments: [{ a: 0, l: 60 }, { a: 0, l: 60 }, { a: 0, l: 60 }] },
    poseB: { root: [240, 440], segments: [{ a: -60, l: 60 }, { a: 70, l: 60 }, { a: 0, l: 60 }] }
  }
}

function rgbDiff(a, b) {
  let d = 0
  for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) d++
  return d
}

function rgbAgree(a, b) {
  let same = 0
  for (let i = 0; i < a.length; i++) if (Math.abs(a[i] - b[i]) <= 8) same++
  return same / a.length
}
