/**
 * ProfileEditContent —— 「编辑资料」界面体（供 PencilProfileEditPage 薄壳承载）。
 *
 * 视觉全量沿用 Pencil 主线：页底 PrototypeTokens.BG_INK、组卡片 WHITE_A03 + 圆角 22 + WHITE_A10 描边、
 * 组内行 WHITE_A06 分隔线、强调色 ACCENT；底部「保存」为厚底按压按钮（MotionTokens）。
 * 交互骨架参考微信资料页：分组行 → 底部编辑面板（文本 / 单选 / 头像 / 二维码 / 说明），点行即改。
 *
 * 数据边界（勿混）：
 *  - UserProfileService：昵称、头像（色键 + 图片路径）、性别、身高、出生年份、经验、体重单位；
 *  - ProfileExtrasService：地区、拍一拍、个性签名、常用健身房（仅本机，不进云快照信封）。
 *
 * 头像图片经系统图库选择器选取（免相册权限）、压缩后写入应用沙箱；未选图时回落「昵称首字 + 色键」。
 */
import { Context } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { MotionTokens } from '../../../common/styles/DesignTokens'
import { PrototypeTokens } from '../../../common/styles/PrototypeTokens'
import UserProfileService, {
  UserProfile,
  WeightUnit,
  Gender,
  Experience
} from '../../../common/services/UserProfileService'
import ProfileExtrasService, { ProfileExtras } from '../../../common/services/ProfileExtrasService'
import AvatarImageService, { AvatarPickResult } from '../../../common/services/AvatarImageService'
import SessionManager, { SessionSnapshot } from '../../../common/services/SessionManager'
import CloudSyncService from '../../../shared/services/CloudSyncService'
import { AVATAR_KEYS, avatarTintOf, avatarInitialOf } from './AvatarTint'

/** 昵称最大长度（与安卓 ProfileEditViewModel.NICKNAME_MAX 一致）。 */
const NAME_MAX: number = 20

/** 行标识（点击分发用）。 */
class Field {
  static readonly AVATAR: string = 'avatar'
  static readonly NAME: string = 'name'
  static readonly GENDER: string = 'gender'
  static readonly REGION: string = 'region'
  static readonly PHONE: string = 'phone'
  static readonly ACCOUNT: string = 'account'
  static readonly TICKLE: string = 'tickle'
  static readonly WHATS_UP: string = 'whatsUp'
  static readonly WEIGHT_UNIT: string = 'weightUnit'
  static readonly GYM: string = 'gym'
  static readonly HEIGHT: string = 'height'
  static readonly BIRTH_YEAR: string = 'birthYear'
  static readonly EXPERIENCE: string = 'experience'
}

/** 底部面板形态。 */
class SheetMode {
  static readonly NONE: string = 'none'
  static readonly TEXT: string = 'text'
  static readonly CHOICE: string = 'choice'
  static readonly AVATAR: string = 'avatar'
  static readonly INFO: string = 'info'
}

interface ChoiceOption {
  label: string
  value: string
}

@Component
export struct ProfileEditContent {
  // ── 资料字段 ────────────────────────────────────────────────────
  @State private nickname: string = ''
  @State private avatarKey: string = ''
  @State private gender: Gender = ''
  @State private experience: Experience = ''
  @State private heightText: string = ''
  @State private birthYearText: string = ''
  @State private weightUnit: WeightUnit = 'kg'
  @State private avatarImagePath: string = ''
  @State private region: string = ''
  @State private tickle: string = ''
  @State private whatsUp: string = ''
  @State private gymAddress: string = ''
  /** 登录会话派生的只读信息（脱敏手机号 / 档案号 / 昵称首字回落）。 */
  @State private sessionPhone: string = ''
  @State private sessionUserId: string = ''
  @State private fallbackName: string = ''

  // ── 页面态 ──────────────────────────────────────────────────────
  @State private topInsetVp: number = 0
  @State private pressedField: string = ''
  @State private backPressed: boolean = false
  @State private savePressed: boolean = false
  @State private dirty: boolean = false
  @State private saving: boolean = false
  @State private toastMessage: string = ''
  @State private toastVisible: boolean = false

  // ── 底部面板态 ───────────────────────────────────────────────────
  @State private sheetMode: string = SheetMode.NONE
  @State private sheetField: string = ''
  @State private sheetTitle: string = ''
  @State private sheetHint: string = ''
  @State private sheetDraft: string = ''
  @State private sheetMaxLen: number = NAME_MAX
  @State private sheetNumeric: boolean = false
  @State private sheetMultiline: boolean = false

