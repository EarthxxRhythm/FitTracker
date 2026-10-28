# 资源来源与授权清单

> **层级**：L2 法律合规
> **最后核对**：2026-10-28
> **状态**：已清理（原 7 个待确认目录已裁定）
> **上位文档**：THIRD-PARTY-NOTICES.md

本文件记录仓库内**非代码资源**（图片、GIF、音视频、设计稿）的来源与授权状态。

## 一、动作演示素材（2026-10-28 裁定并清理）

### 1.1 已移除：Gym Visual 线稿套系

**结论：授权链条不成立，已从仓库移除，不再分发。**

| 项 | 内容 |
|---|---|
| 版权方 | Gym Visual（© gymvisual.com），商业图库 |
| 取得途径 | 经 GitHub 数据集 `hasaneyldrm/exercises-dataset` 取得 |
| 为何不成立 | 该数据集无权转授 Gym Visual 的作品；下游再分发属于对原图库的侵权 |
| 移除范围 | 5 个目录共 115 个 GIF（见下表） |
| 移除日期 | 2026-10-28 |

| 已移除目录 | 文件数 |
|---|---|
| `apps/harmony/entry/src/main/resources/rawfile/exercise-gifs/` | 23 |
| `apps/harmony/entry/src/main/resources/rawfile/exercise-gifs-dark/` | 23 |
| `apps/harmony/entry/src/main/resources/rawfile/exercise-gifs-onpage/` | 23 |
| `apps/android/app/src/main/assets/exercise-gifs/` | 23 |
| `apps/android/app/src/main/assets/exercise-gifs-cut/` | 23 |
| 原始位置（随设计资产移出）`design/06_prototype_redraw/src/assets/exercise-gifs/` | 23 |

同时删除了两个只服务于线稿套系的派生脚本：
`build-exercise-gifs-dark.py`（深色底合成）、`build-exercise-gifs-onpage.py`（页面底色合成）。

> ⚠ **历史记录**：这批素材在 2026-05 至 2026-10 期间随公开仓库分发过，git 历史中仍有副本。
> 若权利人主张，需进一步用 `git filter-repo` 清理历史。当前处置只移除 HEAD，不再新增分发。

### 1.2 已保留：free-exercise-db 实拍套系

| 项 | 内容 |
|---|---|
| 版权/许可 | **Unlicense（公共领域）**，可自由使用、修改、再分发 |
| 来源 | `https://github.com/yuhonas/free-exercise-db` |
| 生成脚本 | `apps/harmony/tools/content/build-exercise-gifs-photo.mjs`（2 张照片 → 三段乒乓 GIF） |
| 映射表 | `apps/harmony/tools/content/exercise-photo-sources.json`（101 条，逐条核对） |
| 位置 | `rawfile/exercise-gifs-photo/`（101）、`apps/android/app/src/main/assets/exercise-gifs-photo/`（101，由 `tools/sync-exercise-gifs-to-android.mjs` 同步） |
| 署名要求 | Unlicense 不强制署名，但本项目仍在 THIRD-PARTY-NOTICES.md 登记来源 |

### 1.3 覆盖范围与唯一缺口

内容库 102 个动作，映射表登记 101 条，**101 个素材已生成且两端一致**。
唯一缺口是「鸟狗式」（`ex_bird_dog`）——free-exercise-db 经 id/name 检索零命中，
源库确实没有该动作，故不登记。其卡片与训练执行页由 `ExerciseDemoImage` 降级为
占位图标（哑铃 SVG + 占位底色），不会报错或出现破图。

`ExerciseGifCatalog` 的解析规则与 Android 端 `PhotoGifCatalog` 一致：只查实拍组，
未命中回退 `DEFAULT_EXERCISE_GIF_ID`（`barbell-deadlift`）。旧的「线稿优先」解析已停用，
否则它会截走本可用的实拍素材（`barbell-row`/`leg-curl` 等文件已随授权清理移除）。

