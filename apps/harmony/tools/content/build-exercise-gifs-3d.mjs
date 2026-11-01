//
// build-exercise-gifs-3d.mjs —— 3D 演示 GIF 批量生成脚本。
//
// 用法（从 apps/harmony 执行）：
//   node tools/content/build-exercise-gifs-3d.mjs                    # 全量
//   node tools/content/build-exercise-gifs-3d.mjs --only barbell-squat,push-up
//   node tools/content/build-exercise-gifs-3d.mjs --dry-run          # 只报计划
//
// 参数与 showcase 实拍线同约定：--size/--out/--only；--out 白名单护栏
// 同 build-exercise-gifs-photo.mjs（仅允许仓库根 test_run/ 之下）。
// 输出：test_run/showcase-gifs-3d/<gifId>.gif（480px、25fps/40ms、50 帧乒乓循环）。
//
// 渲染/编码引擎在 3d/engine.mjs + 3d/encode-gif.mjs + 3d/gif-decode.mjs
// （全自写零外部依赖；不变量由 build-exercise-gifs-3d.test.mjs 守护）。

import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { renderPoseFrames, encodeGif, SIZE, PALETTE, FRAME_COUNT, FRAME_DELAY_CS } from './3d/engine.mjs'

const HERE = path.dirname(fileURLToPath(import.meta.url))
const HARMONY_ROOT = path.resolve(HERE, '..', '..')
const REPO_ROOT = path.resolve(HARMONY_ROOT, '..', '..')
const POSES_PATH = path.join(HERE, '3d/poses.json')

/** --out 白名单护栏：与实拍线同规则。 */
export function assertShowcaseOutAllowed(outDir) {
  const abs = path.resolve(outDir)
  const allowed = path.join(REPO_ROOT, 'test_run') + path.sep
  return abs.startsWith(allowed)
}

function parseArgs(argv) {
  const out = {
    only: null,
    dryRun: false,
    size: SIZE,
    out: path.join(REPO_ROOT, 'test_run', 'showcase-gifs-3d')
  }
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]
    if (a === '--only' && argv[i + 1]) { out.only = argv[++i].split(',').map((s) => s.trim()).filter(Boolean) }
    else if (a === '--size' && argv[i + 1]) { out.size = parseInt(argv[++i], 10) }
    else if (a === '--out' && argv[i + 1]) { out.out = argv[++i] }
    else if (a === '--dry-run') { out.dryRun = true }
  }
  return out
}

function main() {
  const opts = parseArgs(process.argv.slice(2))
  if (!assertShowcaseOutAllowed(opts.out)) {
    console.error('✗ --out 必须位于 ' + path.join(REPO_ROOT, 'test_run') + ' 之下（展示级产物不入库、不进安装包），实际：' + path.resolve(opts.out))
    return 2
  }
  const poses = JSON.parse(fs.readFileSync(POSES_PATH, 'utf8'))
  let entries = Object.entries(poses)
    .filter(([k]) => !k.startsWith('_')) // 元数据键（_readme 等）不是动作
    .map(([gifId, v]) => ({ gifId, ...v }))
  if (opts.only) {
    entries = entries.filter((e) => opts.only.includes(e.gifId))
    if (entries.length === 0) {
      console.error('--only 未匹配到任何条目')
      return 1
    }
  }
  console.log('姿势表 ' + entries.length + ' 条（' + (opts.only ? '筛选' : '全量') + '）')
  if (opts.dryRun) {
    for (const e of entries) console.log('  [dry-run] ' + e.gifId + ' -> ' + e.nameZh)
    return 0
  }
  fs.mkdirSync(opts.out, { recursive: true })
  let failures = 0
  for (const e of entries) {
    const outPath = path.join(opts.out, e.gifId + '.gif')
    const frames = renderPoseFrames({ poseA: e.poseA, poseB: e.poseB }, { size: opts.size })
    const bytes = encodeGif(frames, {
      width: opts.size,
      height: opts.size,
      delays: frames.map(() => FRAME_DELAY_CS),
      palette: PALETTE,
      outPath
    })
    console.log('  ✓ ' + e.gifId + '.gif  ' + (bytes.length / 1024).toFixed(1) + ' KB  ' + FRAME_COUNT + ' 帧')
    if (bytes.length > 1.5 * 1024 * 1024) {
      console.log('    ! 超过 1.5MB 预算')
      failures++
    }
  }
  console.log('输出目录 ' + path.relative(REPO_ROOT, opts.out).replace(/\\/g, '/'))
  return failures > 0 ? 2 : 0
}

const isDirectRun = process.argv[1] !== undefined &&
  path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url))

export { renderPoseFrames, encodeGif, parseArgs }

if (isDirectRun) {
  process.exit(main())
}
