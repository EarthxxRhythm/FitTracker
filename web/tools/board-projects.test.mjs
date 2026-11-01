// web/tools/board-projects.test.mjs
// 开发看板「项目管理」数据层单测。直跑：node --test web/tools/board-projects.test.mjs
// （根级 tools/run-tests.mjs 不扫 web/tools/，故以 node --test 直跑为准。）
//
// 契约以 web/tools/board-projects.d.mts 为准：
//   loadProjects()  → { projects[], improvements[], todos[] }
//   saveProjects()  / addProject / advanceProject / addTodo / toggleTodo / removeTodo
//   addImprovement / applyOperation(state, op)
//
// 容错第一职责（与 board-data.mjs 同源口径）：
//   文件不存在 → 空结构（不抛错）；JSON 损坏 → 备份后重置（不抛错）。

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, writeFileSync, readFileSync, readdirSync, rmSync, existsSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

import {
  PROJECT_STATUSES,
  addImprovement,
  addProject,
  addTodo,
  advanceProject,
  applyOperation,
  emptyState,
  loadProjects,
  removeImprovement,
  removeTodo,
  saveProjects,
  toggleImprovement,
  toggleTodo
} from './board-projects.mjs'

function withTempDir(fn) {
  const dir = mkdtempSync(join(tmpdir(), 'board-projects-'))
  try {
    return fn(join(dir, 'board-projects.json'))
  } finally {
    rmSync(dir, { recursive: true, force: true })
  }
}

const AT = '2026-01-01T00:00:00.000Z'

test('loadProjects: 文件不存在 → 空结构，不抛错', () =>
  withTempDir((file) => {
    assert.equal(existsSync(file), false)
    assert.deepEqual(loadProjects(file), emptyState())
  }))

test('saveProjects → loadProjects 往返一致', () =>
  withTempDir((file) => {
    const state = addProject(emptyState(), { name: '看板项目管理' }, AT)
    saveProjects(state, file)
    const back = loadProjects(file)
    assert.equal(back.projects.length, 1)
    assert.equal(back.projects[0].name, '看板项目管理')
    assert.deepEqual(back, state)
  }))

test('JSON 损坏 → 备份原文件并重置为空结构', () =>
  withTempDir((file) => {
    writeFileSync(file, '{ 这不是 JSON ', 'utf8')
    const state = loadProjects(file)
    assert.deepEqual(state, emptyState())
    // 备份必须真落盘（用户数据不会被静默吞掉）
    const backups = readdirSync(join(file, '..')).filter((n) => n.includes('.corrupt-') && n.endsWith('.bak'))
    assert.equal(backups.length, 1)
    assert.match(readFileSync(join(file, '..', backups[0]), 'utf8'), /这不是 JSON/)
  }))

test('addProject: 默认 backlog / progress 0 / 时间戳齐全 / id 递增', () => {
  let state = addProject(emptyState(), { name: 'A' }, AT)
  state = addProject(state, { name: 'B', note: '备注' }, AT)
  assert.equal(state.projects.length, 2)
  const [a, b] = state.projects
  assert.equal(a.status, 'backlog')
  assert.equal(a.progress, 0)
  assert.equal(a.createdAt, AT)
  assert.equal(a.updatedAt, AT)
  assert.equal(b.note, '备注')
  assert.notEqual(a.id, b.id)
})

test('addProject: 空 name 拒绝（抛错，不写入脏数据）', () => {
  assert.throws(() => addProject(emptyState(), { name: '   ' }), /name/)
})

test('advanceProject: backlog → active → done → archived，且到终态不越界', () => {
  let state = addProject(emptyState(), { name: 'A' }, AT)
  const id = state.projects[0].id
  const seen = []
  for (let i = 0; i < PROJECT_STATUSES.length + 2; i += 1) {
    state = advanceProject(state, id, AT)
    seen.push(state.projects[0].status)
  }
  assert.deepEqual(seen.slice(0, 3), ['active', 'done', 'archived'])
  assert.equal(seen[4], 'archived')
  assert.equal(state.projects[0].progress, 100)
})

