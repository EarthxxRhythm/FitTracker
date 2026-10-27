#!/usr/bin/env node
/**
 * rotate-credential.mjs —— 凭据轮换助手。
 *
 * 解决的问题：把新密钥「粘进终端」会留下命令历史、屏幕回显、截图；
 * 手工替换又容易漏掉行尾 / 误改别的键 / 忘记清理旧值残留。
 *
 * 用法：
 *   1) 把新值（只一行）存进仓库根的 .rotate.tmp —— 用记事本，不要用终端
 *   2) node tools/rotate-credential.mjs <KEY>
 *   3) 脚本替换配置、扫描旧值残留、追加轮换记录，然后删掉 .rotate.tmp
 *
 *   node tools/rotate-credential.mjs --list      查看各键是否已有值（不打印值）
 *
 * 安全约束：
 *   - 全程不把值打印到 stdout / stderr
 *   - 只允许操作白名单内的键
 *   - .rotate.tmp 用完立即 unlink
 *
 * 详细步骤见 docs/security/credential-rotation.md
 */
import { readFileSync, writeFileSync, existsSync, unlinkSync, readdirSync, statSync } from 'node:fs'
import { join, relative, dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptDir = dirname(fileURLToPath(import.meta.url))
const repoRoot = resolve(scriptDir, '..')
const ENV_PATH = join(repoRoot, 'server', 'deploy', 'thirdparty.env')
const TMP_PATH = join(repoRoot, '.rotate.tmp')
const LOG_PATH = join(repoRoot, 'docs', 'security', 'credential-rotation-log.md')

/** 允许轮换的键。新增键必须先在这里登记，避免误改无关配置。 */
const ALLOWED = [
  'QQ_APP_KEY',
  'HUAWEI_CLIENT_SECRET',
  'WECHAT_APP_SECRET',
  'SUPABASE_SERVICE_ROLE_KEY',
  'SEND_SMS_HOOK_SECRET',
  'ALIYUN_ACCESS_KEY_SECRET'
]

/** 残留扫描时跳过的目录。 */
const SKIP_DIRS = new Set([
  '.git', 'node_modules', 'oh_modules', 'build', '.gradle', '.hvigor', '.rivet', '.codex', '.opencode', 'test_run'
])

function fail(message) {
  process.stderr.write('[rotate] 失败：' + message + '\n')
  process.exit(1)
}

function parseEnv(text) {
  const map = new Map()
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)$/)
    if (m) map.set(m[1], m[2])
  }
  return map
}

function listState() {
  if (!existsSync(ENV_PATH)) fail('找不到 ' + relative(repoRoot, ENV_PATH))
  const text = readFileSync(ENV_PATH, 'utf8')
  const map = parseEnv(text)
  process.stdout.write('server/deploy/thirdparty.env 各键状态（不打印值）：\n')
  for (const key of ALLOWED) {
    const v = map.get(key)
    let state = 'EMPTY'
    if (v !== undefined && v.length > 0) state = '已配置 (' + v.length + ' 字符)'
    if (v === undefined) state = '该文件中不存在此键'
    process.stdout.write('  ' + key.padEnd(28) + state + '\n')
  }
}

/** 扫描工作区里是否还残留某个值，返回命中文件列表。 */
function scanResidue(secret, selfPath) {
  const needle = Buffer.from(secret, 'utf8')
  const hits = []
  const walk = (dir, depth) => {
    if (depth > 9) return
    let entries
    try { entries = readdirSync(dir, { withFileTypes: true }) } catch { return }
    for (const e of entries) {
      if (e.name.startsWith('.') && e.name !== '.gitignore') continue
      if (SKIP_DIRS.has(e.name)) continue
      const full = join(dir, e.name)
      if (e.isDirectory()) { walk(full, depth + 1); continue }
      if (!e.isFile()) continue
      let size
      try { size = statSync(full).size } catch { continue }
      if (size > 4 * 1024 * 1024) continue
      let buf
      try { buf = readFileSync(full) } catch { continue }
      if (buf.includes(needle)) hits.push(relative(repoRoot, full).replace(/\\/g, '/'))
    }
  }
  walk(repoRoot, 0)
  return hits.filter((p) => p !== selfPath)
}