  private toastTimer: number = -1
  /** 进入页面时的头像路径：保存成功才删旧文件，未保存离开时删掉本次新选的文件。 */
  private loadedAvatarImagePath: string = ''
  /** 是否已成功保存：决定离开页面时清理哪一份头像文件。 */
  private saved: boolean = false
  /** 是否已发起返回：自动返回与手动返回不能退两次。 */
  private leaving: boolean = false
  private picking: boolean = false

  private contextOrNull(): Context | null {
    const host = this.getUIContext().getHostContext()
    return host === undefined || host === null ? null : host as Context
  }

  private async resolveTopInset(): Promise<void> {
    const context: Context | null = this.contextOrNull()
    if (context === null) {
      return
    }
    try {
      const mainWindow: window.Window = await window.getLastWindow(context)
      const avoidArea: window.AvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      this.topInsetVp = this.getUIContext().px2vp(avoidArea.topRect.height)
    } catch (error) {
      this.topInsetVp = 0
    }
  }

  async aboutToAppear(): Promise<void> {
    await this.resolveTopInset()
    await this.load()
  }

  aboutToDisappear(): void {
    if (this.toastTimer >= 0) {
      clearTimeout(this.toastTimer)
    }
    // 选了图但没保存：删掉这次生成的文件（旧头像仍在原位，资料未变）。
    if (!this.saved && this.avatarImagePath !== this.loadedAvatarImagePath) {
      AvatarImageService.remove(this.avatarImagePath)
    }
  }

  private async load(): Promise<void> {
    const context: Context | null = this.contextOrNull()
    if (context === null) {
      return
    }
    const profile: UserProfile = await UserProfileService.loadProfile(context)
    const extras: ProfileExtras = await ProfileExtrasService.loadExtras(context)
    this.nickname = profile.nickname
    this.avatarKey = profile.avatar
    this.gender = profile.gender
    this.experience = profile.experience
    this.weightUnit = profile.weightUnit
    this.heightText = profile.heightCm > 0 ? profile.heightCm.toString() : ''
    this.birthYearText = profile.birthYear > 0 ? profile.birthYear.toString() : ''
    // 文件已被系统清理时不展示失效路径，回到色键占位。
    this.avatarImagePath = AvatarImageService.exists(profile.avatarImagePath) ? profile.avatarImagePath : ''
    this.loadedAvatarImagePath = this.avatarImagePath
    this.region = extras.region
    this.tickle = extras.tickle
    this.whatsUp = extras.whatsUp
    this.gymAddress = extras.gymAddress
    this.dirty = false
    // 首字与个人页同口径：本地昵称为空时回落到登录会话显示名。
    try {
      const session: SessionSnapshot | null = await SessionManager.getSession(context)
      if (session !== null) {
        this.fallbackName = session.displayName.trim()
        this.sessionPhone = session.phone.trim()
        this.sessionUserId = session.userId.trim()
      }
    } catch (error) {
      this.fallbackName = ''
    }
  }

  // ── 派生展示值 ──────────────────────────────────────────────────

  private displayName(): string {
    const trimmed: string = this.nickname.trim()
    return trimmed.length > 0 ? trimmed : this.fallbackName
  }

  private genderLabel(): string {
    if (this.gender === 'male') {
      return '男'
    }
    if (this.gender === 'female') {
      return '女'
    }
    return ''
  }

  private experienceLabel(): string {
    if (this.experience === 'beginner') {
      return '新手'
    }
    if (this.experience === 'intermediate') {
      return '进阶'
    }
    if (this.experience === 'advanced') {
      return '高阶'
    }
    return ''
  }

  private weightUnitLabel(): string {
    return this.weightUnit === 'lbs' ? '磅（lbs）' : '千克（kg）'
  }

  /** 手机号脱敏：前 3 + 6 星 + 后 2；过短则原样返回。 */
  private maskedPhone(): string {
    const phone: string = this.sessionPhone
    if (phone.length < 8) {
      return phone
    }
    return phone.substring(0, 3) + '******' + phone.substring(phone.length - 2)
  }

  /** 本机档案号：由登录账号哈希派生的稳定展示 ID（不落盘，避免另造一套账号体系）。 */
  private accountIdLabel(): string {
    const seed: string = this.sessionUserId.length > 0 ? this.sessionUserId : this.sessionPhone
    if (seed.length === 0) {
      return ''
    }
    let hash: number = 7
    for (let index = 0; index < seed.length; index++) {
      hash = (hash * 31 + seed.charCodeAt(index)) % 100000000
    }
    let padded: string = hash.toString()
    while (padded.length < 8) {
      padded = '0' + padded
    }
    return 'FT' + padded
  }

  // ── 基础动作 ────────────────────────────────────────────────────

