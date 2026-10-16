/** BodyDataContent —— 身体数据二级页界面体（对应 body-data.html · screen-body-data，390 直绘）。 */
import { ColorTokens, MotionTokens } from '../../../common/styles/DesignTokens'
import { window } from '@kit.ArkUI'
import UserProfileService, { UserProfile, WeightUnit, Gender } from '../../../common/services/UserProfileService'
import SettingsService, { AppSettings } from '../../../common/services/SettingsService'
import { formatWeight, weightUnitLabel, displayToKg } from '../../../common/utils/WeightUtils'
import {
  computeBmi,
  bmiCategory,
  bmiCategoryLabel,
  basalMetabolicRate,
  ageFromBirthYear,
  bodyFatHealthyRange,
  BodyFatRange,
  measurementDelta
} from '../../../common/utils/BodyMetrics'
import { shakeField } from '../../../common/utils/FieldShake'
import BodyRecordService from '../../../shared/services/BodyRecordService'
import BodyMeasurementService from '../../../shared/services/BodyMeasurementService'
import { WeightRecord, BodyTrend, BodyMeasurement, MEASUREMENT_UNSET } from '../../../shared/models/BodyModels'
import { WeekStart } from '../../../common/utils/WeekUtils'

interface BodyMetricTile {
  label: string
  value: string
  unit: string
  note: string
  noteMuted: boolean
}

interface MeasureRow {
  label: string
  value: string
  delta: string
  deltaDown: boolean
}

interface TrendSeries {
  vals: number[]
  labels: string[]
  prefix: string
  deltaKg: number
}

function createMetricTile(label: string, value: string, unit: string, note: string, noteMuted: boolean): BodyMetricTile {
  return {
    label: label,
    value: value,
    unit: unit,
    note: note,
    noteMuted: noteMuted
  }
}

function createMeasure(label: string, value: string, delta: string, deltaDown: boolean): MeasureRow {
  return {
    label: label,
    value: value,
    delta: delta,
    deltaDown: deltaDown
  }
}

/** 体成分卡初始空态（未读数据前先渲染诚实占位，避免空白）。 */
function emptyMetricTiles(): BodyMetricTile[] {
  return [
    createMetricTile('BMI', '--', '', '', false),
    createMetricTile('骨骼肌', '--', '', '', true),
    createMetricTile('基础代谢', '--', '', '', true),
    createMetricTile('身体水分', '--', '', '', false)
  ]
}

/** 围度卡初始空态（五项全未录）。 */
function emptyMeasureRows(): MeasureRow[] {
  return [
    createMeasure('胸围', '--', '', false),
    createMeasure('腰围', '--', '', false),
    createMeasure('臀围', '--', '', false),
    createMeasure('臂围', '--', '', false),
    createMeasure('大腿围', '--', '', false)
  ]
}

@Component
export struct BodyDataContent {
  @State private backPressed: boolean = false
  @State private ctaPressed: boolean = false
  @State private savePressed: boolean = false
  @State private cancelPressed: boolean = false
  @State private sheetOpen: boolean = false
  /** 记录面板当前档：'weight' | 'measure' | 'profile'。 */
  @State private sheetTab: string = 'weight'
  /** 最新体重（kg）；无记录时为 0（展示层按 [hasWeight] 走空态）。 */
  @State private currentWeightKg: number = 0
  @State private hasWeight: boolean = false
  @State private weightInput: string = ''
  @State private sheetHint: string = ''
  /** 测量录入输入（围度 cm / 体脂% / 骨骼肌 kg / 水分%）；空串 = 本次未录，保存时落 MEASUREMENT_UNSET。 */
  @State private chestInput: string = ''
  @State private waistInput: string = ''
  @State private hipInput: string = ''
  @State private armInput: string = ''
  @State private thighInput: string = ''
  @State private fatInput: string = ''
  @State private muscleInput: string = ''
  @State private waterInput: string = ''
  /** 身体档案录入输入（身高 cm / 出生年 / 性别）。 */
  @State private heightInput: string = ''
  @State private birthYearInput: string = ''
  @State private genderSelect: Gender = ''
  /** 真实身体档案（BMI / 基础代谢派生用）。 */
  @State private profileHeightCm: number = 0
  @State private profileGender: Gender = ''
  @State private profileBirthYear: number = 0
  /** 最新一条测量记录；无记录为 undefined（体脂/骨骼肌/水分/围度空态）。 */
  @State private latestMeasurement: BodyMeasurement | undefined = undefined
  /** 顶栏真实日期。 */
  @State private headerDay: string = ''
  @State private headerMonth: string = ''
  /** 体脂率展示值与旁注（旁注按性别生成健康区间）。 */
  @State private bodyFatValue: string = '--'
  @State private bodyFatNote: string = '体脂率'
  /** 体重输入校验失败时的横向抖动偏移（错误消失后无效果）。 */
  @State private shakeOffset: number = 0
  @State private period: string = 'week'
  // 展示层体重单位（来自「设置 · 体重单位」）；基准值始终是 kg，仅展示与输入按单位换算。
  @State private displayUnit: WeightUnit = 'kg'
  @State private trendCap: string = ''
  // 系统状态栏高度（vp）。页面区本身落在状态栏之下，原型顶距须扣掉它才不会双计。
  @State private topInsetVp: number = 0

  aboutToAppear(): void {
    this.resolveTopInset()
    this.syncHeaderDate()
    this.bootstrap()
  }

  /** 顶栏日期取当前系统日期（对齐 Android BodyScreen 的真日期实现）。 */
  private syncHeaderDate(): void {
    const now: Date = new Date()
    this.headerDay = String(now.getDate())
    this.headerMonth = (now.getMonth() + 1) + '月'
  }

  /** 先读展示单位与身体档案（决定文案口径），再读真实体重/测量记录覆盖样例态。 */
  private async bootstrap(): Promise<void> {
    await this.loadDisplayUnit()
    await this.loadBodyRecords()
    await this.loadMeasurementRecords()
  }

