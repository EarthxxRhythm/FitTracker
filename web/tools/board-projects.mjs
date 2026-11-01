// web/tools/board-projects.mjs
// 开发看板「项目管理」数据层：读写 .rivet/board-projects.json（本地文件，.rivet/ 已 gitignore）。
//
// 定位：dev-only 写路径。静态产物（board-dist）没有中间件，写操作必然失效——
// 因此写入口只在 npm run board（vite dev）下可用，board:build 产物保持只读。
//
// 契约以 web/tools/board-projects.d.mts 为准，行为契约见 web/tools/board-projects.test.mjs。
// 容错第一职责（与 board-data.mjs 同源口径）：文件不存在 → 空结构；JSON 损坏 → 备份后重置。
// 绝不因数据格式问题抛错（只有非法操作参数才抛，由端点转成 400）。
import { readFileSync, writeFileSync, mkdirSync, copyFileSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
export const REPO_ROOT = resolve(here, '..', '..')
export const PROJECTS_PATH = resolve(REPO_ROOT, '.rivet', 'board-projects.json')

// 状态机：backlog → active → done → archived（archived 为终态）
export const PROJECT_STATUSES = ['backlog', 'active', 'done', 'archived']
export const PRIORITIES = ['high', 'mid', 'low']

const TERMINAL = new Set(['done', 'archived'])

const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v)
const str = (v, d = '') => (typeof v === 'string' ? v : v === undefined || v === null ? d : String(v))
const nowIso = () => new Date().toISOString()

export function emptyState() {
  return { projects: [], improvements: [], todos: [] }
}

function clampProgress(v) {
  const n = Number(v)
  if (!Number.isFinite(n)) return 0
  return Math.min(100, Math.max(0, Math.round(n)))
}

// id 形如 p-1 / t-3 / i-2：取同类最大序号 + 1，可读、可测、不依赖时钟
function nextId(items, prefix) {
  let max = 0
  for (const it of items) {
    const id = str(it && it.id)
    if (id.startsWith(prefix + '-')) {
      const n = Number(id.slice(prefix.length + 1))
      if (Number.isInteger(n) && n > max) max = n
    }
  }
  return `${prefix}-${max + 1}`
}

// 脏数据降级：非法条目丢弃，缺字段补默认，缺 id 补 id。永不抛错。
export function normalizeState(value) {
  const src = isObj(value) ? value : {}

  const projects = []
  if (Array.isArray(src.projects)) {
    for (const raw of src.projects) {
      if (!isObj(raw)) continue
      const id = str(raw.id) || nextId(projects, 'p')
      const status = PROJECT_STATUSES.includes(raw.status) ? raw.status : 'backlog'
      const createdAt = str(raw.createdAt) || nowIso()
      projects.push({
        id,
        name: str(raw.name),
        status,
        progress: TERMINAL.has(status) ? 100 : clampProgress(raw.progress),
        note: str(raw.note),
        createdAt,
        updatedAt: str(raw.updatedAt) || createdAt
      })
    }
  }

  const improvements = []
  if (Array.isArray(src.improvements)) {
    for (const raw of src.improvements) {
      if (!isObj(raw)) continue
      improvements.push({
        id: str(raw.id) || nextId(improvements, 'i'),
        text: str(raw.text),
        priority: PRIORITIES.includes(raw.priority) ? raw.priority : 'mid',
        status: raw.status === 'done' ? 'done' : 'open'
      })
    }
  }

  const todos = []
  if (Array.isArray(src.todos)) {
    for (const raw of src.todos) {
      if (!isObj(raw)) continue
      const todo = {
        id: str(raw.id) || nextId(todos, 't'),
        text: str(raw.text),
        done: raw.done === true
      }
      const projectId = str(raw.projectId)
      if (projectId) todo.projectId = projectId
      todos.push(todo)
    }
  }

  return { projects, improvements, todos }
}

// JSON 损坏：先备份原文件（用户数据不被静默吞掉），再重置。
function backupCorrupt(file) {
  try {
    const stamp = nowIso().replace(/[:.]/g, '-')
    const target = `${file}.corrupt-${stamp}.bak`
    copyFileSync(file, target)
    return target
  } catch {
    return null
  }
}

export function loadProjects(file = PROJECTS_PATH) {
  let raw
  try {
    raw = readFileSync(file, 'utf8')
  } catch {
    return emptyState() // 文件不存在 / 不可读 → 空结构
  }
  try {
    return normalizeState(JSON.parse(raw))
  } catch {
    backupCorrupt(file)
    return emptyState()
  }
}

