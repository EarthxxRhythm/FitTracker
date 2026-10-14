package com.fittracker.app.wxapi

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import com.fittracker.app.BuildConfig
import com.fittracker.app.data.auth.WxAuthStore
import com.tencent.mm.opensdk.constants.ConstantsAPI
import com.tencent.mm.opensdk.modelbase.BaseReq
import com.tencent.mm.opensdk.modelbase.BaseResp
import com.tencent.mm.opensdk.modelmsg.SendAuth
import com.tencent.mm.opensdk.openapi.IWXAPI
import com.tencent.mm.opensdk.openapi.IWXAPIEventHandler
import com.tencent.mm.opensdk.openapi.WXAPIFactory

/**
 * 微信回调入口 Activity（真实实现）。
 *
 * ⚠ 路径约定：微信 Android SDK 要求回调 Activity 必须位于
 * `{applicationId}.wxapi.WXEntryActivity`（applicationId = com.earthrhythm.fittracker），
 * 且 AndroidManifest 中 exported=true。路径或声明有误会导致授权后无法回到应用。
 *
 * 契约（微信 OpenSDK 接入指南）：
 *  - 实现 IWXAPIEventHandler（onReq / onResp）
 *  - onCreate 中 api.handleIntent(intent, this)
 *  - onNewIntent 中 setIntent(intent) 后再 handleIntent
 *  - 处理完 finish()，结果经 WxAuthStore 交给登录页
 *
 * AppID 来源：BuildConfig.WECHAT_APP_ID（由 local.properties 注入，见 app/build.gradle.kts）。
 * 未配置时本 Activity 直接结束——避免以空 AppID 调用 SDK 产生难排查的失败。
 */
class WXEntryActivity : Activity(), IWXAPIEventHandler {

    private var api: IWXAPI? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val appId: String = BuildConfig.WECHAT_APP_ID
        if (appId.isEmpty()) {
            // 未配置 AppID：无法与微信通信。记录失败供登录页消费后结束。
            WxAuthStore.saveFailure(this, WxAuthStore.KIND_UNAVAILABLE, "微信登录未配置")
            finish()
            return
        }
        api = WXAPIFactory.createWXAPI(this, appId, false)
        api?.handleIntent(intent, this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        api?.handleIntent(intent, this)
    }

    /** 微信主动请求（如分享回跳）。当前无分享业务，仅记录。 */
    override fun onReq(req: BaseReq) {
        // 微信拉起本应用（非登录授权结果）——无业务需求
    }

    /** 授权结果回调。 */
    override fun onResp(resp: BaseResp) {
        // 仅处理授权响应；其他类型（分享/支付）忽略
        if (resp.type != ConstantsAPI.COMMAND_SENDAUTH) {
            finish()
            return
        }
        val authResp: SendAuth.Resp = resp as SendAuth.Resp
        when (authResp.errCode) {
            BaseResp.ErrCode.ERR_OK -> {
                val code: String = authResp.code.orEmpty()
                if (code.isEmpty()) {
                    WxAuthStore.saveFailure(this, WxAuthStore.KIND_ERROR, "未获取到授权码，请重试")
                } else {
                    val state: String = authResp.state.orEmpty()
                    WxAuthStore.saveCode(this, code, state)
                }
            }
            BaseResp.ErrCode.ERR_USER_CANCEL -> {
                // 用户主动取消：静默（不显示错误红字）
                WxAuthStore.saveFailure(this, WxAuthStore.KIND_CANCELLED, "")
            }
            BaseResp.ErrCode.ERR_AUTH_DENIED -> {
                WxAuthStore.saveFailure(this, WxAuthStore.KIND_ERROR, "微信授权被拒绝")
            }
            else -> {
                val message: String = authResp.errStr.orEmpty().ifEmpty { "微信授权失败" }
                WxAuthStore.saveFailure(this, WxAuthStore.KIND_ERROR, message)
            }
        }
        finish()
    }
}