  /** 读回真实体重记录；无记录时走诚实空态（不回落样例值）。 */
  private async loadBodyRecords(): Promise<void> {
    const context: Context | null = this.contextOrNull()
    if (context === null) {
      return
    }
    try {
      const records: WeightRecord[] = await BodyRecordService.loadRecords(context)
      if (records.length === 0) {
        this.hasWeight = false
        this.syncComposition()
        return
      }
      const latest: number | undefined = BodyRecordService.latestKg(records)
      if (latest !== undefined) {
        this.currentWeightKg = latest
        this.hasWeight = true
      }
      const settings: AppSettings = await SettingsService.loadSettings(context)
      this.applyTrends(records, settings.weekStart)
      this.syncComposition()
    } catch (error) {
      // 读取失败保持空态，不打断页面展示
      this.hasWeight = false
      this.syncComposition()
    }
  }

  /** 读回真实测量记录（围度 / 体脂 / 骨骼肌 / 水分），刷新围度卡与体成分卡。 */
  private async loadMeasurementRecords(): Promise<void> {
    const context: Context | null = this.contextOrNull()
    if (context === null) {
      return
    }
    try {
      const records: BodyMeasurement[] = await BodyMeasurementService.loadMeasurements(context)
      this.latestMeasurement = BodyMeasurementService.latest(records)
      this.previousMeasurement = BodyMeasurementService.previous(records)
      this.measures = this.buildMeasures()
      this.syncComposition()
    } catch (error) {
      // 读取失败保持空态
      this.latestMeasurement = undefined
      this.previousMeasurement = undefined
      this.measures = this.emptyMeasures()
      this.syncComposition()
    }
  }

  /** 用真实记录重算周/月/年三段趋势，并刷新区间文案与折线。 */
  private applyTrends(records: WeightRecord[], weekStart: WeekStart): void {
    const now: number = Date.now()
    const week: BodyTrend | undefined = BodyRecordService.weekTrend(records, now, weekStart)
    if (week !== undefined) {
      this.weekSeries = { vals: week.values, labels: week.labels, prefix: week.rangeText, deltaKg: week.deltaKg }
    }
    const month: BodyTrend | undefined = BodyRecordService.monthTrend(records, now)
    if (month !== undefined) {
      this.monthSeries = { vals: month.values, labels: month.labels, prefix: month.rangeText, deltaKg: month.deltaKg }
    }
    const year: BodyTrend | undefined = BodyRecordService.yearTrend(records, now)
    if (year !== undefined) {
      this.yearSeries = { vals: year.values, labels: year.labels, prefix: year.rangeText, deltaKg: year.deltaKg }
    }
    this.trendCap = this.trendCapText(this.getTrendSeries(this.period))
    this.drawTrendChart()
  }

  private contextOrNull(): Context | null {
    const host: Context | undefined = this.getUIContext().getHostContext()
    if (host === undefined) {
      return null
    }
    return host
  }

  /** 读取「设置 · 体重单位」与身体档案（身高/性别/出生年）：只刷新展示层，kg 基准值不变。 */
  private async loadDisplayUnit(): Promise<void> {
    const context: Context | null = this.contextOrNull()
    if (context === null) {
      return
    }
    try {
      const profile: UserProfile = await UserProfileService.loadProfile(context)
      this.displayUnit = profile.weightUnit
      this.profileHeightCm = profile.heightCm
      this.profileGender = profile.gender
      this.profileBirthYear = profile.birthYear
      this.heightInput = profile.heightCm > 0 ? String(profile.heightCm) : ''
      this.birthYearInput = profile.birthYear > 0 ? String(profile.birthYear) : ''
      this.genderSelect = profile.gender
      this.syncComposition()
      this.trendCap = this.trendCapText(this.getTrendSeries(this.period))
    } catch (e) {
      // 读取失败时保持 kg 基准显示，不打断页面展示
    }
  }

  /**
   * 原型 .bd-top 的 padding-top: 52 以屏幕顶为原点（已把状态栏含在内）；设备侧页面区本身落在
   * 状态栏之下，若原样使用 52 就与系统避让重复计数，顶栏整体下移一个状态栏高度（实测 39vp）。
   * 口径同 HomeContent / PlansContent / PlanGroupDetailContent / PlanContent。
   */
  private async resolveTopInset(): Promise<void> {
    const hostContext: Context | undefined = this.getUIContext().getHostContext()
    if (hostContext === undefined) {
      return
    }
    try {
      const mainWindow: window.Window = await window.getLastWindow(hostContext)
      const avoidArea: window.AvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      this.topInsetVp = this.getUIContext().px2vp(avoidArea.topRect.height)
    } catch (e) {
      // 取不到安全区时按 0 处理，顶距回退为原型的 52vp
      this.topInsetVp = 0
    }
  }

  @State private metrics: BodyMetricTile[] = emptyMetricTiles()
  /** 上一档测量记录（围度 delta 用）；无记录为 undefined。 */
  private previousMeasurement: BodyMeasurement | undefined = undefined

  /** 派生体成分四项：BMI/基础代谢由公式，骨骼肌/身体水分取最新录入读数；不可得时 value='--' 且注解留空。 */
  private syncComposition(): void {
    this.metrics = this.buildMetrics()
    this.syncBodyFat()
  }

