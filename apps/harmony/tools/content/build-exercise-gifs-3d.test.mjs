//
// build-exercise-gifs-3d 的合成法回归测试（TDD 先行）。
//
// 守护 3D 演示 GIF 工作流的不变量：帧结构（25fps/40ms 定版 50 帧）、无缝循环、
// 白底、尺寸、round-trip 编码保真。判据全部从脚本常量推导；
// isSeamlessLoop 抽成纯函数并附四反例，反例必须 false（可证伪性由反例保证）。
//
// 运行：cd apps/harmony && node --test tools/content/build-exercise-gifs-3d.test.mjs

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync, existsSync, mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, resolve, join } from 'node:path'
import { fileURLToPath } from 'node:url'

import {
  isSeamlessLoop,
  renderPoseFrames,
  encodeGif,
  FPS,
  FRAME_COUNT,
  FRAME_DELAY_CS,
  SIZE,
  PALETTE,
  BG_INDEX
} from './3d/engine.mjs'
import { decodeGif } from './3d/gif-decode.mjs'

// ── 纯函数组：isSeamlessLoop 四反例 ──────────────────────────────

function chainToFrameIndices(chain) {
  // 把分段链序列转成「帧差异签名」：测试只关心判据行为，用每帧的关节角向量
  // 编码成字符串哈希的近似——这里直接以链数组本身作为帧序列元素。
  return chain
}

test('isSeamlessLoop：正常乒乓序列通过（正例）', function () {
  // 模拟 p[i]≡p[50-i] 的镜像回程 + wrap 衔接=单帧步长：
  // A..B(25)..回程(49)，相邻差均为 1，wrap 差(49→0) 也是 1。
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
  frames[49] = 25 // 末帧替换为远处帧，回绕处大跳变
  assert.equal(isSeamlessLoop(frames), false, 'wrap 跳变必须被拦')
})

test('isSeamlessLoop 反例2：全静止序列必须 false', function () {
  const frames = new Array(FRAME_COUNT).fill(5)
  assert.equal(isSeamlessLoop(frames), false, '全静止必须被拦（活动性前置）')
})

test('isSeamlessLoop 反例3：端点重复停顿必须 false', function () {
  // 首末帧严格相等（端点重复 → 回绕处 0 步长 = 停顿）
  const frames = []
  for (let i = 0; i < FRAME_COUNT; i++) {
    frames.push(i <= 25 ? i : 49 - i)
  }
  frames[49] = frames[0]
  assert.equal(isSeamlessLoop(frames), false, '端点重复停顿必须被拦')
})

test('isSeamlessLoop 反例4：硬切无插值必须 false', function () {
  // A 恒定 → 一跳变到 B → 恒定：相邻差分布极端离群，不满足 wrap≈步长与对称
  const frames = new Array(FRAME_COUNT).fill(0)
  for (let i = 20; i < FRAME_COUNT; i++) frames[i] = 100
  assert.equal(isSeamlessLoop(frames), false, '硬切无插值必须被拦')
})

// ── round-trip：编码 → 解码 → 索引层逐像素一致 ─────────────────

test('round-trip：encode→decode 索引层逐像素一致', function () {
  // 用 2 帧 8×8 合成索引帧（含调色板全部代表性索引），编码后解码必须逐像素还原。
  const w = 8
  const h = 8
  const idxA = new Uint8Array(w * h)
  const idxB = new Uint8Array(w * h)
  for (let i = 0; i < w * h; i++) {
    idxA[i] = i % 16
    idxB[i] = (i * 3) % 16
  }
  const gif = encodeGif([idxA, idxB], { width: w, height: h, delays: [FRAME_DELAY_CS, FRAME_DELAY_CS], palette: PALETTE, loop: true })
  const decoded = decodeGif(gif)
  assert.equal(decoded.frames.length, 2, '应解出 2 帧')
  assert.deepEqual([...decoded.frames[0].indices], [...idxA], '帧0 索引应逐像素一致')
  assert.deepEqual([...decoded.frames[1].indices], [...idxB], '帧1 索引应逐像素一致')
})

// ── 产物组：测试内自渲染（mkdtemp tmpdir，绝不读 test_run/）─────

