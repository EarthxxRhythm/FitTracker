/**
 * 训练预览：开始前看清今天要做什么。
 *
 * 对应真机的 WorkoutPreviewService 产物：动作清单 + 每个动作的组数×次数 + 强度注释。
 * 这里不显示 exerciseId 映射状态——真机在动作详情里才提示「暂未映射到动作库」，
 * 预览页只呈现处方。
 */

import { resolveDayDistance, weekdayIndex } from '../calc'
import type { PresetPlan } from '../types'

interface Props {
  plan: PresetPlan
  dayIndex: number
  onBack: () => void
  onStart: () => void
}

export default function PreviewScreen({ plan, dayIndex, onBack, onStart }: Props) {
  const day = plan.days[dayIndex]

  if (!day) {
    return (
      <section className="ft-screen">
        <p className="ft-sub">找不到这个训练日。</p>
        <button className="ft-btn ft-btn-ghost" onClick={onBack}>
          返回
        </button>
      </section>
    )
  }

  const totalSets = day.exercises.reduce((sum, exercise) => sum + exercise.sets, 0)
  const distance = resolveDayDistance(day, weekdayIndex(Date.now()))

  return (
    <section className="ft-screen">
      <div className="ft-card-head">
        <button className="ft-back" onClick={onBack}>
          ← 返回
        </button>
        <span className="ft-card-meta">{plan.name}</span>
      </div>

      <div>
        <p className="ft-eyebrow">训练预览</p>
        <h1 className="ft-h1">{day.dayLabel}</h1>
        <p className="ft-sub">
          {day.exercises.length} 个动作 · {totalSets} 组
          {distance === 0 ? ' · 今天' : distance > 0 ? ` · ${distance} 天后` : ''}
        </p>
      </div>

      <div className="ft-card">
        <div className="ft-rows">
          {day.exercises.map((exercise, index) => (
            <div className="ft-row" key={`${exercise.name}-${index}`}>
              <span className="ft-row-idx">{String(index + 1).padStart(2, '0')}</span>
              <span className="ft-row-main">
                <span className="ft-row-t">{exercise.name}</span>
                <span className="ft-row-s">{exercise.targetMuscle}</span>
              </span>
              <span className="ft-row-v">
                {exercise.sets} × {exercise.reps}
              </span>
            </div>
          ))}
        </div>
      </div>

      <div className="ft-card">
        <p className="ft-sub" style={{ margin: 0 }}>
          训练中每组的次数与重量逐组记录，热身组可以单独标记（不计入 PR 与训练量）。
          中途退出会保存草稿，下次回来接着练。
        </p>
      </div>

      <button className="ft-btn ft-btn-primary" onClick={onStart}>
        开始训练
      </button>
    </section>
  )
}
