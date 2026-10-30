/** ActiveContent - 训练中界面体（供 PencilActivePage 独立渲染）。 */
import { AppRoutes } from '../../../app/AppRoutes'
import { Context } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { MediaTokens, MotionTokens } from '../../../common/styles/DesignTokens'
import { MotionIntent } from '../../../common/styles/MotionIntent'
import { DuTokens } from '../../../common/styles/DuTokens'
import { ExerciseDemoImage } from '../../../components/ExerciseDemoImage'
import { WorkoutSession } from '../../../shared/models/TrainingModels'
import WorkoutRepository from '../../../shared/services/WorkoutRepository'
import ExerciseGifCatalog from '../../../shared/services/ExerciseGifCatalog'
import ActiveWorkoutService, {
  ActiveWorkoutExercise,
  ActiveWorkoutSetEntry,
  ActiveWorkoutState
} from '../../../shared/services/ActiveWorkoutService'
import WorkoutDraftService, {
  hasWorkoutDraftProgress,
  WorkoutDraftSnapshot
} from '../../../common/services/WorkoutDraftService'
import {
  fromWorkoutDraft,
  toWorkoutDraft
} from '../../../shared/services/ActiveWorkoutDraftMapper'
import { WorkoutPreviewSummary } from '../../../shared/services/WorkoutPreviewService'
import SettingsService, { AppSettings } from '../../../common/services/SettingsService'
import UserProfileService, { UserProfile, WeightUnit } from '../../../common/services/UserProfileService'
import { kgToDisplay, displayToKg, weightUnitLabel } from '../../../common/utils/WeightUtils'
import HapticFeedbackService from '../../../common/services/HapticFeedbackService'
import { PrototypeTokens } from '../../../common/styles/PrototypeTokens'
import {
  ActiveExerciseRecordGroup,
  ActiveSetRecord,
  buildRecordGroupFor,
  findUnfinishedExerciseIndex
} from './ActiveSetRecordModel'

interface ActiveWorkoutRouteParams {
  preview: WorkoutPreviewSummary
}

interface InitialSetValues {
  weight: number
  reps: number
}

// 组记录按动作分组（见 ActiveSetRecordModel）：分组键是 plannedExerciseId，
// 且记录区只显示「当前动作」那一组——切到下一个动作后，上一动作的组不留在列表里。

// 进度条段数不固定：段数 = 本次训练总组数（跨动作求和，见 ActiveWorkoutService.totalTargetSets），
// 由 @State targetSets 驱动。此前这里是硬编码的 6 段常量，结束判据也压在它上面——
// 于是「做完一个动作的组」就会被当成整场训练做完，后面的动作永远不会出现在训练页。

// 重量步进区间（kg 基准，来自原型 `data-min/max`）；显示时按当前单位换算。
const WEIGHT_MIN_KG: number = 20
const WEIGHT_MAX_KG: number = 200
// 目标次数解析不出时的兜底（原型输入框占位为「8–10」）。
const FALLBACK_REPS: number = 8

// 组胶囊：一个胶囊 = 一组（当前动作的目标组数）。高 26，整行等分铺满。
// 组数多时靠 SET_PILL_MIN_WIDTH 兜底：宽度退到与高度相等（正圆点），不再继续变扁。
const SET_PILL_HEIGHT: number = 26
const SET_PILL_GAP: number = 8
// 取 26（= 高度）而不是 44：360dp 屏、左右 18 内边距、间距 8 时，
// 可用宽 324 只撑得住 6 组每格 47；第 7 组起每格算下来 39，顶穿 44 就溢出，
// 而 39 以下到 26 这一段仍是「格」的形状，25 以下才退化成细缝——所以下限压在 26。
const SET_PILL_MIN_WIDTH: number = 26
// 长按「完成」提前结束：按住多久算数、进度推进的步长（16ms ≈ 一帧）。
const HOLD_DURATION_MS: number = 1200
const HOLD_TICK_MS: number = 16
// 进度超过该比例即视为「已进入长按」：此后松开只取消，不算一次点击（≈180ms）。
// 不区分的话，按住 0.6s 后放弃松开会被当成单击，弹窗会意外弹出来（真机实测过）。
const HOLD_ENGAGE_PROGRESS: number = 0.15
// 本动作录满后的「完成态停留」：让满格胶囊 + dock 的「已完成」先被看见，再翻到下一个动作。
// 取 800 而不是 300（DURATION_MARKER）：300 是动画时长量级，读一个状态词需要更久；
// 也不取 1200（HOLD_DURATION_MS）：那是长按判定阈值，跟可读性无关。
// 这一段落在天然停顿点（该换器械了），不是被牺牲掉的连续记录节奏。
const ADVANCE_HOLD_MS: number = 800

// 动作演示卡（容器）高度。原型 .demo-card 为 230，此处有意加高以留出更多版面；
// 标题条固定在距底 56 处，与原型同口径。
const DEMO_CARD_HEIGHT: number = 280
// 演示图自身尺寸，与容器高度解耦——容器加高时图不跟着放大（素材仅 180×180，
// 放大会变糊）。图在容器内居中。
const DEMO_MEDIA_SIZE: number = 230
// 实拍素材的圆角。实拍照无白底、是矩形实景，须靠圆角收敛；收编到 MediaTokens.RADIUS_INLINE（16），
// 与 demoCard 的标题条一致，不引入新视觉值。
const DEMO_PHOTO_RADIUS: number = MediaTokens.RADIUS_INLINE

interface CelebratePiece {
  id: string
  x: number
  y: number
  width: number
  height: number
  rot: number
  color: string
}

const CELEBRATE_PIECES: CelebratePiece[] = [
  { id: 'cp0', x: 120, y: 220, width: 8, height: 14, rot: 25, color: PrototypeTokens.ACCENT },
  { id: 'cp1', x: 268, y: 212, width: 8, height: 14, rot: -30, color: PrototypeTokens.ACCENT_SOFT },
  { id: 'cp2', x: 300, y: 330, width: 8, height: 14, rot: 15, color: PrototypeTokens.ACCENT_DEEP },
  { id: 'cp3', x: 86, y: 342, width: 8, height: 14, rot: -20, color: PrototypeTokens.TEXT_HI },
  { id: 'cp4', x: 148, y: 432, width: 8, height: 14, rot: 40, color: PrototypeTokens.ACCENT },
  { id: 'cp5', x: 248, y: 444, width: 8, height: 14, rot: -45, color: PrototypeTokens.ACCENT_SOFT },
  { id: 'cp6', x: 187, y: 168, width: 8, height: 14, rot: 12, color: PrototypeTokens.ACCENT_DEEP },
  { id: 'cp7', x: 78, y: 262, width: 8, height: 14, rot: -15, color: PrototypeTokens.TEXT_HI },
  { id: 'cp8', x: 296, y: 258, width: 8, height: 14, rot: 30, color: PrototypeTokens.ACCENT },
  { id: 'cp9', x: 122, y: 186, width: 8, height: 14, rot: -35, color: PrototypeTokens.ACCENT_SOFT },
  { id: 'cp10', x: 254, y: 190, width: 8, height: 14, rot: 20, color: PrototypeTokens.ACCENT_DEEP },
  { id: 'cp11', x: 202, y: 494, width: 8, height: 14, rot: -25, color: PrototypeTokens.TEXT_HI }
]

function formatClock(totalSeconds: number): string {
  const minutes: number = Math.floor(totalSeconds / 60)
  const seconds: number = totalSeconds % 60
  const mm: string = minutes < 10 ? '0' + minutes.toString() : minutes.toString()
  const ss: string = seconds < 10 ? '0' + seconds.toString() : seconds.toString()
  return mm + ':' + ss
}

