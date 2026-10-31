/**
 * 动作库：102 个内置动作的列表 / 筛选 / 收藏 / 详情。
 *
 * 数据来自 content.generated.ts（由 JSONL 派生）。动作的 coverUrl 在内容源里全部为空
 * （已核实 exercises.zh-CN.jsonl 前三条），所以这里不拉任何图片，用线性图标占位——
 * 假装有图会让页面出现 404 空框。
 */

import { useMemo, useState } from 'react'

import { EXERCISES, EQUIPMENT, MUSCLES } from '../data/content.generated'
import type { ContentIndex } from '../calc'
import type { WebSnapshot } from '../types'

interface Props {
  snapshot: WebSnapshot
  content: ContentIndex
  detailExerciseId: string
  onOpenDetail: (exerciseId: string) => void
  onCloseDetail: () => void
  onToggleFavorite: (exerciseId: string) => void
  onBack: () => void
}

const DIFFICULTY_LABELS: Record<string, string> = {
  beginner: '入门',
  intermediate: '进阶',
  advanced: '高阶'
}

export default function LibraryScreen({
  snapshot,
  content,
  detailExerciseId,
  onOpenDetail,
  onCloseDetail,
  onToggleFavorite,
  onBack
}: Props) {
  const [query, setQuery] = useState('')
  const [muscle, setMuscle] = useState('')
  const [equipment, setEquipment] = useState('')

  const filtered = useMemo(() => {
    const keyword = query.trim().toLowerCase()
    return EXERCISES.filter((exercise) => {
      if (muscle && !exercise.primaryMuscleIds.includes(muscle)) return false
      if (equipment && !exercise.equipmentIds.includes(equipment)) return false
      if (!keyword) return true
      return (
        exercise.nameZh.toLowerCase().includes(keyword) ||
        exercise.nameEn.toLowerCase().includes(keyword) ||
        exercise.aliases.some((alias) => alias.toLowerCase().includes(keyword))
      )
    })
  }, [query, muscle, equipment])

  const detail = detailExerciseId ? content.byId.get(detailExerciseId) : undefined

  if (detail) {
    const favorite = snapshot.favorites.includes(detail.exerciseId)
    return (
      <section className="ft-screen">
        <div className="ft-card-head">
          <button className="ft-back" onClick={onCloseDetail}>
            ← 动作库
          </button>
          <button
            className={`ft-fav${favorite ? ' is-on' : ''}`}
            onClick={() => onToggleFavorite(detail.exerciseId)}
            aria-label={favorite ? '取消收藏' : '收藏'}
          >
            {favorite ? '★' : '☆'}
          </button>
        </div>

        <div>
          <p className="ft-eyebrow">
            {detail.primaryMuscleIds
              .map((id) => MUSCLES.find((item) => item.muscleId === id)?.nameZh ?? id)
              .join(' · ')}
          </p>
          <h1 className="ft-h1">{detail.nameZh}</h1>
          <p className="ft-sub">
            {detail.nameEn} · {DIFFICULTY_LABELS[detail.difficulty] ?? detail.difficulty}
          </p>
        </div>

        <div className="ft-card">
          <div className="ft-card-head">
            <span className="ft-card-title">动作步骤</span>
          </div>
          <ol className="ft-detail-list">
            {detail.steps.map((step, index) => (
              <li key={index}>{step}</li>
            ))}
          </ol>
        </div>

        {detail.cues.length > 0 && (
          <div className="ft-card">
            <div className="ft-card-head">
              <span className="ft-card-title">要点</span>
            </div>
            <ul className="ft-detail-list">
              {detail.cues.map((cue, index) => (
                <li key={index}>{cue}</li>
              ))}
            </ul>
          </div>
        )}

        {detail.commonMistakes.length > 0 && (
          <div className="ft-card">
            <div className="ft-card-head">
              <span className="ft-card-title">常见错误</span>
            </div>
            <ul className="ft-detail-list warn">
              {detail.commonMistakes.map((item, index) => (
                <li key={index}>{item}</li>
              ))}
            </ul>
          </div>
        )}

        {detail.safetyNotes.length > 0 && (
          <div className="ft-card">
            <div className="ft-card-head">
              <span className="ft-card-title">安全提示</span>
            </div>
            <ul className="ft-detail-list">
              {detail.safetyNotes.map((item, index) => (
                <li key={index}>{item}</li>
              ))}
            </ul>
          </div>
        )}

        <div className="ft-card">
          <div className="ft-card-head">
            <span className="ft-card-title">器械</span>
            <span className="ft-card-meta">内容版本 {detail.contentVersion}</span>
          </div>
          <div className="ft-plan-meta">
            {detail.equipmentIds.map((id) => (
              <span className="ft-pill ft-pill-quiet" key={id}>
                {EQUIPMENT.find((item) => item.equipmentId === id)?.nameZh ?? id}
              </span>
            ))}
            {detail.primaryMuscleIds.map((id) => (
              <span className="ft-pill" key={id}>
                {MUSCLES.find((item) => item.muscleId === id)?.nameZh ?? id}
              </span>
            ))}
          </div>
        </div>
      </section>
    )
  }

  return (
    <section className="ft-screen">
      <div className="ft-card-head">
        <button className="ft-back" onClick={onBack}>
          ← 我的
        </button>
        <span className="ft-card-meta">{EXERCISES.length} 个动作</span>
      </div>

      <div>
        <p className="ft-eyebrow">动作库</p>
        <h1 className="ft-h1">先看怎么做，再决定练多重</h1>
      </div>

      <input
        className="ft-input"
        placeholder="搜索动作名 / 英文 / 别名"
        value={query}
        onChange={(event) => setQuery(event.target.value)}
        style={{ fontSize: 14, fontWeight: 600 }}
      />

      <div className="ft-chips" role="tablist" aria-label="按肌群筛选">
        <button className={`ft-chip${muscle === '' ? ' is-on' : ''}`} onClick={() => setMuscle('')}>
          全部肌群
        </button>
        {MUSCLES.map((item) => (
          <button
            key={item.muscleId}
            className={`ft-chip${muscle === item.muscleId ? ' is-on' : ''}`}
            onClick={() => setMuscle(muscle === item.muscleId ? '' : item.muscleId)}
          >
            {item.nameZh}
          </button>
        ))}
      </div>

      <div className="ft-chips" role="tablist" aria-label="按器械筛选">
        <button className={`ft-chip${equipment === '' ? ' is-on' : ''}`} onClick={() => setEquipment('')}>
          全部器械
        </button>
        {EQUIPMENT.map((item) => (
          <button
            key={item.equipmentId}
            className={`ft-chip${equipment === item.equipmentId ? ' is-on' : ''}`}
            onClick={() => setEquipment(equipment === item.equipmentId ? '' : item.equipmentId)}
          >
            {item.nameZh}
          </button>
        ))}
      </div>

      <div className="ft-card">
        <div className="ft-card-head">
          <span className="ft-card-title">筛选结果</span>
          <span className="ft-card-meta">{filtered.length} 个</span>
        </div>
        {filtered.length === 0 ? (
          <div className="ft-empty">没有符合条件的动作。清掉筛选再看看。</div>
        ) : (
          <div className="ft-rows">
            {filtered.map((exercise) => {
              const favorite = snapshot.favorites.includes(exercise.exerciseId)
              return (
                <div className="ft-lib-row" key={exercise.exerciseId} onClick={() => onOpenDetail(exercise.exerciseId)}>
                  <span className="ft-lib-ic">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round">
                      <path d="M6.5 6.5v11M17.5 6.5v11M3 9v6M21 9v6M6.5 12h11" />
                    </svg>
                  </span>
                  <span className="ft-row-main">
                    <span className="ft-row-t">{exercise.nameZh}</span>
                    <span className="ft-row-s">
                      {exercise.primaryMuscleIds
                        .map((id) => MUSCLES.find((item) => item.muscleId === id)?.nameZh ?? id)
                        .join(' · ')}
                      {' · '}
                      {DIFFICULTY_LABELS[exercise.difficulty] ?? exercise.difficulty}
                    </span>
                  </span>
                  <button
                    className={`ft-fav${favorite ? ' is-on' : ''}`}
                    onClick={(event) => {
                      event.stopPropagation()
                      onToggleFavorite(exercise.exerciseId)
                    }}
                    aria-label={favorite ? '取消收藏' : '收藏'}
                  >
                    {favorite ? '★' : '☆'}
                  </button>
                </div>
              )
            })}
          </div>
        )}
      </div>
    </section>
  )
}
