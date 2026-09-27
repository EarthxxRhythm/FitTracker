/**
 * ExerciseGifCatalog unit test
 * 训练演示 GIF 解析：动作中文名 -> GIF 文件名 -> rawfile 路径，含默认回退。
 * 目录前缀从被测模块导入（DEMO_GIF_DIRECTORY），避免换素材目录时两处同步。
 */
import { describe, it, expect } from '@ohos/hypium'
import ExerciseGifCatalog, {
  DEFAULT_EXERCISE_GIF_ID,
  DEMO_GIF_DIRECTORY
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
  })
}
