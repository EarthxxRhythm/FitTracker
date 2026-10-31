/**
 * 回顾屏：周/月趋势 + 肌肉分布 + 肌群排行。
 *
 * 计算全部来自 calc.ts，口径与产品源码一一对应：
 *  - 肌肉分布是**按组数**聚合到 18 个身体部位（不是重量×次数），近 8 次训练
 *  - 热力 0–4 级是**相对量**：与最大值同量级取 4，全 0 时全空
 *  - 排行按模式换排序键：balance 用组数、fatigue/strength 用等级
 *
 * 视觉差异（有意）：真机用人体 SVG 图着色；这里用 18 格部位色块矩阵。
 * 信息等价（哪些部位练得多/少一眼可见），但不假装自己是人体图。
 */

import { useMemo, useState } from 'react'

import {
  BODY_PART_KEYS,
  BODY_PART_LABELS,
  calculateCompletionRate,
  calculateVolume,
  createMuscleLevels,
  createMuscleRanking,
  createMuscleVolume,
  formatVolume,
  getPrimaryMuscleIds
} from '../calc'
import type { ContentIndex, MuscleRankingMode } from '../calc'
import type { WebSnapshot } from '../types'

interface Props {
  snapshot: WebSnapshot
  content: ContentIndex
  now: number
  weekRangeText: string
  onNavigate: (screen: 'body') => void
}

type Range = 'week' | 'month'

const DAY_MS = 86_400_000
const MODE_LABELS: Record<MuscleRankingMode, string> = {
  balance: '平衡',
  fatigue: '疲劳',
  strength: '力量'
}

const LEVEL_LABELS: Record<number, string> = {
  0: '未练',
  1: '低',
  2: '中低',
  3: '中',
  4: '高'
}

