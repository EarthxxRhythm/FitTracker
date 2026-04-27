/**
 * ExerciseService — 动作库数据服务
 *
 * 功能 #13-16: 提供动作库数据，支持搜索、肌群筛选、器械筛选、分页加载。
 */
export interface Exercise {
  id: string
  name: string
  aliases: string[]
  primaryMuscle: string
  secondaryMuscle: string
  equipment: string
  description: string
  instructions: string
}

const EXERCISES: Exercise[] = [
  // 胸部
  { id: 'e1', name: '杠铃平板卧推', aliases: ['卧推', '平板卧推'], primaryMuscle: '胸', secondaryMuscle: '肩', equipment: '杠铃', description: '', instructions: '' },
  { id: 'e2', name: '上斜哑铃卧推', aliases: ['上斜卧推'], primaryMuscle: '胸', secondaryMuscle: '肩', equipment: '哑铃', description: '', instructions: '' },
  { id: 'e3', name: '哑铃飞鸟', aliases: ['飞鸟'], primaryMuscle: '胸', secondaryMuscle: '肩', equipment: '哑铃', description: '', instructions: '' },
  { id: 'e4', name: '绳索夹胸', aliases: ['夹胸', '龙门架夹胸'], primaryMuscle: '胸', secondaryMuscle: '肩', equipment: '绳索', description: '', instructions: '' },
  { id: 'e5', name: '双杠臂屈伸', aliases: ['臂屈伸', '双杠'], primaryMuscle: '胸', secondaryMuscle: '臂', equipment: '自重', description: '', instructions: '' },
  { id: 'e6', name: '俯卧撑', aliases: ['push up'], primaryMuscle: '胸', secondaryMuscle: '臂', equipment: '自重', description: '', instructions: '' },
  { id: 'e7', name: '下斜杠铃卧推', aliases: ['下斜卧推'], primaryMuscle: '胸', secondaryMuscle: '臂', equipment: '杠铃', description: '', instructions: '' },
  // 背部
  { id: 'e8', name: '引体向上', aliases: ['pull up', '引体'], primaryMuscle: '背', secondaryMuscle: '臂', equipment: '自重', description: '', instructions: '' },
  { id: 'e9', name: '杠铃划船', aliases: ['划船', '俯身划船'], primaryMuscle: '背', secondaryMuscle: '臂', equipment: '杠铃', description: '', instructions: '' },
  { id: 'e10', name: '高位下拉', aliases: ['lat pulldown', '下拉'], primaryMuscle: '背', secondaryMuscle: '臂', equipment: '绳索', description: '', instructions: '' },
  { id: 'e11', name: '坐姿划船', aliases: ['seated row'], primaryMuscle: '背', secondaryMuscle: '臂', equipment: '绳索', description: '', instructions: '' },
  { id: 'e12', name: '哑铃单臂划船', aliases: ['单臂划船'], primaryMuscle: '背', secondaryMuscle: '臂', equipment: '哑铃', description: '', instructions: '' },
  { id: 'e13', name: '杠铃硬拉', aliases: ['硬拉', 'deadlift'], primaryMuscle: '背', secondaryMuscle: '腿', equipment: '杠铃', description: '', instructions: '' },
  { id: 'e14', name: '面拉', aliases: ['face pull'], primaryMuscle: '背', secondaryMuscle: '肩', equipment: '绳索', description: '', instructions: '' },
  // 腿部
  { id: 'e15', name: '杠铃深蹲', aliases: ['深蹲', 'squat'], primaryMuscle: '腿', secondaryMuscle: '背', equipment: '杠铃', description: '', instructions: '' },
  { id: 'e16', name: '罗马尼亚硬拉', aliases: ['RDL'], primaryMuscle: '腿', secondaryMuscle: '背', equipment: '杠铃', description: '', instructions: '' },
  { id: 'e17', name: '腿举', aliases: ['leg press', '倒蹬'], primaryMuscle: '腿', secondaryMuscle: '腿', equipment: '固定器械', description: '', instructions: '' },
  { id: 'e18', name: '腿弯举', aliases: ['leg curl'], primaryMuscle: '腿', secondaryMuscle: '腿', equipment: '固定器械', description: '', instructions: '' },
  { id: 'e19', name: '腿伸展', aliases: ['leg extension'], primaryMuscle: '腿', secondaryMuscle: '腿', equipment: '固定器械', description: '', instructions: '' },
  { id: 'e20', name: '保加利亚分腿蹲', aliases: ['保加利亚蹲'], primaryMuscle: '腿', secondaryMuscle: '腿', equipment: '哑铃', description: '', instructions: '' },
  { id: 'e21', name: '提踵', aliases: ['calf raise'], primaryMuscle: '腿', secondaryMuscle: '腿', equipment: '固定器械', description: '', instructions: '' },
  // 肩部
  { id: 'e22', name: '杠铃推举', aliases: ['推举', '杠铃肩推'], primaryMuscle: '肩', secondaryMuscle: '臂', equipment: '杠铃', description: '', instructions: '' },
  { id: 'e23', name: '哑铃侧平举', aliases: ['侧平举'], primaryMuscle: '肩', secondaryMuscle: '肩', equipment: '哑铃', description: '', instructions: '' },
  { id: 'e24', name: '前平举', aliases: ['front raise'], primaryMuscle: '肩', secondaryMuscle: '肩', equipment: '哑铃', description: '', instructions: '' },
  { id: 'e25', name: '俯身飞鸟', aliases: ['后束飞鸟'], primaryMuscle: '肩', secondaryMuscle: '背', equipment: '哑铃', description: '', instructions: '' },
  { id: 'e26', name: '杠铃耸肩', aliases: ['耸肩', 'shrug'], primaryMuscle: '肩', secondaryMuscle: '背', equipment: '杠铃', description: '', instructions: '' },
  { id: 'e27', name: '阿诺德推举', aliases: ['阿诺德推'], primaryMuscle: '肩', secondaryMuscle: '臂', equipment: '哑铃', description: '', instructions: '' },
  // 手臂
  { id: 'e28', name: '杠铃弯举', aliases: ['弯举', 'barbell curl'], primaryMuscle: '臂', secondaryMuscle: '臂', equipment: '杠铃', description: '', instructions: '' },
  { id: 'e29', name: '哑铃锤式弯举', aliases: ['锤式弯举'], primaryMuscle: '臂', secondaryMuscle: '臂', equipment: '哑铃', description: '', instructions: '' },
  { id: 'e30', name: '窄距卧推', aliases: ['窄推'], primaryMuscle: '臂', secondaryMuscle: '胸', equipment: '杠铃', description: '', instructions: '' },
  { id: 'e31', name: '绳索下压', aliases: ['tricep pushdown'], primaryMuscle: '臂', secondaryMuscle: '臂', equipment: '绳索', description: '', instructions: '' },
  { id: 'e32', name: '集中弯举', aliases: ['concentration curl'], primaryMuscle: '臂', secondaryMuscle: '臂', equipment: '哑铃', description: '', instructions: '' },
  { id: 'e33', name: '过头臂屈伸', aliases: ['overhead extension'], primaryMuscle: '臂', secondaryMuscle: '肩', equipment: '哑铃', description: '', instructions: '' },
  { id: 'e34', name: 'EZ杠弯举', aliases: ['EZ curl'], primaryMuscle: '臂', secondaryMuscle: '臂', equipment: '杠铃', description: '', instructions: '' },
  // 腹部
  { id: 'e35', name: '卷腹', aliases: ['crunch'], primaryMuscle: '腹', secondaryMuscle: '腹', equipment: '自重', description: '', instructions: '' },
  { id: 'e36', name: '平板支撑', aliases: ['plank'], primaryMuscle: '腹', secondaryMuscle: '背', equipment: '自重', description: '', instructions: '' },
  { id: 'e37', name: '悬垂举腿', aliases: ['hanging leg raise'], primaryMuscle: '腹', secondaryMuscle: '臂', equipment: '自重', description: '', instructions: '' },
  { id: 'e38', name: '俄罗斯转体', aliases: ['russian twist'], primaryMuscle: '腹', secondaryMuscle: '腹', equipment: '自重', description: '', instructions: '' },
  { id: 'e39', name: '哑铃腹肌卷腹', aliases: ['decline crunch'], primaryMuscle: '腹', secondaryMuscle: '腹', equipment: '哑铃', description: '', instructions: '' },
  { id: 'e40', name: '山羊挺身', aliases: ['back extension'], primaryMuscle: '背', secondaryMuscle: '腿', equipment: '固定器械', description: '', instructions: '' },
  { id: 'e41', name: '前蹲', aliases: ['front squat'], primaryMuscle: '腿', secondaryMuscle: '背', equipment: '杠铃', description: '', instructions: '' },
  { id: 'e42', name: '史密斯机深蹲', aliases: ['smith squat'], primaryMuscle: '腿', secondaryMuscle: '腿', equipment: '固定器械', description: '', instructions: '' },
  { id: 'e43', name: '直臂下拉', aliases: ['straight arm pulldown'], primaryMuscle: '背', secondaryMuscle: '肩', equipment: '绳索', description: '', instructions: '' },
  { id: 'e44', name: 'T杠划船', aliases: ['T bar row'], primaryMuscle: '背', secondaryMuscle: '臂', equipment: '杠铃', description: '', instructions: '' },
  { id: 'e45', name: '器械推胸', aliases: ['machine chest press'], primaryMuscle: '胸', secondaryMuscle: '肩', equipment: '固定器械', description: '', instructions: '' },
]

