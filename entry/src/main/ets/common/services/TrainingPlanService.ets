/**
 * TrainingPlanService —— 训练计划服务
 *
 * 功能 #7: 提供5套预置训练计划数据，每套包含训练日及动作清单
 * 功能 #9: 启用预置计划 —— 克隆至我的计划并设为当前计划，持久化存储
 * 预置计划为只读模板，启用时通过克隆生成用户计划
 */
import { preferences } from '@kit.ArkData'

export interface ExerciseRef {
  name: string
  targetMuscle: string
  sets: number
  reps: string
}

export interface TrainingDay {
  dayLabel: string
  exercises: ExerciseRef[]
  dayOfWeek?: number[] // 0=Sun, 1=Mon ... 6=Sat; if absent, auto-distributed
}

export interface PresetPlan {
  id: string
  name: string
  coverColor: string
  targetAudience: string
  weeklyFrequency: string
  days: TrainingDay[]
}

export interface UserPlan extends PresetPlan {
  enabledAt: number
}

const STORE_NAME = 'fit_tracker_plans'
const KEY_MY_PLANS = 'my_plans'
const KEY_CURRENT_PLAN_ID = 'current_plan_id'

// ============================================================
// Builder functions — ensure all object literals have explicit types
// to satisfy ArkTS strict mode (arkts-no-untyped-obj-literals,
// arkts-no-noninferrable-arr-literals, arkts-identifiers-as-prop-names)
// ============================================================

function mkExercise(name: string, targetMuscle: string, sets: number, reps: string): ExerciseRef {
  const ex: ExerciseRef = { name: name, targetMuscle: targetMuscle, sets: sets, reps: reps }
  return ex
}

function mkDay(dayLabel: string, dayOfWeek: number[], exercises: ExerciseRef[]): TrainingDay {
  const td: TrainingDay = { dayLabel: dayLabel, dayOfWeek: dayOfWeek, exercises: exercises }
  return td
}

function mkPlan(
  id: string,
  name: string,
  coverColor: string,
  targetAudience: string,
  weeklyFrequency: string,
  days: TrainingDay[]
): PresetPlan {
  const plan: PresetPlan = {
    id: id,
    name: name,
    coverColor: coverColor,
    targetAudience: targetAudience,
    weeklyFrequency: weeklyFrequency,
    days: days
  }
  return plan
}

// ============================================================
// Preset Plans — 5 preset training plans
// ============================================================

