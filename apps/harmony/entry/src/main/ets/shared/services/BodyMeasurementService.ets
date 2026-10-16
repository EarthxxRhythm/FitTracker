/**
 * BodyMeasurementService —— 身体测量记录持久化（围度 + 体成分）。
 *
 * 镜像 `BodyRecordService` 的约定：落盘为单键 JSON 数组、日期归一日粒度、同一自然日覆盖（upsert）。
 * 与体重记录的差异：一条记录承载多项测量（围度 5 项 + 体脂率 + 骨骼肌 + 身体水分），
 * 未录入项以 `MEASUREMENT_UNSET`（-1）表示——**合并语义**：同日重复录入时，只覆盖本次
 * 明确提供的项，其余保留既有值（避免「只记体重围度」把已录的体脂清掉）。
 */
import { preferences } from '@kit.ArkData'
import { Context } from '@kit.AbilityKit'
import { FitTrackerStores } from '../../app/AppState'
import { BodyMeasurement, MEASUREMENT_UNSET } from '../models/BodyModels'

/** 偏好库内承载记录数组的键。 */
const KEY_MEASUREMENTS: string = 'measurements'

class BodyMeasurementService {
  private lastPersistenceError: string = ''

  getLastPersistenceError(): string {
    return this.lastPersistenceError
  }

  /** 读回全部记录（按日期升序）。缺键 / 空串 / 解析失败一律回落空列表。 */
  async loadMeasurements(context: Context): Promise<BodyMeasurement[]> {
    this.lastPersistenceError = ''
    try {
      const prefs = await preferences.getPreferences(context, FitTrackerStores.BODY_MEASUREMENTS)
      const raw = await prefs.get(KEY_MEASUREMENTS, '') as string
      return this.decodeQuiet(raw)
    } catch (error) {
      this.lastPersistenceError = 'load_body_measurements_failed'
      return []
    }
  }

  /** 整份写入（先归一日期到日零点、再升序）。 */
  async saveMeasurements(context: Context, records: BodyMeasurement[]): Promise<void> {
    this.lastPersistenceError = ''
    try {
      await this.writeMeasurements(context, this.normalize(records))
    } catch (error) {
      this.lastPersistenceError = 'save_body_measurements_failed'
    }
  }

  /**
   * 写入一条记录（读-改-写）。落在同一自然日的既有记录按**逐项合并**：
   * 本次为 `MEASUREMENT_UNSET` 的项保留既有值。
   */
  async addMeasurement(context: Context, record: BodyMeasurement): Promise<void> {
    this.lastPersistenceError = ''
    try {
      const day: number = this.startOfDay(record.dateMillis)
      const existing: BodyMeasurement[] = await this.loadMeasurements(context)
      const kept: BodyMeasurement[] = []
      let previous: BodyMeasurement | undefined = undefined
      for (let i = 0; i < existing.length; i++) {
        if (this.startOfDay(existing[i].dateMillis) === day) {
          previous = existing[i]
        } else {
          kept.push(existing[i])
        }
      }
      kept.push(this.merge(previous, record, day))
      await this.writeMeasurements(context, this.normalize(kept))
    } catch (error) {
      this.lastPersistenceError = 'save_body_measurement_failed'
    }
  }

  /** 清空全部记录。 */
  async clearMeasurements(context: Context): Promise<void> {
    this.lastPersistenceError = ''
    try {
      const prefs = await preferences.getPreferences(context, FitTrackerStores.BODY_MEASUREMENTS)
      await prefs.delete(KEY_MEASUREMENTS)
      await prefs.flush()
    } catch (error) {
      this.lastPersistenceError = 'clear_body_measurements_failed'
    }
  }

  /** 最新一条记录；空列表返回 undefined。 */
  latest(records: BodyMeasurement[]): BodyMeasurement | undefined {
    if (records.length === 0) {
      return undefined
    }
    const sorted: BodyMeasurement[] = this.sortByDate(records)
    return sorted[sorted.length - 1]
  }

