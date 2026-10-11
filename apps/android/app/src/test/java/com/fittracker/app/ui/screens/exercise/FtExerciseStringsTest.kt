package com.fittracker.app.ui.screens.exercise

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.fittracker.app.R
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * 动作详情域（exerciseDetail 屏）文案资源的**逐字真源**断言（Wave 8 i18n）。
 *
 * 屏内静态文案走 `stringResource(R.string.exercise_*)`；动态/降级文案由模型层的 `FtLabel`
 * 承载资源 ID + 参数。逐字真值在 `values/strings_exercise.xml`（zh）。
 *
 * `@Config(sdk = [34])` + `qualifiers` 约定同 [com.fittracker.app.ui.screens.body.FtBodyStringsTest]。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "zh-rCN")
class FtExerciseStringsTest {

    private val context: Context = ApplicationProvider.getApplicationContext()

    @Test
    fun `exercise 域文案中文逐字对齐源页`() {
        val expectations = listOf(
            R.string.exercise_lane_media_title to "媒体与演示",
            R.string.exercise_lane_media_desc to "先确认媒体资源和演示状态，再决定直接训练还是查看更深内容。",
            R.string.exercise_lane_technique_title to "执行与替代",
            R.string.exercise_lane_technique_desc to "把动作步骤、关键提醒和替代动作放在同一段，方便训练前快速过一遍。",
            R.string.exercise_lane_meta_title to "扩展与资料",
            R.string.exercise_lane_meta_desc to "把训练资料和元信息收在尾部，不干扰前面的主任务。",
            R.string.exercise_not_found_eyebrow to "动作详情",
            R.string.exercise_not_found_title to "未找到动作",
            R.string.exercise_not_found_desc to "当前入口没有带上有效的动作信息，请从训练预览页或训练回顾页重新进入。",
            R.string.exercise_metric_steps_label to "步骤",
            R.string.exercise_metric_steps_note to "执行序列",
            R.string.exercise_metric_cues_label to "提示",
            R.string.exercise_metric_cues_note to "关键提醒",
            R.string.exercise_metric_alternatives_label to "替代",
            R.string.exercise_metric_alternatives_note to "可切换动作",
            R.string.exercise_focus_label to "训练焦点",
            R.string.exercise_safety_label to "安全提示",
            R.string.exercise_eyebrow_learning to "动作学习",
            R.string.exercise_eyebrow_reference to "动作资料",
            R.string.exercise_eyebrow_detail to "动作详情",
            R.string.exercise_hero_summary to "%1\$s | %2\$s | %3\$s",
            R.string.exercise_hero_focus_default to "先确认动作路径和发力顺序",
            R.string.exercise_muscle_pending to "目标肌群待补充",
            R.string.exercise_equipment_pending to "器械要求待补充",
            R.string.exercise_meta_id to "动作编号 %1\$s",
            R.string.exercise_execution_focus_default to "先确认动作路径、节奏和发力顺序。",
            R.string.exercise_safety_focus_default to "暂无额外安全提示，训练前仍建议先完成热身与重量试探。",
            R.string.exercise_media_title to "动作演示",
            R.string.exercise_media_cover_label to "封面",
            R.string.exercise_media_cover_note to "静态预览",
            R.string.exercise_media_video_label to "视频",
            R.string.exercise_media_video_note to "动态演示",
            R.string.exercise_media_source_row to "统一来源",
            R.string.exercise_media_license_row to "统一授权",
            R.string.exercise_media_cover_block to "封面资源",
            R.string.exercise_media_video_block to "视频资源",
            R.string.exercise_media_preview_overlay to "动作预览",
            R.string.exercise_a11y_demo to "%1\$s 动作演示",
            R.string.exercise_asset_ref_row to "资源引用",
            R.string.exercise_asset_source_row to "来源说明",
            R.string.exercise_asset_license_row to "授权口径",
            R.string.exercise_video_placeholder_ready to "本地动作库已收录视频素材",
            R.string.exercise_video_placeholder_soon to "当前动作库先提供图文讲解，视频素材会后续补充",
            R.string.exercise_difficulty_beginner to "入门",
            R.string.exercise_difficulty_intermediate to "进阶",
            R.string.exercise_difficulty_advanced to "高级",
            R.string.exercise_media_badge_playable to "可播放",
            R.string.exercise_media_status_playable to "已解析到可直接展示的媒体资源",
            R.string.exercise_media_summary_playable to "当前版本会直接展示可解析资源，同时保留来源和授权说明。",
            R.string.exercise_media_detail_playable to "轻量闭环优先服务动作理解；后续再考虑缓存、批量分发和更多播放器能力。",
            R.string.exercise_media_badge_declared to "已配置",
            R.string.exercise_media_status_declared to "媒体引用已记录，当前按受控降级展示",
            R.string.exercise_media_summary_declared to "页面会优先把封面、来源、授权和失败原因说清楚，不会对未映射资源强行尝试播放。",
            R.string.exercise_media_detail_declared to "当前 `local://` 更像内容库里的受控引用；等真实资源映射落地后，可以在这里平滑升级为预览或播放。",
            R.string.exercise_media_badge_placeholder to "图文",
            R.string.exercise_media_status_placeholder to "当前先提供图文讲解，视频素材会随内容包逐步补齐",
            R.string.exercise_media_detail_placeholder to "现阶段优先保证动作要点、来源和训练说明可直接使用；后续补入视频后可沿用同一页面结构。",
            R.string.exercise_media_badge_missing to "待补齐",
            R.string.exercise_media_status_missing to "暂未提供封面或视频",
            R.string.exercise_media_summary_missing to "当前动作还没有可展示的媒体信息。",
            R.string.exercise_media_detail_missing to "后续补入受控的封面或视频引用后，这里会自动切换到更明确的预览状态。",
            R.string.exercise_asset_cover_ready to "可预览",
            R.string.exercise_asset_cover_declared to "已记录引用",
            R.string.exercise_asset_cover_missing to "未提供",
            R.string.exercise_asset_video_ready to "可播放",
            R.string.exercise_asset_video_declared to "待映射播放",
            R.string.exercise_asset_video_missing to "未提供",
            R.string.exercise_asset_cover_primary_ready to "封面可直接预览",
            R.string.exercise_asset_cover_primary_declared to "封面引用已记录",
            R.string.exercise_asset_cover_primary_missing to "暂无封面素材",
            R.string.exercise_asset_video_primary_ready to "视频可直接播放",
            R.string.exercise_asset_video_primary_declared to "视频引用已记录",
            R.string.exercise_asset_video_primary_missing to "暂无动作演示视频",
            R.string.exercise_asset_cover_secondary_ready to "当前资源地址可直接交给图片组件渲染。",
            R.string.exercise_asset_video_secondary_ready to "当前资源地址可直接交给播放器消费。",
            R.string.exercise_asset_cover_secondary_local to "当前版本只保留 `local://` 受控引用，尚未映射到应用内真实封面文件。",
            R.string.exercise_asset_video_secondary_local to "当前版本不做整库离线视频，也不会对未映射的 `local://` 资源强行播放。",
            R.string.exercise_asset_secondary_declared to "当前引用已进入内容库，但还不在页面内直接展示的受支持范围。",
            R.string.exercise_asset_secondary_tail to "后续补入受控资源后即可在这里展示更完整的媒体体验。",
            R.string.exercise_source_missing to "未提供",
            R.string.exercise_source_local to "本地动作库引用",
            R.string.exercise_source_remote to "远程受控资源",
            R.string.exercise_source_file to "应用内文件资源",
            R.string.exercise_source_custom to "自定义资源引用",
            R.string.exercise_license_missing to "暂无授权信息",
            R.string.exercise_license_local to "仅允许自制或已授权素材落地",
            R.string.exercise_license_remote to "需保持远程资源授权可追溯",
            R.string.exercise_license_file to "应用内已打包或用户侧文件",
            R.string.exercise_license_custom to "需在接入前补齐授权说明",
            R.string.exercise_note_source_both to "封面：%1\$s；视频：%2\$s",
            R.string.exercise_note_source_video to "视频：%1\$s",
            R.string.exercise_note_source_cover to "封面：%1\$s",
            R.string.exercise_note_source_none to "当前动作未附带媒体来源",
            R.string.exercise_note_license_both to "封面：%1\$s；视频：%2\$s",
            R.string.exercise_note_license_video to "视频：%1\$s",
            R.string.exercise_note_license_cover to "封面：%1\$s",
            R.string.exercise_note_license_none to "补入资源时需同步登记授权口径",
            R.string.exercise_preview_cover to "封面预览",
            R.string.exercise_preview_video to "视频资源已就绪",
            R.string.exercise_preview_reference to "资源引用已登记",
            R.string.exercise_preview_missing to "媒体待补充",
            R.string.exercise_availability_inline to "可内联",
            R.string.exercise_availability_reference to "仅引用",
            R.string.exercise_availability_missing to "缺失",
            R.string.exercise_status_empty_warning to "暂无安全注意",
            R.string.exercise_status_empty_error to "暂无常见错误",
            R.string.exercise_status_empty_info to "暂无训练提示",
            R.string.exercise_technique_title to "执行要点",
            R.string.exercise_steps_title to "动作步骤",
            R.string.exercise_steps_empty to "暂无动作步骤",
            R.string.exercise_cues_title to "训练提示",
            R.string.exercise_mistakes_title to "常见错误",
            R.string.exercise_safety_title to "安全注意",
            R.string.exercise_alternative_title to "替代动作",
            R.string.exercise_alternative_desc to "如果当前器械条件不匹配，或你想降低动作门槛，可以先从这里选择同目标动作。",
            R.string.exercise_alternative_empty to "当前没有登记替代动作，可先按当前动作完成训练。",
            R.string.exercise_metadata_title to "资料元信息",
            R.string.exercise_meta_id_row to "动作编号",
            R.string.exercise_meta_name_en_row to "英文名称",
            R.string.exercise_meta_muscle_row to "目标肌群",
            R.string.exercise_meta_equipment_row to "器械要求",
        )

        expectations.forEach { (id, expected) ->
            assertEquals("资源 id=$id 与源页中文不一致", expected, context.getString(id))
        }
    }

