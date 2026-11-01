import { useCallback, useEffect, useState } from 'react'
import type { FormEvent } from 'react'

// 项目状态机：单向推进，不后退（待办 → 进行中 → 完成 → 归档）
// 契约真源：web/tools/board-projects.mjs（状态与进度语义由数据层决定，前端只呈现）
type ProjectStatus = 'backlog' | 'active' | 'done' | 'archived'

interface BoardProject {
  id: string
  name: string
  status: ProjectStatus
  // 0–100；done / archived 恒为 100（数据层 normalizeState 保证）
  progress: number
  note: string
  createdAt: string
  updatedAt: string
}

// 端点返回整份状态（projects / improvements / todos），本区块只消费 projects
interface ProjectsState {
  projects?: BoardProject[]
  error?: string
}

// POST body 即操作指令，见 board-projects.mjs 的 BoardOperation
type BoardOperation = { type: 'add-project'; name: string; note?: string } | { type: 'advance-project'; id: string }

// dev server 中间件提供（读 GET / 写 POST）；静态产物没有它 —— 见下方 DEV 分支
const PROJECTS_URL = '/api/board-projects'

const FLOW: ProjectStatus[] = ['backlog', 'active', 'done', 'archived']

// 分组顺序即阅读顺序：手上的在前，归档的压底
const GROUPS: { status: ProjectStatus; label: string; tone: string }[] = [
  { status: 'backlog', label: '待办', tone: 'idle' },
  { status: 'active', label: '进行中', tone: 'info' },
  { status: 'done', label: '完成', tone: 'ok' },
  { status: 'archived', label: '已归档', tone: 'idle' }
]

// 推进按钮的动作名（当前状态 → 下一状态；下一状态由数据层算，前端不传）
const ADVANCE_LABEL: Record<ProjectStatus, string> = {
  backlog: '开始',
  active: '完成',
  done: '归档',
  archived: '已归档'
}

// 与数据层同口径兜底：终态 100，其余 0（只有 progress 缺失的脏数据才走这里）
const STATUS_PROGRESS: Record<ProjectStatus, number> = {
  backlog: 0,
  active: 0,
  done: 100,
  archived: 100
}

function nextStatus(status: ProjectStatus): ProjectStatus | null {
  const i = FLOW.indexOf(status)
  return i >= 0 && i < FLOW.length - 1 ? FLOW[i + 1] : null
}

function progressOf(project: BoardProject): number {
  if (typeof project.progress === 'number' && Number.isFinite(project.progress)) {
    return Math.min(100, Math.max(0, Math.round(project.progress)))
  }
  return STATUS_PROGRESS[project.status] ?? 0
}

function formatTime(iso: string): string {
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return iso
  return d.toLocaleString('zh-CN', { hour12: false })
}

async function requestProjects(init?: RequestInit): Promise<BoardProject[]> {
  const res = await fetch(PROJECTS_URL, { cache: 'no-store', ...init })
  const raw = await res.text()
  let payload: ProjectsState = {}
  try {
    payload = JSON.parse(raw) as ProjectsState
  } catch {
    // 端点缺失时 vite 会兜底回 HTML —— 不当作数据，按 HTTP 状态报错
  }
  if (!res.ok) throw new Error(payload.error ?? `HTTP ${res.status}`)
  return payload.projects ?? []
}

// 写请求带自定义头：跨源页面即便发简单请求也会在预检被拒，写副作用不会发生
// （只靠 Content-Type: application/json 不足以拦住 text/plain 的简单请求）。
function writeInit(op: BoardOperation): RequestInit {
  return {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-Board-Write': '1' },
    body: JSON.stringify(op)
  }
}

