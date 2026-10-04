# FitTracker 合规材料（legal）

本目录收纳上架所需的用户合规文档。所有内容均依据当前仓库的真实实现撰写（本地优先；1.1.0 起接入华为 AGC 认证与云数据库，用于可选的账号云同步），不声明任何未实现的数据行为。

- `docs/legal/privacy-policy.md` —— 隐私政策
- `docs/legal/user-agreement.md` —— 用户协议

## 事实依据（撰写时已核对）

| 合规结论 | 依据 |
| --- | --- |
| 最小权限 | `entry/src/main/module.json5` 仅声明 `ohos.permission.INTERNET`（用途：账号登录与云同步） |
| 联网范围受限 | 联网行为仅指向华为端云一体化服务（AGC 认证 + 云数据库）；不集成广告、第三方统计或社交分享 SDK |
| 本地存储 | 数据经 Preferences 写入应用私有沙箱 |
| 媒体本地化 | 动作素材内置于 `entry/src/main/resources/rawfile/`，不联网加载 |
| 备份能力 | `entry/src/main/resources/base/profile/backup_config.json` 声明 `allowToBackupRestore`，由 `entry/src/main/ets/entrybackupability/EntryBackupAbility.ets` 承接系统备份回调 |

## 应用内展示

登录 / 注册页的协议勾选行与设置页「隐私说明」均经 `features/settings/pages/LegalDocPage`（路由常量 `AppRoutes.LEGAL_DOC`）打开，渲染的是 `entry/src/main/resources/rawfile/legal/privacy-policy.txt` 与 `entry/src/main/resources/rawfile/legal/user-agreement.txt`——本目录两份 md 的逐字转换副本（去除 `#`/`**`/`` ` `` 标记与表格分隔行，正文逐字保留）。修改正文或替换占位符后，必须用 `node tools/convert-legal-docs.mjs` 重生成 rawfile 副本，两者不得漂移。

## 上线前必须补齐（状态 · 2026-10-03）

- [x] **开发者主体名称**：`EarthRhythm` 已替换（两份 md + 应用内 rawfile 副本已重生成）；
- [x] **联系邮箱**：`1930808767@qq.com` 已替换（同上）；
- [x] **「最后更新」日期**：已更新为 2026-10-03；
- [ ] 若上线主体为个人，请核对应用市场对个人开发者的资质要求（待确认主体性质：个人 / 企业）。
- [ ] **真短信启用（上架后）**：手机验证码短信通道见 `docs/cloud-setup.md` §8（R2 路线：上架后以「已上线App名称」申请 AGC 短信签名 → 平台直发）；启用时按 §8.7 复核本目录隐私政策表述。

## 复跑自检

三套本地化字符串资源（`base` / `zh_CN` / `en_US`）的键集必须一致，可用一条命令复跑：

```bash
node -e "const fs=require('fs');const f=['base','zh_CN','en_US'].map(x=>'entry/src/main/resources/'+x+'/element/string.json');const n=f.map(p=>JSON.parse(fs.readFileSync(p,'utf8')).string.map(s=>s.name).sort().join(','));console.log(n[0]===n[1]&&n[0]===n[2]?'locale string keys aligned':'locale string keys MISMATCH')"
```

期望输出 `locale string keys aligned`。

## 维护约定

- 只要版本引入任何**数据采集、联网请求、权限申请**，必须同步修改隐私政策与用户协议，并在应用内提示；
- 若版本新增的能力与本文档所述不符，以代码事实为准，**同时**修正文档与代码，不允许文档先于实现"美化"。