  private buildMetrics(): BodyMetricTile[] {
    const latest: BodyMeasurement | undefined = this.latestMeasurement
    const bmi: number | undefined = computeBmi(this.currentWeightKg, this.profileHeightCm)
    let bmiValue: string = '--'
    let bmiNote: string = ''
    if (bmi !== undefined) {
      bmiValue = String(bmi)
      bmiNote = bmiCategoryLabel(bmiCategory(bmi))
    }
    const age: number = ageFromBirthYear(this.profileBirthYear, Date.now())
    const bmr: number | undefined =
      basalMetabolicRate(this.currentWeightKg, this.profileHeightCm, age, this.profileGender)
    const bmrValue: string = bmr !== undefined ? String(bmr) : '--'
    let muscleValue: string = '--'
    let muscleUnit: string = ''
    if (latest !== undefined && latest.skeletalMuscleKg !== MEASUREMENT_UNSET) {
      muscleValue = formatWeight(latest.skeletalMuscleKg, this.displayUnit)
      muscleUnit = weightUnitLabel(this.displayUnit)
    }
    let waterValue: string = '--'
    if (latest !== undefined && latest.bodyWaterPercent !== MEASUREMENT_UNSET) {
      waterValue = this.trimNumber(latest.bodyWaterPercent)
    }
    return [
      createMetricTile('BMI', bmiValue, '', bmiNote, false),
      createMetricTile('骨骼肌', muscleValue, muscleUnit, '', true),
      createMetricTile('基础代谢', bmrValue, bmr !== undefined ? 'kcal' : '', bmr !== undefined ? '估算值' : '', true),
      createMetricTile('身体水分', waterValue, waterValue !== '--' ? '%' : '', '', false)
    ]
  }

  /** 体脂率展示值与旁注：按性别生成健康区间；未录读数显 '--'，未填性别旁注只留「体脂率」。 */
  private syncBodyFat(): void {
    const latest: BodyMeasurement | undefined = this.latestMeasurement
    if (latest !== undefined && latest.bodyFatPercent !== MEASUREMENT_UNSET) {
      this.bodyFatValue = this.trimNumber(latest.bodyFatPercent)
    } else {
      this.bodyFatValue = '--'
    }
    const range: BodyFatRange | undefined = bodyFatHealthyRange(this.profileGender)
    if (range === undefined) {
      this.bodyFatNote = '体脂率'
    } else {
      this.bodyFatNote = '体脂率 · 健康区间 ' + range.low + '–' + range.high + '%'
    }
  }

  /** 围度五行：由最新/上一档记录填充，delta 用 measurementDelta；未录项 value='--' 且不显示 delta。 */
  private buildMeasures(): MeasureRow[] {
    const latest: BodyMeasurement | undefined = this.latestMeasurement
    const prev: BodyMeasurement | undefined = this.previousMeasurement
    return [
      this.measureRow('胸围', latest !== undefined ? latest.chestCm : MEASUREMENT_UNSET,
        prev !== undefined ? prev.chestCm : MEASUREMENT_UNSET),
      this.measureRow('腰围', latest !== undefined ? latest.waistCm : MEASUREMENT_UNSET,
        prev !== undefined ? prev.waistCm : MEASUREMENT_UNSET),
      this.measureRow('臀围', latest !== undefined ? latest.hipCm : MEASUREMENT_UNSET,
        prev !== undefined ? prev.hipCm : MEASUREMENT_UNSET),
      this.measureRow('臂围', latest !== undefined ? latest.armCm : MEASUREMENT_UNSET,
        prev !== undefined ? prev.armCm : MEASUREMENT_UNSET),
      this.measureRow('大腿围', latest !== undefined ? latest.thighCm : MEASUREMENT_UNSET,
        prev !== undefined ? prev.thighCm : MEASUREMENT_UNSET)
    ]
  }

  private measureRow(label: string, current: number, previous: number): MeasureRow {
    if (current === MEASUREMENT_UNSET) {
      return createMeasure(label, '--', '', false)
    }
    const value: string = this.trimNumber(current) + ' cm'
    const diff: number | undefined = measurementDelta(current, previous, MEASUREMENT_UNSET)
    if (diff === undefined) {
      return createMeasure(label, value, '', false)
    }
    const text: string = (diff < 0 ? '−' : '+') + this.trimNumber(Math.abs(diff))
    return createMeasure(label, value, text, diff < 0)
  }

  /** 围度卡空态：五项全未录。 */
  private emptyMeasures(): MeasureRow[] {
    return emptyMeasureRows()
  }

  /** 数值展示：整数不带小数点，小数最多一位。 */
  private trimNumber(value: number): string {
    if (Number.isInteger(value)) {
      return String(value)
    }
    return String(Math.round(value * 10) / 10)
  }

  @State private measures: MeasureRow[] = emptyMeasureRows()

  private readonly trendX: number[] = [20, 68, 115, 163, 210, 258, 305]

  // 趋势序列：有真实体重记录时由 [applyTrends] 覆盖；无记录时保持空态（全零平线，不回落样例值）。
  @State private weekSeries: TrendSeries = {
    vals: [0, 0, 0, 0, 0, 0, 0],
    labels: ['', '', '', '', '', '', ''],
    prefix: '',
    deltaKg: 0
  }

  @State private monthSeries: TrendSeries = {
    vals: [0, 0, 0, 0, 0, 0, 0],
    labels: ['', '', '', '', '', '', ''],
    prefix: '',
    deltaKg: 0
  }

  @State private yearSeries: TrendSeries = {
    vals: [0, 0, 0, 0, 0, 0, 0],
    labels: ['', '', '', '', '', '', ''],
    prefix: '',
    deltaKg: 0
  }