export default function Projects() {
  const [projects, setProjects] = useState<BoardProject[]>([])
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const [busyId, setBusyId] = useState<string | null>(null)
  const [name, setName] = useState('')
  const [note, setNote] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    try {
      setProjects(await requestProjects())
      setError(null)
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err))
    } finally {
      setLoading(false)
    }
  }, [])

  // 静态快照没有端点，不必发那个注定失败的 GET
  useEffect(() => {
    if (!import.meta.env.DEV) return
    void load()
  }, [load])

  const submit = useCallback(
    async (event: FormEvent<HTMLFormElement>) => {
      event.preventDefault()
      const projectName = name.trim()
      if (projectName.length === 0) return
      setLoading(true)
      try {
        setProjects(await requestProjects(writeInit({ type: 'add-project', name: projectName, note: note.trim() })))
        setName('')
        setNote('')
        setError(null)
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err))
      } finally {
        setLoading(false)
      }
    },
    [name, note]
  )

  const advance = useCallback(async (project: BoardProject) => {
    setBusyId(project.id)
    try {
      setProjects(await requestProjects(writeInit({ type: 'advance-project', id: project.id })))
      setError(null)
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err))
    } finally {
      setBusyId(null)
    }
  }, [])

  const editable = import.meta.env.DEV

  return (
    <section className="board-section board-section--wide">
      <div className="board-section-head">
        <h2 className="board-section-title">项目管理</h2>
        <span className="board-section-note">
          {editable ? `${projects.length} 个项目 · 可立项与推进` : '静态快照只读 · 立项与推进需 dev 看板'}
        </span>
      </div>

      {!editable ? (
        <p className="board-empty">
          静态产物没有写端点：项目数据只在 <code>npm run board</code>（dev server）下读写。
        </p>
      ) : (
        <>
          <form className="board-projects-form" onSubmit={(event) => void submit(event)}>
            <input
              className="board-input"
              value={name}
              onChange={(event) => setName(event.target.value)}
              placeholder="项目名"
              aria-label="项目名"
              maxLength={80}
            />
            <input
              className="board-input"
              value={note}
              onChange={(event) => setNote(event.target.value)}
              placeholder="备注（可选）"
              aria-label="备注"
              maxLength={200}
            />
            <button type="submit" className="board-btn board-btn--primary" disabled={loading || name.trim().length === 0}>
              立项
            </button>
          </form>

          {error ? (
            <p className="board-alert board-alert--error">
              项目管道不可用：{error}（dev server 需提供 {PROJECTS_URL}）
            </p>
          ) : null}

          {projects.length === 0 && !error ? <p className="board-empty">还没有项目，用上面的表单立一个。</p> : null}

          {GROUPS.map((group) => {
            const items = projects.filter((project) => project.status === group.status)
            if (items.length === 0) return null
            return (
              <div key={group.status} className="board-project-group">
                <h3 className="board-project-group-title">
                  <span className={`board-badge board-badge--${group.tone}`}>{group.label}</span>
                  <span className="board-project-group-count">{items.length}</span>
                </h3>
                <ul className="board-project-list">
                  {items.map((project) => {
                    const pct = progressOf(project)
                    const next = nextStatus(project.status)
                    return (
                      <li key={project.id} className="board-project-card">
                        <div className="board-project-head">
                          <span className="board-project-name">{project.name}</span>
                        </div>
                        {project.note ? <p className="board-project-note">{project.note}</p> : null}
                        <div
                          className="board-project-progress"
                          role="progressbar"
                          aria-valuenow={pct}
                          aria-valuemin={0}
                          aria-valuemax={100}
                          aria-label={`${project.name} 进度`}
                        >
                          <span className="board-project-progress-bar" style={{ width: `${pct}%` }} />
                        </div>
                        <div className="board-project-meta">
                          <span className="board-project-pct">{pct}%</span>
                          {project.updatedAt ? <span>{formatTime(project.updatedAt)}</span> : null}
                          {next ? (
                            <button
                              type="button"
                              className="board-btn"
                              disabled={busyId === project.id}
                              onClick={() => void advance(project)}
                            >
                              {busyId === project.id ? '写入中…' : ADVANCE_LABEL[project.status]}
                            </button>
                          ) : (
                            <span className="board-project-end">已到终点</span>
                          )}
                        </div>
                      </li>
                    )
                  })}
                </ul>
              </div>
            )
          })}
        </>
      )}
    </section>
  )
}