function appendLog(key) {
  if (!existsSync(LOG_PATH)) return false
  const today = new Date().toISOString().slice(0, 10)
  const row = '| ' + today + ' | ' + key + ' | 见轮换手册 | 待确认：需推送 secrets / 重启服务 | 待填 | Earth |\n'
  writeFileSync(LOG_PATH, row, { flag: 'a', encoding: 'utf8' })
  return true
}

function main() {
  const arg = process.argv[2]

  if (!arg || arg === '--help' || arg === '-h') {
    process.stdout.write(
      '用法：\n' +
      '  node tools/rotate-credential.mjs --list          查看各键状态\n' +
      '  node tools/rotate-credential.mjs <KEY>           用 .rotate.tmp 里的新值替换\n\n' +
      '步骤见 docs/security/credential-rotation.md\n'
    )
    return
  }

  if (arg === '--list') { listState(); return }

  const key = arg
  if (!ALLOWED.includes(key)) {
    fail('不支持的键 ' + key + '。允许：' + ALLOWED.join(', '))
  }

  if (!existsSync(ENV_PATH)) fail('找不到 ' + relative(repoRoot, ENV_PATH))
  if (!existsSync(TMP_PATH)) {
    fail('找不到 .rotate.tmp。\n' +
      '  请用记事本新建 ' + relative(repoRoot, TMP_PATH) + '，\n' +
      '  里面只写一行：新值本身（不要写 KEY= 前缀），保存后再运行本命令。')
  }

  const rawNew = readFileSync(TMP_PATH, 'utf8').trim()
  if (rawNew.length < 8) fail('.rotate.tmp 内容太短，看起来不像有效密钥（可能是空文件或占位符）')
  if (/[\r\n]/.test(rawNew)) fail('.rotate.tmp 必须只有一行')

  const originalText = readFileSync(ENV_PATH, 'utf8')
  const eol = originalText.includes('\r\n') ? '\r\n' : '\n'
  const lines = originalText.split(/\r?\n/)
  const map = parseEnv(originalText)
  const oldValue = map.get(key) ?? ''

  let replaced = false
  const outLines = lines.map((line) => {
    const m = line.match(/^(\s*)([A-Z0-9_]+)(\s*=\s*)(.*)$/)
    if (m && m[2] === key) {
      replaced = true
      return m[1] + key + m[3] + rawNew
    }
    return line
  })

  if (!replaced) {
    outLines.push(key + '=' + rawNew)
    process.stdout.write('[rotate] 该键原本不存在，已在文件末尾追加：' + key + '\n')
  }

  writeFileSync(ENV_PATH, outLines.join(eol), 'utf8')
  unlinkSync(TMP_PATH)

  process.stdout.write('[rotate] 已更新 ' + key + ' → server/deploy/thirdparty.env（值未回显）\n')
  process.stdout.write('[rotate] 已删除 .rotate.tmp\n')

  if (oldValue.length >= 8 && oldValue !== rawNew) {
    const residue = scanResidue(oldValue, 'server/deploy/thirdparty.env')
    if (residue.length === 0) {
      process.stdout.write('[rotate] 旧值残留扫描：工作区内无残留 ✓\n')
    } else {
      process.stdout.write('[rotate] ⚠ 旧值仍出现在 ' + residue.length + ' 个文件，请人工清理：\n')
      for (const p of residue) process.stdout.write('    ' + p + '\n')
    }
  } else {
    process.stdout.write('[rotate] 该键此前为空，跳过旧值残留扫描\n')
  }

  if (appendLog(key)) {
    process.stdout.write('[rotate] 已在 docs/security/credential-rotation-log.md 追加一条记录（验证列待你填）\n')
  }

  process.stdout.write(
    '\n下一步（脚本不代替你执行）：\n' +
    '  1) 推送 secrets：npx supabase secrets set --env-file server/deploy/thirdparty.env --project-ref <ref>\n' +
    '  2) 重新部署：  npx supabase functions deploy thirdparty-exchange --project-ref <ref>\n' +
    '  3) 验证：      docs/security/credential-rotation.md `4\n' +
    '  4) 服务器侧还需同步：/opt/fittracker/sms-hook.env 或 /opt/supabase/docker/.env\n'
  )
}

main()
