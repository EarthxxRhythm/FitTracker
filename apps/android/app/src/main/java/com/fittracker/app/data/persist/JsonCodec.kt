package com.fittracker.app.data.persist

import kotlinx.serialization.json.Json

/**
 * 序列化配置。
 *
 * - `ignoreUnknownKeys`：宽容读取——鸿蒙侧未来加字段时，旧版 Android 解析不炸（前向兼容）。
 * - `encodeDefaults`：导出含默认值——对齐鸿蒙 `JSON.stringify` 输出全部字段的行为（互操作）。
 */
object JsonCodec {

    /** 常规读写（内部存储、单测）。 */
    val json: Json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    /** 导出用美化格式（对齐鸿蒙 `JSON.stringify(pkg, null, 2)` 的可读形态）。 */
    val prettyJson: Json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
        prettyPrint = true
    }
}
