import { useCallback, useEffect, useState } from 'react'
import type { FormEvent } from 'react'

// 待优化清单：契约真源 web/tools/board-projects.mjs（open/done 由数据层归一）
type ImprovementPriority = 'high' | 'mid' | 'low'
type ImprovementStatus = 'open' | 'done'

interface BoardImprovement {
  id: string
  text: string
  priority: ImprovementPriority
  status: ImprovementStatus
}

interface ImprovementsState {
  improvements?: BoardImprovement[]
  error?: string
}

type BoardOperation =
  | { type: 'add-improvement'; text: string; priority?: ImprovementPriority }
  | { type: 'toggle-improvement'; id: string }
  | { type: 'remove-improvement'; id: string }

const IMPROVEMENTS_URL = '/api/board-projects'

const PRIORITY_LABEL: Record<ImprovementPriority, string> = { high: '高', mid: '中', low: '低' }
const PRIORITY_TONE: Record<ImprovementPriority, string> = { high: 'danger', mid: 'warn', low: 'idle' }

async function requestImprovements(init?: RequestInit): Promise<BoardImprovement[]> {
  const res = await fetch(IMPROVEMENTS_URL, { cache: 'no-store', ...init })
  const raw = await res.text()
  let payload: ImprovementsState = {}
  try {
    payload = JSON.parse(raw) as ImprovementsState
  } catch {
    // 端点缺失时 vite 兜底回 HTML —— 不当作数据，按 HTTP 状态报错
  }
  if (!res.ok) throw new Error(payload.error ?? `HTTP ${res.status}`)
  return payload.improvements ?? []
}

function writeInit(op: BoardOperation): RequestInit {
  return {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-Board-Write': '1' },
    body: JSON.stringify(op)
  }
}

export default function Improvements() {
  const [items, setItems] = useState<BoardImprovement[]>([])
  const [error, setError] = useState<string | null>(null)
  const [busyId, setBusyId] = useState<string | null>(null)
  const [text, setText] = useState('')
  const [priority, setPriority] = useState<ImprovementPriority>('mid')

  const load = useCallback(async () => {
    try {
      setItems(await requestImprovements())
      setError(null)
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err))
    }
  }, [])

  useEffect(() => {
    if (!import.meta.env.DEV) return
    void load()
  }, [load])

  const submit = useCallback(
    async (event: FormEvent<HTMLFormElement>) => {
      event.preventDefault()
      const value = text.trim()
      if (value.length === 0) return
      try {
        setItems(await requestImprovements(writeInit({ type: 'add-improvement', text: value, priority })))
        setText('')
        setError(null)
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err))
      }
    },
    [text, priority]
  )

  const toggle = useCallback(async (item: BoardImprovement) => {
    setBusyId(item.id)
    try {
      setItems(await requestImprovements(writeInit({ type: 'toggle-improvement', id: item.id })))
      setError(null)
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err))
    } finally {
      setBusyId(null)
    }
  }, [])

  const remove = useCallback(async (item: BoardImprovement) => {
    setBusyId(item.id)
    try {
      setItems(await requestImprovements(writeInit({ type: 'remove-improvement', id: item.id })))
      setError(null)
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err))
    } finally {
      setBusyId(null)
    }
  }, [])

  const editable = import.meta.env.DEV
  const openCount = items.filter((i) => i.status === 'open').length
  const doneCount = items.length - openCount

  return (
    <section className="board-section">
      <div className="board-section-head">
        <h2 className="board-section-title">待优化</h2>
        <span className="board-section-note">
          {editable ? `${openCount} 待处理 · ${doneCount} 已处理` : '静态快照只读'}
        </span>
      </div>

      {!editable ? (
        <p className="board-empty">静态产物没有写端点：待优化清单只在 dev 看板可编辑。</p>
      ) : (
        <>
          <form className="board-projects-form" onSubmit={(event) => void submit(event)}>
            <input
              className="board-input"
              value={text}
              onChange={(event) => setText(event.target.value)}
              placeholder="记一条待优化…"
              aria-label="待优化内容"
              maxLength={200}
            />
            <select
              className="board-input"
              value={priority}
              onChange={(event) => setPriority(event.target.value as ImprovementPriority)}
              aria-label="优先级"
            >
              <option value="high">高优先级</option>
              <option value="mid">中优先级</option>
              <option value="low">低优先级</option>
            </select>
            <button type="submit" className="board-btn board-btn--primary" disabled={text.trim().length === 0}>
              添加
            </button>
          </form>

          {error ? <p className="board-alert board-alert--error">待优化管道不可用：{error}</p> : null}

          {items.length === 0 && !error ? <p className="board-empty">还没有待优化项。</p> : null}

          <ul className="board-item-list">
            {items.map((item) => (
              <li key={item.id} className={`board-item${item.status === 'done' ? ' board-item--done' : ''}`}>
                <span className={`board-badge board-badge--${PRIORITY_TONE[item.priority]}`}>
                  {PRIORITY_LABEL[item.priority]}
                </span>
                <span className="board-item-text">{item.text}</span>
                <button
                  type="button"
                  className="board-btn"
                  disabled={busyId === item.id}
                  onClick={() => void toggle(item)}
                >
                  {busyId === item.id ? '…' : item.status === 'done' ? '重开' : '完成'}
                </button>
                <button
                  type="button"
                  className="board-btn board-btn--ghost"
                  disabled={busyId === item.id}
                  onClick={() => void remove(item)}
                >
                  删除
                </button>
              </li>
            ))}
          </ul>
        </>
      )}
    </section>
  )
}