    @Test
    fun `exercise 带参文案插值逐字`() {
        assertEquals("动作编号 ex_bench", context.getString(R.string.exercise_meta_id, "ex_bench"))
        assertEquals("杠铃卧推 动作演示", context.getString(R.string.exercise_a11y_demo, "杠铃卧推"))
        assertEquals("肌群 | 器械 | 提示", context.getString(R.string.exercise_hero_summary, "肌群", "器械", "提示"))
        assertEquals("封面：本地动作库引用；视频：远程受控资源", context.getString(R.string.exercise_note_source_both, "本地动作库引用", "远程受控资源"))
    }

    @Test
    @Config(sdk = [34], qualifiers = "en-rUS")
    fun `exercise 英文资源在 en 区域生效`() {
        assertEquals("Exercise detail", context.getString(R.string.exercise_not_found_eyebrow))
        assertEquals("Exercise not found", context.getString(R.string.exercise_not_found_title))
        assertEquals("Steps", context.getString(R.string.exercise_steps_title))
        assertEquals("Beginner", context.getString(R.string.exercise_difficulty_beginner))
        assertEquals("Playable", context.getString(R.string.exercise_media_badge_playable))
        assertEquals("Exercise ID ex_bench", context.getString(R.string.exercise_meta_id, "ex_bench"))
        assertEquals("Barbell Bench Press demo", context.getString(R.string.exercise_a11y_demo, "Barbell Bench Press"))
        assertEquals("Cover preview", context.getString(R.string.exercise_preview_cover))
    }
}
