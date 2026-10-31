/**
 * 我的：本周概览 + 最佳纪录 + 设置 + 清除数据。
 *
 * 这里不显示昵称/头像编辑——真机那套要走登录与账号服务，web 复刻是纯本机体验，
 * 假装有账号只会误导（页面上写「本机用户」）。
 */

import { useState } from 'react'

import { calculateBestEstimatedOneRepMax, formatDate, formatDuration } from '../calc'
import type { BodyRecord, PresetPlan, WebSnapshot, WeekStart } from '../types'
import type { Screen } from '../AppShell'

interface Props {
  snapshot: WebSnapshot
  plan: PresetPlan
  now: number
  weekRangeText: string
  latestBody: BodyRecord | undefined
  onNavigate: (screen: Screen) => void
  onSettings: (patch: { weekStart?: WeekStart }) => void
  onReset: () => void
}

const DAY_MS = 86_400_000

export default function ProfileScreen({
  snapshot,
  plan,
  now,
  weekRangeText,
  latestBody,
  onNavigate,
  onSettings,
  onReset
}: Props) {
  const [confirmReset, setConfirmReset] = useState(false)

  const today = new Date(now)
  const mondayOffset = today.getDay() === 0 ? 6 : today.getDay() - 1
  const weekStart = new Date(today.getFullYear(), today.getMonth(), today.getDate() - mondayOffset).getTime()
  const weekSessions = snapshot.sessions.filter(
    (session) => session.startedAt >= weekStart && session.startedAt < weekStart + 7 * DAY_MS
  )
  const weekMinutes = Math.round(weekSessions.reduce((sum, session) => sum + session.durationSeconds, 0) / 60)

  // 全期最佳：每个动作取历史最好单组 1RM，再取前 3
  const bestByExercise = new Map<string, { name: string; best: number; date: number }>()
  for (const session of snapshot.sessions) {
    const grouped = new Map<string, typeof session.sets>()
    for (const set of session.sets) {
      if (set.isWarmup || set.weight <= 0 || set.reps <= 0) continue
      const list = grouped.get(set.exerciseId) ?? []
      list.push(set)
      grouped.set(set.exerciseId, list)
    }
    for (const [exerciseId, sets] of grouped) {
      const best = Math.round(calculateBestEstimatedOneRepMax(sets))
      const previous = bestByExercise.get(exerciseId)
      if (!previous || best > previous.best) {
        bestByExercise.set(exerciseId, { name: exerciseId, best, date: session.startedAt })
      }
    }
  }

  return (
    <section className="ft-screen">
      <div className="ft-card">
        <div className="ft-card-head">
          <div>
            <div className="ft-card-title" style={{ fontSize: 18 }}>
              本机用户
            </div>
            <div className="ft-row-s" style={{ marginTop: 3 }}>
              {plan.name} · 已练 {snapshot.sessions.length} 次
            </div>
          </div>
          <span className="ft-pill ft-pill-quiet">数据只在本机</span>
        </div>
      </div>

      <div className="ft-card">
        <div className="ft-card-head">
          <span className="ft-card-title">本周概览</span>
          <span className="ft-card-meta">{weekRangeText}</span>
        </div>
        <div className="ft-metrics">
          <div className="ft-metric">
            <b>{weekSessions.length}</b>
            <span>训练 · 次</span>
          </div>
          <div className="ft-metric">
            <b>{weekMinutes}</b>
            <span>分钟</span>
          </div>
          <div className="ft-metric">
            <b>{latestBody ? latestBody.weight : '--'}</b>
            <span>体重 · kg</span>
          </div>
        </div>
        <p className="ft-card-meta" style={{ margin: 0 }}>
          {weekSessions.length === 0
            ? '这周还没开始。完成一次训练后这里会有数。'
            : `最近一次 ${formatDate(weekSessions[weekSessions.length - 1].startedAt)} · ${formatDuration(
                weekSessions[weekSessions.length - 1].durationSeconds
              )}`}
        </p>
      </div>

      <div className="ft-card">
        <div className="ft-card-head">
          <span className="ft-card-title">最佳纪录</span>
          <span className="ft-card-meta">参考 1RM</span>
        </div>
        {bestByExercise.size === 0 ? (
          <div className="ft-empty">完成一次训练后，这里会记录每个动作的最好表现。</div>
        ) : (
          <div className="ft-rows">
            {[...bestByExercise.entries()]
              .sort((a, b) => b[1].best - a[1].best)
              .slice(0, 3)
              .map(([exerciseId, item]) => (
                <div className="ft-row" key={exerciseId}>
                  <span className="ft-row-main">
                    <span className="ft-row-t">{displayName(exerciseId)}</span>
                    <span className="ft-row-s">{formatDate(item.date)}</span>
                  </span>
                  <span className="ft-row-v">{item.best} kg</span>
                </div>
              ))}
          </div>
        )}
      </div>

      <div className="ft-card">
        <div className="ft-card-head">
          <span className="ft-card-title">更多</span>
        </div>
        <div className="ft-rows">
          <button className="ft-lib-row" onClick={() => onNavigate('library')}>
            <span className="ft-row-main">
              <span className="ft-row-t">动作库</span>
              <span className="ft-row-s">102 个动作 · 筛选 / 收藏 / 详情</span>
            </span>
            <span className="ft-row-v">→</span>
          </button>
          <button className="ft-lib-row" onClick={() => onNavigate('body')}>
            <span className="ft-row-main">
              <span className="ft-row-t">身体数据</span>
              <span className="ft-row-s">{snapshot.bodyRecords.length} 条体重记录</span>
            </span>
            <span className="ft-row-v">→</span>
          </button>
          <button className="ft-lib-row" onClick={() => onNavigate('review')}>
            <span className="ft-row-main">
              <span className="ft-row-t">训练回顾</span>
              <span className="ft-row-s">周/月趋势 · 肌肉分布</span>
            </span>
            <span className="ft-row-v">→</span>
          </button>
        </div>
      </div>

      <div className="ft-card">
        <div className="ft-card-head">
          <span className="ft-card-title">设置</span>
        </div>
        <div className="ft-row" style={{ borderBottom: 0 }}>
          <span className="ft-row-main">
            <span className="ft-row-t">周开始日</span>
            <span className="ft-row-s">影响首页节奏条与周回顾的起点</span>
          </span>
          <div className="ft-seg" role="tablist" aria-label="周开始日">
            <button
              className={snapshot.settings.weekStart === 'monday' ? 'is-on' : ''}
              onClick={() => onSettings({ weekStart: 'monday' })}
            >
              周一
            </button>
            <button
              className={snapshot.settings.weekStart === 'sunday' ? 'is-on' : ''}
              onClick={() => onSettings({ weekStart: 'sunday' })}
            >
              周日
            </button>
          </div>
        </div>
      </div>

      <div className="ft-card">
        <div className="ft-card-head">
          <span className="ft-card-title">本机数据</span>
        </div>
        <p className="ft-sub" style={{ margin: 0 }}>
          训练记录、身体数据与收藏都存在这个浏览器的 localStorage 里，不发送到任何服务器。
          换设备或清除浏览器数据后不会自动同步——这是与真机（登录后云同步）的差异。
        </p>
        {confirmReset ? (
          <div style={{ display: 'flex', gap: 8 }}>
            <button className="ft-btn ft-btn-danger" style={{ flex: 1 }} onClick={onReset}>
              确认清除
            </button>
            <button className="ft-btn ft-btn-ghost" style={{ flex: 1 }} onClick={() => setConfirmReset(false)}>
              取消
            </button>
          </div>
        ) : (
          <button className="ft-btn ft-btn-ghost" onClick={() => setConfirmReset(true)}>
            清除本机数据
          </button>
        )}
      </div>
    </section>
  )
}

function displayName(exerciseId: string): string {
  return exerciseId.startsWith('ex_') ? exerciseId.replace(/^ex_/, '').replace(/_/g, ' ') : exerciseId
}