const PRESET_PLANS: PresetPlan[] = [
  // Plan 1: 五分化训练 (Bro Split)
  mkPlan('preset_bro_split', '五分化训练', '#1E88E5', '中高级健身者', '5天/周', [
    mkDay('周一 胸部', [1], [
      mkExercise('杠铃平板卧推', '胸部', 4, '8-12'),
      mkExercise('上斜哑铃卧推', '胸部', 3, '8-12'),
      mkExercise('哑铃飞鸟', '胸部', 3, '12-15'),
      mkExercise('绳索夹胸', '胸部', 3, '12-15'),
      mkExercise('双杠臂屈伸', '胸部', 3, '8-12')
    ]),
    mkDay('周二 背部', [2], [
      mkExercise('引体向上', '背部', 4, '8-12'),
      mkExercise('杠铃划船', '背部', 4, '8-12'),
      mkExercise('高位下拉', '背部', 3, '10-12'),
      mkExercise('坐姿划船', '背部', 3, '10-12'),
      mkExercise('面拉', '背部', 3, '12-15')
    ]),
    mkDay('周三 腿部', [3], [
      mkExercise('杠铃深蹲', '腿部', 4, '8-12'),
      mkExercise('罗马尼亚硬拉', '腿部', 3, '8-12'),
      mkExercise('腿举', '腿部', 3, '10-12'),
      mkExercise('腿弯举', '腿部', 3, '12-15'),
      mkExercise('提踵', '腿部', 4, '15-20')
    ]),
    mkDay('周四 肩部', [4], [
      mkExercise('杠铃推举', '肩部', 4, '8-12'),
      mkExercise('哑铃侧平举', '肩部', 3, '12-15'),
      mkExercise('前平举', '肩部', 3, '12-15'),
      mkExercise('俯身飞鸟', '肩部', 3, '12-15'),
      mkExercise('耸肩', '肩部', 3, '12-15')
    ]),
    mkDay('周五 手臂', [5], [
      mkExercise('杠铃弯举', '手臂', 4, '8-12'),
      mkExercise('哑铃锤式弯举', '手臂', 3, '10-12'),
      mkExercise('窄距卧推', '手臂', 4, '8-12'),
      mkExercise('绳索下压', '手臂', 3, '12-15'),
      mkExercise('集中弯举', '手臂', 3, '12-15')
    ])
  ]),

  // Plan 2: 上下肢分裂 (Upper/Lower)
  mkPlan('preset_upper_lower', '上下肢分裂', '#43A047', '初中级健身者', '4天/周', [
    mkDay('周一 上肢A', [1], [
      mkExercise('杠铃平板卧推', '胸部', 4, '8-12'),
      mkExercise('哑铃推举', '肩部', 3, '8-12'),
      mkExercise('上斜哑铃飞鸟', '胸部', 3, '10-15'),
      mkExercise('侧平举', '肩部', 3, '12-15'),
      mkExercise('绳索下压', '手臂', 3, '12-15')
    ]),
    mkDay('周二 下肢', [2], [
      mkExercise('杠铃深蹲', '腿部', 4, '8-12'),
      mkExercise('罗马尼亚硬拉', '腿部', 3, '8-12'),
      mkExercise('保加利亚分腿蹲', '腿部', 3, '10-12'),
      mkExercise('腿弯举', '腿部', 3, '12-15'),
      mkExercise('提踵', '腿部', 3, '15-20')
    ]),
    mkDay('周四 上肢B', [4], [
      mkExercise('引体向上', '背部', 4, '8-12'),
      mkExercise('杠铃划船', '背部', 3, '8-12'),
      mkExercise('高位下拉', '背部', 3, '10-12'),
      mkExercise('面拉', '背部', 3, '12-15'),
      mkExercise('杠铃弯举', '手臂', 3, '10-12')
    ]),
    mkDay('周五 下肢', [5], [
      mkExercise('杠铃深蹲', '腿部', 4, '6-10'),
      mkExercise('腿举', '腿部', 3, '10-12'),
      mkExercise('腿弯举', '腿部', 3, '12-15'),
      mkExercise('腿伸展', '腿部', 3, '12-15'),
      mkExercise('提踵', '腿部', 3, '15-20')
    ])
  ]),

  // Plan 3: 推拉腿分裂 (Push/Pull/Legs)
  mkPlan('preset_ppl', '推拉腿分裂', '#FB8C00', '初中高级通用', '3-6天/周', [
    mkDay('推日', [1, 4], [
      mkExercise('杠铃平板卧推', '胸部', 4, '8-12'),
      mkExercise('哑铃推举', '肩部', 3, '8-12'),
      mkExercise('上斜哑铃卧推', '胸部', 3, '8-12'),
      mkExercise('侧平举', '肩部', 3, '12-15'),
      mkExercise('窄距卧推', '手臂', 3, '8-12')
    ]),
    mkDay('拉日', [2, 5], [
      mkExercise('引体向上', '背部', 4, '8-12'),
      mkExercise('杠铃划船', '背部', 4, '8-12'),
      mkExercise('坐姿划船', '背部', 3, '10-12'),
      mkExercise('面拉', '背部', 3, '12-15'),
      mkExercise('杠铃弯举', '手臂', 3, '10-12')
    ]),
    mkDay('腿日', [3, 6], [
      mkExercise('杠铃深蹲', '腿部', 4, '8-12'),
      mkExercise('罗马尼亚硬拉', '腿部', 3, '8-12'),
      mkExercise('腿举', '腿部', 3, '10-12'),
      mkExercise('腿弯举', '腿部', 3, '12-15'),
      mkExercise('提踵', '腿部', 4, '15-20')
    ])
  ]),

  // Plan 4: 全身训练 3x (Full Body 3x/week)
  mkPlan('preset_fullbody_3x', '全身训练 3x', '#8E24AA', '初级健身者', '3天/周', [
    mkDay('周一 全身', [1], [
      mkExercise('杠铃深蹲', '腿部', 3, '8-12'),
      mkExercise('杠铃平板卧推', '胸部', 3, '8-12'),
      mkExercise('杠铃划船', '背部', 3, '8-12'),
      mkExercise('杠铃推举', '肩部', 3, '8-12'),
      mkExercise('杠铃弯举', '手臂', 2, '10-12'),
      mkExercise('平板支撑', '腹部', 3, '30秒')
    ]),
    mkDay('周三 全身', [3], [
      mkExercise('罗马尼亚硬拉', '腿部', 3, '8-12'),
      mkExercise('哑铃卧推', '胸部', 3, '8-12'),
      mkExercise('高位下拉', '背部', 3, '8-12'),
      mkExercise('侧平举', '肩部', 3, '12-15'),
      mkExercise('绳索下压', '手臂', 2, '12-15'),
      mkExercise('卷腹', '腹部', 3, '15-20')
    ]),
    mkDay('周五 全身', [5], [
      mkExercise('杠铃深蹲', '腿部', 3, '8-12'),
      mkExercise('上斜哑铃卧推', '胸部', 3, '8-12'),
      mkExercise('坐姿划船', '背部', 3, '10-12'),
      mkExercise('哑铃推举', '肩部', 3, '8-12'),
      mkExercise('锤式弯举', '手臂', 2, '10-12'),
      mkExercise('悬垂举腿', '腹部', 3, '12-15')
    ])
  ]),

  // Plan 5: 力量举基础 (Powerlifting)
  mkPlan('preset_powerlifting', '力量举基础', '#E53935', '力量举入门', '3-4天/周', [
    mkDay('深蹲日', [1], [
      mkExercise('杠铃深蹲', '腿部', 5, '5'),
      mkExercise('前蹲', '腿部', 3, '6-8'),
      mkExercise('腿弯举', '腿部', 3, '8-12'),
      mkExercise('提踵', '腿部', 3, '12-15'),
      mkExercise('平板支撑', '腹部', 3, '30秒')
    ]),
    mkDay('卧推日', [2], [
      mkExercise('杠铃平板卧推', '胸部', 5, '5'),
      mkExercise('窄距卧推', '手臂', 3, '6-8'),
      mkExercise('哑铃推举', '肩部', 3, '8-12'),
      mkExercise('绳索下压', '手臂', 3, '10-12'),
      mkExercise('面拉', '背部', 3, '12-15')
    ]),
    mkDay('硬拉日', [4], [
      mkExercise('杠铃硬拉', '背部', 5, '5'),
      mkExercise('杠铃划船', '背部', 3, '6-8'),
      mkExercise('引体向上', '背部', 3, '6-8'),
      mkExercise('杠铃弯举', '手臂', 3, '8-12'),
      mkExercise('卷腹', '腹部', 3, '12-15')
    ]),
    mkDay('辅助日（可选）', [5], [
      mkExercise('腿举', '腿部', 3, '8-12'),
      mkExercise('坐姿划船', '背部', 3, '10-12'),
      mkExercise('侧平举', '肩部', 3, '12-15'),
      mkExercise('锤式弯举', '手臂', 3, '10-12'),
      mkExercise('提踵', '腿部', 3, '15-20')
    ])
  ])
]

