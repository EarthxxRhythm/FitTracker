package com.fittracker.app.ui.screens.profile

import android.app.Application
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.service.Experience
import com.fittracker.app.data.service.Gender
import com.fittracker.app.data.service.ProfileExtras
import com.fittracker.app.data.service.ProfileExtrasService
import com.fittracker.app.data.service.UserProfile
import com.fittracker.app.data.service.UserProfileService
import com.fittracker.app.data.service.WeightUnit
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
    fun `昵称超过 20 字被截断_边界值原样保留`() {
        val vm = newViewModel()
        vm.onNicknameChange("一二三四五六七八九十一二三四五六七八九十")
        assertEquals("20 字应原样保留", "一二三四五六七八九十一二三四五六七八九十", vm.nickname)

        vm.onNicknameChange("一二三四五六七八九十一二三四五六七八九十一")
        assertEquals("21 字应截断到 20（对齐鸿蒙面板 maxLength 口径）", 20, vm.nickname.length)
    }

    @Test
    fun `改动后才标记 dirty_未改动时保存等价于返回`() {
        val vm = newViewModel()
        assertTrue("初始应为未改动", !vm.dirty)
        vm.onNicknameChange("阿力")
        assertTrue("改过昵称后应标记 dirty", vm.dirty)
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
    fun `训练经验未知值归一为未填`() {
        assertEquals(Experience.UNSPECIFIED, UserProfileService.normalizeExperience("veteran"))
        assertEquals(Experience.UNSPECIFIED, UserProfileService.normalizeExperience(""))
        assertEquals(Experience.BEGINNER, UserProfileService.normalizeExperience("beginner"))
        assertEquals(Experience.INTERMEDIATE, UserProfileService.normalizeExperience("intermediate"))
        assertEquals(Experience.ADVANCED, UserProfileService.normalizeExperience("advanced"))
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
                experience = Experience.ADVANCED,
            ),
        )

        val loaded = UserProfileService.loadProfile(store)
        assertEquals("阿力", loaded.nickname)
        assertEquals("gold", loaded.avatar)
        assertEquals(178, loaded.heightCm)
        assertEquals(Gender.MALE, loaded.gender)
        assertEquals(1995, loaded.birthYear)
        assertEquals(Experience.ADVANCED, loaded.experience)
        assertEquals("保存不应留下错误码", "", UserProfileService.getLastPersistenceError())
    }

    @Test
    fun `名片字段保存后逐字段读回_清空回落空值`() = runBlocking {
        val context: Context = ApplicationProvider.getApplicationContext()
        val store = JsonStore(context.appDataStore)
        ProfileExtrasService.clearExtras(store)

        ProfileExtrasService.saveExtras(
            store,
            ProfileExtras(
                region = "上海",
                tickle = "拍了拍你的训练计划",
                whatsUp = "今天也要练完最后一组",
                gymAddress = "楼下那家",
            ),
        )
        assertEquals("保存不应留下错误码", "", ProfileExtrasService.getLastPersistenceError())

        val loaded = ProfileExtrasService.loadExtras(store)
        assertEquals("上海", loaded.region)
        assertEquals("拍了拍你的训练计划", loaded.tickle)
        assertEquals("今天也要练完最后一组", loaded.whatsUp)
        assertEquals("楼下那家", loaded.gymAddress)

        ProfileExtrasService.clearExtras(store)
        assertEquals("清空后应回落空值", ProfileExtras(), ProfileExtrasService.loadExtras(store))
    }

    @Test
    fun `名片字段限长与体重单位切换`() {
        val vm = newViewModel()
        vm.onRegionChange("一".repeat(30))
        assertEquals("地区限 24 字", 24, vm.region.length)
        vm.onTickleChange("二".repeat(25))
        assertEquals("拍一拍限 20 字", 20, vm.tickle.length)
        vm.onWhatsUpChange("三".repeat(45))
        assertEquals("个性签名限 40 字", 40, vm.whatsUp.length)
        vm.onGymAddressChange("四".repeat(45))
        assertEquals("常用健身房限 40 字", 40, vm.gymAddress.length)

        assertEquals(WeightUnit.KG, vm.weightUnit)
        vm.onWeightUnitChange(WeightUnit.LBS)
        assertEquals(WeightUnit.LBS, vm.weightUnit)
    }

    @Test
    fun `档案号与手机号脱敏_与鸿蒙同口径`() {
        assertEquals("131******05", maskPhone("13112345605"))
        assertEquals("短号码原样返回", "1380", maskPhone("1380"))
        assertEquals("空账号不派生档案号", "", profileAccountIdOf(""))

        val first = profileAccountIdOf("13800000000")
        assertEquals("同一账号派生稳定", first, profileAccountIdOf("13800000000"))
        assertTrue("前缀应为 FT", first.startsWith("FT"))
        assertEquals("尾号应有 8 位", 8, first.removePrefix("FT").length)
    }
}
