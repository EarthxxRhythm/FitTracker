import { spawnSync } from 'node:child_process'

// Windows 上 devecocli 是 .cmd，spawnSync 不带 shell 无法解析。
const USE_SHELL = process.platform === 'win32'

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
function detectDevecoCli() {
  const probe = runCommand('devecocli', ['--version'], process.cwd(), USE_SHELL)
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

  const version = detectDevecoCli()
  if (version === null) {
    throw new Error(
      '[build-gates] ArkTS 编译门禁无法执行：PATH 中未找到 devecocli。\n' +
      '本仓库约定 HarmonyOS 构建走 deveco-cli（AGENTS.md「提效约定」）。\n' +
      '建议: npm i -g @deveco/deveco-cli 后重跑；确需跳过请显式传 --skip-build。'
    )
  }

  console.log(`[build-gates] ArkTS 编译门禁：devecocli ${version}`)
  const build = runCommand(
    'devecocli',
    ['build', '--modules', 'entry@default', '--build-mode', 'debug'],
    repoRoot,
    USE_SHELL
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

try {
  main()
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error))
  process.exit(1)
}
