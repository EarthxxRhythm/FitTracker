# 演示媒体资产三处口径（本地 / 仓库 / 云服务器对齐）

> 目的：把演示 GIF 与姿势表在**本地设备端 / git 仓库 / 云服务器**三处的分布口径统一。
> 本文件是口径真源；`server/supabase/migrations/20261101000002_exercise_media.sql` 是云侧落点。
> 状态：**基础设施与流程已就绪；GIF 本体批量上传依赖用户对 3D 风格目检拍板**（见 `.rivet\COMMAND.md` 3D GIF 线）。

## 1. 三处分布口径

| 处 | 存放形态 | 命名口径 |
|---|---|---|
| 本地（设备端） | 演示 GIF 打包进 app 资产（鸿蒙 rawfile / Android assets），按动作 id 命名 | `${exerciseId}.gif` |
| 仓库 | 生成脚本 `apps\harmony\tools\content\3d\`（engine/encode-gif/gif-decode/build-exercise-gifs-3d）+ 姿势表 `poses.json`；GIF 产物归档于 `test_run\showcase-gifs-3d\`（不入库） | 同 `${exerciseId}.gif` |
| 云服务器 | Supabase Storage bucket `exercise-media`（公开读）+ `public.exercise_media` 元数据表 | 对象路径 `gifs/${exerciseId}.gif` |

命名口径锚定既有代码：`FtLibraryModel.kt`（L705 注释「演示 GIF 资源名 `${id}.gif`」）。

## 2. 云端对象与元数据

- **bucket**：`exercise-media`（public = true，匿名可读；未登录加载演示图不依赖鉴权）。
- **对象路径**：`exercise-media/gifs/{exerciseId}.gif`。
- **uri 口径**（写入 `exercise_media.uri`）：
  `https://api.earthrhythm.cloud/storage/v1/object/public/exercise-media/gifs/{exerciseId}.gif`
- **元数据表**：`public.exercise_media`（media_id / exercise_id / media_type / uri / thumbnail_uri / view_angle / duration_seconds / license_type / source_note / checksum / sort_order），
  `exercise_id` 外键引用 `public.exercises`，公开读、客户端不可写。

## 3. 姿势表边界

`apps\harmony\tools\content\3d\poses.json` 是 **GIF 生成工具的输入**（双帧关节角），
**不入云、不打包进 app**——它不是运行时数据。运行时只消费渲染后的 GIF。

## 4. 上传管线（风格拍板后执行）

1. 批量生成：`build-exercise-gifs-3d.mjs` 按 `poses.json` 扩充后的条目渲染 `${exerciseId}.gif`（102 条动作对齐内容库）；
2. checksum：对每个 GIF 算摘要，写入元数据 `checksum`（可复用生成脚本已有的校验逻辑）；
3. INSERT 元数据：`exercise_media` 表写入 media_id=`gif:{exerciseId}`、media_type=`gif`、uri（§2 口径）；
4. 上传 Storage：对象路径 `gifs/${exerciseId}.gif`（服务端直传或部署脚本，不经客户端写策略）；
5. 计数对账：`tools\check-content-parity.mjs --remote` 核对云端 exercise_media 行数 = 生成 GIF 数。

## 5. 变更纪律

- 改名/换路径 → 先改本文件，再同步 `exercise_media.sql` 注释与上传脚本，`FtLibraryModel.kt` 的资源名口径不随云路径变（本地打包与云 uri 是两套存放，命名一致即可）。
- bucket 或对象路径变更属于破坏性变更：存量对象会 404，需先上传新路径再退役旧路径。
