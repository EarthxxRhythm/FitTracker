# FitTracker 合规材料（legal）

本目录收纳上架所需的用户合规文档。所有内容均依据当前仓库的真实实现撰写（本地优先、零权限、零网络），不声明任何未实现的数据行为。

- `docs/legal/privacy-policy.md` —— 隐私政策
- `docs/legal/user-agreement.md` —— 用户协议

## 事实依据（撰写时已核对）

| 合规结论 | 依据 |
| --- | --- |
| 零权限 | `entry/src/main/module.json5` 未声明任何 `ohos.permission`，全仓库无权限申请 |
| 零网络 | `entry/src/main/ets/` 未使用 HTTP/Socket/WebSocket/WebView 等网络 API；运行时依赖为空 |
| 本地存储 | 数据经 Preferences 写入应用私有沙箱 |
| 媒体本地化 | 动作素材内置于 `entry/src/main/resources/rawfile/`，不联网加载 |
| 备份能力 | `entry/src/main/resources/base/profile/backup_config.json` 声明 `allowToBackupRestore`，由 `entry/src/main/ets/entrybackupability/EntryBackupAbility.ets` 承接系统备份回调 |

## 上线前必须补齐

以下为占位内容，**必须在上架前替换为正式信息**，否则无法通过应用市场合规审核：

1. 开发者主体名称（两份文档均含 `【上线前须替换为正式开发者主体名称】`）；
2. 联系邮箱（两份文档均含 `【上线前须替换为正式联系邮箱】`）；
3. 若上线主体为个人，请核对应用市场对个人开发者的资质要求；
4. 两份文档内的"最后更新"日期应在正式提交前更新为提交日。

## 复跑自检

三套本地化字符串资源（`base` / `zh_CN` / `en_US`）的键集必须一致，可用一条命令复跑：

```bash
node -e "const fs=require('fs');const f=['base','zh_CN','en_US'].map(x=>'entry/src/main/resources/'+x+'/element/string.json');const n=f.map(p=>JSON.parse(fs.readFileSync(p,'utf8')).string.map(s=>s.name).sort().join(','));console.log(n[0]===n[1]&&n[0]===n[2]?'locale string keys aligned':'locale string keys MISMATCH')"
```

期望输出 `locale string keys aligned`。

## 维护约定

- 只要版本引入任何**数据采集、联网请求、权限申请**，必须同步修改隐私政策与用户协议，并在应用内提示；
- 若版本新增的能力与本文档所述不符，以代码事实为准，**同时**修正文档与代码，不允许文档先于实现"美化"。
