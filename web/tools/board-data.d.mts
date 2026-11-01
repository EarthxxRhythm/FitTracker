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
export declare function parseGitLog(out: string): GitCommit[]
export declare function parseGitStatus(out: string): GitChange[]
export declare function parseGit(cwd?: string): BoardGit
export declare function claimUncommittedCount(raw: string): number | null
export declare function computeDrift(command: BoardCommand, git: BoardGit): BoardDrift
export declare function collectBoardData(options?: CollectOptions): BoardData
