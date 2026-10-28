package com.fittracker.app.data.service

import androidx.appcompat.app.AppCompatDelegate
import java.util.Locale

/**
 * 当前应用语言标签（per-app language，AppCompat）——全项目单一读取点。
 *
 * 口径：`AppCompatDelegate.getApplicationLocales()` 非空时取其 languageTags（如 "zh" / "en"）；
 * 为空（从未显式设置）则回落系统 `Locale.getDefault().language`。
 * 判断语言用前缀：`startsWith("zh")` / `startsWith("en")`（容忍 "zh-CN" 等区域码）。
 */
fun currentLanguageTag(): String {
    val locales = AppCompatDelegate.getApplicationLocales()
    if (!locales.isEmpty) {
        val tag = locales.toLanguageTags()
        if (tag.isNotBlank()) return tag
    }
    return Locale.getDefault().language
}

/**
 * 语言标签归一为设置项的 [SettingsLanguage]：仅前缀 `en` 判英文，其余一律中文。
 *
 * 与页面资源口径一致——应用只提供 `values`（中文）与 `values-en` 两套字符串，
 * `zh-Hant`、`fr` 等不匹配 `values-en`，界面渲染的仍是中文。
 */
fun settingsLanguageFor(tag: String): SettingsLanguage =
    if (tag.startsWith("en", ignoreCase = true)) SettingsLanguage.EN else SettingsLanguage.ZH

/**
 * 设置页语言分段的当前值——真源同 [currentLanguageTag]（per-app locale 优先，回落系统 Locale）。
 *
 * 不能用 `SettingsService.loadSettings().language` 回显：该字段是「用户显式选择过的语言」，
 * 从未选择时恒为默认中文，而界面语言此时跟随系统——系统英文就会出现
 * 「界面英文、设置项却勾着简体中文」。
 */
fun currentSettingsLanguage(): SettingsLanguage = settingsLanguageFor(currentLanguageTag())
