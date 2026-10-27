/**
 * ExerciseGifCatalog -- 训练演示 GIF 的解析目录。
 *
 * ## 素材来源（2026-10-28 变更）
 *
 * 旧版有两套素材：23 个「线稿」+ 59 个 free-exercise-db 实拍。线稿套系经查为
 * Gym Visual（© gymvisual.com）素材，由第三方数据集转授权而来，授权链条不成立，
 * 已从仓库移除、不再分发（详见 ASSETS.md）。
 *
 * 现**唯一素材源**为 rawfile/exercise-gifs-photo/<gifId>.gif（180×180，12 帧）：
 * 由 tools/content/build-exercise-gifs-photo.mjs 从 free-exercise-db（Unlicense）的
 * 实拍照合成，色板 192 色、Bayer 抖动，三段乒乓循环。
 *
 * ## 为什么保留 EXERCISE_GIF_GROUPS
 *
 * 那 23 条「动作中文名 -> gifId」映射本身是资产：它们指向的动作在内容库里都存在，
 * 只是素材文件被撤下。DEMO_GIF_DIRECTORY 现指向 photo 目录，故这些 gifId 在补生成
 * 之前解析到不存在的文件，消费端由 ExerciseDemoImage 的失败回退降级为占位图标。
 *
 * 补全方式（需能访问 raw.githubusercontent.com）：
 *   node tools/content/build-exercise-gifs-photo.mjs --only squat,barbell-bench-press,...
 * 生成同名 <gifId>.gif 到 photo 目录后，这 23 个动作自动恢复，无需改本文件。
 *
 * 文件名沿用动作库的 kebab 英文命名；训练执行页拿到的是动作中文名（内容库 nameZh），
 * 两套命名空间在此收敛：中文名 -> GIF 文件名 -> rawfile 路径。
 *
 * 未命中映射时回退到 DEFAULT_EXERCISE_GIF_ID（该文件在 photo 目录中真实存在）。
 */

/**
 * 未命中映射时的默认演示素材。
 *
 * 必须指向 photo 目录中真实存在的文件，否则回退会二次落空、只剩占位图标。
 * （旧值 'barbell-bench-press' 只存在于已移除的线稿目录。）
 */
export const DEFAULT_EXERCISE_GIF_ID: string = 'barbell-deadlift'

/**
 * 演示素材目录（导出供单测断言复用，避免改目录时多处同步）。
 *
 * 与 PHOTO_GIF_DIRECTORY 同值：线稿目录已随版权清理撤下，两套目录收敛为一套。
 * 保留这个导出名是因为单测与消费端仍按「线稿层」语义引用它。
 */
export const DEMO_GIF_DIRECTORY: string = 'exercise-gifs-photo/'
const GIF_SUFFIX: string = '.gif'

/**
 * 实拍风格素材目录（free-exercise-db 实拍照合成，供线稿素材未覆盖的动作使用）。
 *
 * 与线稿素材的差异是**刻意的**：线稿素材把页底色烘进了图里（无缝），实拍照是全彩
 * 矩形实景、无白底，故由消费端的圆角卡片容器承载。详见
 * tools/content/build-exercise-gifs-photo.mjs 的文档头与 tools/content/exercise-photo-sources.json。
 */
export const PHOTO_GIF_DIRECTORY: string = 'exercise-gifs-photo/'

/** 内容库 exerciseId（ex_barbell_bench_press）-> kebab GIF 名（barbell-bench-press）。 */
export function gifIdOfExerciseId(exerciseId: string): string {
  const trimmed: string = exerciseId.trim()
  if (trimmed.length === 0) {
    return DEFAULT_EXERCISE_GIF_ID
  }
  let body: string = trimmed
  if (body.indexOf('ex_') === 0) {
    body = body.substring(3)
  }
  return body.replace(/_/g, '-')
}

interface ExerciseGifGroup {
  gifId: string
  names: string[]
}

/**
 * 旧「线稿」映射组（23 条）。素材文件因版权问题已移除，但映射数据保留：
 * 补生成同名 photo 素材后即可自动复活（见文件头说明）。
 */
