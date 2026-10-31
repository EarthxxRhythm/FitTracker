/**
 * 计划屏：4 套预置计划 + 当前计划的训练日清单。
 *
 * 启用 = 换当前计划指针（store.enablePlan）。真机启用时会克隆成「我的计划」
 * （TrainingPlanService 功能 #9），web 没有计划编辑能力，所以只记指针——这一点在
 * store.ts 的 enablePlan 注释里写明了。
 */

import { resolveDayDistance, weekdayIndex } from '../calc'
import { PRESET_PLANS } from '../plans'
import type { WebSnapshot } from '../types'
import type { Screen } from '../AppShell'

interface Props {
  snapshot: WebSnapshot
  now: number
  onEnable: (planId: string) => void
  onOpenDay: (dayIndex: number) => void
  onNavigate: (screen: Screen) => void
}

const WEEK_LABELS = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']

function scheduleText(dayOfWeek: number[] | undefined): string {
  if (!dayOfWeek || dayOfWeek.length === 0) return '未排定'
  return dayOfWeek
    .slice()
    .sort((a, b) => (a === 0 ? 7 : a) - (b === 0 ? 7 : b))
    .map((value) => WEEK_LABELS[value])
    .join(' / ')
}

export default function PlansScreen({ snapshot, now, onEnable, onOpenDay }: Props) {
  const current = PRESET_PLANS.find((plan) => plan.id === snapshot.currentPlanId) ?? PRESET_PLANS[0]
  const weekday = weekdayIndex(now)

  return (
    <section className="ft-screen">
      <div>
        <p className="ft-eyebrow">训练计划</p>
        <h1 className="ft-h1">按分化数成套，启用即用</h1>
        <p className="ft-sub">
          四套预置计划来自产品内置数据（二/三/四/五分化）。启用后首页直接给出「今日训练」，
          不用每天重新想练什么。
        </p>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {PRESET_PLANS.map((plan) => {
          const isOn = plan.id === current.id
          return (
            <button
              key={plan.id}
              className={`ft-plan-card${isOn ? ' is-on' : ''}`}
              onClick={() => onEnable(plan.id)}
              aria-pressed={isOn}
            >
              <div className="ft-plan-top">
                <span className="ft-plan-dot" style={{ background: plan.coverColor }} />
                <span className="ft-plan-name">{plan.name}</span>
                {isOn && <span className="ft-pill">当前</span>}
                <span className="ft-top-spacer" />
                <span className="ft-card-meta">{plan.weeklyFrequency}</span>
              </div>
              <p className="ft-plan-desc">{plan.description}</p>
              <div className="ft-plan-meta">
                <span className="ft-pill ft-pill-quiet">{plan.targetAudience}</span>
                <span className="ft-pill ft-pill-quiet">{plan.days.length} 个训练日</span>
                <span className="ft-pill ft-pill-quiet">
                  {plan.days.reduce((sum, day) => sum + day.exercises.length, 0)} 个动作位
                </span>
              </div>
            </button>
          )
        })}
      </div>

      <div className="ft-card">
        <div className="ft-card-head">
          <span className="ft-card-title">{current.name} · 训练日</span>
          <span className="ft-card-meta">{current.weeklyFrequency}</span>
        </div>
        <div className="ft-rows">
          {current.days.map((day, index) => {
            const distance = resolveDayDistance(day, weekday)
            const isToday = distance === 0
            return (
              <div className="ft-row" key={day.dayLabel}>
                <span className="ft-row-idx">{String(index + 1).padStart(2, '0')}</span>
                <span className="ft-row-main">
                  <span className="ft-row-t">
                    {day.dayLabel}
                    {isToday && (
                      <span className="ft-pill" style={{ marginLeft: 8 }}>
                        今天
                      </span>
                    )}
                  </span>
                  <span className="ft-row-s">
                    {scheduleText(day.dayOfWeek)} · {day.exercises.length} 个动作
                  </span>
                </span>
                <button className="ft-btn ft-btn-ghost ft-btn-sm" onClick={() => onOpenDay(index)}>
                  查看
                </button>
              </div>
            )
          })}
        </div>
      </div>
    </section>
  )
}
