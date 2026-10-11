package com.fittracker.app.data.auth

import kotlinx.serialization.Serializable

/**
 * 认证域公共类型 + 提供方抽象——移植自鸿蒙 `entry/src/main/ets/common/services/auth/`。
 *
 * 源定位：
 *  - `auth/AuthProvider.ets:13`（抽象类 `AuthProvider`，14 个抽象成员）
 *  - `auth/AuthTypes.ets:15`（`interface AuthSession`）/ `:25`（`AuthResult` / `VerifyCodeResult`）
 *  - `auth/SandboxAuthProvider.ets`（沙盒实现，见同目录 `SandboxAuthProvider.kt`）
 *  - `common/services/AuthService.ets`（门面，本波未移植——见报告「未决项」）
 *
 * 本波（Wave 5）聚焦**账号密码链路**：Provider 抽象 + 沙盒实现 + 会话管理。
 * 源接口里的验证码链路（`requestPhoneCode` / `requestEmailCode`）、第三方登录
 * （`loginWithThirdParty`）与门面 `AuthService` 未纳入本波接口——见报告「未决项」。
 *
 * 与源的差异（方法签名）：
 *  - 源 `registerWithEmail(email, password, code, nickname)` → 安卓侧 [AuthProvider.signUp]
 *    去掉 `code`（验证码）参数：本波不接验证码链路（源沙盒固定演示码 `'000000'`，
 *    见 `SandboxAuthProvider.ets:23`）。
 *  - 源 `AuthResult { success; message; session }` → 安卓侧改用 Kotlin [Result]`<AuthSession>`，
 *    失败携带 [AuthException]，其 `message` **逐字取自源文案**（如 `'密码错误，请重试'`）。
 *  - 源方法首参 `context: Context` → 安卓侧改为**构造注入** `JsonStore`（见实现类），
 *    便于单测注入临时文件、避免触真实应用存储。
 */

/**
 * 会话快照——源 `auth/AuthTypes.ets:15` `interface AuthSession`。
 *
 * 字段名与源 JSON 输出逐字一致（互操作约束：备份包/跨平台对照依赖于此）。
 * `signedInAt` 承载源 `number`（`Date.now()` 毫秒）→ 安卓侧用 [Long]。
 */
@Serializable
data class AuthSession(
    val userId: String,
    val displayName: String,
    val phone: String,
    val email: String,
    val providerId: String,
    val signedInAt: Long,
)

/**
 * 认证失败异常——承载**逐字源文案**。
 *
 * 源以 `AuthResult.message` 携带失败原因；安卓侧因返回 [Result]，失败原因收进本异常的
 * `message`。文案一律照抄源（`SandboxAuthProvider.ets` 内的中文字符串），不得改写措辞。
 */
class AuthException(message: String) : Exception(message)

/**
 * 验证码请求结果——源 `auth/AuthTypes.ets:32` `interface VerifyCodeResult`。
 *
 * `devCodeHint` 仅沙盒模式回显演示码（源 `SandboxAuthProvider.ets:210`）；生产路径恒为空串。
 */
data class VerifyCodeResult(
    val success: Boolean,
    val message: String,
    val devCodeHint: String,
)

/**
 * 认证后端抽象——源 `auth/AuthProvider.ets:13` `abstract class AuthProvider`。
 *
 * 实现：`SandboxAuthProvider`（本地沙盒，源 `auth/SandboxAuthProvider.ets`）。
 * 源另有 `AgcAuthProvider`（AGC 云认证）——本波未移植（无云依赖）。
 *
 * 所有可能失败的方法返回 [Result]；成功值即会话快照。
 */
interface AuthProvider {

    /** 提供方标识：`'sandbox'`（源 `AuthProvider.ets:15` `getProviderId`）。 */
    val providerId: String

    /** 当前环境是否可用（源 `AuthProvider.ets:18` `isAvailable`；沙盒恒 `true`）。 */
    fun isAvailable(): Boolean

    /**
     * 注册新账号——源 `AuthProvider.ets:33` `registerWithEmail(email, password, code, nickname)`。
     * 安卓侧省略源 `code`（验证码）参数，见类注释「与源的差异」。
     */
    suspend fun signUp(email: String, password: String, nickname: String): Result<AuthSession>

    /** 账号（邮箱）+ 密码登录——源 `AuthProvider.ets:36` `loginWithEmailPassword`。 */
    suspend fun signIn(account: String, password: String): Result<AuthSession>

    /**
     * 请求手机验证码——源 `AuthProvider.ets:24` `requestPhoneCode`。
     * 沙盒实现回显演示码（`devCodeHint`）；云端实现经 SMS provider 发送**真短信**。
     * 默认实现（未接入验证码链路的提供方）返回失败结果。
     */
    suspend fun requestPhoneCode(phone: String): VerifyCodeResult =
        VerifyCodeResult(success = false, message = "当前认证方式不支持手机验证码", devCodeHint = "")

    /**
     * 手机验证码登录——源 `AuthProvider.ets:27` `loginWithPhoneCode`。
     * 语义同源：手机号未注册时**自动建号**（快速注册）。
     */
    suspend fun signInWithPhoneCode(phone: String, code: String): Result<AuthSession> =
        Result.failure(AuthException("当前认证方式不支持手机验证码"))

    /** 退出登录（清理提供方侧会话）——源 `AuthProvider.ets:42` `signOut`。 */
    suspend fun signOut()

    /** 是否已登录（内存会话非空）——源 `AuthProvider.ets:45` `getCurrentSession` 派生。 */
    fun isLoggedIn(): Boolean

    /** 提供方侧当前会话——源 `AuthProvider.ets:45` `getCurrentSession`。 */
    fun currentUser(): AuthSession?

    /** 清空内存状态（测试 / 门面清理）——源 `AuthProvider.ets:51` `clearAllData`。 */
    fun clearAllData()

    /** 清空持久化状态（沙盒存储清理）——源 `AuthProvider.ets:54` `clearPersisted`。 */
    suspend fun clearPersisted()
}
