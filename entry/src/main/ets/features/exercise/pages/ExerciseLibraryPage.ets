/**
 * ExerciseLibraryPage —— 动作库主页面（视觉主线重写）。
 *
 * GIF 网格 + 部位/肌群两级筛选 + 收藏 + 底部详情弹层。
 * 卡片点击打开底部弹层（不再跳转 ExerciseDetailPage）；
 * 收藏经 FavoriteExerciseService 持久化。
 */
import { MotionTokens } from '../../../common/styles/DesignTokens'
import FavoriteExerciseService from '../../../common/services/FavoriteExerciseService'
import { window } from '@kit.ArkUI'

// ---------------------------------------------------------------------------
// 配色（Cold Emerald，就地集中声明）
// ---------------------------------------------------------------------------
class LibPalette {
  static readonly BG_BASE: string = '#0B0F13'
  static readonly ACCENT: string = '#50ECA7'
  static readonly ON_ACCENT: string = '#07100B'
  static readonly SHEET_BG: string = '#0E1316'
  static readonly STROKE: string = 'rgba(255,255,255,0.10)'
  static readonly TEXT_HI: string = '#F7FBF8'
  static readonly WHITE_70: string = 'rgba(255,255,255,0.70)'
  static readonly WHITE_62: string = 'rgba(255,255,255,0.62)'
  static readonly WHITE_54: string = 'rgba(255,255,255,0.54)'
  static readonly WHITE_40: string = 'rgba(255,255,255,0.40)'
  static readonly WHITE_32: string = 'rgba(255,255,255,0.32)'
  static readonly GLASS_BTN_BG: string = 'rgba(255,255,255,0.047)'
  static readonly GLASS_BTN_BORDER: string = 'rgba(255,255,255,0.08)'
  static readonly GLASS_CLOSE_BG: string = 'rgba(255,255,255,0.06)'
  static readonly CHIP_BG: string = 'rgba(255,255,255,0.04)'
  static readonly CHIP_BORDER: string = 'rgba(255,255,255,0.10)'
  static readonly CHIP_ACTIVE_BG: string = 'rgba(80,236,167,0.15)'
  static readonly CHIP_ACTIVE_BORDER: string = 'rgba(80,236,167,0.45)'
  static readonly CARD_BG: string = 'rgba(255,255,255,0.031)'
  static readonly FAV_BG: string = 'rgba(7,10,12,0.62)'
  static readonly FAV_BG_ACTIVE: string = 'rgba(7,10,12,0.72)'
  static readonly FAV_BORDER: string = 'rgba(255,255,255,0.16)'
  static readonly BACKDROP: string = 'rgba(4,7,9,0.55)'
  static readonly TOAST_BG: string = 'rgba(13,17,23,0.94)'
  static readonly HANDLE: string = 'rgba(255,255,255,0.18)'
  static readonly HAIRLINE: string = 'rgba(255,255,255,0.06)'
  static readonly FOCUS_GLOW: string = 'rgba(80,236,167,0.22)'
  static readonly TAG_BG: string = 'rgba(80,236,167,0.12)'
  static readonly TAG_BORDER: string = 'rgba(80,236,167,0.30)'
  static readonly FAV_FILTER_ON_BG: string = 'rgba(80,236,167,0.12)'
  static readonly MEDIA_BG: string = 'rgba(255,255,255,0.04)'
  static readonly MEDIA_BG_SHEET: string = 'rgba(255,255,255,0.045)'
}

// HTML `.lib-fav:active` 按压缩放系数（MotionTokens 无 .9 档，页面级集中声明）。
const PRESS_HEART_SCALE: number = 0.9

// ---------------------------------------------------------------------------
// 数据模型与动作库常量
// ---------------------------------------------------------------------------
interface ExerciseItem {
  id: string
  name: string
  part: string
  muscle: string
  equipment: string
  level: string
  muscles: string
  tip: string
}

function makeExercise(
  id: string,
  name: string,
  part: string,
  muscle: string,
  equipment: string,
  level: string,
  muscles: string,
  tip: string
): ExerciseItem {
  const item: ExerciseItem = {
    id: id,
    name: name,
    part: part,
    muscle: muscle,
    equipment: equipment,
    level: level,
    muscles: muscles,
    tip: tip
  }
  return item
}

