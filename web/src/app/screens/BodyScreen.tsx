/**
 * 身体数据：体重记录 + 趋势折线。
 *
 * 训练量涨了体重没动，和两者一起涨，是两件不同的事——所以身体数据单独成线，
 * 不和训练量混在一张图里。
 */

import { useState } from 'react'

import { formatDate, formatMonthDay } from '../calc'
import type { WebSnapshot } from '../types'

interface Props {
  snapshot: WebSnapshot
  onAdd: (weight: number, bodyFat?: number) => void
  onRemove: (id: string) => void
  onBack: () => void
}

export default function BodyScreen({ snapshot, onAdd, onRemove, onBack }: Props) {
  const [weight, setWeight] = useState('')
  const [bodyFat, setBodyFat] = useState('')
  const [confirmId, setConfirmId] = useState('')

  const records = snapshot.bodyRecords
  const latest = records[records.length - 1]
  const first = records[0]
  const delta = latest && first && records.length > 1 ? latest.weight - first.weight : 0

  const submit = () => {
    const value = Number(weight)
    if (Number.isNaN(value) || value <= 0 || value > 500) return
    const fat = Number(bodyFat)
    onAdd(value, Number.isNaN(fat) || fat <= 0 ? undefined : fat)
    setWeight('')
    setBodyFat('')
  }

  return (
    <section className="ft-screen">
      <div className="ft-card-head">
        <button className="ft-back" onClick={onBack}>
          ← 我的
        </button>
        <span className="ft-card-meta">{records.length} 条记录</span>
      </div>

      <div>
        <p className="ft-eyebrow">身体数据</p>
        <h1 className="ft-h1">
          {latest ? `${latest.weight} kg` : '还没有记录'}
          {records.length > 1 && (
            <span className="ft-pill" style={{ marginLeft: 10, verticalAlign: 'middle' }}>
              {delta >= 0 ? '+' : ''}
              {delta.toFixed(1)} kg
            </span>
          )}
        </h1>
        <p className="ft-sub">
          {latest ? `最近记录于 ${formatDate(latest.at)}` : '记录一次体重，就能开始看趋势'}
        </p>
      </div>

      <div className="ft-card">
        <div className="ft-card-head">
          <span className="ft-card-title">记一条</span>
          <span className="ft-card-meta">单位 kg</span>
        </div>
        <div className="ft-input-row">
          <div className="ft-field">
            <label htmlFor="body-weight">体重</label>
            <input
              id="body-weight"
              className="ft-input"
              inputMode="decimal"
              placeholder="72.5"
              value={weight}
              onChange={(event) => setWeight(event.target.value)}
            />
          </div>
          <div className="ft-field">
            <label htmlFor="body-fat">体脂 %（可选）</label>
            <input
              id="body-fat"
              className="ft-input"
              inputMode="decimal"
              placeholder="18"
              value={bodyFat}
              onChange={(event) => setBodyFat(event.target.value)}
            />
          </div>
        </div>
        <button className="ft-btn ft-btn-primary" onClick={submit} disabled={weight.trim().length === 0}>
          保存
        </button>
      </div>

      {records.length >= 2 && <WeightChart records={records} />}

      <div className="ft-card">
        <div className="ft-card-head">
          <span className="ft-card-title">记录</span>
          <span className="ft-card-meta">点删除可移除</span>
        </div>
        {records.length === 0 ? (
          <div className="ft-empty">还没有记录。</div>
        ) : (
          <div className="ft-rows">
            {[...records].reverse().map((record) => (
              <div className="ft-row" key={record.id}>
                <span className="ft-row-idx">·</span>
                <span className="ft-row-main">
                  <span className="ft-row-t">{record.weight} kg</span>
                  <span className="ft-row-s">
                    {formatMonthDay(record.at)}
                    {record.bodyFat ? ` · 体脂 ${record.bodyFat}%` : ''}
                  </span>
                </span>
                {confirmId === record.id ? (
                  <span style={{ display: 'flex', gap: 6 }}>
                    <button className="ft-btn ft-btn-danger ft-btn-sm" onClick={() => onRemove(record.id)}>
                      确认删
                    </button>
                    <button className="ft-btn ft-btn-ghost ft-btn-sm" onClick={() => setConfirmId('')}>
                      取消
                    </button>
                  </span>
                ) : (
                  <button className="ft-btn ft-btn-ghost ft-btn-sm" onClick={() => setConfirmId(record.id)}>
                    删除
                  </button>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </section>
  )
}

function WeightChart({ records }: { records: WebSnapshot['bodyRecords'] }) {
  const width = 320
  const height = 110
  const padding = 8
  const weights = records.map((record) => record.weight)
  const min = Math.min(...weights)
  const max = Math.max(...weights)
  const span = max - min || 1

  const points = records.map((record, index) => {
    const x = padding + (index / Math.max(1, records.length - 1)) * (width - padding * 2)
    const y = padding + (1 - (record.weight - min) / span) * (height - padding * 2)
    return { x, y }
  })

  const line = points.map((point, index) => `${index === 0 ? 'M' : 'L'}${point.x.toFixed(1)},${point.y.toFixed(1)}`).join(' ')
  const area = `${line} L${points[points.length - 1].x.toFixed(1)},${height} L${points[0].x.toFixed(1)},${height} Z`

  return (
    <div className="ft-card">
      <div className="ft-card-head">
        <span className="ft-card-title">体重趋势</span>
        <span className="ft-card-meta">
          {min} – {max} kg
        </span>
      </div>
      <svg className="ft-spark" viewBox={`0 0 ${width} ${height}`} preserveAspectRatio="none" role="img" aria-label="体重趋势折线">
        <path className="area" d={area} />
        <path className="line" d={line} />
        {points.map((point, index) => (
          <circle key={index} cx={point.x} cy={point.y} r={2.6} />
        ))}
      </svg>
      <p className="ft-card-meta" style={{ margin: 0 }}>
        {formatDate(records[0].at)} → {formatDate(records[records.length - 1].at)}
      </p>
    </div>
  )
}
