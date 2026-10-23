package com.fittracker.app.ui

import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/**
 * Tab 一级路由的 chrome 收起状态。
 *
 * 内容屏（当前是回顾页）按滚动方向写入，壳层 [com.fittracker.app.ui.components.FtBottomTabBar]
 * 与屏内头部共同消费：`collapsed = true` 表示「向下浏览中」——底栏滑出、头部高度收缩并淡出。
 *
 * 用 CompositionLocal 传递而非逐层参数：`FtApp → FtNavHost → FtScreen → 屏` 链路很长，
 * 且只有个别屏写、只有壳与自身读。状态对象本身恒定（只改字段），故 `compositionLocalOf`
 * 的默认值不会在每个读取点新建实例。
 */
class FtChromeState {

    /** true = chrome 收起（浏览态）；false = 常驻（默认，含回顶）。 */
    var collapsed: Boolean by mutableStateOf(false)

    /** 幂等写入，避免无变化时触发无谓重组。 */
    fun updateCollapsed(value: Boolean) {
        if (collapsed != value) {
            collapsed = value
        }
    }
}

val LocalFtChrome = compositionLocalOf { FtChromeState() }
