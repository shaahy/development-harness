# Ask Harness Bootstrap 流程

## 目标结果

根对话从用户声明的 Matt 产物推进到两个真实结果之一：

- `READY_FOR_START_CONFIRMATION`：项目 Harness、Git 基线、技术设计、执行输入和 Intake 均已通过，但尚未授权执行。
- 一个结构化阻断项和一个决策问题。

获得启动授权后，生成 `READY_FOR_AUTONOMOUS_EXECUTION`，并在同一对话中继续担任 Orchestrator。

## 状态序列

| 状态 | 必需证据 | 允许的下一步 |
|---|---|---|
| `VERIFYING_HARNESS` | 项目内 Harness 验证结果 | 检查声明的输入 |
| `DISCOVERING_INPUTS` | 项目根目录和声明路径 | 读取并分类输入 |
| `INPUTS_MAPPED` | 权威表和冲突记录 | 询问一个权威问题或检查 Git |
| `GIT_INSPECTED` | 仓库、远程地址、分支、HEAD、脏状态 | 解决一个 Git 阻断或继续 |
| `TECHNICAL_DESIGN` | 缺失决策清单 | 使用 `superpowers:brainstorming`，不得编码 |
| `BASELINE_READY` | 已批准的 Spec/ADR 和干净的基线提交 | 生成草稿输入 |
| `INTAKE_CHECKING` | 草稿输入和确定性检查 | 修复一个阻断项或请求最终启动 |
| `READY_FOR_START_CONFIRMATION` | Bootstrap 通过、执行授权为 false | 提出一个最终问题 |
| `READY_FOR_AUTONOMOUS_EXECUTION` | 执行授权为 true 且再次检查通过 | 加载 Orchestrator 并继续 |

使用准确的契约状态。语义或权威矛盾为 `BLOCKED_INPUT_CONFLICT`；Git 或模板远程仓库失败为 `BLOCKED_GIT`。

## 项目内 Harness

项目模板已经包含 Harness。从本技能目录向上查找，直到发现同时包含 `HARNESS.md`、`AGENTS.md` 和 `harness.config.yaml` 的仓库根目录，然后运行 `checks/validate-harness.ps1`。

- 不请求全局安装技能。
- 不向同一项目重复复制 Harness。
- 不检查宿主产品名称，也不按宿主名称分支。
- 不以单 Agent 降级替代真实多 Agent 执行。
- 验证失败是真实阻断；报告失败检查，只修复安全、确定性的漂移。

## 输入分类

使用以下固定权威表结构：

| 文件 | 分类 | 批准状态 | 约束范围 | 冲突 |
|---|---|---|---|---|

分类值保持为：

- `formal_authority`：已批准的 Spec、ADR、UI Contract 或等价文件。
- `approved_decision`：已确认的支持性决策记录。
- `reference`：有用但不具约束力的资料。
- `historical_evidence`：旧实现或测试声明，不能作为当前通过证据。
- `conflict`：缺少更高权威裁决的互斥陈述。

不得根据文件名、完整程度或自信语气推断批准状态。用户当前的明确决策高于已存文件，且必须记录。

## Git 与模板远程仓库

建立基线前检查仓库：

- 已存在且有未提交改动：在识别并安全隔离用户改动前，不得暂存、提交、stash、reset 或创建 worktree。
- 已存在且干净：保留当前分支和历史。
- 尚未初始化：先预览 `scripts/initialize-project.ps1`，获得授权后再应用。
- `origin` 等于 `harness-source.yaml` 中的 `template_repository`：返回 `BLOCKED_GIT`。产品提交前，用户必须创建或选择产品仓库，或者明确仅保留本地工作。
- 通过 GitHub `Use this template` 创建的仓库：保留其产品 `origin`，无需额外配置远程仓库。

基线提交前，报告准确的暂存文件白名单并请求授权。存在无关改动时不得广泛暂存。

## 技术就绪度

实施关键决策包括平台/运行时、框架、进程或模块边界、持久化、迁移、安全边界、错误恢复、构建/启动契约和验证策略。

缺失或矛盾时使用 `superpowers:brainstorming`。每次解决一个重要决策，确认后才能写入 ADR。UI 细节可以保留为 `auto_detect`，产品行为不能留空。

## 执行输入与 Intake

只有在 Spec 和技术设计批准后才使用 `scripts/new-execution-input.ps1`。首次运行不传入 `-ExecutionAuthorized`。

然后运行：

```powershell
checks/bootstrap-check.ps1 -TargetRoot <project> -ExecutionInputPath <project>/.harness/execution-input.json
```

不得把失败结果解释为通过。安全的确定性失败可以自动修复；语义冲突必须交由用户裁决。

## 最终交接

到达 `READY_FOR_START_CONFIRMATION` 时，报告已确认权威、Harness 版本、Git 分支和基线提交、已批准技术 ADR、输入路径和 UI 模式、Intake 结果及剩余风险。

只询问：`是否授权现在开始自主执行？`

用户确认后，用 `-ExecutionAuthorized` 重新生成输入，再次运行 Bootstrap，必须得到 `READY_FOR_AUTONOMOUS_EXECUTION`；随后加载 `roles/orchestrator.md`，建立执行 Todo，并在同一对话中继续，无需粘贴交接提示词。

## 常见错误

| 错误 | 必须采取的纠正方式 |
|---|---|
| 重复安装模板中已有的 Harness | 验证项目内 Harness |
| 按宿主产品名称分支 | 使用固定的多 Agent 执行契约 |
| 把模板仓库作为产品远程仓库 | 产品提交前以 `BLOCKED_GIT` 停止 |
| 一次询问多个决策 | 每次只询问一个重要问题，记录后继续 |
| 把旧的绿色测试作为当前证据 | 标为历史证据并重新生成验证证据 |
| 架构未解决却把 Intake 标为通过 | 先通过 brainstorming 形成已批准 ADR |
| Intake 后启动新的根任务 | 在同一根对话中继续 |
