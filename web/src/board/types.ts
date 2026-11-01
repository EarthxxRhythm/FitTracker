// 看板前端类型 —— 镜像 web/tools/board-data.d.mts（数据管道输出）。
// 浏览器侧独立声明：.d.mts 只服务 node/vite 配置的 TS 解析，不能被打进 bundle。
export type PlanStatus = 'APPROVED' | 'DRAFT' | 'EXECUTED' | 'REJECTED' | 'UNKNOWN'

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

// 状态源漂移读数（数据层 computeDrift() 算好，前端只呈现）
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

// COMMAND.md 按标题语义找节：格式会漂，所以按关键词匹配而不是精确标题
export function findSection(sections: BoardSection[], keyword: string): BoardSection | undefined {
  return sections.find((s) => s.title.includes(keyword))
}

// 第一张表的行 → 对象数组（列名取自表头），便于按列渲染
export function rowsAsRecords(table: BoardTable | undefined): Record<string, string>[] {
  if (!table || table.header.length === 0) return []
  return table.rows.map((row) => {
    const record: Record<string, string> = {}
    table.header.forEach((key, i) => {
      record[key] = row[i] ?? ''
    })
    return record
  })
}

// 极简 Markdown 去噪：去掉引用前缀与加粗标记（看板只做「一眼看到」，不做渲染器）
export function plainText(line: string): string {
  return line
    .replace(/^>\s?/, '')
    .replace(/\*\*/g, '')
    .replace(/`([^`]*)`/g, '$1')
    .trim()
}

export type Tone = 'ok' | 'warn' | 'danger' | 'info' | 'idle'

// 状态单元格 → 色调。文案是半结构化的 `✅ 已提交` / `**阻塞**` / `⚠ 待重跑`，
// 只做关键词归类：格式漂移时退回 idle（不猜）。
export function statusTone(text: string): Tone {
  if (/阻塞|风险|禁提交|泄漏|失败/i.test(text)) return 'danger'
  if (/⚠|待|评审中|在途|进行中/i.test(text)) return 'warn'
  if (/✅|已提交|已完成|已闭环|已收敛|已接页面/i.test(text)) return 'ok'
  if (/计划|新线|收口/i.test(text)) return 'info'
  return 'idle'
}
