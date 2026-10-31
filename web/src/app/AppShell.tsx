/**
 * 在线体验的应用外壳：持有全部状态，负责路由、持久化与底部 Tab。
 *
 * 为什么状态放在这里而不是各屏内部：训练态要能跨屏存活（录入 → 切动作 → 摘要），
 * 且必须随时能落到 localStorage 的 draft 上。放在屏内会在切屏时丢。
 *
 * 进入方式：#/app。退出方式：顶栏「返回官网」→ #/。
 */

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import './app.css'

import { EXERCISES } from './data/content.generated'
import {
  buildContentIndex,
  formatWeekRange,
  isSameDay,
  resolveDayDistance,
  resolvePresetExercise,
  resolveTodayTrainingIndex,
  weekDayStarts,
  weekdayIndex
} from './calc'
import { findPresetPlan, PRESET_PLANS } from './plans'
import {
  addBodyRecord,
  appendSession,
  enablePlan,
  latestBodyRecord,
  loadSnapshot,
  removeBodyRecord,
  resetSnapshot,
  saveSnapshot,
  toggleFavorite,
  updateSettings
} from './store'
import type { BodyRecord, TrainingDay, WebSnapshot } from './types'
import {
  addSet,
  createActiveState,
  createSessionFromState,
  endExercise,
  writeSet,
  writeWarmup
} from './workout'
import type { ActiveExerciseSeed } from './workout'

import ActiveScreen from './screens/ActiveScreen'
import BodyScreen from './screens/BodyScreen'
import HomeScreen from './screens/HomeScreen'
import LibraryScreen from './screens/LibraryScreen'
import PlansScreen from './screens/PlansScreen'
import PreviewScreen from './screens/PreviewScreen'
import ProfileScreen from './screens/ProfileScreen'
import ReviewScreen from './screens/ReviewScreen'
import SummaryScreen from './screens/SummaryScreen'

export type Screen =
  | 'home'
  | 'plans'
  | 'preview'
  | 'active'
  | 'summary'
  | 'review'
  | 'library'
  | 'body'
  | 'profile'

const TABS: { key: Screen; label: string }[] = [
  { key: 'home', label: '首页' },
  { key: 'plans', label: '计划' },
  { key: 'review', label: '回顾' },
  { key: 'profile', label: '我的' }
]

/** 计划日的动作清单 → 训练态种子（名称换 exerciseId 的规则见 resolvePresetExercise）。 */
function buildSeeds(planId: string, day: TrainingDay, index: ReturnType<typeof buildContentIndex>): ActiveExerciseSeed[] {
  return day.exercises.map((item, position) => {
    const resolved = resolvePresetExercise(index, planId, item.name, position)
    return {
      plannedExerciseId: `${day.dayLabel}_exercise_${position + 1}`,
      exerciseId: resolved.exerciseId,
      name: resolved.name,
      targetSets: item.sets,
      targetReps: item.reps,
      intensityNote: `目标肌群 ${item.targetMuscle}`
    }
  })
}

