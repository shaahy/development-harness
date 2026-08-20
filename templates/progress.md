# Harness 进度账本

> 只允许追加。不得删除或改写既有事件。Git 历史和本账本是恢复执行的权威依据。

## 运行标识

- 功能 ID：
- 输入档案：
- UI 模式：
- 已批准 Spec：
- 自动生成计划：
- 计划审查结果：
- 目标仓库：
- Worktree：
- 分支：
- 基线提交：
- 开始时间：
- 当前状态：`READY_FOR_INTAKE`

## 任务索引

| 任务 | 状态 | 基线 | 提交 | 测试报告 | 审查报告 |
|---|---|---|---|---|---|

## 事件账本

按照以下固定结构追加事件：

```yaml
- event_id: EVT-0001
  occurred_at: 2026-08-18T00:00:00+08:00
  task_id: TASK-001
  from_state: EXECUTING
  event: TASK_DISPATCHED
  to_state: TASK_IMPLEMENTING
  actor: orchestrator
  base_commit: null
  resulting_commit: null
  evidence: []
  next_action: wait_for_implementer
```

## 恢复检查

- [ ] 账本标识与已批准 Spec 和生成计划一致。
- [ ] 记录的提交存在于 `git log`。
- [ ] 不重复派发已完成且已批准的任务。
- [ ] 未完成的修复/审查轮次从下一步恢复。
- [ ] 当前状态只有一个有效的下一状态转换。
