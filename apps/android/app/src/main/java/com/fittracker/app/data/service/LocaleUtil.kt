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