@Component
export struct ActiveContent {
  @State private completed: number = 0
  @State private weight: number = 0
  @State private reps: number = 0
  @State private exerciseName: string = ''
  @State private exerciseGifSource: string = ExerciseGifCatalog.resolveDemoSource('')
  /**
   * 当前动作是否用的是实拍风格素材（free-exercise-db 实拍照合成）。
   *
   * 两套素材的容器需求不同，故须区分：
   * - 线稿素材已把页底色烘进图里，与页面无缝，加圆角对它是视觉无感的（圆角外即页底色）；
   * - 实拍照是全彩矩形实景、无白底，必须靠圆角卡片收敛，否则在深色页上是一块亮矩形。
   * 演示容器恰为正方形（DEMO_MEDIA_SIZE 230），圆角直接落在 Image 上即可，无需包壳。
   */
  @State private exerciseUsesPhotoStyle: boolean = false
  @State private exerciseIndex: number = 1
  @State private exerciseTotal: number = 0
  /** 本次训练总组数（跨动作求和）：进度条段数、组号文案与收尾判据都以它为准。 */
  @State private targetSets: number = 0
  @State private showModal: boolean = false
  /** 当前动作的组记录（0 或 1 个分组）：页面只显示正在练的动作，历史动作不进列表。 */
  @State private recordGroups: ActiveExerciseRecordGroup[] = []
  @State private celebrating: boolean = false
  @State private elapsedSeconds: number = 0
  @State private submitPressed: boolean = false
  @State private completePressed: boolean = false
  @State private closePressed: boolean = false
  @State private minusPressed: boolean = false
  @State private plusPressed: boolean = false
  @State private livePulseLow: boolean = false
  /** 顶部动作切换条选中的动作下标（0 起）；初值 = 首个未录满动作。 */
  @State private selectedExerciseIndex: number = 0
  @State private collapsePressed: boolean = false
  /** 动作切换弹层开关（点顶栏动作名打开）。 */
  @State private showExercisePicker: boolean = false
  /** 名称滚动替换：0 → -28 旧名上滑淡出；28 → 0 新名升入。 */
  @State private nameShift: number = 0
  @State private nameOpacity: number = 1
  /** 演示卡 Y 轴翻转角（0 → 90 → -90 → 0，中段换内容）。 */
  @State private cardFlipAngle: number = 0
  /** 长按「完成」的进度 0..1 与按住态。 */
  @State private holdProgress: number = 0
  @State private holding: boolean = false
  private holdTimer: number = -1
  private holdTriggered: boolean = false
  /** 已越过「长按判定线」——松开时据此区分「点击」与「按住后放弃」。 */
  private holdEngaged: boolean = false
  /** 挂起的自动前进：-1 表示没有待执行的切换。 */
  private advanceTimer: number = -1
  /** 挂起切换的来源动作 id：回调时用它判断用户是否已手动切走。 */
  private advanceFromId: string = ''
  private celebrateTimer: number = -1
  private clockTimer: number = -1
  private pulseTimer: number = -1
  private finished: boolean = false
  /** 本次退出是否已落过草稿：chevron 与 aboutToDisappear 两处调用靠它幂等。 */
  private draftSavedOnExit: boolean = false
  private win: window.Window | null = null
  private keepScreenOnApplied: boolean = false
  private soundEnabled: boolean = true
  /** 进入训练时解析出的完整训练状态（含真实 planId / dayId / 各动作 exerciseId）。 */
  private activeState: ActiveWorkoutState = {
    hasWorkout: false,
    planId: '',
    dayId: '',
    title: '',
    totalTargetSets: 0,
    completedSets: 0,
    currentExerciseName: '',
    currentExerciseSetProgress: '0/0 正式组',
    exercises: []
  }
  /** 展示单位（来自「设置 · 体重单位」）；重量基准值始终为 kg，仅输入与展示按单位换算。 */
  @State private displayUnit: WeightUnit = 'kg'

  async aboutToAppear(): Promise<void> {
    await this.applyDisplayUnitPreference()
    // 入口分流：带预览参数 = 从预览开始新一场（旧草稿作废）；否则可能是首页「继续训练」。
    const fromPreview: boolean = this.applyPreviewState()
    if (fromPreview) {
      await this.clearStaleDraft()
    } else {
      const restored: boolean = await this.restoreDraftIfAny()
      if (!restored) {
        this.applyState(this.createEmptyActiveState(), 0)
      }
    }
    this.clockTimer = setInterval(() => {
      this.elapsedSeconds += 1
    }, 1000)
    this.pulseTimer = setInterval(() => {
      this.livePulseLow = !this.livePulseLow
    }, MotionTokens.DURATION_PULSE / 2)
    this.applyKeepScreenOnPreference()
    this.applySoundPreference()
  }

  aboutToDisappear(): void {
    if (this.clockTimer !== -1) {
      clearInterval(this.clockTimer)
      this.clockTimer = -1
    }
    if (this.pulseTimer !== -1) {
      clearInterval(this.pulseTimer)
      this.pulseTimer = -1
    }
    if (this.celebrateTimer !== -1) {
      clearTimeout(this.celebrateTimer)
      this.celebrateTimer = -1
    }
    if (this.holdTimer !== -1) {
      clearInterval(this.holdTimer)
      this.holdTimer = -1
    }
    this.cancelAdvance()
    this.releaseKeepScreenOn()
    // 系统返回键 / 被 pop 时的兜底：chevron 之外的退出路径也要留下草稿
    this.persistDraftOnExit()
  }

  /** 当前输入重量的展示值（显示单位下的整数）。 */
  private displayWeightValue(): number {
    return Math.round(kgToDisplay(this.weight, this.displayUnit))
  }

  /** 已记录组的重量展示文本（显示单位下的整数，基准值仍为 kg）。 */
  private displayWeightText(weightKg: number): string {
    return Math.round(kgToDisplay(weightKg, this.displayUnit)).toString()
  }

  /** 读取「设置 · 体重单位」；读取失败保持 kg。 */
  private async applyDisplayUnitPreference(): Promise<void> {
    const host: Context | undefined = this.getUIContext().getHostContext()
    if (host === undefined) {
      return
    }
    try {
      const profile: UserProfile = await UserProfileService.loadProfile(host)
      this.displayUnit = profile.weightUnit
    } catch (error) {
      // 读取失败保持 kg 基准显示
    }
  }

  /** 读取「训练中屏幕常亮」偏好并应用到当前窗口；失败不阻塞训练流。 */
  private async applyKeepScreenOnPreference(): Promise<void> {
    const host: Context | undefined = this.getUIContext().getHostContext()
    if (host === undefined) {
      return
    }
    try {
      const settings: AppSettings = await SettingsService.loadSettings(host)
      if (!settings.keepOn) {
        return
      }
      const win: window.Window = await window.getLastWindow(host)
      this.win = win
      await win.setWindowKeepScreenOn(true)
      this.keepScreenOnApplied = true
    } catch (error) {
      // 常亮设置失败不阻塞训练流
    }
  }

  /** 读取「声音与震动」开关（设置页门控）；读取失败保持默认开。 */
  private async applySoundPreference(): Promise<void> {
    const host: Context | undefined = this.getUIContext().getHostContext()
    if (host === undefined) {
      return
    }
    try {
      const settings: AppSettings = await SettingsService.loadSettings(host)
      this.soundEnabled = settings.sound
    } catch (error) {
      // 读取失败保持默认值
    }
  }

  /** 释放常亮并解除窗口引用。完成页以 pushUrl 压栈、本组件不销毁，finish() 需主动调用。 */
  private releaseKeepScreenOn(): void {
    if (this.keepScreenOnApplied && this.win !== null) {
      this.win.setWindowKeepScreenOn(false)
      this.keepScreenOnApplied = false
    }
    this.win = null
  }

  /**
   * 从路由参数建立新训练；返回是否拿到了可用预览。
   *
   * 拿不到（直接进入本页 / 参数异常）时**不写界面**——交给 restoreDraftIfAny 或空态兜底，
   * 否则先铺一遍空态再铺草稿，快照上会闪一次 0 组。
   */
  private applyPreviewState(): boolean {
    try {
      const params: ActiveWorkoutRouteParams = this.getUIContext().getRouter().getParams() as ActiveWorkoutRouteParams
      if (params.preview !== undefined) {
        const candidate: ActiveWorkoutState = ActiveWorkoutService.createState(params.preview)
        if (candidate.hasWorkout) {
          this.applyState(candidate, 0)
          return true
        }
      }
    } catch (e) {
      // 参数缺失或格式异常：交给草稿恢复 / 空态兜底
    }
    return false
  }

