/**
 * ExerciseMediaResolverService unit test
 * Function #17: media resolution, downgrade states, placeholder fallback, and note aggregation.
 */
import { describe, it, expect } from '@ohos/hypium'
import ExerciseMediaResolverService, {
  ExerciseMediaMetadata,
  ExerciseMediaPresentation
} from '../../../main/ets/shared/services/ExerciseMediaResolverService'

function createMetadata(
  coverSourceLabel: string,
  videoSourceLabel: string,
  mediaLicenseText: string
): ExerciseMediaMetadata {
  const metadata: ExerciseMediaMetadata = {
    coverSourceLabel: coverSourceLabel,
    videoSourceLabel: videoSourceLabel,
    mediaLicenseText: mediaLicenseText
  }
  return metadata
}

export default function exerciseMediaResolverServiceTest(): void {
  describe('ExerciseMediaResolverService', () => {
    it('resolves directly renderable cover and video assets', 0, () => {
      const presentation: ExerciseMediaPresentation = ExerciseMediaResolverService.resolve(
        'https://cdn.example.com/media/bench-cover.png',
        'file://entry/resources/rawfile/bench-demo.mp4',
        'placeholder should be ignored once video is playable',
        createMetadata('Remote cover CDN', 'Bundled rawfile video', 'CC BY 4.0')
      )

      expect(presentation.overallState).assertEqual('playable')
      expect(presentation.tone).assertEqual('primary')

      expect(presentation.cover.state).assertEqual('ready')
      expect(presentation.cover.scheme).assertEqual('https')
      expect(presentation.cover.canRenderInline).assertTrue()
      expect(presentation.cover.resolvedUrl).assertEqual('https://cdn.example.com/media/bench-cover.png')
      expect(presentation.cover.sourceLabel).assertEqual('Remote cover CDN')

      expect(presentation.video.state).assertEqual('ready')
      expect(presentation.video.scheme).assertEqual('file')
      expect(presentation.video.canRenderInline).assertTrue()
      expect(presentation.video.resolvedUrl).assertEqual('file://entry/resources/rawfile/bench-demo.mp4')
      expect(presentation.video.sourceLabel).assertEqual('Bundled rawfile video')
    })

    it('keeps local declarations in downgrade state when they cannot render inline', 0, () => {
      const presentation: ExerciseMediaPresentation = ExerciseMediaResolverService.resolve(
        'local://exercise-library/squat-cover',
        'local://exercise-library/squat-video',
        '',
        createMetadata('', '', '')
      )

      expect(presentation.overallState).assertEqual('declared')
      expect(presentation.tone).assertEqual('accent')

      expect(presentation.cover.state).assertEqual('declared')
      expect(presentation.cover.scheme).assertEqual('local')
      expect(presentation.cover.hasReference).assertTrue()
      expect(presentation.cover.canRenderInline).assertFalse()
      expect(presentation.cover.resolvedUrl).assertEqual('')

      expect(presentation.video.state).assertEqual('declared')
      expect(presentation.video.scheme).assertEqual('local')
      expect(presentation.video.hasReference).assertTrue()
      expect(presentation.video.canRenderInline).assertFalse()
      expect(presentation.video.resolvedUrl).assertEqual('')

      expect(presentation.sourceNote).assertEqual(presentation.cover.sourceLabel)
      expect(presentation.licenseNote).assertEqual(presentation.cover.licenseLabel)
    })

    it('falls back to placeholder state when there are no media resources', 0, () => {
      const presentation: ExerciseMediaPresentation = ExerciseMediaResolverService.resolve(
        '',
        '',
        '  local placeholder pending asset wiring  ',
        createMetadata('', '', '')
      )

      expect(presentation.overallState).assertEqual('placeholder')
      expect(presentation.tone).assertEqual('accent')
      expect(presentation.summaryText).assertEqual('local placeholder pending asset wiring')

      expect(presentation.cover.state).assertEqual('missing')
      expect(presentation.cover.hasReference).assertFalse()
      expect(presentation.video.state).assertEqual('missing')
      expect(presentation.video.hasReference).assertFalse()
      expect(presentation.video.secondaryText).assertEqual('local placeholder pending asset wiring')
    })

    it('collapses identical source and license notes when both assets share them', 0, () => {
      const presentation: ExerciseMediaPresentation = ExerciseMediaResolverService.resolve(
        'https://cdn.example.com/media/push-up-cover.png',
        'https://cdn.example.com/media/push-up-video.mp4',
        '',
        createMetadata('Self-shot demo set', 'Self-shot demo set', 'Internal approved')
      )

      expect(presentation.sourceNote).assertEqual('Self-shot demo set')
      expect(presentation.licenseNote).assertEqual('Internal approved')
    })

    it('aggregates distinct source and license notes for cover and video separately', 0, () => {
      const presentation: ExerciseMediaPresentation = ExerciseMediaResolverService.resolve(
        'local://exercise-library/press-cover',
        'https://cdn.example.com/media/press-video.mp4',
        '',
        createMetadata('', '', '')
      )

      expect(presentation.sourceNote === presentation.cover.sourceLabel).assertFalse()
      expect(presentation.sourceNote === presentation.video.sourceLabel).assertFalse()
      expect(presentation.sourceNote.indexOf(presentation.cover.sourceLabel) >= 0).assertTrue()
      expect(presentation.sourceNote.indexOf(presentation.video.sourceLabel) >= 0).assertTrue()

      expect(presentation.licenseNote === presentation.cover.licenseLabel).assertFalse()
      expect(presentation.licenseNote === presentation.video.licenseLabel).assertFalse()
      expect(presentation.licenseNote.indexOf(presentation.cover.licenseLabel) >= 0).assertTrue()
      expect(presentation.licenseNote.indexOf(presentation.video.licenseLabel) >= 0).assertTrue()
    })
  })
}
