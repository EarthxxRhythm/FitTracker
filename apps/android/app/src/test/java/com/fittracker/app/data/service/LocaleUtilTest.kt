package com.fittracker.app.data.service

import androidx.appcompat.app.AppCompatDelegate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.util.Locale

/**
 * 设置页语言选中态的真源契约（`LocaleUtil`）。
 *
 * 缺陷背景：设置页此前用 `SettingsService.loadSettings().language` 回显选中项——那是「用户显式
 * 选择过的语言」，从未选择时恒为默认中文；而界面语言跟随系统。系统英文环境下因此出现
 * 「界面英文、设置项勾着简体中文」。修复后选中态一律取 [currentSettingsLanguage]。
 *
 * `@Config(sdk = [34])`：与既有 `ContentRepositoryTest` 一致——targetSdk 37 超出
 * Robolectric 4.16 支持范围。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class LocaleUtilTest {

    @Test
    fun `language tags map to supported settings languages`() {
        // 英文前缀（含区域码、大小写差异）
        assertEquals(SettingsLanguage.EN, settingsLanguageFor("en"))
        assertEquals(SettingsLanguage.EN, settingsLanguageFor("en-US"))
        assertEquals(SettingsLanguage.EN, settingsLanguageFor("EN-GB"))

        // 应用只有 values / values-en 两套资源，其余全落回中文
        assertEquals(SettingsLanguage.ZH, settingsLanguageFor("zh"))
        assertEquals(SettingsLanguage.ZH, settingsLanguageFor("zh-CN"))
        assertEquals(SettingsLanguage.ZH, settingsLanguageFor("zh-Hans"))
        assertEquals(SettingsLanguage.ZH, settingsLanguageFor("zh-Hant"))
        assertEquals(SettingsLanguage.ZH, settingsLanguageFor("fr"))
        assertEquals(SettingsLanguage.ZH, settingsLanguageFor(""))
    }

    @Test
    fun `system english without explicit app locale selects english`() {
        val originalLocale = Locale.getDefault()
        try {
            Locale.setDefault(Locale.US)
            // 前置条件：从未通过 per-app language 显式设置过语言（本用例争的就是这条回落分支）
            assertTrue(AppCompatDelegate.getApplicationLocales().isEmpty)

            // 缺陷判据（可执行）：旧回显真源（存储默认值）断言「中文」，生效语言断言「英文」——
            // 两者分叉正是「界面英文、设置项勾简体中文」的成因，修复后 UI 只认后者。
            assertEquals(SettingsLanguage.ZH, SettingsService.getDefaultSettings().language)
            assertEquals(SettingsLanguage.EN, currentSettingsLanguage())
        } finally {
            Locale.setDefault(originalLocale)
        }
    }

    @Test
    fun `system chinese without explicit app locale selects chinese`() {
        val originalLocale = Locale.getDefault()
        try {
            Locale.setDefault(Locale.SIMPLIFIED_CHINESE)
            assertTrue(AppCompatDelegate.getApplicationLocales().isEmpty)

            assertEquals(SettingsLanguage.ZH, currentSettingsLanguage())
        } finally {
            Locale.setDefault(originalLocale)
        }
    }
}
