/**
 * 训练执行屏。
 *
 * 与真机的交互差异（有意的）：真机只聚焦「当前组」，输入一张卡片、点完成推进；
 * web 这里给**每一组一行输入框**，可以随时回改任意一组。
 * 理由：键盘输入在浏览器里本就比在卡片间跳转更适合批量修正，而且 writeSet 已经是
 * 精确的组级写入——不为了模仿动效牺牲可用性。
 *
 * 推进与收缩的规则仍照抄真机：写在 workout.ts（recordSet / endExercise），这里只调用。
 */

import { useEffect, useMemo, useState } from 'react'

import { formatClock } from '../calc'
import type { ActiveWorkoutSetEntry, ActiveWorkoutState } from '../types'
import { findUnfinishedExerciseIndex, nextExercise, workoutProgress } from '../workout'

interface Props {
  state: ActiveWorkoutState
  startedAt: number
  onWriteSet: (plannedExerciseId: string, setIndex: number, weightText: string, repsText: string) => void
  onToggleWarmup: (plannedExerciseId: string, setIndex: number, isWarmup: boolean) => void
  onEndExercise: (plannedExerciseId: string) => void
  onAddSet: (plannedExerciseId: string) => void
  onFinish: () => void
  onExit: () => void
}

export default function ActiveScreen({
  state,
  startedAt,
  onWriteSet,
  onToggleWarmup,
  onEndExercise,
  onAddSet,
  onFinish,
  onExit
}: Props) {
  const [elapsed, setElapsed] = useState(() => Math.floor((Date.now() - startedAt) / 1000))
  const [selectedId, setSelectedId] = useState('')

  useEffect(() => {
    const id = window.setInterval(() => {
      setElapsed(Math.floor((Date.now() - startedAt) / 1000))
    }, 1000)
    return () => window.clearInterval(id)
  }, [startedAt])

  // 默认停在「首个未录满的动作」上；用户点胶囊可以切走补录
  const unfinishedIndex = findUnfinishedExerciseIndex(state.exercises)
  const current = useMemo(() => {
    if (selectedId) {
      const found = state.exercises.find((item) => item.plannedExerciseId === selectedId)
      if (found) return found
    }
    if (unfinishedIndex >= 0) return state.exercises[unfinishedIndex]
    return state.exercises[state.exercises.length - 1]
  }, [selectedId, state.exercises, unfinishedIndex])

  const pending = nextExercise(state)
  const progress = workoutProgress(state)
  const allDone = pending === undefined

  if (!current) {
    return (
      <section className="ft-screen">
        <p className="ft-sub">这个训练日没有动作。</p>
        <button className="ft-btn ft-btn-ghost" onClick={onExit}>
          返回首页
        </button>
      </section>
    )
  }

  const canEndExercise = current.completedSets < current.targetSets

  return (
    <section className="ft-screen">
      <div className="ft-card-head">
        <button className="ft-back" onClick={onExit}>
          ⌄ 退出
        </button>
        <span className="ft-card-meta">
          总时长 <b style={{ color: 'var(--color-fg)' }}>{formatClock(elapsed)}</b>
        </span>
      </div>

      <div>
        <p className="ft-eyebrow">{state.title}</p>
        <h1 className="ft-h1">
          {state.completedSets} / {state.totalTargetSets} 组
        </h1>
        <p className="ft-sub">
          全场进度 {Math.round(progress * 100)}%
          {pending ? ` · 下一个 ${pending.name}` : ' · 全部动作已录满'}
        </p>
      </div>

      <div className="ft-set-bars" aria-label="全场组进度">
        {Array.from({ length: state.totalTargetSets }, (_, index) => {
          const cls = index < state.completedSets ? 'is-done' : index === state.completedSets ? 'is-on' : ''
          return <i key={index} className={cls} />
        })}
      </div>

      {/* 动作切换胶囊：切走后上一动作的已录分组不会丢 */}
      <div className="ft-chips" role="tablist" aria-label="动作切换">
        {state.exercises.map((exercise) => {
          const done = exercise.completedSets >= exercise.targetSets
          const classes = ['ft-chip']
          if (exercise.plannedExerciseId === current.plannedExerciseId) classes.push('is-on')
          else if (done) classes.push('is-done')
          return (
            <button
              key={exercise.plannedExerciseId}
              className={classes.join(' ')}
              onClick={() => setSelectedId(exercise.plannedExerciseId)}
              role="tab"
              aria-selected={exercise.plannedExerciseId === current.plannedExerciseId}
            >
              {exercise.name}
              <small>
                {exercise.completedSets}/{exercise.targetSets}
              </small>
            </button>
          )
        })}
      </div>

      <div className="ft-card">
        <div className="ft-card-head">
          <span className="ft-card-title">{current.name}</span>
          <span className="ft-card-meta">
            {current.targetSets} 组 × {current.targetReps}
          </span>
        </div>
        {current.intensityNote && <p className="ft-card-meta">{current.intensityNote}</p>}

        <div className="ft-rows">
          {current.sets.map((entry) => (
            <SetRow
              key={entry.setIndex}
              entry={entry}
              onWrite={(weight, reps) =>
                onWriteSet(current.plannedExerciseId, entry.setIndex, weight, reps)
              }
              onToggleWarmup={() =>
                onToggleWarmup(current.plannedExerciseId, entry.setIndex, !entry.isWarmup)
              }
            />
          ))}
        </div>

        <div style={{ display: 'flex', gap: 8 }}>
          <button className="ft-btn ft-btn-ghost ft-btn-sm" onClick={() => onAddSet(current.plannedExerciseId)}>
            + 加一组
          </button>
          <button
            className="ft-btn ft-btn-ghost ft-btn-sm"
            disabled={!canEndExercise}
            onClick={() => onEndExercise(current.plannedExerciseId)}
            title="把本动作收缩到已完成的组数，剩余组不再要求"
          >
            结束本动作
          </button>
        </div>
        {canEndExercise && (
          <p className="ft-hint">
            提前结束会把计划组数收缩到已录组数（{current.completedSets}/{current.targetSets}），
            剩余组不再计入完成率分母。
          </p>
        )}
      </div>

      <div className="ft-action-bar">
        <button className="ft-btn ft-btn-primary" onClick={onFinish} disabled={state.completedSets === 0}>
          {allDone ? '完成训练' : `完成训练（还有 ${state.totalTargetSets - state.completedSets} 组未录）`}
        </button>
      </div>
    </section>
  )
}