const EXERCISE_GIF_GROUPS: ExerciseGifGroup[] = [
  {
    gifId: 'barbell-bench-press',
    names: ['杠铃卧推', '哑铃卧推', '上斜哑铃卧推', '器械推胸', '上斜器械推胸']
  },
  {
    gifId: 'push-up',
    names: ['俯卧撑', '窄距俯卧撑']
  },
  {
    gifId: 'dumbbell-fly',
    names: ['哑铃飞鸟']
  },
  {
    gifId: 'cable-crossover',
    names: ['绳索夹胸', '弹力带夹胸']
  },
  {
    gifId: 'pull-up',
    names: ['引体向上']
  },
  {
    gifId: 'barbell-row',
    names: ['杠铃划船', '单臂哑铃划船', '胸托划船', '绳索直立划船']
  },
  {
    gifId: 'seated-row',
    names: ['坐姿划船', '坐姿绳索划船']
  },
  {
    gifId: 'lat-pulldown',
    names: ['高位下拉', '反握高位下拉']
  },
  {
    gifId: 'band-pulldown',
    names: ['弹力带高位下拉']
  },
  {
    gifId: 'overhead-press',
    names: ['站姿推举', '杠铃推举', '哑铃肩推', '器械推肩']
  },
  {
    gifId: 'lateral-raise',
    names: ['侧平举', '哑铃侧平举', '绳索侧平举']
  },
  {
    gifId: 'band-lateral-raise',
    names: ['弹力带侧平举']
  },
  {
    gifId: 'face-pull',
    names: ['面拉']
  },
  {
    gifId: 'biceps-curl',
    names: ['二头弯举', '哑铃弯举', '杠铃弯举', '绳索锤式弯举']
  },
  {
    gifId: 'triceps-pushdown',
    names: ['绳索下压', '弹力带臂屈伸', '哑铃仰卧臂屈伸']
  },
  {
    gifId: 'squat',
    names: ['深蹲', '杠铃深蹲', '高脚杯深蹲', '哈克深蹲']
  },
  {
    gifId: 'lunge',
    names: ['弓步蹲', '行进弓步']
  },
  {
    gifId: 'leg-press',
    names: ['腿举', '单腿腿举']
  },
  {
    gifId: 'leg-curl',
    names: ['腿弯举']
  },
  {
    gifId: 'band-squat',
    names: ['弹力带深蹲']
  },
  {
    gifId: 'plank',
    names: ['平板支撑', '侧桥']
  },
  {
    gifId: 'crunch',
    names: ['卷腹']
  },
  {
    gifId: 'hanging-leg-raise',
    names: ['悬垂举腿', '悬垂提膝']
  }
]


/**
 * 实拍风格素材组（free-exercise-db 实拍照合成，见 tools/content/build-exercise-gifs-photo.mjs）。
 *
 * 与上方 EXERCISE_GIF_GROUPS（自制线稿）的分工：
 * - 线稿组先于本组解析，因此已被线稿覆盖的名字（如「杠铃划船」「腿弯举」）仍走既有素材，
 *   既有视觉主线零回归；本组只为线稿未覆盖的动作提供演示素材。
 * - 两组目录不同，由 resolveDemoSource 按命中组决定，故本组必须独立遍历。
 *
 * 数据来源：tools/content/exercise-photo-sources.json（人工逐条核对，59 条）。
 */
