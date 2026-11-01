// board-projects.mjs 的类型声明（vite.board.config.ts 以 TS 导入它，需要可解析的 .d.mts，
// 与 board-data.d.mts 同源做法）。行为契约见 board-projects.test.mjs。

export type ProjectStatus = 'backlog' | 'active' | 'done' | 'archived'
export type ImprovementPriority = 'high' | 'mid' | 'low'
export type ImprovementStatus = 'open' | 'done'

export interface BoardProject {
  id: string
  name: string
  status: ProjectStatus
  /** 0–100；done / archived 恒为 100 */
  progress: number
  note: string
  createdAt: string
  updatedAt: string
}

export interface BoardImprovement {
  id: string
  text: string
  priority: ImprovementPriority
  status: ImprovementStatus
}

export interface BoardTodo {
  id: string
  text: string
  done: boolean
  projectId?: string
}

export interface BoardProjectsState {
  projects: BoardProject[]
  improvements: BoardImprovement[]
  todos: BoardTodo[]
}

export type BoardOperation =
  | { type: 'add-project'; name: string; note?: string; at?: string }
  | { type: 'advance-project'; id: string; at?: string }
  | { type: 'add-todo'; text: string; projectId?: string }
  | { type: 'toggle-todo'; id: string }
  | { type: 'remove-todo'; id: string }
  | { type: 'add-improvement'; text: string; priority?: ImprovementPriority }
  | { type: 'toggle-improvement'; id: string }
  | { type: 'remove-improvement'; id: string }

export declare const REPO_ROOT: string
export declare const PROJECTS_PATH: string
export declare const PROJECT_STATUSES: readonly ProjectStatus[]
export declare const PRIORITIES: readonly ImprovementPriority[]

export declare function emptyState(): BoardProjectsState
export declare function normalizeState(value: unknown): BoardProjectsState
/** 文件不存在 / JSON 损坏 → 空结构（损坏时先落备份 .corrupt-*.bak），绝不抛错 */
export declare function loadProjects(file?: string): BoardProjectsState
/** 写盘并返回归一化后的状态 */
export declare function saveProjects(state: BoardProjectsState, file?: string): BoardProjectsState

export declare function addProject(
  state: BoardProjectsState,
  input?: { name?: string; note?: string },
  at?: string
): BoardProjectsState
export declare function advanceProject(state: BoardProjectsState, id: string, at?: string): BoardProjectsState
export declare function addTodo(state: BoardProjectsState, input?: { text?: string; projectId?: string }): BoardProjectsState
export declare function toggleTodo(state: BoardProjectsState, id: string): BoardProjectsState
export declare function removeTodo(state: BoardProjectsState, id: string): BoardProjectsState
export declare function addImprovement(
  state: BoardProjectsState,
  input?: { text?: string; priority?: ImprovementPriority }
): BoardProjectsState
export declare function toggleImprovement(state: BoardProjectsState, id: string): BoardProjectsState
export declare function removeImprovement(state: BoardProjectsState, id: string): BoardProjectsState

/** POST /api/board-projects 的指令分派：非法操作为抛错（端点转 400） */
export declare function applyOperation(state: BoardProjectsState, op: BoardOperation): BoardProjectsState
