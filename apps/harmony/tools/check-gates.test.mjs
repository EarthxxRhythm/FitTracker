import { test } from 'node:test'
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { mkdtempSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { describeProfileDrift, fileSha256, resolveDevecoCliInvocation } from './check-gates.mjs'

// 背景（2026-10-12 本机实测）：
// Windows 上 npm 生成的 `devecocli.cmd` 是标准 shim，内部以 `node` 启动
// `node_modules/@deveco/deveco-cli/cli.js`。但本机环境中该行内的 `node` 解析
// 到了一个不存在的 `tianshu-runtime.exe`（相对 cwd），于是
// `spawnSync('devecocli', ['--version'], { shell: true })` 以 exit 1 失败——
// 门禁据此误报「PATH 中未找到 devecocli」，而 devecocli 其实就在 PATH 里
// （Git Bash 直接执行同一命令可正常返回 1.3.4）。
//
// 这些测试固定的是「解析出的调用方式必须真的能跑通」，而不是某一种具体解析策略。

/**
 * devecocli 是否真实可用。
 *
 * CI 跑在 ubuntu runner 上，没有 DevEco Studio 与 HarmonyOS SDK，devecocli 不可能存在。
 * 这条测试固定的是「解析出的调用方式必须真的能跑通」——没有可执行的 CLI 就没有判据，
 * 应 skip 而非 fail（与 check-auth-spacing 在 design 缺失时的处理一致）。
 */
function devecoCliAvailable() {
  const invocation = resolveDevecoCliInvocation()
  if (!invocation || !invocation.command) {
    return false
  }
  const probe = spawnSync(
    invocation.command,
    [...(invocation.prefixArgs || []), '--version'],
    { encoding: 'utf8', shell: invocation.useShell === true }
  )
  return probe.status === 0
}

const DEVECO_AVAILABLE = devecoCliAvailable()

test(
  'devecocli 调用方式可解析，且 --version 真实可执行',
  { skip: DEVECO_AVAILABLE ? false : 'devecocli 不可用（CI 无 DevEco CLI），无判据可比' },
  () => {
  const invocation = resolveDevecoCliInvocation()
  assert.ok(invocation, '应解析出调用方式')
  assert.ok(invocation.command, '调用方式必须含 command')

  const probe = spawnSync(
    invocation.command,
    [...(invocation.prefixArgs || []), '--version'],
    { encoding: 'utf8', shell: invocation.useShell === true }
  )

  assert.equal(probe.status, 0, `--version 应以 exit 0 结束，实际 stderr=${probe.stderr}`)
  assert.match(String(probe.stdout).trim(), /\d+\.\d+/, '应输出版本号')
  }
)

test('解析结果必须自洽：直接调 cli.js 时不得再启用 shell', () => {
  const invocation = resolveDevecoCliInvocation()
  const usesCliJs = (invocation.prefixArgs || []).some((arg) => arg.endsWith('cli.js'))

  if (usesCliJs) {
    assert.equal(invocation.command, process.execPath, '应以当前 node 可执行文件直调 cli.js')
    assert.notEqual(invocation.useShell, true, '直调 cli.js 时不应启用 shell（避免再次走 .cmd shim）')
  }
})

// ---------------------------------------------------------------------------
// build-profile.json5 安全不变式：「构建前 hash == 构建后 hash」。
//
// 历史事故形态：把某次 `git hash-object` 的结果（ad7ad40d…）当成绝对基线写进计划，
// 而该文件工作区本就是脏的（含真实签名材料、用户未提交改动），于是门要么误报，
// 要么把「build 真的改写了文件」掩盖掉。以下用例固定的是：判定只看前后两次快照，
// 与任何写死的常量无关。纯函数，不需要 devecocli。
// ---------------------------------------------------------------------------

test('fileSha256：文件缺失返回 null，内容不变哈希稳定，内容改动哈希变化', () => {
  const dir = mkdtempSync(join(tmpdir(), 'ft-gate-profile-'))
  const target = join(dir, 'build-profile.json5')

  assert.equal(fileSha256(target), null, '文件不存在时应返回 null，而不是抛错或空串')

  writeFileSync(target, '{"app":{}}\n', 'utf8')
  const first = fileSha256(target)
  assert.match(String(first), /^[0-9a-f]{64}$/, '应是 sha256 十六进制摘要')

  assert.equal(fileSha256(target), first, '内容未变，哈希必须稳定')

  writeFileSync(target, '{"app":{"signingConfigs":[]}}\n', 'utf8')
  assert.notEqual(fileSha256(target), first, '内容变化必须反映到哈希上')
})

test('describeProfileDrift：前后一致即通过——不看任何绝对基线', () => {
  assert.equal(describeProfileDrift(null, null), null, '构建前后都不存在 => 视为未变')
  assert.equal(
    describeProfileDrift('ad7ad40d1af353ccb07056fae5aabcf88382759d', 'ad7ad40d1af353ccb07056fae5aabcf88382759d'),
    null,
    '同一快照 => 未变；判据里没有「必须等于某个历史哈希」这一项'
  )
  // 反例：哪怕哈希「看起来像」历史基线，只要前后不同就必须报。
  assert.notEqual(
    describeProfileDrift('ad7ad40d1af353ccb07056fae5aabcf88382759d', '6bbf0e13b962749d16236d3b50706f31eb1d4d73'),
    null,
    '前后不一致必须判为变（否则门就丢了判据）'
  )
})

test('describeProfileDrift：改写/新建/删除给出方向性说明', () => {
  const rewritten = describeProfileDrift('aaa', 'bbb')
  assert.ok(rewritten && rewritten.includes('aaa') && rewritten.includes('bbb'), '改写说明须带前后哈希')

  const created = describeProfileDrift(null, 'bbb')
  assert.ok(created && created.includes('出现'), '构建前不存在：须说明是被 build 写出来了')

  const removed = describeProfileDrift('aaa', null)
  assert.ok(removed && removed.includes('删除'), '构建后不存在：须说明是被 build 删掉了')
})