  /** 倒数第二条记录（用于计算「较上次」差值）；记录不足 2 条返回 undefined。 */
  previous(records: BodyMeasurement[]): BodyMeasurement | undefined {
    if (records.length < 2) {
      return undefined
    }
    const sorted: BodyMeasurement[] = this.sortByDate(records)
    return sorted[sorted.length - 2]
  }

  /** 某项的「较上次」差值；任一侧未录入返回 undefined。 */
  delta(latest: number, previous: number): number | undefined {
    if (latest === MEASUREMENT_UNSET || previous === MEASUREMENT_UNSET) {
      return undefined
    }
    return Math.round((latest - previous) * 10) / 10
  }

  // --- 内部 ---------------------------------------------------------------

  /** 逐项合并：`record` 中未录入（-1）的项沿用 `previous` 的既有值。 */
  private merge(previous: BodyMeasurement | undefined, record: BodyMeasurement, day: number): BodyMeasurement {
    if (previous === undefined) {
      const fresh: BodyMeasurement = {
        dateMillis: day,
        chestCm: record.chestCm,
        waistCm: record.waistCm,
        hipCm: record.hipCm,
        armCm: record.armCm,
        thighCm: record.thighCm,
        bodyFatPercent: record.bodyFatPercent,
        skeletalMuscleKg: record.skeletalMuscleKg,
        bodyWaterPercent: record.bodyWaterPercent
      }
      return fresh
    }
    const merged: BodyMeasurement = {
      dateMillis: day,
      chestCm: this.pick(record.chestCm, previous.chestCm),
      waistCm: this.pick(record.waistCm, previous.waistCm),
      hipCm: this.pick(record.hipCm, previous.hipCm),
      armCm: this.pick(record.armCm, previous.armCm),
      thighCm: this.pick(record.thighCm, previous.thighCm),
      bodyFatPercent: this.pick(record.bodyFatPercent, previous.bodyFatPercent),
      skeletalMuscleKg: this.pick(record.skeletalMuscleKg, previous.skeletalMuscleKg),
      bodyWaterPercent: this.pick(record.bodyWaterPercent, previous.bodyWaterPercent)
    }
    return merged
  }

  private pick(incoming: number, fallback: number): number {
    return incoming === MEASUREMENT_UNSET ? fallback : incoming
  }

  private sortByDate(records: BodyMeasurement[]): BodyMeasurement[] {
    const copy: BodyMeasurement[] = records.slice()
    copy.sort((a: BodyMeasurement, b: BodyMeasurement) => a.dateMillis - b.dateMillis)
    return copy
  }

  private normalize(records: BodyMeasurement[]): BodyMeasurement[] {
    const normalized: BodyMeasurement[] = []
    for (let i = 0; i < records.length; i++) {
      const item: BodyMeasurement = records[i]
      const copy: BodyMeasurement = {
        dateMillis: this.startOfDay(item.dateMillis),
        chestCm: item.chestCm,
        waistCm: item.waistCm,
        hipCm: item.hipCm,
        armCm: item.armCm,
        thighCm: item.thighCm,
        bodyFatPercent: item.bodyFatPercent,
        skeletalMuscleKg: item.skeletalMuscleKg,
        bodyWaterPercent: item.bodyWaterPercent
      }
      normalized.push(copy)
    }
    return this.sortByDate(normalized)
  }

  /** 本地时区日零点。 */
  private startOfDay(millis: number): number {
    const d: Date = new Date(millis)
    return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime()
  }

  private decodeQuiet(raw: string): BodyMeasurement[] {
    if (raw.length === 0) {
      return []
    }
    try {
      const parsed = JSON.parse(raw) as BodyMeasurement[]
      if (!Array.isArray(parsed)) {
        return []
      }
      return this.sortByDate(parsed)
    } catch (error) {
      return []
    }
  }

  private async writeMeasurements(context: Context, records: BodyMeasurement[]): Promise<void> {
    const prefs = await preferences.getPreferences(context, FitTrackerStores.BODY_MEASUREMENTS)
    await prefs.put(KEY_MEASUREMENTS, JSON.stringify(records))
    await prefs.flush()
  }
}

export default new BodyMeasurementService()
