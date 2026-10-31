/**
 * 完成摘要：一次训练的政治账。
 *
 * 口径全部来自 calc.ts / workout.ts：
 *  - 目标组数从 session.notes 的 `target_sets=` 解析（真机 WorkoutSummaryService 同款）
 *  - 完成率 = round(completed × 100 / planned)
 *  - 每动作最佳 1RM 取整（真机 PersonalRecordService 用 Math.round）
 */

import { calculateBestEstimatedOneRepMax, calculateCompletionRate, formatDuration, formatVolume } from '../calc'
import type { ContentIndex } from '../calc'
import { findPresetPlan } from '../plans'
import type { WorkoutSession } from '../types'

interface Props {
  session: WorkoutSession
  content: ContentIndex
  onDone: () => void
}

function readNoteNumber(notes: string, prefix: string): number {
  const start = notes.indexOf(prefix)
  if (start < 0) return 0
  const valueStart = start + prefix.length
  let valueEnd = notes.indexOf(';', valueStart)
  if (valueEnd < 0) valueEnd = notes.length
  const parsed = Number(notes.slice(valueStart, valueEnd))
  return Number.isNaN(parsed) ? 0 : Math.floor(parsed)
}

export default function SummaryScreen({ session, content, onDone }: Props) {
  const completed = session.sets.filter((set) => set.weight > 0 && set.reps > 0 && !set.isWarmup).length
  const planned = readNoteNumber(session.notes, 'target_sets=') || completed
  const rate = calculateCompletionRate(completed, planned)

  // 按动作聚合：每个动作取本次最好的单组 1RM
  const byExercise = new Map<string, WorkoutSession['sets']>()
  for (const set of session.sets) {
    if (set.isWarmup) continue
    const list = byExercise.get(set.exerciseId) ?? []
    list.push(set)
    byExercise.set(set.exerciseId, list)
  }

  return (
    <section className="ft-screen">
      <div>
        <p className="ft-eyebrow">训练完成</p>
        <h1 className="ft-h1">
          {rate >= 100 ? '全部练满。' : rate >= 70 ? '节奏不错。' : '完成了一部分。'}
        </h1>
        <p className="ft-sub">
          {session.dayId || '训练'} · {formatDuration(session.durationSeconds)}
        </p>
      </div>

      <div className="ft-card">
        <div className="ft-metrics">
          <div className="ft-metric">
            <b>{completed}</b>
            <span>完成组</span>
          </div>
          <div className="ft-metric">
            <b>{rate}%</b>
            <span>完成率</span>
          </div>
          <div className="ft-metric">
            <b>{formatVolume(session.totalVolume)}</b>
            <span>训练量 kg</span>
          </div>
        </div>
        <p className="ft-card-meta" style={{ margin: 0 }}>
          {completed} / {planned} 组 · 时长 {formatDuration(session.durationSeconds)}
        </p>
      </div>

      <div className="ft-card">
        <div className="ft-card-head">
          <span className="ft-card-title">各动作最佳单组</span>
          <span className="ft-card-meta">参考 1RM</span>
        </div>
        {byExercise.size === 0 ? (
          <div className="ft-empty">这次没有有效组（热身组不计入 PR 与训练量）。</div>
        ) : (
          <div className="ft-rows">
            {[...byExercise.entries()].map(([exerciseId, sets]) => {
              const name = resolveExerciseName(content, session.planId, session.dayId, exerciseId)
              const best = Math.round(calculateBestEstimatedOneRepMax(sets))
              const heaviest = sets.reduce((max, set) => (set.weight > max.weight ? set : max), sets[0])
              return (
                <div className="ft-row" key={exerciseId}>
                  <span className="ft-row-main">
                    <span className="ft-row-t">{name}</span>
                    <span className="ft-row-s">
                      最重 {heaviest.weight} kg × {heaviest.reps} 次
                    </span>
                  </span>
                  <span className="ft-row-v">{best} kg</span>
                </div>
              )
            })}
          </div>
        )}
      </div>

      <div className="ft-card">
        <p className="ft-sub" style={{ margin: 0 }}>
          这次记录已经存进这台设备。首页的「本周节奏」和回顾页的趋势会立刻反映它。
        </p>
      </div>

      <button className="ft-btn ft-btn-primary" onClick={onDone}>
        回到首页
      </button>
    </section>
  )
}


/**
 * 动作名解析。
 *
 * 预置计划里 26/43 个动作名对不上动作库（真机同样如此，见 calc.ts 的 resolvePresetExercise 注释），
 * 这些动作落库时用的是 `${planId}_exercise_N` 占位 id。直接把它显示给用户是明显劣质，
 * 所以用 session 的 planId + dayId 反查计划里的原始中文名——只影响显示，不改数据口径。
 */
export function resolveExerciseName(
  content: ContentIndex,
  planId: string,
  dayId: string,
  exerciseId: string
): string {
  const direct = content.byId.get(exerciseId)
  if (direct) return direct.nameZh
  const matched = /_exercise_([0-9]+)$/.exec(exerciseId)
  if (!matched) return exerciseId
  const index = Number(matched[1]) - 1
  const plan = findPresetPlan(planId)
  const day = plan?.days.find((item) => item.dayLabel === dayId)
  return day?.exercises[index]?.name ?? exerciseId
}