import type { BoardCommand } from '../types'
import { findSection, plainText } from '../types'

interface Props {
  command: BoardCommand
}

// 阻塞与风险：COMMAND.md「三、阻塞与风险」的表 + 平台级约束散文
export default function Blockers({ command }: Props) {
  const section = findSection(command.sections, '阻塞')
  const table = section?.tables[0]
  const header = table?.header ?? []
  const prose = section ? section.text.split('\n').filter((l) => l.trim() !== '') : []

  return (
    <section className="board-section">
      <div className="board-section-head">
        <h2 className="board-section-title">阻塞与风险</h2>
        <span className="board-section-note">{section ? section.title : '未找到「阻塞与风险」章节'}</span>
      </div>

      {header.length > 0 && table ? (
        <div className="board-table-wrap">
          <table className="board-table board-table--compact">
            <thead>
              <tr>
                {header.map((h) => (
                  <th key={h}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {table.rows.map((row, i) => (
                <tr key={i}>
                  {header.map((key, col) => (
                    <td key={key} data-col={key}>
                      <span className={col === 0 ? 'board-blocker-item' : undefined}>
                        {plainText(row[col] ?? '')}
                      </span>
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <p className="board-empty">未解析出阻塞表格。</p>
      )}

      {prose.length > 0 ? (
        <div className="board-prose board-prose--tight">
          {prose.map((line, i) => (
            <p key={i} className="board-prose-note">
              {plainText(line)}
            </p>
          ))}
        </div>
      ) : null}
    </section>
  )
}
