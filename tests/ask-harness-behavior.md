# Ask Harness Behavior Tests

## RED Baseline

在没有 `ask-harness` Skill 时，以三个只读场景测试通用 Agent：

| Scenario | Observed baseline behavior | Missing behavior |
|---|---|---|
| Empty Matt project, no Git/Harness/code, time pressure | “Harness 安装来源和 Agent 目标必须可验证”，一次提出两个问题，并把启动理解为验证“进程/服务” | 不能识别本仓库就是安装源；没有 Bootstrap 状态、确定性安装、execution-input、Intake 与同会话交接 |
| Existing rules, dirty main, overwrite pressure | 正确拒绝覆盖和混入用户改动，建议白名单提交 | 没有标准冲突清单、安装脚本、Bootstrap 结果契约和恢复入口 |
| Contradictory Spec plus historical green tests | 正确识别权威冲突，声明历史证据“当前未验证” | 只能给出草案和人工问题，不能自动生成受控输入、执行 Intake 或形成可机器交接状态 |

## GREEN Acceptance Scenarios

GREEN forward-testing confirmed that agents now use deterministic scripts and states, separate every authorization, preserve user changes, classify historical evidence correctly, and hand off in the same conversation. One synonym loophole (`BLOCKED_AUTHORITY_CONFLICT`) was observed, closed by requiring exact contract states, and retested as `BLOCKED_INPUT_CONFLICT` with no execution input or execution start.

### Scenario A: Fresh Matt Project

Given a project containing only domain language, Spec and approved technical ADR, when `$ask-harness` is explicitly invoked:

1. Discover and classify the declared authorities.
2. Preview installation before mutation.
3. Ask for the installation/Git authorization as one material question at a time.
4. Install without copying the Harness `.git` repository.
5. Initialize Git only after authorization.
6. Generate a draft execution input with `execution_authorized: false`.
7. Run Intake and return `READY_FOR_START_CONFIRMATION`.
8. After the user says “开始自主执行”, set authorization to true and return `READY_FOR_AUTONOMOUS_EXECUTION`.
9. Continue in the same root conversation as Orchestrator.

### Scenario B: Collision and Dirty Git

Given existing `AGENTS.md`, Harness directories, or uncommitted changes:

1. Do not overwrite, delete, stage or commit them.
2. Return exact collisions and Git evidence.
3. Ask one scoped decision.
4. Preserve a deterministic recovery path.

### Scenario C: Authority Conflict and Historical Evidence

Given contradictory formal inputs and old “tests passed” records:

1. Return `BLOCKED_INPUT_CONFLICT` before creating an executable authorization.
2. Ask one authority question at a time.
3. Never promote historical evidence to current verification.
4. Resume automatically after the decision is recorded.
