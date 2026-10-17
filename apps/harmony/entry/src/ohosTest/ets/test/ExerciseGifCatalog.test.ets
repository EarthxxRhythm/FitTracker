/**
 * ExerciseGifCatalog unit test
 * 训练演示 GIF 解析：动作中文名 -> GIF 文件名 -> rawfile 路径，含默认回退。
 * 目录前缀从被测模块导入（DEMO_GIF_DIRECTORY / PHOTO_GIF_DIRECTORY），避免换素材目录时两处同步。
 * 素材分两套：自制线稿（已烘页底色）与 free-exercise-db 实拍照（无白底，须圆角容器）。
 * 线稿优先解析——已被线稿覆盖的名字不受实拍组影响。
 */
import { describe, it, expect } from '@ohos/hypium'
import ExerciseGifCatalog, {
  DEFAULT_EXERCISE_GIF_ID,
  DEMO_GIF_DIRECTORY,
  PHOTO_GIF_DIRECTORY,
  gifIdOfExerciseId
} from '../../../main/ets/shared/services/ExerciseGifCatalog'

export default function exerciseGifCatalogTest(): void {
  describe('ExerciseGifCatalog', () => {
    it('resolves a known exercise name to its gif rawfile path', 0, () => {
      expect(ExerciseGifCatalog.resolveGifId('杠铃卧推')).assertEqual('barbell-bench-press')
      expect(ExerciseGifCatalog.resolveDemoSource('杠铃卧推')).assertEqual(DEMO_GIF_DIRECTORY + 'barbell-bench-press.gif')

      expect(ExerciseGifCatalog.resolveGifId('深蹲')).assertEqual('squat')
      expect(ExerciseGifCatalog.resolveGifId('杠铃深蹲')).assertEqual('squat')
      expect(ExerciseGifCatalog.resolveGifId('俯卧撑')).assertEqual('push-up')
      expect(ExerciseGifCatalog.resolveGifId('引体向上')).assertEqual('pull-up')
      expect(ExerciseGifCatalog.resolveGifId('悬垂提膝')).assertEqual('hanging-leg-raise')
    })

    it('trims whitespace before matching', 0, () => {
      expect(ExerciseGifCatalog.resolveGifId('  深蹲  ')).assertEqual('squat')
    })

    it('falls back to the default demo gif when the name is unknown or empty', 0, () => {
      expect(ExerciseGifCatalog.resolveGifId('')).assertEqual(DEFAULT_EXERCISE_GIF_ID)
      expect(ExerciseGifCatalog.resolveGifId('   ')).assertEqual(DEFAULT_EXERCISE_GIF_ID)
      expect(ExerciseGifCatalog.resolveGifId('不存在的动作名')).assertEqual(DEFAULT_EXERCISE_GIF_ID)
      expect(ExerciseGifCatalog.resolveDemoSource('')).assertEqual(DEMO_GIF_DIRECTORY + DEFAULT_EXERCISE_GIF_ID + '.gif')
    })

    it('maps every gif id to its .gif rawfile path', 0, () => {
      const gifIds: string[] = [
        'barbell-bench-press', 'push-up', 'dumbbell-fly', 'cable-crossover', 'pull-up',
        'barbell-row', 'seated-row', 'lat-pulldown', 'band-pulldown', 'overhead-press',
        'lateral-raise', 'band-lateral-raise', 'face-pull', 'biceps-curl', 'triceps-pushdown',
        'squat', 'lunge', 'leg-press', 'leg-curl', 'band-squat', 'plank', 'crunch',
        'hanging-leg-raise'
      ]
      for (let index = 0; index < gifIds.length; index++) {
        const gifId: string = gifIds[index]
        expect(ExerciseGifCatalog.demoSourceOfGifId(gifId)).assertEqual(DEMO_GIF_DIRECTORY + gifId + '.gif')
      }
    })

    it('resolves photo-style sources into the photo directory', 0, () => {
      // 线稿未覆盖的动作 -> 实拍目录（罗马尼亚硬拉不在 23 组线稿映射里）。
      expect(ExerciseGifCatalog.resolveDemoSource('罗马尼亚硬拉'))
        .assertEqual(PHOTO_GIF_DIRECTORY + 'romanian-deadlift.gif')
      expect(ExerciseGifCatalog.resolveDemoSource('农夫走'))
        .assertEqual(PHOTO_GIF_DIRECTORY + 'farmers-carry.gif')
      expect(ExerciseGifCatalog.usesPhotoStyle('罗马尼亚硬拉')).assertTrue()
    })

    it('keeps line-art precedence when a name exists in both groups', 0, () => {
      // 「杠铃划船」「腿弯举」同时存在于线稿组与实拍组（源库指向同一动作）。
      // 线稿先解析，故老动作必须仍走线稿目录——既有视觉主线零回归。
      expect(ExerciseGifCatalog.resolveDemoSource('杠铃划船'))
        .assertEqual(DEMO_GIF_DIRECTORY + 'barbell-row.gif')
      expect(ExerciseGifCatalog.resolveDemoSource('腿弯举'))
        .assertEqual(DEMO_GIF_DIRECTORY + 'leg-curl.gif')
      expect(ExerciseGifCatalog.usesPhotoStyle('杠铃划船')).assertFalse()
    })

    it('maps content-library exercise ids to source paths', 0, () => {
      // 动作库页拿的是内容库 id（ex_barbell_bench_press），须归一化为 kebab 再分派目录。
      expect(gifIdOfExerciseId('ex_barbell_bench_press')).assertEqual('barbell-bench-press')
      expect(ExerciseGifCatalog.resolveDemoSourceByExerciseId('ex_barbell_bench_press'))
        .assertEqual(DEMO_GIF_DIRECTORY + 'barbell-bench-press.gif')
      expect(ExerciseGifCatalog.resolveDemoSourceByExerciseId('ex_romanian_deadlift'))
        .assertEqual(PHOTO_GIF_DIRECTORY + 'romanian-deadlift.gif')
      expect(ExerciseGifCatalog.usesPhotoStyleByExerciseId('ex_romanian_deadlift')).assertTrue()
      // 未知 id 回退默认演示动作，不抛错。
      expect(ExerciseGifCatalog.resolveDemoSourceByExerciseId('ex_not_a_real_exercise'))
        .assertEqual(DEMO_GIF_DIRECTORY + DEFAULT_EXERCISE_GIF_ID + '.gif')
      expect(ExerciseGifCatalog.resolveDemoSourceByExerciseId(''))
        .assertEqual(DEMO_GIF_DIRECTORY + DEFAULT_EXERCISE_GIF_ID + '.gif')
    })
  })
}