test('advanceProject: 未知 id → 抛错', () => {
  assert.throws(() => advanceProject(emptyState(), 'p-999'), /unknown/)
})

test('addTodo / toggleTodo / removeTodo', () => {
  let state = addProject(emptyState(), { name: 'A' }, AT)
  const projectId = state.projects[0].id
  state = addTodo(state, { text: '写单测', projectId }, AT)
  assert.equal(state.todos.length, 1)
  assert.equal(state.todos[0].done, false)
  assert.equal(state.todos[0].projectId, projectId)

  const todoId = state.todos[0].id
  state = toggleTodo(state, todoId)
  assert.equal(state.todos[0].done, true)
  state = toggleTodo(state, todoId)
  assert.equal(state.todos[0].done, false)

  state = removeTodo(state, todoId)
  assert.equal(state.todos.length, 0)
})

test('addImprovement: 默认 mid / status open，非法优先级回落 mid', () => {
  let state = addImprovement(emptyState(), { text: '拆分 plugin' })
  assert.equal(state.improvements[0].priority, 'mid')
  assert.equal(state.improvements[0].status, 'open')
  state = addImprovement(state, { text: 'X', priority: 'urgent' })
  assert.equal(state.improvements[1].priority, 'mid')
})

test('toggleImprovement / removeImprovement: open↔done 切换，删除，未知 id 抛错', () => {
  let state = addImprovement(emptyState(), { text: '拆分 plugin' })
  const id = state.improvements[0].id

  state = toggleImprovement(state, id)
  assert.equal(state.improvements[0].status, 'done')
  state = toggleImprovement(state, id)
  assert.equal(state.improvements[0].status, 'open')

  state = removeImprovement(state, id)
  assert.equal(state.improvements.length, 0)

  assert.throws(() => toggleImprovement(emptyState(), 'i-999'), /unknown improvement/)
  assert.throws(() => removeImprovement(emptyState(), 'i-999'), /unknown improvement/)
})

test('applyOperation: 分派五类操作，未知类型抛错', () => {
  let state = emptyState()
  state = applyOperation(state, { type: 'add-project', name: 'P', at: AT })
  const id = state.projects[0].id
  state = applyOperation(state, { type: 'advance-project', id, at: AT })
  assert.equal(state.projects[0].status, 'active')
  state = applyOperation(state, { type: 'add-todo', text: 'T', at: AT })
  const todoId = state.todos[0].id
  state = applyOperation(state, { type: 'toggle-todo', id: todoId })
  assert.equal(state.todos[0].done, true)
  state = applyOperation(state, { type: 'add-improvement', text: 'I', priority: 'high' })
  assert.equal(state.improvements[0].priority, 'high')
  const impId = state.improvements[0].id
  state = applyOperation(state, { type: 'toggle-improvement', id: impId })
  assert.equal(state.improvements[0].status, 'done')
  state = applyOperation(state, { type: 'remove-improvement', id: impId })
  assert.equal(state.improvements.length, 0)
  assert.throws(() => applyOperation(state, { type: 'nope' }), /unknown operation/)
})

test('纯函数：所有操作不修改入参', () => {
  const base = emptyState()
  const frozen = JSON.stringify(base)
  addProject(base, { name: 'A' }, AT)
  assert.equal(JSON.stringify(base), frozen)
})

test('normalizeState: 缺字段/脏数组降级为合法结构', () =>
  withTempDir((file) => {
    writeFileSync(file, JSON.stringify({ projects: 'oops', todos: [{ text: 'T' }] }), 'utf8')
    const back = loadProjects(file)
    assert.deepEqual(back.projects, [])
    assert.deepEqual(back.improvements, [])
    assert.equal(back.todos.length, 1)
    assert.equal(back.todos[0].done, false)
    assert.ok(back.todos[0].id, '缺 id 的条目应补出 id')
    // saveProjects 同样归一化入参
    const saved = saveProjects({ projects: 'oops' }, file)
    assert.deepEqual(saved, emptyState())
  }))
