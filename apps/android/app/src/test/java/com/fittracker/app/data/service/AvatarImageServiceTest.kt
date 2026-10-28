package com.fittracker.app.data.service

import java.io.File
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * [AvatarImageService] 契约测试——base64 往返、超限拒绝、坏数据容错。
 *
 * 不走相册选图（`importFromUri` 依赖系统解码器与 ContentResolver，JVM 单测覆盖不到真实图片），
 * 上下行共用的「base64 ↔ 沙箱文件」链路在此逐条验收；压缩规格由实现常量约束（256×256 / q80）。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class AvatarImageServiceTest {

    @get:Rule
    val tempFolder: TemporaryFolder = TemporaryFolder()

    @Test
    fun `base64 写入后可读回同一份内容`() = runBlocking {
        val dir = File(tempFolder.root, "avatars")
        val bytes = ByteArray(1024) { index -> (index % 251).toByte() }
        val base64 = java.util.Base64.getEncoder().encodeToString(bytes)

        val path = AvatarImageService.writeFromBase64(dir, base64)

        assertTrue("应返回沙箱路径", path.isNotEmpty())
        assertTrue(AvatarImageService.exists(path))
        assertEquals(base64, AvatarImageService.readAsBase64(path))
    }

    @Test
    fun `空串与坏数据不产出文件`() = runBlocking {
        val dir = File(tempFolder.root, "avatars")
        assertEquals("", AvatarImageService.writeFromBase64(dir, ""))
        assertEquals("", AvatarImageService.writeFromBase64(dir, "not-base64!!"))
        assertFalse(dir.exists())
    }

    @Test
    fun `超过体积上限的图片被拒绝`() = runBlocking {
        val dir = File(tempFolder.root, "avatars")
        val oversized = ByteArray(201 * 1024) { 1 }
        val base64 = java.util.Base64.getEncoder().encodeToString(oversized)
        assertEquals("", AvatarImageService.writeFromBase64(dir, base64))
        assertFalse(dir.exists())
    }

    @Test
    fun `缺失或失效路径读取为空串_删除静默成功`() = runBlocking {
        assertEquals("", AvatarImageService.readAsBase64(""))
        assertEquals("", AvatarImageService.readAsBase64(File(tempFolder.root, "missing.jpg").absolutePath))
        assertFalse(AvatarImageService.exists(""))

        val dir = File(tempFolder.root, "avatars")
        val bytes = ByteArray(64) { 7 }
        val base64 = java.util.Base64.getEncoder().encodeToString(bytes)
        val path = AvatarImageService.writeFromBase64(dir, base64)
        AvatarImageService.remove(path)
        assertFalse(AvatarImageService.exists(path))
        // 再次删除不再抛错
        AvatarImageService.remove(path)
    }

    @Test
    fun `头像目录固定在 filesDir 下`() {
        val context = org.robolectric.RuntimeEnvironment.getApplication()
        val dir = AvatarImageService.resolveDir(context)
        assertEquals(File(context.filesDir, AvatarImageService.DIR_NAME), dir)
    }
}