  /** 返回上一页；重复调用只生效一次。 */
  private leavePage(): void {
    if (this.leaving) {
      return
    }
    this.leaving = true
    this.getUIContext().getRouter().back()
  }

  private showToast(message: string): void {
    this.toastMessage = message
    this.toastVisible = true
    if (this.toastTimer >= 0) {
      clearTimeout(this.toastTimer)
    }
    this.toastTimer = setTimeout(() => {
      this.toastVisible = false
    }, 1600)
  }

  private markDirty(): void {
    this.dirty = true
  }

  // ── 面板开合 ────────────────────────────────────────────────────

  private closeSheet(): void {
    this.sheetMode = SheetMode.NONE
    this.sheetField = ''
    this.sheetTitle = ''
    this.sheetHint = ''
    this.sheetDraft = ''
    this.sheetNumeric = false
    this.sheetMultiline = false
  }

  private openTextSheet(field: string, title: string, current: string, maxLen: number,
    numeric: boolean, multiline: boolean): void {
    this.sheetMode = SheetMode.TEXT
    this.sheetField = field
    this.sheetTitle = title
    this.sheetHint = ''
    this.sheetDraft = current
    this.sheetMaxLen = maxLen
    this.sheetNumeric = numeric
    this.sheetMultiline = multiline
  }

  private openChoiceSheet(field: string, title: string): void {
    this.sheetMode = SheetMode.CHOICE
    this.sheetField = field
    this.sheetTitle = title
    this.sheetHint = ''
    this.sheetDraft = ''
    this.sheetNumeric = false
    this.sheetMultiline = false
  }

  private openInfoSheet(title: string, hint: string): void {
    this.sheetMode = SheetMode.INFO
    this.sheetField = ''
    this.sheetTitle = title
    this.sheetHint = hint
    this.sheetDraft = ''
    this.sheetNumeric = false
    this.sheetMultiline = false
  }

  private openAvatarSheet(): void {
    this.sheetMode = SheetMode.AVATAR
    this.sheetField = Field.AVATAR
    this.sheetTitle = '头像'
    this.sheetHint = ''
    this.sheetDraft = ''
    this.sheetNumeric = false
    this.sheetMultiline = false
  }

  private onRowClick(field: string): void {
    if (field === Field.AVATAR) {
      this.openAvatarSheet()
      return
    }
    if (field === Field.NAME) {
      this.openTextSheet(Field.NAME, '更改名字', this.nickname, NAME_MAX, false, false)
      return
    }
    if (field === Field.GENDER) {
      this.openChoiceSheet(Field.GENDER, '性别')
      return
    }
    if (field === Field.REGION) {
      this.openTextSheet(Field.REGION, '所在地区', this.region, 24, false, false)
      return
    }
    if (field === Field.PHONE) {
      this.openInfoSheet('手机号', '手机号是登录凭证，绑定与更换请在「账号与安全」中完成；此处仅展示脱敏号码。')
      return
    }
    if (field === Field.ACCOUNT) {
      this.openInfoSheet('档案号', '档案号由登录账号自动生成，用于扫码识别与云同步定位，不需要手动维护。')
      return
    }
    if (field === Field.TICKLE) {
      this.openTextSheet(Field.TICKLE, '拍一拍', this.tickle, 20, false, false)
      return
    }
    if (field === Field.WHATS_UP) {
      this.openTextSheet(Field.WHATS_UP, '个性签名', this.whatsUp, 40, false, true)
      return
    }
    if (field === Field.WEIGHT_UNIT) {
      this.openChoiceSheet(Field.WEIGHT_UNIT, '体重单位')
      return
    }
    if (field === Field.GYM) {
      this.openTextSheet(Field.GYM, '常用健身房', this.gymAddress, 40, false, false)
      return
    }
    if (field === Field.HEIGHT) {
      this.openTextSheet(Field.HEIGHT, '身高（厘米）', this.heightText, 3, true, false)
      return
    }
    if (field === Field.BIRTH_YEAR) {
      this.openTextSheet(Field.BIRTH_YEAR, '出生年份', this.birthYearText, 4, true, false)
      return
    }
    if (field === Field.EXPERIENCE) {
      this.openChoiceSheet(Field.EXPERIENCE, '训练经验')
    }
  }

  // ── 面板提交 ────────────────────────────────────────────────────