export default function AppShell() {
  const [snapshot, setSnapshot] = useState<WebSnapshot>(() => loadSnapshot())
  const [screen, setScreen] = useState<Screen>('home')
  const [toast, setToast] = useState('')
  const [summarySessionId, setSummarySessionId] = useState('')
  const [detailExerciseId, setDetailExerciseId] = useState('')
  const [previewDayIndex, setPreviewDayIndex] = useState(-1)

  const content = useMemo(() => buildContentIndex(EXERCISES), [])
  const toastTimer = useRef<number>(0)
  const bodyRef = useRef<HTMLElement | null>(null)

  const now = Date.now()
  const plan = findPresetPlan(snapshot.currentPlanId) ?? PRESET_PLANS[0]
  const todayIndex = resolveTodayTrainingIndex(plan.days, weekdayIndex(now))
  const todayDay = todayIndex >= 0 ? plan.days[todayIndex] : null

  // 持久化：防抖 300ms，避免每敲一个数字就写一次
  useEffect(() => {
    const id = window.setTimeout(() => {
      const result = saveSnapshot(snapshot)
      if (!result.ok) {
        setToast(
          result.reason === 'quota'
            ? '本机存储已满，可在「我的」页清除数据'
            : '当前浏览器不允许本地存储，刷新后数据会丢'
        )
      }
    }, 300)
    return () => window.clearTimeout(id)
  }, [snapshot])

  useEffect(() => {
    if (!toast) return
    window.clearTimeout(toastTimer.current)
    toastTimer.current = window.setTimeout(() => setToast(''), 2200)
    return () => window.clearTimeout(toastTimer.current)
  }, [toast])

  const go = useCallback((next: Screen) => {
    setScreen(next)
    bodyRef.current?.scrollTo({ top: 0 })
  }, [])

  // ── 训练流程 ────────────────────────────────────────────────────────

  const openPreview = (dayIndex: number) => {
    setPreviewDayIndex(dayIndex)
    go('preview')
  }

  const startWorkout = () => {
    const day = plan.days[previewDayIndex]
    if (!day) return
    const state = createActiveState(plan.id, day.dayLabel, `${day.dayLabel} · ${plan.name}`, buildSeeds(plan.id, day, content))
    setSnapshot((prev) => ({ ...prev, draft: state, draftStartedAt: Date.now() }))
    go('active')
  }

  const updateDraft = (updater: (state: NonNullable<WebSnapshot['draft']>) => WebSnapshot['draft']) => {
    setSnapshot((prev) => {
      if (!prev.draft) return prev
      return { ...prev, draft: updater(prev.draft) }
    })
  }

  const finishWorkout = () => {
    const draft = snapshot.draft
    if (!draft) return
    const startedAt = snapshot.draftStartedAt || Date.now()
    const session = createSessionFromState(`web_${startedAt}`, draft, startedAt, Date.now())
    setSnapshot((prev) => appendSession(prev, session))
    setSummarySessionId(session.sessionId)
    go('summary')
  }

  const exitWorkout = () => {
    setSnapshot((prev) => ({ ...prev, draft: null, draftStartedAt: 0 }))
    go('home')
  }

  const summarySession = snapshot.sessions.find((item) => item.sessionId === summarySessionId) ?? null

  // ── 内容与设置 ──────────────────────────────────────────────────────

  const handleToggleFavorite = (exerciseId: string) =>
    setSnapshot((prev) => toggleFavorite(prev, exerciseId))

  const handleAddBody = (weight: number, bodyFat?: number) => {
    const record: BodyRecord = { id: `body_${Date.now()}`, at: Date.now(), weight, bodyFat }
    setSnapshot((prev) => addBodyRecord(prev, record))
    setToast(`已记录 ${weight} kg`)
  }

  const handleRemoveBody = (id: string) => {
    setSnapshot((prev) => removeBodyRecord(prev, id))
    setToast('已删除该条记录')
  }

  const handleReset = () => {
    setSnapshot(resetSnapshot(Date.now()))
    setToast('已清除本机数据，回到初始状态')
    go('home')
  }

  const weekRangeText = formatWeekRange(now, snapshot.settings.weekStart)
  const weekStarts = weekDayStarts(now, snapshot.settings.weekStart)

  return (
    <div className="hero-app">
      <div className="hero-app-status">
        <span>12:28</span>
        <span className="hero-app-sig">
          <i />
          <i />
          <i />
          <b>82</b>
        </span>
      </div>

      <main className="ft-main hero-app-body" ref={bodyRef}>
        {screen === 'home' && (
          <HomeScreen
            snapshot={snapshot}
            plan={plan}
            todayDay={todayDay}
            todayIndex={todayIndex}
            now={now}
            weekRangeText={weekRangeText}
            weekStarts={weekStarts}
            hasDraft={snapshot.draft !== null}
            onStart={() => openPreview(todayIndex >= 0 ? todayIndex : 0)}
            onResume={() => go('active')}
            onOpenPlans={() => go('plans')}
            onNavigate={go}
          />
        )}

        {screen === 'plans' && (
          <PlansScreen
            snapshot={snapshot}
            now={now}
            onEnable={(planId) => {
              setSnapshot((prev) => enablePlan(prev, planId))
              setToast('已切换到该计划')
            }}
            onOpenDay={(dayIndex) => openPreview(dayIndex)}
            onNavigate={go}
          />
        )}

        {screen === 'preview' && (
          <PreviewScreen
            plan={plan}
            dayIndex={previewDayIndex}
            onBack={() => go('home')}
            onStart={startWorkout}
          />
        )}

        {screen === 'active' && snapshot.draft && (
          <ActiveScreen
            state={snapshot.draft}
            startedAt={snapshot.draftStartedAt}
            onWriteSet={(plannedExerciseId, setIndex, weightText, repsText) =>
              updateDraft((state) => writeSet(state, plannedExerciseId, setIndex, weightText, repsText))
            }
            onToggleWarmup={(plannedExerciseId, setIndex, isWarmup) =>
              updateDraft((state) => writeWarmup(state, plannedExerciseId, setIndex, isWarmup))
            }
            onAddSet={(plannedExerciseId) => updateDraft((state) => addSet(state, plannedExerciseId))}
            onEndExercise={(plannedExerciseId) => {
              updateDraft((state) => endExercise(state, plannedExerciseId))
              setToast('已结束该动作')
            }}
            onFinish={finishWorkout}
            onExit={exitWorkout}
          />
        )}

        {screen === 'summary' && summarySession && (
          <SummaryScreen session={summarySession} content={content} onDone={() => go('home')} />
        )}

        {screen === 'review' && (
          <ReviewScreen snapshot={snapshot} content={content} now={now} weekRangeText={weekRangeText} onNavigate={go} />
        )}

        {screen === 'library' && (
          <LibraryScreen
            snapshot={snapshot}
            content={content}
            detailExerciseId={detailExerciseId}
            onOpenDetail={setDetailExerciseId}
            onCloseDetail={() => setDetailExerciseId('')}
            onToggleFavorite={handleToggleFavorite}
            onBack={() => go('profile')}
          />
        )}

        {screen === 'body' && (
          <BodyScreen
            snapshot={snapshot}
            onAdd={handleAddBody}
            onRemove={handleRemoveBody}
            onBack={() => go('profile')}
          />
        )}

        {screen === 'profile' && (
          <ProfileScreen
            snapshot={snapshot}
            plan={plan}
            now={now}
            weekRangeText={weekRangeText}
            latestBody={latestBodyRecord(snapshot)}
            onNavigate={go}
            onSettings={(patch) => setSnapshot((prev) => updateSettings(prev, patch))}
            onReset={handleReset}
          />
        )}
      </main>

      {(screen === 'home' || screen === 'plans' || screen === 'review' || screen === 'profile') && (
        <nav className="ft-tabs" aria-label="应用导航">
          {TABS.slice(0, 2).map((tab) => (
            <button
              key={tab.key}
              className={`ft-tab${screen === tab.key ? ' is-on' : ''}`}
              onClick={() => go(tab.key)}
            >
              {tab.label}
            </button>
          ))}
          <button className="ft-tab-cta" aria-label="开始训练" onClick={() => openPreview(todayIndex >= 0 ? todayIndex : 0)}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round">
              <path d="M6.5 6.5v11M17.5 6.5v11M3 9v6M21 9v6M6.5 12h11" />
            </svg>
          </button>
          {TABS.slice(2).map((tab) => (
            <button
              key={tab.key}
              className={`ft-tab${screen === tab.key ? ' is-on' : ''}`}
              onClick={() => go(tab.key)}
            >
              {tab.label}
            </button>
          ))}
        </nav>
      )}

      <div className={`ft-toast${toast ? ' is-on' : ''}`} role="status" aria-live="polite">
        {toast}
      </div>
    </div>
  )
}

// ── 供各屏复用的小工具 ──────────────────────────────────────────────────

export function nextTrainingDayLabel(plan: { days: TrainingDay[] }, now: number): string {
  const weekday = weekdayIndex(now)
  let best = ''
  let bestDistance = 8
  for (const day of plan.days) {
    const distance = resolveDayDistance(day, weekday)
    if (distance >= 0 && distance < bestDistance) {
      bestDistance = distance
      best = day.dayLabel
    }
  }
  return best
}

export function sessionCountOn(sessions: { startedAt: number }[], dayStart: number): number {
  return sessions.filter((session) => isSameDay(session.startedAt, dayStart)).length
}
