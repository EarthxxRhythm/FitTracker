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
    implementation(libs.androidx.activity.compose)

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.datastore.preferences)
    // 应用内语言切换（per-app language，AppCompatDelegate.setApplicationLocales）——设置模块 Wave 6
    implementation(libs.androidx.appcompat)
    // 训练/成就提醒本地通知调度（WorkManager）——设置模块 Wave 4
    implementation(libs.androidx.work.runtime.ktx)
    implementation(libs.kotlinx.serialization.json)
    // W2-2 动作 GIF 素材接入：Coil 负责动画 GIF 解码与内存/生命周期管理
    implementation(libs.coil.compose)
    implementation(libs.coil.gif)

    testImplementation(libs.junit)
    // Compose 布局层测试（Robolectric 在 JVM 上跑组合/测量）——见 FtCanvasLayoutTest
    testImplementation(libs.robolectric)
    testImplementation(libs.androidx.work.testing)
    testImplementation(libs.androidx.ui.test.junit4)

    debugImplementation(libs.androidx.ui.tooling)
    debugImplementation(libs.androidx.ui.test.manifest)
}
