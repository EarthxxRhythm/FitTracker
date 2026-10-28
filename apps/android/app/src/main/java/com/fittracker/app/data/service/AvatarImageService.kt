package com.fittracker.app.data.service

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import android.util.Base64
import java.io.ByteArrayOutputStream
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * 头像图片的选取、压缩与本机沙箱读写——对齐鸿蒙 `common/services/AvatarImageService.ets`。
 *
 * 存储模型（双端一致）：
 * - 本机：`<filesDir>/avatars/avatar_<时间戳>.jpg`，`UserProfile.avatarImagePath` 存绝对路径；
 * - 跨设备：图片 base64 随云同步信封的 `avatarImage` 字段传输（`avatarImageHash` 才进变更检测视图）。
 *
 * 选图由屏侧 `ActivityResultContracts.PickVisualMedia` 承担（系统照片选择器，**无需存储权限**；
 * minSdk 24 时 AndroidX 自动回落 `ACTION_OPEN_DOCUMENT`），本服务只负责 Uri → 文件。
 * 压缩规格：居中裁正方形 → 256×256 → JPEG quality 80；同时按 EXIF 方向摆正，避免竖拍照片躺倒。
 */
object AvatarImageService {

    /** `filesDir` 下的头像目录名。 */
    const val DIR_NAME: String = "avatars"

    /** 输出边长（px）。 */
    private const val EDGE: Int = 256

    /** JPEG 质量（与鸿蒙同值）。 */
    private const val JPEG_QUALITY: Int = 80

    /** 压缩后体积上限；超出视为异常图（不让单张头像把云快照撑大）。 */
    private const val MAX_BYTES: Int = 200 * 1024

    private const val FILE_PREFIX: String = "avatar_"
    private const val FILE_SUFFIX: String = ".jpg"

    /** 头像目录；不存在时创建。 */
    fun resolveDir(context: Context): File = File(context.filesDir, DIR_NAME)

    /** 文件是否存在（渲染前判断，避免 Coil 对空路径报错）。 */
    fun exists(path: String): Boolean = path.isNotEmpty() && File(path).isFile

    /**
     * 把相册 Uri 读成压缩头像并落盘；成功返回新文件绝对路径，失败（解码异常 / 超限 / 写盘失败）
     * 返回 `null`。调用方负责删除不再使用的旧文件。
     */
    suspend fun importFromUri(context: Context, uri: Uri): String? = withContext(Dispatchers.IO) {
        try {
            val bitmap = decodeOrientedSquare(context, uri) ?: return@withContext null
            val compressed = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, compressed)
            if (!bitmap.isRecycled) {
                bitmap.recycle()
            }
            val bytes = compressed.toByteArray()
            if (bytes.isEmpty() || bytes.size > MAX_BYTES) {
                return@withContext null
            }
            val dir = resolveDir(context)
            if (!dir.exists() && !dir.mkdirs()) {
                return@withContext null
            }
            val target = File(dir, FILE_PREFIX + System.currentTimeMillis() + FILE_SUFFIX)
            target.writeBytes(bytes)
            target.absolutePath
        } catch (error: Exception) {
            null
        }
    }

    /** 读沙箱头像为 base64；文件缺失 / 读取失败 / 超限返回空串（上行时按无图处理）。 */
    suspend fun readAsBase64(path: String): String = withContext(Dispatchers.IO) {
        try {
            if (!exists(path)) {
                return@withContext ""
            }
            val bytes = File(path).readBytes()
            if (bytes.isEmpty() || bytes.size > MAX_BYTES) {
                return@withContext ""
            }
            Base64.encodeToString(bytes, Base64.NO_WRAP)
        } catch (error: Exception) {
            ""
        }
    }

    /** 把下行 base64 写成沙箱新文件；成功返回绝对路径，失败返回空串。 */
    suspend fun writeFromBase64(dir: File, base64: String): String = withContext(Dispatchers.IO) {
        try {
            if (base64.isEmpty()) {
                return@withContext ""
            }
            val bytes = Base64.decode(base64, Base64.NO_WRAP)
            if (bytes.isEmpty() || bytes.size > MAX_BYTES) {
                return@withContext ""
            }
            if (!dir.exists() && !dir.mkdirs()) {
                return@withContext ""
            }
            val target = File(dir, FILE_PREFIX + System.currentTimeMillis() + FILE_SUFFIX)
            target.writeBytes(bytes)
            target.absolutePath
        } catch (error: Exception) {
            ""
        }
    }

    /** 删除沙箱头像文件；不存在或删除失败静默忽略。 */
    suspend fun remove(path: String) = withContext(Dispatchers.IO) {
        if (path.isNotEmpty()) {
            try {
                File(path).delete()
            } catch (error: Exception) {
                // 已被清理或路径失效：无需提示
            }
        }
        Unit
    }

    /** 计算 2 的幂下采样倍数，避免把整张大图读进内存。 */
    private fun calculateInSampleSize(side: Int, target: Int): Int {
        var sample = 1
        var current = side
        while (current / 2 >= target) {
            current /= 2
            sample *= 2
        }
        return sample
    }

    /** 解码 → 按 EXIF 摆正 → 居中裁正方形 → 缩到 EDGE×EDGE。失败返回 `null`。 */
    private fun decodeOrientedSquare(context: Context, uri: Uri): Bitmap? {
        val resolver = context.contentResolver
        val bounds = BitmapFactory.Options()
        bounds.inJustDecodeBounds = true
        resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        val rawWidth = bounds.outWidth
        val rawHeight = bounds.outHeight
        if (rawWidth <= 0 || rawHeight <= 0) {
            return null
        }
        val options = BitmapFactory.Options()
        options.inSampleSize = calculateInSampleSize(minOf(rawWidth, rawHeight), EDGE)
        val decoded = resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, options) }
            ?: return null
        val oriented = applyExifRotation(context, uri, decoded)
        val edge = minOf(oriented.width, oriented.height)
        if (edge <= 0) {
            oriented.recycle()
            return null
        }
        val left = (oriented.width - edge) / 2
        val top = (oriented.height - edge) / 2
        val cropped = Bitmap.createBitmap(oriented, left, top, edge, edge)
        if (cropped !== oriented) {
            oriented.recycle()
        }
        val scaled = Bitmap.createScaledBitmap(cropped, EDGE, EDGE, true)
        if (scaled !== cropped && !cropped.isRecycled) {
            cropped.recycle()
        }
        return scaled
    }

    /** EXIF 方向摆正；读取失败或无方向信息时原样返回。 */
    private fun applyExifRotation(context: Context, uri: Uri, bitmap: Bitmap): Bitmap {
        val orientation = try {
            context.contentResolver.openInputStream(uri)?.use { stream ->
                ExifInterface(stream).getAttributeInt(
                    ExifInterface.TAG_ORIENTATION,
                    ExifInterface.ORIENTATION_NORMAL,
                )
            } ?: ExifInterface.ORIENTATION_NORMAL
        } catch (error: Exception) {
            ExifInterface.ORIENTATION_NORMAL
        }
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                matrix.postRotate(90f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                matrix.postRotate(270f)
                matrix.postScale(-1f, 1f)
            }
            else -> return bitmap
        }
        return try {
            Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        } catch (error: Exception) {
            bitmap
        }
    }
}
