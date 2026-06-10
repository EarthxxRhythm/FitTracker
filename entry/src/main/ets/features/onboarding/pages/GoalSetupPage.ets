/**
 * GoalSetupPage -- target training goal questionnaire.
 * Function #7: real goal setup questionnaire.
 */
import { Context } from '@kit.AbilityKit'
import { AppRoutes } from '../../../app/AppRoutes'
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens, TouchTokens } from '../../../common/styles/DesignTokens'
import { UserGoal } from '../../../shared/models/TrainingModels'
import GoalRepository from '../../../shared/services/GoalRepository'
import GoalSetupService, { GoalSetupPrefill } from '../../../shared/services/GoalSetupService'

interface GoalOption {
  id: string
  label: string
}

function createGoalOption(id: string, label: string): GoalOption {
  const option: GoalOption = {
    id: id,
    label: label
  }
  return option
}

const GOAL_OPTIONS: GoalOption[] = [
  createGoalOption('hypertrophy', '增肌'),
  createGoalOption('strength', '力量'),
  createGoalOption('fat_loss', '减脂')
]

const LEVEL_OPTIONS: GoalOption[] = [
  createGoalOption('beginner', '新手'),
  createGoalOption('intermediate', '进阶'),
  createGoalOption('advanced', '熟练')
]

const DAY_OPTIONS: number[] = [2, 3, 4, 5]
const MINUTE_OPTIONS: number[] = [30, 45, 60, 75]

const EQUIPMENT_OPTIONS: GoalOption[] = [
  createGoalOption('eq_bodyweight', '自重'),
  createGoalOption('eq_dumbbell', '哑铃'),
  createGoalOption('eq_barbell', '杠铃'),
  createGoalOption('eq_cable', '绳索')
]

const RESTRICTED_MUSCLE_OPTIONS: GoalOption[] = [
  createGoalOption('muscle_chest', '胸部'),
  createGoalOption('muscle_back', '背部'),
  createGoalOption('muscle_legs', '腿部'),
  createGoalOption('muscle_shoulders', '肩部'),
  createGoalOption('muscle_arms', '手臂'),
  createGoalOption('muscle_core', '核心')
]

@Entry
@Component
export struct GoalSetupPage {
  @State saving: boolean = false
  @State hasExistingGoal: boolean = false
  @State existingGoal: UserGoal | undefined = undefined
  @State selectedGoalType: string = 'hypertrophy'
  @State selectedLevel: string = 'beginner'
  @State weeklyDays: number = 3
  @State sessionMinutes: number = 45
  @State selectedEquipmentIds: string[] = ['eq_bodyweight', 'eq_dumbbell']
  @State selectedRestrictedMuscleIds: string[] = []

  private getHostContextOrNull(): Context | null {
    const hostContext = this.getUIContext().getHostContext()
    if (hostContext === undefined || hostContext === null) {
      return null
    }
    return hostContext as Context
  }

  async aboutToAppear(): Promise<void> {
    try {
      const context: Context | null = this.getHostContextOrNull()
      if (context === null) {
        this.hasExistingGoal = false
        return
      }
      const goal: UserGoal | undefined = await GoalRepository.loadGoal(context)
      if (goal !== undefined) {
        const prefill: GoalSetupPrefill = GoalSetupService.createPrefillFromGoal(goal)
        this.hasExistingGoal = true
        this.existingGoal = goal
        this.selectedGoalType = prefill.goalType
        this.selectedLevel = prefill.level
        this.weeklyDays = prefill.weeklyDays
        this.sessionMinutes = prefill.sessionMinutes
        this.selectedEquipmentIds = prefill.equipmentIds
        this.selectedRestrictedMuscleIds = prefill.restrictedMuscleIds
      }
    } catch (e) {
      this.hasExistingGoal = false
    }
  }