const EXERCISES: ExerciseItem[] = [
  makeExercise('push-up', '俯卧撑', '胸部', '胸大肌', '自重', '入门', '胸大肌 · 三角肌前束 · 肱三头肌', '核心收紧，身体保持一条直线，下放至胸部接近地面后推起。'),
  makeExercise('barbell-bench-press', '杠铃卧推', '胸部', '胸大肌', '杠铃', '进阶', '胸大肌 · 三角肌前束 · 肱三头肌', '肩胛后收下沉，杠铃下放至胸部中段，推起时呼气。'),
  makeExercise('dumbbell-fly', '哑铃飞鸟', '胸部', '胸大肌', '哑铃', '进阶', '胸大肌', '肘部保持微屈，双臂向两侧展开至胸部充分拉伸，再夹拢。'),
  makeExercise('cable-crossover', '绳索夹胸', '胸部', '胸大肌', '器械', '进阶', '胸大肌内侧', '身体略前倾，双手向身体中线夹拢，顶峰收缩 1 秒。'),
  makeExercise('pull-up', '引体向上', '背部', '背阔肌', '自重', '进阶', '背阔肌 · 肱二头肌', '肩胛下沉，将胸部引向横杆，避免摆动借力。'),
  makeExercise('barbell-row', '杠铃划船', '背部', '背阔肌', '杠铃', '进阶', '背阔肌 · 斜方肌 · 菱形肌', '髋部后移、背部平直，将杠铃拉向腹部，肩胛主动后收。'),
  makeExercise('seated-row', '坐姿划船', '背部', '菱形肌', '器械', '入门', '背阔肌 · 菱形肌', '挺胸收腹，肘部贴近身体向后拉，挤压肩胛骨。'),
  makeExercise('lat-pulldown', '高位下拉', '背部', '背阔肌', '器械', '入门', '背阔肌', '下拉至锁骨上方，控制还原，避免耸肩和身体后仰。'),
  makeExercise('band-pulldown', '弹力带高位下拉', '背部', '背阔肌', '弹力带', '入门', '背阔肌', '固定弹力带于高位，下拉至锁骨，控制还原。'),
  makeExercise('overhead-press', '站姿推举', '肩部', '三角肌前束', '哑铃', '进阶', '三角肌前中束', '核心收紧，将哑铃推至头顶上方，避免腰部过度反弓。'),
  makeExercise('lateral-raise', '侧平举', '肩部', '三角肌中束', '哑铃', '入门', '三角肌中束', '肘部微屈，抬至与肩同高即可，避免耸肩借力。'),
  makeExercise('band-lateral-raise', '弹力带侧平举', '肩部', '三角肌中束', '弹力带', '入门', '三角肌中束', '踩住弹力带，双臂向两侧抬至与肩同高。'),
  makeExercise('face-pull', '面拉', '肩部', '三角肌后束', '器械', '入门', '三角肌后束 · 上背', '拉向面部，肘部外展高于手腕，改善圆肩体态。'),
  makeExercise('biceps-curl', '二头弯举', '手臂', '肱二头肌', '哑铃', '入门', '肱二头肌', '上臂贴紧身体，避免摆动借力，顶峰收缩。'),
  makeExercise('triceps-pushdown', '绳索下压', '手臂', '肱三头肌', '器械', '入门', '肱三头肌', '肘部固定于身体两侧，下压至手臂完全伸直。'),
  makeExercise('squat', '深蹲', '腿部', '股四头肌', '杠铃', '进阶', '股四头肌 · 臀大肌', '膝盖与脚尖同向，下蹲至大腿接近平行地面，保持躯干稳定。'),
  makeExercise('lunge', '弓步蹲', '腿部', '股四头肌', '哑铃', '入门', '股四头肌 · 臀大肌', '前膝与脚尖同向，身体垂直下沉，后膝轻触地面。'),
  makeExercise('leg-press', '腿举', '腿部', '股四头肌', '器械', '入门', '股四头肌 · 臀大肌', '下放至膝盖约 90 度，避免完全锁死膝关节。'),
  makeExercise('leg-curl', '腿弯举', '腿部', '腘绳肌', '器械', '入门', '腘绳肌', '控制离心下放，顶峰收缩大腿后侧。'),
  makeExercise('band-squat', '弹力带深蹲', '腿部', '股四头肌', '弹力带', '入门', '股四头肌 · 臀大肌', '踩住弹力带下蹲，起身时保持弹力带张力。'),
  makeExercise('plank', '平板支撑', '核心', '腹直肌', '自重', '入门', '腹横肌 · 腹直肌', '身体保持一条直线，收紧核心与臀部，避免塌腰。'),
  makeExercise('crunch', '卷腹', '核心', '腹直肌', '自重', '入门', '腹直肌', '下背贴地，卷起上背而非颈部，呼气时收缩腹部。'),
  makeExercise('hanging-leg-raise', '悬垂举腿', '核心', '腹直肌', '自重', '熟练', '腹直肌 · 髂腰肌', '控制身体不摆动，抬腿至与地面平行或更高。')
]