  /**
   * 把一份训练态铺到界面字段上。预览新建与草稿恢复共用同一段，
   * 避免两处各写一遍导致「恢复后的记录区口径」与「新建时」漂移。
   *
   * [elapsedSeconds] 只有草稿恢复时非 0（草稿存的是绝对起点，见 restoreDraftIfAny）。
   */
  private applyState(state: ActiveWorkoutState, elapsedSeconds: number): void {
    // 留存完整 state：保存会话时需回读真实 planId / dayId / 各动作 exerciseId
    //（此前的写死值 'active_plan' / 'active_day' / 'bench_press' 即源于此处丢失）。
    this.activeState = state
    this.exerciseName = state.currentExerciseName
    this.exerciseGifSource = ExerciseGifCatalog.resolveDemoSource(state.currentExerciseName)
    this.exerciseUsesPhotoStyle = ExerciseGifCatalog.usesPhotoStyle(state.currentExerciseName)
    this.exerciseTotal = state.exercises.length
    this.exerciseIndex = this.findCurrentExerciseIndex(state)
    this.targetSets = ActiveWorkoutService.totalTargetSets(state)
    this.completed = state.completedSets
    this.elapsedSeconds = elapsedSeconds
    // 顶部胶囊初值：首个未录满动作（= 改造前「当前动作」的同一口径）；全部录满时停在最后一个动作。
    const unfinished: number = findUnfinishedExerciseIndex(state.exercises)
    this.selectedExerciseIndex =
      unfinished >= 0 ? unfinished : Math.max(state.exercises.length - 1, 0)
    // 记录区只持有选中动作的分组；从预览新建的 state 通常还没有完成组，此处为空数组。
    this.recordGroups = this.selectedExerciseIndex < state.exercises.length
      ? buildRecordGroupFor(state.exercises, state.exercises[this.selectedExerciseIndex].plannedExerciseId)
      : []
    // 重量/次数必须有可落库的初值：组条目初建时是空文本（解析出 0），而
    // ActiveWorkoutService 只把 weight>0 && reps>0 的组判为已完成——沿用 0 时
    // 「完成本组」写不进进度，训练会卡在同一组反复覆盖。故回落到重量下限与目标次数。
    const initialValues: InitialSetValues = this.findInitialSetValues(state)
    this.weight = initialValues.weight > 0 ? initialValues.weight : WEIGHT_MIN_KG
    this.reps = initialValues.reps > 0 ? initialValues.reps : this.findTargetRepsValue(state)
  }

  /**
   * 草稿恢复：本页在没有预览参数时进入（首页「继续训练」），按上次退出的进度续练。
   * 返回是否恢复成功。
   */
  private async restoreDraftIfAny(): Promise<boolean> {
    const host: Context | undefined = this.getUIContext().getHostContext()
    if (host === undefined) {
      return false
    }
    const draft: WorkoutDraftSnapshot | null = await WorkoutDraftService.getDraft(host)
    if (draft === null || !hasWorkoutDraftProgress(draft)) {
      return false
    }
    const state: ActiveWorkoutState = fromWorkoutDraft(draft)
    if (!state.hasWorkout) {
      return false
    }
    // 时长接续：草稿存的是绝对起点，隔多久回来都算得准（此前 elapsedSeconds 只从 0 起）。
    const elapsed: number = Math.max(0, Math.floor((Date.now() - draft.startedAt) / 1000))
    this.applyState(state, elapsed)
    return true
  }

  /**
   * 落草稿。两个调用点共用：chevron 收起、aboutToDisappear 兜底（系统返回键）。
   *
   * 幂等（draftSavedOnExit）；整场做完（finished）与零完成组时不写——
   * 前者草稿已被 clearStaleDraft 清掉，后者避免首页留下「0/12 组」的空壳接续态。
   * fire-and-forget：preferences 失败不阻塞退出，Context 来自 UIAbility 不随组件销毁失效。
   */
  private persistDraftOnExit(): void {
    if (this.draftSavedOnExit || this.finished) {
      return
    }
    const host: Context | undefined = this.getUIContext().getHostContext()
    if (host === undefined) {
      return
    }
    if (ActiveWorkoutService.countCompletedSets(this.activeState.exercises) <= 0) {
      return
    }
    this.draftSavedOnExit = true
    const now: number = Date.now()
    const startedAt: number = now - this.elapsedSeconds * 1000
    // 第三参数（dayLabel 槽位）传入 dayId：草稿结构没有独立的 dayId 字段，
    // 借用该槽位保持往返无损，fromWorkoutDraft 再取回为 dayId。
    const snapshot: WorkoutDraftSnapshot = toWorkoutDraft(
      this.activeState,
      this.activeState.title,
      this.activeState.dayId,
      startedAt,
      now
    )
    WorkoutDraftService.saveDraft(host, snapshot)
  }

  /** 清掉上一场残留的草稿（新一场开始 / 整场完成时调用）。 */
  private async clearStaleDraft(): Promise<void> {
    const host: Context | undefined = this.getUIContext().getHostContext()
    if (host === undefined) {
      return
    }
    await WorkoutDraftService.clearDraft(host)
  }

  private createEmptyActiveState(): ActiveWorkoutState {
    const exercises: ActiveWorkoutExercise[] = []
    const state: ActiveWorkoutState = {
      hasWorkout: false,
      planId: '',
      dayId: '',
      title: '',
      totalTargetSets: 0,
      completedSets: 0,
      currentExerciseName: '',
      currentExerciseSetProgress: '0/0 正式组',
      exercises: exercises
    }
    return state
  }

  private findInitialSetValues(state: ActiveWorkoutState): InitialSetValues {
    const values: InitialSetValues = { weight: 0, reps: 0 }
    if (state.exercises.length === 0) {
      return values
    }
    const firstExercise: ActiveWorkoutExercise = state.exercises[0]
    if (firstExercise.sets.length === 0) {
      return values
    }
    const firstSet: ActiveWorkoutSetEntry = firstExercise.sets[0]
    values.weight = this.parsePositiveNumber(firstSet.weightText)
    values.reps = this.parsePositiveNumber(firstSet.repsText)
    return values
  }

  /**
   * 从首个动作的目标次数文本（「8–10」「10 次」等）里取首个数字；取不到回退 [FALLBACK_REPS]。
   *
   * 只作为输入框的初值——组条目自身是空文本，直接解析永远得到 0，而重量/次数为 0
   * 的组不会计入进度（见 ActiveWorkoutService.createSetEntry 的 isComplete 判据）。
   */
  private findTargetRepsValue(state: ActiveWorkoutState): number {
    if (state.exercises.length === 0) {
      return FALLBACK_REPS
    }
    const text: string = state.exercises[0].targetReps
    let digits: string = ''
    for (let index = 0; index < text.length; index++) {
      const char: string = text.charAt(index)
      if (char >= '0' && char <= '9') {
        digits += char
      } else if (digits.length > 0) {
        break
      }
    }
    if (digits.length === 0) {
      return FALLBACK_REPS
    }
    const parsed: number = Number(digits)
    if (Number.isNaN(parsed) || parsed <= 0) {
      return FALLBACK_REPS
    }
    return parsed
  }

  private parsePositiveNumber(text: string): number {
    if (text.length === 0) {
      return 0
    }
    const value: number = Number(text)
    if (Number.isNaN(value) || value < 0) {
      return 0
    }
    return value
  }

  private currentExerciseLabel(): string {
    if (this.exerciseName.length === 0) {
      return '未设置动作'
    }
    return this.exerciseName
  }

  /** 当前进行中的动作序号（1 起）；全部完成时取最后一个。 */
  private findCurrentExerciseIndex(state: ActiveWorkoutState): number {
    for (let index = 0; index < state.exercises.length; index++) {
      const exercise: ActiveWorkoutExercise = state.exercises[index]
      if (exercise.completedSets < exercise.targetSets) {
        return index + 1
      }
    }
    if (state.exercises.length === 0) {
      return 1
    }
    return state.exercises.length
  }

  /** 角标「当前动作 / 动作总数」；无训练数据时返回空串（不再回落原型示例值）。 */
  private exerciseBadgeText(): string {
    if (this.exerciseTotal <= 0) {
      return ''
    }
    return this.exerciseIndex.toString() + ' / ' + this.exerciseTotal.toString()
  }

  private finish(): void {
    this.releaseKeepScreenOn()
    this.getUIContext().getRouter().pushUrl({ url: AppRoutes.WORKOUT_COMPLETE })
  }

  private openModal(): void {
    // 判据是「选中动作还有空组」，不是全局组数——切到已录满的动作时不该开弹窗
    if (this.selectedCanRecord()) {
      this.getUIContext().animateTo({ duration: MotionTokens.DURATION_OVERLAY, curve: MotionTokens.EASE_MOTION }, () => {
        this.showModal = true
      })
    }
  }

  private closeModal(): void {
    this.showModal = false
  }

