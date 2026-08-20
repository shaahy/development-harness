# Development Harness

本项目由平台无关的多 Agent 开发 Harness 管理，直接面向具备完整能力的多 Agent 开发环境，不关心环境名称，也不为能力不足提供降级方案。

## 统一入口

用户输入 `$ask-harness` 时，根主 Agent 必须读取：

```text
.agents/skills/ask-harness/SKILL.md
```

随后在当前根对话完成：Harness 校验、Matt 输入分类、Git/技术基线、`execution-input`、Intake、最终执行授权，以及向 `roles/orchestrator.md` 的交接。

## 固定执行链

```text
$ask-harness
  -> Bootstrap
  -> Intake
  -> 按需 UI Preparer <-> UI Review
  -> Planner <-> Plan Review
  -> Implementer -> Tester
  -> FAIL: Debugger -> Tester
  -> PASS: Reviewer
  -> 全量回归
  -> 最终三轴审查
  -> 人工最终验收
```

主 Agent 必须派发真实的专业 Agent。工作 Agent 不得继续创建下级 Agent。任何实现、测试、修复和审查结论都必须使用当前代码与当前提交产生的新鲜证据。

## 权限边界

Harness 可以执行安全、可逆、局部的开发动作，并在隔离 worktree 中按任务提交。未经单独授权，不得 merge、push、创建远程 PR、deploy、publish、release、删除分支/worktree、获取凭证或执行不可逆及生产副作用操作。

## 持久化状态

运行状态写入 `.harness/`。中断后先读取 `.harness/progress.md` 和决策账本，再用 Git 历史核对，从第一个未闭合事件恢复；不得仅凭历史文字宣称当前通过。

## 模板来源

模板版本见 `HARNESS_VERSION`，来源见 `harness-source.yaml`。如果产品仓库的 `origin` 仍指向模板仓库，必须在产品基线提交前进入 `BLOCKED_GIT`。
