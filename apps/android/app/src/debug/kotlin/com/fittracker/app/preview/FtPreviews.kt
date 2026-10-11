package com.fittracker.app.preview

import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview
import com.fittracker.app.nav.FtCanvasKind
import com.fittracker.app.ui.components.FtCanvas
import com.fittracker.app.ui.screens.auth.LoginScreen
import com.fittracker.app.ui.screens.auth.RegisterScreen
import com.fittracker.app.ui.screens.plan.PlanScreen
import com.fittracker.app.ui.screens.plangroup.PlanGroupScreen
import com.fittracker.app.ui.screens.plans.PlansScreen
import com.fittracker.app.ui.screens.welcome.WelcomeScreen
import com.fittracker.app.ui.screens.workout.WorkoutPreviewScreen
import com.fittracker.app.ui.theme.FtTheme

/**
 * 屏预览（debug 源集，供 Android Studio 预览面板使用）。
 *
 * 每张预览的尺寸与对应屏的**视口**一致（390×844）——
 * 缩放屏的内容缩放由 `FtCanvas` 在内部施加，预览只负责给视口。
 *
 * ⚠️ 已知缺口：本环境**没有可用的无设备渲染通道**。曾尝试官方
 * `com.android.compose.screenshot` 插件（0.0.1-alpha14 / alpha16）：
 * 源集可编译，但截图任务始终报 `did not discover any tests`，
 * 疑似该 alpha 插件与 AGP 9.4.1 的预览发现机制不兼容，已回退配置。
 * 因此本文件目前只在 IDE 内可用，不参与命令行验证。
 * 视觉验收的替代路径见交付报告。
 */
private const val VIEW_W = 390
private const val VIEW_H = 844

class FtPreviews {

    @Preview(name = "welcome", widthDp = VIEW_W, heightDp = VIEW_H, showBackground = true)
    @Composable
    fun pWelcome() {
        FtTheme {
            FtCanvas(kind = FtCanvasKind.Scaled, designW = 430f, designH = 900f) {
                WelcomeScreen(onStart = {})
            }
        }
    }

    @Preview(name = "login", widthDp = VIEW_W, heightDp = VIEW_H, showBackground = true)
    @Composable
    fun pLogin() {
        FtTheme {
            FtCanvas(kind = FtCanvasKind.Scaled, designW = 430f, designH = 900f) {
                LoginScreen(
                    onSubmitSuccess = { _, _ -> },
                    onPhoneCodeSuccess = { _, _ -> },
                    onNavigate = {},
                    onToast = {},
                )
            }
        }
    }

    @Preview(name = "register", widthDp = VIEW_W, heightDp = VIEW_H, showBackground = true)
    @Composable
    fun pRegister() {
        FtTheme {
            FtCanvas(kind = FtCanvasKind.Scaled, designW = 430f, designH = 900f) {
                RegisterScreen(onSubmitSuccess = { _, _, _ -> }, onNavigate = {}, onToast = {})
            }
        }
    }

    @Preview(name = "plan", widthDp = VIEW_W, heightDp = VIEW_H, showBackground = true)
    @Composable
    fun pPlan() {
        FtTheme {
            FtCanvas(kind = FtCanvasKind.Direct) {
                PlanScreen(onNavigate = {})
            }
        }
    }

    @Preview(name = "plans", widthDp = VIEW_W, heightDp = VIEW_H, showBackground = true)
    @Composable
    fun pPlans() {
        FtTheme {
            FtCanvas(kind = FtCanvasKind.Direct) {
                PlansScreen(onNavigate = {}, onBack = {})
            }
        }
    }

    @Preview(name = "planGroup", widthDp = VIEW_W, heightDp = VIEW_H, showBackground = true)
    @Composable
    fun pPlanGroup() {
        FtTheme {
            FtCanvas(kind = FtCanvasKind.Direct) {
                PlanGroupScreen(onNavigate = {}, onBack = {})
            }
        }
    }

    @Preview(name = "workout", widthDp = VIEW_W, heightDp = VIEW_H, showBackground = true)
    @Composable
    fun pWorkout() {
        FtTheme {
            FtCanvas(kind = FtCanvasKind.Direct) {
                WorkoutPreviewScreen(onNavigate = {}, onBack = {})
            }
        }
    }
}
