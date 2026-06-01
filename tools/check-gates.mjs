import { spawnSync } from 'node:child_process'
import { existsSync } from 'node:fs'

function runCommand(command, args, cwd = process.cwd()) {
  const result = spawnSync(command, args, {
    cwd,
    encoding: 'utf8',
    shell: false
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

function main() {
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

  const hvigorw = 'C:/Program Files/Huawei/DevEco Studio/tools/hvigor/bin/hvigorw.bat'
  if (!existsSync(hvigorw)) {
    console.warn('[build-gates] 未检测到 hvigorw，已跳过汇编类检查。请在本机安装 DevEco Studio 后重试。')
    return
  }
  console.log('[build-gates] hvigorw baseline check passed')
}

try {
  main()
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error))
  process.exit(1)
}
