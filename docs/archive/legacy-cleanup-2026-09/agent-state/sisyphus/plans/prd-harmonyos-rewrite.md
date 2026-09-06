# PRD HarmonyOS Rewrite: 对齐鸿蒙规则重写产品需求文档

## TL;DR
> **Summary**: 基于 rules.md（ArkTS 编码规范）和鸿蒙智能体默认规则（官方）重写 `.opencode/FitTracker健身工具PRD.md`，删除所有 React Native/Firebase/OAuth/AI/社交/视频等不实描述，替换为 HarmonyOS ArkTS/ArkUI 本地优先方案。
> **Deliverables**: 一份对齐鸿蒙技术栈的 PRD（覆盖 rules.md 目录结构、ArkTS 编译器约束、DesignTokens 引用、官方 API 规范）
> **Effort**: Medium | **Parallel**: NO — 单一文档顺序重写

## Work Objectives
### Core Objective
将 `.opencode/FitTracker健身工具PRD.md` 重写为完全对齐 HarmonyOS ArkTS/ArkUI 技术栈的 PRD，删除所有与代码不符的云端/AI/社交/跨平台描述。

### Deliverables
1. 重写后的 `.opencode/FitTracker健身工具PRD.md` — HarmonyOS 原生方案

### Must Fix (基于规则文件的硬性要求)
- ❌ 删除 "React Native/iOS/Android" → ✅ HarmonyOS ArkTS/ArkUI
- ❌ 删除 "Firebase/云端同步" → ✅ `@ohos.data.preferences` 本地存储
- ❌ 删除 "OAuth 2.0/JWT/Apple/Google 登录" → ✅ Mock 内存认证
- ❌ 删除 "200+ 动作/3D动画/视频" → ✅ 45 个文本动作
- ❌ 删除 "AI 算法推荐" → ✅ 规则匹配预设计划
- ❌ 删除 "社交/社区/分享/成就/徽章" → ✅ 移除
- ❌ 删除 "HTTPS/TLS/GDPR/React Native" → ✅ 移除
- ➕ 添加 ArkTS 编译器约束附录（73 条规则摘要）
- ➕ 添加 DesignTokens.ets 引用和 `$r` 资源规范
- ➕ 添加 `pages/`、`components/`、`common/services/` 目录结构
- ➕ 添加 ArkUI 动画约束（`renderGroup`、`animateTo`、禁止动画改布局属性）

## Verification
- [ ] 无 React Native/Firebase/OAuth/AI/社交 关键词
- [ ] 包含 ArkTS 编译器约束引用
- [ ] 包含 DesignTokens 和 `$r` 引用
- [ ] 技术栈描述为 HarmonyOS ArkTS/ArkUI
- [ ] 所有功能描述与现有代码一致
