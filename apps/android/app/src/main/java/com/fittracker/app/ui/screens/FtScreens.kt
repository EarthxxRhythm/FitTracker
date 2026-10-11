package com.fittracker.app.ui.screens

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalResources
import com.fittracker.app.data.auth.AuthService
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.sync.SyncOrchestrator
import com.fittracker.app.nav.FtRoute
import com.fittracker.app.ui.components.FtCanvas
import com.fittracker.app.ui.screens.account.AccountSyncScreen
import com.fittracker.app.ui.screens.active.ActiveScreen
import com.fittracker.app.ui.screens.auth.AUTH_LOGIN_SUCCESS_TOAST
import com.fittracker.app.ui.screens.auth.AUTH_REGISTER_SUCCESS_TOAST
import com.fittracker.app.ui.screens.auth.AuthToast
import com.fittracker.app.ui.screens.auth.LoginScreen
import com.fittracker.app.ui.screens.auth.RegisterScreen
import com.fittracker.app.ui.screens.body.BodyScreen
import com.fittracker.app.ui.screens.complete.CompleteScreen
import com.fittracker.app.ui.screens.home.HomeScreen
import com.fittracker.app.ui.screens.library.LibraryScreen
import com.fittracker.app.ui.screens.plan.PlanScreen
import com.fittracker.app.ui.screens.plangroup.PlanGroupScreen
import com.fittracker.app.ui.screens.plans.PlansScreen
import com.fittracker.app.ui.screens.preferences.TrainingPreferencesScreen
import com.fittracker.app.ui.screens.profile.ProfileScreen
import com.fittracker.app.ui.screens.review.ReviewScreen
import com.fittracker.app.ui.screens.settings.SettingsScreen
import com.fittracker.app.ui.screens.splash.SplashScreen
import com.fittracker.app.ui.screens.welcome.WelcomeScreen
import com.fittracker.app.ui.screens.workout.WorkoutPreviewScreen
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * 屏分派：把路由映射到具体 Composable。
 *
 * 各波次逐屏接入——接入时在此 `when` 中新增分支。`FtNavHost` 注册的全部路由
 * （`FtRoutes.navigable` 去掉 `legal` / `exerciseDetail` 两条带参特判）都已覆盖，
 * 故 `when` 无 `else` 分支；新增路由必须同步补分支，否则该路由渲染为空。
 * 屏自身负责内容；画布口径由 [FtCanvas] 依 [FtRoute.canvas] 统一施加，
 * **屏内禁止手写缩放**。
 */
