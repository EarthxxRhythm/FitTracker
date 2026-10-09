# FitTracker APP 备案材料（办备案时照抄）

> 生成：2026-10-09。用途：APP 备案（工信部，2023 年起强制）时需要提交的「应用公钥 + 证书指纹」。
> 材料来源：发布证书 `~/.ohos/release-keys/fittracker_release.cer` 的 **Leaf 证书**（证书链 3 张：Root → Developer Relations CA → Leaf，**备案只取 Leaf**）。

## 1. 备案要交的核心材料（已备齐）

| 项 | 值 |
| --- | --- |
| 应用包名 | `com.earthrhythm.fittracker` |
| 应用名称 | FitTracker |
| 证书主体（Subject） | `C=CN, O=李凡, OU=1794157958125343233, CN=李凡(1794157958125343233)\,Release` |
| 证书有效期 | 2026-10-09 → **2029-10-09** |
| **公钥（PEM）** | 见下方 §2 |
| **MD5 指纹** | `AB:4C:9F:9B:DD:DB:4A:87:07:75:D9:A7:14:7F:41:B5` |
| SHA1 指纹 | `3D:0B:DA:19:19:DE:13:89:6E:16:74:4B:AC:21:57:44:85:56:E3:04` |
| SHA256 指纹 | `13:04:C8:51:87:8A:07:24:D2:D0:C8:82:EF:28:D5:7E:75:93:92:D2:AA:13:8E:4F:98:6F:DB:E5:A3:AD:D6:67` |

> 官方 FAQ 口径（`FAQ/安全/证书管理_Device_Certificate/APP备案如何获取公钥和证书指纹/faqs-device-certificate-5`）提到备案平台要求「应用对应的**公钥和证书 md5 指纹**」，故 MD5 与公钥两者都要给。

## 2. 公钥（PEM，直接复制）

```text
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEd2YsCJEbpDcNaIciyUGg0Ucvlrgp
ewsd22gLJmPZsZO/9ysTy3e2DpGh+eE3hPZBPdBeTyr/jkBOz6flqsxplQ==
-----END PUBLIC KEY-----
```

**自洽校验（已做）**：该公钥与申请证书时提交的 CSR 中的公钥一致（同源片段 `d2YsCJEbpDcNaIciyUGg0Ucvlrgp`），可确认「申请 CSR → 换回证书」链条未被替换过。

## 3. 复现方式（换证书或换机器时重跑）

```bash
CERT="$HOME/.ohos/release-keys/fittracker_release.cer"
# 证书链共 3 张，取最后一张（Leaf）
python -c "
import re
s = open(r'C:/Users/19308/.ohos/release-keys/fittracker_release.cer', encoding='utf-8').read()
certs = re.findall(r'-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----', s, re.S)
open(r'C:/Users/19308/.ohos/release-keys/leaf.pem','w').write(certs[-1])
print('leaf written, chain len =', len(certs))
"
L="$HOME/.ohos/release-keys/leaf.pem"
openssl x509 -in "$L" -noout -fingerprint -md5      # MD5 指纹
openssl x509 -in "$L" -noout -fingerprint -sha256   # SHA256 指纹
openssl x509 -in "$L" -noout -subject -dates        # 主体与有效期
openssl x509 -in "$L" -pubkey -noout                # 公钥
```

⚠️ **必须取 Leaf**：`~/.ohos/config/*.cer` 与 `release-keys/*.cer` 都是**多级证书链**。取到 Root CA 或中间 CA 的指纹是不通用的（此前调试证书指纹注册曾踩过这个坑）。

## 4. 备案流程（[用户] 执行，Agent 无法代办）

备案是**账号级外部操作**（需要你的实名主体、接入商账号、服务器/云资源），项目计划中已明确划归用户侧。

1. **确认主体**：个人 or 企业 —— 影响可备案的 APP 类别与所需证件；
2. **选接入商**：可用**华为云**（与现有 AGC 生态一致）；
3. **备齐资源**：备案通常需要**备案服务码**（购买指定云服务器/云资源后领取）；
4. **提交材料**：
   - 主体证件（个人身份证 / 企业营业执照）
   - APP 信息：应用名称、包名、**公钥 + MD5 指纹**（本文档 §1/§2 直接抄）
   - 涉及云资源的还需云服务信息
5. **审核链路**：接入商初审 → 工信部审核（官方口径 **20 个工作日内**）→ 下发**备案号**；
6. **回填**：拿到备案号后，填入 AGC 提审信息。

## 5. 注意事项

- **这是上架最长的一段周期**（计划文档估 **1–2 周+**），越早启动越好，可与工程侧并行；
- **所有 APP 必须备案**；**端云一体化（本项目使用 AGC 认证 + 云数据库）必须 ICP 备案**——这是提审前置；
- 发布证书**有效期 3 年（至 2029-10-09）**：证书到期换证后，备案里的公钥与指纹需同步更新（备案信息与实际证书不一致可能导致问题）；
- 若后续更换 `bundleName`，备案信息也需一并变更。