  private commitText(): void {
    const value: string = this.sheetDraft.trim()
    const field: string = this.sheetField
    if (field === Field.NAME) {
      this.nickname = value.substring(0, NAME_MAX)
    } else if (field === Field.REGION) {
      this.region = value
    } else if (field === Field.TICKLE) {
      this.tickle = value
    } else if (field === Field.WHATS_UP) {
      this.whatsUp = value
    } else if (field === Field.GYM) {
      this.gymAddress = value
    } else if (field === Field.HEIGHT) {
      this.heightText = value
    } else if (field === Field.BIRTH_YEAR) {
      this.birthYearText = value
    } else {
      this.closeSheet()
      return
    }
    this.markDirty()
    this.closeSheet()
  }

  private commitChoice(value: string): void {
    const field: string = this.sheetField
    if (field === Field.GENDER) {
      if (value === 'male' || value === 'female') {
        this.gender = value
      } else {
        this.gender = ''
      }
    } else if (field === Field.EXPERIENCE) {
      if (value === 'beginner' || value === 'intermediate' || value === 'advanced') {
        this.experience = value
      } else {
        this.experience = ''
      }
    } else if (field === Field.WEIGHT_UNIT) {
      this.weightUnit = value === 'lbs' ? 'lbs' : 'kg'
    }
    this.markDirty()
    this.closeSheet()
  }

  private choiceOptions(): ChoiceOption[] {
    const field: string = this.sheetField
    if (field === Field.GENDER) {
      const options: ChoiceOption[] = [
        { label: '男', value: 'male' },
        { label: '女', value: 'female' },
        { label: '不显示', value: '' }
      ]
      return options
    }
    if (field === Field.EXPERIENCE) {
      const options: ChoiceOption[] = [
        { label: '新手（0–6 个月）', value: 'beginner' },
        { label: '进阶（6 个月–2 年）', value: 'intermediate' },
        { label: '高阶（2 年以上）', value: 'advanced' },
        { label: '未设置', value: '' }
      ]
      return options
    }
    if (field === Field.WEIGHT_UNIT) {
      const options: ChoiceOption[] = [
        { label: '千克（kg）', value: 'kg' },
        { label: '磅（lbs）', value: 'lbs' }
      ]
      return options
    }
    const empty: ChoiceOption[] = []
    return empty
  }

  private currentChoiceValue(): string {
    const field: string = this.sheetField
    if (field === Field.GENDER) {
      return this.gender
    }
    if (field === Field.EXPERIENCE) {
      return this.experience
    }
    if (field === Field.WEIGHT_UNIT) {
      return this.weightUnit
    }
    return ''
  }

  // ── 头像 ────────────────────────────────────────────────────────

  /** 从相册选一张头像：系统图库选择器免权限；取消静默，失败提示。 */
  private async pickAvatar(): Promise<void> {
    if (this.picking) {
      return
    }
    const context: Context | null = this.contextOrNull()
    if (context === null) {
      return
    }
    this.picking = true
    try {
      const result: AvatarPickResult = await AvatarImageService.pickAndCompress(context)
      if (result.ok) {
        // 已保存的旧图不在此删除：用户可能不保存直接返回，届时仍要用旧图。
        const previousPending: string = this.avatarImagePath
        this.avatarImagePath = result.path
        if (previousPending !== this.loadedAvatarImagePath) {
          await AvatarImageService.remove(previousPending)
        }
        this.markDirty()
      } else if (!result.cancelled) {
        this.showToast(result.message.length > 0 ? result.message : '图片读取失败，请重试')
      }
    } finally {
      this.picking = false
    }
  }

  /** 移除头像：只清路径并回收本次未保存的临时文件，磁盘清理由保存/离开统一处理。 */
  private removeAvatar(): void {
    const pending: string = this.avatarImagePath
    this.avatarImagePath = ''
    if (pending !== this.loadedAvatarImagePath) {
      AvatarImageService.remove(pending)
    }
    this.markDirty()
  }

  private selectAvatarKey(key: string): void {
    this.avatarKey = key
    this.markDirty()
  }

  // ── 完成 / 保存 ─────────────────────────────────────────────────

  private async finish(): Promise<void> {
    if (this.saving) {
      return
    }
    if (!this.dirty) {
      this.leavePage()
      return
    }
    await this.saveAll()
  }

