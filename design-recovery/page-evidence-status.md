# FitTracker 页面证据台账

更新时间：2026-08-02

目标视口：`390 x 844`

## 证据等级

| 页面 | Pencil 画板 | 当前内容状态 | 可用证据 | 还原状态 |
|---|---|---|---|---|
| Welcome | `aPp6H` | 独立节点树 | Pencil 节点、Welcome 几何规格、资源 SVG | `VERIFIED_SOURCE` |
| Home | `S13NN` | 独立壳层，但内容可作当前实现参考 | `reference-home.jpeg`、现有 ArkUI | `SCREENSHOT_REFERENCE` |
| Plan | `vKjGl` | 内容复制自 Home | 无当前页面参考截图 | `BLOCKED` |
| Workout Preview | `GJZFt` | 内容复制自 Home | 无当前页面参考截图 | `BLOCKED` |
| Active Workout | `D7k93y` | 内容复制自 Home | `reference-active-workout.jpeg`、现有 ArkUI | `SCREENSHOT_REFERENCE` |
| Review | `f3JJyI` | 内容复制自 Home | 无当前页面参考截图 | `BLOCKED` |
| Profile | `wCt98` | 内容复制自 Home | 无当前页面参考截图 | `BLOCKED` |
| Splash | `dQDuD` | 内容复制自 Welcome | 无当前页面参考截图 | `BLOCKED` |
| Login | `ydoY0` | 内容复制自 Welcome | 无当前页面参考截图 | `BLOCKED` |
| Register | `ctrea` | 内容复制自 Welcome | 无当前页面参考截图 | `BLOCKED` |
| Workout Complete | `ym9nH` | 内容复制自 Home | `reference-workout-complete.jpeg`、现有 ArkUI | `SCREENSHOT_REFERENCE` |

## 统一几何记录要求

对于 `VERIFIED_SOURCE` 页面，逐节点记录：

- 相对父节点的 `x`、`y`、`width`、`height`
- 容器 `padding`、`gap`、布局方向、裁剪和对齐方式
- 文本字体、字号、字重、行高、字距、对齐方式和颜色
- 填充、描边、描边宽度、圆角、阴影和透明度
- 图片或 SVG 的资源路径、`objectFit`/裁剪模式
- 按父子顺序记录 z-order

对于 `SCREENSHOT_REFERENCE` 页面，截图能够确认的像素值和几何值单独登记；字体来源、节点层级或未能从截图确认的字段必须写为 `UNKNOWN`，不得推测。

对于 `BLOCKED` 页面，不修改当前视觉实现为所谓的 1:1 结果。获得原始 Pencil 节点、页面截图或明确备份后，再建立逐节点规格。

## Pencil 扫描事实

- 11 个顶层画板均为 `390 x 844`。
- `S13NN`、`vKjGl`、`GJZFt`、`D7k93y`、`f3JJyI`、`wCt98`、`ym9nH` 的内容结构出现相同 Home 卡片节点序列。
- `dQDuD`、`ydoY0`、`ctrea` 的内容结构出现相同 Welcome 节点序列。
- 这些重复结构仅用于定位恢复损坏，不可作为缺失页面的视觉证据。
- 页面不绘制手机外框、Notch、伪状态栏或设备阴影；设备系统栏不计入应用层 z-order。