function SetRow({
  entry,
  onWrite,
  onToggleWarmup
}: {
  entry: ActiveWorkoutSetEntry
  onWrite: (weight: string, reps: string) => void
  onToggleWarmup: () => void
}) {
  return (
    <div className="ft-row" style={{ alignItems: 'flex-start', gap: 8 }}>
      <button
        className={`ft-fav${entry.isWarmup ? ' is-on' : ''}`}
        onClick={onToggleWarmup}
        title={entry.isWarmup ? '这是一个热身组（点击取消）' : '标记为热身组（不计入 PR 与训练量）'}
        aria-label={entry.isWarmup ? '取消热身标记' : '标记为热身组'}
        style={{ marginTop: 8 }}
      >
        {entry.isWarmup ? '◉' : '○'}
      </button>
      <span className="ft-row-idx" style={{ marginTop: 12 }}>
        {entry.setIndex + 1}
      </span>
      <div className="ft-input-row" style={{ flex: 1 }}>
        <div className="ft-field">
          <label htmlFor={`w-${entry.setIndex}`}>重量 kg</label>
          <input
            id={`w-${entry.setIndex}`}
            className="ft-input"
            inputMode="decimal"
            placeholder="0"
            value={entry.weightText}
            onChange={(event) => onWrite(event.target.value, entry.repsText)}
          />
        </div>
        <div className="ft-field">
          <label htmlFor={`r-${entry.setIndex}`}>次数</label>
          <input
            id={`r-${entry.setIndex}`}
            className="ft-input"
            inputMode="numeric"
            placeholder="0"
            value={entry.repsText}
            onChange={(event) => onWrite(entry.weightText, event.target.value)}
          />
        </div>
      </div>
      <span
        className="ft-row-v"
        style={{ marginTop: 24, minWidth: 46, textAlign: 'right', fontSize: 11.5 }}
      >
        {entry.isComplete
          ? entry.isWarmup
            ? '热身'
            : `${entry.estimatedOneRepMax}`
          : '—'}
      </span>
    </div>
  )
}
