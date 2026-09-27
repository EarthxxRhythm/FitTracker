/**
 * ExerciseGifCatalog -- 训练演示 GIF 的解析目录。
 *
 * 素材位于 rawfile/exercise-gifs-onpage/<gifId>.gif（180×180、12 帧动作演示），
 * 由 tools/build-exercise-gifs-onpage.py 把原白底素材**按亮度软过渡合成到页面底色**上：
 * 颜色不动、白底区即页面底色、边缘是逐像素插值而非 1 bit 阈值，故既无白块也无锯齿。
 * 训练执行页的动作卡相应不设卡面底色（见 ActiveContent.demoVisual）。
 *
 * 文件名沿用动作库的 kebab 英文命名；训练执行页拿到的是动作中文名（内容库 nameZh），
 * 两套命名空间在此收敛：中文名 -> GIF 文件名 -> rawfile 路径。
 *
 * 未命中映射时回退到默认演示动作（杠铃卧推）——与原型的 .demo-visual 演示一致。
 */

export const DEFAULT_EXERCISE_GIF_ID: string = 'barbell-bench-press'

/** 演示素材目录（导出供单测断言复用，避免改目录时多处同步）。 */
export const DEMO_GIF_DIRECTORY: string = 'exercise-gifs-onpage/'
const GIF_SUFFIX: string = '.gif'

interface ExerciseGifGroup {
  gifId: string
  names: string[]
}

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

class ExerciseGifCatalogImpl {
  /** 动作中文名 -> GIF 文件名；未命中回退默认演示动作。 */
  resolveGifId(exerciseName: string): string {
    const name: string = exerciseName.trim()
    if (name.length === 0) {
      return DEFAULT_EXERCISE_GIF_ID
    }
    for (let groupIndex = 0; groupIndex < EXERCISE_GIF_GROUPS.length; groupIndex++) {
      const group: ExerciseGifGroup = EXERCISE_GIF_GROUPS[groupIndex]
      for (let nameIndex = 0; nameIndex < group.names.length; nameIndex++) {
        if (group.names[nameIndex] === name) {
          return group.gifId
        }
      }
    }
    return DEFAULT_EXERCISE_GIF_ID
  }

  /** 动作中文名 -> 训练执行页用的深色素材路径，可直接交给 $rawfile。 */
  resolveDemoSource(exerciseName: string): string {
    return this.demoSourceOfGifId(this.resolveGifId(exerciseName))
  }

  /** GIF 文件名 -> 深色素材路径。 */
  demoSourceOfGifId(gifId: string): string {
    return DEMO_GIF_DIRECTORY + gifId + GIF_SUFFIX
  }
}

export default new ExerciseGifCatalogImpl()
