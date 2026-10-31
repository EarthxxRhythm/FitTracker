/**
 * 首页：今日训练 + 本周节奏。
 *
 * 「今天练什么」走预置计划路径（TrainingPlanService.resolveTodayTrainingIndex）：
 * 先按 dayOfWeek 匹配今天，解析不出就是休息日，并给出最近的下一个训练日。
 */

import { formatMonthDayWeekday, isSameDay } from '../calc'
import type { PresetPlan, TrainingDay, WebSnapshot } from '../types'
import type { Screen } from '../AppShell'

interface Props {
  snapshot: WebSnapshot
  plan: PresetPlan
  todayDay: TrainingDay | null
  todayIndex: number
  now: number
  weekRangeText: string
  weekStarts: number[]
  hasDraft: boolean
  onStart: () => void
  onResume: () => void
  onOpenPlans: () => void
  onNavigate: (screen: Screen) => void
}

const WEEK_LABELS = ['日', '一', '二', '三', '四', '五', '六']

function greeting(now: number): string {
  const hour = new Date(now).getHours()
  if (hour < 6) return '夜深了，注意恢复'
  if (hour < 12) return '早上好'
  if (hour < 18) return '下午好'
  return '晚上好'
}

export default function HomeScreen({
  snapshot,
  plan,
  todayDay,
  now,
  weekRangeText,
  weekStarts,
  hasDraft,
  onStart,
  onResume,
  onOpenPlans,
  onNavigate
}: Props) {
  const weekStart = weekStarts[0]
  const weekEnd = weekStarts[6] + 86_400_000
  const weekSessions = snapshot.sessions.filter(
    (session) => session.startedAt >= weekStart && session.startedAt < weekEnd
  )
  const plannedDays = plan.days.length || 1
  const progress = Math.min(1, weekSessions.length / plannedDays)

  const muscleCount = todayDay
    ? new Set(todayDay.exercises.map((exercise) => exercise.targetMuscle)).size
    : 0
  const todayDone = snapshot.sessions.some((session) => isSameDay(session.startedAt, now))

  return (
    <section className="ft-screen">
      <div>
        <p className="ft-eyebrow">{formatMonthDayWeekday(now)}</p>
        <h1 className="ft-h1">{greeting(now)}，今天练什么？</h1>
      </div>

      {hasDraft && (
        <div className="ft-card" style={{ borderColor: 'rgba(181,152,105,.5)' }}>
          <div className="ft-card-head">
            <span className="ft-card-title">有一次训练没结束</span>
            <span className="ft-pill ft-pill-gold">草稿</span>
          </div>
          <p className="ft-sub">接着练会从上次的进度继续；退出会丢掉这次记录。</p>
          <button className="ft-btn ft-btn-primary" onClick={onResume}>
            继续训练
          </button>
        </div>
      )}

      <div className="ft-card">
        <div className="ft-card-head">
          <div>
            <div className="ft-card-meta">今日训练</div>
            <div className="ft-card-title" style={{ fontSize: 19, marginTop: 3 }}>
              {todayDay ? todayDay.dayLabel : '恢复日'}
              {todayDone && <span className="ft-pill" style={{ marginLeft: 8 }}>已练</span>}
            </div>
            <div className="ft-row-s" style={{ marginTop: 4 }}>
              {plan.name} · {plan.weeklyFrequency}
            </div>
          </div>
          <div className="ft-ring">
            <svg viewBox="0 0 100 100" aria-hidden="true">
              <circle className="track" cx="50" cy="50" r="44" />
              <circle
                className="fill"
                cx="50"
                cy="50"
                r="44"
                strokeDasharray={`${2 * Math.PI * 44}`}
                strokeDashoffset={`${2 * Math.PI * 44 * (1 - progress)}`}
              />
            </svg>
            <div className="ft-ring-label">
              <b>{Math.round(progress * 100)}%</b>
              <span>本周进度</span>
            </div>
          </div>
        </div>

        {todayDay ? (
          <>
            <div className="ft-metrics">
              <div className="ft-metric">
                <b>{todayDay.exercises.length}</b>
                <span>动作</span>
              </div>
              <div className="ft-metric">
                <b>{todayDay.exercises.reduce((sum, exercise) => sum + exercise.sets, 0)}</b>
                <span>计划组</span>
              </div>
              <div className="ft-metric">
                <b>{muscleCount}</b>
                <span>肌群</span>
              </div>
            </div>
            <button className="ft-btn ft-btn-primary" onClick={onStart}>
              开始训练
            </button>
            <button className="ft-btn ft-btn-ghost" onClick={onOpenPlans}>
              换个计划
            </button>
          </>
        ) : (
          <>
            <p className="ft-sub">
              当前计划今天没有训练安排，保持恢复节奏就好。拉伸、散步或睡够都算训练的一部分。
            </p>
            <button className="ft-btn ft-btn-ghost" onClick={onOpenPlans}>
              看看其他计划
            </button>
          </>
        )}
      </div>

      <div className="ft-card">
        <div className="ft-card-head">
          <span className="ft-card-title">本周节奏</span>
          <span className="ft-card-meta">
            {weekSessions.length} / {plannedDays} 次 · {weekRangeText}
          </span>
        </div>
        <div className="ft-week">
          {weekStarts.map((dayStart) => {
            const done = snapshot.sessions.some((session) => isSameDay(session.startedAt, dayStart))
            const isToday = isSameDay(dayStart, now)
            const classes = ['ft-day']
            if (done) classes.push('is-done')
            if (isToday) classes.push('is-today')
            return (
              <div key={dayStart} className={classes.join(' ')}>
                <i />
                <span>{WEEK_LABELS[new Date(dayStart).getDay()]}</span>
                <b>{new Date(dayStart).getDate()}</b>
              </div>
            )
          })}
        </div>
      </div>

      <div className="ft-card">
        <div className="ft-card-head">
          <span className="ft-card-title">最近训练</span>
          <button className="ft-back" onClick={() => onNavigate('review')}>
            全部回顾 →
          </button>
        </div>
        {snapshot.sessions.length === 0 ? (
          <div className="ft-empty">还没有记录。完成一次训练后，这里会开始累积趋势。</div>
        ) : (
          <div className="ft-rows">
            {[...snapshot.sessions]
              .sort((a, b) => b.startedAt - a.startedAt)
              .slice(0, 3)
              .map((session) => (
                <div className="ft-row" key={session.sessionId}>
                  <span className="ft-row-main">
                    <span className="ft-row-t">{session.dayId || '训练'}</span>
                    <span className="ft-row-s">{formatMonthDayWeekday(session.startedAt)}</span>
                  </span>
                  <span className="ft-row-v">
                    {session.totalSets} 组 · {Math.round(session.totalVolume)} kg
                  </span>
                </div>
              ))}
          </div>
        )}
      </div>
    </section>
  )
}