// ============================================================
// Day-of-week helper — replaces Chinese-keyed Record
// (avoids arkts-identifiers-as-prop-names)
// ============================================================

function getDayNumberFromLabel(label: string): number {
  if (label.includes('周一')) return 1
  if (label.includes('周二')) return 2
  if (label.includes('周三')) return 3
  if (label.includes('周四')) return 4
  if (label.includes('周五')) return 5
  if (label.includes('周六')) return 6
  if (label.includes('周日')) return 0
  return -1
}

// ============================================================
// Service class
// ============================================================

class TrainingPlanService {
  private localPlans: UserPlan[] = []
  private localCurrentPlanId: string = ''

  getAllPresetPlans(): PresetPlan[] {
    return PRESET_PLANS
  }

  getPresetPlanById(id: string): PresetPlan | undefined {
    return PRESET_PLANS.find(p => p.id === id)
  }

  getPlanCount(): number {
    return PRESET_PLANS.length
  }

  async enablePlan(context: Context, presetId: string): Promise<UserPlan | null> {
    const preset = this.getPresetPlanById(presetId)
    if (!preset) {
      return null
    }
    const userPlan: UserPlan = this.createUserPlan(
      preset.name,
      preset.coverColor,
      preset.targetAudience,
      preset.weeklyFrequency,
      preset.days
    )
    return this.enableUserPlan(context, userPlan)
  }

