package com.fittracker.app

import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.fittracker.app.data.service.ContentRepository
import com.fittracker.app.notifications.ReminderScheduler
import com.fittracker.app.ui.FtApp
import kotlinx.coroutines.launch

/**
 * 主 Activity——Wave 6 起为 `AppCompatActivity`：承载 AppCompat 的 per-app language
 * （[androidx.appcompat.app.AppCompatDelegate.setApplicationLocales]）机制。
 * 纯 Compose 渲染（主题仅窗口层；themes.xml 已切 AppCompat 族）。
 */
class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        // W4（A6）：训练提醒调度登记（幂等）——只读本地偏好 + 登记 WorkManager，无网络 / 重活。
        // 覆盖升级 / 清数据后周期任务丢失的场景；开关状态由 Worker 每次执行现读，故此处只管登记。
        lifecycleScope.launch { ReminderScheduler.syncFromSettings(applicationContext) }
        // 内容库预热（幂等）：任何数据路径（如偏好页生成计划）都能取到动作库，
        // 不再依赖用户先打开动作库屏（真机验收 2026-10-12 缺陷的保险层）。
        lifecycleScope.launch { runCatching { ContentRepository.ensureLoaded(applicationContext) } }
        setContent {
            FtApp()
        }
    }
}