  private async saveAll(): Promise<void> {
    const context: Context | null = this.contextOrNull()
    if (context === null) {
      this.showToast('保存失败：缺少运行环境')
      return
    }
    this.saving = true
    try {
      const heightValue: number = this.heightText.length > 0 ? Number(this.heightText) : 0
      const birthValue: number = this.birthYearText.length > 0 ? Number(this.birthYearText) : 0
      const profile: UserProfile = {
        nickname: this.nickname.trim(),
        avatar: this.avatarKey,
        weightUnit: this.weightUnit,
        heightCm: Number.isFinite(heightValue) ? heightValue : 0,
        gender: this.gender,
        birthYear: Number.isFinite(birthValue) ? birthValue : 0,
        experience: this.experience,
        avatarImagePath: this.avatarImagePath
      }
      await UserProfileService.saveProfile(context, profile)
      // 不做假成功：写入失败时停在页面并提示，由用户重试。
      if (UserProfileService.getLastPersistenceError().length > 0) {
        this.showToast('保存失败，请稍后重试')
        return
      }
      const extras: ProfileExtras = {
        region: this.region,
        tickle: this.tickle,
        whatsUp: this.whatsUp,
        gymAddress: this.gymAddress
      }
      await ProfileExtrasService.saveExtras(context, extras)
      if (ProfileExtrasService.getLastPersistenceError().length > 0) {
        this.showToast('保存失败，请稍后重试')
        return
      }
      this.saved = true
      // 换图成功：旧头像文件此时才可安全删除。
      if (this.loadedAvatarImagePath !== this.avatarImagePath) {
        await AvatarImageService.remove(this.loadedAvatarImagePath)
        this.loadedAvatarImagePath = this.avatarImagePath
      }
      this.dirty = false
      // 保存成功即触发后台同步：失败由 requestBackgroundSync 内部静默处理。
      await CloudSyncService.requestBackgroundSync(context)
      this.leavePage()
    } finally {
      this.saving = false
    }
  }

