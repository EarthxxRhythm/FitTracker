/**
 * BodyRecordService —— 体重记录持久化与趋势统计（镜像安卓端 `data/service/BodyRecordService.kt`）。
 *
 * 约定：
 *  - 落盘键 `fit_tracker_body_records`，值为 `WeightRecord[]` 的 JSON。
 *  - 记录日期归一为**本地日零点**（日粒度）；同一自然日重复记录按「覆盖」处理（upsert by day）。
 *  - 重量恒以 **kg** 为基准存储；展示换算由 UI 层按「设置 · 体重单位」完成。
 *  - 趋势统计为**纯函数**（无 Context 依赖，便于单测）：周/月/年三段趋势 + 「较上周」delta。
 */
import { preferences } from '@kit.ArkData'
import { Context } from '@kit.AbilityKit'
import { FitTrackerStores } from '../../app/AppState'
import { WeightRecord, BodyTrend } from '../models/BodyModels'
import { WeekStart } from '../../common/utils/WeekUtils'

/** 偏好库内承载记录数组的键。 */
const KEY_RECORDS: string = 'records'

/** 月趋势锚点（今天回溯天数）。 */
const MONTH_OFFSETS: number[] = [30, 25, 20, 15, 10, 5, 0]
/** 月趋势标签（稀疏样式，空串留白）。 */
const MONTH_LABELS: string[] = ['30天前', '', '', '15天前', '', '', '现在']
/** 年趋势锚点（本月回溯月数）。 */
const YEAR_OFFSETS: number[] = [12, 10, 8, 6, 4, 2, 0]
/** 年趋势标签。 */
const YEAR_LABELS: string[] = ['12个月前', '', '', '6个月前', '', '', '现在']

/** 周首为周一时的一周标签。 */
const WEEK_LABELS_MONDAY: string[] = ['一', '二', '三', '四', '五', '六', '日']
/** 周首为周日时的一周标签。 */
const WEEK_LABELS_SUNDAY: string[] = ['日', '一', '二', '三', '四', '五', '六']

class BodyRecordService {
  private lastPersistenceError: string = ''

  getLastPersistenceError(): string {
    return this.lastPersistenceError
  }

  // --- 读 / 写 -------------------------------------------------------------

  /** 读回全部记录（按日期升序）。缺键 / 空串 / 解析失败一律回落空列表。 */
  async loadRecords(context: Context): Promise<WeightRecord[]> {
    this.lastPersistenceError = ''
    try {
      const prefs = await preferences.getPreferences(context, FitTrackerStores.BODY_RECORDS)
      const raw = await prefs.get(KEY_RECORDS, '') as string
      return this.decodeQuiet(raw)
    } catch (error) {
      this.lastPersistenceError = 'load_body_records_failed'
      return []
    }
  }

  /** 整份写入（先归一日期到日零点、再升序）。 */
  async saveRecords(context: Context, records: WeightRecord[]): Promise<void> {
    this.lastPersistenceError = ''
    try {
      await this.writeRecords(context, this.normalize(records))
    } catch (error) {
      this.lastPersistenceError = 'save_body_records_failed'
    }
  }

  /**
   * 追加一条记录（读-改-写）。落在**同一自然日**的既有记录被覆盖；其余记录保留。
   */
  async addRecord(context: Context, record: WeightRecord): Promise<void> {
    this.lastPersistenceError = ''
    try {
      const day: number = this.startOfDay(record.dateMillis)
      const existing: WeightRecord[] = await this.loadRecords(context)
      const kept: WeightRecord[] = []
      for (let i = 0; i < existing.length; i++) {
        if (this.startOfDay(existing[i].dateMillis) !== day) {
          kept.push(existing[i])
        }
      }
      kept.push({ dateMillis: day, kg: record.kg })
      await this.writeRecords(context, this.normalize(kept))
    } catch (error) {
      this.lastPersistenceError = 'save_body_record_failed'
    }
  }

  /** 清空全部记录。 */
  async clearRecords(context: Context): Promise<void> {
    this.lastPersistenceError = ''
    try {
      const prefs = await preferences.getPreferences(context, FitTrackerStores.BODY_RECORDS)
      await prefs.delete(KEY_RECORDS)
      await prefs.flush()
    } catch (error) {
      this.lastPersistenceError = 'clear_body_records_failed'
    }
  }

  // --- 统计（纯函数） ------------------------------------------------------

  /**
   * 周趋势：本周（周首由 [weekStart] 决定，共 7 天）逐日点。缺记录的日子按「最近一条 ≤ 该日的记录」
   * 前向填充；若无则回填最早一条。[records] 为空返回 undefined（调用方回落样例态）。
   */
  weekTrend(records: WeightRecord[], now: number, weekStart: WeekStart): BodyTrend | undefined {
    if (records.length === 0) {
      return undefined
    }
    const sorted: WeightRecord[] = this.sortByDate(records)
    const start: number = this.weekStartMillis(now, weekStart)
    const values: number[] = []
    for (let day = 0; day < 7; day++) {
      values.push(this.sampleAt(sorted, this.addDays(start, day)))
    }
    const labels: string[] = weekStart === 'sunday' ? WEEK_LABELS_SUNDAY : WEEK_LABELS_MONDAY
    const trend: BodyTrend = {
      values: values,
      labels: labels,
      deltaKg: values[6] - values[0],
      rangeText: '近 7 天'
    }
    return trend
  }

