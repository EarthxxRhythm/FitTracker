# 多代理文件信箱协议

## 背景

Codex 桌面版当前版本的 inter-agent `message` 载荷投递不可靠：`spawn_agent` / `followup_task` / `send_message` 都能触发目标回合，但内容可能为空。原因是平台把消息写进 `encrypted_content` 段，而子代理侧未能解密并注入分析通道。此协议用共享文件系统绕过该通道，作为所有并行子代理的任务载体。

## 目录

```text
cluster/
├─ PROTOCOL.md          # 本协议
├─ inbox/<task>.json    # 待认领任务
├─ claimed/<task>.json  # 已认领任务（执行中/已完成）
└─ outbox/<task>.json   # 子代理结果
```

## 任务 JSON 字段

```json
{
  "task": "任务唯一标识，与文件名一致",
  "title": "一句话标题",
  "brief": "任务完整说明，自包含，不依赖聊天上下文",
  "owner_files": ["明确允许修改的文件或目录"],
  "do_not_touch": ["禁止修改的文件或目录"],
  "acceptance": ["验收条件列表"],
  "created_at": "ISO8601"
}
```

## 协调者流程

1. 用 `apply_patch` 把任务写入 `cluster/inbox/<task>.json`。
2. `spawn_agent`，`fork_turns="none"`，`task_name` 与文件名一致；`message` 只写“执行 cluster/inbox/<task>.json 中的任务，完成后写 cluster/outbox/<task>.json”。
3. 以 `cluster/outbox/<task>.json` 出现为完成信号，用 `functions.exec` 轮询，不要依赖 `wait_agent`。

## 子代理流程

1. 启动后若分析通道中没有可见的 NEW_TASK 正文，扫描 `cluster/inbox/*.json`。
2. 按修改时间取最旧文件，原子移动到 `cluster/claimed/`（同卷 rename）。移动失败说明已被他人认领，换下一个。
3. 执行任务；把结果写 `cluster/outbox/<task>.json`（字段：`task`、`status: done|blocked`、`summary`、`changed_files`、`evidence`）。
4. final answer 只给一行摘要 + outbox 路径。

## 约束

- `fork_turns` 必须是 `"none"`，避免子代理继承主会话后误派子任务。
- 每个任务自包含，禁止依赖“上一条消息”这类聊天状态。
- 同一文件只归一个任务所有；跨文件共享冲突时先认领者优先。