  private changeWeight(delta: number): void {
    // 步进在「显示单位」下进行（lbs 时每次 ±1 lbs），再换算回 kg 单一真源。
    const displayValue: number = kgToDisplay(this.weight, this.displayUnit)
    const minDisplay: number = Math.round(kgToDisplay(WEIGHT_MIN_KG, this.displayUnit))
    const maxDisplay: number = Math.round(kgToDisplay(WEIGHT_MAX_KG, this.displayUnit))
    const nextDisplay: number = Math.max(minDisplay, Math.min(maxDisplay, Math.round(displayValue) + delta))
    this.weight = displayToKg(nextDisplay, this.displayUnit)
  }

  private changeReps(delta: number): void {
    this.reps = Math.max(1, Math.min(15, this.reps + delta))
  }

  private completeSet(): void {
    if (this.finished) {
      return
    }
    const target: ActiveWorkoutExercise | undefined = this.selectedExercise()
    // 目标动作由「顶部胶囊选中的动作」决定，不再由 state 推导：
    // 沿用 recordSet（首个未录满动作）会让用户看着动作 3 却记到动作 1，且无任何可见报错。
    if (target === undefined || !this.selectedCanRecord()) {
      return
    }
    const nextState: ActiveWorkoutState = ActiveWorkoutService.recordSetFor(
      this.activeState,
      target.plannedExerciseId,
      this.weight.toString(),
      this.reps.toString()
    )
    if (nextState === this.activeState) {
      // 目标动作没有空组：服务原样返回，不落任何写
      return
    }
    this.activeState = nextState
    // 选中的动作刚录满 → 排一次自动前进（保持「做完自动切下一个」的既有体感）；
    // 用户跳着补录时不会被拽走。
    //
    // 这里不再直接改 selectedExerciseIndex：改完之后 applyCurrentExercise 立刻把展示换成新动作，
    // 而 selectedIsFull()、dock 的「已完成」、胶囊满格全都以 index 为准——
    // 在同一个同步块里改掉 index，这套完成态连一帧都渲染不出来（真机上就是「瞬间归零」）。
    if (target.completedSets + 1 >= target.targetSets) {
      const nextIndex: number = findUnfinishedExerciseIndex(nextState.exercises)
      if (nextIndex >= 0) {
        this.scheduleAdvance(target.plannedExerciseId, nextIndex)
      }
    }
    this.applyCurrentExercise(nextState)
    if (this.selectedExerciseIndex < nextState.exercises.length) {
      const selected: ActiveWorkoutExercise = nextState.exercises[this.selectedExerciseIndex]
      // 记录从刚更新的 activeState 派生（与落库同源），且只取选中动作：
      // 设备实测确认过增量维护 UI 状态会吞组，派生方案让展示与落库永远同源。
      this.recordGroups = buildRecordGroupFor(nextState.exercises, selected.plannedExerciseId)
    } else {
      this.recordGroups = []
    }
    this.getUIContext().animateTo({ duration: MotionTokens.DURATION_MARKER, curve: MotionTokens.EASE_MOTION }, () => {
      this.completed = nextState.completedSets
    })
    this.showModal = false
    if (this.soundEnabled) {
      HapticFeedbackService.confirm()
    }
    // 收尾判据改为「没有下一个未录满动作」，不再比较全局组号与总组数：
    // 跳着做时 completed 可能先追平，但那只是跳过的动作还没做。
    if (ActiveWorkoutService.nextExercise(nextState) === undefined) {
      // 庆祝只在里程碑出现。此前每组都置 celebrating=true 并铺 1.4s 全屏遮罩：
      // 一次训练放 N 次焰火，情绪价值被稀释，还会打断连续记录的输入节奏。
      this.celebrating = true
      this.finished = true
      this.saveCompletedSession()
      this.celebrateTimer = setTimeout(() => {
        this.celebrating = false
        this.celebrateTimer = -1
        this.finish()
      }, 900)
    }
  }

  /** 把选中动作同步到展示态（名称 / 演示素材 / 角标序号）。 */
  private applyCurrentExercise(state: ActiveWorkoutState): void {
    if (this.selectedExerciseIndex < 0 || this.selectedExerciseIndex >= state.exercises.length) {
      this.exerciseIndex = 1
      return
    }
    const exercise: ActiveWorkoutExercise = state.exercises[this.selectedExerciseIndex]
    this.exerciseName = exercise.name
    this.exerciseGifSource = ExerciseGifCatalog.resolveDemoSource(exercise.name)
    this.exerciseUsesPhotoStyle = ExerciseGifCatalog.usesPhotoStyle(exercise.name)
    this.exerciseIndex = this.selectedExerciseIndex + 1
  }

  /**
   * 保存本次训练会话。
   *
   * 走 [ActiveWorkoutService.createCompletedSession] 构建——planId / dayId 取自进入训练时解析的
   * 真实计划上下文，动作 id 取自各动作的真实 exerciseId（此前写死 'active_plan'/'active_day'/
   * 'bench_press'，会让回顾与 PR 统计失去真实归属）。
   *
   * 用户的组记录（weight / reps）写回 state 对应动作的组条目后再构建，保证落库的组数据是实测值。
   */
  private saveCompletedSession(): void {
    const endedAt: number = Date.now()
    const startedAt: number = endedAt - this.elapsedSeconds * 1000
    // 每组已在 completeSet 里实时写入 activeState（经 recordSet），此处不再按界面记录回填：
    // 旧实现按扁平顺序摊到所有动作，动作边界一变就会把组记到错误的动作/组上。
    const session: WorkoutSession = ActiveWorkoutService.createCompletedSession(
      'session_' + endedAt.toString(),
      this.activeState,
      startedAt,
      endedAt,
      ActiveWorkoutService.countCompletedSets(this.activeState.exercises)
    )
    WorkoutRepository.saveSession(session)
    // 草稿使命结束：整场已完成，首页不该再出现「继续训练」
    this.clearStaleDraft()
  }

  /** 动作切换胶囊的索引序列（0..exerciseTotal-1）。 */
  private exerciseIndexes(): number[] {
    const indexes: number[] = []
    for (let index = 0; index < this.exerciseTotal; index++) {
      indexes.push(index)
    }
    return indexes
  }

  /** 当前选中的动作；下标越界或无训练数据时返回 undefined。 */
  private selectedExercise(): ActiveWorkoutExercise | undefined {
    const exercises: ActiveWorkoutExercise[] = this.activeState.exercises
    if (this.selectedExerciseIndex < 0 || this.selectedExerciseIndex >= exercises.length) {
      return undefined
    }
    return exercises[this.selectedExerciseIndex]
  }

  /** 选中动作还能不能记一组（有未填的空组）。 */
  private selectedCanRecord(): boolean {
    const exercise: ActiveWorkoutExercise | undefined = this.selectedExercise()
    if (exercise === undefined) {
      return false
    }
    return exercise.completedSets < exercise.targetSets
  }

  /** 选中动作是否已录满（按钮置灰与弹窗关闭的判据）。 */
  private selectedIsFull(): boolean {
    return !this.selectedCanRecord()
  }

  /** 选中动作的目标组数（caption 在录满态报总数用）。 */
  private exerciseTargetSets(): number {
    const exercise: ActiveWorkoutExercise | undefined = this.selectedExercise()
    return exercise === undefined ? 0 : exercise.targetSets
  }

  /** 当前动作的组索引（0..targetSets-1）；提前结束后 targetSets 已收缩，自动变短。 */
  private setIndexes(): number[] {
    const indexes: number[] = []
    const exercise: ActiveWorkoutExercise | undefined = this.selectedExercise()
    const total: number = exercise === undefined ? 0 : exercise.targetSets
    for (let index = 0; index < total; index++) {
      indexes.push(index)
    }
    return indexes
  }

  /** 该组是否已完成（实心态）。 */
  private isSetDone(index: number): boolean {
    const exercise: ActiveWorkoutExercise | undefined = this.selectedExercise()
    return exercise !== undefined && index < exercise.completedSets
  }

  /** 该组是否是「正在做的那一组」（实线描边 + 呼吸）。 */
  private isSetCurrent(index: number): boolean {
    const exercise: ActiveWorkoutExercise | undefined = this.selectedExercise()
    return exercise !== undefined && index === exercise.completedSets && index < exercise.targetSets
  }

  private openExercisePicker(): void {
    this.showExercisePicker = true
  }

  /** 弹层里第 index 个动作的显示名。 */
  private exerciseEntryName(index: number): string {
    if (index < 0 || index >= this.activeState.exercises.length) {
      return ''
    }
    return this.activeState.exercises[index].name
  }