const PART_OPTIONS: string[] = ['全部', '胸部', '背部', '肩部', '手臂', '腿部', '核心']

interface PartMusclesEntry {
  part: string
  muscles: string[]
}

const PART_MUSCLES: PartMusclesEntry[] = [
  { part: '胸部', muscles: ['胸大肌'] },
  { part: '背部', muscles: ['背阔肌', '菱形肌'] },
  { part: '肩部', muscles: ['三角肌前束', '三角肌中束', '三角肌后束'] },
  { part: '手臂', muscles: ['肱二头肌', '肱三头肌'] },
  { part: '腿部', muscles: ['股四头肌', '腘绳肌'] },
  { part: '核心', muscles: ['腹直肌'] }
]

const EQUIPMENT_ORDER: string[] = ['杠铃', '哑铃', '器械', '弹力带', '自重']

function getMusclesForPart(part: string): string[] {
  for (let index = 0; index < PART_MUSCLES.length; index++) {
    if (PART_MUSCLES[index].part === part) {
      return PART_MUSCLES[index].muscles
    }
  }
  return []
}

@Entry
@Component
export struct ExerciseLibraryPage {
  @State private query: string = ''
  @State private selectedPart: string = '全部'
  @State private selectedMuscle: string = '全部肌群'
  @State private favOnly: boolean = false
  @State private favoriteIds: string[] = []
  @State private sheetVisible: boolean = false
  @State private selectedId: string = ''
  @State private ctaBusy: boolean = false
  @State private toastVisible: boolean = false
  @State private toastMessage: string = ''
  @State private searchFocused: boolean = false
  @State private pressedBack: boolean = false
  @State private pressedFavFilter: boolean = false
  @State private pressedCardId: string = ''
  @State private pressedHeartId: string = ''
  @State private pressedClose: boolean = false
  @State private pressedCta: boolean = false
  @State private topInset: number = 50
  @State private bottomInset: number = 0
  @State private failedGifIds: string[] = []
  private win: window.Window | null = null
  private toastTimer: number = -1
  private ctaTimer: number = -1

  aboutToAppear(): void {
    this.loadFavorites()
    const host = this.getUIContext().getHostContext()
    if (host === undefined) {
      return
    }
    window.getLastWindow(host).then((win: window.Window) => {
      this.win = win
      win.setWindowLayoutFullScreen(true).then(() => {
        this.readAvoidAreas()
        win.on('avoidAreaChange', this.handleAvoidAreaChange)
      })
    })
  }

  aboutToDisappear(): void {
    if (this.win) {
      this.win.off('avoidAreaChange', this.handleAvoidAreaChange)
      this.win.setWindowLayoutFullScreen(false)
      this.win = null
    }
    if (this.toastTimer >= 0) {
      clearTimeout(this.toastTimer)
      this.toastTimer = -1
    }
    if (this.ctaTimer >= 0) {
      clearTimeout(this.ctaTimer)
      this.ctaTimer = -1
    }
  }

  private handleAvoidAreaChange = (data: window.AvoidAreaOptions): void => {
    this.readAvoidAreas()
  }

  private readAvoidAreas(): void {
    if (!this.win) {
      return
    }
    const systemArea: window.AvoidArea = this.win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
    const topPx: number = systemArea.topRect.height
    if (topPx > 0) {
      this.topInset = this.getUIContext().px2vp(topPx)
    }
    const navArea: window.AvoidArea = this.win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
    const bottomPx: number = navArea.bottomRect.height
    if (bottomPx > 0) {
      this.bottomInset = this.getUIContext().px2vp(bottomPx)
    }
  }

  // -------------------------------------------------------------------------
  // 收藏
  // -------------------------------------------------------------------------
  private async loadFavorites(): Promise<void> {
    try {
      await FavoriteExerciseService.load()
    } catch (e) {
      // 持久化失败不影响主流程。
    }
    this.favoriteIds = FavoriteExerciseService.getFavoriteIds()
  }

