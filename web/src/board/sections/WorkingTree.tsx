import type { BoardGit } from '../types'

interface Props {
  git: BoardGit
}

const CODE_LABEL: Record<string, string> = {
  ' M': '改',
  'M ': '暂存改',
  MM: '改+暂存',
  'A ': '新增',
  '??': '未跟踪',
  'D ': '删除',
  ' D': '删除',
  'R ': '重命名'
}

// 工作区改动：签名材料（build-profile.json5）出现即为「禁提交」，刺眼地标出来
export default function WorkingTree({ git }: Props) {
  const changes = git.status
  const forbidden = changes.filter((c) => c.forbidden)

  return (
    <section className="board-section">
      <div className="board-section-head">
        <h2 className="board-section-title">工作区改动</h2>
        <span className="board-section-note">
          {git.available ? `${changes.length} 项 · 均为用户资产，不碰不回退` : 'git 不可用'}
        </span>
      </div>

      {forbidden.length > 0 ? (
        <p className="board-alert board-alert--danger">
          ⚠ 含签名材料（{forbidden.map((c) => c.path).join('、')}）——禁提交、禁回退；提交必须走文件白名单。
        </p>
      ) : null}

      {!git.available ? (
        <p className="board-empty">读不到 git：{git.error ?? '未知原因'}</p>
      ) : changes.length === 0 ? (
        <p className="board-empty">工作区干净。</p>
      ) : (
        <ul className="board-changes">
          {changes.map((change) => (
            <li
              key={`${change.code}-${change.path}`}
              className={change.forbidden ? 'board-change board-change--forbidden' : 'board-change'}
            >
              <span className="board-change-code" title={change.code.trim() || 'M'}>
                {CODE_LABEL[change.code] ?? change.code.trim()}
              </span>
              <span className="board-change-path">{change.path}</span>
              {change.origPath ? <span className="board-change-from">← {change.origPath}</span> : null}
              {change.forbidden ? <span className="board-badge board-badge--danger">禁提交</span> : null}
            </li>
          ))}
        </ul>
      )}
    </section>
  )
}
