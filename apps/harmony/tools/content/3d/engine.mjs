//
// 3D 演示 GIF 引擎（纯 Node 软件渲染，零外部运行时依赖）。
//
// 渲染链：姿势（分段链 + 锚点）→ slerp 插值 50 帧（25fps/40ms 定版）→
// 胶囊 SDF 软件渲染（2×2 超采样 + 漫反射光照 + 地面软阴影）→
// 固定 256 色调色板量化 → 索引帧缓冲 → vendor gifenc 编码。
//
// 帧结构定版（council 评审通过）：帧 0=姿势 A、帧 25=姿势 B、帧 49=回程接近 A；
// 循环时 49→0 的姿势差 = 单帧步长（回绕无缝）；p[i] ≡ p[50-i]（镜像回程）。
//
// 依赖：node:fs（仅落盘用）、./vendor/gifenc.esm.js（MIT，见 THIRD-PARTY-NOTICES）。

import { encodeGif as encodeGifBytes } from './encode-gif.mjs'
import { writeFileSync, mkdirSync } from 'node:fs'
import { dirname } from 'node:path'

export const FPS = 25
export const FRAME_COUNT = 50 // 2s × 25fps
export const FRAME_DELAY_CS = 4 // 40ms（GIF delay 单位 1/100s，25fps 精确表达）
export const SIZE = 480

// ── 固定调色板（256 色，确定性常量表）────────────────────────
// 0 = 纯白背景；1-11 = 阴影灰阶；12-15 = 人物主色（深→亮）；其余填充中间灰。
export const BG_INDEX = 0
export const PALETTE = buildPalette()

function buildPalette() {
  const out = []
  out.push([255, 255, 255]) // 0 白底
  for (let i = 0; i < 10; i++) {
    const v = Math.round(240 - i * 18) // 240→78 阴影灰阶
    out.push([v, v, v])
  }
  // 人物色（暖灰蓝 4 级：暗面→高光）
  const skin = [
    [96, 108, 124],
    [120, 132, 148],
    [148, 160, 174],
    [180, 190, 200]
  ]
  out.push(...skin)
  // 填充到 256
  while (out.length < 256) out.push([150, 150, 150])
  const flat = new Uint8Array(256 * 3)
  out.forEach((rgb, i) => { flat[i * 3] = rgb[0]; flat[i * 3 + 1] = rgb[1]; flat[i * 3 + 2] = rgb[2] })
  return flat
}

// ── 无缝循环判据（纯函数，数值序列版；四反例在测试中钉死）───

/**
 * 判据（端点语义定版：末帧≠首帧，wrap 衔接 = 单帧步长）：
 * ① 活动性前置：非零相邻差 ≥ 总数×0.5（排除全静止）
 * ② 对称性：p[i] == p[n-i]（i ∈ 1..n/2-1，镜像回程）
 * ③ wrapDiff ∈ [0.5×median, 2×median]（回绕处 = 单帧步长同量级）
 */
export function isSeamlessLoop(frames) {
  if (!Array.isArray(frames) || frames.length < 3) return false
  const n = frames.length
  const diffs = []
  for (let i = 0; i + 1 < n; i++) diffs.push(Math.abs(frames[i + 1] - frames[i]))
  const wrap = Math.abs(frames[0] - frames[n - 1])
  if (diffs.filter((d) => d !== 0).length < n * 0.5) return false
  for (let i = 1; i < n / 2; i++) {
    if (frames[i] !== frames[n - i]) return false
  }
  const sorted = [...diffs].sort((a, b) => a - b)
  const median = sorted[Math.floor(sorted.length / 2)]
  if (wrap < 0.5 * median || wrap > 2 * median) return false
  return true
}

// ── 姿势插值 ─────────────────────────────────────────────────

/** 角度短弧插值（度）。 */
export function slerpAngle(a0, a1, t) {
  let d = ((a1 - a0) % 360 + 360) % 360
  if (d > 180) d -= 360
  return a0 + d * t
}

/** 姿势（{root:[x,y], segments:[{a,l}...]}）线性插值。 */
export function lerpPose(pA, pB, t) {
  const n = Math.min(pA.segments.length, pB.segments.length)
  return {
    root: [
      pA.root[0] + (pB.root[0] - pA.root[0]) * t,
      pA.root[1] + (pB.root[1] - pA.root[1]) * t
    ],
    segments: Array.from({ length: n }, (_, i) => ({
      a: slerpAngle(pA.segments[i].a, pB.segments[i].a, t),
      l: pA.segments[i].l + (pB.segments[i].l - pA.segments[i].l) * t
    }))
  }
}

/** 分段链 → 顶点坐标（世界系，y 向下）。a=0 指 +y（下），a=90 指 +x（右）。 */
export function chainToPoints(pose) {
  const pts = [[pose.root[0], pose.root[1]]]
  let x = pose.root[0]
  let y = pose.root[1]
  for (const seg of pose.segments) {
    const rad = (seg.a * Math.PI) / 180
    x += Math.sin(rad) * seg.l
    y += Math.cos(rad) * seg.l
    pts.push([x, y])
  }
  return pts
}

// ── 软件渲染（胶囊 SDF）──────────────────────────────────────

const LIMB_R = 10 // 肢体半径（px）
const JOINT_R = 13 // 关节球半径
const LIGHT = [-0.5, -0.75] // 光方向（左上，归一化）

