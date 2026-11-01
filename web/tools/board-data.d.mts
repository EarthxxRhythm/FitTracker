// board-data.mjs 的类型声明（vite.board.config.ts 以 TS 导入它，需要可解析的 .d.mts）。
// 与 web/src/board/types.ts 结构同源；改动数据形状时两处一起改（test 是行为契约）。
export interface BoardTable {
  header: string[]
  rows: string[][]
}

export interface BoardSection {
  title: string
  text: string
  tables: BoardTable[]
}

export interface BoardCommand {
  path: string
  sections: BoardSection[]
  raw: string
  updatedAt?: string
  error?: string
}

export type PlanStatus = 'APPROVED' | 'DRAFT' | 'EXECUTED' | 'REJECTED' | 'UNKNOWN'

export interface BoardPlan {
  file: string
  status: PlanStatus
  statusRaw: string
  bytes: number
  modifiedAt: string
  absPath: string
  /** 「## 需求提炼 → **目标**」提取出的目标条目（已去 `**` 加粗）；未命中为空数组 */
  goals: string[]
  /** goals 的整块文本（换行连接），便于一次展示；行级渲染用 goals */
  goalText: string
  /** 计划文件内 `- [x]` 的条数 */
  tasksDone: number
  /** 计划文件内 `- [x]` / `- [ ]` 的总条数 */
  tasksTotal: number
}

export interface GitCommit {
  hash: string
  subject: string
  date: string
}

export interface GitChange {
  code: string
  path: string
  forbidden: boolean
  origPath?: string
}

export interface BoardGit {
  available: boolean
  head: string
  headCommittedAt?: string
  log: GitCommit[]
  status: GitChange[]
  error?: string
}

export interface BoardDrift {
  stale: boolean
  reasons: string[]
  commandUpdatedAt: string | null
  headCommittedAt: string | null
  claimedUncommitted: number | null
  actualUncommitted: number
}

export interface BoardData {
  generatedAt: string
  command: BoardCommand
  plans: BoardPlan[]
  git: BoardGit
  drift?: BoardDrift
}

export interface CollectOptions {
  commandPath?: string
  plansDir?: string
  cwd?: string
}

export declare const REPO_ROOT: string
export declare const COMMAND_PATH: string
export declare const PLANS_DIR: string
export declare function parseCommand(md: string): BoardSection[]
export declare function normalizePlanStatus(raw: string | null | undefined): PlanStatus
export declare function parsePlans(dir?: string): BoardPlan[]
/** 「## 需求提炼」章节里 `**目标**` 标记行 → 目标条目（已去 `**`）；格式漂移/未命中返回 []，不抛 */
export declare function parsePlanGoals(body: string): string[]
/** 勾选框进度：`- [x]` 已完成 / `- [ ]` 未完成 */
export declare function countCheckboxes(body: string): { done: number; total: number }
export declare function parseGitLog(out: string): GitCommit[]
export declare function parseGitStatus(out: string): GitChange[]
export declare function parseGit(cwd?: string): BoardGit
export declare function claimUncommittedCount(raw: string): number | null
export declare function computeDrift(command: BoardCommand, git: BoardGit): BoardDrift
export declare function collectBoardData(options?: CollectOptions): BoardData