@Composable
fun FtScreen(
    route: FtRoute,
    onNavigate: (String) -> Unit,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val resources = LocalResources.current
    val store = remember { JsonStore(context.appDataStore) }

    // 轻量反馈浮层。原型里 `.auth-toast` 是 `.phone` 的子元素、位于 `.auth-frame` 之外，
    // 即**不随设计空间缩放**——故它的宿主在 FtCanvas 之外，按设备坐标系定位
    // （底边内 48px、水平居中），而不是画布内的设计坐标。
    var toast by remember(route.id) { mutableStateOf<AuthToastState?>(null) }
    val scope = rememberCoroutineScope()

    // 原型 `showToast` 的 `setTimeout(…, 2000)`（fittracker-auth.html:730）
    LaunchedEffect(toast) {
        if (toast != null) {
            delay(2000)
            toast = null
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        FtCanvas(kind = route.canvas, designW = route.designW, designH = route.designH) {
            when (route.id) {
                "welcome" -> WelcomeScreen(onStart = { onNavigate("login") })
                "home" -> HomeScreen(onNavigate = onNavigate)
                "plan" -> PlanScreen(onNavigate = onNavigate)
                "plans" -> PlansScreen(onNavigate = onNavigate, onBack = onBack)
                "planGroup" -> PlanGroupScreen(onNavigate = onNavigate, onBack = onBack)
                "workout" -> WorkoutPreviewScreen(onNavigate = onNavigate, onBack = onBack)
                "active" -> ActiveScreen(onNavigate = onNavigate)
                "complete" -> CompleteScreen(onNavigate = onNavigate)
                "review" -> ReviewScreen(onNavigate = onNavigate)
                "library" -> LibraryScreen(onNavigate = onNavigate, onBack = onBack)
                "body" -> BodyScreen(onNavigate = onNavigate, onBack = onBack)
                "profile" -> ProfileScreen(onNavigate = onNavigate)
                "settings" -> SettingsScreen(onNavigate = onNavigate)
                "trainingPreferences" -> TrainingPreferencesScreen(onNavigate = onNavigate, onBack = onBack)
                "splash" -> SplashScreen(onNavigate = onNavigate)

                "login" -> LoginScreen(
                    onSubmitSuccess = { account, password ->
                        scope.launch {
                            // 真认证（沙盒/云端 Provider）：失败弹源文案；成功走原型 afterAuth 编排
                            val error = AuthService.signIn(store, account, password).exceptionOrNull()?.message
                            if (error == null) {
                                toast = AuthToastState.next(toast, resources.getString(AUTH_LOGIN_SUCCESS_TOAST))
                                // 登录成功钩子（源 CloudSyncService.onSignIn）：后台首次同步、不阻塞跳转
                                launch {
                                    SyncOrchestrator.onSignIn(store, SyncOrchestrator.forFilesDir(context.filesDir))
                                }
                                // 原型交互壳 `ft-stage.js` 的 afterAuth：提交成功后 900ms 跳首页
                                delay(900)
                                onNavigate("home")
                            } else {
                                toast = AuthToastState.next(toast, error)
                            }
                        }
                    },
                    onPhoneCodeSuccess = { _, _ ->
                        // 手机验证码登录成功（凭据已在 provider 内校验并落会话）——编排同密码成功路径
                        toast = AuthToastState.next(toast, resources.getString(AUTH_LOGIN_SUCCESS_TOAST))
                        scope.launch {
                            launch {
                                SyncOrchestrator.onSignIn(store, SyncOrchestrator.forFilesDir(context.filesDir))
                            }
                            delay(900)
                            onNavigate("home")
                        }
                    },
                    onNavigate = onNavigate,
                    onToast = { toast = AuthToastState.next(toast, it) },
                )

                "register" -> RegisterScreen(
                    onSubmitSuccess = { account, password, nickname ->
                        scope.launch {
                            // 注册（沙盒语义：注册成功即登录，见 AuthService.signUp）——失败弹源文案
                            val error = AuthService.signUp(store, account, password, nickname)
                                .exceptionOrNull()?.message
                            if (error == null) {
                                toast = AuthToastState.next(toast, resources.getString(AUTH_REGISTER_SUCCESS_TOAST))
                                // 注册成功即登录（沙盒语义 / Supabase 直通）——同样触发首次同步
                                launch {
                                    SyncOrchestrator.onSignIn(store, SyncOrchestrator.forFilesDir(context.filesDir))
                                }
                                delay(900)
                                onNavigate("home")
                            } else {
                                toast = AuthToastState.next(toast, error)
                            }
                        }
                    },
                    onNavigate = onNavigate,
                    onToast = { toast = AuthToastState.next(toast, it) },
                )

                "accountSync" -> AccountSyncScreen(
                    onNavigate = onNavigate,
                    // 返回优先出栈（与系统返回键一致）；直达无栈可退时按 PARENT 表回退 settings
                    // （入口在设置页，源 SettingsContent.ets:304）
                    onBack = onBack,
                )
            }
        }

        AuthToast(
            message = toast?.text,
            modifier = Modifier.align(Alignment.BottomCenter),
        )
    }
}

/**
 * 浮层消息的携带序号。
 *
 * 序号的作用是让「同一条文案连续弹两次」也能重新计时：`LaunchedEffect(toast)` 以实例为键，
 * 若第二次沿用同一个等值实例，键未变则协程不重启，浮层就续不足 2 秒
 * （原型每次 `showToast` 都 `clearTimeout` 后重设，是对齐该项行为）。
 */
private data class AuthToastState(val seq: Int, val text: String) {
    companion object {
        fun next(current: AuthToastState?, text: String): AuthToastState =
            AuthToastState((current?.seq ?: -1) + 1, text)
    }
}
