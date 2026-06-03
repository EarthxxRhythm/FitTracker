/**
 * ExerciseMediaResolverService -- resolve exercise media into previewable or clearly downgraded UI states.
 *
 * Function #17: exercise detail media metadata, source notice, license notice, and failure downgrade.
 */

export interface ExerciseMediaAssetInfo {
  kind: string
  originalUrl: string
  resolvedUrl: string
  scheme: string
  state: string
  stateText: string
  primaryText: string
  secondaryText: string
  sourceLabel: string
  licenseLabel: string
  hasReference: boolean
  canRenderInline: boolean
}

export interface ExerciseMediaPresentation {
  overallState: string
  badgeText: string
  tone: string
  statusText: string
  summaryText: string
  detailText: string
  sourceNote: string
  licenseNote: string
  cover: ExerciseMediaAssetInfo
  video: ExerciseMediaAssetInfo
}

export interface ExerciseMediaMetadata {
  coverSourceLabel: string
  videoSourceLabel: string
  mediaLicenseText: string
}

class ExerciseMediaResolverServiceImpl {
  resolve(
    coverUrl: string,
    videoUrl: string,
    videoPlaceholder: string,
    metadata: ExerciseMediaMetadata
  ): ExerciseMediaPresentation {
    const normalizedPlaceholder: string = videoPlaceholder.trim()
    const cover: ExerciseMediaAssetInfo = this.resolveAsset('cover', coverUrl, normalizedPlaceholder, metadata)
    const video: ExerciseMediaAssetInfo = this.resolveAsset('video', videoUrl, normalizedPlaceholder, metadata)

    const presentation: ExerciseMediaPresentation = {
      overallState: this.getOverallState(cover, video, normalizedPlaceholder),
      badgeText: '',
      tone: '',
      statusText: '',
      summaryText: '',
      detailText: '',
      sourceNote: this.buildSourceNote(cover, video),
      licenseNote: this.buildLicenseNote(cover, video),
      cover: cover,
      video: video
    }

    this.fillPresentationCopy(presentation, normalizedPlaceholder)
    return presentation
  }

  private resolveAsset(
    kind: string,
    url: string,
    videoPlaceholder: string,
    metadata: ExerciseMediaMetadata
  ): ExerciseMediaAssetInfo {
    const normalizedUrl: string = url.trim()
    const scheme: string = this.getScheme(normalizedUrl)
    const hasReference: boolean = normalizedUrl.length > 0
    const canRenderInline: boolean = this.canRenderInline(kind, normalizedUrl, scheme)
    const state: string = this.getAssetState(hasReference, canRenderInline)
    const explicitSourceLabel: string = this.getExplicitSourceLabel(kind, metadata)
    const explicitLicenseLabel: string = metadata.mediaLicenseText.trim()

    const asset: ExerciseMediaAssetInfo = {
      kind: kind,
      originalUrl: normalizedUrl,
      resolvedUrl: canRenderInline ? normalizedUrl : '',
      scheme: scheme,
      state: state,
      stateText: this.getAssetStateText(kind, state),
      primaryText: this.getAssetPrimaryText(kind, state),
      secondaryText: this.getAssetSecondaryText(kind, state, scheme, videoPlaceholder),
      sourceLabel: this.getSourceLabel(explicitSourceLabel, normalizedUrl, scheme),
      licenseLabel: this.getLicenseLabel(explicitLicenseLabel, normalizedUrl, scheme),
      hasReference: hasReference,
      canRenderInline: canRenderInline
    }
    return asset
  }

  private getExplicitSourceLabel(kind: string, metadata: ExerciseMediaMetadata): string {
    if (kind === 'cover') {
      return metadata.coverSourceLabel.trim()
    }
    return metadata.videoSourceLabel.trim()
  }

  private fillPresentationCopy(presentation: ExerciseMediaPresentation, videoPlaceholder: string): void {
    if (presentation.overallState === 'playable') {
      presentation.badgeText = '可播放'
      presentation.tone = 'primary'
      presentation.statusText = '已解析到可直接展示的媒体资源'
      presentation.summaryText = '当前版本会直接展示可解析资源，同时保留来源和授权说明。'
      presentation.detailText = '轻量闭环优先服务动作理解；后续再考虑缓存、批量分发和更多播放器能力。'
      return
    }

    if (presentation.overallState === 'declared') {
      presentation.badgeText = '已配置'
      presentation.tone = 'accent'
      presentation.statusText = '媒体引用已记录，当前按受控降级展示'
      presentation.summaryText = '页面会优先把封面、来源、授权和失败原因说清楚，不会对未映射资源强行尝试播放。'
      presentation.detailText = '当前 `local://` 更像内容库里的受控引用；等真实资源映射落地后，可以在这里平滑升级为预览或播放。'
      return
    }

    if (videoPlaceholder.length > 0) {
      presentation.badgeText = '占位'
      presentation.tone = 'accent'
      presentation.statusText = '媒体位已预留，等待后续补齐'
      presentation.summaryText = videoPlaceholder
      presentation.detailText = '当前版本保留媒体语义与说明位，避免后续接入真实资源时再重做页面结构。'
      return
    }

    presentation.badgeText = '待补齐'
    presentation.tone = 'muted'
    presentation.statusText = '暂未提供封面或视频'
    presentation.summaryText = '当前动作还没有可展示的媒体信息。'
    presentation.detailText = '后续补入受控的封面或视频引用后，这里会自动切换到更明确的预览状态。'
  }

