import { useCallback, useEffect, useState } from 'react'
import type { BoardData } from './types'
import StatusOverview from './sections/StatusOverview'
import Blockers from './sections/Blockers'
import Plans from './sections/Plans'
import Commits from './sections/Commits'
import WorkingTree from './sections/WorkingTree'

// dev：vite.board.config.ts 的插件中间件实时聚合（改了 COMMAND.md 刷新即见）
// build：同一份数据被落成静态快照，随产物一起分发（board-dist/board-data.json）
const DATA_URL = import.meta.env.DEV ? '/api/board-data' : './board-data.json'

function formatTime(iso: string): string {
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return iso
  return d.toLocaleString('zh-CN', { hour12: false })
}

export default function BoardApp() {
  const [data, setData] = useState<BoardData | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const res = await fetch(DATA_URL, { cache: 'no-store' })
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      setData((await res.json()) as BoardData)
      setError(null)
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err))
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void load()
  }, [load])

  return (
    <div className="board">
      <header className="board-header">
        <div className="board-header-main">
          <h1 className="board-title">FitTracker · 开发看板</h1>
          <p className="board-subtitle">
            只读聚合 <code>.rivet/COMMAND.md</code> · <code>.rivet/plans/*.md</code> · git
          </p>
        </div>
        <div className="board-header-meta">
          {data ? <span className="board-stamp">生成于 {formatTime(data.generatedAt)}</span> : null}
          {data && data.git.available ? <code className="board-head">{data.git.head}</code> : null}
          <button type="button" className="board-refresh" onClick={() => void load()} disabled={loading}>
            {loading ? '读取中…' : '刷新'}
          </button>
        </div>
      </header>

      {error ? (
        <p className="board-alert board-alert--error">
          数据管道未就绪：{error}
          {import.meta.env.DEV
            ? '（确认看板 dev server 已启动：npm run board）'
            : '（静态快照缺失：先跑 npm run board:build）'}
        </p>
      ) : null}

      {data && data.command.error ? (
        <p className="board-alert board-alert--warn">状态源降级：{data.command.error}</p>
      ) : null}

      {data ? (
        <main className="board-main">
          <StatusOverview command={data.command} drift={data.drift} />
          <Blockers command={data.command} />
          <Plans plans={data.plans} />
          <Commits git={data.git} />
          <WorkingTree git={data.git} />
        </main>
      ) : error ? null : (
        <p className="board-loading">读取 .rivet 状态…</p>
      )}
    </div>
  )
}