  private trendSettings: RenderingContextSettings = new RenderingContextSettings(true)
  private trendContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.trendSettings)

  private handleBack(): void {
    this.getUIContext().getRouter().back()
  }

  private openSheet(): void {
    this.sheetTab = 'weight'
    this.weightInput = this.hasWeight ? formatWeight(this.currentWeightKg, this.displayUnit) : ''
    this.sheetHint = ''
    this.sheetOpen = true
  }

  private closeSheet(): void {
    this.sheetOpen = false
    this.sheetHint = ''
  }

  /** 切换记录面板档位（体重 / 围度与体成分 / 身体档案），清空上一档的校验提示。 */
  private switchSheetTab(tab: string): void {
    this.sheetTab = tab
    this.sheetHint = ''
  }

  private async saveWeight(): Promise<void> {
    const parsed: number = Number(this.weightInput)
    const kg: number = displayToKg(parsed, this.displayUnit)
    if (this.weightInput.length === 0 || Number.isNaN(parsed) || parsed <= 0 || kg > 500) {
      this.sheetHint = '请输入 0–500 之间的有效体重'
      shakeField(this.getUIContext(), (value: number) => {
        this.shakeOffset = value
      })
      return
    }
    this.currentWeightKg = kg
    this.hasWeight = true
    this.closeSheet()
    // 落盘（同一自然日覆盖）后重算趋势。
    const context: Context | null = this.contextOrNull()
    if (context === null) {
      return
    }
    await BodyRecordService.addRecord(context, { dateMillis: Date.now(), kg: kg })
    await this.loadBodyRecords()
  }

  /** 解析围度/体成分输入：空串或非法 → MEASUREMENT_UNSET（本次不录），否则为数值。 */
  private parseMeasureInput(text: string): number {
    if (text.length === 0) {
      return MEASUREMENT_UNSET
    }
    const value: number = Number(text)
    if (Number.isNaN(value) || value < 0) {
      return MEASUREMENT_UNSET
    }
    return value
  }

  /** 保存围度与体成分录入（同日逐项合并），随后重读刷新围度卡与体成分卡。 */
  private async saveMeasurement(): Promise<void> {
    const context: Context | null = this.contextOrNull()
    if (context === null) {
      return
    }
    const record: BodyMeasurement = {
      dateMillis: Date.now(),
      chestCm: this.parseMeasureInput(this.chestInput),
      waistCm: this.parseMeasureInput(this.waistInput),
      hipCm: this.parseMeasureInput(this.hipInput),
      armCm: this.parseMeasureInput(this.armInput),
      thighCm: this.parseMeasureInput(this.thighInput),
      bodyFatPercent: this.parseMeasureInput(this.fatInput),
      skeletalMuscleKg: this.parseMeasureInput(this.muscleInput),
      bodyWaterPercent: this.parseMeasureInput(this.waterInput)
    }
    await BodyMeasurementService.addMeasurement(context, record)
    this.chestInput = ''
    this.waistInput = ''
    this.hipInput = ''
    this.armInput = ''
    this.thighInput = ''
    this.fatInput = ''
    this.muscleInput = ''
    this.waterInput = ''
    this.closeSheet()
    await this.loadMeasurementRecords()
  }

  /** 保存身体档案（身高/性别/出生年），随后重派生 BMI 与基础代谢。 */
  private async saveBodyProfile(): Promise<void> {
    const context: Context | null = this.contextOrNull()
    if (context === null) {
      return
    }
    const heightCm: number = this.heightInput.length > 0 ? Number(this.heightInput) : 0
    const birthYear: number = this.birthYearInput.length > 0 ? Number(this.birthYearInput) : 0
    if (!Number.isFinite(heightCm) || !Number.isFinite(birthYear)) {
      this.sheetHint = '请输入有效的身高与出生年份'
      return
    }
    this.profileHeightCm = heightCm
    this.profileGender = this.genderSelect
    this.profileBirthYear = birthYear
    this.closeSheet()
    await UserProfileService.saveBodyProfile(context, heightCm, this.genderSelect, birthYear)
    this.syncComposition()
  }

  private deltaText(deltaKg: number): string {
    const magnitude: string = formatWeight(Math.abs(deltaKg), this.displayUnit)
    if (deltaKg < 0) {
      return '−' + magnitude + ' ' + weightUnitLabel(this.displayUnit)
    }
    return '+' + magnitude + ' ' + weightUnitLabel(this.displayUnit)
  }

  private trendCapText(series: TrendSeries): string {
    if (series.prefix.length === 0) {
      return ''
    }
    return series.prefix + ' · ' + this.deltaText(series.deltaKg)
  }

  private getTrendSeries(key: string): TrendSeries {
    if (key === 'month') {
      return this.monthSeries
    }
    if (key === 'year') {
      return this.yearSeries
    }
    return this.weekSeries
  }

  private selectPeriod(key: string): void {
    this.period = key
    this.trendCap = this.trendCapText(this.getTrendSeries(key))
    this.drawTrendChart()
  }

  private drawTrendChart(): void {
    const ctx: CanvasRenderingContext2D = this.trendContext
    const width: number = ctx.width
    const height: number = ctx.height
    if (width <= 0 || height <= 0) {
      return
    }
    const s: TrendSeries = this.getTrendSeries(this.period)
    ctx.clearRect(0, 0, width, height)
    const scaleX: number = width / 326
    const scaleY: number = height / 140
    ctx.save()
    ctx.scale(scaleX, scaleY)

    ctx.strokeStyle = 'rgba(255,255,255,0.06)'
    ctx.lineWidth = 1
    ctx.beginPath()
    ctx.moveTo(20, 20)
    ctx.lineTo(305, 20)
    ctx.stroke()

    ctx.strokeStyle = 'rgba(255,255,255,0.10)'
    ctx.beginPath()
    ctx.moveTo(20, 100)
    ctx.lineTo(305, 100)
    ctx.stroke()

    let lo: number = s.vals[0]
    let hi: number = s.vals[0]
    for (let i = 1; i < s.vals.length; i++) {
      if (s.vals[i] < lo) {
        lo = s.vals[i]
      }
      if (s.vals[i] > hi) {
        hi = s.vals[i]
      }
    }
    const span: number = hi - lo
    const pointsY: number[] = []
    for (let i = 0; i < s.vals.length; i++) {
      const ratio: number = span > 0 ? (s.vals[i] - lo) / span : 0.5
      pointsY.push(100 - ratio * (100 - 18))
    }

    const gradient: CanvasGradient = ctx.createLinearGradient(0, 0, 0, 140)
    gradient.addColorStop(0, 'rgba(80,236,167,0.18)')
    gradient.addColorStop(1, 'rgba(80,236,167,0)')
    ctx.fillStyle = gradient
    ctx.beginPath()
    ctx.moveTo(this.trendX[0], 112)
    for (let i = 0; i < this.trendX.length; i++) {
      ctx.lineTo(this.trendX[i], pointsY[i])
    }
    ctx.lineTo(this.trendX[this.trendX.length - 1], 112)
    ctx.closePath()
    ctx.fill()

    ctx.strokeStyle = '#50ECA7'
    ctx.lineWidth = 2
    ctx.lineCap = 'round'
    ctx.lineJoin = 'round'
    ctx.beginPath()
    ctx.moveTo(this.trendX[0], pointsY[0])
    for (let i = 1; i < this.trendX.length; i++) {
      ctx.lineTo(this.trendX[i], pointsY[i])
    }
    ctx.stroke()

    for (let i = 0; i < this.trendX.length; i++) {
      const isLast: boolean = i === this.trendX.length - 1
      const radius: number = isLast ? 4.5 : 3
      ctx.beginPath()
      ctx.arc(this.trendX[i], pointsY[i], radius, 0, Math.PI * 2)
      ctx.fillStyle = isLast ? '#50ECA7' : '#0B0F13'
      ctx.fill()
      ctx.strokeStyle = '#50ECA7'
      ctx.lineWidth = 1.5
      ctx.stroke()
    }

    ctx.fillStyle = 'rgba(255,255,255,0.5)'
    ctx.font = '9px Inter'
    ctx.textAlign = 'center'
    for (let i = 0; i < s.labels.length; i++) {
      if (s.labels[i].length > 0) {
        ctx.fillText(s.labels[i], this.trendX[i], 126)
      }
    }

    ctx.restore()
  }

  private sheetTitle(): string {
    if (this.sheetTab === 'measure') {
      return '记录围度与体成分'
    }
    if (this.sheetTab === 'profile') {
      return '身体档案'
    }
    return '记录今日体重'
  }

  private sheetSubtitle(): string {
    if (this.sheetTab === 'measure') {
      return '留空的项本次不记录，已录的读数会保留'
    }
    if (this.sheetTab === 'profile') {
      return '用于派生 BMI 与基础代谢'
    }
    return '每次记录都会被纳入体重趋势'
  }

  @Builder
  private sheetTabButton(label: string, key: string) {
    Button(label)
      .height(30)
      .padding({ left: 12, right: 12 })
      .fontFamily('Noto Sans SC')
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.sheetTab === key ? '#07100B' : '#9EFFFFFF')
      .backgroundColor(this.sheetTab === key ? '#50ECA7' : Color.Transparent)
      .borderRadius(9)
      .animation({ duration: MotionTokens.DURATION_COLOR_FAST, curve: MotionTokens.EASE_MOTION })
      .onClick(() => {
        this.switchSheetTab(key)
      })
  }

  @Builder
  private measureField(label: string, value: string, unit: string, onChange: (value: string) => void) {
    Row() {
      Text(label)
        .fontFamily('Noto Sans SC')
        .fontSize(13)
        .fontColor('#B3FFFFFF')
      Blank()
      TextInput({ text: value, placeholder: '—' })
        .type(InputType.NUMBER_DECIMAL)
        .fontFamily('Inter')
        .fontSize(15)
        .fontColor('#F7FBF8')
        .placeholderColor('#52FFFFFF')
        .backgroundColor(Color.Transparent)
        .borderRadius(0)
        .width(96)
        .padding(0)
        .textAlign(TextAlign.End)
        .onChange((next: string) => {
          onChange(next)
        })
      Text(unit)
        .fontFamily('Inter')
        .fontSize(12)
        .fontColor('#9EFFFFFF')
        .width(24)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .height(48)
    .padding({ left: 14, right: 14 })
    .backgroundColor('#0FFFFFFF')
    .border({ width: 1, color: '#14FFFFFF' })
    .borderRadius(14)
  }

  @Builder
  private genderButton(label: string, value: Gender) {
    Button(label)
      .height(30)
      .padding({ left: 16, right: 16 })
      .fontFamily('Noto Sans SC')
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.genderSelect === value ? '#07100B' : '#B3FFFFFF')
      .backgroundColor(this.genderSelect === value ? '#50ECA7' : '#0FFFFFFF')
      .border({ width: 1, color: this.genderSelect === value ? '#50ECA7' : '#14FFFFFF' })
      .borderRadius(10)
      .onClick(() => {
        this.genderSelect = value
      })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 180, colors: [['#0B0F13', 0], ['#0A0D12', 1]] })

      Column() {
        Row({ space: 10 }) {
          Row() {
            Image($rawfile('pencil-plan-nav-chevron-left.svg'))
              .width(20)
              .height(20)
              .opacity(0.7)
          }
          .width(44)
            .height(44)
            .borderRadius(22)
            .backgroundColor('#0CFFFFFF')
            .border({ width: 1, color: '#14FFFFFF' })
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .scale({ x: this.backPressed ? MotionTokens.PRESS_BACK : 1, y: this.backPressed ? MotionTokens.PRESS_BACK : 1 })
            .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.backPressed = true
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.backPressed = false
              }
            })
            .onClick(() => {
              this.handleBack()
            })
          Text('身体数据')
            .fontFamily('Noto Sans SC')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F7FBF8')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Column() {
            Text(this.headerDay)
              .fontFamily('Inter')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#B3FFFFFF')
              .lineHeight(13)
            Text(this.headerMonth)
              .fontFamily('Noto Sans SC')
              .fontSize(11)
              .fontColor('#8AFFFFFF')
              .lineHeight(11)
              .margin({ top: 2 })
          }
          .width(44)
          .alignItems(HorizontalAlign.Center)
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        // 原型以屏幕顶为原点；设备页面区已在状态栏下方，扣掉状态栏高度才是与原型一致的 52vp 顶距。
        .padding({ top: Math.max(52 - this.topInsetVp, 0), bottom: 12, left: 16, right: 16 })
        .alignItems(VerticalAlign.Center)

        Scroll() {
          Column({ space: 14 }) {
            this.weightSummaryCard()
            this.compositionCard()
            this.trendCard()
            this.measurementsCard()

            Button('记录今日体重')
              .width('100%')
              .height(54)
              .padding(0)
              .fontFamily('Noto Sans SC')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#07100B')
              .backgroundColor('#50ECA7')
              .borderRadius(17)
              .shadow({ radius: 28, color: '#52000000', offsetX: 0, offsetY: 12 })
              .scale({ x: this.ctaPressed ? MotionTokens.PRESS_SHORTCUT : 1, y: this.ctaPressed ? MotionTokens.PRESS_SHORTCUT : 1 })
              .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
              .onTouch((event: TouchEvent) => {
                if (event.type === TouchType.Down) {
                  this.ctaPressed = true
                } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                  this.ctaPressed = false
                }
              })
              .onClick(() => {
                this.openSheet()
              })

            Text('身体数据仅保存在本机；单位可在「设置」中切换为磅（lbs）。本页数值为界面示例，用于展示信息层级与交互。')
              .fontFamily('Noto Sans SC')
              .fontSize(11)
              .fontColor('#66FFFFFF')
              .lineHeight(18)
              .padding({ left: 4, right: 4 })
              .width('100%')
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 6, bottom: 30 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')

      if (this.sheetOpen) {
        Column() {
          Blank()
            .width('100%')
            .layoutWeight(1)
            .onClick(() => {
              this.closeSheet()
            })
          Column() {
            Row()
              .width(40)
              .height(4)
              .borderRadius(999)
              .backgroundColor('#52FFFFFF')
            Text(this.sheetTitle())
              .fontFamily('Noto Sans SC')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F7FBF8')
              .textAlign(TextAlign.Center)
              .width('100%')
              .margin({ top: 18 })
            Text(this.sheetSubtitle())
              .fontFamily('Noto Sans SC')
              .fontSize(12)
              .fontColor('#8AFFFFFF')
              .textAlign(TextAlign.Center)
              .width('100%')
              .margin({ top: 5 })
            Row({ space: 8 }) {
              this.sheetTabButton('体重', 'weight')
              this.sheetTabButton('围度与体成分', 'measure')
              this.sheetTabButton('身体档案', 'profile')
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .margin({ top: 16 })

            if (this.sheetTab === 'weight') {
              Row({ space: 8 }) {
                TextInput({ text: this.weightInput, placeholder: '—' })
                  .type(InputType.NUMBER_DECIMAL)
                  .fontFamily('Inter')
                  .fontSize(40)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#F7FBF8')
                  .placeholderColor('#52FFFFFF')
                  .backgroundColor(this.sheetHint.length > 0 ? ColorTokens.FIELD_ERROR_FILL : '#0FFFFFFF')
                  .border({ width: 1, color: this.sheetHint.length > 0 ? ColorTokens.FIELD_ERROR_BORDER : '#14FFFFFF' })
                  .borderRadius(18)
                  .width(140)
                  .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                  .textAlign(TextAlign.Center)
                  .translate({ x: this.shakeOffset })
                  .onChange((value: string) => {
                    this.weightInput = value
                    if (this.sheetHint.length > 0) {
                      this.sheetHint = ''
                    }
                  })
                Text(weightUnitLabel(this.displayUnit))
                  .fontFamily('Inter')
                  .fontSize(16)
                  .fontColor('#9EFFFFFF')
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .margin({ top: 20 })
            } else if (this.sheetTab === 'measure') {
              Column({ space: 10 }) {
                this.measureField('胸围', this.chestInput, 'cm', (value: string) => {
                  this.chestInput = value
                  if (this.sheetHint.length > 0) {
                    this.sheetHint = ''
                  }
                })
                this.measureField('腰围', this.waistInput, 'cm', (value: string) => {
                  this.waistInput = value
                  if (this.sheetHint.length > 0) {
                    this.sheetHint = ''
                  }
                })
                this.measureField('臀围', this.hipInput, 'cm', (value: string) => {
                  this.hipInput = value
                  if (this.sheetHint.length > 0) {
                    this.sheetHint = ''
                  }
                })
                this.measureField('臂围', this.armInput, 'cm', (value: string) => {
                  this.armInput = value
                  if (this.sheetHint.length > 0) {
                    this.sheetHint = ''
                  }
                })
                this.measureField('大腿围', this.thighInput, 'cm', (value: string) => {
                  this.thighInput = value
                  if (this.sheetHint.length > 0) {
                    this.sheetHint = ''
                  }
                })
                this.measureField('体脂率', this.fatInput, '%', (value: string) => {
                  this.fatInput = value
                  if (this.sheetHint.length > 0) {
                    this.sheetHint = ''
                  }
                })
                this.measureField('骨骼肌', this.muscleInput, 'kg', (value: string) => {
                  this.muscleInput = value
                  if (this.sheetHint.length > 0) {
                    this.sheetHint = ''
                  }
                })
                this.measureField('身体水分', this.waterInput, '%', (value: string) => {
                  this.waterInput = value
                  if (this.sheetHint.length > 0) {
                    this.sheetHint = ''
                  }
                })
              }
              .width('100%')
              .margin({ top: 18 })
            } else {
              Column({ space: 10 }) {
                this.measureField('身高', this.heightInput, 'cm', (value: string) => {
                  this.heightInput = value
                  if (this.sheetHint.length > 0) {
                    this.sheetHint = ''
                  }
                })
                this.measureField('出生年份', this.birthYearInput, '', (value: string) => {
                  this.birthYearInput = value
                  if (this.sheetHint.length > 0) {
                    this.sheetHint = ''
                  }
                })
                Row() {
                  Text('性别')
                    .fontFamily('Noto Sans SC')
                    .fontSize(13)
                    .fontColor('#B3FFFFFF')
                  Blank()
                  Row({ space: 8 }) {
                    this.genderButton('男', 'male')
                    this.genderButton('女', 'female')
                  }
                }
                .width('100%')
                .height(48)
                .padding({ left: 14, right: 14 })
                .backgroundColor('#0FFFFFFF')
                .border({ width: 1, color: '#14FFFFFF' })
                .borderRadius(14)
              }
              .width('100%')
              .margin({ top: 18 })
            }

            Text(this.sheetHint)
              .fontFamily('Noto Sans SC')
              .fontSize(11.5)
              .fontColor(this.sheetHint.length > 0 ? ColorTokens.FIELD_ERROR_TEXT : '#50ECA7')
              .textAlign(TextAlign.Center)
              .width('100%')
              .height(16)
              .margin({ top: 14 })
            Row({ space: 10 }) {
              Button('取消')
                .layoutWeight(1)
                .height(50)
                .padding(0)
                .fontFamily('Noto Sans SC')
                .fontSize(14.5)
                .fontWeight(FontWeight.Medium)
                .fontColor('#B3FFFFFF')
                .backgroundColor('#0FFFFFFF')
                .border({ width: 1, color: '#14FFFFFF' })
                .borderRadius(16)
                .onClick(() => {
                  this.closeSheet()
                })
              Button('保存')
                .layoutWeight(1)
                .height(50)
                .padding(0)
                .fontFamily('Noto Sans SC')
                .fontSize(14.5)
                .fontWeight(FontWeight.Medium)
                .fontColor('#07100B')
                .backgroundColor('#50ECA7')
                .borderRadius(16)
                .onClick(() => {
                  if (this.sheetTab === 'weight') {
                    this.saveWeight()
                  } else if (this.sheetTab === 'measure') {
                    this.saveMeasurement()
                  } else {
                    this.saveBodyProfile()
                  }
                })
            }
            .width('100%')
            .margin({ top: 20 })
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 12, bottom: 30 })
          .backgroundColor('#0A0D12')
          .border({ width: { top: 1 }, color: '#1AFFFFFF' })
          .borderRadius({ topLeft: 28, topRight: 28 })
          .shadow({ radius: 60, color: '#73000000', offsetX: 0, offsetY: -24 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#80000000')
        .transition(TransitionEffect.OPACITY.animation({ duration: MotionTokens.DURATION_OVERLAY, curve: MotionTokens.EASE_MOTION }))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0B0F13')
  }

  @Builder
  private weightSummaryCard() {
    Column() {
      Row() {
        Text('当前体重')
          .fontFamily('Noto Sans SC')
          .fontSize(12)
          .fontColor('#9EFFFFFF')
        Text('今日 · 更新于 07:40')
          .fontFamily('Inter')
          .fontSize(11)
          .fontColor('#8AFFFFFF')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Row({ space: 7 }) {
        Text(this.hasWeight ? formatWeight(this.currentWeightKg, this.displayUnit) : '--')
          .fontFamily('Inter')
          .fontSize(56)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
          .letterSpacing(-1.1)
          .margin({ top: 10 })
        if (this.hasWeight) {
          Text(weightUnitLabel(this.displayUnit))
            .fontFamily('Inter')
            .fontSize(16)
            .fontColor('#9EFFFFFF')
            .margin({ top: 10 })
        }
      }
      .width('100%')

      if (this.hasWeight && this.weekSeries.prefix.length > 0) {
        Row({ space: 5 }) {
          Image($rawfile('pencil-body-arrow-down.svg'))
            .width(15)
            .height(15)
          Text('较上周 ' + this.deltaText(this.weekSeries.deltaKg))
            .fontFamily('Noto Sans SC')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#50ECA7')
        }
        .padding({ left: 11, right: 11, top: 5, bottom: 5 })
        .backgroundColor('#1A50ECA7')
        .borderRadius(999)
        .margin({ top: 12 })
      }

      Row()
        .width('100%')
        .height(1)
        .backgroundColor('#0FFFFFFF')
        .margin({ top: 16 })

      Row() {
        Text('增肌目标 ' + formatWeight(74.0, this.displayUnit) + ' ' + weightUnitLabel(this.displayUnit))
          .fontFamily('Noto Sans SC')
          .fontSize(12)
          .fontColor('#9EFFFFFF')
        Text('还差 ' + formatWeight(1.5, this.displayUnit) + ' ' + weightUnitLabel(this.displayUnit))
          .fontFamily('Inter')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F7FBF8')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 15 })

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(7)
          .backgroundColor('#14FFFFFF')
          .borderRadius(999)
        Row()
          .width('98%')
          .height(7)
          .backgroundColor('#50ECA7')
          .borderRadius(999)
          .animation({ duration: MotionTokens.DURATION_PROGRESS, curve: MotionTokens.EASE_PANEL })
      }
      .width('100%')
      .height(7)
      .margin({ top: 10 })
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#0F50ECA7')
    .border({ width: 1, color: '#3850ECA7' })
    .borderRadius(26)
    .shadow({ radius: 40, color: '#38000000', offsetX: 0, offsetY: 20 })
  }

  @Builder
  private compositionCard() {
    Column() {
      Row() {
        Text('身体成分')
          .fontFamily('Noto Sans SC')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text('目标 · 增肌')
          .fontFamily('Noto Sans SC')
          .fontSize(11)
          .fontColor('#9EFFFFFF')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Row() {
        Row({ space: 0 }) {
          Text(this.bodyFatValue)
            .fontFamily('Inter')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#50ECA7')
          if (this.bodyFatValue !== '--') {
            Text('%')
              .fontFamily('Inter')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#9EFFFFFF')
          }
        }
        .alignItems(VerticalAlign.Bottom)
        Blank()
        Text(this.bodyFatNote)
          .fontFamily('Noto Sans SC')
          .fontSize(11)
          .fontColor('#9EFFFFFF')
      }
      .width('100%')
      .margin({ top: 14, bottom: 8 })

      Stack({ alignContent: Alignment.TopStart }) {
        Row()
          .width('100%')
          .height(8)
          .backgroundColor('#14FFFFFF')
          .borderRadius(999)
          .position({ x: 0, y: 11 })
        Row()
          .width('50%')
          .height(8)
          .backgroundColor('#3350ECA7')
          .borderRadius(999)
          .position({ x: 82, y: 11 })
        Row()
          .width(20)
          .height(20)
          .borderRadius(10)
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: '#8050ECA7' })
          .position({ x: 173, y: 5 })
        Row()
          .width(18)
          .height(18)
          .borderRadius(9)
          .backgroundColor('#50ECA7')
          .border({ width: 3, color: '#0B0F13' })
          .position({ x: 174, y: 6 })
      }
      .width('100%')
      .height(30)
      .margin({ top: 8 })

      Row() {
        Text('偏低')
          .fontFamily('Inter')
          .fontSize(10)
          .fontColor('#66FFFFFF')
        Text('健康')
          .fontFamily('Inter')
          .fontSize(10)
          .fontColor('#66FFFFFF')
        Text('偏高')
          .fontFamily('Inter')
          .fontSize(10)
          .fontColor('#66FFFFFF')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 4 })

      Grid() {
        ForEach(this.metrics, (tile: BodyMetricTile) => {
          GridItem() {
            Column() {
              Text(tile.label)
                .fontFamily('Noto Sans SC')
                .fontSize(11.5)
                .fontColor('#9EFFFFFF')
              Row({ space: 3 }) {
                Text(tile.value)
                  .fontFamily('Inter')
                  .fontSize(21)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#F7FBF8')
                if (tile.unit.length > 0) {
                  Text(tile.unit)
                    .fontFamily('Inter')
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#9EFFFFFF')
                }
              }
              .margin({ top: 7 })
              Text(tile.note)
                .fontFamily('Noto Sans SC')
                .fontSize(10.5)
                .fontColor(tile.noteMuted ? '#66FFFFFF' : '#50ECA7')
                .margin({ top: 6 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ top: 13, bottom: 13, left: 14, right: 14 })
            .backgroundColor('#06FFFFFF')
            .border({ width: 1, color: '#0FFFFFFF' })
            .borderRadius(16)
          }
        }, (tile: BodyMetricTile) => tile.label + tile.unit)
      }
      .columnsTemplate('1fr 1fr')
      .columnsGap(10)
      .rowsGap(10)
      .width('100%')
      .margin({ top: 16 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#08FFFFFF')
    .border({ width: 1, color: '#1AFFFFFF' })
    .borderRadius(22)
  }

  @Builder
  private trendCard() {
    Column() {
      Row() {
        Column() {
          Text('体重趋势')
            .fontFamily('Noto Sans SC')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F7FBF8')
          Text(this.trendCap)
            .fontFamily('Inter')
            .fontSize(11)
            .fontColor('#8AFFFFFF')
            .margin({ top: 3 })
        }
        Row({ space: 2 }) {
          this.periodButton('周', 'week')
          this.periodButton('月', 'month')
          this.periodButton('年', 'year')
        }
        .padding(3)
        .backgroundColor('#0FFFFFFF')
        .border({ width: 1, color: '#1AFFFFFF' })
        .borderRadius(12)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: 14 })

      Canvas(this.trendContext)
        .width('100%')
        .aspectRatio(326 / 140)
        .margin({ top: 4 })
        .onReady(() => {
          this.drawTrendChart()
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#08FFFFFF')
    .border({ width: 1, color: '#1AFFFFFF' })
    .borderRadius(22)
  }

  @Builder
  private periodButton(label: string, key: string) {
    Button(label)
      .height(30)
      .padding({ left: 14, right: 14 })
      .fontFamily('Noto Sans SC')
      .fontSize(12.5)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.period === key ? '#07100B' : '#9EFFFFFF')
      .backgroundColor(this.period === key ? '#50ECA7' : Color.Transparent)
      .borderRadius(9)
      .animation({ duration: MotionTokens.DURATION_COLOR_FAST, curve: MotionTokens.EASE_MOTION })
      .onClick(() => {
        this.selectPeriod(key)
      })
  }

  @Builder
  private measurementsCard() {
    Column() {
      Row() {
        Text('围度记录')
          .fontFamily('Noto Sans SC')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text('较上月')
          .fontFamily('Noto Sans SC')
          .fontSize(11)
          .fontColor('#9EFFFFFF')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: 14 })

      ForEach(this.measures, (row: MeasureRow, index: number) => {
        Row() {
          Text(row.label)
            .fontFamily('Noto Sans SC')
            .fontSize(13.5)
            .fontColor('#B3FFFFFF')
          Blank()
          Text(row.value)
            .fontFamily('Inter')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#F7FBF8')
          Text(row.delta)
            .fontFamily('Inter')
            .fontSize(11.5)
            .fontColor(row.deltaDown ? '#8AFFFFFF' : '#50ECA7')
            .width(44)
            .textAlign(TextAlign.End)
        }
        .width('100%')
        .padding({ top: 13, bottom: 13 })
        .border({ width: { top: index === 0 ? 0 : 1 }, color: '#0FFFFFFF' })
      }, (row: MeasureRow) => row.label)
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#08FFFFFF')
    .border({ width: 1, color: '#1AFFFFFF' })
    .borderRadius(22)
  }
}
