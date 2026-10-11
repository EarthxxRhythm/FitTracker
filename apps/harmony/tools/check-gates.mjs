import { spawnSync } from 'node:child_process'
import { existsSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

// Windows 上 devecocli 是 .cmd，spawnSync 不带 shell 无法解析。
// 注意：这条仅适用于「shim 本身完好」的环境——见 resolveDevecoCliInvocation 的说明。
const USE_SHELL = process.platform === 'win32'

/**
 * 解析 devecocli 的调用方式，返回 { command, prefixArgs, useShell }。
 *
 * 背景（2026-10-12 本机实测）：Windows 上 npm 生成的 `devecocli.cmd` 是标准 shim，
 * 内部以 `node` 启动 `node_modules/@deveco/deveco-cli/cli.js`。但该行里的 `node` 在
 * 本机环境被解析到不存在的 `tianshu-runtime.exe`（相对 cwd），于是
 * `spawnSync('devecocli', ['--version'], { shell: true })` 以 exit 1 失败，门禁据此
 * 误报「PATH 中未找到 devecocli」—— 而 devecocli 确实在 PATH 中（Git Bash 里直接
 * 执行同一条命令可正常返回 1.3.4）。
 *
 * 所以优先从 PATH 中的 npm 安装目录解析出 cli.js，用当前 node 进程直调，绕开 shim
 * 与 cmd.exe；解析不到时才回退为直接调用 `devecocli`。
 */
export function resolveDevecoCliInvocation() {
  const pathDirs = String(process.env.PATH || '')
    .split(path.delimiter)
    .filter((dir) => dir !== '')

  for (const dir of pathDirs) {
    const cliJs = path.join(dir, 'node_modules', '@deveco', 'deveco-cli', 'cli.js')
    if (existsSync(cliJs)) {
      return { command: process.execPath, prefixArgs: [cliJs], useShell: false }
    }
  }

  return { command: 'devecocli', prefixArgs: [], useShell: USE_SHELL }
}

function runCommand(command, args, cwd = process.cwd(), useShell = false) {
  const result = spawnSync(command, args, {
    cwd,
    encoding: 'utf8',
    shell: useShell
  })

  const output = `${result.stdout || ''}${result.stderr || ''}`.trim()
  return {
    status: result.status ?? 0,
    output
  }
}

function parseOutput(raw) {
  if (raw === '') {
    return 'No output.'
  }
  return raw
}

/**
 * 探测 devecocli 是否可用，返回版本号字符串；不可用返回 null。
 * 本仓库约定 HarmonyOS 构建走 deveco-cli（AGENTS.md「提效约定」），不裸跑 hvigorw。
 */
function detectDevecoCli(invocation) {
  const probe = runCommand(
    invocation.command,
    [...invocation.prefixArgs, '--version'],
    process.cwd(),
    invocation.useShell
  )
  if (probe.status !== 0) {
    return null
  }
  return parseOutput(probe.output).split(/\r?\n/)[0].trim()
}

function main() {
  const repoRoot = process.cwd()
  const argv = process.argv.slice(2)
  const skipBuild = argv.includes('--skip-build')

  const steps = [
    {
      name: 'content build',
      command: 'node',
      args: ['tools/content/build-content.mjs'],
      help: '修正 content/exercises/*.jsonl 里的数据错误后重试，关注报错行号中的 id/file/line。'
    },
    {
      name: 'main page check',
      command: 'node',
      args: ['tools/check-main-pages.mjs'],
      help: '确认 main_pages.json 内所有 @Entry 页面路径正确存在且每页仅有一个 @Entry。'
    },
    {
      name: 'git whitespace/style',
      command: 'git',
      args: ['diff', '--check'],
      help: '清理制表符/尾随空白后重跑。'
    },
    {
      name: 'doc dead-refs',
      command: 'node',
      args: ['tools/check-dead-refs.mjs'],
      help: '文档/配置里引用了仓库内已不存在的路径。改为当前路径；若该引用本就是「已归档/已删除」说明，请在同一句带上失效措辞（脚本据此豁免）。'
    }
  ]

  for (const step of steps) {
    const result = runCommand(step.command, step.args)
    if (result.status !== 0) {
      throw new Error(
        ` [build-gates] ${step.name} failed (exit ${result.status})\n` +
        `${parseOutput(result.output)}\n` +
        `建议: ${step.help}`
      )
    }
    console.log(`[build-gates] ${step.name} passed`)
  }

  // ---- ArkTS 编译门禁 ----
  // 历史问题：这里曾只准备 DevEco 环境就打印 "hvigorw baseline check passed"，
  // 从未真正调用编译器 —— 于是「main_pages.json 注册了 5 个不存在的页面」
  // 这类 HEAD 级破损长期潜伏。现在改为真实编译，且无法编译时绝不声称通过。
  if (skipBuild) {
    console.warn('[build-gates] ⚠ --skip-build：ArkTS 编译门禁被显式跳过，产物未经编译验证。')
    console.warn('[build-gates]   仅在明确已知编译状态时使用；提交前请去掉该参数。')
    return
  }

  const invocation = resolveDevecoCliInvocation()
  const version = detectDevecoCli(invocation)
  if (version === null) {
    throw new Error(
      '[build-gates] ArkTS 编译门禁无法执行：devecocli 不可用（注意：这不是「不在 PATH」）。\n' +
      `已尝试: ${invocation.command} ${[...invocation.prefixArgs, '--version'].join(' ')}\n` +
      '本仓库约定 HarmonyOS 构建走 deveco-cli（AGENTS.md「提效约定」）。\n' +
      '建议: 先确认 `devecocli --version` 可用；必要时重装 npm i -g @deveco/deveco-cli；确需跳过请显式传 --skip-build。'
    )
  }

  console.log(`[build-gates] ArkTS 编译门禁：devecocli ${version}`)
  const build = runCommand(
    invocation.command,
    [...invocation.prefixArgs, 'build', '--modules', 'entry@default', '--build-mode', 'debug'],
    repoRoot,
    invocation.useShell
  )
  if (build.status !== 0) {
    throw new Error(
      `[build-gates] ArkTS 编译失败 (exit ${build.status})\n` +
      `${parseOutput(build.output)}\n` +
      '建议: 以上是真实编译输出；修编译错误本身，不要用 git stash / checkout 清空工作区来绕过门禁。'
    )
  }
  console.log('[build-gates] ArkTS 编译通过')
}

// 仅在直接执行本文件时运行门禁；被 import（例如单测）时只暴露工具函数。
const isDirectRun =
  process.argv[1] !== undefined &&
  path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url))

if (isDirectRun) {
  try {
    main()
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error))
    process.exit(1)
  }
}
