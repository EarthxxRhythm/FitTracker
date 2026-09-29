# cloud/agc — AGC 侧配置材料

本目录存放「AppGallery Connect 控制台侧配置」所需的材料与说明。
完整操作手册见 [`docs/cloud-setup.md`](../../docs/cloud-setup.md)。

## 文件

| 文件 | 用途 |
| --- | --- |
| `SyncSnapshot.schema.json` | 云数据库对象类型 `SyncSnapshot` 的字段定义。在 AGC 控制台创建对象类型时用作**字段对照表**；也可尝试用控制台的「导入」功能直接导入（如校验失败则按字段表手动创建）。字段与端侧代码 `entry/src/main/ets/shared/services/CloudSnapshotStore.ets` 的 `CloudSnapshot` 接口一一对应（userId / payloadJson / updatedAt / deviceTag / schemaVersion）。 |

## 关键设计警示（配置前必读）

1. **`payloadJson` 必须用 `Text` 类型**——官方《创建数据条目》明确：`String` 字段上限 **200 字符**，装不下用户数据聚合包（预期 <200KB）；`Text` 上限 1 亿字符。
   ⚠️ 对象类型的 `fieldType` 等字段信息**部署后不可修改**（官方 FAQ："existing fields cannot be modified"）——若误配为 String，修复需删除对象类型（连带数据）重建。**创建前务必按本目录定义核对。**
2. 主键为 `userId`（String）；`updatedAt` 用 Long（毫秒时间戳超出 Integer 范围）。
3. 权限推荐：`数据创建者`全勾（行级隔离：仅自己创建的数据）；`认证用户`查询 + 新增或修改（不加删除）；`所有人`不勾写删。行级语义边界在 Wave 5 用双账号实测复核。

## 注意

- 端侧真正需要放进工程的 `schema.json`（`AppScope/resources/rawfile/schema.json`）是**从 AGC 控制台导出**的文件（对象类型页 → 勾选 → 导出 → json 格式），不是本目录这份定义参考。
- 本目录文件可入库（不含密钥）；`agconnect-services.json` 含密钥，**严禁入库**（`.gitignore` 规则 `**/agconnect-services.json` 保障）。
- 调试证书指纹（注册到 AGC 用）：`12:3B:CE:0A:30:90:63:C2:58:AD:98:3B:C6:E9:EC:9F:CC:FF:42:DD:19:4E:9D:02:48:2A:A3:AC:6A:8F:CE:61`（SHA256，提取自 `~/.ohos/config/default_FitTracker_….cer` Leaf 证书）。
