package com.fittracker.app.wxapi

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import com.fittracker.app.data.auth.WxAuthResult
import com.fittracker.app.data.auth.WxAuthStore

/**
 * 微信回调入口 Activity。
 *
 * ⚠ 路径约定：微信 Android SDK 要求回调 Activity 必须位于
 * `{applicationId}.wxapi.WXEntryActivity`（此处 applicationId = com.earthrhythm.fittracker），
 * 且必须在 AndroidManifest.xml 中声明 `android:exported="true"`。
 * 路径或声明有误会导致授权后无法回到本应用。
 *
 * 契约（微信官方 OpenSDK 接入指南）：
 *  - 本 Activity 需实现 IWXAPIEventHandler（onReq / onResp）
 *  - 在 onCreate 中调 api.handleIntent(intent, this)
 *  - onNewIntent 中调 setIntent(intent) + api.handleIntent(...)
 *  - 处理完成后 finish()，把结果交给 WxAuthStore 供登录页消费
 *
 * 实现状态（本波）：**占位实现** —— 未引入微信 Android SDK 依赖（需开放平台资质与
 * AppID 才能完成真机验证），故此处只建立回调落点与数据通道骨架，不 import 微信 SDK。
 * 待资质就绪后按上述契约补 IWXAPIEventHandler 实现（见下方 TODO 注释）。
 *
 * 本文件对应计划 Wave 2-C；因 SDK 依赖与资质绑定，当前为「结构就位、逻辑待接」状态。
 */
class WXEntryActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleWeChatIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleWeChatIntent(intent)
    }

    /**
     * 解析微信回调并落盘，随后结束本 Activity。
     *
     * TODO(资质就绪后)：接入微信 Android SDK
     *  - val api = WXAPIFactory.createWXAPI(this, WX_APP_ID, false)
     *  - api.handleIntent(intent, this)   // 触发 IWXAPIEventHandler.onResp
     *  - 在 onResp(resp: BaseResp) 中：resp is SendAuth.Resp →
     *      resp.errCode == BaseResp.ErrCode.ERR_OK → WxAuthStore.saveCode(this, resp.code)
     *      resp.errCode == ERR_USER_CANCEL → WxAuthStore.saveFailure(this, "cancelled")
     *
     * 当前无 SDK 时：仅尝试从 Intent extras 读取（便于测试注入），读不到则记录失败。
     */
    private fun handleWeChatIntent(intent: Intent?) {
        val code: String? = intent?.getStringExtra(EXTRA_WECHAT_AUTH_CODE)
        if (code.isNullOrEmpty()) {
            // 无 code：授权未完成或用户取消。记录失败供登录页消费（不区分取消/错误，
            // 由 UI 侧按文案呈现；真接入后应据 resp.errCode 细分）。
            WxAuthStore.saveFailure(this, "cancelled", "微信授权未完成")
        } else {
            val state: String = intent?.getStringExtra(EXTRA_WECHAT_STATE).orEmpty()
            WxAuthStore.saveCode(this, code, state)
        }
        finish()
    }

    companion object {
        /** 测试/调试注入用 extra 键（真接入后由微信 SDK 回调替代）。 */
        private const val EXTRA_WECHAT_AUTH_CODE: String = "wx_auth_code"
        private const val EXTRA_WECHAT_STATE: String = "wx_auth_state"
    }
}
