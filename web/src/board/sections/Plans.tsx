import type { BoardPlan, PlanStatus } from '../types'
import { plainText } from '../types'

interface Props {
  plans: BoardPlan[]
}

// 分组顺序即阅读顺序：可执行的在前，归档的在最后
const GROUPS: { status: PlanStatus; label: string; tone: string }[] = [
  { status: 'APPROVED', label: '已批准（可执行）', tone: 'ok' },
  { status: 'DRAFT', label: '待审批', tone: 'warn' },
  { status: 'EXECUTED', label: '已执行', tone: 'info' },
  { status: 'REJECTED', label: '已驳回', tone: 'danger' },
  { status: 'UNKNOWN', label: '未标状态', tone: 'idle' }
]

function formatDate(iso: string): string {
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleDateString('zh-CN')
}

// 打开源文件：dev 下 vite 的 /@fs/ 能取到工作区外（仓根）的 .rivet/plans；
// 静态快照没有文件服务，退回纯文本（不渲染死链）。
function sourceHref(plan: BoardPlan): string | undefined {
  return import.meta.env.DEV ? `/@fs/${plan.absPath}` : undefined
}

export default function Plans({ plans }: Props) {
  const total = plans.length

  return (
    <section className="board-section board-section--wide">
      <div className="board-section-head">
        <h2 className="board-section-title">计划列表</h2>
        <span className="board-section-note">{total} 份（按 Status 分组）</span>
      </div>

      {total === 0 ? <p className="board-empty">未读到 .rivet/plans 下的计划文件。</p> : null}

      {GROUPS.map((group) => {
        const items = plans.filter((p) => p.status === group.status)
        if (items.length === 0) return null
        return (
          <div key={group.status} className="board-plan-group">
            <h3 className="board-plan-group-title">
              <span className={`board-badge board-badge--${group.tone}`}>{group.label}</span>
              <span className="board-plan-group-count">{items.length}</span>
            </h3>
            <ul className="board-plan-list">
              {items.map((plan) => {
                const href = sourceHref(plan)
                return (
                  <li key={plan.file} className="board-plan">
                    <span className="board-plan-name">{plan.file.replace(/\.md$/, '')}</span>
                    <span className="board-plan-meta">
                      {formatDate(plan.modifiedAt)} · {(plan.bytes / 1024).toFixed(1)} KB
                      {plan.statusRaw ? ` · ${plainText(plan.statusRaw)}` : ''}
                    </span>
                    {href ? (
                      <a className="board-link" href={href} target="_blank" rel="noreferrer">
                        打开源文件
                      </a>
                    ) : (
                      <span className="board-link board-link--off" title="静态快照无文件服务；开发模式可点开">
                        打开源文件
                      </span>
                    )}
                  </li>
                )
              })}
            </ul>
          </div>
        )
      })}
    </section>
  )
}
