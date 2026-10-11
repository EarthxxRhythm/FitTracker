---
name: prd-user-stories-moscow
title: 架构设计 - PRD 第四章：用户故事与 MoSCoW
author: 自动生成
created_at: 2026-05-05
---

# 概览

本设计文档用于支撑 PRD 第四章的实现，重点在于将 MVP 功能以清晰的用户故事表达，并通过 MoSCoW 优先级确保范围的可控性。

# 章节结构映射
- 4.1 用户故事（6 条以上，覆盖核心 MVP 功能）
- 4.2 MoSCoW 优先级表
- 4.3 Won't Have（单独段落，不展开为用户故事）
- 4.4 验收准则与格式规范

# 设计原则
- 保持与现有实现的紧密对齐，避免临时性扩展
- 使用统一的“角色-希望-价值”表述和 Given-When-Then 验收格式
- Won't Have 应独立列出，确保不会被误解为 MVP 的可选实现

# 实施要点
- 采用 Markdown 格式，确保与 PRD.md 的风格一致
- 所有用户故事均以“作为<角色>，我希望<功能>，以便<价值>”开头
- 验收标准采用 Given-When-Then，3-5 条/故事
- MoSCoW 表放置于 4.2 小节，清晰分类
- Won't Have 段落放在 4.3 小节之外的单独段落