const PAGE_SIZE = 20

class ExerciseService {
  getAll(): Exercise[] {
    return EXERCISES
  }

  search(query: string): Exercise[] {
    if (!query || query.trim().length === 0) {
      return EXERCISES
    }
    const q = query.trim().toLowerCase()
    return EXERCISES.filter(e =>
      e.name.toLowerCase().includes(q) ||
      e.aliases.some(a => a.toLowerCase().includes(q))
    )
  }

  filterByMuscle(muscle: string): Exercise[] {
    if (!muscle || muscle === '全部') {
      return EXERCISES
    }
    return EXERCISES.filter(e => e.primaryMuscle === muscle)
  }

  filterByEquipment(equipment: string): Exercise[] {
    if (!equipment || equipment === '全部') {
      return EXERCISES
    }
    return EXERCISES.filter(e => e.equipment === equipment)
  }

  getPage(items: Exercise[], page: number): Exercise[] {
    const start = (page - 1) * PAGE_SIZE
    return items.slice(start, start + PAGE_SIZE)
  }

  hasMore(items: Exercise[], page: number): boolean {
    return page * PAGE_SIZE < items.length
  }

  getById(id: string): Exercise | undefined {
    return EXERCISES.find(e => e.id === id)
  }

  getMuscleGroups(): string[] {
    return ['全部', '胸', '背', '腿', '肩', '臂', '腹']
  }

  getEquipmentTypes(): string[] {
    return ['杠铃', '哑铃', '绳索', '固定器械', '自重']
  }

  getTotalCount(): number {
    return EXERCISES.length
  }
}

export default new ExerciseService()