  private getOverallState(
    cover: ExerciseMediaAssetInfo,
    video: ExerciseMediaAssetInfo,
    videoPlaceholder: string
  ): string {
    if (video.canRenderInline) {
      return 'playable'
    }
    if (cover.canRenderInline || cover.hasReference || video.hasReference) {
      return 'declared'
    }
    if (videoPlaceholder.length > 0) {
      return 'placeholder'
    }
    return 'missing'
  }

  private getAssetState(hasReference: boolean, canRenderInline: boolean): string {
    if (canRenderInline) {
      return 'ready'
    }
    if (hasReference) {
      return 'declared'
    }
    return 'missing'
  }

  private getAssetStateText(kind: string, state: string): string {
    if (kind === 'cover') {
      if (state === 'ready') {
        return '可预览'
      }
      if (state === 'declared') {
        return '已记录引用'
      }
      return '未提供'
    }

    if (state === 'ready') {
      return '可播放'
    }
    if (state === 'declared') {
      return '待映射播放'
    }
    return '未提供'
  }

  private getAssetPrimaryText(kind: string, state: string): string {
    if (kind === 'cover') {
      if (state === 'ready') {
        return '封面可直接预览'
      }
      if (state === 'declared') {
        return '封面引用已记录'
      }
      return '暂无封面素材'
    }

    if (state === 'ready') {
      return '视频可直接播放'
    }
    if (state === 'declared') {
      return '视频引用已记录'
    }
    return '暂无动作演示视频'
  }

  private getAssetSecondaryText(kind: string, state: string, scheme: string, videoPlaceholder: string): string {
    if (state === 'ready') {
      if (kind === 'cover') {
        return '当前资源地址可直接交给图片组件渲染。'
      }
      return '当前资源地址可直接交给播放器消费。'
    }

    if (state === 'declared') {
      if (scheme === 'local') {
        if (kind === 'cover') {
          return '当前版本只保留 `local://` 受控引用，尚未映射到应用内真实封面文件。'
        }
        return '当前版本不做整库离线视频，也不会对未映射的 `local://` 资源强行播放。'
      }
      return '当前引用已进入内容库，但还不在页面内直接展示的受支持范围。'
    }

    if (kind === 'video' && videoPlaceholder.length > 0) {
      return videoPlaceholder
    }
    return '后续补入受控资源后即可在这里展示更完整的媒体体验。'
  }

  private getSourceLabel(explicitLabel: string, url: string, scheme: string): string {
    if (explicitLabel.length > 0) {
      return explicitLabel
    }
    if (url.length === 0) {
      return '未提供'
    }
    if (scheme === 'local') {
      return '本地动作库引用'
    }
    if (scheme === 'http' || scheme === 'https') {
      return '远程受控资源'
    }
    if (scheme === 'file') {
      return '应用内文件资源'
    }
    return '自定义资源引用'
  }

  private getLicenseLabel(explicitLabel: string, url: string, scheme: string): string {
    if (explicitLabel.length > 0) {
      return explicitLabel
    }
    if (url.length === 0) {
      return '暂无授权信息'
    }
    if (scheme === 'local') {
      return '仅允许自制或已授权素材落地'
    }
    if (scheme === 'http' || scheme === 'https') {
      return '需保持远程资源授权可追溯'
    }
    if (scheme === 'file') {
      return '应用内已打包或用户侧文件'
    }
    return '需在接入前补齐授权说明'
  }

  private buildSourceNote(cover: ExerciseMediaAssetInfo, video: ExerciseMediaAssetInfo): string {
    if (cover.hasReference && video.hasReference) {
      if (cover.sourceLabel === video.sourceLabel) {
        return cover.sourceLabel
      }
      return '封面：' + cover.sourceLabel + '；视频：' + video.sourceLabel
    }
    if (video.hasReference) {
      return '视频：' + video.sourceLabel
    }
    if (cover.hasReference) {
      return '封面：' + cover.sourceLabel
    }
    return '当前动作未附带媒体来源'
  }

  private buildLicenseNote(cover: ExerciseMediaAssetInfo, video: ExerciseMediaAssetInfo): string {
    if (cover.hasReference && video.hasReference) {
      if (cover.licenseLabel === video.licenseLabel) {
        return cover.licenseLabel
      }
      return '封面：' + cover.licenseLabel + '；视频：' + video.licenseLabel
    }
    if (video.hasReference) {
      return '视频：' + video.licenseLabel
    }
    if (cover.hasReference) {
      return '封面：' + cover.licenseLabel
    }
    return '补入资源时需同步登记授权口径'
  }

  private canRenderInline(kind: string, url: string, scheme: string): boolean {
    if (url.length === 0) {
      return false
    }
    if (scheme === 'http' || scheme === 'https' || scheme === 'file') {
      return true
    }
    if (kind === 'cover' && this.isAbsoluteFilePath(url)) {
      return true
    }
    return false
  }

  private isAbsoluteFilePath(url: string): boolean {
    if (url.length < 3) {
      return false
    }
    const driveLetter: string = url.substring(0, 1)
    const separatorText: string = url.substring(1, 3)
    return this.isAsciiLetter(driveLetter) && separatorText === ':\\'
  }

  private isAsciiLetter(value: string): boolean {
    if (value.length !== 1) {
      return false
    }
    const code: number = value.charCodeAt(0)
    if (code >= 65 && code <= 90) {
      return true
    }
    return code >= 97 && code <= 122
  }

  private getScheme(url: string): string {
    const schemeSeparatorIndex: number = url.indexOf('://')
    if (schemeSeparatorIndex <= 0) {
      return ''
    }
    return url.substring(0, schemeSeparatorIndex).toLowerCase()
  }
}

export default new ExerciseMediaResolverServiceImpl()
