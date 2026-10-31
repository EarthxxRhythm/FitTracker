/**
 * 本机快照存储层。
 *
 * 设计取舍：
 *  - **localStorage 而非 IndexedDB**：数据量有明确上限（用户数据是 sessions + bodyRecords，
 *    一年训练约 200KB 量级；102 个动作是只读常量，不落库）。同步 API 让 store 保持纯函数式。
 *    代价是 5MB 硬上限，所以 save 捕获 QuotaExceededError 并给出可操作提示。
 *  - **形状校验 fail-closed 到空态**：读到脏数据不能把整页搞白，也不能静默当成有效数据。
 *  - **种子数据走真实结构**：预览页/回顾页的每个数字都是算出来的，不是写死的文案。
 *
 * 数据形状对齐 contracts/README.md §1 的 UserDataBackupPackage 子集——
 * 将来要接云同步，只需要换掉 save/load，数据层不用重写。
 */

import type { BodyRecord, WebSettings, WebSnapshot, WorkoutSession, WorkoutSet } from './types'

export const STORAGE_KEY = 'fittracker.web.v1'

const DAY_MS = 86_400_000

export function defaultSettings(): WebSettings {
  // 与 SettingsService.ets:51-53 的默认值一致
  return { weightUnit: 'kg', weekStart: 'monday' }
}

export function emptySnapshot(): WebSnapshot {
  return {
    schemaVersion: 1,
    createdAt: 0,
    sessions: [],
    currentPlanId: '',
    enabledPlans: [],
    bodyRecords: [],
    favorites: [],
    draft: null,
    draftStartedAt: 0,
    settings: defaultSettings()
  }
}

// ── 种子：首次进入时给一条真实结构的历史 ───────────────────────────────

function seedSet(exerciseId: string, weight: number, reps: number): WorkoutSet {
  return { setId: '', exerciseId, weight, reps, rpe: 0, isWarmup: false }
}

/**
 * 首次进入的演示数据：3 天前一次腿部训练（3 个动作 8 组）。
 *
 * 为什么给种子而不是空白页：空白首页无法展示任何计算能力，用户第一眼看到的是
 * 「暂无数据」——那正是现有 AppDemo 的毛病（写死文案冒充数据）。种子走真实结构，
 * 首页、回顾、肌肉分布全都由同一套计算得出，用户改一个数字就能看到它联动。
 */
export function seedSnapshot(now: number): WebSnapshot {
  const startedAt = now - 3 * DAY_MS
  const sets: WorkoutSet[] = [
    seedSet('ex_barbell_squat', 60, 10),
    seedSet('ex_barbell_squat', 60, 10),
    seedSet('ex_barbell_squat', 60, 8),
    seedSet('ex_romanian_deadlift', 50, 10),
    seedSet('ex_romanian_deadlift', 50, 10),
    seedSet('ex_machine_leg_press', 80, 12),
    seedSet('ex_machine_leg_press', 80, 12),
    seedSet('ex_machine_leg_press', 80, 10)
  ].map((set, index) => ({ ...set, setId: `seed_set_${index + 1}` }))

  let volume = 0
  for (const set of sets) volume += set.weight * set.reps

  const session: WorkoutSession = {
    sessionId: 'seed_session_1',
    planId: 'preset_upper_lower',
    dayId: '下肢A',
    startedAt,
    endedAt: startedAt + 52 * 60_000,
    durationSeconds: 52 * 60,
    totalSets: sets.length,
    totalVolume: Math.round(volume * 100) / 100,
    fatigueScore: 0,
    sessionRpe: 0,
    notes: `completed_sets=${sets.length};target_sets=${sets.length}`,
    sets
  }

  return {
    ...emptySnapshot(),
    createdAt: now,
    sessions: [session],
    currentPlanId: 'preset_upper_lower',
    enabledPlans: [],
    bodyRecords: [{ id: 'seed_body_1', at: startedAt - 2 * DAY_MS, weight: 72.5 }],
    favorites: ['ex_barbell_squat']
  }
}

// ── 读 ─────────────────────────────────────────────────────────────────

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null
}

function isWorkoutSet(value: unknown): value is WorkoutSet {
  return (
    isRecord(value) &&
    typeof value.setId === 'string' &&
    typeof value.exerciseId === 'string' &&
    typeof value.weight === 'number' &&
    typeof value.reps === 'number' &&
    typeof value.isWarmup === 'boolean'
  )
}

function isWorkoutSession(value: unknown): value is WorkoutSession {
  return (
    isRecord(value) &&
    typeof value.sessionId === 'string' &&
    typeof value.startedAt === 'number' &&
    typeof value.durationSeconds === 'number' &&
    typeof value.notes === 'string' &&
    Array.isArray(value.sets) &&
    value.sets.every(isWorkoutSet)
  )
}

function isBodyRecord(value: unknown): value is BodyRecord {
  return isRecord(value) && typeof value.id === 'string' && typeof value.at === 'number' && typeof value.weight === 'number'
}

function isSettings(value: unknown): value is WebSettings {
  return (
    isRecord(value) &&
    (value.weightUnit === 'kg' || value.weightUnit === 'lbs') &&
    (value.weekStart === 'monday' || value.weekStart === 'sunday')
  )
}

/**
 * 读快照。任何一环不合形状就整份丢弃并回种子——宁可让用户看到演示数据，
 * 也不要让半残数据把页面渲染成 NaN。
 *
 * 版本不同（未来 schemaVersion 升级）时同样回种子，不做静默迁移。
 */