test('自渲染产物：帧块 50 / 总时长 2000ms / 尺寸 480 / 白底四角 / 无缝', function () {
  const tmp = mkdtempSync(join(tmpdir(), 'gif3d-test-'))
  try {
    const out = join(tmp, 'probe.gif')
    const frames = renderPoseFrames(posesForProbe(), { size: SIZE })
    assert.equal(frames.length, FRAME_COUNT, `应渲染 ${FRAME_COUNT} 帧`)
    encodeGif(frames, { width: SIZE, height: SIZE, delays: frames.map(() => FRAME_DELAY_CS), palette: PALETTE, loop: true, outPath: out })
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

    // 解码做像素断言（白底四角 + 像素版无缝判据 + 无连续 3 帧停顿）
    const decoded = decodeGif(buf)
    const firstIdx = decoded.frames[0].indices
    const cornerOk = [firstIdx[0], firstIdx[SIZE - 1],
      firstIdx[(SIZE - 1) * SIZE], firstIdx[(SIZE - 1) * SIZE + (SIZE - 1)]]
      .every((v) => v === BG_INDEX)
    assert.ok(cornerOk, '四角必须为白底索引')
    const idxFrames = decoded.frames.map((f) => f.indices)
    const signatures = idxFrames.map((f) => hashIndexFrame(f))
    assert.ok(!has3ConsecutiveSame(signatures), '不得有连续 3 帧停顿')
    // 像素版无缝（与 isSeamlessLoop 同构判据，逐像素不一致计数）：
    const diffs = []
    for (let i = 0; i + 1 < idxFrames.length; i++) {
      diffs.push(pixelDiff(idxFrames[i], idxFrames[i + 1]))
    }
    const wrap = pixelDiff(idxFrames[idxFrames.length - 1], idxFrames[0])
    const sorted = [...diffs].sort((a, b) => a - b)
    const median = sorted[Math.floor(sorted.length / 2)]
    assert.ok(diffs.filter((d) => d !== 0).length >= idxFrames.length * 0.5, '活动性不足（疑似全静止）')
    assert.ok(wrap >= 0.5 * median && wrap <= 2 * median,
      `wrap 像素差 ${wrap} 应 ∈ [${(0.5 * median).toFixed(0)}, ${(2 * median).toFixed(0)}]（回绕处跳变或停顿）`)
    // 对称性：p[i] 与 p[50-i] 像素一致比例 ≥0.9
    for (let i = 1; i < idxFrames.length / 2; i++) {
      const agree = pixelAgree(idxFrames[i], idxFrames[idxFrames.length - i])
      assert.ok(agree >= 0.9, `帧 ${i} 与 ${idxFrames.length - i} 对称性 ${agree.toFixed(2)} < 0.9`)
    }
  } finally {
    rmSync(tmp, { recursive: true, force: true })
  }
})

// ── 辅助 ─────────────────────────────────────────────────────

function posesForProbe() {
  // 深蹲探针姿势：站立 A ↔ 深蹲 B（大幅摆角，保证相邻帧有可见位移）。
  return {
    name: 'probe-squat',
    poseA: { root: [240, 100], segments: [{ a: 90, l: 60 }, { a: 90, l: 60 }, { a: 90, l: 60 }] },
    poseB: { root: [240, 160], segments: [{ a: 150, l: 60 }, { a: 20, l: 60 }, { a: 90, l: 60 }] }
  }
}

function hashIndexFrame(idx) {
  // 全像素确定性摘要
  let h = 0
  for (let i = 0; i < idx.length; i++) h = (h * 31 + idx[i]) >>> 0
  return h
}

function pixelDiff(a, b) {
  let d = 0
  for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) d++
  return d
}

function pixelAgree(a, b) {
  let same = 0
  for (let i = 0; i < a.length; i++) if (a[i] === b[i]) same++
  return same / a.length
}

function has3ConsecutiveSame(arr) {
  for (let i = 0; i + 2 < arr.length; i++) {
    if (arr[i] === arr[i + 1] && arr[i + 1] === arr[i + 2]) return true
  }
  return false
}
