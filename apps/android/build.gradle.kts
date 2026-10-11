plugins {
    // AGP 9 起内置 Kotlin 支持，不再需要 org.jetbrains.kotlin.android 插件
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.compose) apply false
}