export function saveProjects(state, file = PROJECTS_PATH) {
  const data = normalizeState(state)
  mkdirSync(dirname(file), { recursive: true })
  writeFileSync(file, JSON.stringify(data, null, 2) + '\n', 'utf8')
  return data
}

// ── 纯操作：返回新状态，不修改入参 ────────────────────────────────────────────

export function addProject(state, input = {}, at = nowIso()) {
  const base = normalizeState(state)
  const name = str(input && input.name).trim()
  if (!name) throw new Error('project name is required')
  const project = {
    id: nextId(base.projects, 'p'),
    name,
    status: 'backlog',
    progress: 0,
    note: str(input && input.note),
    createdAt: at,
    updatedAt: at
  }
  return { ...base, projects: [...base.projects, project] }
}

export function advanceProject(state, id, at = nowIso()) {
  const base = normalizeState(state)
  const idx = base.projects.findIndex((p) => p.id === id)
  if (idx === -1) throw new Error(`unknown project: ${str(id)}`)
  const cur = base.projects[idx]
  const i = PROJECT_STATUSES.indexOf(cur.status)
  const next = PROJECT_STATUSES[Math.min((i < 0 ? 0 : i) + 1, PROJECT_STATUSES.length - 1)]
  const updated = {
    ...cur,
    status: next,
    progress: TERMINAL.has(next) ? 100 : cur.progress,
    updatedAt: at
  }
  const projects = base.projects.slice()
  projects[idx] = updated
  return { ...base, projects }
}

export function addTodo(state, input = {}) {
  const base = normalizeState(state)
  const text = str(input && input.text).trim()
  if (!text) throw new Error('todo text is required')
  const todo = { id: nextId(base.todos, 't'), text, done: false }
  const projectId = str(input && input.projectId)
  if (projectId) todo.projectId = projectId
  return { ...base, todos: [...base.todos, todo] }
}

export function toggleTodo(state, id) {
  const base = normalizeState(state)
  const idx = base.todos.findIndex((t) => t.id === id)
  if (idx === -1) throw new Error(`unknown todo: ${str(id)}`)
  const todos = base.todos.slice()
  todos[idx] = { ...todos[idx], done: !todos[idx].done }
  return { ...base, todos }
}

export function removeTodo(state, id) {
  const base = normalizeState(state)
  const idx = base.todos.findIndex((t) => t.id === id)
  if (idx === -1) throw new Error(`unknown todo: ${str(id)}`)
  const todos = base.todos.slice()
  todos.splice(idx, 1)
  return { ...base, todos }
}

export function addImprovement(state, input = {}) {
  const base = normalizeState(state)
  const text = str(input && input.text).trim()
  if (!text) throw new Error('improvement text is required')
  const priority = PRIORITIES.includes(input && input.priority) ? input.priority : 'mid'
  const improvement = { id: nextId(base.improvements, 'i'), text, priority, status: 'open' }
  return { ...base, improvements: [...base.improvements, improvement] }
}

export function toggleImprovement(state, id) {
  const base = normalizeState(state)
  const idx = base.improvements.findIndex((it) => it.id === id)
  if (idx === -1) throw new Error(`unknown improvement: ${str(id)}`)
  const improvements = base.improvements.slice()
  improvements[idx] = { ...improvements[idx], status: improvements[idx].status === 'done' ? 'open' : 'done' }
  return { ...base, improvements }
}

export function removeImprovement(state, id) {
  const base = normalizeState(state)
  const idx = base.improvements.findIndex((it) => it.id === id)
  if (idx === -1) throw new Error(`unknown improvement: ${str(id)}`)
  const improvements = base.improvements.slice()
  improvements.splice(idx, 1)
  return { ...base, improvements }
}

// POST /api/board-projects 的指令分派：body 即操作指令，返回新状态。
export function applyOperation(state, op) {
  if (!isObj(op)) throw new Error('operation must be an object')
  switch (op.type) {
    case 'add-project':
      return addProject(state, { name: op.name, note: op.note }, op.at ? str(op.at) : undefined)
    case 'advance-project':
      return advanceProject(state, str(op.id), op.at ? str(op.at) : undefined)
    case 'add-todo':
      return addTodo(state, { text: op.text, projectId: op.projectId })
    case 'toggle-todo':
      return toggleTodo(state, str(op.id))
    case 'remove-todo':
      return removeTodo(state, str(op.id))
    case 'add-improvement':
      return addImprovement(state, { text: op.text, priority: op.priority })
    case 'toggle-improvement':
      return toggleImprovement(state, str(op.id))
    case 'remove-improvement':
      return removeImprovement(state, str(op.id))
    default:
      throw new Error(`unknown operation type: ${str(op.type)}`)
  }
}