  // ── 渲染 ────────────────────────────────────────────────────────

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        this.buildHeader()
        Scroll() {
          Column({ space: 12 }) {
            this.buildIdentitySection()
            this.buildCardSection()
            this.buildPreferenceSection()
            this.buildBodySection()
            this.buildSaveButton()
            Text('个人信息仅用于本机展示；昵称、头像、身体档案与训练经验会随云快照同步到同一账号。')
              .fontFamily('Noto Sans SC')
              .fontSize(11.5)
              .lineHeight(17)
              .fontColor(PrototypeTokens.WHITE_A40)
              .textAlign(TextAlign.Center)
              .width('100%')
              .padding({ left: 8, right: 8, top: 2 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 2, bottom: 30 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')

      if (this.sheetMode !== SheetMode.NONE) {
        this.buildSheet()
      }
      if (this.toastVisible) {
        this.buildToast()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PrototypeTokens.BG_INK)
  }

  @Builder
  private buildHeader() {
    Row({ space: 12 }) {
      Row() {
        Image($rawfile('pencil-plan-nav-chevron-left.svg'))
          .width(22)
          .height(22)
          .opacity(0.7)
      }
      .width(44)
      .height(44)
      .borderRadius(14)
      .justifyContent(FlexAlign.Center)
      .scale({
        x: this.backPressed ? MotionTokens.PRESS_BACK : 1,
        y: this.backPressed ? MotionTokens.PRESS_BACK : 1
      })
      .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.backPressed = true
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.backPressed = false
        }
      })
      .onClick(() => {
        this.leavePage()
      })

      Text('编辑资料')
        .fontFamily('Noto Sans SC')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(PrototypeTokens.TEXT_HI)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Row()
        .width(44)
        .height(44)
    }
    .width('100%')
    .padding({ top: Math.max(52 - this.topInsetVp, 0), bottom: 10, left: 12, right: 12 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildSectionTitle(title: string) {
    Text(title)
      .fontFamily('Noto Sans SC')
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .fontColor(PrototypeTokens.WHITE_A54)
      .width('100%')
      .padding({ left: 18, bottom: 8 })
  }

  /** 通用行：左标签 + 右值（空值显示占位）+ chevron；行间用 WHITE_A06 顶边分隔。 */
  @Builder
  private buildRow(field: string, label: string, value: string, placeholder: string, first: boolean) {
    Row() {
      Text(label)
        .fontFamily('Noto Sans SC')
        .fontSize(14)
        .fontColor(PrototypeTokens.WHITE_A82)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (value.length > 0) {
        Text(value)
          .fontFamily('Noto Sans SC')
          .fontSize(13.5)
          .fontColor(PrototypeTokens.WHITE_A65)
          .maxLines(1)
          .textAlign(TextAlign.End)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: 200 })
          .margin({ left: 12 })
      } else {
        Text(placeholder)
          .fontFamily('Noto Sans SC')
          .fontSize(13.5)
          .fontColor(PrototypeTokens.WHITE_A32)
          .maxLines(1)
          .margin({ left: 12 })
      }

      Text('›')
        .fontFamily('Noto Sans SC')
        .fontSize(16)
        .fontColor(PrototypeTokens.WHITE_A32)
        .margin({ left: 8 })
    }
    .width('100%')
    .padding({ top: 14, bottom: 14, left: 2, right: 2 })
    .backgroundColor(this.pressedField === field ? PrototypeTokens.WHITE_A05 : PrototypeTokens.WHITE_A00)
    .border({ width: { top: first ? 0 : 1 }, color: PrototypeTokens.WHITE_A06 })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedField = field
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedField = ''
      }
    })
    .onClick(() => {
      this.pressedField = ''
      this.onRowClick(field)
    })
  }

  /** 头像行：右侧圆形缩略图（与个人页头像同口径：圆 + 色键 + 首字）。 */
  @Builder
  private buildAvatarRow() {
    Row() {
      Text('头像')
        .fontFamily('Noto Sans SC')
        .fontSize(14)
        .fontColor(PrototypeTokens.WHITE_A82)
        .layoutWeight(1)

      this.buildAvatarBadge(56, 28)

      Text('›')
        .fontFamily('Noto Sans SC')
        .fontSize(16)
        .fontColor(PrototypeTokens.WHITE_A32)
        .margin({ left: 8 })
    }
    .width('100%')
    .padding({ top: 12, bottom: 12, left: 2, right: 2 })
    .backgroundColor(this.pressedField === Field.AVATAR ? PrototypeTokens.WHITE_A05 : PrototypeTokens.WHITE_A00)
    .border({ width: { bottom: 1 }, color: PrototypeTokens.WHITE_A06 })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedField = Field.AVATAR
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedField = ''
      }
    })
    .onClick(() => {
      this.pressedField = ''
      this.onRowClick(Field.AVATAR)
    })
  }

  /** 头像缩略图：有图显示图，无图回落色键 + 首字。 */
  @Builder
  private buildAvatarBadge(size: number, radius: number) {
    Stack() {
      if (this.avatarImagePath.length > 0) {
        Image(this.avatarImagePath)
          .width(size)
          .height(size)
          .borderRadius(radius)
          .objectFit(ImageFit.Cover)
      } else {
        Column()
          .width(size)
          .height(size)
          .borderRadius(radius)
          .backgroundColor(avatarTintOf(this.avatarKey).fill)
          .border({ width: 1, color: avatarTintOf(this.avatarKey).border })
        Text(avatarInitialOf(this.displayName()))
          .fontFamily('Inter')
          .fontSize(Math.round(size * 0.42))
          .fontWeight(FontWeight.Bold)
          .fontColor(avatarTintOf(this.avatarKey).text)
      }
    }
    .width(size)
    .height(size)
  }

  @Builder
  private buildIdentitySection() {
    Column() {
      this.buildSectionTitle('个人资料')
      Column() {
        this.buildAvatarRow()
        this.buildRow(Field.NAME, '名字', this.nickname.trim(), '未设置', false)
        this.buildRow(Field.GENDER, '性别', this.genderLabel(), '未设置', false)
        this.buildRow(Field.REGION, '地区', this.region, '未设置', false)
        this.buildRow(Field.PHONE, '手机号', this.maskedPhone(), '未绑定', false)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .backgroundColor(PrototypeTokens.WHITE_A03)
      .borderRadius(22)
      .border({ width: 1, color: PrototypeTokens.WHITE_A10 })
    }
    .width('100%')
  }

  @Builder
  private buildCardSection() {
    Column() {
      this.buildSectionTitle('名片')
      Column() {
        this.buildRow(Field.ACCOUNT, '档案号', this.accountIdLabel(), '未生成', true)
          this.buildRow(Field.TICKLE, '拍一拍', this.tickle, '未设置', false)
        this.buildRow(Field.WHATS_UP, '个性签名', this.whatsUp, '未设置', false)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .backgroundColor(PrototypeTokens.WHITE_A03)
      .borderRadius(22)
      .border({ width: 1, color: PrototypeTokens.WHITE_A10 })
    }
    .width('100%')
  }

  @Builder
  private buildPreferenceSection() {
    Column() {
      this.buildSectionTitle('偏好')
      Column() {
        this.buildRow(Field.WEIGHT_UNIT, '体重单位', this.weightUnitLabel(), '千克（kg）', true)
        this.buildRow(Field.GYM, '常用健身房', this.gymAddress, '未设置', false)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .backgroundColor(PrototypeTokens.WHITE_A03)
      .borderRadius(22)
      .border({ width: 1, color: PrototypeTokens.WHITE_A10 })
    }
    .width('100%')
  }

  @Builder
  private buildBodySection() {
    Column() {
      this.buildSectionTitle('身体档案')
      Column() {
        this.buildRow(Field.HEIGHT, '身高', this.heightText.length > 0 ? this.heightText + ' cm' : '', '未填写', true)
        this.buildRow(Field.BIRTH_YEAR, '出生年份', this.birthYearText, '未填写', false)
        this.buildRow(Field.EXPERIENCE, '训练经验', this.experienceLabel(), '未填写', false)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .backgroundColor(PrototypeTokens.WHITE_A03)
      .borderRadius(22)
      .border({ width: 1, color: PrototypeTokens.WHITE_A10 })
    }
    .width('100%')
  }

  @Builder
  private buildSaveButton() {
    Button(this.saving ? '保存中…' : '保存')
      .width('100%')
      .height(52)
      .fontFamily('Noto Sans SC')
      .fontSize(15)
      .fontWeight(FontWeight.Bold)
      .fontColor(PrototypeTokens.TEXT_ON_ACCENT)
      .backgroundColor(PrototypeTokens.ACCENT)
      .borderRadius(16)
      .enabled(!this.saving)
      .opacity(this.saving ? 0.6 : 1)
      // Duolingo 硬边厚底：按下收平 + 下沉，替代缩放按压
      .border({
        width: { bottom: this.savePressed ? 0 : MotionTokens.PRESS_DEPTH },
        color: { bottom: PrototypeTokens.ACCENT_DEEP }
      })
      .translate({ y: this.savePressed ? MotionTokens.PRESS_SHIFT : 0 })
      .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.savePressed = true
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.savePressed = false
        }
      })
      .onClick(() => {
        this.finish()
      })
      .margin({ top: 4 })
  }

  // ── 底部编辑面板 ────────────────────────────────────────────────

  @Builder
  private buildSheet() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(PrototypeTokens.BLACK_A40)
        .onClick(() => {
          this.closeSheet()
        })

      Column() {
        this.buildSheetHeader()
        this.buildSheetBody()
      }
      .width('100%')
      .backgroundColor(PrototypeTokens.STAT_BG)
      .borderRadius({ topLeft: 22, topRight: 22 })
      .border({ width: 1, color: PrototypeTokens.WHITE_A10 })
      .padding({ bottom: 28 })
      .transition(TransitionEffect.move(TransitionEdge.BOTTOM)
        .combine(TransitionEffect.OPACITY)
        .animation({ duration: MotionTokens.DURATION_PANEL, curve: MotionTokens.EASE_PANEL }))
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildSheetHeader() {
    Row() {
      Text(this.sheetMode === SheetMode.TEXT ? '取消' : '关闭')
        .fontFamily('Noto Sans SC')
        .fontSize(13.5)
        .fontColor(PrototypeTokens.WHITE_A54)
        .height(48)
        .padding({ left: 20, right: 12 })
        .onClick(() => {
          this.closeSheet()
        })

      Text(this.sheetTitle)
        .fontFamily('Noto Sans SC')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(PrototypeTokens.TEXT_HI)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .maxLines(1)

      if (this.sheetMode === SheetMode.TEXT) {
        Text('保存')
          .fontFamily('Noto Sans SC')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(PrototypeTokens.ACCENT)
          .height(48)
          .padding({ left: 12, right: 20 })
          .onClick(() => {
            this.commitText()
          })
      } else {
        Row()
          .width(80)
          .height(48)
      }
    }
    .width('100%')
    .height(48)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildSheetBody() {
    if (this.sheetMode === SheetMode.TEXT) {
      Column() {
        if (this.sheetMultiline) {
          TextArea({ text: this.sheetDraft, placeholder: '写点想说的' })
            .fontFamily('Noto Sans SC')
            .fontSize(14.5)
            .fontColor(PrototypeTokens.TEXT_HI)
            .placeholderColor(PrototypeTokens.WHITE_A32)
            .backgroundColor(PrototypeTokens.WHITE_A06)
            .border({ width: 1, color: PrototypeTokens.WHITE_A08 })
            .borderRadius(14)
            .height(104)
            .padding(12)
            .maxLength(this.sheetMaxLen)
            .onChange((next: string) => {
              this.sheetDraft = next.length > this.sheetMaxLen ? next.substring(0, this.sheetMaxLen) : next
            })
        } else {
          TextInput({ text: this.sheetDraft, placeholder: '' })
            .type(this.sheetNumeric ? InputType.Number : InputType.Normal)
            .fontFamily('Noto Sans SC')
            .fontSize(14.5)
            .fontColor(PrototypeTokens.TEXT_HI)
            .caretColor(PrototypeTokens.ACCENT)
            .backgroundColor(PrototypeTokens.WHITE_A06)
            .border({ width: 1, color: PrototypeTokens.WHITE_A08 })
            .borderRadius(14)
            .height(48)
            .padding({ left: 12, right: 12 })
            .maxLength(this.sheetMaxLen)
            .onChange((next: string) => {
              this.sheetDraft = next.length > this.sheetMaxLen ? next.substring(0, this.sheetMaxLen) : next
            })
        }

        Text(this.sheetNumeric ? '只填数字，留空表示不填。' : '最多 ' + this.sheetMaxLen + ' 个字。')
          .fontFamily('Noto Sans SC')
          .fontSize(11.5)
          .fontColor(PrototypeTokens.WHITE_A40)
          .width('100%')
          .padding({ top: 10, left: 2 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 4 })
    } else if (this.sheetMode === SheetMode.CHOICE) {
      Column() {
        ForEach(this.choiceOptions(), (item: ChoiceOption) => {
          Row() {
            Text(item.label)
              .fontFamily('Noto Sans SC')
              .fontSize(14.5)
              .fontColor(this.currentChoiceValue() === item.value
                ? PrototypeTokens.TEXT_HI
                : PrototypeTokens.WHITE_A70)
              .layoutWeight(1)
            if (this.currentChoiceValue() === item.value) {
              Text('✓')
                .fontFamily('Noto Sans SC')
                .fontSize(15)
                .fontColor(PrototypeTokens.ACCENT)
            }
          }
          .width('100%')
          .height(50)
          .padding({ left: 14, right: 14 })
          .borderRadius(14)
          .backgroundColor(this.currentChoiceValue() === item.value
            ? PrototypeTokens.ACCENT_A07
            : PrototypeTokens.WHITE_A00)
          .margin({ bottom: 4 })
          .onClick(() => {
            this.commitChoice(item.value)
          })
        }, (item: ChoiceOption) => item.label)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 4 })
    } else if (this.sheetMode === SheetMode.AVATAR) {
      Column({ space: 16 }) {
        this.buildAvatarBadge(88, 44)

        Row({ space: 10 }) {
          ForEach(AVATAR_KEYS, (key: string) => {
            Column() {
              Column()
                .width(26)
                .height(26)
                .borderRadius(13)
                .backgroundColor(avatarTintOf(key).fill)
                .border({
                  width: this.avatarKey === key ? 2 : 1,
                  color: this.avatarKey === key ? avatarTintOf(key).text : avatarTintOf(key).border
                })
            }
            .width(38)
            .height(38)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .onClick(() => {
              this.selectAvatarKey(key)
            })
          }, (key: string) => 'sheet-avatar-key-' + key)
        }

        Button(this.picking ? '读取中…' : '从相册选择')
          .width('100%')
          .height(46)
          .fontFamily('Noto Sans SC')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(PrototypeTokens.TEXT_ON_ACCENT)
          .backgroundColor(PrototypeTokens.ACCENT)
          .borderRadius(14)
          .enabled(!this.picking)
          .opacity(this.picking ? 0.6 : 1)
          .onClick(() => {
            this.pickAvatar()
          })

        if (this.avatarImagePath.length > 0) {
          Button('移除头像')
            .width('100%')
            .height(46)
            .fontFamily('Noto Sans SC')
            .fontSize(14)
            .fontColor(PrototypeTokens.WHITE_A70)
            .backgroundColor(PrototypeTokens.WHITE_A06)
            .border({ width: 1, color: PrototypeTokens.WHITE_A08 })
            .borderRadius(14)
            .onClick(() => {
              this.removeAvatar()
            })
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 8 })
      .alignItems(HorizontalAlign.Center)
    } else {
      Column({ space: 16 }) {
        Text(this.sheetHint)
          .fontFamily('Noto Sans SC')
          .fontSize(13.5)
          .lineHeight(21)
          .fontColor(PrototypeTokens.WHITE_A70)
          .width('100%')

        Button('我知道了')
          .width('100%')
          .height(46)
          .fontFamily('Noto Sans SC')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(PrototypeTokens.TEXT_ON_ACCENT)
          .backgroundColor(PrototypeTokens.ACCENT)
          .borderRadius(14)
          .onClick(() => {
            this.closeSheet()
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 4 })
      .alignItems(HorizontalAlign.Center)
    }
  }

  @Builder
  private buildToast() {
    Text(this.toastMessage)
      .fontFamily('Noto Sans SC')
      .fontSize(13)
      .fontColor(PrototypeTokens.TEXT_HI)
      .padding({ left: 18, right: 18, top: 11, bottom: 11 })
      .backgroundColor('#E61A201E')
      .borderRadius(14)
      .border({ width: 1, color: PrototypeTokens.WHITE_A10 })
      .margin({ bottom: 90 })
  }
}