function distToSegment(px, py, ax, ay, bx, by) {
  const abx = bx - ax
  const aby = by - ay
  const t = Math.max(0, Math.min(1, ((px - ax) * abx + (py - ay) * aby) / (abx * abx + aby * aby)))
  const cx = ax + abx * t
  const cy = ay + aby * t
  return Math.hypot(px - cx, py - cy)
}

/** 单帧渲染：姿势 → 索引帧（Uint8Array size*size）。 */
export function renderOneFrame(pose, size, groundY) {
  const idx = new Uint8Array(size * size)
  idx.fill(BG_INDEX)
  const pts = chainToPoints(pose)
  // 逐段包围盒（加速）
  const segs = []
  for (let i = 0; i + 1 < pts.length; i++) {
    const [ax, ay] = pts[i]
    const [bx, by] = pts[i + 1]
    const r = LIMB_R
    segs.push({
      ax, ay, bx, by,
      x0: Math.floor(Math.min(ax, bx) - r) - 2, x1: Math.ceil(Math.max(ax, bx) + r) + 2,
      y0: Math.floor(Math.min(ay, by) - r) - 2, y1: Math.ceil(Math.max(ay, by) + r) + 2,
      // 段轴向单位向量（法线 = 垂直方向）
      ux: (bx - ax) / (Math.hypot(bx - ax, by - ay) || 1),
      uy: (by - ay) / (Math.hypot(bx - ax, by - ay) || 1)
    })
  }
  // 地面软阴影：每条链 root 附近椭圆（深灰阶）
  for (const [rx, ry] of pts.slice(0, 1)) {
    paintEllipse(idx, size, rx, groundY, 46, 10, 2)
  }
  // 逐像素（2×2 超采样）
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      let best = Infinity
      let hitSeg = null
      let closest = null
      for (const s of segs) {
        if (x < s.x0 || x > s.x1 || y < s.y0 || y > s.y1) continue
        const d = distToSegment(x + 0.5, y + 0.5, s.ax, s.ay, s.bx, s.by)
        if (d < best) { best = d; hitSeg = s; closest = null }
      }
      // 关节球
      for (const [jx, jy] of pts) {
        const d = Math.hypot(x + 0.5 - jx, y + 0.5 - jy)
        if (d < best) { best = d; hitSeg = null; closest = [jx, jy] }
      }
      let color = BG_INDEX
      if (best <= LIMB_R || (closest && best <= JOINT_R)) {
        // 光照：法线 × 光方向 → 4 级人物色
        let nx
        let ny
        if (closest) {
          nx = (x + 0.5 - closest[0]) / (best || 1)
          ny = (y + 0.5 - closest[1]) / (best || 1)
        } else {
          // 段表面法线近似：像素点与段轴投影的垂直分量
          const proj = (x + 0.5 - hitSeg.ax) * hitSeg.ux + (y + 0.5 - hitSeg.ay) * hitSeg.uy
          const px = hitSeg.ax + proj * hitSeg.ux
          const py = hitSeg.ay + proj * hitSeg.uy
          nx = (x + 0.5 - px) / (best || 1)
          ny = (y + 0.5 - py) / (best || 1)
        }
        const dot = Math.max(0, nx * LIGHT[0] + ny * LIGHT[1])
        // 12..15 人物色（暗→亮）
        color = 12 + Math.round(dot * 3)
        if (color > 15) color = 15
      }
      idx[y * size + x] = color
    }
  }
  return idx
}

/** 椭圆软阴影（索引级：边缘用更浅的灰）。 */
function paintEllipse(idx, size, cx, cy, rx, ry, colorBase) {
  const x0 = Math.max(0, Math.floor(cx - rx))
  const x1 = Math.min(size - 1, Math.ceil(cx + rx))
  const y0 = Math.max(0, Math.floor(cy - ry))
  const y1 = Math.min(size - 1, Math.ceil(cy + ry))
  for (let y = y0; y <= y1; y++) {
    for (let x = x0; x <= x1; x++) {
      const nx = (x - cx) / rx
      const ny = (y - cy) / ry
      if (nx * nx + ny * ny <= 1) {
        idx[y * size + x] = colorBase
      }
    }
  }
}

// ── 帧序列与编码 ────────────────────────────────────────────

/** 姿势 A/B → 50 帧索引序列（镜像回程：p[i] ≡ p[50-i]）。 */
export function renderPoseFrames(posePair, opts) {
  const size = opts.size || SIZE
  const groundY = size - 36
  const { poseA, poseB } = posePair
  const frames = []
  for (let i = 0; i < FRAME_COUNT; i++) {
    const t = i <= 25 ? i / 25 : 1 - (i - 25) / 25
    const pose = lerpPose(poseA, poseB, t)
    frames.push(renderOneFrame(pose, size, groundY))
  }
  return frames
}

/** 索引帧序列 → GIF 字节（自写编码器，与 gif-decode.mjs 配对）。 */
export function encodeGif(frames, opts) {
  const width = opts.width
  const height = opts.height
  const delays = opts.delays || frames.map(() => FRAME_DELAY_CS)
  const bytes = encodeGifBytes(frames, {
    width,
    height,
    delays,
    palette: opts.palette || PALETTE
  })
  if (opts.outPath) {
    mkdirSync(dirname(opts.outPath), { recursive: true })
    writeFileSync(opts.outPath, bytes)
  }
  return bytes
}