  private isFav(id: string): boolean {
    return this.favoriteIds.indexOf(id) >= 0
  }

  private toggleFav(id: string): void {
    FavoriteExerciseService.toggleFavorite(id)
    this.favoriteIds = FavoriteExerciseService.getFavoriteIds()
  }

  private markGifFailed(id: string): void {
    if (this.failedGifIds.indexOf(id) === -1) {
      this.failedGifIds.push(id)
    }
  }

  private isGifFailed(id: string): boolean {
    return this.failedGifIds.indexOf(id) !== -1
  }

  // -------------------------------------------------------------------------
  // 筛选
  // -------------------------------------------------------------------------
  private matchesFilters(item: ExerciseItem): boolean {
    if (this.favOnly && this.favoriteIds.indexOf(item.id) < 0) {
      return false
    }
    if (this.selectedPart !== '全部' && item.part !== this.selectedPart) {
      return false
    }
    if (this.selectedMuscle !== '全部肌群' && item.muscle !== this.selectedMuscle) {
      return false
    }
    const normalizedQuery: string = this.query.trim()
    if (normalizedQuery.length > 0) {
      const haystack: string =
        item.name + ' ' + item.part + ' ' + item.muscle + ' ' + item.equipment + ' ' + item.muscles
      if (haystack.indexOf(normalizedQuery) < 0) {
        return false
      }
    }
    return true
  }

  private filteredExercises(): ExerciseItem[] {
    const result: ExerciseItem[] = []
    for (let index = 0; index < EXERCISES.length; index++) {
      if (this.matchesFilters(EXERCISES[index])) {
        result.push(EXERCISES[index])
      }
    }
    return result
  }

  private groupItems(equipment: string): ExerciseItem[] {
    const filtered: ExerciseItem[] = this.filteredExercises()
    const result: ExerciseItem[] = []
    for (let index = 0; index < filtered.length; index++) {
      if (filtered[index].equipment === equipment) {
        result.push(filtered[index])
      }
    }
    return result
  }

  private muscleOptions(): string[] {
    const result: string[] = ['全部肌群']
    const muscles: string[] = getMusclesForPart(this.selectedPart)
    for (let index = 0; index < muscles.length; index++) {
      result.push(muscles[index])
    }
    return result
  }

  private selectPart(part: string): void {
    this.selectedPart = part
    this.selectedMuscle = '全部肌群'
  }

  private selectMuscle(muscle: string): void {
    this.selectedMuscle = muscle
  }

  private toggleFavOnly(): void {
    this.favOnly = !this.favOnly
  }

  // -------------------------------------------------------------------------
  // 弹层 / toast
  // -------------------------------------------------------------------------
  private currentExercise(): ExerciseItem {
    for (let index = 0; index < EXERCISES.length; index++) {
      if (EXERCISES[index].id === this.selectedId) {
        return EXERCISES[index]
      }
    }
    return EXERCISES[0]
  }

  private openSheet(id: string): void {
    this.selectedId = id
    this.ctaBusy = false
    this.sheetVisible = true
  }

  private closeSheet(): void {
    if (!this.sheetVisible) {
      return
    }
    this.sheetVisible = false
    try {
      this.getUIContext().getFocusController().requestFocus('lib-card-' + this.selectedId)
    } catch (e) {
      // 焦点还原失败不影响主流程。
    }
  }

  private showToast(message: string): void {
    this.toastMessage = message
    this.toastVisible = true
    if (this.toastTimer >= 0) {
      clearTimeout(this.toastTimer)
    }
    this.toastTimer = setTimeout(() => {
      this.toastVisible = false
    }, 1900)
  }

  private addToPlan(): void {
    if (this.ctaBusy) {
      return
    }
    this.ctaBusy = true
    const name: string = this.currentExercise().name
    if (this.ctaTimer >= 0) {
      clearTimeout(this.ctaTimer)
    }
    this.ctaTimer = setTimeout(() => {
      this.ctaBusy = false
      this.showToast('已把「' + name + '」加入今日计划')
    }, 1600)
  }

  private goBack(): void {
    try {
      this.getUIContext().getRouter().back()
    } catch (e) {
      // 无历史栈时留在当前页。
    }
  }

  // -------------------------------------------------------------------------
  // 构建
  // -------------------------------------------------------------------------
  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(LibPalette.BG_BASE)