const EXERCISE_PHOTO_GIF_GROUPS: ExerciseGifGroup[] = [
  {
    gifId: 'dead-bug',
    names: ['死虫式', 'dead bug']
  },
  {
    gifId: 'romanian-deadlift',
    names: ['罗马尼亚硬拉', 'rdl']
  },
  {
    gifId: 'pallof-press',
    names: ['帕洛夫抗旋推', 'pallof']
  },
  {
    gifId: 'dumbbell-pullover',
    names: ['哑铃上拉', 'pullover']
  },
  {
    gifId: 'single-leg-romanian-deadlift',
    names: ['单腿罗马尼亚硬拉', 'single leg rdl']
  },
  {
    gifId: 'assisted-dip',
    names: ['辅助双杠臂屈伸', 'assisted dip']
  },
  {
    gifId: 'farmers-carry',
    names: ['农夫走', 'farmer carry']
  },
  {
    gifId: 'mountain-climber',
    names: ['登山者', 'mountain climber']
  },
  {
    gifId: 'kettlebell-swing-placeholder',
    names: ['髋铰链摆动', 'swing pattern']
  },
  {
    gifId: 'bodyweight-glute-bridge',
    names: ['臀桥', 'glute bridge']
  },
  {
    gifId: 'barbell-incline-bench-press',
    names: ['上斜杠铃卧推', '上斜卧推', 'incline bench press']
  },
  {
    gifId: 'decline-barbell-bench-press',
    names: ['下斜杠铃卧推', '下斜卧推', 'decline bench press']
  },
  {
    gifId: 'decline-dumbbell-bench-press',
    names: ['下斜哑铃卧推', '下斜哑铃推胸', 'decline dumbbell press']
  },
  {
    gifId: 'incline-dumbbell-flyes',
    names: ['上斜哑铃飞鸟', '上斜飞鸟', 'incline dumbbell fly']
  },
  {
    gifId: 'machine-chest-fly',
    names: ['蝴蝶机夹胸', '蝴蝶机', 'butterfly', 'pec deck']
  },
  {
    gifId: 'cable-crossover',
    names: ['龙门架交叉夹胸', '龙门架夹胸', 'cable crossover']
  },
  {
    gifId: 'wide-push-up',
    names: ['宽距俯卧撑', '宽距俯卧撑', 'wide push up']
  },
  {
    gifId: 'incline-push-up',
    names: ['上斜俯卧撑', '高位俯卧撑', 'incline push up']
  },
  {
    gifId: 'chin-up',
    names: ['反握引体向上', '反握引体', 'chin up']
  },
  {
    gifId: 'barbell-deadlift',
    names: ['杠铃硬拉', '硬拉', 'deadlift']
  },
  {
    gifId: 'bent-over-barbell-row',
    names: ['俯身杠铃划船', '杠铃划船', 'barbell row']
  },
  {
    gifId: 'close-grip-lat-pulldown',
    names: ['窄距高位下拉', '窄距下拉', 'close grip pulldown']
  },
  {
    gifId: 'dumbbell-shrug',
    names: ['哑铃耸肩', '耸肩', 'dumbbell shrug']
  },
  {
    gifId: 'barbell-shrug',
    names: ['杠铃耸肩', '杠铃耸肩', 'barbell shrug']
  },
  {
    gifId: 'rack-pull',
    names: ['架上硬拉', '架上拉', 'rack pull']
  },
  {
    gifId: 'straight-arm-pulldown',
    names: ['直臂下压', '直臂下拉', 'straight arm pulldown']
  },
  {
    gifId: 'standing-dumbbell-upright-row',
    names: ['站姿哑铃直立划船', '哑铃直立划船', 'dumbbell upright row']
  },
  {
    gifId: 'one-arm-kettlebell-row',
    names: ['单臂壶铃划船', '壶铃划船', 'kettlebell row']
  },
  {
    gifId: 'barbell-full-squat',
    names: ['杠铃全蹲', '全蹲', 'full squat']
  },
  {
    gifId: 'barbell-lunge',
    names: ['杠铃箭步蹲', '杠铃弓步', 'barbell lunge']
  },
  {
    gifId: 'dumbbell-lunges',
    names: ['哑铃箭步蹲', '哑铃弓步', 'dumbbell lunge']
  },
  {
    gifId: 'leg-extensions',
    names: ['坐姿腿屈伸', '腿屈伸', 'leg extension']
  },
  {
    gifId: 'lying-leg-curls',
    names: ['俯卧腿弯举', '腿弯举', 'lying leg curl']
  },
  {
    gifId: 'seated-calf-raise',
    names: ['坐姿提踵', '坐姿提踵', 'seated calf raise']
  },
  {
    gifId: 'standing-calf-raises',
    names: ['站姿提踵', '站姿提踵', 'standing calf raise']
  },
  {
    gifId: 'deficit-romanian-deadlift',
    names: ['垫高罗马尼亚硬拉', '垫高 RDL', 'deficit RDL']
  },
  {
    gifId: 'dumbbell-step-ups',
    names: ['哑铃登阶', '登阶', 'step up']
  },
  {
    gifId: 'smith-machine-squat',
    names: ['史密斯机深蹲', '史密斯深蹲', 'smith squat']
  },
  {
    gifId: 'barbell-hip-thrust',
    names: ['杠铃臀推', '臀推', 'hip thrust']
  },
  {
    gifId: 'seated-barbell-shoulder-press',
    names: ['坐姿杠铃肩推', '坐姿推举', 'seated shoulder press']
  },
  {
    gifId: 'front-dumbbell-raise',
    names: ['哑铃前平举', '前平举', 'front raise']
  },
  {
    gifId: 'reverse-flyes',
    names: ['俯卧上斜哑铃飞鸟', '后束飞鸟', 'reverse fly']
  },
  {
    gifId: 'arnold-dumbbell-press',
    names: ['阿诺德推举', '阿诺德推', 'arnold press']
  },
  {
    gifId: 'upright-barbell-row',
    names: ['杠铃直立划船', '直立划船', 'upright row']
  },
  {
    gifId: 'seated-rear-delt-raise',
    names: ['坐姿俯身后束飞鸟', '坐姿后束飞鸟', 'rear delt raise']
  },
  {
    gifId: 'cable-shoulder-press',
    names: ['绳索肩推', '龙门架肩推', 'cable shoulder press']
  },
  {
    gifId: 'alternate-hammer-curl',
    names: ['交替锤式弯举', '锤式弯举', 'hammer curl']
  },
  {
    gifId: 'preacher-curl',
    names: ['牧师凳弯举', '牧师凳弯举', 'preacher curl']
  },
  {
    gifId: 'concentration-curls',
    names: ['集中弯举', '集中弯举', 'concentration curl']
  },
  {
    gifId: 'close-grip-barbell-bench-press',
    names: ['窄距杠铃卧推', '窄距卧推', 'close grip bench press']
  },
  {
    gifId: 'triceps-dip',
    names: ['双杠臂屈伸（三头）', '双杠臂屈伸', 'triceps dip']
  },
  {
    gifId: 'standing-dumbbell-triceps-extension',
    names: ['站姿哑铃臂屈伸', '哑铃颈后臂屈伸', 'overhead triceps extension']
  },
  {
    gifId: 'bench-dips',
    names: ['凳上臂屈伸', '凳上臂屈伸', 'bench dip']
  },
  {
    gifId: 'lying-triceps-press',
    names: ['仰卧杠铃臂屈伸', '仰卧臂屈伸', 'lying triceps extension', '碎颅式']
  },
  {
    gifId: 'three-quarter-sit-up',
    names: ['四分之三卷腹', '3/4 卷腹', 'three quarter sit up']
  },
  {
    gifId: 'russian-twist',
    names: ['俄罗斯转体', '俄罗斯转体', 'russian twist']
  },
  {
    gifId: 'cable-crunch',
    names: ['绳索卷腹', '绳索卷腹', 'cable crunch']
  },
  {
    gifId: 'alternating-kettlebell-press',
    names: ['壶铃交替推举', '壶铃交替推举', 'kettlebell press']
  },
  {
    gifId: 'flutter-kicks',
    names: ['俯卧剪刀腿', '剪刀腿', 'flutter kicks']
  }
]

