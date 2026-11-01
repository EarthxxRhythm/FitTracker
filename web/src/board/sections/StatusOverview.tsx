import type { BoardCommand, BoardDrift } from '../types'
import { findSection, plainText, rowsAsRecords, statusTone } from '../types'

interface Props {
  command: BoardCommand
  // 状态源 vs git 真值的漂移读数（数据层算好）：缺失时退化为「无读数」而不是假警报
  drift?: BoardDrift
}

function formatTime(iso: string | null): string {
  if (!iso) return '—'
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return iso
  return d.toLocaleString('zh-CN', { hour12: false })
}

// 各线状态：COMMAND.md「一、现在到哪了」的散文 + 状态表
export default function StatusOverview({ command, drift }: Props) {
  const section = findSection(command.sections, '现在到哪了')
  const table = section?.tables[0]
  const header = table?.header ?? []
  const records = rowsAsRecords(table)
  const prose = section ? section.text.split('\n').filter((l) => l.trim() !== '') : []
  const sectionNote = section ? section.title : '未找到「现在到哪了」章节'
  const readout = drift
    ? `状态源 ${formatTime(drift.commandUpdatedAt)} · HEAD 提交 ${formatTime(drift.headCommittedAt)} · 未提交 ${drift.actualUncommitted} 项${drift.claimedUncommitted === null ? '' : `（总账自述 ${drift.claimedUncommitted} 项）`}`
    : ''

  return (
    <section className="board-section board-section--wide">
      <div className="board-section-head">
        <h2 className="board-section-title">各线状态</h2>
        <span className="board-section-note">{[sectionNote, readout].filter((s) => s !== '').join(' · ')}</span>
      </div>

      {drift && drift.stale ? (
        <p className="board-alert board-alert--warn">
          ⚠ 状态总账可能过期：{drift.reasons.join('；')}
        </p>
      ) : null}

      {prose.length > 0 ? (
        <div className="board-prose">
          {prose.map((line, i) => (
            <p key={i} className={line.trim().startsWith('>') ? 'board-prose-note' : 'board-prose-line'}>
              {plainText(line)}
            </p>
          ))}
        </div>
      ) : null}

      {records.length > 0 ? (
        <div className="board-table-wrap">
          <table className="board-table">
            <thead>
              <tr>
                {header.map((h) => (
                  <th key={h}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {records.map((record, i) => (
                <tr key={i}>
                  {header.map((key) => (
                    <td key={key} data-col={key}>
                      {key === '状态' ? (
                        <span className={`board-badge board-badge--${statusTone(record[key])}`}>
                          {plainText(record[key])}
                        </span>
                      ) : (
                        plainText(record[key])
                      )}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <p className="board-empty">
          未解析出「各线状态」表格——COMMAND.md 格式可能已漂移，需按新格式调整解析器。
        </p>
      )}
    </section>
  )
}
