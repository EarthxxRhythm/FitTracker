/**
 * ExerciseGifCatalog unit test
 * 训练演示 GIF 解析：动作中文名 -> GIF 文件名 -> rawfile 路径，含默认回退。
 * 目录前缀从被测模块导入（DEMO_GIF_DIRECTORY / PHOTO_GIF_DIRECTORY），避免换素材目录时两处同步。
 * 素材已收敛为 free-exercise-db 实拍单一来源：旧线稿套系因授权问题移除，其映射组也停用，
 * 故解析只查实拍组，与 Android 端 PhotoGifCatalog 同规则。
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
      expect(ExerciseGifCatalog.resolveDemoSource('杠铃卧推'))
        .assertEqual(DEMO_GIF_DIRECTORY + 'barbell-bench-press.gif')

      expect(ExerciseGifCatalog.resolveGifId('深蹲')).assertEqual('barbell-squat')
      expect(ExerciseGifCatalog.resolveGifId('杠铃深蹲')).assertEqual('barbell-squat')
      expect(ExerciseGifCatalog.resolveGifId('俯卧撑')).assertEqual('push-up')
      expect(ExerciseGifCatalog.resolveGifId('引体向上')).assertEqual('pull-up')
      expect(ExerciseGifCatalog.resolveGifId('悬垂提膝')).assertEqual('hanging-knee-raise')
    })

    it('trims whitespace before matching', 0, () => {
      expect(ExerciseGifCatalog.resolveGifId('  深蹲  ')).assertEqual('barbell-squat')
    })

    it('falls back to the default demo gif when the name is unknown or empty', 0, () => {
      expect(ExerciseGifCatalog.resolveGifId('')).assertEqual(DEFAULT_EXERCISE_GIF_ID)
      expect(ExerciseGifCatalog.resolveGifId('   ')).assertEqual(DEFAULT_EXERCISE_GIF_ID)
      expect(ExerciseGifCatalog.resolveGifId('不存在的动作名')).assertEqual(DEFAULT_EXERCISE_GIF_ID)
      expect(ExerciseGifCatalog.resolveDemoSource(''))
        .assertEqual(DEMO_GIF_DIRECTORY + DEFAULT_EXERCISE_GIF_ID + '.gif')
    })

    it('maps every gif id to its .gif rawfile path', 0, () => {
      // 覆盖三种来源：原实拍组（dead-bug）、原线稿组补生成（barbell-bench-press）、
      // 本轮补齐（dumbbell-bench-press）。
      const gifIds: string[] = [
        'dead-bug', 'romanian-deadlift', 'farmers-carry',
        'barbell-bench-press', 'push-up', 'pull-up', 'plank',
        'dumbbell-bench-press', 'machine-chest-press', 'hammer-curl-cable'
      ]
      for (let index = 0; index < gifIds.length; index++) {
        const gifId: string = gifIds[index]
        expect(ExerciseGifCatalog.demoSourceOfGifId(gifId))
          .assertEqual(PHOTO_GIF_DIRECTORY + gifId + '.gif')
      }
    })

    it('resolves all names into the single photo directory', 0, () => {
      expect(ExerciseGifCatalog.resolveDemoSource('罗马尼亚硬拉'))
        .assertEqual(PHOTO_GIF_DIRECTORY + 'romanian-deadlift.gif')
      expect(ExerciseGifCatalog.resolveDemoSource('农夫走'))
        .assertEqual(PHOTO_GIF_DIRECTORY + 'farmers-carry.gif')
      expect(ExerciseGifCatalog.resolveDemoSource('杠铃卧推'))
        .assertEqual(PHOTO_GIF_DIRECTORY + 'barbell-bench-press.gif')
      // 素材已收敛为实拍单一来源，任何名字都应交给圆角容器。
      expect(ExerciseGifCatalog.usesPhotoStyle('罗马尼亚硬拉')).assertTrue()
      expect(ExerciseGifCatalog.usesPhotoStyle('杠铃卧推')).assertTrue()
      expect(ExerciseGifCatalog.usesPhotoStyle('不存在的动作名')).assertTrue()
    })

    it('resolves names once owned by the retired line-art group to exact photo assets', 0, () => {
      // 「杠铃划船」「腿弯举」此前被线稿组截走（barbell-row / leg-curl，文件已撤下 -> 占位）。
      // 线稿组停用后必须落到语义精确的实拍素材，而不是回退默认图。
      expect(ExerciseGifCatalog.resolveDemoSource('杠铃划船'))
        .assertEqual(PHOTO_GIF_DIRECTORY + 'bent-over-barbell-row.gif')
      expect(ExerciseGifCatalog.resolveDemoSource('腿弯举'))
        .assertEqual(PHOTO_GIF_DIRECTORY + 'lying-leg-curls.gif')
      expect(ExerciseGifCatalog.resolveDemoSource('哑铃卧推'))
        .assertEqual(PHOTO_GIF_DIRECTORY + 'dumbbell-bench-press.gif')
    })

    it('maps content-library exercise ids to source paths', 0, () => {
      // 动作库页拿的是内容库 id（ex_barbell_bench_press），须归一化为 kebab 再查实拍组。
      expect(gifIdOfExerciseId('ex_barbell_bench_press')).assertEqual('barbell-bench-press')
      expect(ExerciseGifCatalog.resolveDemoSourceByExerciseId('ex_barbell_bench_press'))
        .assertEqual(PHOTO_GIF_DIRECTORY + 'barbell-bench-press.gif')
      expect(ExerciseGifCatalog.resolveDemoSourceByExerciseId('ex_dumbbell_bench_press'))
        .assertEqual(PHOTO_GIF_DIRECTORY + 'dumbbell-bench-press.gif')
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