  async saveSelectedGoal(): Promise<void> {
    if (this.saving) {
      return
    }
    this.saving = true
    const equipmentIds: string[] = this.getSelectedEquipmentIds()
    const restrictedMuscleIds: string[] = this.copyStringArray(this.selectedRestrictedMuscleIds)
    const now: number = Date.now()
    let goal: UserGoal
    if (this.existingGoal !== undefined) {
      goal = GoalSetupService.createGoalFromExistingSelection(
        this.existingGoal,
        this.selectedGoalType,
        this.selectedLevel,
        this.weeklyDays,
        this.sessionMinutes,
        equipmentIds,
        restrictedMuscleIds,
        now
      )
    } else {
      goal = GoalSetupService.createCurrentGoalFromSelection(
        this.selectedGoalType,
        this.selectedLevel,
        this.weeklyDays,
        this.sessionMinutes,
        equipmentIds,
        restrictedMuscleIds,
        now
      )
    }

    try {
      const context: Context | null = this.getHostContextOrNull()
      if (context === null) {
        this.saving = false
        return
      }
      await GoalRepository.saveGoal(context, goal)
      this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.HOME })
    } catch (e) {
      this.saving = false
    }
  }

  toggleEquipment(equipmentId: string): void {
    const values: string[] = []
    const exists: boolean = this.containsValue(this.selectedEquipmentIds, equipmentId)
    for (let index = 0; index < this.selectedEquipmentIds.length; index++) {
      const value: string = this.selectedEquipmentIds[index]
      if (value !== equipmentId) {
        values.push(value)
      }
    }
    if (!exists) {
      values.push(equipmentId)
    }
    this.selectedEquipmentIds = values
  }

  toggleRestrictedMuscle(muscleId: string): void {
    const values: string[] = []
    const exists: boolean = this.containsValue(this.selectedRestrictedMuscleIds, muscleId)
    for (let index = 0; index < this.selectedRestrictedMuscleIds.length; index++) {
      const value: string = this.selectedRestrictedMuscleIds[index]
      if (value !== muscleId) {
        values.push(value)
      }
    }
    if (!exists) {
      values.push(muscleId)
    }
    this.selectedRestrictedMuscleIds = values
  }

  getSelectedEquipmentIds(): string[] {
    if (this.selectedEquipmentIds.length === 0) {
      const fallback: string[] = ['eq_bodyweight']
      return fallback
    }

    const values: string[] = []
    for (let index = 0; index < this.selectedEquipmentIds.length; index++) {
      values.push(this.selectedEquipmentIds[index])
    }
    return values
  }

  containsValue(values: string[], targetValue: string): boolean {
    for (let index = 0; index < values.length; index++) {
      if (values[index] === targetValue) {
        return true
      }
    }
    return false
  }

  copyStringArray(source: string[]): string[] {
    const values: string[] = []
    for (let index = 0; index < source.length; index++) {
      values.push(source[index])
    }
    return values
  }

  selectedBg(isSelected: boolean): string {
    if (isSelected) {
      return ColorTokens.PRIMARY
    }
    return ColorTokens.SURFACE_ELEVATED
  }

  selectedTextColor(isSelected: boolean): string {
    if (isSelected) {
      return ColorTokens.TEXT_ON_PRIMARY
    }
    return ColorTokens.TEXT_SECONDARY
  }

  build() {
    Scroll() {
      Column({ space: SpacingTokens.LG }) {
        Column({ space: SpacingTokens.SM }) {
          Text('训练目标')
            .fontSize(FontTokens.DISPLAY_SIZE)
            .fontWeight(FontTokens.DISPLAY_WEIGHT)
            .fontColor(ColorTokens.TEXT_PRIMARY)

          Text('先建立目标，后续计划会围绕你的目标、经验和器械生成。')
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Column({ space: SpacingTokens.MD }) {
          Text('目标')
            .fontSize(FontTokens.TITLE_SIZE)
            .fontWeight(FontTokens.TITLE_WEIGHT)
            .fontColor(ColorTokens.TEXT_PRIMARY)

          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(GOAL_OPTIONS, (option: GoalOption) => {
              Button(option.label)
                .width('31%')
                .height(TouchTokens.BUTTON_HEIGHT_DEFAULT)
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(this.selectedTextColor(this.selectedGoalType === option.id))
                .backgroundColor(this.selectedBg(this.selectedGoalType === option.id))
                .borderRadius(RadiusTokens.SM)
                .margin({ right: SpacingTokens.SM, bottom: SpacingTokens.SM })
                .onClick(() => {
                  this.selectedGoalType = option.id
                })
            }, (option: GoalOption) => option.id)
          }
          .width('100%')
        }
        .width('100%')
        .padding(SpacingTokens.MD)
        .borderRadius(RadiusTokens.SM)
        .backgroundColor(ColorTokens.BG_SECONDARY)

        Column({ space: SpacingTokens.MD }) {
          Text('训练经验')
            .fontSize(FontTokens.TITLE_SIZE)
            .fontWeight(FontTokens.TITLE_WEIGHT)
            .fontColor(ColorTokens.TEXT_PRIMARY)

          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(LEVEL_OPTIONS, (option: GoalOption) => {
              Button(option.label)
                .width('31%')
                .height(TouchTokens.BUTTON_HEIGHT_DEFAULT)
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(this.selectedTextColor(this.selectedLevel === option.id))
                .backgroundColor(this.selectedBg(this.selectedLevel === option.id))
                .borderRadius(RadiusTokens.SM)
                .margin({ right: SpacingTokens.SM, bottom: SpacingTokens.SM })
                .onClick(() => {
                  this.selectedLevel = option.id
                })
            }, (option: GoalOption) => option.id)
          }
          .width('100%')
        }
        .width('100%')
        .padding(SpacingTokens.MD)
        .borderRadius(RadiusTokens.SM)
        .backgroundColor(ColorTokens.BG_SECONDARY)

        Column({ space: SpacingTokens.MD }) {
          Text('每周训练天数')
            .fontSize(FontTokens.TITLE_SIZE)
            .fontWeight(FontTokens.TITLE_WEIGHT)
            .fontColor(ColorTokens.TEXT_PRIMARY)

          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(DAY_OPTIONS, (day: number) => {
              Button(`${day} 天`)
                .width('23%')
                .height(TouchTokens.BUTTON_HEIGHT_DEFAULT)
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(this.selectedTextColor(this.weeklyDays === day))
                .backgroundColor(this.selectedBg(this.weeklyDays === day))
                .borderRadius(RadiusTokens.SM)
                .margin({ right: SpacingTokens.SM, bottom: SpacingTokens.SM })
                .onClick(() => {
                  this.weeklyDays = day
                })
            }, (day: number) => `${day}`)
          }
          .width('100%')
        }
        .width('100%')
        .padding(SpacingTokens.MD)
        .borderRadius(RadiusTokens.SM)
        .backgroundColor(ColorTokens.BG_SECONDARY)

        Column({ space: SpacingTokens.MD }) {
          Text('单次训练时长')
            .fontSize(FontTokens.TITLE_SIZE)
            .fontWeight(FontTokens.TITLE_WEIGHT)
            .fontColor(ColorTokens.TEXT_PRIMARY)

          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(MINUTE_OPTIONS, (minute: number) => {
              Button(`${minute} 分钟`)
                .width('47%')
                .height(TouchTokens.BUTTON_HEIGHT_DEFAULT)
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(this.selectedTextColor(this.sessionMinutes === minute))
                .backgroundColor(this.selectedBg(this.sessionMinutes === minute))
                .borderRadius(RadiusTokens.SM)
                .margin({ right: SpacingTokens.SM, bottom: SpacingTokens.SM })
                .onClick(() => {
                  this.sessionMinutes = minute
                })
            }, (minute: number) => `${minute}`)
          }
          .width('100%')
        }
        .width('100%')
        .padding(SpacingTokens.MD)
        .borderRadius(RadiusTokens.SM)
        .backgroundColor(ColorTokens.BG_SECONDARY)

        Column({ space: SpacingTokens.MD }) {
          Text('可用器械')
            .fontSize(FontTokens.TITLE_SIZE)
            .fontWeight(FontTokens.TITLE_WEIGHT)
            .fontColor(ColorTokens.TEXT_PRIMARY)

          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(EQUIPMENT_OPTIONS, (option: GoalOption) => {
              Button(option.label)
                .width('47%')
                .height(TouchTokens.BUTTON_HEIGHT_DEFAULT)
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(this.selectedTextColor(this.containsValue(this.selectedEquipmentIds, option.id)))
                .backgroundColor(this.selectedBg(this.containsValue(this.selectedEquipmentIds, option.id)))
                .borderRadius(RadiusTokens.SM)
                .margin({ right: SpacingTokens.SM, bottom: SpacingTokens.SM })
                .onClick(() => {
                  this.toggleEquipment(option.id)
                })
            }, (option: GoalOption) => option.id)
          }
          .width('100%')
        }
        .width('100%')
        .padding(SpacingTokens.MD)
        .borderRadius(RadiusTokens.SM)
        .backgroundColor(ColorTokens.BG_SECONDARY)

        Column({ space: SpacingTokens.MD }) {
          Text('限制肌群')
            .fontSize(FontTokens.TITLE_SIZE)
            .fontWeight(FontTokens.TITLE_WEIGHT)
            .fontColor(ColorTokens.TEXT_PRIMARY)

          Text('选中后计划会尽量避开相关肌群，适合疼痛、恢复期或临时限制。')
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)

          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(RESTRICTED_MUSCLE_OPTIONS, (option: GoalOption) => {
              Button(option.label)
                .width('31%')
                .height(TouchTokens.BUTTON_HEIGHT_DEFAULT)
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(this.selectedTextColor(this.containsValue(this.selectedRestrictedMuscleIds, option.id)))
                .backgroundColor(this.selectedBg(this.containsValue(this.selectedRestrictedMuscleIds, option.id)))
                .borderRadius(RadiusTokens.SM)
                .margin({ right: SpacingTokens.SM, bottom: SpacingTokens.SM })
                .onClick(() => {
                  this.toggleRestrictedMuscle(option.id)
                })
            }, (option: GoalOption) => option.id)
          }
          .width('100%')
        }
        .width('100%')
        .padding(SpacingTokens.MD)
        .borderRadius(RadiusTokens.SM)
        .backgroundColor(ColorTokens.BG_SECONDARY)

        Button(this.saving ? '保存中' : '生成训练计划')
          .width('100%')
          .height(TouchTokens.BUTTON_HEIGHT_LARGE)
          .fontSize(FontTokens.BODY_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(ColorTokens.TEXT_ON_PRIMARY)
          .backgroundColor(this.saving ? ColorTokens.PRIMARY_DISABLED : ColorTokens.PRIMARY)
          .borderRadius(RadiusTokens.FULL)
          .enabled(!this.saving)
          .onClick(() => {
            this.saveSelectedGoal()
          })
      }
      .width('100%')
      .padding(SpacingTokens.LG)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.BG_PRIMARY)
  }
}
