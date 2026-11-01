import type { BoardGit } from '../types'

interface Props {
  git: BoardGit
}

// git 的 `%ci` 是 `2026-11-01 15:18:38 +0800`：只保留日期 + 时分
function formatCommitDate(date: string): string {
  const m = /^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2})/.exec(date)
  if (m) return `${m[1]} ${m[2]}`
  const d = new Date(date)
  return Number.isNaN(d.getTime()) ? date : d.toLocaleString('zh-CN', { hour12: false })
}

export default function Commits({ git }: Props) {
  return (
    <section className="board-section">
      <div className="board-section-head">
        <h2 className="board-section-title">最近提交</h2>
        <span className="board-section-note">
          {git.available ? `HEAD ${git.head} · ${git.log.length} 条` : 'git 不可用'}
        </span>
      </div>

      {!git.available ? (
        <p className="board-empty">读不到 git：{git.error ?? '未知原因'}</p>
      ) : git.log.length === 0 ? (
        <p className="board-empty">暂无提交记录。</p>
      ) : (
        <ol className="board-commits">
          {git.log.map((commit) => (
            <li key={commit.hash} className="board-commit">
              <code className="board-commit-hash">{commit.hash}</code>
              <span className="board-commit-subject">{commit.subject}</span>
              <time className="board-commit-date">{formatCommitDate(commit.date)}</time>
            </li>
          ))}
        </ol>
      )}
    </section>
  )
}
