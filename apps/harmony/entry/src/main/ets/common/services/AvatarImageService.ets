/**
 * AvatarImageService —— 头像图片的选取、压缩与本机沙箱读写。
 *
 * 存储模型（双端一致）：
 *  - 本机：`<filesDir>/avatars/avatar_<时间戳>.jpg`，`UserProfile.avatarImagePath` 存绝对路径；
 *  - 跨设备：图片 base64 随云同步信封的 `avatarImage` 字段传输（不进 hash 视图，见 CloudSyncService）。
 *
 * 选图走 `photoAccessHelper.PhotoViewPicker`（系统图库选择器，**无需相册权限**），因此
 * `module.json5` 不新增任何媒体权限。压缩规格：居中裁成正方形 → 256×256 → JPEG quality 80，
 * 典型体积 8～20KB，信封增量远小于快照体积上限。
 */
import { Context } from '@kit.AbilityKit'
import { fileIo } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { util } from '@kit.ArkTS'

const AVATAR_DIR_NAME: string = 'avatars'
const AVATAR_EDGE: number = 256
const AVATAR_JPEG_QUALITY: number = 80
/** 压缩后体积上限；超出视为异常图（不让单张头像把云快照撑大）。 */
const AVATAR_MAX_BYTES: number = 200 * 1024
const AVATAR_FILE_PREFIX: string = 'avatar_'
const AVATAR_FILE_SUFFIX: string = '.jpg'

/** 选图结果：`ok` 成功、`cancelled` 用户取消（静默返回，不提示）。 */
export interface AvatarPickResult {
  ok: boolean
  cancelled: boolean
  /** 成功时为沙箱内新文件绝对路径；失败/取消为空串。 */
  path: string
  /** 失败时的中文提示；成功/取消为空串。 */
  message: string
}

