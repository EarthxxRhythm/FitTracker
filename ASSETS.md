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
| 映射表 | `apps/harmony/tools/content/exercise-photo-sources.json`（59 条，逐条核对） |
| 位置 | `rawfile/exercise-gifs-photo/`（59）、`apps/android/app/src/main/assets/exercise-gifs-photo/`（59，由 `tools/sync-exercise-gifs-to-android.mjs` 同步） |
| 署名要求 | Unlicense 不强制署名，但本项目仍在 THIRD-PARTY-NOTICES.md 登记来源 |

### 1.3 已知降级与补全路径

线稿套系覆盖的 22 个动作（深蹲、杠铃卧推、硬拉、引体向上、平板支撑等）目前**没有演示图**，
消费端 `ExerciseDemoImage` 会降级为占位图标（哑铃 SVG + 占位底色），不会报错或出现破图。

**补全方式**（需要能访问 `raw.githubusercontent.com` 或自备源 JSON）：

```bash
cd apps/harmony
node tools/content/build-exercise-gifs-photo.mjs --input ./fedb.json \
  --only squat,barbell-bench-press,barbell-row,pull-up,push-up,plank,lunge,leg-press,...
```

生成同名 `<gifId>.gif` 到 photo 目录后，`ExerciseGifCatalog` 的 23 条映射会自动复活，
无需改动任何代码（映射数据保留在 `EXERCISE_GIF_GROUPS`）。

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