  async enableCustomPlan(
    context: Context,
    name: string,
    coverColor: string,
    targetAudience: string,
    weeklyFrequency: string,
    days: TrainingDay[]
  ): Promise<UserPlan | null> {
    const userPlan: UserPlan = this.createUserPlan(
      name,
      coverColor,
      targetAudience,
      weeklyFrequency,
      days
    )
    return this.enableUserPlan(context, userPlan)
  }

  async enableUserPlan(context: Context, userPlan: UserPlan): Promise<UserPlan | null> {
    const myPlans = await this.getMyPlans(context)
    const nextPlan: UserPlan = this.copyUserPlan(userPlan)
    myPlans.push(nextPlan)
    await this.replaceMyPlans(context, myPlans, nextPlan.id)
    return nextPlan
  }

  async getMyPlans(context: Context): Promise<UserPlan[]> {
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      const json = await prefs.get(KEY_MY_PLANS, '[]') as string
      const plans = this.copyUserPlans(JSON.parse(json) as UserPlan[])
      this.localPlans = this.copyUserPlans(plans)
      return plans
    } catch (e) {
      return this.copyUserPlans(this.localPlans)
    }
  }

  async getCurrentPlan(context: Context): Promise<UserPlan | null> {
    try {
      const currentId = await this.getCurrentPlanId(context)
      if (!currentId) {
        return null
      }
      const myPlans = await this.getMyPlans(context)
      return myPlans.find(p => p.id === currentId) || null
    } catch (e) {
      return null
    }
  }

  async getCurrentPlanId(context: Context): Promise<string> {
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      const currentPlanId = await prefs.get(KEY_CURRENT_PLAN_ID, '') as string
      this.localCurrentPlanId = currentPlanId
      return currentPlanId
    } catch (e) {
      return this.localCurrentPlanId
    }
  }

  async replaceMyPlans(context: Context, plans: UserPlan[], currentPlanId: string): Promise<void> {
    const nextPlans: UserPlan[] = this.copyUserPlans(plans)
    let nextCurrentPlanId: string = currentPlanId
    if (!this.containsPlanId(nextPlans, nextCurrentPlanId)) {
      nextCurrentPlanId = nextPlans.length > 0 ? nextPlans[0].id : ''
    }

    this.localPlans = this.copyUserPlans(nextPlans)
    this.localCurrentPlanId = nextCurrentPlanId

    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      await prefs.put(KEY_MY_PLANS, JSON.stringify(nextPlans))
      await prefs.put(KEY_CURRENT_PLAN_ID, nextCurrentPlanId)
      await prefs.flush()
    } catch (e) {
    }
  }

  async setCurrentPlan(context: Context, planId: string): Promise<void> {
    this.localCurrentPlanId = planId
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      await prefs.put(KEY_CURRENT_PLAN_ID, planId)
      await prefs.flush()
    } catch (e) {
    }
  }

  async removeMyPlan(context: Context, planId: string): Promise<void> {
    let myPlans = await this.getMyPlans(context)
    myPlans = myPlans.filter(p => p.id !== planId)
    const currentId = await this.getCurrentPlanId(context)
    let nextCurrentPlanId: string = currentId
    if (currentId === planId) {
      nextCurrentPlanId = myPlans.length > 0 ? myPlans[0].id : ''
    }
    await this.replaceMyPlans(context, myPlans, nextCurrentPlanId)
  }

  async hasMyPlans(context: Context): Promise<boolean> {
    const plans = await this.getMyPlans(context)
    return plans.length > 0
  }

  getTodayTraining(plan: UserPlan): TrainingDay | null {
    const today = new Date().getDay() // 0=Sun, 1=Mon ... 6=Sat
    for (let day of plan.days) {
      if (day.dayOfWeek && day.dayOfWeek.length > 0) {
        if (day.dayOfWeek.includes(today)) {
          return day
        }
      }
    }
    // Fallback: try matching from dayLabel
    for (let day of plan.days) {
      const dayNum = getDayNumberFromLabel(day.dayLabel)
      if (dayNum === today) {
        return day
      }
    }
    return null
  }

  isTrainingDay(plan: UserPlan): boolean {
    return this.getTodayTraining(plan) !== null
  }

  getTodayLabel(): string {
    const labels: string[] = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六']
    return labels[new Date().getDay()]
  }

  private containsPlanId(plans: UserPlan[], planId: string): boolean {
    for (let index = 0; index < plans.length; index++) {
      if (plans[index].id === planId) {
        return true
      }
    }
    return false
  }

  private createUserPlan(
    name: string,
    coverColor: string,
    targetAudience: string,
    weeklyFrequency: string,
    days: TrainingDay[]
  ): UserPlan {
    const plan: UserPlan = {
      id: 'user_plan_' + Date.now().toString(),
      name: name,
      coverColor: coverColor,
      targetAudience: targetAudience,
      weeklyFrequency: weeklyFrequency,
      days: this.copyTrainingDays(days),
      enabledAt: Date.now()
    }
    return plan
  }

  private copyUserPlans(source: UserPlan[]): UserPlan[] {
    const plans: UserPlan[] = []
    for (let index = 0; index < source.length; index++) {
      plans.push(this.copyUserPlan(source[index]))
    }
    return plans
  }

  private copyUserPlan(source: UserPlan): UserPlan {
    const plan: UserPlan = {
      id: source.id,
      name: source.name,
      coverColor: source.coverColor,
      targetAudience: source.targetAudience,
      weeklyFrequency: source.weeklyFrequency,
      days: this.copyTrainingDays(source.days),
      enabledAt: source.enabledAt
    }
    return plan
  }

  private copyTrainingDays(source: TrainingDay[]): TrainingDay[] {
    const days: TrainingDay[] = []
    for (let index = 0; index < source.length; index++) {
      const sourceDay: TrainingDay = source[index]
      const day: TrainingDay = {
        dayLabel: sourceDay.dayLabel,
        dayOfWeek: this.copyDayOfWeek(sourceDay.dayOfWeek),
        exercises: this.copyExercises(sourceDay.exercises)
      }
      days.push(day)
    }
    return days
  }

  private copyExercises(source: ExerciseRef[]): ExerciseRef[] {
    const exercises: ExerciseRef[] = []
    for (let index = 0; index < source.length; index++) {
      const sourceExercise: ExerciseRef = source[index]
      const exercise: ExerciseRef = {
        name: sourceExercise.name,
        targetMuscle: sourceExercise.targetMuscle,
        sets: sourceExercise.sets,
        reps: sourceExercise.reps
      }
      exercises.push(exercise)
    }
    return exercises
  }

  private copyDayOfWeek(source: number[] | undefined): number[] | undefined {
    if (source === undefined) {
      return undefined
    }
    const values: number[] = []
    for (let index = 0; index < source.length; index++) {
      values.push(source[index])
    }
    return values
  }
}

export default new TrainingPlanService()