export function parseSnapshot(raw: string | null, now: number): WebSnapshot {
  if (raw === null || raw.length === 0) return seedSnapshot(now)
  let parsed: unknown
  try {
    parsed = JSON.parse(raw)
  } catch {
    return seedSnapshot(now)
  }
  if (!isRecord(parsed) || parsed.schemaVersion !== 1) return seedSnapshot(now)
  if (!Array.isArray(parsed.sessions) || !parsed.sessions.every(isWorkoutSession)) {
    return seedSnapshot(now)
  }
  if (!Array.isArray(parsed.bodyRecords) || !parsed.bodyRecords.every(isBodyRecord)) {
    return seedSnapshot(now)
  }
  if (!Array.isArray(parsed.favorites) || !parsed.favorites.every((item) => typeof item === 'string')) {
    return seedSnapshot(now)
  }
  if (!isSettings(parsed.settings)) return seedSnapshot(now)

  const draft = parsed.draft
  const validDraft =
    isRecord(draft) && Array.isArray(draft.exercises) && typeof draft.title === 'string' ? (draft as unknown as WebSnapshot['draft']) : null

  return {
    schemaVersion: 1,
    createdAt: typeof parsed.createdAt === 'number' ? parsed.createdAt : now,
    sessions: parsed.sessions as WorkoutSession[],
    currentPlanId: typeof parsed.currentPlanId === 'string' ? parsed.currentPlanId : '',
    enabledPlans: Array.isArray(parsed.enabledPlans) ? (parsed.enabledPlans as WebSnapshot['enabledPlans']) : [],
    bodyRecords: parsed.bodyRecords as BodyRecord[],
    favorites: parsed.favorites as string[],
    draft: validDraft,
    draftStartedAt: typeof parsed.draftStartedAt === 'number' ? parsed.draftStartedAt : 0,
    settings: parsed.settings
  }
}

export function loadSnapshot(now = Date.now()): WebSnapshot {
  if (typeof localStorage === 'undefined') return seedSnapshot(now)
  return parseSnapshot(localStorage.getItem(STORAGE_KEY), now)
}

// ── 写 ─────────────────────────────────────────────────────────────────

export type SaveResult = { ok: true } | { ok: false; reason: 'quota' | 'unavailable' }

/** 写快照。配额超限时返回失败原因，由调用方给出可操作提示（不静默丢数据）。 */
export function saveSnapshot(snapshot: WebSnapshot): SaveResult {
  if (typeof localStorage === 'undefined') return { ok: false, reason: 'unavailable' }
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(snapshot))
    return { ok: true }
  } catch (error) {
    const isQuota =
      error instanceof Error &&
      (error.name === 'QuotaExceededError' || error.name === 'NS_ERROR_DOM_QUOTA_REACHED')
    return { ok: false, reason: isQuota ? 'quota' : 'unavailable' }
  }
}

// ── 不可变更新器 ───────────────────────────────────────────────────────

export function appendSession(snapshot: WebSnapshot, session: WorkoutSession): WebSnapshot {
  return {
    ...snapshot,
    sessions: [...snapshot.sessions, session],
    draft: null,
    draftStartedAt: 0
  }
}

export function dropSession(snapshot: WebSnapshot, sessionId: string): WebSnapshot {
  return { ...snapshot, sessions: snapshot.sessions.filter((item) => item.sessionId !== sessionId) }
}

export function addBodyRecord(snapshot: WebSnapshot, record: BodyRecord): WebSnapshot {
  const others = snapshot.bodyRecords.filter((item) => item.id !== record.id)
  return { ...snapshot, bodyRecords: [...others, record].sort((a, b) => a.at - b.at) }
}

export function removeBodyRecord(snapshot: WebSnapshot, id: string): WebSnapshot {
  return { ...snapshot, bodyRecords: snapshot.bodyRecords.filter((item) => item.id !== id) }
}

export function toggleFavorite(snapshot: WebSnapshot, exerciseId: string): WebSnapshot {
  const exists = snapshot.favorites.includes(exerciseId)
  return {
    ...snapshot,
    favorites: exists
      ? snapshot.favorites.filter((item) => item !== exerciseId)
      : [...snapshot.favorites, exerciseId]
  }
}

export function updateSettings(snapshot: WebSnapshot, patch: Partial<WebSettings>): WebSnapshot {
  return { ...snapshot, settings: { ...snapshot.settings, ...patch } }
}

export function enablePlan(snapshot: WebSnapshot, planId: string): WebSnapshot {
  // 预置计划为只读模板，启用只是换指针——真机启用时会克隆成用户计划（TrainingPlanService 功能 #9），
  // web 没有「我的计划」编辑能力，因此只记录当前计划 id。
  if (snapshot.currentPlanId === planId) return snapshot
  return { ...snapshot, currentPlanId: planId }
}

/** 清空本机数据 → 回到「首次进入」的状态（含演示种子）。 */
export function resetSnapshot(now: number): WebSnapshot {
  if (typeof localStorage !== 'undefined') {
    try {
      localStorage.removeItem(STORAGE_KEY)
    } catch {
      // 移除失败也无妨：下一次 save 会覆盖
    }
  }
  return seedSnapshot(now)
}

// ── 便捷派生 ───────────────────────────────────────────────────────────

export function sessionsInRange(snapshot: WebSnapshot, fromInclusive: number, toExclusive: number): WorkoutSession[] {
  return snapshot.sessions.filter(
    (session) => session.startedAt >= fromInclusive && session.startedAt < toExclusive
  )
}

export function latestBodyRecord(snapshot: WebSnapshot): BodyRecord | undefined {
  return snapshot.bodyRecords[snapshot.bodyRecords.length - 1]
}
