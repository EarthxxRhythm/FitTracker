# 页面证据映射

| 页面 | Pencil 节点/状态 | 几何证据 | ArkUI 实现 |
|---|---|---|---|
| Splash | `n3Xd5` | `pencil-all-pages-geometry-spec.md` | `entry/src/main/ets/features/pencil/PencilSplashPage.ets` |
| Welcome | `x8cHBq` | `pencil-welcome-geometry-spec.md` | `entry/src/main/ets/features/welcome/pages/PencilWelcomePage.ets` |
| Login | `NFOSZ` | `pencil-all-pages-geometry-spec.md` | `entry/src/main/ets/features/pencil/PencilLoginPage.ets` |
| Home | `R3xJMP` | `pencil-all-pages-geometry-spec.md` | `entry/src/main/ets/features/pencil/PencilHomePage.ets` |
| Plan | `RDOOY` | `pencil-all-pages-geometry-spec.md` | `entry/src/main/ets/features/pencil/PencilPlanPage.ets` |
| Workout Preview | `nOkrv` | `pencil-all-pages-geometry-spec.md` | `entry/src/main/ets/features/pencil/PencilPreviewPage.ets` |
| Active Workout | `LtqJz` | `pencil-all-pages-geometry-spec.md` | `entry/src/main/ets/features/pencil/PencilActivePage.ets` |
| Active Rest | `sS03p` | `pencil-all-pages-geometry-spec.md` | `PencilActivePage.ets` 的 `rest=true` 状态 |
| Review | `GuVxb` | `pencil-all-pages-geometry-spec.md` | `entry/src/main/ets/features/pencil/PencilReviewPage.ets` |
| Profile | `i15gXf` | `pencil-all-pages-geometry-spec.md` | `entry/src/main/ets/features/pencil/PencilProfilePage.ets` |
| Register | 非顶层节点 | `pencil-all-pages-geometry-spec.md` | `entry/src/main/ets/features/pencil/PencilRegisterPage.ets` |
| Workout Complete | 后续新增页面 | 现有 ArkUI 截图与代码 | `entry/src/main/ets/features/workout/pages/WorkoutCompletePage.ets` |

## 资源规则

- Lucide 图标优先使用 `entry/src/main/resources/rawfile/pencil-lucide-*.svg`。
- 底部 Tab 图标使用 `rawfile` 中对应的选中/未选中 SVG。
- 不使用系统图标、Emoji 或字体字符替代已有图标。
