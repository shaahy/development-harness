# Development Harness

面向 Codex App 的 Spec 后自主开发 Harness。用户把 Matt 领域语言、Spec 和可选设计产物放入项目后，通过 `$ask-harness` 完成安装、Git、技术设计、execution-input 和 Intake 引导；最终确认启动后，同一主对话自动调度 UI、计划、实施、测试、修复和审查。

## 1. 最短使用方式

### 一次性安装 Skill

把本仓库克隆为 Codex Skill：

```powershell
$askHarnessSkillRoot = Join-Path $env:USERPROFILE '.codex\skills\ask-harness'
git clone https://github.com/shaahy/development-harness.git $askHarnessSkillRoot
```

重启 Codex App。此后每个项目不需要手工复制 Harness。

### 在新项目中启动

先把 Matt 产物放进项目，然后在以该项目为工作区的新任务中发送：

```text
$ask-harness

项目根目录：<绝对路径>
Matt 正式输入：
- <领域语言或 CONTEXT 路径>
- <Spec 路径>
- <其他已批准决策或设计文件>

请引导我完成执行前准备；一次只问一个需要我决定的问题。Intake 通过后，向我确认一次是否开始自主执行。
```

Ask Harness 会自己调用安装和检查脚本，不要求用户复制文件、写 JSON 或运行 PowerShell。

## 2. Bootstrap 流程

```text
声明 Matt 输入
  -> 权威分类与冲突检查
  -> Harness 安装预览 -> 用户授权 -> 安装
  -> Git 检查/初始化 -> 用户授权
  -> 技术设计缺口 -> brainstorming -> 用户确认 ADR
  -> 用户授权基线提交
  -> 自动生成未授权 execution-input
  -> Intake / Bootstrap 检查
  -> READY_FOR_START_CONFIRMATION
  -> 用户确认开始
  -> READY_FOR_AUTONOMOUS_EXECUTION
  -> 同一对话切换 Orchestrator
```

安装、Git 初始化、基线提交、技术设计确认和最终执行授权是相互独立的关卡；前一个确认不会隐含后一个确认。

## 3. 自主执行流程

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

UI 与 Plan 审查最多3轮；Plan 通过后不再要求人工确认。

## 4. 两种输入

### `matt_spec_only`

必须提供领域语言、Spec 和已经确认的实施技术基线。默认 `ui_mode: auto_detect`：

- 无 UI：`none`
- 复用已有设计：`reuse_existing`
- 全新 UI 且无基线：`auto_generate`

### `matt_plus_uiux`

除 Matt 输入外，还提供交接清单、UI Contract、tokens、组件规格和状态矩阵；`ui_mode` 为 `provided`。

## 5. 人与 AI 的边界

人负责：确认产品和技术基线、裁决权威冲突、授权安装/Git/正式启动、安全或不可逆操作、外部副作用和最终体验。

AI 负责：发现输入、执行机械准备、生成输入、Intake、UI 基线、Implementation Plan、隔离 worktree 提交、TDD、测试、调试、复测、审查与证据。

历史 issue 中“测试已通过”只能作为历史证据，不能替代本轮验证。

## 6. 安全特性

- `install-harness.ps1` 默认只预览；`-Apply` 才写入。
- 不复制 `.git`，不覆盖不同内容的现有文件。
- 已存在的 `.gitignore`、`.gitattributes` 只报告，不覆盖。
- `initialize-project.ps1` 默认只检查；需单独授权初始化。
- execution-input 初始为 `execution_authorized: false`。
- 只有 Bootstrap 再次通过且授权为真，才进入 Orchestrator。
- merge、push、deploy、release、破坏性清理始终需要单独授权。

## 7. 手工与诊断入口

安装预览：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-harness.ps1 -TargetRoot <project>
```

Bootstrap 检查：

```powershell
powershell -ExecutionPolicy Bypass -File .\checks\bootstrap-check.ps1 `
  -TargetRoot <project> `
  -ExecutionInputPath <project>\.harness\execution-input.json
```

完整自检：

```powershell
powershell -ExecutionPolicy Bypass -File .\checks\validate-harness.ps1
powershell -ExecutionPolicy Bypass -File .\tests\ask-harness-scripts.test.ps1
```

## 8. 恢复与限制

`.harness/progress.md` 是执行恢复依据。中断后用 Git 历史核对 commit SHA，从第一个未闭合事件继续。

Harness 是 Codex 主对话中的控制机制，不是后台服务；任务关闭后不会常驻运行。它不持有生产凭证，也不自动执行 Git 集成或发布。
