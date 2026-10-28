/**
 * TrainingPlanService —— 训练计划服务
 *
 * 功能 #7: 提供 4 套按分化数成套的预置训练计划数据（二/三/四/五分化），每套包含训练日及动作清单
 * 功能 #9: 启用预置计划 —— 克隆至我的计划并设为当前计划，持久化存储
 * 预置计划为只读模板，启用时通过克隆生成用户计划
 */
import { preferences } from '@kit.ArkData'
import { util } from '@kit.ArkTS'
import GoalRepository from '../../shared/services/GoalRepository'
import PlanEngine from '../../shared/services/PlanEngine'
import ContentRepository from '../../shared/services/ContentRepository'

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
  description: string
  days: TrainingDay[]
}

export interface UserPlan extends PresetPlan {
  enabledAt: number
}

const STORE_NAME = 'fit_tracker_plans'
const KEY_MY_PLANS = 'my_plans'
const KEY_CURRENT_PLAN_ID = 'current_plan_id'

/**
 * preferences 单个字符串值的上限是 8192 字节（超限时 put/flush 抛错）。
 * my_plans 存的是完整计划的 JSON，一套预置计划约 1.8-2.4 KB，旧实现每次「使用此计划」
 * 都往数组里 push 一份新副本，切换 4 次就把这个值顶到 8 KB 附近，再切换就写不进去——
 * 表现正是「计划组切换功能没用」（toast 说成功，重启后仍是旧计划）。
 * 这里留出安全余量，写入前主动裁剪，保证指针一定能落地。
 */
const MAX_MY_PLANS_JSON_BYTES = 7000

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
  description: string,
  days: TrainingDay[]
): PresetPlan {
  const plan: PresetPlan = {
    id: id,
    name: name,
    coverColor: coverColor,
    targetAudience: targetAudience,
    weeklyFrequency: weeklyFrequency,
    description: description,
    days: days
  }
  return plan
}

// ============================================================
// Preset Plans — 按分化数成套的 4 套预置训练计划
//   二分化（上下肢） / 三分化 · 谭成义 / 四分化 / 五分化
// ============================================================

