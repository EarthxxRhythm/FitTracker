/**
 * TrainingPlanService �?训练计划服务
 *
 * 功能 #7: 提供5套预置训练计划数据，每套包含训练日及动作清单�? * 功能 #9: 启用预置计划 �?克隆至我的计划并设为当前计划，持久化存储�? * 预置计划为只读模板，启用时通过克隆生成用户计划�? */
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

const PRESET_PLANS: PresetPlan[] = [
  {
    id: 'preset_bro_split',
    name: '五分化训�?,
    coverColor: '#1E88E5',
    targetAudience: '中高级健身�?,
    weeklyFrequency: '5�?�?,
    days: [
      {
        dayLabel: '周一 胸部',
        dayOfWeek: [1],
        exercises: [
          { name: '杠铃平板卧推', targetMuscle: '�?, sets: 4, reps: '8-12' },
          { name: '上斜哑铃卧推', targetMuscle: '�?, sets: 3, reps: '8-12' },
          { name: '哑铃飞鸟', targetMuscle: '�?, sets: 3, reps: '12-15' },
          { name: '绳索夹胸', targetMuscle: '�?, sets: 3, reps: '12-15' },
          { name: '双杠臂屈�?, targetMuscle: '�?, sets: 3, reps: '8-12' }
        ]
      },
      {
        dayLabel: '周二 背部',
        dayOfWeek: [2],
        exercises: [
          { name: '引体向上', targetMuscle: '�?, sets: 4, reps: '8-12' },
          { name: '杠铃划船', targetMuscle: '�?, sets: 4, reps: '8-12' },
          { name: '高位下拉', targetMuscle: '�?, sets: 3, reps: '10-12' },
          { name: '坐姿划船', targetMuscle: '�?, sets: 3, reps: '10-12' },
          { name: '面拉', targetMuscle: '�?, sets: 3, reps: '12-15' }
        ]
      },
      {
        dayLabel: '周三 腿部',
        dayOfWeek: [3],
        exercises: [
          { name: '杠铃深蹲', targetMuscle: '�?, sets: 4, reps: '8-12' },
          { name: '罗马尼亚硬拉', targetMuscle: '�?, sets: 3, reps: '8-12' },
          { name: '腿举', targetMuscle: '�?, sets: 3, reps: '10-12' },
          { name: '腿弯�?, targetMuscle: '�?, sets: 3, reps: '12-15' },
          { name: '提踵', targetMuscle: '�?, sets: 4, reps: '15-20' }
        ]
      },
      {
        dayLabel: '周四 肩部',
        dayOfWeek: [4],
        exercises: [
          { name: '杠铃推举', targetMuscle: '�?, sets: 4, reps: '8-12' },
          { name: '哑铃侧平�?, targetMuscle: '�?, sets: 3, reps: '12-15' },
          { name: '前平�?, targetMuscle: '�?, sets: 3, reps: '12-15' },
          { name: '俯身飞鸟', targetMuscle: '�?, sets: 3, reps: '12-15' },
          { name: '耸肩', targetMuscle: '�?, sets: 3, reps: '12-15' }
        ]
      },
      {
        dayLabel: '周五 手臂',
        dayOfWeek: [5],
        exercises: [
          { name: '杠铃弯举', targetMuscle: '�?, sets: 4, reps: '8-12' },
          { name: '哑铃锤式弯举', targetMuscle: '�?, sets: 3, reps: '10-12' },
          { name: '窄距卧推', targetMuscle: '�?, sets: 4, reps: '8-12' },
          { name: '绳索下压', targetMuscle: '�?, sets: 3, reps: '12-15' },
          { name: '集中弯举', targetMuscle: '�?, sets: 3, reps: '12-15' }
        ]
      }
    ]
  },
  {
    id: 'preset_upper_lower',
    name: '上下肢分�?,
    coverColor: '#43A047',
    targetAudience: '初中级健身�?,
    weeklyFrequency: '4�?�?,
    days: [
      {
        dayLabel: '周一 上肢�?,
        dayOfWeek: [1],
        exercises: [
          { name: '杠铃平板卧推', targetMuscle: '�?, sets: 4, reps: '8-12' },
          { name: '哑铃推举', targetMuscle: '�?, sets: 3, reps: '8-12' },
          { name: '上斜哑铃飞鸟', targetMuscle: '�?, sets: 3, reps: '10-15' },
          { name: '侧平�?, targetMuscle: '�?, sets: 3, reps: '12-15' },
          { name: '绳索下压', targetMuscle: '�?, sets: 3, reps: '12-15' }
        ]
      },
      {
        dayLabel: '周二 下肢',
        dayOfWeek: [2],
        exercises: [
          { name: '杠铃深蹲', targetMuscle: '�?, sets: 4, reps: '8-12' },
          { name: '罗马尼亚硬拉', targetMuscle: '�?, sets: 3, reps: '8-12' },
          { name: '保加利亚分腿�?, targetMuscle: '�?, sets: 3, reps: '10-12' },
          { name: '腿弯�?, targetMuscle: '�?, sets: 3, reps: '12-15' },
          { name: '提踵', targetMuscle: '�?, sets: 3, reps: '15-20' }
        ]
      },
      {
        dayLabel: '周四 上肢�?,
        dayOfWeek: [4],

        exercises: [
          { name: '引体向上', targetMuscle: '�?, sets: 4, reps: '8-12' },
          { name: '杠铃划船', targetMuscle: '�?, sets: 3, reps: '8-12' },
          { name: '高位下拉', targetMuscle: '�?, sets: 3, reps: '10-12' },
          { name: '面拉', targetMuscle: '�?, sets: 3, reps: '12-15' },
          { name: '杠铃弯举', targetMuscle: '�?, sets: 3, reps: '10-12' }
        ]
      },
      {
        dayLabel: '周五 下肢',
        dayOfWeek: [5],

        exercises: [
          { name: '杠铃深蹲', targetMuscle: '�?, sets: 4, reps: '6-10' },
          { name: '腿举', targetMuscle: '�?, sets: 3, reps: '10-12' },
          { name: '腿弯�?, targetMuscle: '�?, sets: 3, reps: '12-15' },
          { name: '腿伸�?, targetMuscle: '�?, sets: 3, reps: '12-15' },
          { name: '提踵', targetMuscle: '�?, sets: 3, reps: '15-20' }
        ]
      }
    ]
  },
  {
    id: 'preset_ppl',
    name: '推拉腿分�?,
    coverColor: '#FB8C00',
    targetAudience: '初中高级通用',
    weeklyFrequency: '3-6�?�?,
    days: [
      {
        dayLabel: '推日',
        dayOfWeek: [1, 4],

        exercises: [
          { name: '杠铃平板卧推', targetMuscle: '�?, sets: 4, reps: '8-12' },
          { name: '哑铃推举', targetMuscle: '�?, sets: 3, reps: '8-12' },
          { name: '上斜哑铃卧推', targetMuscle: '�?, sets: 3, reps: '8-12' },
          { name: '侧平�?, targetMuscle: '�?, sets: 3, reps: '12-15' },
          { name: '窄距卧推', targetMuscle: '�?, sets: 3, reps: '8-12' }
        ]
      },
      {
        dayLabel: '拉日',
        dayOfWeek: [2, 5],

        exercises: [
          { name: '引体向上', targetMuscle: '�?, sets: 4, reps: '8-12' },
          { name: '杠铃划船', targetMuscle: '�?, sets: 4, reps: '8-12' },
          { name: '坐姿划船', targetMuscle: '�?, sets: 3, reps: '10-12' },
          { name: '面拉', targetMuscle: '�?, sets: 3, reps: '12-15' },
          { name: '杠铃弯举', targetMuscle: '�?, sets: 3, reps: '10-12' }
        ]
      },
      {
        dayLabel: '腿日',
        dayOfWeek: [3, 6],

        exercises: [
          { name: '杠铃深蹲', targetMuscle: '�?, sets: 4, reps: '8-12' },
          { name: '罗马尼亚硬拉', targetMuscle: '�?, sets: 3, reps: '8-12' },
          { name: '腿举', targetMuscle: '�?, sets: 3, reps: '10-12' },
          { name: '腿弯�?, targetMuscle: '�?, sets: 3, reps: '12-15' },
          { name: '提踵', targetMuscle: '�?, sets: 4, reps: '15-20' }
        ]
      }
    ]
  },
  {
    id: 'preset_fullbody_3x',
    name: '全身训练 3x',
    coverColor: '#8E24AA',
    targetAudience: '初级健身�?,
    weeklyFrequency: '3�?�?,
    days: [
      {
        dayLabel: '周一 全身',
        dayOfWeek: [1],

        exercises: [
          { name: '杠铃深蹲', targetMuscle: '�?, sets: 3, reps: '8-12' },
          { name: '杠铃平板卧推', targetMuscle: '�?, sets: 3, reps: '8-12' },
          { name: '杠铃划船', targetMuscle: '�?, sets: 3, reps: '8-12' },
          { name: '杠铃推举', targetMuscle: '�?, sets: 3, reps: '8-12' },
          { name: '杠铃弯举', targetMuscle: '�?, sets: 2, reps: '10-12' },
          { name: '平板支撑', targetMuscle: '�?, sets: 3, reps: '30�? }
        ]
      },
      {
        dayLabel: '周三 全身',
        dayOfWeek: [3],

        exercises: [
          { name: '罗马尼亚硬拉', targetMuscle: '�?, sets: 3, reps: '8-12' },
          { name: '哑铃卧推', targetMuscle: '�?, sets: 3, reps: '8-12' },
          { name: '高位下拉', targetMuscle: '�?, sets: 3, reps: '8-12' },
          { name: '侧平�?, targetMuscle: '�?, sets: 3, reps: '12-15' },
          { name: '绳索下压', targetMuscle: '�?, sets: 2, reps: '12-15' },
          { name: '卷腹', targetMuscle: '�?, sets: 3, reps: '15-20' }
        ]
      },
      {
        dayLabel: '周五 全身',
        dayOfWeek: [5],

        exercises: [
          { name: '杠铃深蹲', targetMuscle: '�?, sets: 3, reps: '8-12' },
          { name: '上斜哑铃卧推', targetMuscle: '�?, sets: 3, reps: '8-12' },
          { name: '坐姿划船', targetMuscle: '�?, sets: 3, reps: '10-12' },
          { name: '哑铃推举', targetMuscle: '�?, sets: 3, reps: '8-12' },
          { name: '锤式弯举', targetMuscle: '�?, sets: 2, reps: '10-12' },
          { name: '悬垂举腿', targetMuscle: '�?, sets: 3, reps: '12-15' }
        ]
      }
    ]
  },
  {
    id: 'preset_powerlifting',
    name: '力量举基础',
    coverColor: '#E53935',
    targetAudience: '力量举入�?,
    weeklyFrequency: '3-4�?�?,
    days: [
      {
        dayLabel: '深蹲�?,
        dayOfWeek: [1],
        exercises: [
          { name: '杠铃深蹲', targetMuscle: '�?, sets: 5, reps: '5' },
          { name: '前蹲', targetMuscle: '�?, sets: 3, reps: '6-8' },
          { name: '腿弯�?, targetMuscle: '�?, sets: 3, reps: '8-12' },
          { name: '提踵', targetMuscle: '�?, sets: 3, reps: '12-15' },
          { name: '平板支撑', targetMuscle: '�?, sets: 3, reps: '30�? }
        ]
      },
      {
        dayLabel: '卧推�?,
        dayOfWeek: [2],
        exercises: [
          { name: '杠铃平板卧推', targetMuscle: '�?, sets: 5, reps: '5' },
          { name: '窄距卧推', targetMuscle: '�?, sets: 3, reps: '6-8' },
          { name: '哑铃推举', targetMuscle: '�?, sets: 3, reps: '8-12' },
          { name: '绳索下压', targetMuscle: '�?, sets: 3, reps: '10-12' },
          { name: '面拉', targetMuscle: '�?, sets: 3, reps: '12-15' }
        ]
      },
      {
        dayLabel: '硬拉�?,
        dayOfWeek: [4],
        exercises: [
          { name: '杠铃硬拉', targetMuscle: '�?, sets: 5, reps: '5' },
          { name: '杠铃划船', targetMuscle: '�?, sets: 3, reps: '6-8' },
          { name: '引体向上', targetMuscle: '�?, sets: 3, reps: '6-8' },
          { name: '杠铃弯举', targetMuscle: '�?, sets: 3, reps: '8-12' },
          { name: '卷腹', targetMuscle: '�?, sets: 3, reps: '12-15' }
        ]
      },
      {
        dayLabel: '辅助日（可选）',
        dayOfWeek: [5],
        exercises: [
          { name: '腿举', targetMuscle: '�?, sets: 3, reps: '8-12' },
          { name: '坐姿划船', targetMuscle: '�?, sets: 3, reps: '10-12' },
          { name: '侧平�?, targetMuscle: '�?, sets: 3, reps: '12-15' },
          { name: '锤式弯举', targetMuscle: '�?, sets: 3, reps: '10-12' },
          { name: '提踵', targetMuscle: '�?, sets: 3, reps: '15-20' }
        ]
      }
    ]
  }
]

class TrainingPlanService {
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
    const userPlan: UserPlan = {
      id: `user_plan_${Date.now()}`,
      name: preset.name,
      coverColor: preset.coverColor,
      targetAudience: preset.targetAudience,
      weeklyFrequency: preset.weeklyFrequency,
      days: JSON.parse(JSON.stringify(preset.days)),
      enabledAt: Date.now()
    }
    const myPlans = await this.getMyPlans(context)
    myPlans.push(userPlan)
    const prefs = await preferences.getPreferences(context, STORE_NAME)
    await prefs.put(KEY_MY_PLANS, JSON.stringify(myPlans))
    await prefs.put(KEY_CURRENT_PLAN_ID, userPlan.id)
    await prefs.flush()
    return userPlan
  }

  async getMyPlans(context: Context): Promise<UserPlan[]> {
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      const json = await prefs.get(KEY_MY_PLANS, '[]') as string
      return JSON.parse(json) as UserPlan[]
    } catch (e) {
      return []
    }
  }

  async getCurrentPlan(context: Context): Promise<UserPlan | null> {
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      const currentId = await prefs.get(KEY_CURRENT_PLAN_ID, '') as string
      if (!currentId) {
        return null
      }
      const myPlans = await this.getMyPlans(context)
      return myPlans.find(p => p.id === currentId) || null
    } catch (e) {
      return null
    }
  }

  async setCurrentPlan(context: Context, planId: string): Promise<void> {
    const prefs = await preferences.getPreferences(context, STORE_NAME)
    await prefs.put(KEY_CURRENT_PLAN_ID, planId)
    await prefs.flush()
  }

  async removeMyPlan(context: Context, planId: string): Promise<void> {
    let myPlans = await this.getMyPlans(context)
    myPlans = myPlans.filter(p => p.id !== planId)
    const prefs = await preferences.getPreferences(context, STORE_NAME)
    const currentId = await prefs.get(KEY_CURRENT_PLAN_ID, '') as string
    if (currentId === planId) {
      await prefs.put(KEY_CURRENT_PLAN_ID, myPlans.length > 0 ? myPlans[0].id : '')
    }
    await prefs.put(KEY_MY_PLANS, JSON.stringify(myPlans))
    await prefs.flush()
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
    const dayNames: Record<string, number> = {
      '周一': 1, '周二': 2, '周三': 3, '周四': 4, '周五': 5, '周六': 6, '周日': 0
    }
    for (let day of plan.days) {
      for (let key in dayNames) {
        if (day.dayLabel.includes(key) && dayNames[key] === today) {
          return day
        }
      }
    }
    return null
  }

  isTrainingDay(plan: UserPlan): boolean {
    return this.getTodayTraining(plan) !== null
  }

  getTodayLabel(): string {
    const labels = ['星期�?, '星期一', '星期�?, '星期�?, '星期�?, '星期�?, '星期�?]
    return labels[new Date().getDay()]
  }
}

export default new TrainingPlanService()
