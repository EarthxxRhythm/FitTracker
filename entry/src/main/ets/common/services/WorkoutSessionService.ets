/**
 * WorkoutSessionService —— 训练会话持久化服务
 *
 * 功能 #26: 保存训练会话（含备注）至本地偏好存储
 * 功能 #28-#32: 提供周统计、个人纪录、日历热力图数据源
 */
import { preferences } from '@kit.ArkData'

// ============================================================
// 接口定义
// ============================================================
export interface SavedSet {
  weight: number
  reps: number
}

export interface SavedExercise {
  name: string
  targetMuscle: string
  sets: SavedSet[]
}

export interface WorkoutSession {
  id: string
  planId: string
  planName: string
  dayLabel: string
  startTime: number
  endTime: number
  durationSeconds: number
  totalSets: number
  totalVolume: number
  notes: string
  exercises: SavedExercise[]
  createdAt: string
}

export interface WeeklyStats {
  count: number
  duration: number
  sets: number
  volume: number
}

export interface ExerciseRecord {
  exerciseName: string
  best1RM: number
  bestWeight: number
  bestReps: number
  bestDate: string
}

// ============================================================
// 常量
// ============================================================
const STORE_NAME = 'fit_tracker_sessions'
const KEY_SESSIONS = 'sessions'

// ============================================================
// 服务实现
// ============================================================
class WorkoutSessionService {
  async saveSession(context: Context, session: WorkoutSession): Promise<void> {
    const prefs = await preferences.getPreferences(context, STORE_NAME)
    const json = await prefs.get(KEY_SESSIONS, '[]') as string
    const sessions: WorkoutSession[] = JSON.parse(json)
    sessions.push(session)
    await prefs.put(KEY_SESSIONS, JSON.stringify(sessions))
    await prefs.flush()
  }

  async getSessions(context: Context): Promise<WorkoutSession[]> {
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      const json = await prefs.get(KEY_SESSIONS, '[]') as string
      return JSON.parse(json) as WorkoutSession[]
    } catch (e) {
      return []
    }
  }

  async getWeeklyStats(context: Context): Promise<WeeklyStats> {
    const sessions = await this.getSessions(context)
    const now = new Date()
    const dayOfWeek = now.getDay()
    // Monday = 1 ... Sunday = 7 (treat Sunday as 7)
    const mondayOffset = dayOfWeek === 0 ? 6 : dayOfWeek - 1
    const monday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - mondayOffset)
    const mondayStr = `${monday.getFullYear()}-${String(monday.getMonth() + 1).padStart(2, '0')}-${String(monday.getDate()).padStart(2, '0')}`
    const sunday = new Date(monday.getTime() + 6 * 24 * 60 * 60 * 1000)
    const sundayStr = `${sunday.getFullYear()}-${String(sunday.getMonth() + 1).padStart(2, '0')}-${String(sunday.getDate()).padStart(2, '0')}`

    let count = 0
    let duration = 0
    let sets = 0
    let volume = 0

    for (const session of sessions) {
      if (session.createdAt >= mondayStr && session.createdAt <= sundayStr) {
        count++
        duration += session.durationSeconds
        sets += session.totalSets
        volume += session.totalVolume
      }
    }

    return { count, duration, sets, volume }
  }

  async getAllExerciseRecords(context: Context): Promise<ExerciseRecord[]> {
    const sessions = await this.getSessions(context)
    const recordMap = new Map<string, ExerciseRecord>()

    for (const session of sessions) {
      for (const exercise of session.exercises) {
        if (exercise.sets.length === 0) {
          continue
        }
        for (const set of exercise.sets) {
          if (set.weight <= 0 || set.reps <= 0) {
            continue
          }
          // Epley formula: 1RM = weight * (1 + reps / 30)
          const oneRM = Math.round(set.weight * (1 + set.reps / 30))
          const existing = recordMap.get(exercise.name)

          if (!existing || oneRM > existing.best1RM) {
            const newRecord: ExerciseRecord = {
              exerciseName: exercise.name,
              best1RM: oneRM,
              bestWeight: set.weight,
              bestReps: set.reps,
              bestDate: session.createdAt
            }
            recordMap.set(exercise.name, newRecord)
          }
        }
      }
    }

    const results: ExerciseRecord[] = []
    recordMap.forEach((record: ExerciseRecord) => {
      results.push(record)
    })
    return results
  }

  async getTrainingDates(context: Context): Promise<string[]> {
    const sessions = await this.getSessions(context)
    const dateSet = new Set<string>()
    for (const session of sessions) {
      dateSet.add(session.createdAt)
    }
    const dates: string[] = []
    dateSet.forEach((date: string) => {
      dates.push(date)
    })
    return dates
  }
}

export default new WorkoutSessionService()
