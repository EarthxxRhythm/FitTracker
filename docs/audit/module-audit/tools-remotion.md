# tools / apps-harmony-tools / remotion · 分区边界 / 重复实现审计台账

- 任务：`team:audit-tools-remotion`（只读审计，**未修改任何源码**）
- 审计对象（三域，实测清单见 §1）：
  - `tools\`（排除 `tools\loop\`，`.gitignore:197` 排除的 agent 资产）—— 13 个 `.mjs`
  - `apps\harmony\tools\`（递归，含 `cloud-debug\`、`content\`、`content\3d\`，排除 `node_modules`）—— 46 个 `.mjs`
  - `remotion\src\` 全部 `.ts`/`.tsx` —— 5 个文件（另含 4 个工程配置文件，见 §1.3）
- 生成时间：2026-11（worktree HEAD = `23abd74`）
- 台账用途：模块化重构的唯一依据。所有条目均附 file:line 与可复现命令。
- 只读自证：`git status --short` 全程仅 ` M apps/harmony/build-profile.json5`（用户既有改动）+ `?? docs/audit/`（本台账目录）。未执行任何仓库内脚本（`check-gates` 的第一步 `build-content.mjs` 会 `writeFileSync` 生成物，属源码写操作，故本轮不跑，见 §C9 说明）。

---

## 0. 口径声明

| 记号 | 含义 |
|---|---|
| `N 文件` | 离散文件个数（`find`/`readdir` 实测） |
| `N 处` | 离散引用点个数（一次 import / 一次 `writeFileSync` / 一次字面量出现） |

「门禁接线」一律指**三种真实执行路径之一**，不混用：

1. `apps/harmony/tools/check-gates.mjs` 的 steps 数组（`.github/workflows/gates.yml:29` 在 CI 跑 `--skip-build`）
2. `.rivet-config.json:7` 声明的 `verify.test` = `node tools/run-tests.mjs`
3. `.github/workflows/gates.yml:33,36` 的 `node --test "tools/*.test.mjs"`（两个 cwd 各一次）

### 0.1 复现命令（全部已在本 worktree 执行）

```bash
# 文件清单（三域）
find tools -maxdepth 1 -type f | sort                                   # → 13
find apps/harmony/tools -name '*.mjs' -not -path '*node_modules*' | sort # → 46
find remotion/src -name '*.ts' -o -name '*.tsx' | sort                   # → 5

