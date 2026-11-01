// 看板数据管道：只读聚合 .rivet/COMMAND.md + .rivet/plans/*.md + git。
//
// 唯一读逻辑：dev 时被 vite plugin 每请求实时调用（改了 COMMAND.md 刷新即见），
// build 时被同一 plugin 写成静态快照。两处共用一份实现，杜绝「dev 一套、build 一套」的漂移。
//
// API 以 web/tools/board-data.d.mts 为准，行为契约见 web/tools/board-data.test.mjs。
// 容错第一职责：COMMAND.md 是替换式更新的半结构化 Markdown，Status 标记三态混存——
// 格式漂移时降级返回空集，绝不抛错。
import { readFileSync, readdirSync, statSync, mkdirSync, writeFileSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
export const REPO_ROOT = resolve(here, '..', '..')
export const COMMAND_PATH = resolve(REPO_ROOT, '.rivet', 'COMMAND.md')
export const PLANS_DIR = resolve(REPO_ROOT, '.rivet', 'plans')
const COMMIT_LIMIT = 50

// 签名材料：工作区出现即为「禁提交」，看板要标红
const FORBIDDEN = /(?:^|\/)build-profile\.json5$/

const toPosix = (p) => p.replace(/\\/g, '/')
const isSeparatorRow = (cells) => cells.length > 0 && cells.every((c) => /^:?-{2,}:?$/.test(c))

// 按未转义的 | 拆列；`\|` 还原成字面竖线（表格里写代码片段时会出现）
function splitRow(line) {
  const trimmed = line.trim().replace(/^\|/, '').replace(/\|$/, '')
  return trimmed.split(/(?<!\\)\|/).map((c) => c.trim().replace(/\\\|/g, '|'))
}

// 连续以 | 开头的行算一张表；第二行是全分隔行时第一行即表头
function buildTables(lines) {
  const blocks = []
  let cur = null
  for (const line of lines) {
    if (line.trim().startsWith('|')) {
      if (!cur) {
        cur = []
        blocks.push(cur)
      }
      cur.push(line)
    } else {
      cur = null
    }
  }
  return blocks.map((block) => {
    const rows = block.map(splitRow)
    if (rows.length >= 2 && isSeparatorRow(rows[1])) {
      return { header: rows[0], rows: rows.slice(2) }
    }
    return { header: [], rows }
  })
}

// 只按 `## ` 二级标题分节（一级标题 / 无标题都算格式漂移 → 空数组）。
// 每节保留散文（text）与表格（tables），供前端按语义取用。
export function parseCommand(md) {
  if (typeof md !== 'string' || md.trim() === '') return []

  const sections = []
  let cur = null
  for (const line of md.split(/\r?\n/)) {
    const heading = /^##\s+(.+?)\s*$/.exec(line)
    if (heading) {
      cur = { title: heading[1], lines: [] }
      sections.push(cur)
      continue
    }
    if (cur) cur.lines.push(line)
  }

  return sections.map(({ title, lines }) => {
    const prose = lines.filter((l) => l.trim() !== '' && !l.trim().startsWith('|'))
    return { title, text: prose.join('\n').trim(), tables: buildTables(lines) }
  })
}

// 实测三态混存：`**Status: APPROVED**` / `Status: 待审批（DRAFT）` /
// `**Status: EXECUTED（归档——方案不实施）**`。终态优先（「EXECUTED —— 此前为 APPROVED」判 EXECUTED）。
export function normalizePlanStatus(raw) {
  const s = typeof raw === 'string' ? raw : ''
  if (/EXECUTED/i.test(s)) return 'EXECUTED'
  if (/APPROVED/i.test(s)) return 'APPROVED'
  if (/REJECTED/i.test(s)) return 'REJECTED'
  if (/DRAFT|待审批|草稿/i.test(s)) return 'DRAFT'
  return 'UNKNOWN'
}

// 只认「标记行」：可选 > 引用前缀 + 可选加粗 + Status:。
// 正文或表格里提到 `Status:` 的半句话不得覆盖真实状态。
const STATUS_MARKER = /^\s*>?\s*\*{0,2}\s*Status\s*:/i
const FENCE = /^\s*(?:```|~~~)/

// 围栏代码块里的 `status: normalizePlanStatus(last),` 不是状态标记行（真实档案踩过）。
function statusMarkers(body) {
  const markers = []
  let inFence = false
  for (const line of body.split(/\r?\n/)) {
    if (FENCE.test(line)) {
      inFence = !inFence
      continue
    }
    if (!inFence && STATUS_MARKER.test(line)) markers.push(line)
  }
  return markers
}

// ── 「需求提炼 → 目标」提取 ───────────────────────────────────────────────
//
// 计划档案的目标行格式实测不统一（四种已观测变体）：
//   ① `**目标**：散文`                     —— 训练页收起语义与接续态.md
//   ② `**目标（用户原话）**：` + 编号列表   —— 数据一致性收口…双端.md
//   ③ `**目标**：` 空标题 + `- ` 列表 / 散文段
//   ④ `**目标**` 无冒号，内容在下一行
// 只支持这四种变体，未命中即空数组——不追求穷举：格式再漂就反复加分支，
// 是结构性脆弱点（计划里已登记的 Challenge），此处明确划界。
const GOAL_SECTION = '需求提炼'
const HEADING_LINE = /^(#{1,6})\s+(.+?)\s*$/
// 标记行 = 可选引用前缀 + 可选列表符 + 可选加粗 + 「目标」+ 括注（加粗前/后都实测出现过）
// + 可选加粗 + 冒号/空白/行尾。
// 「**目标态数据流**」「> **目标平台**：」这类（目标后直接跟汉字）不匹配；
// 「**非目标**」也不匹配（前一位是非）。
const GOAL_MARKER =
  /^[\s>]*(?:[-+•]\s+)?\*{0,2}\s*目标\s*(?:（[^）]*）|\([^)]*\))?\s*\*{0,2}\s*(?:（[^）]*）|\([^)]*\))?\s*(?:[:：]|\s|$)/
const GOAL_STOP = /^[\s>]*(?:[-+•]\s+)?\*{0,2}\s*非目标/
// 下一个「**标签**」纯标记行也终止，但只认整行就是一个标签（冒号可有可无）——
// 散文里的 `**加粗词**` 不截断目标段（计划里登记的 Challenge）。
const BOLD_LABEL_LINE = /^[\s>]*\*\*[^*]+\*\*\s*[:：]?\s*$/
// `- item` / `* item` / `+ item` / `1. item` / `1、item` / `1) item`
const LIST_ITEM = /^\s*(?:[-*+]|\d+[.)、])\s+(.*)$/
const CHECKBOX_ITEM = /^\s*[-*+]\s*\[([xX ])\]/

const stripBold = (s) => s.replace(/\*\*/g, '').trim()

// 取某个标题节的行（终止于同级或更高级标题）。节内的更深子标题行丢弃、内容保留；
// 围栏代码块里的 `#` 不当标题。
function sectionLines(body, keyword) {
  const out = []
  let level = 0
  let inFence = false
  for (const line of body.split(/\r?\n/)) {
    if (FENCE.test(line)) {
      inFence = !inFence
      if (level > 0) out.push(line)
      continue
    }
    if (!inFence) {
      const heading = HEADING_LINE.exec(line)
      if (heading) {
        const depth = heading[1].length
        if (level > 0 && depth <= level) break // 同级/更高级标题 = 本节结束
        if (level === 0) {
          if (!heading[2].includes(keyword)) continue
          level = depth
          continue
        }
        continue // 节内的子标题：只留内容
      }
    }
    if (level > 0) out.push(line)
  }
  return out
}

// 从「## 需求提炼」章节的 `**目标**` 标记行提取目标条目。
// 容错第一职责：章节缺失、标记缺失、格式漂移都返回 []，绝不抛错。
export function parsePlanGoals(body) {
  if (typeof body !== 'string' || body === '') return []

  const lines = sectionLines(body, GOAL_SECTION)
  if (lines.length === 0) return []

  const goals = []
  let paragraph = []
  const flush = () => {
    const text = paragraph.join('').trim()
    if (text !== '') goals.push(text)
    paragraph = []
  }

  let started = false
  for (const line of lines) {
    // 终止：`**非目标**` 标记行 / 下一个纯 `**标签**` 行（`#` 标题已在 sectionLines 截断）
    const isGoalMarker = GOAL_MARKER.test(line)
    if (!isGoalMarker && (GOAL_STOP.test(line) || BOLD_LABEL_LINE.test(line))) {
      if (started) break
      continue
    }

    if (isGoalMarker) {
      if (started) break // 只认第一条目标标记行
      started = true
      const marker = GOAL_MARKER.exec(line)
      const inline = stripBold(line.slice(marker[0].length))
      if (inline !== '') goals.push(inline) // ① 冒号后非空散文 = 一条 goal
      continue
    }

    if (!started) continue
    if (line.trim() === '') {
      flush()
      continue
    }

    const item = LIST_ITEM.exec(line)
    if (item) {
      flush()
      const text = stripBold(item[1])
      if (text !== '') goals.push(text)
      continue
    }

    // 散文行：并入当前段落（中文换行不加空格，避免拼出空格缝）
    paragraph.push(stripBold(line))
  }
  flush()

  return goals
}

// 勾选框进度：`- [x]` 已完成 / `- [ ]` 未完成。全局统计（不限定章节）。
export function countCheckboxes(body) {
  if (typeof body !== 'string' || body === '') return { done: 0, total: 0 }
  let done = 0
  let total = 0
  for (const line of body.split(/\r?\n/)) {
    const m = CHECKBOX_ITEM.exec(line)
    if (!m) continue
    total += 1
    if (m[1] !== ' ') done += 1
  }
  return { done, total }
}

export function parsePlans(dir = PLANS_DIR) {
  if (typeof dir !== 'string' || dir === '') return []

  let entries = []
  try {
    entries = readdirSync(dir, { withFileTypes: true })
  } catch {
    return []
  }

  return entries
    .filter((e) => e.isFile() && e.name.endsWith('.md') && !e.name.startsWith('draft-'))
    .map((e) => {
      const abs = resolve(dir, e.name)
      let body = ''
      let bytes = 0
      let modifiedAt = ''
      try {
        body = readFileSync(abs, 'utf8')
        const stat = statSync(abs)
        bytes = stat.size
        modifiedAt = stat.mtime.toISOString()
      } catch {
        body = ''
      }
      const markers = statusMarkers(body)
      const last = markers.length > 0 ? markers[markers.length - 1] : ''
      const goals = parsePlanGoals(body)
      const checkboxes = countCheckboxes(body)
      return {
        file: e.name,
        status: normalizePlanStatus(last),
        statusRaw: last.trim(),
        bytes,
        modifiedAt,
        absPath: toPosix(abs),
        // 「## 需求提炼 → **目标**」提取结果：行级用 goals，整块展示用 goalText
        goals,
        goalText: goals.join('\n'),
        // 勾选框进度：`- [x]` 已完成 / `- [ ]` 未完成
        tasksDone: checkboxes.done,
        tasksTotal: checkboxes.total
      }
    })
}

// git log 用 `%h|%s|%ci`；subject 里可能自带 |，所以取首尾两个分隔符
export function parseGitLog(out) {
  if (typeof out !== 'string' || out.trim() === '') return []
  return out
    .split(/\r?\n/)
    .filter((l) => l.trim() !== '')
    .map((line) => {
      const i = line.indexOf('|')
      const j = line.lastIndexOf('|')
      if (i < 0 || j <= i) return { hash: line.trim(), subject: '', date: '' }
      return {
        hash: line.slice(0, i).trim(),
        subject: line.slice(i + 1, j),
        date: line.slice(j + 1).trim()
      }
    })
}

export function parseGitStatus(out) {
  if (typeof out !== 'string' || out.trim() === '') return []
  return out
    .split(/\r?\n/)
    .filter((l) => l.trim() !== '')
    .map((line) => {
      const code = line.slice(0, 2)
      const rest = line.slice(3)
      const arrow = rest.indexOf(' -> ')
      const path = toPosix(arrow >= 0 ? rest.slice(arrow + 4) : rest)
      const change = { code, path, forbidden: FORBIDDEN.test(path) }
      if (arrow >= 0) change.origPath = toPosix(rest.slice(0, arrow))
      return change
    })
}

// 读不到 git 只降级（log/status 空 + error 文案 + available:false），不抛
export function parseGit(cwd = REPO_ROOT) {
  const dir = typeof cwd === 'string' && cwd !== '' ? cwd : REPO_ROOT
  const run = (args) => execFileSync('git', args, { cwd: dir, encoding: 'utf8', maxBuffer: 8 * 1024 * 1024 })
  try {
    // `%ci` = git 默认日期格式（2026-11-01 15:18:38 +0800），契约见 test 的日期断言
    const log = parseGitLog(run(['log', `-n${COMMIT_LIMIT}`, '--pretty=format:%h|%s|%ci']))
    const head = run(['rev-parse', '--short', 'HEAD']).trim()
    // HEAD 提交时间另取 ISO 8601（%cI）：要与 COMMAND.md 的 mtime（toISOString）直接比大小，
    // 不能复用 log[0].date（%ci 的 `YYYY-MM-DD HH:mm:ss +0800` 解析依赖宿主实现）
    const headCommittedAt = run(['log', '-1', '--pretty=format:%cI']).trim()
    const status = parseGitStatus(run(['status', '--porcelain']))
    return { available: true, head, headCommittedAt, log, status }
  } catch (err) {
    return { available: false, head: '', headCommittedAt: '', log: [], status: [], error: String(err) }
  }
}

// COMMAND.md 是替换式总账（人工维护、会滞后），git 是实时真值——两者会漂。
// 判据只用三个可测量的量：状态源 mtime、HEAD 提交时间、git status 项数，不做语义推断。
const UNCOMMITTED_CLAIM = /共\s*(\d+)\s*项/

// 总账自述「工作区未提交改动（… 共 N 项）」：取首个同时含「未提交」与「共 N 项」的行。
// 表格里「工作区无未提交残留」这类半句话没有项数，不会误取。
export function claimUncommittedCount(raw) {
  if (typeof raw !== 'string' || raw === '') return null
  for (const line of raw.split(/\r?\n/)) {
    if (!line.includes('未提交')) continue
    const m = line.match(UNCOMMITTED_CLAIM)
    if (m) return Number(m[1])
  }
  return null
}

// 漂移判定：stale=true 即看板要标「状态总账可能过期」。
// 只报可复现的读数矛盾，不猜内容对错——总账写了什么由人判，项数与时间由机器判。
export function computeDrift(command, git) {
  const cmd = command && typeof command === 'object' ? command : {}
  const g = git && typeof git === 'object' ? git : {}
  const status = Array.isArray(g.status) ? g.status : []
  const claimedUncommitted = claimUncommittedCount(cmd.raw)
  const commandUpdatedAt = typeof cmd.updatedAt === 'string' && cmd.updatedAt !== '' ? cmd.updatedAt : null
  const headCommittedAt = typeof g.headCommittedAt === 'string' && g.headCommittedAt !== '' ? g.headCommittedAt : null
  const reasons = []

  // git 不可用时不判定：没有真值可比，报「过期」就是假警报
  if (g.available === true) {
    const cmdMs = commandUpdatedAt === null ? NaN : Date.parse(commandUpdatedAt)
    const headMs = headCommittedAt === null ? NaN : Date.parse(headCommittedAt)
    if (!Number.isNaN(cmdMs) && !Number.isNaN(headMs) && cmdMs < headMs) {
      reasons.push(`状态源最后更新 ${commandUpdatedAt}，早于 HEAD 提交 ${headCommittedAt}`)
    }
    if (claimedUncommitted !== null && claimedUncommitted !== status.length) {
      reasons.push(`状态源自述 ${claimedUncommitted} 项未提交，git status 实测 ${status.length} 项`)
    }
  }

  return {
    stale: reasons.length > 0,
    reasons,
    commandUpdatedAt,
    headCommittedAt,
    claimedUncommitted,
    actualUncommitted: status.length
  }
}

export function collectBoardData(options) {
  const opts = options && typeof options === 'object' ? options : {}
  const commandPath = typeof opts.commandPath === 'string' ? opts.commandPath : COMMAND_PATH
  const plansDir = typeof opts.plansDir === 'string' ? opts.plansDir : PLANS_DIR
  const cwd = typeof opts.cwd === 'string' ? opts.cwd : REPO_ROOT

  const command = { path: toPosix(commandPath), sections: [], raw: '' }
  try {
    command.raw = readFileSync(commandPath, 'utf8')
    command.sections = parseCommand(command.raw)
    command.updatedAt = statSync(commandPath).mtime.toISOString()
  } catch (err) {
    command.error = `读不到状态源 ${commandPath}：${String(err)}`
  }

  const git = parseGit(cwd)

  return {
    generatedAt: new Date().toISOString(),
    command,
    plans: parsePlans(plansDir),
    git,
    // 漂移在数据层算一次：前端与静态 HTML 只负责呈现，避免两端各写一套判据又各自漂
    drift: computeDrift(command, git)
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 静态渲染（--render）：一次扫描直接产出可双击打开的 board.html
//
// 与 vite dev server 方案共享同一份 collectBoardData()，差别只在「数据怎么到页面」：
//   · dev（vite.board.config.ts）：中间件每请求实时聚合，改 COMMAND.md 刷新即见；
//   · 静态（本模块 --render）：一次性写 board-dist/board-data.json + board-dist/index.html。
// 看板只读聚合低频变更的 Markdown 与 git，实时性收益有限，而静态生成把运维面降到零：
// 无常驻进程、无端口、无 dev-only 中间件概念，产物可拷贝/归档/直接丢给浏览器。
// 刻意不引入 React：静态模式只需把已聚合的数据铺成表格，单文件自包含即可。
// ─────────────────────────────────────────────────────────────────────────────

const HTML_ESCAPES = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }
const esc = (v) => String(v === undefined || v === null ? '' : v).replace(/[&<>"']/g, (c) => HTML_ESCAPES[c])

const BADGE = {
  APPROVED: 'ok',
  EXECUTED: 'done',
  DRAFT: 'wait',
  REJECTED: 'bad',
  UNKNOWN: 'mute'
}

function renderTable(header, rows) {
  const head = header.length > 0
    ? `<thead><tr>${header.map((c) => `<th>${esc(c)}</th>`).join('')}</tr></thead>`
    : ''
  const body = rows.length > 0
    ? `<tbody>${rows.map((r) => `<tr>${r.map((c) => `<td>${esc(c)}</td>`).join('')}</tr>`).join('')}</tbody>`
    : ''
  return `<table>${head}${body}</table>`
}

function renderCommand(command) {
  if (command.error) return `<section class="card"><p class="warn">${esc(command.error)}</p></section>`
  if (!Array.isArray(command.sections) || command.sections.length === 0) {
    return '<section class="card"><p class="muted">状态源没有 ## 二级标题节（格式漂移降级为空集）。</p></section>'
  }
  return command.sections
    .map((s) => {
      const text = s.text ? `<pre class="prose">${esc(s.text)}</pre>` : ''
      const tables = (s.tables || []).map((t) => renderTable(t.header || [], t.rows || [])).join('\n')
      return `<section class="card"><h2>${esc(s.title)}</h2>${text}${tables}</section>`
    })
    .join('\n')
}

function renderPlans(plans) {
  if (!Array.isArray(plans) || plans.length === 0) return '<p class="muted">无计划档案。</p>'
  const rows = plans
    .map((p) => `<tr>
      <td>${esc(p.file)}</td>
      <td><span class="badge ${BADGE[p.status] || BADGE.UNKNOWN}">${esc(p.status)}</span></td>
      <td class="muted">${esc(p.statusRaw)}</td>
      <td class="num">${esc(p.bytes)}</td>
      <td class="num muted">${esc(p.modifiedAt)}</td>
    </tr>`)
    .join('')
  return `<table><thead><tr><th>文件</th><th>状态</th><th>标记原文</th><th>字节</th><th>修改时间</th></tr></thead><tbody>${rows}</tbody></table>`
}

function renderGit(git) {
  if (!git.available) return `<p class="warn">git 不可用：${esc(git.error || '未知原因')}</p>`

  const changeRows = git.status.length === 0
    ? '<tr><td colspan="2" class="muted">工作区干净</td></tr>'
    : git.status
        .map((c) => {
          const cls = c.forbidden ? ' class="forbidden"' : ''
          const orig = c.origPath ? ` <span class="muted">← ${esc(c.origPath)}</span>` : ''
          const flag = c.forbidden ? ' <span class="badge bad">禁提交</span>' : ''
          return `<tr${cls}><td class="code">${esc((c.code || '').trim() || '??')}</td><td>${esc(c.path)}${orig}${flag}</td></tr>`
        })
        .join('')

  const logRows = git.log.length === 0
    ? '<tr><td colspan="3" class="muted">无提交记录</td></tr>'
    : git.log
        .map((c) => `<tr><td class="code">${esc(c.hash)}</td><td>${esc(c.subject)}</td><td class="num muted">${esc(c.date)}</td></tr>`)
        .join('')

  return `<div class="grid2">
  <section class="card"><h2>未提交改动 <span class="muted">${git.status.length}</span></h2><table><thead><tr><th>码</th><th>路径</th></tr></thead><tbody>${changeRows}</tbody></table></section>
  <section class="card"><h2>最近提交 <span class="muted">${git.log.length}</span></h2><table><thead><tr><th>hash</th><th>主题</th><th>时间</th></tr></thead><tbody>${logRows}</tbody></table></section>
</div>`
}

const BOARD_CSS = `
:root{color-scheme:dark}
*{box-sizing:border-box}
body{margin:0;padding:24px;background:#11131a;color:#e6e8ef;font:14px/1.5 -apple-system,"Segoe UI",Roboto,"Helvetica Neue",Arial,"PingFang SC","Microsoft YaHei",sans-serif}
h1{font-size:18px;margin:0 0 4px}
h2{font-size:14px;margin:0 0 12px;font-weight:600;color:#c8cddd}
a{color:#7fb0ff}
.wrap{max-width:1200px;margin:0 auto}
.card{background:#171a23;border:1px solid #242836;border-radius:10px;padding:16px;margin:0 0 16px}
.grid2{display:grid;grid-template-columns:1fr 1fr;gap:16px}
@media (max-width:900px){.grid2{grid-template-columns:1fr}}
header.card{display:flex;flex-wrap:wrap;gap:8px 20px;align-items:baseline}
.kv{display:flex;gap:6px;align-items:baseline}
.kv b{font-weight:600;color:#8f97ad;font-size:12px;text-transform:uppercase;letter-spacing:.04em}
table{width:100%;border-collapse:collapse;font-size:13px}
th,td{text-align:left;padding:6px 8px;border-bottom:1px solid #232838;vertical-align:top}
th{color:#8f97ad;font-weight:600;font-size:12px;text-transform:uppercase;letter-spacing:.04em}
tbody tr:last-child td{border-bottom:none}
tr.forbidden td{background:#3a1620;color:#ff8f9e}
.code{font-family:ui-monospace,SFMono-Regular,Consolas,monospace;color:#9fd3ff;white-space:nowrap}
.num{font-variant-numeric:tabular-nums;white-space:nowrap}
.muted{color:#7b8296}
.warn{color:#ffb347;margin:0}
.prose{white-space:pre-wrap;margin:0 0 12px;color:#c8cddd;font:inherit}
.badge{display:inline-block;padding:1px 8px;border-radius:999px;font-size:11px;font-weight:600;letter-spacing:.03em}
.badge.ok{background:#123524;color:#63e6a8}
.badge.done{background:#152537;color:#7fb0ff}
.badge.wait{background:#332a12;color:#ffcf6b}
.badge.bad{background:#3a1620;color:#ff8f9e}
.badge.mute{background:#232838;color:#8f97ad}
footer{margin:8px 0 0;text-align:center}
`

export function renderBoardHtml(data) {
  const d = data && typeof data === 'object' ? data : {}
  const command = d.command && typeof d.command === 'object'
    ? d.command
    : { path: '', sections: [], raw: '', error: '数据缺失' }
  const plans = Array.isArray(d.plans) ? d.plans : []
  const rawGit = d.git && typeof d.git === 'object'
    ? { available: false, head: '', headCommittedAt: '', log: [], status: [], ...d.git }
    : { available: false, head: '', headCommittedAt: '', log: [], status: [], error: '数据缺失' }
  // 契约是「降级不抛错」：注入/降级数据里 log、status 可能缺失或非数组
  const git = {
    ...rawGit,
    log: Array.isArray(rawGit.log) ? rawGit.log : [],
    status: Array.isArray(rawGit.status) ? rawGit.status : []
  }

  const forbidden = git.status.filter((c) => c.forbidden).length
  // 注入数据没带 drift 时重算一遍：静态看板与 React 看板共用同一判据
  const drift = d.drift && typeof d.drift === 'object'
    ? { stale: false, reasons: [], commandUpdatedAt: null, headCommittedAt: null, claimedUncommitted: null, actualUncommitted: git.status.length, ...d.drift }
    : computeDrift(command, git)
  const driftReasons = Array.isArray(drift.reasons) ? drift.reasons : []
  const driftBanner = drift.stale
    ? `<p class="warn">⚠ 状态总账可能过期：${esc(driftReasons.join('；'))}</p>`
    : ''
  const statusLine = Object.keys(BADGE)
    .map((s) => `${s} ${plans.filter((p) => p.status === s).length}`)
    .join(' · ')

  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>FitTracker · 开发看板（静态快照）</title>
<style>${BOARD_CSS}</style>
</head>
<body>
<div class="wrap">
<header class="card">
  <div class="kv"><b>HEAD</b><span class="code">${esc(git.head || '—')}</span></div>
  <div class="kv"><b>HEAD 提交</b><span class="num">${esc(git.headCommittedAt || '—')}</span></div>
  <div class="kv"><b>生成于</b><span class="num">${esc(d.generatedAt)}</span></div>
  <div class="kv"><b>状态源</b><span class="code">${esc(command.path)}</span>${command.updatedAt ? ` <span class="muted">${esc(command.updatedAt)}</span>` : ''}</div>
  <div class="kv"><b>计划</b><span class="muted">${esc(statusLine)}</span></div>
  <div class="kv"><b>未提交</b><span class="num">${git.status.length}</span>${forbidden > 0 ? ` <span class="badge bad">禁提交 ${forbidden}</span>` : ''}</div>
  <div class="kv muted">静态快照 · 数据同时落在 board-data.json</div>
</header>
${driftBanner}
<h1>状态源</h1>
${renderCommand(command)}
<h1>计划档案</h1>
<section class="card">${renderPlans(plans)}</section>
<h1>Git</h1>
${renderGit(git)}
<footer class="muted">由 node tools/board-data.mjs --render 生成</footer>
</div>
</body>
</html>
`
}

// 一次性扫描 + 落盘：board-data.json（机器可读快照）与 index.html（人读）。
// data 可注入（测试用），缺省自行 collectBoardData，走的就是 dev server 那条同一路径。
export function renderBoard(options) {
  const opts = options && typeof options === 'object' ? options : {}
  const outDir = typeof opts.outDir === 'string' && opts.outDir !== ''
    ? resolve(opts.outDir)
    : resolve(REPO_ROOT, 'board-dist')
  const data = opts.data && typeof opts.data === 'object' ? opts.data : collectBoardData(opts)

  mkdirSync(outDir, { recursive: true })
  const jsonPath = resolve(outDir, 'board-data.json')
  const htmlPath = resolve(outDir, 'index.html')
  writeFileSync(jsonPath, JSON.stringify(data, null, 2))
  writeFileSync(htmlPath, renderBoardHtml(data))
  return { outDir, jsonPath, htmlPath, data }
}

const USAGE = `用法: node tools/board-data.mjs [--render] [--out <dir>]

  --render     一次性聚合 .rivet + git，输出静态看板（默认动作）
  --out <dir>  输出目录（默认 <repo>/board-dist）
  -h, --help   显示本帮助
`

function cliMain(argv) {
  const args = argv.slice(2)
  let outDir = ''
  for (let i = 0; i < args.length; i += 1) {
    const a = args[i]
    if (a === '--render') continue
    if (a === '-h' || a === '--help') {
      process.stdout.write(USAGE)
      return 0
    }
    if (a === '--out') {
      outDir = args[i + 1] || ''
      i += 1
      if (outDir === '') {
        process.stderr.write('--out 需要一个目录参数\n')
        return 2
      }
      continue
    }
    if (a.startsWith('--out=')) {
      outDir = a.slice('--out='.length)
      if (outDir === '') {
        process.stderr.write('--out 需要一个目录参数\n')
        return 2
      }
      continue
    }
    process.stderr.write(`未知参数：${a}\n${USAGE}`)
    return 2
  }

  const result = renderBoard({ outDir })
  const { data } = result
  process.stdout.write(`board-data: 静态看板已生成\n`)
  process.stdout.write(`  html  ${toPosix(result.htmlPath)}\n`)
  process.stdout.write(`  json  ${toPosix(result.jsonPath)}\n`)
  process.stdout.write(`  command sections=${data.command.sections.length} plans=${data.plans.length} git=${data.git.available ? 'ok' : 'unavailable'}\n`)
  if (data.command.error) process.stderr.write(`  警告: ${data.command.error}\n`)
  if (!data.git.available) process.stderr.write(`  警告: git 不可用（${data.git.error}），已降级为空集\n`)
  return 0
}

// 只有被当脚本直跑时才产出（被 vite.board.config.ts import 时保持零副作用）
const isDirectRun = (() => {
  const entry = process.argv[1]
  if (!entry) return false
  const norm = (p) => resolve(p).replace(/\\/g, '/').toLowerCase()
  try {
    return norm(entry) === norm(fileURLToPath(import.meta.url))
  } catch {
    return false
  }
})()

if (isDirectRun) process.exitCode = cliMain(process.argv)
