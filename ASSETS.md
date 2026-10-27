# 资源来源与授权清单

> **层级**：L2 法律合规
> **最后核对**：2026-10-28
> **状态**：⚠ 含待确认项
> **上位文档**：THIRD-PARTY-NOTICES.md

本文件记录仓库内**非代码资源**（图片、GIF、音视频、设计稿）的来源与授权状态。
每一项目标状态为 ✅ 已确认（注明来源与许可）。⚠ 标记的项在确认前不应对外宣称拥有分发权。

## 一、动作演示素材

| 目录 | 数量 / 体积 | 格式 | 来源 | 授权 |
|---|---|---|---|---|
| `apps/harmony/entry/src/main/resources/rawfile/exercise-gifs/` | 23 / 1.9 MB | GIF | ⚠ 待确认 | ⚠ 待确认 |
| `apps/harmony/entry/src/main/resources/rawfile/exercise-gifs-dark/` | 23 / 1.7 MB | GIF | ⚠ 待确认 | ⚠ 待确认 |
| `apps/harmony/entry/src/main/resources/rawfile/exercise-gifs-onpage/` | 23 / 2.1 MB | GIF | ⚠ 待确认 | ⚠ 待确认 |
| `apps/harmony/entry/src/main/resources/rawfile/exercise-gifs-photo/` | 59 / 8.9 MB | GIF | ⚠ 待确认 | ⚠ 待确认 |
| `apps/android/app/src/main/assets/exercise-gifs/` | 23 | GIF | 与鸿蒙同源 | ⚠ 待确认 |
| `apps/android/app/src/main/assets/exercise-gifs-cut/` | 23 | GIF | 与鸿蒙同源 | ⚠ 待确认 |
| `apps/android/app/src/main/assets/exercise-gifs-photo/` | 59 | GIF | 与鸿蒙同源 | ⚠ 待确认 |

**需要维护者回答的三个问题**（确认后把上面表格的 ⚠ 换成具体来源）：

1. 这批 GIF 是你自己制作/拍摄/录制的吗？
   - 是 → 在授权列写「© 2026 Earth，随本仓库以 Apache-2.0 授权」。
2. 还是来自某个素材站 / 某个 App / 某个开源数据集？
   - 素材站 → 记录站点名、许可类型（CC0 / CC-BY / 商用授权）、购买或下载凭证位置。
   - 其他 App → **必须替换**，这是最直接的风险点。
3. 是否有肖像权或品牌露出（例如画面中含他人、健身房标识、器械品牌）？
   - 有 → 需要肖像授权或打码处理。

在回答之前，建议的处理：把上面 7 个目录加入 `.gitignore`（保留本地构建可用），仓库只提交占位说明文件；确认授权后再提交素材本体。

## 二、应用图标与矢量图形

| 资源 | 来源 | 授权 |
|---|---|---|
| `rawfile/fittracker-logo-ring.svg`、`pencil-*.svg`（共 32 个，除下列 lucide 外） | 本项目自绘 | ✅ Apache-2.0（同仓库） |
| `rawfile/pencil-lucide-*.svg`（9 个） | [Lucide](https://lucide.dev) | ✅ ISC |
| `rawfile/pencil-social-wechat.svg` / `pencil-social-qq.svg` / `pencil-social-huawei.svg` | 各品牌官方标识 | ✅ 指示性使用（商标权归权利人，见 THIRD-PARTY-NOTICES.md 第五节） |
| Android App Icon（mipmap 各密度） | 本项目自绘 | ✅ Apache-2.0 |
| HarmonyOS App Icon（`AppScope/resources/base/media/`） | 本项目自绘 | ✅ Apache-2.0 |

## 三、设计过程资产（**建议不进入主仓库**）

| 目录 | 体积 | 说明 | 处置 |
|---|---|---|---|
| `design/` | 6.6 MB / 111 文件 | 含 `06_prototype_redraw/src/assets/opengym-ref/`——**第三方参考实现的资源副本**（`demo-index.js`、`demo-index.css`、`body-paths.js`、`stats.png`），版权不属于本项目 | ⚠ 移出主仓库 |
| `design-recovery/` | — | 重建过程导出物 | ⚠ 移出主仓库 |
| `docs/archive/` | 2.0 MB / 47 文件 | 历史归档、agent 状态快照 | ⚠ 移出主仓库 |

处置建议：以上三个目录迁移到独立仓库（如 `FitTracker-design`）或私有分支，主仓库仅保留 `docs/screenshots/` 中的成品截图。

## 四、法律文本

`rawfile/legal/` 与 `apps/android/app/src/main/assets/legal/` 下的隐私政策为用户协议文本，由本项目自行编写。其中联系邮箱为维护者个人邮箱，公开发布前请确认是否替换为专用邮箱。

## 五、更新规则

新增任何非代码资源时，**同一次提交**内必须在上表加入一行并填写来源与授权。
`tools/check-assets.mjs`（规划中）将校验本文件是否存在未登记的媒体文件。