# 规模
wc -l tools/*.mjs | tail -1                                             # → 2615
wc -l $(find apps/harmony/tools -name '*.mjs') | tail -1                # → 11391
wc -l remotion/src/*.ts remotion/src/*.tsx remotion/src/components/*.tsx # → 430

# 门禁接线矩阵（逐脚本反查调用方，排除 .rivet/、test_run/、package-lock）
for s in <脚本名>; do grep -rn "$s\.mjs" --include=*.mjs --include=*.json \
  --include=*.yml --include=*.ps1 --include=*.md . | grep -v node_modules \
  | grep -v "^./.rivet/" | grep -v "^./test_run/"; done

# 测试覆盖（node -e 脚本，纯读，无落盘探针）
#   SCOPE mjs: 59 (root 13 / harmony 46)  impl: 34  test: 25
#   run-tests 覆盖 test: 13   未覆盖: 12
#   CI 覆盖 test: 16          未覆盖: 9
```

### 0.2 file:line 漂移抽验（回应计划暂缓项「台账完成判据缺可验证 gate」）

**采纳**，但不新增脚本（本轮不修改源码），以台账内命令交付。凡本台账引用的 `file:line`，可用下面一条命令回归抽验（任一行输出为空即为已漂移）：

```bash
cd "$(git rev-parse --show-toplevel)"
for a in \
  "apps/harmony/tools/check-gates.mjs:81:const steps = \[" \
  "apps/harmony/tools/check-gates.mjs:131:content gif regression" \
  "tools/device-smoke.mjs:224:process.exit(1)" \
  "tools/check-content-parity.mjs:102:function isAligned" \
  "tools/check-content-parity.mjs:122:ubuntu@106.55.37.80" \
  "apps/harmony/tools/content/export-db-seed.mjs:39:sync-content-to-android" \
  "remotion/src/Root.tsx:9:durationInFrames=\{1890\}" \
  "remotion/src/LoopTutorial.tsx:6:const FPS = 30" ; do
  IFS=':' read -r f l pat <<< "$a"
  sed -n "${l}p" "$f" | grep -q -- "$pat" && echo "OK   $f:$l" || echo "DRIFT $f:$l"
done
```

本台账生成时上述 8 个锚点实测全部 `OK`。

---

## 1. 文件清单（三域，以实测为准）

### 1.1 `tools\`（根，13 文件 / 2615 行；`tools\loop\` 10 文件不计入）

| 文件 | 行数 | 门禁接线（实测） |
|---|---|---|
| `build-site.mjs` | 392 | `web\package.json:12,13,14`（`legal` / `prebuild` / `predev`）—— 唯一被 npm 脚本化的根工具 |
| `check-site.mjs` | 147 | **无**（仅被自身 test 引用） |
| `check-site.test.mjs` | 82 | 仅 CI 顶层 glob |
| `check-content-parity.mjs` | 154 | **无**（仅被自身 test 引用） |
| `check-content-parity.test.mjs` | 70 | 仅 CI 顶层 glob（不在 `run-tests`） |
| `check-snapshot-mirror-sql.test.mjs` | 210 | 仅 CI 顶层 glob；**无同名 impl**（纯 test） |
| `device-smoke.mjs` | 236 | 人工 CLI；另被 `tools\loop\verify.test.mjs`、`loop\agents\test\agent.json` 引用（agent 资产，不入库） |
| `rotate-credential.mjs` | 202 | 人工 CLI（`docs\security\credential-rotation.md:77,105`） |
| `run-tests.mjs` | 78 | `.rivet-config.json:7`（声明 verify 唯一入口） |
| `serve-site.mjs` | 119 | 人工 CLI（仅文档提及） |
| `sync-content-to-android.mjs` | 384 | 被 `apps\harmony\tools\content\export-db-seed.mjs:39` **import**（跨根） |
| `sync-content-to-android.test.mjs` | 309 | `run-tests` + CI |
| `sync-exercise-gifs-to-android.mjs` | 232 | 人工 CLI（仅文档/`ASSETS.md` 提及） |

### 1.2 `apps\harmony\tools\`（递归 46 文件 / 11391 行）

**门禁类（10）**

| 文件 | 行数 | 接线 |
|---|---|---|
| `check-gates.mjs` | 200 | CI（`gates.yml:29`）；steps 数组 `:81` 起 9 步 |
| `check-main-pages.mjs` | 45 | `check-gates` 第 2 步 |
| `check-dead-refs.mjs` | 194 | `check-gates` 第 4 步 |
| `check-specs.mjs` | 295 | `check-gates` 第 5 步 |
| `check-glossary.mjs` | 356 | `check-gates` 第 6 步 |
| `check-parity.mjs` | 260 | `check-gates` 第 7 步 |
| `check-code-rules.mjs` | 403 | `check-gates` 第 8 步 |
| `check-icon-assets.mjs` | 197 | **不在 check-gates**；仅自身 test 经 CI 执行（见 C2） |
| `check-closeout-evidence.mjs` | 288 | **无任何 gate/CI 接线**（见 C3） |
| `check-auth-spacing.mjs` | 266 | 无 CLI，纯函数库；经 test 对真实源码断言（见 C4） |
| `check-release-readiness.mjs` | 481 | 人工 CLI（`README.md`、`docs\release\release-build-runbook.md`、`loop\agents\release\`） |

**内容流水线（`content\`，14 文件含数据资产）**

| 文件 | 行数 | 接线 |
|---|---|---|
| `build-content.mjs` | 472 | `check-gates` 第 1 步（**会写** `entry\src\main\ets\generated\*.ets`，`:446`+`mkdirSync`） |
| `export-db-seed.mjs` | 285 | 人工 CLI；`check-parity`/`check-content-parity` 读其产物 |
| `import-external-source.mjs` | 456 | 人工 CLI |
| `merge-candidates.mjs` | 238 | 人工 CLI |
| `build-exercise-gifs-photo.mjs` | 370 | 人工 CLI（`check-gates` 第 9 步只跑其 **test**） |
| `build-exercise-gifs-3d.mjs` | 101 | 人工 CLI（同上，只跑 test） |
| `3d\engine.mjs` | 274 | 被 `build-exercise-gifs-3d.mjs` import |
| `3d\gif-decode.mjs` | 249 | 被上述两者 import |
| `3d\poses.json` | — | **数据资产**（非代码） |
| `exercise-photo-sources.json` | — | **数据资产**（非代码） |
| 7 个 `.test.mjs`（`build-content` / `build-exercise-gifs-3d` / `build-exercise-gifs-photo` / `exercise-photo-sources` / `export-db-seed` / `import-external-source` / `merge-candidates`） | 118/182/203/272/208/251/214 | 3 个在 `run-tests` 与 `check-gates`；7 个**不在 CI**（见 D2） |

**设备执行层与发布/法务工具**

| 文件 | 行数 | 接线 |
|---|---|---|
| `harmony-device.mjs` | 973 | 被 `tools\device-smoke.mjs:80` 动态 import + 自身 CLI |
| `cloud-debug\cdp.mjs` | 352 | 人工 CLI；test 不在 CI（见 D2） |
| `convert-legal-docs.mjs` | 50 | 人工 CLI（**无 import 守卫**，见 E6） |
| `make-copyright-source.mjs` | 201 | 被 `make-copyright-pdf.mjs` import |
| `make-copyright-doc.mjs` | 168 | 被 `make-copyright-pdf.mjs` import |
| `make-copyright-pdf.mjs` | 384 | 人工 CLI（`docs\release\software-copyright-form.md`） |
| 3 个 `.test.mjs` | 160/98/154 | `check-auth-spacing` / `make-copyright-pdf` / `make-copyright` |

> 46 个 `.mjs` 的完整逐文件清单（含行号）已在本节全量覆盖，无省略。

### 1.3 `remotion\`（5 源码 + 4 工程文件）

| 文件 | 行数 | 说明 |
|---|---|---|
| `remotion\src\index.ts` | 4 | `registerRoot(Root)` |
| `remotion\src\Root.tsx` | 15 | 单个 Composition `LoopTutorial`：`durationInFrames={1890}` (`:9`) / `fps={30}` (`:10`) |
| `remotion\src\LoopTutorial.tsx` | 218 | 8 个场景讲解 `tools\loop\` 六环流程（`:20` `SCENES`） |
| `remotion\src\components\RingBar.tsx` | 81 | 环状态条 |
| `remotion\src\components\Terminal.tsx` | 112 | 终端模拟 |
| `remotion\remotion.config.ts` | 3 | jpeg / overwrite |
| `remotion\tsconfig.json` | 14 | `strict: true`，`include: ["src"]` |
| `remotion\package.json` | 24 | `typecheck` 脚本无调用方（`F1`） |
| `remotion\package-lock.json` | 148747 B | 入库 |

---

## A. 分区边界

| ID | 问题类型 | 影响面 | 优先级 | file:line 依据 | 证据 / 结论 |
|---|---|---|---|---|---|
| A1 | **双根工具目录无成文归属判据，依赖方向双向发散** | 任何新增脚本的落位、跨根 import 的可维护性 | **P0** | 根→子：`tools\device-smoke.mjs:47`（import `apps/android/tools/android-device.mjs`）、`:80`（import `apps/harmony/tools/harmony-device.mjs`）、`tools\run-tests.mjs:21-63`（三处 cwd）；子→根：`apps\harmony\tools\content\export-db-seed.mjs:39`（`import ... from '../../../../tools/sync-content-to-android.mjs'`） | 根 `tools\` 同时扮演三种角色：①仓库级通用工具（`rotate-credential`/`build-site`/`run-tests`）②鸿蒙工程入口的跨端冒烟（`device-smoke`）③被鸿蒙内容流水线反向依赖的库（`sync-content-to-android` 只导出 `NAME_EN_FALLBACK`/`loadPreservedNameEn` 两个符号，`:39` 是库用法而非 CLI 用法）。没有任何文档规定「什么脚本放根、什么放子工程」，`docs\process\engineering-constraints.md` 里 `tools` 相关条目为 0（grep 实测）。重构前必须先立判据，否则同一条新脚本可以有三种「合法」落位。 |
| A2 | 工具目录混放数据资产 | 素材流水线数据变更无 diff 校验、审计口径混淆 | P1 | `apps\harmony\tools\content\exercise-photo-sources.json`、`apps\harmony\tools\content\3d\poses.json` | `content\` 既是代码目录又是数据目录：两个 JSON 是 3 条素材产线的输入（`build-exercise-gifs-photo.mjs` / `build-exercise-gifs-3d.mjs` 读取），只有 `.test.mjs` 用断言兜底（`exercise-photo-sources.test.mjs` 272 行、`build-exercise-gifs-3d.test.mjs` 182 行），无 schema 文件、无 gate。数据文件与代码同目录的后果：`.mjs` 审计（本次）与「资产审计」边界重叠，且 JSON 变更不进任何门禁。 |
| A3 | 仓库级工具寄居在鸿蒙工程目录 | 发布/法务流程的归属、Android 侧对等工具无从对照 | P1 | `apps\harmony\tools\make-copyright-source.mjs`(201)、`make-copyright-doc.mjs`(168)、`make-copyright-pdf.mjs`(384)、`convert-legal-docs.mjs`(50) | 三者操作的对象在**仓库级**：`make-copyright-source.mjs` 扫描全仓源码生成著作权源程序文档（`docs\release\software-copyright-form.md` 是唯一调用记录），`convert-legal-docs.mjs` 从根 `docs\legal\*.md` 生成 `entry/.../rawfile/legal/*.txt`。放在 `apps\harmony\tools\` 的后果：`check-gates` 的 cwd 约定（`cd apps\harmony`）成为这些脚本的隐含前提，从根执行时需要额外注意 cwd（`convert-legal-docs.mjs:16` 的注释即为 2026-10-27 因 monorepo 重组而做的 cwd 修正，历史已踩过一次）。 |
| A4 | server 域契约测试落在根 tools，且无 impl | 契约漂移检测的归属、锚点漂移无 gate | P1 | `tools\check-snapshot-mirror-sql.test.mjs:1-22` | 212 行纯 test：读 `server/supabase/migrations/20261101000001_snapshot_mirror.sql`（`:26`）+ Android `TrainingModels.kt` / `PlanModels.kt` / `BodyRecord.kt` + 鸿蒙 `export-db-seed.mjs` 的 `EXERCISE_COLUMNS`，**横跨 server / android / harmony 三域**，是根 tools 里唯一「无 impl 的 test」。锚点写法是硬行号（`:10-16`：`TrainingModels.kt:130-146`、`:115-124`）——本轮实测两个锚点**当前有效**（`TrainingModels.kt:130` = `data class WorkoutSession(`，`:115` = `data class WorkoutSet(`），但行号锚一旦漂移即是**静默失效**（断言仍在跑，契约已指向别处）。 |
| A5 | `remotion\` 是 agent 流程演示工程，描述对象不入库；同时产品 web 又依赖同一技术栈 | 仓库边界（产品 vs agent 资产）、依赖版本双轨 | P1 | `remotion\src\LoopTutorial.tsx:20-40`（场景命令为 `node tools/loop/state.mjs ...`、`node tools/loop/verify.mjs ...`）；`.gitignore:197`（`/tools/loop/`）；`.gitignore:196`（`/loop/`）；产品侧：`web\src\journey\JourneyFilm.tsx:20`（`import { Player } from '@remotion/player'`） | `remotion\` 的 8 个场景逐条演示 `tools\loop\` 的命令输出，而 `tools\loop\`（10 文件）被 `.gitignore:197` 排除 —— **被描述的对象不在仓库里**，视频内容与真实实现无法交叉核对，也没有任何门禁。与此同时 web 产品站用 `@remotion/player` 播放旅程影片：`remotion\package.json:12,15` 钉死 `4.0.515`，`web\package.json:21,25` 用 `^4.0.539` —— 两套独立 `node_modules`、两个版本，同一技术栈双轨。 |

---

## B. 重复实现

| ID | 问题类型 | 影响面 | 优先级 | file:line 依据 | 证据 / 结论 |
|---|---|---|---|---|---|
| B1 | `main_pages.json` 解析器两份、归一化规则不同 | 页面注册类门禁的一致性 | P1 | `apps\harmony\tools\check-main-pages.mjs:13-23`（`readMainPages`，`JSON.parse` 后**不做**分隔符归一）；`apps\harmony\tools\check-code-rules.mjs:135-141`（`parseMainPages`，`String(page).replace(/\\/g, '/')`） | 职责是互补的（前者验「注册页文件存在 + 每页恰好一个 `@Entry`」，后者 RT-01 验「注册页 ↔ `AppRoutes` 常量双向一致」），**不是**同一个检查的两份实现——但解析同一份 JSON 的逻辑重复且归一化策略不一致：Windows 风格反斜杠路径在 `check-main-pages.mjs:32` 会被 `resolve()` 吸收（碰巧正确），在 `check-code-rules` 侧被显式归一。新增第三种读取者前应收敛成一个解析器。 |
| B2 | 目录遍历 / `.ets` 收集自实现 8 处，无共享 util | 每个门禁的遍历口径各自演化 | P2 | `check-closeout-evidence.mjs`、`check-code-rules.mjs:78-97`（`collectEtsFiles`）、`check-dead-refs.mjs`、`check-glossary.mjs`、`check-icon-assets.mjs`、`check-parity.mjs`、`check-release-readiness.mjs`、`harmony-device.mjs`（`grep -rln readdirSync` 实测 8 个文件） | 8 个门禁各自实现 `readdirSync` 递归，跳过目录集合各不相同（例：`check-dead-refs.mjs:68-70` 的 `SKIP_DIR_NAMES` 含 `archive`/`scripts`/`cluster`，`check-code-rules.mjs:78` 的 `collectEtsFiles` 不跳过任何目录但只收 `.ets`）。同一文件可能被 A 门禁扫、被 B 门禁漏，且漏扫无法从任一门禁内部察觉。 |
| B3 | `check-content-parity` 与 `check-parity` 近名异义 | 调用方误用、文档引用歧义 | P2 | `tools\check-content-parity.mjs:1-2`（「动作内容库三处计数对账 jsonl ↔ Android 资产 ↔ seed SQL」）；`apps\harmony\tools\check-parity.mjs:17-20`（「双端对等清单 ↔ 代码」） | 两个不同根的脚本共用 `check-*-parity` 命名族：前者是**内容计数**对账，后者是**功能/身份对等**。`docs\process\dual-platform-parity.md` 只描述后者，根目录的 `check-content-parity` 无对应文档章节；`CONTRIBUTING.md` 提到 `check-parity` 时未限定根，存在指代歧义。 |
| B4 | 两条「鸿蒙权威源 → Android 产物」同步线，无共享写入器 | 素材/内容同步的失败模式重复实现 | P2 | `tools\sync-content-to-android.mjs`(384) 与 `tools\sync-exercise-gifs-to-android.mjs`(232) | 两者同构（读鸿蒙源 → 生成 Android 侧文件 → 打印对照），但产物形态不同（前者生 JSON 资产 + Kotlin 映射，后者生 GIF 文件 + `ExerciseGifCatalog` 映射），且**后者的权威源是 `ExerciseGifCatalog.ets` 的 `EXERCISE_PHOTO_GIF_GROUPS`**（`sync-exercise-gifs-to-android.mjs:10-12` 注释）。前者有 309 行 test 且接线 `run-tests`，后者**零接线、零 test**（`D1`）——同构的两条线测试纪律差一档。 |

---

## C. 门禁接线矩阵（本域最集中的问题区）

| ID | 问题类型 | 影响面 | 优先级 | file:line 依据 | 证据 / 结论 |
|---|---|---|---|---|---|
| C1 | **CI 步骤名与实际步数不符（八条 vs 9 步）** | 门禁清单的对外宣称 | P1 | `.github/workflows/gates.yml:27`（`name: 八条门禁（内容构建 / 页面注册 / 空白 / 死链 / 规范注册表 / 术语口径 / 双端对等 / 代码规则）`）；`apps\harmony\tools\check-gates.mjs:81-139`（steps 数组实测 **9** 项，第 9 项 `:131` 为 `content gif regression`） | 名称列了 8 条，实际跑 9 条（多出「内容 gif 回归」）；之后还追加 ArkTS 编译（`:155` 起，`--skip-build` 时跳过）。读者据步骤名核对门禁覆盖会漏掉第 9 步。 |
| C2 | **图标口径门禁从未以门禁形态执行** | `check-icon-assets` 的全部判据实际上只活在单测里 | **P0** | `apps\harmony\tools\check-icon-assets.mjs:188`（`process.exit(result.issues.length === 0 ? 0 : 1)`）——有完整 CLI 与退出码；`check-gates.mjs:81-139` 的 9 步中无它；全仓 `grep check-icon-assets.mjs` 仅命中自身 test 与 `check-dead-refs.mjs` 的一处文字 | 该脚本检查「图标资产 ↔ `.ets` 字面量引用」双向（`:81-120`，`ALLOWLIST` 为空数组 `:45`）。它**不在** `check-gates` 的 steps 里，CI 也不直接调用 → 「图标未被任何 ets 引用」这类问题只能靠 `check-icon-assets.test.mjs`（经 CI 顶层 glob 执行）用 fixture 证明逻辑正确，**真实仓库的图标现状从未被检查过**。这是本次审计最直接的「门禁存在但不生效」。 |
| C3 | **合入证据门禁零接线** | 结项/收口证据链无自动校验 | P1 | `apps\harmony\tools\check-closeout-evidence.mjs:159`（`process.exit(2)` 用法错）、`:285`（`process.exit(overallPass ? 0 : 1)`）；反查调用方仅 `docs\closeout\*.md`、`docs\blockers.md`、`docs\archive\...` | 288 行、完整 CLI + 退出码，但 `check-gates`、`run-tests`、CI 三处均不引用。属「文档说要去跑、没人跑」的门禁。 |
| C4 | `check-auth-spacing` 形态例外且文档失真 | 认证屏间距纪律的执行路径不明 | P2 | `apps\harmony\tools\check-auth-spacing.mjs`（266 行：**无** `process.argv`、无 `existsSync`、无 `main`，末尾 `:266` 直接结束在 `evaluateRegisterSpacing` 的返回值）；`check-auth-spacing.test.mjs:57-67`（test 侧 `readFileSync` 真实 `.ets` 与原型 HTML 后断言）；`ASSETS.md:144`（「`check-auth-spacing.mjs` 及其测试（design 缺失时自动 skip）」） | 断言**有效**（test 读真实源码，CI 顶层 glob 覆盖），所以不是死代码；但 ①它是 10 个「check-*」里唯一没有 CLI 的，形态与其余 9 个不一致；②`ASSETS.md:144` 宣称的「design 缺失时自动 skip」在模块内不存在（无 `existsSync`、无 skip 分支）——文档描述的是测试 fixture 缺失时的行为，不是脚本行为。 |
| C5 | **官网静态门禁零接线** | site/ 的六条检查（lang/title/description、本地链接、站内互链、占位标记、零第三方资源、img alt+尺寸）从不执行 | P1 | `tools\check-site.mjs:1-14`（六条检查声明）+ `:137`（`process.exit(1)`）；反查调用方：仅 `tools\check-site.test.mjs`；无 npm script、无 CI 步骤、无 `check-gates` 引用 | `web\package.json` 的 `build`/`prebuild` 只跑 `legal`（`build-site.mjs`），不跑 `check-site`。CI 的 `gates.yml` 只覆盖鸿蒙工程。→ 官网 6 条规则在 CI 中**完全不存在**，只在本地手工 `node tools/check-site.mjs` 时生效。 |
| C6 | **内容计数对账零接线** | 「jsonl ↔ Android 资产 ↔ seed SQL」三处漂移（2026-10-16 曾真实发生 102 vs 50）无自动守护 | **P0** | `tools\check-content-parity.mjs:1-16`（脚本头即写明「任一可比的数字不一致 → exit 1（对账红线；2026-10-16 曾发生鸿蒙 102 vs Android 50 漂移）」）；反查调用方：仅 `tools\check-content-parity.test.mjs`，而该 test **也不在** `run-tests.mjs`（实测未覆盖 12 项之一） | 唯一守护过内容库计数漂移的脚本，现在同时缺席 `run-tests`、`check-gates`、CI 直调；它只在 CI 的 `node --test "tools/*.test.mjs"` 里以 **test** 形态跑（而 test 用 fixture，不读真实 jsonl/android 资产，见 `:21-27` 的纯函数导出）。→ 真实数据漂移目前**无人守**。 |
| C7 | **`device-smoke` 的 SKIP 退出码与自述矛盾** | 自动化把「设备没起」当「双端验过」 | **P0** | `tools\device-smoke.mjs:6`（`// SKIP 绝不等同于 PASS：设备没启动却算通过，会让"双端都验过"变成假账。`）、`:224`（`process.exit(1)` 只在 `failed.length > 0` 时触发）、`:226-229`（SKIP 分支只 `console.log`，落回自然退出 0） | 自述的反面被自己的退出码实现：两端全 SKIP 时进程退出码 **0**。`loop/agents/test/agent.json` 与 `tools/loop/verify.test.mjs`（agent 侧门禁）以它为依据——只看退出码的调用方会把「未验证」记成「通过」。修法二选一并写清语义：SKIP→非零退出，或新增 `--strict`（SKIP 视为 FAIL）。 |
| C8 | 人工入口未在台账/文档中区分 | 误把人工脚本当门禁 | P2 | `tools\rotate-credential.mjs`、`tools\serve-site.mjs`、`tools\sync-exercise-gifs-to-android.mjs`、`apps\harmony\tools\check-release-readiness.mjs`、`make-copyright-*.mjs`、`convert-legal-docs.mjs` | 7 个脚本为**人工入口**（反查调用方仅有文档/README 文本，无脚本/CI/npm script 引用）。本身合理，但没有任何清单标注「这些不是门禁」，与 C2/C3/C5/C6 的「看起来是门禁其实没接」混在同一个 `check-*` 命名空间里，是本域最主要的认知负荷来源。 |
| C9 | 声明 verify 与 CI 覆盖面不一致 | 「本地单命令验证」不等于「CI 验证」 | P1 | `.rivet-config.json:7`（`"test": "node tools/run-tests.mjs"`）；`tools\run-tests.mjs:18-63`（4 个 group、**13** 个文件）；`gates.yml:33,36`（`node --test "tools/*.test.mjs"`，覆盖 **16** 个） | 实测：25 个 test 文件中，`run-tests.mjs` 覆盖 13（缺 12），CI 覆盖 16（缺 9，全在 `content\`/`cloud-debug\` 子目录）。两者交集之外各有独有部分 → 本地全绿不能推出 CI 全绿，反之亦然。 |

---

## D. 测试覆盖矩阵

| ID | 问题类型 | 影响面 | 优先级 | file:line 依据 | 证据 / 结论 |
|---|---|---|---|---|---|
| D1 | **13 个 impl 无任何 test** | 其中 3 个是高后果脚本 | P1 | 实测清单：`tools\build-site.mjs`(392)、`tools\device-smoke.mjs`(236)、`tools\rotate-credential.mjs`(202)、`tools\run-tests.mjs`(78)、`tools\serve-site.mjs`(119)、`tools\sync-exercise-gifs-to-android.mjs`(232)、`apps\harmony\tools\check-closeout-evidence.mjs`(288)、`check-main-pages.mjs`(45)、`content\3d\engine.mjs`(274)、`content\3d\gif-decode.mjs`(249)、`convert-legal-docs.mjs`(50)、`make-copyright-source.mjs`(201)、`make-copyright-doc.mjs`(168) | 三点尤其值得注意：①`device-smoke.mjs` 的 flag 解析曾有过真实缺陷并在注释里留档（`:203-206`「旧实现一律写 true，导致 `--harmony-wait 180` 被算成 `Number(true) === 1`」）——**修了 bug 但没留回归测试**，同类退化无护栏；②`rotate-credential.mjs` 是写 `server\deploy\thirdparty.env` 并扫描全仓残留的安全工具（`:36-40` 白名单、`:87-118` 残留扫描），零单测；③`build-site.mjs` 生成对外法务页并发布到 `web\public\legal`，其产物漂移已被 `docs\audit\module-audit\web-site.md` A5 记录为实际发生（`site\privacy.html` 15203 B ≠ `web\public\legal\privacy.html` 15224 B）。 |
| D2 | **9 个子目录测试从不进 CI** | 内容流水线（7）与 cloud-debug（2）的回归只在本地 | P1 | `.github/workflows/gates.yml:33,36`（`node --test "tools/*.test.mjs"`，glob 不含子目录）；实测未覆盖清单：`cloud-debug\cdp.test.mjs`、`cloud-debug\inject-net-retry.test.mjs`、`content\build-content.test.mjs`、`content\build-exercise-gifs-3d.test.mjs`、`content\build-exercise-gifs-photo.test.mjs`、`content\exercise-photo-sources.test.mjs`、`content\export-db-seed.test.mjs`、`content\import-external-source.test.mjs`、`content\merge-candidates.test.mjs` | 其中 3 个（gifs 双线 + photo-sources）被 `check-gates.mjs:131-136` 作为第 9 步**显式点名运行**，而 `check-gates` 在 CI 里跑 `--skip-build` —— **这 3 个其实是进了 CI 的**（`gates.yml:29`）；但 `check-gates` 一旦因前面 8 步任一失败就抛错（`:142`），第 9 步不会执行。真正从不进 CI 的是：`cloud-debug\*`（2）、`content\build-content`、`content\export-db-seed`、`content\import-external-source`、`content\merge-candidates`（4）。 |
| D3 | 测试与实现的配对命名无守护 | 新增 impl 是否必须带 test 无从判断 | P2 | 命名约定为 `X.mjs` ↔ `X.test.mjs`（23 组符合），例外 3 个：`tools\check-snapshot-mirror-sql.test.mjs`（无 impl）、`content\exercise-photo-sources.test.mjs`（对应数据文件 `exercise-photo-sources.json` 而非 impl）、`check-auth-spacing.mjs`（test 存在但模块无 CLI） | 无任何门禁校验「impl ↔ test 配对」，也没有 `EXEMPT` 清单说明哪些 impl 允许无菌（`D1` 的 13 个都是既成事实）。 |

---

## E. 魔法值 / 硬编码 / 声明-实现漂移

| ID | 问题类型 | 影响面 | 优先级 | file:line 依据 | 证据 / 结论 |
|---|---|---|---|---|---|
| E1 | **硬编码 SSH 目标 + 「远程对账」只打印不判定** | 云端计数与本地漂移无法被发现 | P1 | `tools\check-content-parity.mjs:115`（`// ssh 到自托管服务器（106.55.37.80）对 public 三表 COUNT。`）、`:122`（`'ubuntu@106.55.37.80'`）、`:123`（`docker exec -i supabase-db psql -U postgres -d postgres`）、`:148`（`console.log('云端计数：\n' + result.stdout)`） | 两个问题叠加：①主机 IP、SSH 用户名、容器名、数据库名全部硬编码（`:122-123`），换机/改容器名即失效且无提示；②`--remote` 分支拿到云端计数后**只打印**，从不与 `counts.jsonl` 比较，也不置 `exitCode` —— 参数名为 `--remote`（对账），行为是「打印云端的数」。用户看到「云端计数：…」会当成对账已过。 |
| E2 | 注释承诺 id 级对账，实现只比计数 | 计数相等但 id 集合不同时误判为对齐 | P1 | `tools\check-content-parity.mjs:7`（`// 计数口径（三处各自计数，同一批 id 才算对齐）：`）、`:39-48`（`countJsonlRows` 仅统计非空行数，注释明说「行内容不解析」）、`:102-112`（`isAligned` 只比 `jsonl[table] !== android[table]`） | 「同一批 id 才算对齐」在实现里不存在：删一条 + 加一条会让计数不变而对账通过。三处（jsonl / Android 资产 / seed SQL）**都没有** id 集合比较。 |
| E3 | 错误修复指令在调用 cwd 下不可执行 | 用户按提示修复会失败 | P2 | `apps\harmony\tools\content\export-db-seed.mjs:159`（`throw new Error(\`nameEn missing for ${id}; run node tools/sync-content-to-android.mjs first\`)`） | 该脚本位于 `apps\harmony\tools\content\`，而鸿蒙门禁统一以 `cwd=apps\harmony` 运行（`gates.yml:28`、`.rivet.md` 的验证命令）。此时 `tools/sync-content-to-android.mjs` 解析到 `apps\harmony\tools\...`（不存在）。正确提示应为仓库根相对路径或 `cd <repoRoot> && node tools/...`。 |
| E4 | `FPS` 常量声明后从未使用 | 修改 fps 时只改一处会静默失配 | P2 | `remotion\src\LoopTutorial.tsx:6`（`const FPS = 30;`）、`remotion\src\Root.tsx:10`（`fps={30}`） | `grep -n "FPS" remotion/src/LoopTutorial.tsx` 仅命中第 6 行（定义），无任何读取点 → 死常量；真实 fps 硬编码在 `Root.tsx:10`。 |
| E5 | `durationInFrames` 是手算副本 | 增删场景后时长静默失配 | P2 | `remotion\src\Root.tsx:9`（`durationInFrames={1890}`）、`remotion\src\LoopTutorial.tsx:7-9`（`INTRO_FRAMES=90` / `SCENE_FRAMES=150` / `OUTRO_FRAMES=600`）、`:20`（`SCENES` 8 项）、`:145`（`SCENES.length * SCENE_FRAMES` 的动态计算） | 1890 = 90 + 8×150 + 600，是常量组合的手算结果且**跨文件**：退出后的尾部动画在 `LoopTutorial.tsx:145` 用 `SCENES.length` 动态算，而 Composition 的时长写死在 `Root.tsx:9`。加一个场景 → `LoopTutorial` 的尾部时间轴后移、Composition 提前截断，且无 typecheck/测试能发现（见 F1）。 |
| E6 | `convert-legal-docs.mjs` 无 import 守卫、顶层即写盘 | 被 import 时产生非预期文件写入（目前潜伏） | P2 | `apps\harmony\tools\convert-legal-docs.mjs:16-50`（无 `isDirectRun`/`import.meta` 主守卫，末尾 `:50` 直接 `process.stdout.write('convert done\n')`；文件中部 `writeFileSync(dst, ...)`） | 对比：`check-code-rules`/`check-dead-refs`/`check-gates`/`check-glossary`/`check-icon-assets`/`check-parity`/`check-specs`/`harmony-device`/`build-site`/`check-site`/`sync-content-to-android`/`sync-exercise-gifs-to-android` 共 12 个脚本都有 `isDirectRun` 守卫（`grep -ln isDirectRun` 实测）。`convert-legal-docs.mjs` 是唯一「顶层有写文件副作用却无守卫」的工具；当前无人 import，故为潜伏风险。 |

---

## F. remotion 专节（三域技术栈异构的处置）

| ID | 问题类型 | 影响面 | 优先级 | file:line 依据 | 证据 / 结论 |
|---|---|---|---|---|---|
| F1 | **`strict` 编译从未被执行** | TSX 的类型错误只能靠人工发现 | P1 | `remotion\package.json:9`（`"typecheck": "tsc --noEmit"`）、`remotion\tsconfig.json:13`（`"include": ["src"]`）、`strict: true` | 全仓 `grep -rn "remotion" .rivet-config.json apps/harmony/tools/*.mjs tools/*.mjs` → 0 命中；CI 两个 workflow 均不涉及 remotion。`typecheck` 脚本**无任何调用方**（含 `prebuild`/`predev`）→ `strict: true` 只是一份声明。 |
| F2 | 依赖树记录在 lock 文件，产物无发布口径 | 复现性与产物流向 | P2 | `remotion\.gitignore:1-2`（`node_modules/`、`out/`）、`remotion\package-lock.json`（148747 B，入库）、工作区存在 `remotion\out\loop-tutorial.mp4` | 依赖版本只有 `package-lock.json` 一个事实源（`package.json` 为精确版本 `4.0.515`，尚可），`out/loop-tutorial.mp4` 在工作区但被忽略且**全仓无引用**——谁消费这个 mp4、放在哪里、是否已过期，无任何记录。 |
| F3 | 三域异构导致「门禁」不可套用同一模板 | 重构时的统一化期望管理 | P2 | 域间形态差异实测：根/鸿蒙两域是 `.mjs` + `node --test`（零第三方依赖，`package.json` 在仓库根**不存在**）；`remotion\` 是独立 npm 工程（React 18 + remotion 4.0.515），`web\` 又是另一个（vite + `@remotion/player` ^4.0.539） | **采纳**计划暂缓项的技术栈异构 challenge：台账据此按域给判据，不强行统一——`.mjs` 域可要求「impl ↔ test 配对 + 接线三选一」，`remotion\` 域只能要求「`typecheck` 进 CI + 时长常量化」这一档。若后续要统一门禁外壳，需先决定 remotion 是并入 `web\` 的 npm 工作区还是维持独立工程。 |

---

## G. 待决与移交（回应计划暂缓项，逐条有着落）

| 暂缓项 | 处置 | 说明 |
|---|---|---|
| 三域台账「已落盘入库可复核」与 git 现状冲突（`docs\audit\` 整目录 untracked） | **采纳**，需主会话统一提交 | 本工单为 patch_proposal，只落盘不提交。台账内所有 file:line 均基于 **HEAD `23abd74` 的工作树**（含用户既有改动 ` M apps/harmony/build-profile.json5`，该文件与本域无关）。复核前需要一次 `git add docs/audit && git commit`，否则下游 worker 拿到的是未入库基线。 |
| 台账完成判据「每个 file:line 可在源码中复核」缺可验证 gate | **采纳** → §0.2 抽验命令 | 不新增脚本文件（不修改源码），以台账内可粘贴命令交付；8 个锚点本轮实测全 `OK`。 |
| 三域技术栈异构（`.mjs` / `.tsx`） | **采纳** → §F3 | 按域分级给判据，不强行统一模板。 |
| `audit-contracts` 基线 §0-§6 与实际 §0-§7 不符 | **移交** `audit-contracts` | 不属本工单范围（本工单范围 = tools / apps-harmony-tools / remotion）。 |
| `audit-server-functions` 的 files 漏 `server/deploy`、`server/supabase/migrations` | **移交** `audit-server-functions` | 同上。注：本工单 `A4` 已记录 `tools\check-snapshot-mirror-sql.test.mjs` 引用 `server/supabase/migrations/20261101000001_snapshot_mirror.sql`，可作为该工单的只读引用源线索。 |
| `audit-contracts` 问题类型分布可能失衡 | **移交** `audit-contracts` | 本域按「实际捕获的事实」出行，未凑满五型（本域条目集中在边界/重复/接线三类，是实测结果而非配额）。 |

### 本域优先级摘要（按处置顺序）

1. **C7** `device-smoke` SKIP 退出码 —— 一句话修，影响所有依赖它判「双端验过」的自动化。
2. **C2 / C6** 两个 `check-*` 门禁实际不生效；`C5` 官网门禁缺席 CI。三者都要么接进 `check-gates`/CI，要么在 `C8` 的「人工入口清单」里明确降级。
3. **C9 / D2** 统一 verify 入口为唯一事实源（建议 `run-tests.mjs` 改为 glob 全部 `*.test.mjs` 而非手写清单），再对齐 CI。
4. **A1** 立「脚本落位判据」，才能谈 A3/A4 的搬迁。
5. **E1 / E2** 对账脚本的语义修正（id 级比较 + `--remote` 真判定）。
6. **F1 / E4 / E5** remotion 域的三件小事（typecheck 进 CI、删死常量、时长常量化）。