class ExerciseGifCatalogImpl {
  /** 动作中文名 -> GIF 文件名；未命中回退默认演示动作。 */
  resolveGifId(exerciseName: string): string {
    const name: string = exerciseName.trim()
    if (name.length === 0) {
      return DEFAULT_EXERCISE_GIF_ID
    }
    const lineArtId: string = this.findInGroups(EXERCISE_GIF_GROUPS, name)
    if (lineArtId.length > 0) {
      return lineArtId
    }
    const photoId: string = this.findInGroups(EXERCISE_PHOTO_GIF_GROUPS, name)
    if (photoId.length > 0) {
      return photoId
    }
    return DEFAULT_EXERCISE_GIF_ID
  }

  /** 在给定分组里按中文名精确查找；未命中返回空串。 */
  private findInGroups(groups: ExerciseGifGroup[], name: string): string {
    for (let groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      const group: ExerciseGifGroup = groups[groupIndex]
      for (let nameIndex = 0; nameIndex < group.names.length; nameIndex++) {
        if (group.names[nameIndex] === name) {
          return group.gifId
        }
      }
    }
    return ''
  }

  /** 动作中文名 -> 训练执行页用的素材路径，可直接交给 $rawfile。 */
  resolveDemoSource(exerciseName: string): string {
    const name: string = exerciseName.trim()
    if (name.length > 0) {
      const lineArtId: string = this.findInGroups(EXERCISE_GIF_GROUPS, name)
      if (lineArtId.length > 0) {
        return DEMO_GIF_DIRECTORY + lineArtId + GIF_SUFFIX
      }
      const photoId: string = this.findInGroups(EXERCISE_PHOTO_GIF_GROUPS, name)
      if (photoId.length > 0) {
        return PHOTO_GIF_DIRECTORY + photoId + GIF_SUFFIX
      }
    }
    return DEMO_GIF_DIRECTORY + DEFAULT_EXERCISE_GIF_ID + GIF_SUFFIX
  }

