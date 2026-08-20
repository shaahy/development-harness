# 多 Agent 开发 Harness

面向具备完整能力的多 Agent 开发环境的项目模板。它从已确认的 Matt 领域语言与 Spec 接管，先由项目内置 `$ask-harness` 完成执行前准备，再由主 Agent 自动调度 UI、计划、实施、测试、修复、复测和审查。

Harness 不绑定开发环境名称，不检测能力，不提供单 Agent 降级模式。

## 1. 从模板创建产品项目

不要把产品代码直接开发在 `development-harness` 模板仓库中。在 GitHub 仓库首页选择：

```text
Use this template
  -> Create a new repository
  -> 创建产品自己的仓库
  -> 克隆产品仓库
```

也可以使用 GitHub CLI：

```powershell
gh repo create <owner>/<product-repository> `
  --private `
  --template shaahy/development-harness `
  --clone
```

从模板创建的产品仓库拥有自己的 `origin`。如果直接克隆 `development-harness`，`$ask-harness` 会在产品基线提交前返回 `BLOCKED_GIT`，防止产品代码误提交到模板仓库。

## 2. 克隆后直接启动

把用户提供的 Matt 产物和其他需求文档统一放入 `requirements-input/`，然后在该项目的根任务中发送：

```text
$ask-harness

项目根目录：<绝对路径>
Matt 正式输入：
- requirements-input/<领域语言或 CONTEXT 文件>
- requirements-input/<Spec 文件>
- requirements-input/<其他已批准决策或设计文件>

请引导我完成执行前准备；一次只问一个需要我决定的问题。
Intake 通过后，向我确认一次是否开始自主执行。
```

根 `AGENTS.md` 会把 `$ask-harness` 路由到：

```text
.agents/skills/ask-harness/SKILL.md
```

无需全局安装 Skill，也无需再次复制 Harness 文件。

## 3. Bootstrap 流程

```text
验证项目内置 Harness
  -> 声明并分类 Matt 输入
  -> Git 仓库、origin、分支和脏状态检查
  -> 技术设计缺口 -> brainstorming -> 用户确认 ADR
  -> 用户授权基线提交
  -> 自动生成未授权 execution-input
  -> Intake / Bootstrap 检查
  -> READY_FOR_START_CONFIRMATION
  -> 用户确认开始
  -> READY_FOR_AUTONOMOUS_EXECUTION
  -> 同一主对话切换 Orchestrator
```

Git 初始化、基线提交、技术设计确认和最终执行授权是相互独立的关卡；前一个确认不会隐含后一个确认。

## 4. 自主执行流程

```text
Intake 与 UI 分类
  -> 按需 ui-ux-pro-max 生成基线 <-> 独立 UI 审查
  -> Superpowers writing-plans <-> 独立 Plan 审查
  -> subagent-driven-development
  -> Implementer -> Tester
  -> 失败：Debugger -> Tester 复测
  -> 通过：Reviewer
  -> 全量回归 -> 最终三轴审查
  -> 人工最终验收
```

主 Agent 必须派发真实的专业 Agent。UI 与 Plan 审查最多3轮；Plan 通过后不再要求人工确认。

## 5. 输入档案

### `matt_spec_only`

提供领域语言、Spec 和已经确认的实施技术基线。默认 `ui_mode: auto_detect`：

- 无 UI：`none`
- 复用已有设计：`reuse_existing`
- 全新 UI 且无基线：`auto_generate`

### `matt_plus_uiux`

除 Matt 输入外，还提供交接清单、UI Contract、tokens、组件规格和状态矩阵；`ui_mode` 为 `provided`。

## 6. 人与 Harness 的边界

人负责：确认产品和技术基线、裁决权威冲突、授权 Git/正式启动、安全或不可逆操作、外部副作用和最终体验。

Harness 负责：发现输入、机械准备、Intake、必要 UI 基线、Implementation Plan、隔离 worktree 提交、TDD、测试、调试、复测、审查和证据。

历史记录中的“测试已通过”只能作为历史证据，不能替代当前代码的本轮验证。

## 7. 安全与诊断

- `execution-input` 初始为 `execution_authorized: false`。
- 只有 Bootstrap 再次通过且授权为真，才进入 Orchestrator。
- 同一时间只允许一个写代码 Agent。
- Tester 与 Debugger 分离，不得修改测试制造通过。
- merge、push、远程 PR、deploy、release 和破坏性清理始终需要单独授权。

完整自检：

```powershell
powershell -ExecutionPolicy Bypass -File .\checks\validate-harness.ps1
powershell -ExecutionPolicy Bypass -File .\tests\template-repository.test.ps1
powershell -ExecutionPolicy Bypass -File .\tests\ask-harness-scripts.test.ps1
```

## 8. 版本与恢复

模板版本见 `HARNESS_VERSION`，来源见 `harness-source.yaml`。模板生成的是独立项目快照，后续模板更新不会自动覆盖既有产品。

`.harness/progress.md` 是执行恢复依据。中断后用 Git 历史核对 commit SHA，从第一个未闭合事件继续。Harness 不持有生产凭证，也不自动执行 Git 集成或发布。