  /** 月趋势：近 30 天 7 个锚点的取样点。 */
  monthTrend(records: WeightRecord[], now: number): BodyTrend | undefined {
    if (records.length === 0) {
      return undefined
    }
    const sorted: WeightRecord[] = this.sortByDate(records)
    const today: number = this.startOfDay(now)
    const values: number[] = []
    for (let i = 0; i < MONTH_OFFSETS.length; i++) {
      values.push(this.sampleAt(sorted, this.addDays(today, -MONTH_OFFSETS[i])))
    }
    const trend: BodyTrend = {
      values: values,
      labels: MONTH_LABELS,
      deltaKg: values[6] - values[0],
      rangeText: '近 30 天'
    }
    return trend
  }

  /** 年趋势：近 12 个月 7 个锚点的取样点。 */
  yearTrend(records: WeightRecord[], now: number): BodyTrend | undefined {
    if (records.length === 0) {
      return undefined
    }
    const sorted: WeightRecord[] = this.sortByDate(records)
    const values: number[] = []
    for (let i = 0; i < YEAR_OFFSETS.length; i++) {
      values.push(this.sampleAt(sorted, this.addMonths(now, -YEAR_OFFSETS[i])))
    }
    const trend: BodyTrend = {
      values: values,
      labels: YEAR_LABELS,
      deltaKg: values[6] - values[0],
      rangeText: '近 12 个月'
    }
    return trend
  }

  /** 「较上周」delta（千克）：最新一条 − 该记录日期回溯 7 天的取样值。空记录返回 0。 */
  weekDeltaKg(records: WeightRecord[], now: number): number {
    if (records.length === 0) {
      return 0
    }
    const sorted: WeightRecord[] = this.sortByDate(records)
    const latest: WeightRecord = sorted[sorted.length - 1]
    const weekAgo: number = this.sampleAt(sorted, this.addDays(latest.dateMillis, -7))
    return latest.kg - weekAgo
  }

  /** 最新一条记录的 kg；空记录返回 undefined。 */
  latestKg(records: WeightRecord[]): number | undefined {
    if (records.length === 0) {
      return undefined
    }
    const sorted: WeightRecord[] = this.sortByDate(records)
    return sorted[sorted.length - 1].kg
  }

  // --- 内部：取样与日期算术（本地时区） ------------------------------------

  /** 取 [day]（含）之前最近一条记录的 kg；若无（皆晚于该日）则回填最早一条。 */
  private sampleAt(sorted: WeightRecord[], day: number): number {
    let value: number = sorted[0].kg
    for (let i = 0; i < sorted.length; i++) {
      if (sorted[i].dateMillis <= day) {
        value = sorted[i].kg
      } else {
        break
      }
    }
    return value
  }

  private sortByDate(records: WeightRecord[]): WeightRecord[] {
    const copy: WeightRecord[] = records.slice()
    copy.sort((a: WeightRecord, b: WeightRecord) => a.dateMillis - b.dateMillis)
    return copy
  }

  private normalize(records: WeightRecord[]): WeightRecord[] {
    const normalized: WeightRecord[] = []
    for (let i = 0; i < records.length; i++) {
      normalized.push({ dateMillis: this.startOfDay(records[i].dateMillis), kg: records[i].kg })
    }
    return this.sortByDate(normalized)
  }

  /** 本地时区日零点。 */
  private startOfDay(millis: number): number {
    const d: Date = new Date(millis)
    return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime()
  }

  /** 日粒度偏移（跨月/跨年由 Date 归一）。 */
  private addDays(millis: number, days: number): number {
    const d: Date = new Date(millis)
    return new Date(d.getFullYear(), d.getMonth(), d.getDate() + days).getTime()
  }

  /** 月粒度偏移（月末溢出由 Date 归一）。 */
  private addMonths(millis: number, months: number): number {
    const d: Date = new Date(millis)
    return new Date(d.getFullYear(), d.getMonth() + months, d.getDate()).getTime()
  }

  /** 当周周首 00:00（周首由 [weekStart] 决定）。 */
  private weekStartMillis(millis: number, weekStart: WeekStart): number {
    const d: Date = new Date(millis)
    const dayOfWeek: number = d.getDay() // 0=周日 .. 6=周六
    const offset: number = weekStart === 'sunday' ? dayOfWeek : (dayOfWeek + 6) % 7
    return this.addDays(this.startOfDay(millis), -offset)
  }

  // --- 内部：JSON 读写 -----------------------------------------------------

  private decodeQuiet(raw: string): WeightRecord[] {
    if (raw.length === 0) {
      return []
    }
    try {
      const parsed = JSON.parse(raw) as WeightRecord[]
      if (!Array.isArray(parsed)) {
        return []
      }
      return this.sortByDate(parsed)
    } catch (error) {
      return []
    }
  }

  private async writeRecords(context: Context, records: WeightRecord[]): Promise<void> {
    const prefs = await preferences.getPreferences(context, FitTrackerStores.BODY_RECORDS)
    await prefs.put(KEY_RECORDS, JSON.stringify(records))
    await prefs.flush()
  }
}

export default new BodyRecordService()