      Column() {
        this.buildTopBar()

        Scroll() {
          Column({ space: 14 }) {
            this.buildSearch()

            this.buildPartChips()

            if (this.selectedPart !== '全部') {
              this.buildMuscleChips()
            }

            ForEach(EQUIPMENT_ORDER, (equipment: string) => {
              if (this.groupItems(equipment).length > 0) {
                this.buildGroupSection(equipment)
              }
            }, (equipment: string) => equipment)

            if (this.filteredExercises().length === 0) {
              this.buildEmptyState()
            }

            Text('动作数据为演示内容；点击卡片查看动作要点，点右上角心形可收藏。')
              .width('100%')
              .fontSize(11)
              .fontColor(LibPalette.WHITE_54)
              .textAlign(TextAlign.Center)
              .lineHeight(18)
              .padding({ left: 6, right: 6, top: 2, bottom: 0 })
          }
          .width('100%')
          .padding({
            left: 16,
            right: 16,
            top: 8,
            bottom: 30 + this.bottomInset
          })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')

      if (this.sheetVisible) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(LibPalette.BACKDROP)
          .transition(TransitionEffect.OPACITY.animation({
            duration: MotionTokens.DURATION_OVERLAY,
            curve: MotionTokens.EASE_MOTION
          }))
          .onClick(() => {
            this.closeSheet()
          })
      }

      if (this.sheetVisible) {
        this.buildSheet()
      }

      if (this.toastVisible) {
        Row() {
          Text(this.toastMessage)
            .fontSize(13)
            .lineHeight(18)
            .fontColor(LibPalette.TEXT_HI)
            .textAlign(TextAlign.Center)
        }
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .constraintSize({ maxWidth: 320 })
        .backgroundColor(LibPalette.TOAST_BG)
        .borderRadius(999)
        .border({ width: 1, color: LibPalette.CHIP_BORDER })
        .margin({ bottom: 30 + this.bottomInset })
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.translate({ y: 10 }))
          .animation({
            duration: MotionTokens.DURATION_COLOR_BASE,
            curve: MotionTokens.EASE_MOTION
          }))
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildTopBar() {
    Row() {
      Column() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20)
          .fontColor([LibPalette.WHITE_70])
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(LibPalette.GLASS_BTN_BG)
      .border({ width: 1, color: LibPalette.GLASS_BTN_BORDER })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.pressedBack = true
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.pressedBack = false
        }
      })
      .scale({
        x: this.pressedBack ? MotionTokens.PRESS_BACK : 1,
        y: this.pressedBack ? MotionTokens.PRESS_BACK : 1
      })
      .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
      .onClick(() => {
        this.goBack()
      })

      Text('动作库')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(LibPalette.TEXT_HI)

      Column() {
        if (this.favOnly) {
          SymbolGlyph($r('sys.symbol.heart_fill'))
            .fontSize(20)
            .fontColor([LibPalette.ACCENT])
        } else {
          SymbolGlyph($r('sys.symbol.heart'))
            .fontSize(20)
            .fontColor([LibPalette.WHITE_70])
        }
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.favOnly ? LibPalette.FAV_FILTER_ON_BG : LibPalette.GLASS_BTN_BG)
      .border({ width: 1, color: this.favOnly ? LibPalette.CHIP_ACTIVE_BORDER : LibPalette.GLASS_BTN_BORDER })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.pressedFavFilter = true
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.pressedFavFilter = false
        }
      })
      .scale({
        x: this.pressedFavFilter ? MotionTokens.PRESS_BACK : 1,
        y: this.pressedFavFilter ? MotionTokens.PRESS_BACK : 1
      })
      .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
      .onClick(() => {
        this.toggleFavOnly()
      })
    }
    .width('100%')
    .padding({ top: this.topInset, left: 16, right: 16, bottom: 12 })
  }

  @Builder
  private buildSearch() {
    Row({ space: 9 }) {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(17)
        .fontColor([LibPalette.WHITE_40])

      TextInput({ text: this.query, placeholder: '搜索动作、肌群或器械' })
        .layoutWeight(1)
        .height(44)
        .fontSize(14)
        .fontColor(LibPalette.TEXT_HI)
        .placeholderColor(LibPalette.WHITE_40)
        .placeholderFont({ size: 14 })
        .caretColor(LibPalette.ACCENT)
        .backgroundColor(Color.Transparent)
        .padding({ left: 0, right: 0 })
        .onChange((value: string) => {
          this.query = value
        })
        .onFocus(() => {
          this.searchFocused = true
        })
        .onBlur(() => {
          this.searchFocused = false
        })
    }
    .width('100%')
    .height(44)
    .padding({ left: 14, right: 14 })
    .backgroundColor(this.searchFocused ? 'rgba(255,255,255,0.055)' : LibPalette.CHIP_BG)
    .borderRadius(14)
    .border({ width: 1, color: this.searchFocused ? LibPalette.ACCENT : LibPalette.CHIP_BORDER })
    .outline({ width: this.searchFocused ? 3 : 0, color: LibPalette.FOCUS_GLOW })
    .animation({ duration: MotionTokens.DURATION_COLOR_FAST, curve: MotionTokens.EASE_MOTION })
  }

  @Builder
  private buildChip(label: string, active: boolean) {
    Text(label)
      .fontSize(13)
      .fontWeight(active ? 600 : 500)
      .fontColor(active ? LibPalette.ACCENT : LibPalette.WHITE_70)
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .backgroundColor(active ? LibPalette.CHIP_ACTIVE_BG : LibPalette.CHIP_BG)
      .borderRadius(999)
      .border({ width: 1, color: active ? LibPalette.CHIP_ACTIVE_BORDER : LibPalette.CHIP_BORDER })
      .animation({ duration: MotionTokens.DURATION_COLOR_FAST, curve: MotionTokens.EASE_MOTION })
  }

  @Builder
  private buildSmallChip(label: string, active: boolean) {
    Text(label)
      .fontSize(12)
      .fontWeight(active ? 600 : 500)
      .fontColor(active ? LibPalette.ACCENT : LibPalette.WHITE_70)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(active ? LibPalette.CHIP_ACTIVE_BG : LibPalette.CHIP_BG)
      .borderRadius(999)
      .border({ width: 1, color: active ? LibPalette.CHIP_ACTIVE_BORDER : LibPalette.CHIP_BORDER })
      .animation({ duration: MotionTokens.DURATION_COLOR_FAST, curve: MotionTokens.EASE_MOTION })
  }

  @Builder
  private buildPartChips() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(PART_OPTIONS, (part: string) => {
          Column() {
            this.buildChip(part, this.selectedPart === part)
          }
          .onClick(() => {
            this.selectPart(part)
          })
        }, (part: string) => part)
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }

  @Builder
  private buildMuscleChips() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(this.muscleOptions(), (muscle: string) => {
          Column() {
            this.buildSmallChip(muscle, this.selectedMuscle === muscle)
          }
          .onClick(() => {
            this.selectMuscle(muscle)
          })
        }, (muscle: string) => muscle)
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .margin({ top: -6 })
  }

  @Builder
  private buildHeartIcon(fav: boolean, size: number) {
    if (fav) {
      SymbolGlyph($r('sys.symbol.heart_fill'))
        .fontSize(size)
        .fontColor([LibPalette.ACCENT])
    } else {
      SymbolGlyph($r('sys.symbol.heart'))
        .fontSize(size)
        .fontColor([LibPalette.WHITE_70])
    }
  }

  @Builder
  private buildCard(item: ExerciseItem) {
    Column() {
      Stack({ alignContent: Alignment.TopEnd }) {
        if (this.isGifFailed(item.id)) {
          Column() {
            Image($rawfile('pencil-lucide-dumbbell.svg'))
              .width(30)
              .height(30)
              .fillColor(LibPalette.WHITE_32)
          }
          .width('100%')
          .aspectRatio(4 / 3)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor(LibPalette.MEDIA_BG)
        } else {
          Image($rawfile('exercise-gifs/' + item.id + '.gif'))
            .width('100%')
            .aspectRatio(4 / 3)
            .objectFit(ImageFit.Cover)
            .alt(item.name + ' 动作演示')
            .onError(() => {
              this.markGifFailed(item.id)
            })
        }

        Column() {
          this.buildHeartIcon(this.isFav(item.id), 16)
        }
        .width(30)
        .height(30)
        .borderRadius(15)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.isFav(item.id) ? LibPalette.FAV_BG_ACTIVE : LibPalette.FAV_BG)
        .border({ width: 1, color: LibPalette.FAV_BORDER })
        .margin({ top: 8, right: 8 })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.pressedHeartId = item.id
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.pressedHeartId = ''
          }
        })
        .scale({
          x: this.pressedHeartId === item.id ? PRESS_HEART_SCALE : 1,
          y: this.pressedHeartId === item.id ? PRESS_HEART_SCALE : 1
        })
        .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
        .onClick(() => {
          this.toggleFav(item.id)
        })
      }
      .width('100%')

      Column() {
        Text(item.name)
          .width('100%')
          .fontSize(12)
          .fontWeight(600)
          .fontColor(LibPalette.TEXT_HI)
          .lineHeight(15)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 8, bottom: 9 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .borderRadius(14)
    .backgroundColor(LibPalette.CARD_BG)
    .border({ width: 1, color: LibPalette.STROKE })
    .clip(true)
    .key('lib-card-' + item.id)
    .focusable(true)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedCardId = item.id
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedCardId = ''
      }
    })
    .scale({
      x: this.pressedCardId === item.id ? MotionTokens.PRESS_PRIMARY : 1,
      y: this.pressedCardId === item.id ? MotionTokens.PRESS_PRIMARY : 1
    })
    .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
    .onClick(() => {
      this.openSheet(item.id)
    })
  }

  @Builder
  private buildGroupSection(equipment: string) {
    Column({ space: 10 }) {
      Row() {
        Text(equipment)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(LibPalette.TEXT_HI)
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      Grid() {
        ForEach(this.groupItems(equipment), (item: ExerciseItem) => {
          GridItem() {
            this.buildCard(item)
          }
        }, (item: ExerciseItem) => item.id)
      }
      .columnsTemplate('1fr 1fr 1fr')
      .columnsGap(10)
      .rowsGap(10)
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private buildEmptyState() {
    Column({ space: 6 }) {
      Column() {
        Column({ space: 2 }) {
          Row({ space: 2 }) {
            Rect({ width: 7, height: 7, radius: 2 })
              .fillOpacity(0)
              .stroke(LibPalette.WHITE_40)
              .strokeWidth(1.6)
            Rect({ width: 7, height: 7, radius: 2 })
              .fillOpacity(0)
              .stroke(LibPalette.WHITE_40)
              .strokeWidth(1.6)
          }
          Row({ space: 2 }) {
            Rect({ width: 7, height: 7, radius: 2 })
              .fillOpacity(0)
              .stroke(LibPalette.WHITE_40)
              .strokeWidth(1.6)
            Rect({ width: 7, height: 7, radius: 2 })
              .fillOpacity(0)
              .stroke(LibPalette.WHITE_40)
              .strokeWidth(1.6)
          }
        }
      }
      .width(46)
      .height(46)
      .borderRadius(23)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('rgba(255,255,255,0.05)')
      .border({ width: 1, color: LibPalette.CHIP_BORDER })
      .margin({ bottom: 6 })

      Text(this.emptyTitle())
        .fontSize(14)
        .fontWeight(600)
        .fontColor(LibPalette.TEXT_HI)

      Text(this.emptyHint())
        .fontSize(12)
        .lineHeight(18)
        .fontColor(LibPalette.WHITE_54)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ top: 38, bottom: 34, left: 20, right: 20 })
  }

  @Builder
  private buildSheetRow(key: string, value: string) {
    Row() {
      Text(key)
        .fontSize(13)
        .fontColor(LibPalette.WHITE_54)

      Text(value)
        .layoutWeight(1)
        .fontSize(13)
        .fontWeight(600)
        .fontColor(LibPalette.TEXT_HI)
        .textAlign(TextAlign.End)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ top: 13, bottom: 13 })
    .border({ width: { bottom: 1 }, color: LibPalette.HAIRLINE })
  }

  @Builder
  private buildSheet() {
    Column() {
      Row()
        .width(40)
        .height(4)
        .borderRadius(999)
        .backgroundColor(LibPalette.HANDLE)
        .margin({ bottom: 16 })

      Stack({ alignContent: Alignment.TopStart }) {
        if (this.isGifFailed(this.currentExercise().id)) {
          Column() {
            Image($rawfile('pencil-lucide-dumbbell.svg'))
              .width(36)
              .height(36)
              .fillColor(LibPalette.WHITE_32)
          }
          .width('100%')
          .aspectRatio(16 / 9)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .borderRadius(14)
        } else {
          Image($rawfile('exercise-gifs/' + this.currentExercise().id + '.gif'))
            .width('100%')
            .aspectRatio(16 / 9)
            .objectFit(ImageFit.Contain)
            .borderRadius(14)
            .alt(this.currentExercise().name + ' 动作演示')
            .onError(() => {
              this.markGifFailed(this.currentExercise().id)
            })
        }

        Text('动作演示')
          .fontSize(11)
          .fontWeight(600)
          .fontColor(LibPalette.TEXT_HI)
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .backgroundColor(LibPalette.FAV_BG)
          .borderRadius(999)
          .border({ width: 1, color: LibPalette.FAV_BORDER })
          .margin({ left: 10, top: 10 })
      }
      .width('100%')
      .backgroundColor(LibPalette.MEDIA_BG_SHEET)
      .borderRadius(14)
      .clip(true)
      .margin({ bottom: 16 })

      Row({ space: 12 }) {
        Text(this.currentExercise().name)
          .layoutWeight(1)
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor(LibPalette.TEXT_HI)
          .lineHeight(25)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Column() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(18)
            .fontColor([LibPalette.WHITE_70])
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(LibPalette.GLASS_CLOSE_BG)
        .border({ width: 1, color: LibPalette.CHIP_BORDER })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.pressedClose = true
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.pressedClose = false
          }
        })
        .scale({
          x: this.pressedClose ? MotionTokens.PRESS_ICON : 1,
          y: this.pressedClose ? MotionTokens.PRESS_ICON : 1
        })
        .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
        .onClick(() => {
          this.closeSheet()
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.sheetTags(), (tag: string) => {
          Text(tag)
            .fontSize(11.5)
            .fontWeight(600)
            .fontColor(LibPalette.ACCENT)
            .padding({ left: 11, right: 11, top: 4, bottom: 4 })
            .backgroundColor(LibPalette.TAG_BG)
            .borderRadius(999)
            .border({ width: 1, color: LibPalette.TAG_BORDER })
            .margin({ right: 7, bottom: 7 })
        }, (tag: string) => tag)
      }
      .width('100%')
      .margin({ top: 12, bottom: -7 })

      Column() {
        this.buildSheetRow('目标肌群', this.currentExercise().muscles)
        this.buildSheetRow('器械', this.currentExercise().equipment)
        this.buildSheetRow('难度', this.currentExercise().level)
      }
      .width('100%')
      .margin({ top: 6 })

      Text(this.currentExercise().tip)
        .width('100%')
        .fontSize(13)
        .lineHeight(22)
        .fontColor(LibPalette.WHITE_62)
        .margin({ top: 14 })

      Button(this.ctaBusy ? '已加入今日计划' : '加入训练计划')
        .type(ButtonType.Normal)
        .width('100%')
        .height(52)
        .margin({ top: 18 })
        .borderRadius(16)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(LibPalette.ON_ACCENT)
        .backgroundColor(LibPalette.ACCENT)
        .opacity(this.ctaBusy ? 0.92 : 1)
        .enabled(!this.ctaBusy)
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.pressedCta = true
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.pressedCta = false
          }
        })
        .scale({
          x: this.pressedCta ? MotionTokens.PRESS_PRIMARY : 1,
          y: this.pressedCta ? MotionTokens.PRESS_PRIMARY : 1
        })
        .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
        .onClick(() => {
          this.addToPlan()
        })
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 12, bottom: 20 + this.bottomInset })
    .constraintSize({ maxHeight: '84%' })
    .backgroundColor(LibPalette.SHEET_BG)
    .borderRadius({ topLeft: 26, topRight: 26 })
    .border({ width: { left: 1, right: 1, top: 1, bottom: 0 }, color: LibPalette.CHIP_BORDER })
    .transition(TransitionEffect.translate({ y: '100%' })
      .animation({
        duration: MotionTokens.DURATION_PANEL,
        curve: MotionTokens.EASE_PANEL
      }))
  }

  private sheetTags(): string[] {
    const exercise: ExerciseItem = this.currentExercise()
    const tags: string[] = []
    tags.push(exercise.part)
    tags.push(exercise.equipment)
    tags.push(exercise.level)
    return tags
  }

  private emptyTitle(): string {
    if (this.favOnly) {
      return '暂无收藏'
    }
    if (this.query.trim().length > 0) {
      return '没有匹配的动作'
    }
    return '该部位暂无动作'
  }

  private emptyHint(): string {
    if (this.favOnly) {
      return '点右上角心形，收藏常用动作'
    }
    if (this.query.trim().length > 0) {
      return '换个关键词试试'
    }
    return '换个部位或肌群筛选试试'
  }
}
