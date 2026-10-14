package com.fittracker.app.data.cloud

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.URL

/**
 * Supabase 基础设施：配置读取 + 最小 HTTP 封装 + 端点工具。
 *
 * 设计取舍：
 * - **零第三方依赖**——用 `HttpURLConnection`（项目当前无网络库；需求仅 4 个端点：
 *   GoTrue signup/token/logout + PostgREST snapshots 读写）。传输层经 [CloudHttpTransport]
 *   抽象注入——单测用 fake，零网络。
 * - 配置来自 `BuildConfig`（`local.properties` 注入，见 `app/build.gradle.kts`）——
 *   不进版本库；空串 = 未配置（云端能力禁用，见 [SupabaseConfig.isConfigured]）。
 */

/** Supabase 部署配置。 */
object SupabaseConfig {

    /** 项目 URL（如 `https://xxxx.supabase.co`）；空串 = 未配置。 */
    val url: String = com.fittracker.app.BuildConfig.SUPABASE_URL

    /** publishable key（公开客户端凭据；访问能力受 RLS 约束）。 */
    val publishableKey: String = com.fittracker.app.BuildConfig.SUPABASE_PUBLISHABLE_KEY

    /** 是否已配置（未配置时云端路径优雅禁用）。 */
    val isConfigured: Boolean get() = url.isNotEmpty() && publishableKey.isNotEmpty()
}

/** HTTP 响应快照。 */
data class CloudHttpResponse(val status: Int, val body: String)

/** HTTP 传输抽象——生产用 [UrlConnectionTransport]，单测注入 fake。 */
interface CloudHttpTransport {
    suspend fun request(
        method: String,
        url: String,
        headers: Map<String, String> = emptyMap(),
        body: String? = null,
    ): CloudHttpResponse
}

/** `HttpURLConnection` 实现（IO 调度器；15s 连接 / 20s 读取超时）。 */
object UrlConnectionTransport : CloudHttpTransport {

    override suspend fun request(
        method: String,
        url: String,
        headers: Map<String, String>,
        body: String?,
    ): CloudHttpResponse = withContext(Dispatchers.IO) {
        val connection: HttpURLConnection = URL(url).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = method
            connection.connectTimeout = 15_000
            connection.readTimeout = 20_000
            headers.forEach { (name, value) -> connection.setRequestProperty(name, value) }
            if (body != null) {
                connection.doOutput = true
                connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            }
            val status: Int = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val text: String = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() } ?: ""
            CloudHttpResponse(status = status, body = text)
        } finally {
            connection.disconnect()
        }
    }
}

/**
 * Supabase 端点与标准头。
 *
 * 头口径：`apikey` 恒为 publishable key；`Authorization` 默认同为 publishable key
 * （匿名请求），传入用户 [accessToken] 后以它为 Bearer（RLS 的 `auth.uid()` 由此取）。
 */
object SupabaseEndpoints {

    fun auth(path: String): String = "${SupabaseConfig.url}/auth/v1/$path"

    fun rest(path: String): String = "${SupabaseConfig.url}/rest/v1/$path"

    /** Edge Functions 端点：`{url}/functions/v1/{path}`（第三方换票等）。 */
    fun functions(path: String): String = "${SupabaseConfig.url}/functions/v1/$path"

    fun headers(accessToken: String? = null): Map<String, String> = buildMap {
        put("apikey", SupabaseConfig.publishableKey)
        put("Authorization", "Bearer ${accessToken ?: SupabaseConfig.publishableKey}")
        put("Content-Type", "application/json")
    }
}
