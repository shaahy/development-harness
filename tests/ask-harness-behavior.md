# Ask Harness Behavior Tests

## RED Baseline

在没有 `ask-harness` Skill 时，以三个只读场景测试通用 Agent：

| Scenario | Observed baseline behavior | Missing behavior |
|---|---|---|
| Matt project without project-local Skill routing, time pressure | 把启动理解为验证“进程/服务”，并要求用户自行准备命令 | 没有模板完整性校验、Bootstrap 状态、execution-input、Intake 与同会话交接 |
| Existing rules, dirty main, overwrite pressure | 正确拒绝覆盖和混入用户改动，建议白名单提交 | 没有标准冲突清单、安装脚本、Bootstrap 结果契约和恢复入口 |
| Contradictory Spec plus historical green tests | 正确识别权威冲突，声明历史证据“当前未验证” | 只能给出草案和人工问题，不能自动生成受控输入、执行 Intake 或形成可机器交接状态 |

## GREEN Acceptance Scenarios

GREEN forward-testing confirmed that agents now use deterministic scripts and states, separate every authorization, preserve user changes, classify historical evidence correctly, and hand off in the same conversation. One synonym loophole (`BLOCKED_AUTHORITY_CONFLICT`) was observed, closed by requiring exact contract states, and retested as `BLOCKED_INPUT_CONFLICT` with no execution input or execution start.

### Scenario A: Fresh Matt Project

Given a project containing only domain language, Spec and approved technical ADR, when `$ask-harness` is explicitly invoked:

1. Resolve `$ask-harness` to `.agents/skills/ask-harness/SKILL.md`.
2. Validate the project-local Harness already supplied by the repository template.
3. Discover and classify the declared authorities.
4. Inspect Git and block if `origin` still points to the Harness template repository.
5. Ask for Git/technical/baseline authorization as one material question at a time.
6. Generate a draft execution input with `execution_authorized: false`.
7. Run Intake and return `READY_FOR_START_CONFIRMATION`.
8. After the user says “开始自主执行”, set authorization to true and return `READY_FOR_AUTONOMOUS_EXECUTION`.
9. Continue in the same root conversation as Orchestrator using real specialist Agents.

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