const PRESET_PLANS: PresetPlan[] = [
  // 二分化（上下肢）—— 上肢 / 下肢 交替，每周 4 练
  mkPlan(
    'preset_upper_lower',
    '二分化（上下肢）',
    '#43A047',
    '初中级健身者',
    '4 天/周',
    '按上肢、下肢两类交替安排，每周各练两次，兼顾训练频率与恢复，适合初中级训练者起步。',
    [
      mkDay('上肢A', [1], [
        mkExercise('杠铃平板卧推', '胸部', 4, '8-12'),
        mkExercise('哑铃推举', '肩部', 3, '8-12'),
        mkExercise('上斜哑铃飞鸟', '胸部', 3, '10-15'),
        mkExercise('侧平举', '肩部', 3, '12-15'),
        mkExercise('绳索下压', '手臂', 3, '12-15')
      ]),
      mkDay('下肢A', [2], [
        mkExercise('杠铃深蹲', '腿部', 4, '8-12'),
        mkExercise('罗马尼亚硬拉', '腿部', 3, '8-12'),
        mkExercise('保加利亚分腿蹲', '腿部', 3, '10-12'),
        mkExercise('腿弯举', '腿部', 3, '12-15'),
        mkExercise('提踵', '腿部', 3, '15-20')
      ]),
      mkDay('上肢B', [4], [
        mkExercise('引体向上', '背部', 4, '8-12'),
        mkExercise('杠铃划船', '背部', 3, '8-12'),
        mkExercise('高位下拉', '背部', 3, '10-12'),
        mkExercise('面拉', '背部', 3, '12-15'),
        mkExercise('杠铃弯举', '手臂', 3, '10-12')
      ]),
      mkDay('下肢B', [5], [
        mkExercise('杠铃深蹲', '腿部', 4, '6-10'),
        mkExercise('腿举', '腿部', 3, '10-12'),
        mkExercise('腿弯举', '腿部', 3, '12-15'),
        mkExercise('腿伸展', '腿部', 3, '12-15'),
        mkExercise('提踵', '腿部', 3, '15-20')
      ])
    ]
  ),

  // 三分化 · 谭成义（2026版）—— 胸肩三头 / 背后束二头 / 下肢，三练一循环，每周 3-6 练
  mkPlan(
    'preset_ppl',
    '三分化 · 谭成义',
    '#FB8C00',
    '新手与进阶爱好者',
    '3-6 天/周',
    '谭成义三分化（2026版）：胸+肩中束+三头 / 背+肩后束+二头 / 下肢以后侧为主。保留自由重量主项，用 RPE8 与渐进超负荷推进；复合动作留余量，单关节小动作可力竭。',
    [
      mkDay('胸肩三头', [1, 4], [
        mkExercise('杠铃卧推', '胸部', 4, '12/10/8'),
        mkExercise('哑铃上斜卧推', '胸部', 4, '12'),
        mkExercise('双杠臂屈伸', '胸部', 4, '12'),
        mkExercise('仰卧杠铃臂屈伸', '手臂', 4, '15→12'),
        mkExercise('外侧侧平举', '肩部', 3, '10+10')
      ]),
      mkDay('背后束二头', [2, 5], [
        mkExercise('单臂钢线下拉', '背部', 4, '12（末组10+5）'),
        mkExercise('对握下拉', '背部', 4, '12-8'),
        mkExercise('单臂器械划船', '背部', 4, '10+5'),
        mkExercise('坐姿开肘划船', '背部', 3, '12-15'),
        mkExercise('钢线弯举', '手臂', 3, '10-12')
      ]),
      mkDay('腿（后侧为主）', [3, 6], [
        mkExercise('单腿硬拉', '腿部', 3, '10-12'),
        mkExercise('保加利亚蹲', '腿部', 3, '10-12'),
        mkExercise('颈前深蹲', '腿部', 3, '10-12'),
        mkExercise('罗马尼亚硬拉', '腿部', 3, '10-12'),
        mkExercise('山羊挺身', '腿部', 3, '12-15')
      ])
    ]
  ),

  // 四分化 —— 胸+三头 / 背+二头 / 腿 / 肩+臂，每周 4 练
  mkPlan(
    'preset_split_4',
    '四分化',
    '#1E88E5',
    '中高级健身者',
    '4 天/周',
    '每个训练日聚焦一个大肌群并搭配协同肌：胸+三头、背+二头、腿、肩+臂，一周循环一次，适合中高级训练者。',
    [
      mkDay('胸 + 三头', [1], [
        mkExercise('杠铃平板卧推', '胸部', 4, '8-12'),
        mkExercise('上斜哑铃卧推', '胸部', 3, '8-12'),
        mkExercise('双杠臂屈伸', '胸部', 3, '8-12'),
        mkExercise('绳索夹胸', '胸部', 3, '12-15'),
        mkExercise('绳索下压', '手臂', 3, '12-15')
      ]),
      mkDay('背 + 二头', [2], [
        mkExercise('引体向上', '背部', 4, '8-12'),
        mkExercise('杠铃划船', '背部', 4, '8-12'),
        mkExercise('高位下拉', '背部', 3, '10-12'),
        mkExercise('坐姿划船', '背部', 3, '10-12'),
        mkExercise('杠铃弯举', '手臂', 3, '10-12')
      ]),
      mkDay('腿', [4], [
        mkExercise('杠铃深蹲', '腿部', 4, '8-12'),
        mkExercise('罗马尼亚硬拉', '腿部', 3, '8-12'),
        mkExercise('腿举', '腿部', 3, '10-12'),
        mkExercise('腿弯举', '腿部', 3, '12-15'),
        mkExercise('提踵', '腿部', 4, '15-20')
      ]),
      mkDay('肩 + 臂', [5], [
        mkExercise('杠铃推举', '肩部', 4, '8-12'),
        mkExercise('哑铃侧平举', '肩部', 3, '12-15'),
        mkExercise('俯身飞鸟', '肩部', 3, '12-15'),
        mkExercise('哑铃锤式弯举', '手臂', 3, '10-12'),
        mkExercise('绳索下压', '手臂', 3, '12-15')
      ])
    ]
  ),

  // 五分化 —— 胸 / 背 / 腿 / 肩 / 臂，每周 5 练
  mkPlan(
    'preset_bro_split',
    '五分化',
    '#E53935',
    '中高级健身者',
    '5 天/周',
    '每个肌群单独一天：胸、背、腿、肩、手臂，一周五个训练日，单次容量集中，适合恢复能力较好的中高级训练者。',
    [
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
    ]
  )
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

/**
 * 今天对应的训练日索引（计划 tab / 计划组详情 / 训练预览共用这一份口径）：
 * 先按 dayOfWeek 匹配，缺失时按 dayLabel 中的「周X」兜底；无匹配返回 -1（休息日）。
 */
export function resolveTodayTrainingIndex(days: TrainingDay[], todayWeekday: number): number {
  for (let index = 0; index < days.length; index++) {
    const weekdays: number[] | undefined = days[index].dayOfWeek
    if (weekdays !== undefined && weekdays.length > 0 && weekdays.indexOf(todayWeekday) >= 0) {
      return index
    }
  }
  for (let index = 0; index < days.length; index++) {
    if (getDayNumberFromLabel(days[index].dayLabel) === todayWeekday) {
      return index
    }
  }
  return -1
}

/**
 * 某训练日距今天最近一次是几天后（0=今天，1..6）；该日既无 dayOfWeek 也无法从
 * dayLabel 解析出星期时返回 -1（调用方回退到按位置的徽标）。
 */
export function resolveDayDistance(day: TrainingDay, todayWeekday: number): number {
  const weekdays: number[] = []
  if (day.dayOfWeek !== undefined) {
    for (let index = 0; index < day.dayOfWeek.length; index++) {
      weekdays.push(day.dayOfWeek[index])
    }
  }
  if (weekdays.length === 0) {
    const labelWeekday: number = getDayNumberFromLabel(day.dayLabel)
    if (labelWeekday >= 0) {
      weekdays.push(labelWeekday)
    }
  }
  if (weekdays.length === 0) {
    return -1
  }
  let best: number = 7
  for (let index = 0; index < weekdays.length; index++) {
    const distance: number = (weekdays[index] - todayWeekday + 7) % 7
    if (distance < best) {
      best = distance
    }
  }
  return best
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

  /**
   * 反查某个用户计划对应的预置计划 id；自定义计划返回空串。
   *
   * 判断「当前计划是不是这一套」必须按身份（预置 id）而不是显示名：
   * 同名计划可能存有多份历史副本，用 name 比较会把「已在使用」标到别的计划组上。
   */
  getPresetIdForPlan(plan: UserPlan): string {
    if (this.getPresetPlanById(plan.id) !== undefined) {
      return plan.id
    }
    for (let index = 0; index < PRESET_PLANS.length; index++) {
      if (PRESET_PLANS[index].name === plan.name) {
        return PRESET_PLANS[index].id
      }
    }
    return ''
  }

  /** 当前计划的预置 id（无当前计划或自定义计划返回空串）。 */
  async getCurrentPresetId(context: Context): Promise<string> {
    const current: UserPlan | null = await this.getCurrentPlan(context)
    if (current === null) {
      return ''
    }
    return this.getPresetIdForPlan(current)
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
      preset.description,
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
    description: string,
    days: TrainingDay[]
  ): Promise<UserPlan | null> {
    const userPlan: UserPlan = this.createUserPlan(
      name,
      coverColor,
      targetAudience,
      weeklyFrequency,
      description,
      days
    )
    return this.enableUserPlan(context, userPlan)
  }

  /**
   * 启用（切换）一份计划。
   *
   * 语义是「单活动计划」：my_plans 里只保留刚启用的这一份。
   * 旧实现是 `myPlans.push(nextPlan)` —— 每切换一次就多一份完整计划副本，
   * 把 my_plans 的 JSON 顶到 preferences 8 KB 上限之后写入静默失败，切换就「没用」了。
   * 应用里没有「我的计划」多份管理界面（removeMyPlan 无 UI 调用方），
   * 保留历史副本没有消费方，只保留当前计划即可。
   */
  async enableUserPlan(context: Context, userPlan: UserPlan): Promise<UserPlan | null> {
    const nextPlan: UserPlan = this.copyUserPlan(userPlan)
    const myPlans: UserPlan[] = [nextPlan]
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
      // 指针也可以直接是预置 id（例如从备份包恢复当前计划时）——按预置定义即时重建，
      // 不必依赖 my_plans 里存着那份完整副本。
      const presetCurrent: PresetPlan | undefined = this.getPresetPlanById(currentId)
      if (presetCurrent !== undefined) {
        return this.createUserPlanFromPreset(presetCurrent)
      }
      const myPlans = await this.getMyPlans(context)
      const currentPlan: UserPlan | undefined = myPlans.find(p => p.id === currentId)
      if (currentPlan === undefined) {
        return null
      }
      return await this.repairCurrentPlanIfNeeded(context, currentPlan, myPlans)
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
    const nextPlans: UserPlan[] = this.trimToStorageBudget(this.copyUserPlans(plans))
    let nextCurrentPlanId: string = currentPlanId
    // 预置 id 也是合法指针（等价于「用这套预置计划」），不要被下面的兜底改写掉。
    if (!this.containsPlanId(nextPlans, nextCurrentPlanId) && this.getPresetPlanById(nextCurrentPlanId) === undefined) {
      nextCurrentPlanId = nextPlans.length > 0 ? nextPlans[0].id : ''
    }

    this.localPlans = this.copyUserPlans(nextPlans)
    this.localCurrentPlanId = nextCurrentPlanId

    try {
      await this.writePlans(context, nextPlans, nextCurrentPlanId)
    } catch (e) {
      // 一次降级重试：宁可丢掉历史副本，也要保证「当前计划指针 + 当前计划」能落盘。
      const minimalPlans: UserPlan[] = this.keepOnlyCurrentPlan(nextPlans, nextCurrentPlanId)
      try {
        await this.writePlans(context, minimalPlans, nextCurrentPlanId)
      } catch (retryError) {
        // 两次都失败时保留内存态（localPlans/localCurrentPlanId），本次会话内仍能读到新计划。
      }
    }
  }

  private async writePlans(context: Context, plans: UserPlan[], currentPlanId: string): Promise<void> {
    const prefs = await preferences.getPreferences(context, STORE_NAME)
    await prefs.put(KEY_MY_PLANS, JSON.stringify(plans))
    await prefs.put(KEY_CURRENT_PLAN_ID, currentPlanId)
    await prefs.flush()
  }

  /**
   * 写入前裁剪 my_plans：先按名称去重（保留最新一份），再按 preferences 单值上限收敛。
   *
   * 这里同时兜住老数据：历史版本每次切换都 push 一份副本，设备上可能已经堆了
   * 4-8 KB 的同名副本，靠这一次写入把数组收敛回 1-2 份，恢复可写状态。
   */
  private trimToStorageBudget(source: UserPlan[]): UserPlan[] {
    const deduped: UserPlan[] = []
    for (let index = 0; index < source.length; index++) {
      const plan: UserPlan = source[index]
      let replaced: boolean = false
      for (let kept = 0; kept < deduped.length; kept++) {
        if (deduped[kept].name === plan.name) {
          deduped[kept] = plan
          replaced = true
          break
        }
      }
      if (!replaced) {
        deduped.push(plan)
      }
    }

    while (deduped.length > 1 && this.jsonByteLength(deduped) > MAX_MY_PLANS_JSON_BYTES) {
      deduped.shift()
    }
    return deduped
  }

  private jsonByteLength(plans: UserPlan[]): number {
    const text: string = JSON.stringify(plans)
    try {
      const encoder: util.TextEncoder = new util.TextEncoder()
      return encoder.encodeInto(text).length
    } catch (e) {
      // 极端环境下退化为字符数估算（中文按 3 字节放大）。
      return text.length * 3
    }
  }

  private keepOnlyCurrentPlan(plans: UserPlan[], currentPlanId: string): UserPlan[] {
    const kept: UserPlan[] = []
    for (let index = 0; index < plans.length; index++) {
      if (plans[index].id === currentPlanId) {
        kept.push(plans[index])
        break
      }
    }
    return kept
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
    const index: number = resolveTodayTrainingIndex(plan.days, new Date().getDay())
    if (index < 0) {
      return null
    }
    return plan.days[index]
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

  /** 由预置定义即时重建用户计划（id 用预置 id，保证多次读取稳定）。 */
  private createUserPlanFromPreset(preset: PresetPlan): UserPlan {
    const plan: UserPlan = {
      id: preset.id,
      name: preset.name,
      coverColor: preset.coverColor,
      targetAudience: preset.targetAudience,
      weeklyFrequency: preset.weeklyFrequency,
      description: preset.description,
      days: this.copyTrainingDays(preset.days),
      enabledAt: 0
    }
    return plan
  }

  private createUserPlan(
    name: string,
    coverColor: string,
    targetAudience: string,
    weeklyFrequency: string,
    description: string,
    days: TrainingDay[]
  ): UserPlan {
    const plan: UserPlan = {
      id: 'user_plan_' + Date.now().toString(),
      name: name,
      coverColor: coverColor,
      targetAudience: targetAudience,
      weeklyFrequency: weeklyFrequency,
      description: description,
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
      description: source.description,
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

  private async repairCurrentPlanIfNeeded(context: Context, currentPlan: UserPlan, myPlans: UserPlan[]): Promise<UserPlan> {
    if (!this.containsPlaceholderExerciseName(currentPlan.days)) {
      return currentPlan
    }

    const goal = await GoalRepository.loadGoal(context)
    if (goal === undefined) {
      return currentPlan
    }

    const generatedPlan = PlanEngine.generatePlan(goal)
    if (generatedPlan.name !== currentPlan.name || generatedPlan.days.length !== currentPlan.days.length) {
      return currentPlan
    }

    const repairedPlan: UserPlan = this.copyUserPlan(currentPlan)
    let changed: boolean = false
    for (let dayIndex = 0; dayIndex < repairedPlan.days.length; dayIndex++) {
      const repairedDay: TrainingDay = repairedPlan.days[dayIndex]
      const generatedDay = generatedPlan.days[dayIndex]
      if (repairedDay.exercises.length !== generatedDay.exercises.length) {
        continue
      }
      for (let exerciseIndex = 0; exerciseIndex < repairedDay.exercises.length; exerciseIndex++) {
        const repairedExercise: ExerciseRef = repairedDay.exercises[exerciseIndex]
        if (!this.isPlaceholderName(repairedExercise.name)) {
          continue
        }
        const generatedExercise = generatedDay.exercises[exerciseIndex]
        const content = ContentRepository.getExerciseById(generatedExercise.exerciseId)
        if (content === undefined) {
          continue
        }
        repairedExercise.name = content.nameZh
        changed = true
      }
    }

    if (!changed) {
      return currentPlan
    }

    const updatedPlans: UserPlan[] = this.copyUserPlans(myPlans)
    for (let index = 0; index < updatedPlans.length; index++) {
      if (updatedPlans[index].id === repairedPlan.id) {
        updatedPlans[index] = this.copyUserPlan(repairedPlan)
        break
      }
    }
    await this.replaceMyPlans(context, updatedPlans, repairedPlan.id)
    return repairedPlan
  }

  private containsPlaceholderExerciseName(days: TrainingDay[]): boolean {
    for (let dayIndex = 0; dayIndex < days.length; dayIndex++) {
      const exercises: ExerciseRef[] = days[dayIndex].exercises
      for (let exerciseIndex = 0; exerciseIndex < exercises.length; exerciseIndex++) {
        if (this.isPlaceholderName(exercises[exerciseIndex].name)) {
          return true
        }
      }
    }
    return false
  }

  private isPlaceholderName(name: string): boolean {
    return name.indexOf('?') >= 0
  }
}

export default new TrainingPlanService()
