import { useCallback, useEffect, useState } from 'react'
import type { FormEvent } from 'react'

// todo 清单：契约真源 web/tools/board-projects.mjs
interface BoardTodo {
  id: string
  text: string
  done: boolean
  projectId?: string
}

interface TodosState {
  todos?: BoardTodo[]
  error?: string
}

type BoardOperation =
  | { type: 'add-todo'; text: string; projectId?: string }
  | { type: 'toggle-todo'; id: string }
  | { type: 'remove-todo'; id: string }

const TODOS_URL = '/api/board-projects'

async function requestTodos(init?: RequestInit): Promise<BoardTodo[]> {
  const res = await fetch(TODOS_URL, { cache: 'no-store', ...init })
  const raw = await res.text()
  let payload: TodosState = {}
  try {
    payload = JSON.parse(raw) as TodosState
  } catch {
    // 端点缺失时 vite 兜底回 HTML —— 不当作数据，按 HTTP 状态报错
  }
  if (!res.ok) throw new Error(payload.error ?? `HTTP ${res.status}`)
  return payload.todos ?? []
}

function writeInit(op: BoardOperation): RequestInit {
  return {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-Board-Write': '1' },
    body: JSON.stringify(op)
  }
}

export default function TodoList() {
  const [items, setItems] = useState<BoardTodo[]>([])
  const [error, setError] = useState<string | null>(null)
  const [busyId, setBusyId] = useState<string | null>(null)
  const [text, setText] = useState('')

  const load = useCallback(async () => {
    try {
      setItems(await requestTodos())
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
        setItems(await requestTodos(writeInit({ type: 'add-todo', text: value })))
        setText('')
        setError(null)
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err))
      }
    },
    [text]
  )

  const toggle = useCallback(async (item: BoardTodo) => {
    setBusyId(item.id)
    try {
      setItems(await requestTodos(writeInit({ type: 'toggle-todo', id: item.id })))
      setError(null)
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err))
    } finally {
      setBusyId(null)
    }
  }, [])

  const remove = useCallback(async (item: BoardTodo) => {
    setBusyId(item.id)
    try {
      setItems(await requestTodos(writeInit({ type: 'remove-todo', id: item.id })))
      setError(null)
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err))
    } finally {
      setBusyId(null)
    }
  }, [])

  const editable = import.meta.env.DEV
  const openCount = items.filter((t) => !t.done).length
  const doneCount = items.length - openCount

  return (
    <section className="board-section">
      <div className="board-section-head">
        <h2 className="board-section-title">Todo</h2>
        <span className="board-section-note">
          {editable ? `${openCount} 待办 · ${doneCount} 已完成` : '静态快照只读'}
        </span>
      </div>

      {!editable ? (
        <p className="board-empty">静态产物没有写端点：todo 清单只在 dev 看板可编辑。</p>
      ) : (
        <>
          <form className="board-projects-form" onSubmit={(event) => void submit(event)}>
            <input
              className="board-input"
              value={text}
              onChange={(event) => setText(event.target.value)}
              placeholder="记一条待办…"
              aria-label="待办内容"
              maxLength={200}
            />
            <button type="submit" className="board-btn board-btn--primary" disabled={text.trim().length === 0}>
              添加
            </button>
          </form>

          {error ? <p className="board-alert board-alert--error">todo 管道不可用：{error}</p> : null}

          {items.length === 0 && !error ? <p className="board-empty">还没有待办。</p> : null}

          <ul className="board-item-list">
            {items.map((item) => (
              <li key={item.id} className={`board-item${item.done ? ' board-item--done' : ''}`}>
                <button
                  type="button"
                  className="board-check"
                  aria-label={item.done ? '标记未完成' : '标记完成'}
                  aria-pressed={item.done}
                  disabled={busyId === item.id}
                  onClick={() => void toggle(item)}
                >
                  {item.done ? '✓' : ''}
                </button>
                <span className="board-item-text">{item.text}</span>
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
