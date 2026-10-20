import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.kotlin.compose)
}

// Supabase 部署配置（读 local.properties，不进版本库；缺省为空串 → 云端功能优雅禁用）。
// publishable key 是设计上可公开的客户端凭据（访问受 RLS 约束），但仍不硬编码进仓库，
// 便于换项目/环境——读取方见 `data/cloud`。
val supabaseLocalProps: Properties = Properties().apply {
    val propsFile = rootProject.file("local.properties")
    if (propsFile.exists()) {
        propsFile.inputStream().use { load(it) }
    }
}
val supabaseUrl: String = supabaseLocalProps.getProperty("supabase.url") ?: ""
val supabasePublishableKey: String = supabaseLocalProps.getProperty("supabase.publishableKey") ?: ""

// 微信 OpenSDK 的 AppID（同样读 local.properties，不进版本库；缺省为空串 → 微信登录优雅禁用）。
// 字段名与鸿蒙侧 thirdparty.json 的 wechatAppId 语义一致（同一开放平台应用的同一 AppID）。
val wechatAppId: String = supabaseLocalProps.getProperty("wechat.appId") ?: ""

// QQ 互联 AppID（数字串；同鸿蒙侧 thirdparty.json 的 qqAppId）。
// 空串时 QQ 登录通道不可用（登录页给出「暂未开通」提示）。
val qqAppId: String = supabaseLocalProps.getProperty("qq.appId") ?: ""

// Release 签名（同样读 local.properties，材料不进版本库）。
// 未配置时 hasReleaseSigning = false → release 构建不签名，配置阶段不报错；
// 生成 keystore 与填写方式见 docs/release/android-signing-and-store.md。
val releaseStoreFile: String? = supabaseLocalProps.getProperty("release.storeFile")
val releaseStorePassword: String? = supabaseLocalProps.getProperty("release.storePassword")
val releaseKeyAlias: String? = supabaseLocalProps.getProperty("release.keyAlias")
val releaseKeyPassword: String? = supabaseLocalProps.getProperty("release.keyPassword")
val hasReleaseSigning: Boolean =
    !releaseStoreFile.isNullOrBlank() &&
        !releaseStorePassword.isNullOrBlank() &&
        !releaseKeyAlias.isNullOrBlank() &&
        !releaseKeyPassword.isNullOrBlank()

android {
    namespace = "com.fittracker.app"
    compileSdk = 37
    // 钉住已安装的 build-tools，避免 AGP 去拉它默认的版本
    buildToolsVersion = "36.0.0"

    defaultConfig {
        // 上架身份，与鸿蒙侧 bundleName（AppScope/app.json5）统一 —— 备案 / 应用市场登记 / 签名标识都用它。
        // namespace 仍为 com.fittracker.app：它只决定代码内 R 类与 BuildConfig 的包名，与上架身份无关；
        // 改名需移动整个源码包结构（122 个 .kt / 330 处引用），另立一轮独立重构。
        applicationId = "com.earthrhythm.fittracker"
        minSdk = 24
        targetSdk = 37
        versionCode = 1
        versionName = "0.1.0"

        // 部署配置注入（local.properties）——空串表示未配置（云端能力禁用）
        buildConfigField("String", "SUPABASE_URL", "\"$supabaseUrl\"")
        buildConfigField("String", "SUPABASE_PUBLISHABLE_KEY", "\"$supabasePublishableKey\"")
        // 微信 AppID——空串时微信登录通道不可用（WXEntryActivity 会直接结束）
        buildConfigField("String", "WECHAT_APP_ID", "\"$wechatAppId\"")
        // QQ AppID——空串时 QQ 登录通道不可用
        buildConfigField("String", "QQ_APP_ID", "\"$qqAppId\"")
        // QQ SDK 的回调 scheme 需在 AndroidManifest 中声明为字面量
        // （com.tencent.tauth.AuthActivity 的 intent-filter data scheme = tencent<APPID>）。
        // 用 manifestPlaceholders 注入，避免把 AppID 硬编码进入库的 manifest。
        manifestPlaceholders["qqAppId"] = qqAppId
    }

    signingConfigs {
        val storeFilePath = releaseStoreFile
        if (!storeFilePath.isNullOrBlank() &&
            !releaseStorePassword.isNullOrBlank() &&
            !releaseKeyAlias.isNullOrBlank() &&
            !releaseKeyPassword.isNullOrBlank()
        ) {
            create("release") {
                storeFile = file(storeFilePath)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // 未配置 local.properties 的 release.* 时不签名（构建仍可跑），
            // 配置后自动启用——避免"配置缺失即构建失败"。
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
        // Wave 6：BuildConfig 注入 Supabase 部署配置（SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY）
        buildConfig = true
    }

    testOptions {
        unitTests {
            // Robolectric 需要真实资源（Compose 测试会解析 material 等资源）
            isIncludeAndroidResources = true
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    // 状态层改造：提供 viewModel() composable，让屏状态挂在 NavBackStackEntry 作用域
    // （tab 切换 saveState=true 不清除其 ViewModelStore，故状态与已装载数据存活）。
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.activity.compose)

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    implementation(libs.androidx.navigation.compose)
    // Wave 6 修复：ViewTree 的 NavigationEventDispatcherOwner 显式注册（AppCompat 场景链断，真机启动崩溃）
    implementation(libs.androidx.navigationevent)
    implementation(libs.androidx.datastore.preferences)
    // 应用内语言切换（per-app language，AppCompatDelegate.setApplicationLocales）——设置模块 Wave 6
    implementation(libs.androidx.appcompat)
    // 训练/成就提醒本地通知调度（WorkManager）——设置模块 Wave 4
    implementation(libs.androidx.work.runtime.ktx)
    implementation(libs.kotlinx.serialization.json)
    // W2-2 动作 GIF 素材接入：Coil 负责动画 GIF 解码与内存/生命周期管理
    implementation(libs.coil.compose)
    implementation(libs.coil.gif)

    // 微信 OpenSDK（第三方登录）。版本锁定见 gradle/libs.versions.toml 的 wechatSdk。
    // 依赖它的前提：WXEntryActivity 位于 {applicationId}.wxapi 包下（微信硬性约定）。
    implementation(libs.wechat.sdk.android)

    // QQ 互联 OpenSDK（第三方登录）。**不在 Maven Central**（实测 search.maven.org 零结果），
    // 官方只提供 JAR 下载，故以本地文件引入。来源：QQ 互联开放平台 open_sdk_3.5.19_r9483ffc7_lite.jar。
    // 包结构 com.tencent.{connect,open,tauth}，纯 class 无 Android 资源，可直接 files() 引入。
    implementation(files("libs/open_sdk_3.5.19_r9483ffc7_lite.jar"))

    testImplementation(libs.junit)
    // Compose 布局层测试（Robolectric 在 JVM 上跑组合/测量）——见 FtCanvasLayoutTest
    testImplementation(libs.robolectric)
    testImplementation(libs.androidx.work.testing)
    testImplementation(libs.androidx.ui.test.junit4)

    debugImplementation(libs.androidx.ui.tooling)
    debugImplementation(libs.androidx.ui.test.manifest)
}