**新增或替换素材的流程**（需要能访问 `raw.githubusercontent.com` 或自备源 JSON）：

```bash
cd apps/harmony
# 1. 在 tools/content/exercise-photo-sources.json 增加 { exerciseId, nameZh, fedbId }，逐条核对语义
# 2. 生成素材（--only 接 exerciseId）
node tools/content/build-exercise-gifs-photo.mjs --input ./fedb.json --only ex_bird_dog
# 3. 在 ExerciseGifCatalog.ets 的 EXERCISE_PHOTO_GIF_GROUPS 增加同名 gifId 条目
# 4. 同步到 Android 并重生成 PhotoGifCatalog.kt（从仓库根执行）
node tools/sync-exercise-gifs-to-android.mjs
```

数据一致性由 `tools/content/exercise-photo-sources.test.mjs` 与 ohosTest 的
`ExerciseGifCatalog.test.ets` 双重守护：映射表、素材文件、catalog 表三者必须一一对应。

## 二、应用图标与矢量图形

| 资源 | 来源 | 授权 |
|---|---|---|
| `rawfile/fittracker-logo-ring.svg`、`pencil-*.svg`（共 32 个，除下列 lucide 外） | 本项目自绘 | ✅ Apache-2.0（同仓库） |
| `rawfile/pencil-lucide-*.svg`（9 个） | [Lucide](https://lucide.dev) | ✅ ISC |
| `rawfile/pencil-social-wechat.svg` / `pencil-social-qq.svg` / `pencil-social-huawei.svg` | 各品牌官方标识 | ✅ 指示性使用（商标归权利人，见 THIRD-PARTY-NOTICES.md 第五节） |
| Android App Icon（mipmap 各密度） | 本项目自绘 | ✅ Apache-2.0 |
| HarmonyOS App Icon（`AppScope/resources/base/media/`） | 本项目自绘 | ✅ Apache-2.0 |

## 三、设计过程资产（2026-10-28 已移出主仓）

`design/` 目录共 111 个文件 / 6.6 MB，已整体移出到同级目录 `FitTracker-design/`，
并从主仓 `.gitignore` 排除。原因：

1. 其中的 `06_prototype_redraw/src/assets/opengym-ref/` 是**第三方参考实现的资源副本**
   （`demo-index.js/css`、`body-paths.js`、`stats.png`），版权不属于本项目；
2. 其余为设计过程产物（原型重绘、规格提取、核对记录），不构成对外交付物。

随之一并移出的设计工作流文档：`docs/prototype/opendesign-1to1-rules.md`、
`docs/prototype/ui-analysis-and-beautify-prompt.md`、`docs/ui/ui-final-acceptance-runbook.md`。

**依赖 `design/` 的工具会静默失效或整体跳过**，属预期：

- `apps/harmony/tools/check-auth-spacing.mjs` 及其测试（design 缺失时自动 skip）；
- `collect-screens.ps1`、`restore-accept.ps1`、`probe-css-metrics.py`、`spec-bounds-diff.py`；
- `apps/android/tools/` 下的 `render-prototype.mjs`、`proto-text.mjs`、`accept-screen.py` 等。

需要这些能力时，把 `FitTracker-design/` 放回 `design/` 即可恢复。

成品界面截图保留在主仓 `docs/screenshots/`（8 张，来源为设备实测，非设计稿）。

## 四、法律文本

`rawfile/legal/` 与 `apps/android/app/src/main/assets/legal/` 下的隐私政策为用户协议文本，由本项目自行编写。
其中联系邮箱为维护者个人邮箱，公开发布前请确认是否替换为专用邮箱。

## 五、更新规则

新增任何非代码资源时，**同一次提交**内必须在上表加入一行并填写来源与授权。
判定标准：能指出权利人或明确的开放许可（CC0 / Unlicense / CC-BY / Apache / MIT / OFL / ISC）。
"从网上找的""从某数据集拿的"都不构成授权依据——必须能追到权利人本人或其授权渠道。