export default function ReviewScreen({ snapshot, content, now, weekRangeText, onNavigate }: Props) {
  const [range, setRange] = useState<Range>('week')
  const [mode, setMode] = useState<MuscleRankingMode>('balance')

  const buckets = useMemo(() => {
    const sessions = snapshot.sessions
    if (range === 'week') {
      // 本周 7 天，按天聚合训练量
      const today = new Date(now)
      const mondayOffset = today.getDay() === 0 ? 6 : today.getDay() - 1
      const weekStart = new Date(today.getFullYear(), today.getMonth(), today.getDate() - mondayOffset).getTime()
      const labels = ['一', '二', '三', '四', '五', '六', '日']
      return {
        labels,
        values: labels.map((_, index) => {
          const from = weekStart + index * DAY_MS
          const to = from + DAY_MS
          const inRange = sessions.filter((session) => session.startedAt >= from && session.startedAt < to)
          return inRange.reduce((sum, session) => sum + calculateVolume(session.sets), 0)
        }),
        scoped: sessions.filter((session) => session.startedAt >= weekStart && session.startedAt < weekStart + 7 * DAY_MS),
        caption: weekRangeText
      }
    }

    // 月视图：最近 4 周，每周一根柱
    const labels = ['4 周前', '3 周前', '2 周前', '本周']
    const thisWeekStart = new Date(
      new Date(now).getFullYear(),
      new Date(now).getMonth(),
      new Date(now).getDate() - ((new Date(now).getDay() + 6) % 7)
    ).getTime()
    const values = labels.map((_, index) => {
      const from = thisWeekStart - (3 - index) * 7 * DAY_MS
      const to = from + 7 * DAY_MS
      const inRange = sessions.filter((session) => session.startedAt >= from && session.startedAt < to)
      return inRange.reduce((sum, session) => sum + calculateVolume(session.sets), 0)
    })
    return {
      labels,
      values,
      scoped: sessions.filter((session) => session.startedAt >= thisWeekStart - 3 * 7 * DAY_MS),
      caption: '近 4 周'
    }
  }, [snapshot.sessions, range, now, weekRangeText])

  const sessionCount = buckets.scoped.length
  const totalMinutes = Math.round(buckets.scoped.reduce((sum, session) => sum + session.durationSeconds, 0) / 60)
  const totalVolume = buckets.scoped.reduce((sum, session) => sum + calculateVolume(session.sets), 0)
  const plannedSets = buckets.scoped.reduce((sum, session) => {
    const match = /target_sets=(\d+)/.exec(session.notes)
    return sum + (match ? Number(match[1]) : session.totalSets)
  }, 0)
  const completedSets = buckets.scoped.reduce((sum, session) => sum + session.totalSets, 0)
  const completionRate = calculateCompletionRate(completedSets, plannedSets)

  // 体重变化：区间首尾差
  const scopedBodyStart = buckets.scoped.length > 0 ? Math.min(...buckets.scoped.map((s) => s.startedAt)) : now
  const bodyInRange = snapshot.bodyRecords.filter((record) => record.at >= scopedBodyStart - DAY_MS)
  const weightDelta =
    bodyInRange.length >= 2 ? bodyInRange[bodyInRange.length - 1].weight - bodyInRange[0].weight : 0

  const resolvePrimary = useMemo(
    () => (exerciseId: string) => getPrimaryMuscleIds(content, exerciseId),
    [content]
  )
  const muscleVolume = useMemo(
    () => createMuscleVolume(snapshot.sessions, resolvePrimary, 8),
    [snapshot.sessions, resolvePrimary]
  )
  const muscleLevels = useMemo(() => createMuscleLevels(muscleVolume), [muscleVolume])
  const ranking = useMemo(
    () => createMuscleRanking(muscleLevels, muscleVolume, mode),
    [muscleLevels, muscleVolume, mode]
  )

  const maxBar = Math.max(...buckets.values, 1)
  const hasMuscleData = muscleVolume.some((value) => value > 0)
  const topRanking = ranking.slice(0, 8)

  return (
    <section className="ft-screen">
      <div>
        <p className="ft-eyebrow">训练回顾</p>
        <h1 className="ft-h1">数字会告诉你哪里没练到</h1>
      </div>

      <div className="ft-seg" role="tablist" aria-label="时间范围">
        <button className={range === 'week' ? 'is-on' : ''} onClick={() => setRange('week')} role="tab" aria-selected={range === 'week'}>
          周
        </button>
        <button className={range === 'month' ? 'is-on' : ''} onClick={() => setRange('month')} role="tab" aria-selected={range === 'month'}>
          月
        </button>
      </div>

      <div className="ft-card">
        <div className="ft-card-head">
          <span className="ft-card-title">
            {range === 'week' ? '本周' : '近 4 周'}{' '}
            <span className="ft-pill">{sessionCount === 0 ? '待开始' : completionRate >= 80 ? '节奏稳' : '可加密'}</span>
          </span>
          <span className="ft-card-meta">{buckets.caption}</span>
        </div>
        <div className="ft-metrics">
          <div className="ft-metric">
            <b>{sessionCount}</b>
            <span>训练 · 次</span>
          </div>
          <div className="ft-metric">
            <b>{totalMinutes}</b>
            <span>时长 · 分钟</span>
          </div>
          <div className="ft-metric">
            <b style={{ color: 'var(--color-fg-2)' }}>{weightDelta.toFixed(1)}</b>
            <span>体重变化 · kg</span>
          </div>
        </div>
        <p className="ft-card-meta" style={{ margin: 0 }}>
          训练量合计 {formatVolume(totalVolume)} kg · 完成 {completedSets}/{plannedSets} 组（{completionRate}%）
        </p>
      </div>

      <div className="ft-card">
        <div className="ft-card-head">
          <span className="ft-card-title">训练量分布</span>
          <span className="ft-card-meta">单位 kg</span>
        </div>
        <div className="ft-bars">
          {buckets.values.map((value, index) => (
            <div className={`ft-bar${value === maxBar && value > 0 ? ' is-hi' : ''}`} key={buckets.labels[index]}>
              <i style={{ height: `${Math.max(3, (value / maxBar) * 100)}%` }} title={`${formatVolume(value)} kg`} />
              <span>{buckets.labels[index]}</span>
            </div>
          ))}
        </div>
      </div>

      <div className="ft-card">
        <div className="ft-card-head">
          <span className="ft-card-title">肌肉分布</span>
          <span className="ft-card-meta">近 8 次训练 · 按组数</span>
        </div>

        {hasMuscleData ? (
          <>
            <div className="ft-muscle-grid">
              {BODY_PART_KEYS.map((key, index) => {
                const level = muscleLevels[index]
                return (
                  <div
                    key={key}
                    className={`ft-muscle-cell${level > 0 ? ` lv${level}` : ''}`}
                    title={`${BODY_PART_LABELS[key]}：${muscleVolume[index]} 组（${LEVEL_LABELS[level]}）`}
                  >
                    {BODY_PART_LABELS[key]}
                  </div>
                )
              })}
            </div>
            <div className="ft-legend">
              <span>少</span>
              <i style={{ background: 'rgba(255,255,255,.08)' }} />
              <i style={{ background: 'rgba(76,236,164,.16)' }} />
              <i style={{ background: 'rgba(76,236,164,.32)' }} />
              <i style={{ background: 'rgba(76,236,164,.56)' }} />
              <i style={{ background: 'var(--color-brand)' }} />
              <span>多 · 相对量，非绝对强度</span>
            </div>
          </>
        ) : (
          <div className="ft-empty">
            还没有可统计的训练组。完成一次训练后，这里会按动作的主肌群把组数落到身体部位上。
          </div>
        )}

        <div className="ft-seg" role="tablist" aria-label="排序模式">
          {(Object.keys(MODE_LABELS) as MuscleRankingMode[]).map((key) => (
            <button key={key} className={mode === key ? 'is-on' : ''} onClick={() => setMode(key)}>
              {MODE_LABELS[key]}
            </button>
          ))}
        </div>

        {hasMuscleData ? (
          <div className="ft-rank">
            {topRanking.map((partIndex) => {
              const key = BODY_PART_KEYS[partIndex]
              const value = mode === 'balance' ? muscleVolume[partIndex] : muscleLevels[partIndex]
              const max = mode === 'balance' ? Math.max(...muscleVolume, 1) : 4
              return (
                <div className="ft-rank-row" key={key}>
                  <span className="nm">{BODY_PART_LABELS[key]}</span>
                  <span className="bar">
                    <i style={{ width: `${(value / max) * 100}%` }} />
                  </span>
                  <span className="v">{mode === 'balance' ? `${value}组` : `${value}级`}</span>
                </div>
              )
            })}
          </div>
        ) : (
          <div className="ft-empty">暂无排行数据。</div>
        )}

        <p className="ft-hint" style={{ margin: 0 }}>
          「平衡」按真实组数排序，「疲劳」「力量」按热力等级排序——等级会把不同组数并成同一档。
        </p>
      </div>

      <div className="ft-card">
        <div className="ft-card-head">
          <span className="ft-card-title">身体数据</span>
          <button className="ft-back" onClick={() => onNavigate('body')}>
            去记录 →
          </button>
        </div>
        {snapshot.bodyRecords.length === 0 ? (
          <div className="ft-empty">还没有体重记录。力量涨了体重没动，和两者一起涨，是两件不同的事。</div>
        ) : (
          <p className="ft-sub" style={{ margin: 0 }}>
            最近一次 {snapshot.bodyRecords[snapshot.bodyRecords.length - 1].weight} kg · 共{' '}
            {snapshot.bodyRecords.length} 条记录
          </p>
        )}
      </div>
    </section>
  )
}
