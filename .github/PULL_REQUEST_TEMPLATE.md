## 这个 PR 做了什么

<!-- 一句话说明结果，不要写"更新了一些代码" -->

## 改动范围

- [ ] HarmonyOS（`apps/harmony`）
- [ ] Android（`apps/android`）
- [ ] 服务端（`server`）
- [ ] 跨端契约（`contracts`）— 若是，两端实现是否同步？
- [ ] 文档 / 脚本

## 关联 issue

Closes #

## 自查清单

- [ ] 在 `apps/harmony` 下跑过 `node tools/check-gates.mjs`（或 `--skip-build` 并说明编译状态）
- [ ] 涉及鸿蒙改动时，本地跑过 `devecocli build --product default` 并附输出
- [ ] 涉及 Android 改动时，`./gradlew :app:testDebugUnitTest` 通过
- [ ] 改动数据结构时，先改了 `contracts/README.md` 并同步两端
- [ ] 新增第三方依赖 / 资源时，同步更新 `THIRD-PARTY-NOTICES.md` 或 `ASSETS.md`
- [ ] 没有提交密钥、签名材料、`agconnect-services.json`、`.env` 真值

## 截图 / 日志（UI 或设备相关改动必填）
