# Execution Harness Agent Rules

本文件约束 Matt Spec 已确认后的自主交付阶段。Harness 可以自动补齐必要的 UI 基线和 Implementation Plan，但无权重新定义产品或发布边界。

## 1. 使命与接管点

用户确认 Matt 输出的领域语言、Spec、范围和执行授权后，主 Agent 即接管。`ui-ux-pro-max` 产物和 Implementation Plan 都不是启动前必需的人工确认项。

支持两种入口：

- `matt_spec_only`：领域语言 + Spec；默认 `auto_detect`，由 Harness 判断无 UI、复用既有设计或自动生成。
- `matt_plus_uiux`：领域语言 + Spec + 已交付 UI 基线。

## 2. 启动前提

- `intake-check.ps1` 返回 `ready: true`。
- 领域语言/`CONTEXT.md` 与 Spec 非空且已获用户确认。
- 用户已授权 Harness 自动规划、必要时自动补 UI 基线并开始执行。
- Git 仓库可用，代码工作在隔离 worktree/分支中进行。

Implementation Plan 是自动生成产物，不是人工准入条件。

## 3. 权威与冲突

权威顺序：用户当前指令与安全边界 > 已批准 Spec/ADR > 提供或自动审查通过的 UI 基线 > 自动审查通过的 Implementation Plan > Harness 规则 > 原型和截图。

- UI 和计划只能解释、拆解上游，不能静默改变上游。
- `ui-ux-pro-max` 可选不等于 UI 决策可缺失；全新 UI 且无基线时必须自动生成。
- 实质冲突或产品歧义必须停止，不得猜测。

## 4. 技能路由

- Matt 系列技能负责产品分析、领域语言与 Spec；执行阶段不得重开产品定义。
- 缺少必要 UI 基线时，UI Preparer 自动使用 `ui-ux-pro-max`，不要求中间确认。
- Planner 使用 Superpowers `writing-plans`；通过独立审查后默认 `subagent-driven-development`。
- 实施使用 `using-git-worktrees`、`test-driven-development`、`systematic-debugging`、`requesting-code-review`、`verification-before-completion`。

## 5. 主 Agent 职责

1. Intake 校验并分类 UI 模式。
2. 按需调度 UI Preparer 与独立 UI 审查，最多3轮。
3. 调度 Planner 与独立 Plan Reviewer，最多3轮；通过后自动执行。
4. 建立 Todo，并以 `progress.md` 为持久化真相源。
5. 每项任务生成最小充分的 `task-brief`；同一时间只允许一个写代码 Agent。
6. 实现后必须取得独立 Tester 和 Reviewer 的新鲜证据。
7. 每次状态变化先落账；命中停止条件时保存现场并只问一个问题。

工作 Agent 不得创建自己的子 Agent，也不得自行宣布整个项目完成。

## 6. 执行原则

- 编码前明确假设，选择满足 Spec 的最简单实现。
- 只修改任务直接需要的文件，不顺手重构、升级或清理用户内容。
- 每项代码任务必须先获得失败测试或等价失败检查，再实施最小改动。
- 每个改动都能追溯到 Spec、计划任务或审查发现。

## 7. 自动循环

```text
Intake
  -> 按需 UI Preparer <-> UI Review
  -> Planner <-> Plan Review
  -> Implementer -> Tester
  -> FAIL: Debugger -> Tester
  -> PASS: Reviewer
  -> FINDINGS: Implementer/Debugger -> Tester -> Reviewer
  -> 全量回归 -> 最终三轴审查 -> 人工最终验收
```

- UI 审查最多3轮；耗尽进入 `BLOCKED_ARCHITECTURE`。
- Plan 审查最多3轮；耗尽进入 `BLOCKED_PLAN`。
- 同一根因最多3次修复；同一任务最多5轮代码审查返工。
- 不得删除、跳过、弱化或篡改测试制造通过。

## 8. Git 权限

允许只读检查、创建/使用隔离 worktree，以及在隔离 worktree 中按任务自动提交。

未经另行授权禁止 merge、rebase 到共享分支、push、远程 PR、deploy、publish、release、删除 worktree/分支/证据、强推或重写共享历史。每个提交必须记录 commit SHA。

## 9. 证据规则

“完成”“修复”“通过”必须引用实际命令、退出码、测试名称、变更文件、commit SHA 和独立 Reviewer 结论。静态检查、自动化测试、真实运行、视觉比较与人工验收必须分别陈述，不能互相替代。

## 10. 必须暂停

- 输入缺失、权威冲突或实质产品歧义。
- UI/Plan/调试/审查达到断路器。
- 需要改变已批准产品行为、安全边界或架构主干。
- 需要凭证、付费、外部权限、不可逆操作或生产副作用。
- Git 隔离失败，或继续只能依赖猜测。

普通、可逆、局部的实现选择由主 Agent裁决并写入 `decision-ledger.md` 后继续。

## 11. 完成定义

所有计划任务、独立任务审查、聚焦测试、全量回归、真实构建和最终三轴审查通过后，进入 `AWAITING_HUMAN_ACCEPTANCE`。这不等于发布批准；Git 集成和发布仍需单独授权。