  /**
   * 选中某个动作：关闭弹层 → 旧名上滑淡出 + 卡片转到 90° → 换内容 → 名称升入 + 卡片转回。
   *
   * 中段的 setTimeout 是切换点：卡片此时正好侧对屏幕，换素材不露馅。
   */
  /**
   * 挂起一次自动前进：停留期满、且用户没有手动切走时，才走 chooseExercise。
   *
   * 用 plannedExerciseId 而不是 index 标识来源：提前结束会收缩 targetSets，
   * index 的可比性不如这条动作的稳定身份。
   */
  private scheduleAdvance(fromId: string, targetIndex: number): void {
    this.cancelAdvance()
    this.advanceFromId = fromId
    this.advanceTimer = setTimeout(() => {
      this.advanceTimer = -1
      const source: string = this.advanceFromId
      this.advanceFromId = ''
      const current: ActiveWorkoutExercise | undefined = this.selectedExercise()
      // 这段时间里用户自己切走了 → 尊重用户选择，不把他拽回自动前进的目标
      if (current === undefined || current.plannedExerciseId !== source) {
        return
      }
      this.chooseExercise(targetIndex)
    }, ADVANCE_HOLD_MS)
  }

  /** 取消挂起的自动前进（手动切换、离开页面、再次录满时都要先取消）。 */
  private cancelAdvance(): void {
    if (this.advanceTimer !== -1) {
      clearTimeout(this.advanceTimer)
      this.advanceTimer = -1
    }
    this.advanceFromId = ''
  }

  private chooseExercise(index: number): void {
    this.showExercisePicker = false
    // 手动切换优先于任何挂起的自动前进（含用户点开菜单又选回当前动作）
    this.cancelAdvance()
    if (index === this.selectedExerciseIndex) {
      return
    }
    this.getUIContext().animateTo({ duration: 120, curve: MotionTokens.EASE_MOTION }, () => {
      this.nameShift = -28
      this.nameOpacity = 0
      this.cardFlipAngle = 90
    })
    setTimeout(() => {
      this.selectExercise(index)
      this.nameShift = 28
      this.cardFlipAngle = -90
      this.getUIContext().animateTo({ duration: 160, curve: MotionTokens.EASE_MOTION }, () => {
        this.nameShift = 0
        this.nameOpacity = 1
        this.cardFlipAngle = 0
      })
    }, 120)
  }

  // --- 长按「完成」：提前结束当前动作 ---------------------------------------

  private startHold(): void {
    if (this.selectedIsFull()) {
      return
    }
    this.holding = true
    this.holdTriggered = false
    this.holdEngaged = false
    this.holdProgress = 0
    this.stopHoldTimer()
    this.holdTimer = setInterval(() => {
      this.holdProgress += HOLD_TICK_MS / HOLD_DURATION_MS
      if (this.holdProgress >= HOLD_ENGAGE_PROGRESS) {
        this.holdEngaged = true
      }
      if (this.holdProgress >= 1) {
        this.holdProgress = 1
        this.holdTriggered = true
        this.stopHoldTimer()
        this.endCurrentExercise()
      }
    }, HOLD_TICK_MS)
  }

  /** 中途松开：停表 + 复位（回落由渲染处的 animation 补出来）。 */
  private cancelHold(): void {
    this.stopHoldTimer()
    this.holding = false
    this.holdProgress = 0
  }

  private stopHoldTimer(): void {
    if (this.holdTimer !== -1) {
      clearInterval(this.holdTimer)
      this.holdTimer = -1
    }
  }

  /**
   * 提前结束当前动作：收缩到已完成的组数，然后自动前进到下一个未录满动作。
   *
   * 收尾判据与「完成本组」共用 nextExercise——最后一个动作也被结束时直接进庆祝/完成页。
   */
  private endCurrentExercise(): void {
    const target: ActiveWorkoutExercise | undefined = this.selectedExercise()
    if (target === undefined) {
      return
    }
    const nextState: ActiveWorkoutState =
      ActiveWorkoutService.endExercise(this.activeState, target.plannedExerciseId)
    this.holding = false
    this.holdProgress = 0
    if (nextState === this.activeState) {
      return
    }
    this.activeState = nextState
    const nextIndex: number = findUnfinishedExerciseIndex(nextState.exercises)
    if (nextIndex >= 0) {
      this.selectedExerciseIndex = nextIndex
    }
    this.applyCurrentExercise(nextState)
    this.completed = nextState.completedSets
    const selected: ActiveWorkoutExercise | undefined = this.selectedExercise()
    this.recordGroups = selected === undefined
      ? []
      : buildRecordGroupFor(nextState.exercises, selected.plannedExerciseId)
    if (this.soundEnabled) {
      HapticFeedbackService.confirm()
    }
    if (ActiveWorkoutService.nextExercise(nextState) === undefined) {
      this.celebrating = true
      this.finished = true
      this.saveCompletedSession()
      this.celebrateTimer = setTimeout(() => {
        this.celebrating = false
        this.celebrateTimer = -1
        this.finish()
      }, 900)
    }
  }

  /** 动作内组号（1 起，录满停在 targetSets）——替换原来的全场组号。 */
  private selectedSetNumber(): number {
    const exercise: ActiveWorkoutExercise | undefined = this.selectedExercise()
    if (exercise === undefined) {
      return 1
    }
    const next: number = exercise.completedSets + 1
    return next > exercise.targetSets ? exercise.targetSets : next
  }

  /** 切到指定动作：名称、演示素材、角标、记录区、输入初值一起跟随。 */
  private selectExercise(index: number): void {
    if (index === this.selectedExerciseIndex) {
      return
    }
    if (index < 0 || index >= this.activeState.exercises.length) {
      return
    }
    this.selectedExerciseIndex = index
    const exercise: ActiveWorkoutExercise = this.activeState.exercises[index]
    this.exerciseName = exercise.name
    this.exerciseGifSource = ExerciseGifCatalog.resolveDemoSource(exercise.name)
    this.exerciseUsesPhotoStyle = ExerciseGifCatalog.usesPhotoStyle(exercise.name)
    this.exerciseIndex = index + 1
    this.recordGroups = buildRecordGroupFor(this.activeState.exercises, exercise.plannedExerciseId)
    this.applyExerciseInputDefaults(exercise)
  }

  /** 输入初值跟随选中动作：取该动作最后一个已完成组；没有则保持当前输入。 */
  private applyExerciseInputDefaults(exercise: ActiveWorkoutExercise): void {
    for (let index = exercise.sets.length - 1; index >= 0; index--) {
      const entry: ActiveWorkoutSetEntry = exercise.sets[index]
      if (!entry.isComplete) {
        continue
      }
      const weight: number = this.parsePositiveNumber(entry.weightText)
      const reps: number = this.parsePositiveNumber(entry.repsText)
      if (weight > 0) {
        this.weight = weight
      }
      if (reps > 0) {
        this.reps = reps
      }
      return
    }
  }

  /**
   * 收起训练：落草稿后返回主壳（首页据此显示「继续训练」）。
   *
   * 与系统返回键走同一条退出路径——aboutToDisappear 里也调 persistDraftOnExit 兜底，
   * 两处靠 draftSavedOnExit 幂等，不会重复写盘。
   */
  private collapseWorkout(): void {
    this.releaseKeepScreenOn()
    this.persistDraftOnExit()
    this.getUIContext().getRouter().back()
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(PrototypeTokens.BG_INK)

      Column() {
        this.activeTop()
        Scroll() {
          Column({ space: 14 }) {
            this.demoCard()
            this.setList()
          }
          .width('100%')
          .padding({ left: 18, right: 18, top: 16, bottom: 24 })
        }
        .align(Alignment.Top)
        .layoutWeight(1)
        .width('100%')
        this.dock()
      }
      .width('100%')
      .height('100%')

      if (this.showModal) {
        this.recordModal()
      }

      this.celebrateOverlay()
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private activeTop() {
    Column({ space: 10 }) {
      Row() {
        this.collapseButton()
        Row({ space: 4 }) {
          Text(this.currentExerciseLabel())
            .fontFamily('Noto Sans SC')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(PrototypeTokens.TEXT_HI)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .opacity(this.nameOpacity)
            .translate({ y: this.nameShift })
          Path()
            .width(14)
            .height(14)
            .commands('M3 5 L7 9 L11 5')
            .fill(PrototypeTokens.TRANSPARENT)
            .stroke(PrototypeTokens.WHITE_A54)
            .strokeWidth(1.6)
            .strokeLineCap(LineCapStyle.Round)
        }
        .layoutWeight(1)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .accessibilityText('切换动作')
        .onClick(() => {
          this.openExercisePicker()
        })
        .bindPopup(this.showExercisePicker, {
          builder: (): void => {
            this.exercisePickerList()
          },
          placement: Placement.Bottom,
          popupColor: '#13161A',
          backgroundBlurStyle: BlurStyle.NONE,
          enableArrow: true,
          autoCancel: true,
          mask: true,
          radius: 16
          // 不设 width：动作名长短差别大，固定宽度必然一边留空（140 时最长项只占 66dp）。
          // 内容有多宽菜单就多宽，上限由列表容器 Column 的 constraintSize(maxWidth) 兜住；
          // 安卓侧用 onSizeChanged 回写实测宽度，实现同一效果。
        })
        this.topTimer()
      }
      .width('100%')
      .height(44)
      .alignItems(VerticalAlign.Center)

      this.setPills()
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 10, bottom: 10 })
    // 原型 .wo-top: rgba(10,13,18,.96)。ArkUI 的 8 位色是 #AARRGGBB，
    // 曾误按 #RRGGBBAA 写成 #0A0D12F5（= 4% 透明 + RGB(13,18,245)），顶栏因此比主体偏蓝。
    .backgroundColor(PrototypeTokens.SCRIM_DEEP)
    .border({ width: { bottom: 1 }, color: PrototypeTokens.WHITE_A06 })
  }