class AvatarImageService {
  /** 拉起系统图库选图并压缩落盘；返回新文件路径（旧文件清理由调用方决定）。 */
  async pickAndCompress(context: Context): Promise<AvatarPickResult> {
    let uri: string = ''
    try {
      const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker()
      const options: photoAccessHelper.PhotoSelectOptions = {
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      }
      const result: photoAccessHelper.PhotoSelectResult = await picker.select(options)
      if (result.photoUris.length === 0) {
        return this.cancelledResult()
      }
      uri = result.photoUris[0]
    } catch (error) {
      // 用户取消时选择器以异常返回；取消与失败对用户都是「没选成」，静默处理。
      return this.cancelledResult()
    }
    if (uri.length === 0) {
      return this.cancelledResult()
    }

    let file: fileIo.File | null = null
    let source: image.ImageSource | null = null
    let pixelMap: image.PixelMap | null = null
    let packer: image.ImagePacker | null = null
    try {
      file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY)
      source = image.createImageSource(file.fd)
      const info: image.ImageInfo = await source.getImageInfo()
      const width: number = info.size.width
      const height: number = info.size.height
      if (width <= 0 || height <= 0) {
        return this.failedResult('图片读取失败，请重试')
      }
      // 居中裁正方形 → 缩到 256×256（先裁后缩，减少解码峰值内存）。
      const edge: number = Math.min(width, height)
      const decodeOptions: image.DecodingOptions = {
        desiredRegion: {
          size: { width: edge, height: edge },
          x: Math.floor((width - edge) / 2),
          y: Math.floor((height - edge) / 2)
        },
        desiredSize: { width: AVATAR_EDGE, height: AVATAR_EDGE },
        cropAndScaleStrategy: image.CropAndScaleStrategy.CROP_FIRST
      }
      pixelMap = await source.createPixelMap(decodeOptions)
      packer = image.createImagePacker()
      const packOptions: image.PackingOption = { format: 'image/jpeg', quality: AVATAR_JPEG_QUALITY }
      const buffer: ArrayBuffer = await packer.packToData(pixelMap, packOptions)
      if (buffer.byteLength === 0) {
        return this.failedResult('图片读取失败，请重试')
      }
      if (buffer.byteLength > AVATAR_MAX_BYTES) {
        return this.failedResult('图片过大，请换一张')
      }
      const dirPath: string = this.resolveDirPath(context)
      this.ensureDirectorySync(dirPath)
      const filePath: string = this.resolveNewFilePath(dirPath)
      this.writeBufferSync(filePath, buffer)
      const success: AvatarPickResult = { ok: true, cancelled: false, path: filePath, message: '' }
      return success
    } catch (error) {
      return this.failedResult('图片读取失败，请重试')
    } finally {
      await this.releaseQuietly(pixelMap, source, packer)
      if (file !== null) {
        try {
          fileIo.closeSync(file.fd)
        } catch (error) {
          // 关闭失败不影响结果
        }
      }
    }
  }

  /** 读沙箱头像文件为 base64；文件缺失/读取失败返回空串（上行时按无图处理）。 */
  async readAsBase64(filePath: string): Promise<string> {
    if (filePath.length === 0 || !this.exists(filePath)) {
      return ''
    }
    let file: fileIo.File | null = null
    try {
      const stat: fileIo.Stat = fileIo.statSync(filePath)
      if (stat.size <= 0 || stat.size > AVATAR_MAX_BYTES) {
        return ''
      }
      file = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY)
      const buffer: ArrayBuffer = new ArrayBuffer(stat.size)
      const readBytes: number = fileIo.readSync(file.fd, buffer)
      if (readBytes <= 0) {
        return ''
      }
      const helper: util.Base64Helper = new util.Base64Helper()
      return helper.encodeToStringSync(new Uint8Array(buffer.slice(0, readBytes)))
    } catch (error) {
      return ''
    } finally {
      if (file !== null) {
        try {
          fileIo.closeSync(file.fd)
        } catch (error) {
          // 关闭失败不影响结果
        }
      }
    }
  }

  /** 把下行 base64 写成沙箱新文件；成功返回绝对路径，失败返回空串。 */
  async writeFromBase64(context: Context, base64: string): Promise<string> {
    if (base64.length === 0) {
      return ''
    }
    try {
      const helper: util.Base64Helper = new util.Base64Helper()
      const bytes: Uint8Array = helper.decodeSync(base64)
      if (bytes.byteLength === 0 || bytes.byteLength > AVATAR_MAX_BYTES) {
        return ''
      }
      const buffer: ArrayBuffer = new ArrayBuffer(bytes.byteLength)
      new Uint8Array(buffer).set(bytes)
      const dirPath: string = this.resolveDirPath(context)
      this.ensureDirectorySync(dirPath)
      const filePath: string = this.resolveNewFilePath(dirPath)
      this.writeBufferSync(filePath, buffer)
      return filePath
    } catch (error) {
      return ''
    }
  }

  /** 删除沙箱头像文件；不存在或删除失败静默忽略。 */
  async remove(filePath: string): Promise<void> {
    if (filePath.length === 0) {
      return
    }
    try {
      await fileIo.unlink(filePath)
    } catch (error) {
      // 已被清理或路径失效：无需提示
    }
  }

  /** 文件是否存在（渲染前判断，避免 Image 组件空路径报错）。 */
  exists(filePath: string): boolean {
    if (filePath.length === 0) {
      return false
    }
    try {
      return fileIo.accessSync(filePath)
    } catch (error) {
      return false
    }
  }

  private cancelledResult(): AvatarPickResult {
    const result: AvatarPickResult = { ok: false, cancelled: true, path: '', message: '' }
    return result
  }

  private failedResult(message: string): AvatarPickResult {
    const result: AvatarPickResult = { ok: false, cancelled: false, path: '', message: message }
    return result
  }

  private resolveDirPath(context: Context): string {
    return context.filesDir + '/' + AVATAR_DIR_NAME
  }

  private resolveNewFilePath(dirPath: string): string {
    return dirPath + '/' + AVATAR_FILE_PREFIX + Date.now().toString() + AVATAR_FILE_SUFFIX
  }

  private ensureDirectorySync(dirPath: string): void {
    if (this.exists(dirPath)) {
      return
    }
    fileIo.mkdirSync(dirPath, true)
  }

  private writeBufferSync(filePath: string, buffer: ArrayBuffer): void {
    const file: fileIo.File = fileIo.openSync(
      filePath,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
    )
    try {
      fileIo.writeSync(file.fd, buffer)
    } finally {
      try {
        fileIo.closeSync(file.fd)
      } catch (error) {
        // 关闭失败不影响写入结果
      }
    }
  }

  private async releaseQuietly(
    pixelMap: image.PixelMap | null,
    source: image.ImageSource | null,
    packer: image.ImagePacker | null
  ): Promise<void> {
    if (pixelMap !== null) {
      try {
        await pixelMap.release()
      } catch (error) {
        // 释放失败忽略
      }
    }
    if (source !== null) {
      try {
        await source.release()
      } catch (error) {
        // 释放失败忽略
      }
    }
    if (packer !== null) {
      try {
        await packer.release()
      } catch (error) {
        // 释放失败忽略
      }
    }
  }
}

export default new AvatarImageService()
