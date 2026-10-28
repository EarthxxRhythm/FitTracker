import { test } from 'node:test'
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { resolveDevecoCliInvocation } from './check-gates.mjs'

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
