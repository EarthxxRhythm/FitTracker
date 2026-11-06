package com.fittracker.app.data.service

import android.content.Context
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.sync.SyncOrchestrator
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * 登录成功后的收尾编排。
 *
 * 源原型 `ft-stage.js` 的 afterAuth 序列：认证成功后触发首次后台同步、停留 900ms、跳首页。
 * 三条登录路径（密码、手机验证码、注册即登录）共用这一段，差异（成功文案、失败分支、
 * 注册额外提示）留在调用方。
 */
object LoginOrchestrator {

    /** 原型 afterAuth 的停留时长（毫秒）——提交成功后 900ms 跳首页。 */
    const val AFTER_AUTH_DELAY_MS = 900L

    /** 认证成功后的落地路由。 */
    const val HOME_ROUTE = "home"

    /**
     * 登录成功收尾：后台首次同步（不阻塞跳转）→ 延时 → 跳首页。
     *
     * 须在调用方的协程内 await；[syncScope] 只用于发起同步，同步不阻塞本函数。
     */
    suspend fun onLoginSucceeded(
        context: Context,
        store: JsonStore,
        syncScope: CoroutineScope,
        onNavigate: (String) -> Unit,
    ) {
        // 登录成功钩子（源 CloudSyncService.onSignIn）：后台首次同步、不阻塞跳转
        syncScope.launch {
            SyncOrchestrator.onSignIn(
                store,
                SyncOrchestrator.forFilesDir(context.filesDir),
                AvatarImageService.resolveDir(context),
            )
        }
        delay(AFTER_AUTH_DELAY_MS)
        onNavigate(HOME_ROUTE)
    }
}