  /**
   * 收起按钮：纯线条 chevron-down，无底色块、无描边底、无常驻圆底（参考图左上角）。
   *
   * 用 Path 直接画折线而不是放 SVG 资源：IconTokens 的注释已写明 Image.fillColor 只换 fill、
   * 对 stroke 无效——需要随状态变色的线条图标必须自绘。
   */
  @Builder
  private collapseButton() {
    Stack({ alignContent: Alignment.Center }) {
      Path()
        .width(24)
        .height(24)
        .commands('M6 9.5 L12 15.5 L18 9.5')
        .fill(PrototypeTokens.TRANSPARENT)
        .stroke(PrototypeTokens.ACCENT)
        .strokeWidth(2.2)
        .strokeLineCap(LineCapStyle.Round)
        .strokeLineJoin(LineJoinStyle.Round)
    }
    .width(44)
    .height(44)
    .scale({ x: this.collapsePressed ? MotionTokens.PRESS_ICON : 1, y: this.collapsePressed ? MotionTokens.PRESS_ICON : 1 })
    .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
    .accessibilityText('收起训练')
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.collapsePressed = true
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.collapsePressed = false
      }
    })
    .onClick(() => {
      this.collapseWorkout()
    })
  }

  /** 顶栏右端计时器：呼吸点 +「·总时长」+ 等宽 mm:ss。 */
  @Builder
  private topTimer() {
    Row({ space: 5 }) {
      Row()
        .width(6)
        .height(6)
        .borderRadius(3)
        .backgroundColor(PrototypeTokens.ACCENT)
        .opacity(this.livePulseLow ? 0.45 : 1)
        .scale({ x: this.livePulseLow ? 0.78 : 1, y: this.livePulseLow ? 0.78 : 1 })
        .animation({ duration: MotionTokens.DURATION_PULSE / 2, curve: Curve.EaseInOut })
      Text('·总时长')
        .fontFamily('Noto Sans SC')
        .fontSize(11.5)
        .fontColor(PrototypeTokens.WHITE_A60)
      Text(formatClock(this.elapsedSeconds))
        .fontFamily('Geist Mono')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(PrototypeTokens.TEXT_HI)
    }
  }

  /** 组胶囊行：当前动作每组一个胶囊，整行等分铺满。 */
  @Builder
  private setPills() {
    if (this.setIndexes().length === 0) {
      // 不套描边壳：胶囊的语义是「一格一组」，用一个壳装一句话会让这一行读成第 N+1 格。
      Text('本动作已结束')
        .fontFamily('Noto Sans SC')
        .fontSize(12)
        .fontColor(PrototypeTokens.WHITE_A40)
        .width('100%')
        .height(SET_PILL_HEIGHT)
        .textAlign(TextAlign.Center)
    } else {
      // 行尾不再放 n/total：组号在演示卡 caption（「第 N 组 · 正式组」）与记录分组头（「n 组」）
      // 各有一份，胶囊再来一份是第三重编码，还占掉约 30dp——6 组时每格从 54 被压到 47。
      // 「共几组」本来就能数格数读出来，这个比值不带来新信息。
      Row({ space: SET_PILL_GAP }) {
        ForEach(this.setIndexes(), (index: number) => {
          this.setPill(index)
        }, (index: number) => 'set_' + index.toString())
      }
      .width('100%')
    }
  }

  /** 单个组胶囊：已完成实心 accent、当前组呼吸描边、未做灰底。纯形态，不标数字。 */
  @Builder
  private setPill(index: number) {
    Row()
      .height(SET_PILL_HEIGHT)
      .constraintSize({ minWidth: SET_PILL_MIN_WIDTH })
      .layoutWeight(1)
      // 三态底色：已完成填满 ACCENT、当前组极淡 ACCENT（「下一个待填满的位置」）、未做玻璃灰。
      // 当前组原先是透明底 + 虚线描边——26 高的细条上虚线只剩一两个 dash，
      // 读起来像「描边没画好」而不是「进行中」，改实线 + 淡底后层级才立得住。
      .backgroundColor(
        this.isSetDone(index)
          ? PrototypeTokens.ACCENT
          : (this.isSetCurrent(index) ? PrototypeTokens.ACCENT_A12 : PrototypeTokens.WHITE_A03)
      )
      .borderRadius(999)
      .border({
        width: this.isSetDone(index) ? 0 : (this.isSetCurrent(index) ? 1.5 : 1),
        // 当前组的描边跟着顶栏计时点同一个拍子呼吸（livePulseLow，800ms 半周期）。
        // 只动描边、不动底色：填充变暗会被读成「这一组的完成度退回去了」。
        // 同频而不是另起周期，是让两处读成同一个「系统在走」的节拍，不是两团互相盖住的噪音。
        color: this.isSetCurrent(index)
          ? (this.livePulseLow ? PrototypeTokens.ACCENT_A45 : PrototypeTokens.ACCENT)
          : PrototypeTokens.WHITE_A10,
        style: BorderStyle.Solid
      })
      // 不渲染数字后，组号与三态都只保留在无障碍描述里
      .accessibilityText('第 ' + (index + 1).toString() + ' 组，' + this.setPillStateLabel(index))
      .animation({ duration: MotionTokens.DURATION_MARKER, curve: MotionTokens.EASE_MOTION })
  }

  /** 胶囊的三态状态词：视觉上有三态，读屏也得有三态，否则「第 3 组」分不出做没做。 */
  private setPillStateLabel(index: number): string {
    if (this.isSetDone(index)) {
      return '已完成'
    }
    return this.isSetCurrent(index) ? '进行中' : '未开始'
  }

  /** 动作切换弹层内容：当前项右侧带对勾。 */
  @Builder
  private exercisePickerList() {
    Column() {
      ForEach(this.exerciseIndexes(), (index: number) => {
        Row() {
          Text(this.exerciseEntryName(index))
            .fontFamily('Noto Sans SC')
            .fontSize(14)
            .fontColor(index === this.selectedExerciseIndex ? PrototypeTokens.ACCENT : PrototypeTokens.WHITE_A70)
            // 不用 layoutWeight(1)：那会把勾选推到行尾，中间留一大片空档。
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (index === this.selectedExerciseIndex) {
            Text('✓')
              .fontFamily('HarmonyOS Sans')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(PrototypeTokens.ACCENT)
              .margin({ left: 6 })
          }
        }
        .width('100%')
        .height(48)
        .padding({ left: 14, right: 14 })
        .backgroundColor(index === this.selectedExerciseIndex ? PrototypeTokens.ACCENT_A10 : PrototypeTokens.TRANSPARENT)
        .onClick(() => {
          this.chooseExercise(index)
        })
      }, (index: number) => 'picker_' + index.toString())
    }
    // 不设 width：宽度由最宽的一行决定（与安卓 widthIn(max) 同口径），
    // 上限 200 防止超长动作名把菜单撑到屏幕边。
    .constraintSize({ minWidth: 132, maxWidth: 200 })
    .padding({ top: 6, bottom: 6 })
  }

  @Builder
  private demoCard() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 卡面不设底色：素材已收敛为实拍单一来源，由 demoVisual 的圆角容器承载，
      // 图与卡片边界一致，不出现白色面板。
      Column()
        .width('100%')
        .height('100%')

      this.demoVisual()

      Row({ space: 6 }) {
        Text('动作')
          .fontFamily('Noto Sans SC')
          .fontSize(11)
          .fontColor(PrototypeTokens.WHITE_A60)
        Text(this.exerciseBadgeText())
          .fontFamily('Geist Mono')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(PrototypeTokens.ACCENT)
      }
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      // 原型 .demo-position: rgba(8,13,17,.82)（同族笔误，原为 #080D11D1）
      .backgroundColor(PrototypeTokens.SCRIM_DARK)
      .borderRadius(999)
      .border({ width: 1, color: PrototypeTokens.WHITE_A10 })
      .position({ x: 14, y: 14 })

      Row() {
        Text(this.currentExerciseLabel())
          .fontFamily('Noto Sans SC')
          .fontSize(18)
          .lineHeight(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(PrototypeTokens.TEXT_HI)
        // 录满时「第 N 组」是错的：第 N 组已经做完，此刻屏上停留的正是完成态。
        // 换成本动作口径，与 dock 的「本动作已完成」、胶囊满格说同一件事。
        Text(this.selectedIsFull()
          ? '本动作完成 · 共 ' + this.exerciseTargetSets().toString() + ' 组'
          : '第 ' + this.selectedSetNumber().toString() + ' 组 · 正式组')
          .fontFamily('Noto Sans SC')
          .fontSize(12)
          .lineHeight(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(PrototypeTokens.ACCENT)
      }
      .width(326)
      .height(42)
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .justifyContent(FlexAlign.SpaceBetween)
      // 原型 .demo-caption: rgba(8,13,17,.82)（同族笔误，原为 #080D11D1）
      .backgroundColor(PrototypeTokens.SCRIM_DARK)
      .borderRadius(16)
      .border({ width: 1, color: PrototypeTokens.WHITE_A08 })
      .position({ x: 14, y: DEMO_CARD_HEIGHT - 56 })
    }
    .width('100%')
    .height(DEMO_CARD_HEIGHT)
    .borderRadius(28)
    .border({ width: 1, color: PrototypeTokens.WHITE_A08 })
    .clip(true)
    // 切换动作时沿 Y 轴翻面：0 → 90 → -90 → 0，中段（侧对屏幕时）替换素材
    .rotate({ y: 1, angle: this.cardFlipAngle, centerX: '50%', centerY: '50%' })
  }

  @Builder
  private demoVisual() {
    // 动作演示内嵌 GIF：素材已收敛为 free-exercise-db 实拍单一来源
    // （rawfile/exercise-gifs-photo），全彩矩形实景、无白底，须 Cover + 圆角收敛。
    // 容器为正方形且按 DEMO_MEDIA_SIZE 定尺寸居中——容器高度变化不会放大素材。
    // 占位 / 淡入 / 失败回退由 ExerciseDemoImage 统一承担（此前这里两者皆无：
    // 加载失败就是一块空白方框，首帧解码前卡片会跳一下）。
    Row() {
      ExerciseDemoImage({
        source: this.exerciseGifSource,
        photoStyle: this.exerciseUsesPhotoStyle,
        radius: DEMO_PHOTO_RADIUS,
        fit: this.exerciseUsesPhotoStyle ? ImageFit.Cover : ImageFit.Contain,
        fixedSize: DEMO_MEDIA_SIZE,
        label: this.currentExerciseLabel() + ' 动作演示'
      })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private setList() {
    Column({ space: 10 }) {
      if (this.recordGroups.length === 0) {
        Column() {
          Text('还没有完成组')
            .fontFamily('Noto Sans SC')
            .fontSize(13)
            .fontColor(PrototypeTokens.WHITE_A54)
        }
        .width('100%')
        .height(52)
        .justifyContent(FlexAlign.Center)
        .border({ width: 1, color: PrototypeTokens.WHITE_A10, style: BorderStyle.Dashed })
        .borderRadius(14)
      } else {
        ForEach(this.recordGroups, (group: ActiveExerciseRecordGroup) => {
          Column({ space: 8 }) {
            Row() {
              Text(group.exerciseName)
                .fontFamily('Noto Sans SC')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(PrototypeTokens.WHITE_A70)
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(group.sets.length.toString() + ' 组')
                .fontFamily('Geist Mono')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(PrototypeTokens.ACCENT)
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)

            ForEach(group.sets, (record: ActiveSetRecord) => {
              Row() {
                Text('第 ' + record.setNumber.toString() + ' 组')
                  .fontFamily('Noto Sans SC')
                  .fontSize(13)
                  .fontColor(PrototypeTokens.WHITE_A70)
                Text(this.displayWeightText(record.weight) + ' ' + weightUnitLabel(this.displayUnit) + ' × ' + record.reps.toString())
                  .fontFamily('Geist Mono')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(PrototypeTokens.TEXT_HI)
                Text('✓')
                  .fontFamily('HarmonyOS Sans')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(PrototypeTokens.ACCENT)
              }
              .width('100%')
              .height(40)
              .padding({ left: 10, right: 10 })
              .justifyContent(FlexAlign.SpaceBetween)
              .borderRadius(10)
              .border({ width: 1, color: PrototypeTokens.WHITE_A08 })
              .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 6 })))
            }, (record: ActiveSetRecord) => record.setNumber.toString())
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 10, bottom: 12 })
          .backgroundColor('#06FFFFFF')
          .borderRadius(16)
          .border({ width: 1, color: PrototypeTokens.WHITE_A06 })
        }, (group: ActiveExerciseRecordGroup) => group.plannedExerciseId)
      }
    }
    .width('100%')
  }

  @Builder
  private dock() {
    Column({ space: 8 }) {
      if (this.holding) {
        Column({ space: 4 }) {
          Row() {
            Row()
              .width((this.holdProgress * 100).toFixed(1) + '%')
              .height(3)
              .borderRadius(999)
              .backgroundColor(PrototypeTokens.ACCENT)
          }
          .width('100%')
          .height(3)
          .borderRadius(999)
          .backgroundColor(PrototypeTokens.WHITE_A10)
          .animation({ duration: HOLD_TICK_MS, curve: Curve.Linear })
          Text('松开取消 · 继续按住结束本动作')
            .fontFamily('Noto Sans SC')
            .fontSize(11)
            .fontColor(PrototypeTokens.ACCENT)
        }
        .width('100%')
      } else {
        Text(this.selectedIsFull() ? '本动作已完成' : '长按「完成」提前结束本动作')
          .fontFamily('Noto Sans SC')
          .fontSize(11)
          .fontColor(PrototypeTokens.WHITE_A40)
          .width('100%')
          .textAlign(TextAlign.Center)
      }

      Button(this.selectedIsFull() ? '已完成' : '完成')
        .width('100%')
        .height(50)
        .padding(0)
        .fontFamily('Noto Sans SC')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.selectedIsFull() ? PrototypeTokens.WHITE_A40 : PrototypeTokens.TEXT_ON_ACCENT)
        .backgroundColor(this.selectedIsFull() ? PrototypeTokens.WHITE_A06 : PrototypeTokens.ACCENT)
        .borderRadius(16)
        .shadow({ radius: this.selectedIsFull() ? 0 : 22, color: this.selectedIsFull() ? PrototypeTokens.TRANSPARENT : PrototypeTokens.BLACK_A24, offsetX: 0, offsetY: this.selectedIsFull() ? 0 : 10 })
        .enabled(!this.selectedIsFull())
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.submitPressed = true
            this.startHold()
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.submitPressed = false
            // 先读后复位：长按触发后松开会同时走到这里，必须抑掉那次「单击」。
            // holdEngaged 再区分「快速点击」与「按住后放弃」——后者也不该弹窗。
            const triggered: boolean = this.holdTriggered
            const engaged: boolean = this.holdEngaged
            this.holdTriggered = false
            this.holdEngaged = false
            this.cancelHold()
            if (!triggered && !engaged) {
              this.openModal()
            }
          }
        })
        // 硬边厚底：按下收平 + 整体下沉，替代缩放按压
        .border({
          width: { bottom: this.submitPressed ? 0 : DuTokens.PRESS_DEPTH },
          color: { bottom: PrototypeTokens.ACCENT_DEEP }
        })
        .translate({ y: this.submitPressed ? DuTokens.PRESS_SHIFT : 0 })
        .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
        // 不再用 .onClick：长按完成后松开会同时触发 click，导致结束动作后又弹窗
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 10, bottom: 18 })
    // 原型 .wo-dock: rgba(10,13,18,.98)（同族笔误，原为 #0A0D12FA）
    .backgroundColor('#FA0A0D12')
    .border({ width: { top: 1 }, color: PrototypeTokens.WHITE_A06 })
  }

  @Builder
  private recordModal() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#030606B8')
        .transition(TransitionEffect.OPACITY.animation({ duration: MotionIntent.scrimDuration(), curve: MotionIntent.scrimCurve() }))

      Column() {
        Row() {
          Column() {
            Text('RECORD SET')
              .fontFamily('Geist Mono')
              .fontSize(10)
              .letterSpacing(0.8)
              .fontColor(PrototypeTokens.ACCENT)
              .margin({ bottom: 6 })
            Text('记录本组')
              .fontFamily('Noto Sans SC')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(PrototypeTokens.TEXT_HI)
            Text(this.currentExerciseLabel() + ' · 第 ' + this.selectedSetNumber().toString() + ' 组')
              .fontFamily('Noto Sans SC')
              .fontSize(13)
              .fontColor(PrototypeTokens.WHITE_A60)
              .margin({ top: 4 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text('×')
            .fontFamily('HarmonyOS Sans')
            .fontSize(20)
            .lineHeight(36)
            .fontColor(PrototypeTokens.WHITE_A70)
            .width(36)
            .height(36)
            .textAlign(TextAlign.Center)
            .backgroundColor(PrototypeTokens.WHITE_A03)
            .borderRadius(18)
            .border({ width: 1, color: PrototypeTokens.WHITE_A08 })
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.closePressed = true
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.closePressed = false
              }
            })
            .scale({ x: this.closePressed ? MotionTokens.PRESS_ICON : 1, y: this.closePressed ? MotionTokens.PRESS_ICON : 1 })
            .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
            .onClick(() => {
              this.closeModal()
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Row({ space: 12 }) {
          this.inputBox('重量', weightUnitLabel(this.displayUnit).toUpperCase(), this.displayWeightValue(), true)
          this.inputBox('次数', '8–10', this.reps, false)
        }
        .width('100%')
        .margin({ top: 18 })

        Button('完成本组')
          .width('100%')
          .height(50)
          .padding(0)
          .margin({ top: 16 })
          .fontFamily('Noto Sans SC')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(PrototypeTokens.TEXT_ON_ACCENT)
          .backgroundColor(PrototypeTokens.ACCENT)
          .borderRadius(16)
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.completePressed = true
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.completePressed = false
            }
          })
          // Duolingo 硬边厚底：完成本组是全页最高频操作，用物理厚度强化反馈
          .border({
            width: { bottom: this.completePressed ? 0 : DuTokens.PRESS_DEPTH },
            color: { bottom: PrototypeTokens.ACCENT_DEEP }
          })
          .translate({ y: this.completePressed ? DuTokens.PRESS_SHIFT : 0 })
          .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
          .onClick(() => {
            this.completeSet()
          })
      }
      .width(342)
      .padding(20)
      // 底色对齐首页「本周节奏」卡：那张卡是「页底 #0B0F13 + 3.1% 白(#08FFFFFF)」叠出的中性玻璃面，
      // 等效合成色即 #13161A，此处直接用该不透明色——弹窗底下是半透明蒙层，若照搬半透明白会把
      // 下页内容透进面板（已实测）。描边 #1AFFFFFF 与首页卡一致，未改动。
      .backgroundColor('#13161A')
      .borderRadius(28)
      .border({ width: 1, color: PrototypeTokens.WHITE_A10 })
      .shadow({ radius: 60, color: '#80000000', offsetX: 0, offsetY: 28 })
      .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 12 })).combine(TransitionEffect.scale({ x: 0.98, y: 0.98 })).animation({ duration: MotionTokens.DURATION_OVERLAY, curve: MotionTokens.EASE_MOTION }))
    }
    .width('100%')
    .height('100%')
    .onClick(() => {
      this.closeModal()
    })
  }

  @Builder
  private celebrateOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#8C0B0F13')
        .backdropBlur(18)
        .saturate(1.06)

      ForEach(CELEBRATE_PIECES, (piece: CelebratePiece) => {
        Row()
          .width(piece.width)
          .height(piece.height)
          .backgroundColor(piece.color)
          .borderRadius(2)
          .rotate({ angle: piece.rot })
          .position({ x: piece.x, y: piece.y })
          .scale({ x: this.celebrating ? 1 : 0.45, y: this.celebrating ? 1 : 0.45 })
          .animation({ duration: MotionTokens.DURATION_CONFETTI_FLY, curve: MotionTokens.EASE_FLY })
      }, (piece: CelebratePiece) => piece.id)

      Column({ space: 12 }) {
        Stack({ alignContent: Alignment.Center }) {
          Row()
            .width(120)
            .height(120)
            .borderRadius(60)
            .backgroundColor(PrototypeTokens.ACCENT_A07)
          Row()
            .width(88)
            .height(88)
            .borderRadius(44)
            .backgroundColor(PrototypeTokens.ACCENT)
            .shadow({ radius: 54, color: PrototypeTokens.ACCENT_A20, offsetX: 0, offsetY: 0 })
          Image($rawfile('pencil-active-set-check.svg'))
            .width(42)
            .height(42)
        }
        .width(120)
        .height(120)
        .scale({ x: this.celebrating ? 1 : 0.72, y: this.celebrating ? 1 : 0.72 })
        .animation({ duration: MotionTokens.DURATION_CORE, curve: MotionTokens.EASE_MOTION, delay: MotionTokens.DELAY_CORE })

        Text('本组完成')
          .fontFamily('HarmonyOS Sans')
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor(PrototypeTokens.TEXT_HI)

        Text('做得很好')
          .fontFamily('HarmonyOS Sans')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(PrototypeTokens.WHITE_A70)
          .margin({ top: -5 })
      }
      .translate({ y: -84 })
    }
    .width('100%')
    .height('100%')
    .opacity(this.celebrating ? 1 : 0)
    .visibility(this.celebrating ? Visibility.Visible : Visibility.Hidden)
    .animation({ duration: MotionTokens.DURATION_CORE, curve: MotionTokens.EASE_MOTION, delay: MotionTokens.DELAY_CORE })
  }

  @Builder
  private inputBox(label: string, unit: string, value: number, isWeight: boolean) {
    Column({ space: 8 }) {
      Row() {
        Text(label)
          .fontFamily('Noto Sans SC')
          .fontSize(12)
          .fontColor(PrototypeTokens.WHITE_A60)
        Text(unit)
          .fontFamily('Geist Mono')
          .fontSize(10)
          .fontColor(PrototypeTokens.ACCENT)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Row() {
        Text('−')
          .fontFamily('HarmonyOS Sans')
          .fontSize(16)
          .fontColor(PrototypeTokens.WHITE_A60)
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
          .backgroundColor(PrototypeTokens.WHITE_A03)
          .borderRadius(10)
          .border({ width: 1, color: PrototypeTokens.WHITE_A06 })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.minusPressed = true
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.minusPressed = false
            }
          })
          .scale({ x: this.minusPressed ? MotionTokens.PRESS_ICON : 1, y: this.minusPressed ? MotionTokens.PRESS_ICON : 1 })
          .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
          .onClick(() => {
            if (isWeight) {
              this.changeWeight(-1)
            } else {
              this.changeReps(-1)
            }
          })
        Text(value.toString())
          .fontFamily('Geist Mono')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(PrototypeTokens.TEXT_HI)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('+')
          .fontFamily('HarmonyOS Sans')
          .fontSize(16)
          .fontColor(PrototypeTokens.WHITE_A60)
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
          .backgroundColor(PrototypeTokens.WHITE_A03)
          .borderRadius(10)
          .border({ width: 1, color: PrototypeTokens.WHITE_A06 })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.plusPressed = true
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.plusPressed = false
            }
          })
          .scale({ x: this.plusPressed ? MotionTokens.PRESS_ICON : 1, y: this.plusPressed ? MotionTokens.PRESS_ICON : 1 })
          .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
          .onClick(() => {
            if (isWeight) {
              this.changeWeight(1)
            } else {
              this.changeReps(1)
            }
          })
      }
      .width('100%')
    }
    .layoutWeight(1)
    .padding(12)
    .backgroundColor(PrototypeTokens.WHITE_A06)
    .borderRadius(17)
    .border({ width: 1, color: PrototypeTokens.WHITE_A06 })
  }
}