  /** 动作中文名是否命中实拍风格素材（消费端据此决定是否套圆角卡片）。 */
  usesPhotoStyle(exerciseName: string): boolean {
    const name: string = exerciseName.trim()
    if (name.length === 0) {
      return false
    }
    if (this.findInGroups(EXERCISE_GIF_GROUPS, name).length > 0) {
      return false
    }
    return this.findInGroups(EXERCISE_PHOTO_GIF_GROUPS, name).length > 0
  }

  /** GIF 文件名 -> 深色素材路径。 */
  demoSourceOfGifId(gifId: string): string {
    return DEMO_GIF_DIRECTORY + gifId + GIF_SUFFIX
  }

  /**
   * 内容库 exerciseId（ex_barbell_bench_press）-> 素材路径，可直接交给 $rawfile。
   *
   * 动作库页拿到的是内容库 id 而非中文名，故单独给出按 id 的入口：先在线稿组里找，
   * 再在实拍组里找，都未命中才回退默认演示动作。id 由 gifIdOfExerciseId 归一化
   * （去 ex_ 前缀、下划线转连字符），与两组表的 gifId 命名一致。
   */
  resolveDemoSourceByExerciseId(exerciseId: string): string {
    const gifId: string = gifIdOfExerciseId(exerciseId)
    if (this.hasGifId(EXERCISE_GIF_GROUPS, gifId)) {
      return DEMO_GIF_DIRECTORY + gifId + GIF_SUFFIX
    }
    if (this.hasGifId(EXERCISE_PHOTO_GIF_GROUPS, gifId)) {
      return PHOTO_GIF_DIRECTORY + gifId + GIF_SUFFIX
    }
    return DEMO_GIF_DIRECTORY + DEFAULT_EXERCISE_GIF_ID + GIF_SUFFIX
  }

  /** 按 exerciseId 判断是否命中实拍风格素材（消费端据此决定容器形态）。 */
  usesPhotoStyleByExerciseId(exerciseId: string): boolean {
    const gifId: string = gifIdOfExerciseId(exerciseId)
    if (this.hasGifId(EXERCISE_GIF_GROUPS, gifId)) {
      return false
    }
    return this.hasGifId(EXERCISE_PHOTO_GIF_GROUPS, gifId)
  }

  private hasGifId(groups: ExerciseGifGroup[], gifId: string): boolean {
    if (gifId.length === 0) {
      return false
    }
    for (let index = 0; index < groups.length; index++) {
      if (groups[index].gifId === gifId) {
        return true
      }
    }
    return false
  }
}

export default new ExerciseGifCatalogImpl()
