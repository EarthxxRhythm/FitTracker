package com.fittracker.app.ui.screens.profile

import android.app.Application
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.service.Gender
import com.fittracker.app.data.service.UserProfile
import com.fittracker.app.data.service.UserProfileService
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * 资料编辑页的行为契约测试。
 *
 * 覆盖三类不可回归点：
 * 1. 输入归一（昵称上限 20、身高/出生年只吃数字并限长）；
 * 2. 头像色键 → 配色映射（空键回落翡翠，与个人页 `avatarTintOf` 同一实现）；
 * 3. 保存链路真实落盘（`saveProfile` → `loadProfile` 逐字段读回）。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "zh-rCN")
class ProfileEditLogicTest {

    private fun newViewModel(): ProfileEditViewModel =
        ProfileEditViewModel(ApplicationProvider.getApplicationContext<Application>())

    @Test
    fun `昵称超过 20 字被拒绝_边界值原样保留`() {
        val vm = newViewModel()
        vm.onNicknameChange("一二三四五六七八九十一二三四五六七八九十")
        assertEquals("20 字应原样保留", "一二三四五六七八九十一二三四五六七八九十", vm.nickname)

        vm.onNicknameChange("一二三四五六七八九十一二三四五六七八九十一")
        assertEquals("21 字应被忽略（保持上一次值）", "一二三四五六七八九十一二三四五六七八九十", vm.nickname)
    }

    @Test
    fun `身高与出生年只接受数字并限长`() {
        val vm = newViewModel()
        vm.onHeightChange("17a8cm")
        assertEquals("178", vm.heightText)
        vm.onHeightChange("1789")
        assertEquals("178", vm.heightText)

        vm.onBirthYearChange("19x9y5")
        assertEquals("1995", vm.birthYearText)
        vm.onBirthYearChange("19955")
        assertEquals("1995", vm.birthYearText)
    }

    @Test
    fun `头像色键为空或未知时回落翡翠`() {
        val fallback = avatarTintOf("")
        val unknown = avatarTintOf("not-a-key")
        assertEquals("空键与未知键应得到同一配色", fallback, unknown)

        val gold = avatarTintOf("gold")
        assertTrue("已定义的色键必须与默认不同", gold != fallback)
    }

    @Test
    fun `保存后 loadProfile 逐字段读回`() = runBlocking {
        val context: Context = ApplicationProvider.getApplicationContext()
        val store = JsonStore(context.appDataStore)
        UserProfileService.clearProfile(store)

        UserProfileService.saveProfile(
            store,
            UserProfile(
                nickname = "阿力",
                avatar = "gold",
                heightCm = 178,
                gender = Gender.MALE,
                birthYear = 1995,
            ),
        )

        val loaded = UserProfileService.loadProfile(store)
        assertEquals("阿力", loaded.nickname)
        assertEquals("gold", loaded.avatar)
        assertEquals(178, loaded.heightCm)
        assertEquals(Gender.MALE, loaded.gender)
        assertEquals(1995, loaded.birthYear)
        assertEquals("保存不应留下错误码", "", UserProfileService.getLastPersistenceError())
    }
}
