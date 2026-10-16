// build-content.mjs 的集成回归测试（不重构被测脚本，按真实行为断言）。
//
// 背景：该脚本是内容构建门禁——把 content/exercises/*.jsonl 校验后生成
// LocalExerciseContent.ets 与 LocalContentSyncPackage.ets。它是关键构建门，
// 因此这里用子进程集成测试覆盖其真实副作用（退出码 + 生成的 manifest 字段 +
// 覆盖率报告文本），而不是导出内部函数做单元测试（重构门禁脚本回归风险更高）。
//
// 本轮实际改动：recommendedExerciseCount 50 → 110（仅影响报告文案，不参与拦截），
// 以及动作数据从 50 条扩充到 102 条。以下断言锁定这两点。
//
// 运行：node --test tools/content/build-content.test.mjs

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptDir = dirname(fileURLToPath(import.meta.url))
const harmonyRoot = resolve(scriptDir, '../..')
const scriptPath = resolve(scriptDir, 'build-content.mjs')

/** 运行 build-content.mjs，返回 { status, output }。 */
function runBuild() {
  const result = spawnSync(process.execPath, [scriptPath], {
    cwd: harmonyRoot,
    encoding: 'utf8'
  })
  return {
    status: result.status,
    output: `${result.stdout || ''}${result.stderr || ''}`
  }
}

test('build-content 对当前内容数据校验通过（exit 0）', function () {
  const { status, output } = runBuild()
  assert.equal(status, 0, `build-content 失败（exit ${status}）:\n${output}`)
})

test('覆盖率报告列出动作总数，且总数高于扩充前的 50 条', function () {
  const { status, output } = runBuild()
  assert.equal(status, 0, `构建失败:\n${output}`)

  const match = output.match(/- exercises: (\d+) \(target (\d+)-(\d+)\)/)
  assert.ok(match, `覆盖率报告缺少 exercises 行:\n${output}`)

  const actualCount = Number(match[1])
  const targetMin = Number(match[2])
  const targetMax = Number(match[3])

  // 2026-10-16 扩充：50 → 102 条
  assert.ok(actualCount > 50, `动作总数应高于扩充前的 50，实际 ${actualCount}`)
  assert.ok(actualCount >= targetMin, `动作总数 ${actualCount} 低于下限 ${targetMin}`)
  assert.ok(
    actualCount <= targetMax,
    `动作总数 ${actualCount} 超过上限 ${targetMax}（recommendedExerciseCount 需同步上调）`
  )
})

test('生成的 manifest 中 exerciseCount 与真实动作条数一致', function () {
  const { status } = runBuild()
  assert.equal(status, 0)

  const exercisesPath = resolve(harmonyRoot, 'content/exercises/exercises.zh-CN.jsonl')
  const actualCount = readFileSync(exercisesPath, 'utf8')
    .split(/\r?\n/)
    .filter((line) => line.trim().length > 0).length

  const manifestPath = resolve(harmonyRoot, 'entry/src/main/ets/generated/LocalContentSyncPackage.ets')
  const manifestText = readFileSync(manifestPath, 'utf8')

  // createContentSyncManifest(1, "full", packageVersion, url, checksum, size, generatedAt, exerciseCount, channel, note)
  const match = manifestText.match(/createContentSyncManifest\(\s*1,\s*"full",\s*(\d+),\s*"([^"]*)",\s*"([^"]*)",\s*(\d+),\s*(\d+),\s*(\d+),/)
  assert.ok(match, '无法解析生成的 manifest 参数')

  const packageVersion = Number(match[1])
  const checksum = match[3]
  const sizeBytes = Number(match[4])
  const exerciseCount = Number(match[6])

  assert.equal(exerciseCount, actualCount, `manifest.exerciseCount (${exerciseCount}) 与真实条数 (${actualCount}) 不一致`)
  assert.ok(packageVersion >= 3, `packageVersion 应 ≥3（扩充后触发设备重新导入），实际 ${packageVersion}`)
  assert.ok(checksum.startsWith('sha256:'), `checksum 格式应为 sha256:...，实际 ${checksum}`)
  assert.ok(sizeBytes > 0, 'manifest.packageSizeBytes 应为正数')
})

test('生成产物与 JSONL 源保持同步（重复构建幂等）', function () {
  // 连续两次构建，第二次不应再改写文件（writeFileIfChanged 的幂等语义）
  const first = runBuild()
  assert.equal(first.status, 0)

  const generatedPath = resolve(harmonyRoot, 'entry/src/main/ets/generated/LocalExerciseContent.ets')
  const afterFirst = readFileSync(generatedPath, 'utf8')

  const second = runBuild()
  assert.equal(second.status, 0)

  const afterSecond = readFileSync(generatedPath, 'utf8')
  assert.equal(afterSecond, afterFirst, '重复构建改写了产物——生成逻辑不幂等')
})

test('覆盖率报告覆盖全部 6 个肌群与目标区间内的难度分布', function () {
  const { status, output } = runBuild()
  assert.equal(status, 0)

  const musclesLine = output.match(/- muscles: (.+)/)
  assert.ok(musclesLine, '覆盖率报告缺少 muscles 行')
  for (const muscleId of ['muscle_chest', 'muscle_back', 'muscle_legs', 'muscle_shoulders', 'muscle_arms', 'muscle_core']) {
    assert.ok(musclesLine[1].includes(muscleId), `肌肉覆盖缺失 ${muscleId}`)
  }

  const difficultiesLine = output.match(/- difficulties: (.+)/)
  assert.ok(difficultiesLine, '覆盖率报告缺少 difficulties 行')
  for (const difficulty of ['beginner', 'intermediate', 'advanced']) {
    assert.ok(difficultiesLine[1].includes(difficulty), `难度覆盖缺失 ${difficulty}`)
  }
})
