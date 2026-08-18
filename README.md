# Spec 后自主执行多 Agent Harness

面向 Codex App 的仓库级 Harness。用户确认 Matt 的领域语言与 Spec 后，它自动处理条件性 UI 设计、Implementation Plan、实施、测试、调试和审查，直到生成最终验收包或遇到真实的人类阻断。

## 1. 边界

- 不是平台或常驻服务，而是可复制到目标仓库的规则、状态机、角色、契约和检查脚本。
- Matt 系列技能负责产品澄清、领域语言和 Spec；这些内容仍由人确认。
- `ui-ux-pro-max` 是可选入口；缺少必要 UI 基线时由 Harness 自动调用。
- Implementation Plan 由 Superpowers `writing-plans` 自动生成并独立审查，不需要人确认。
- 执行默认使用 `subagent-driven-development`，随后自动进行 TDD、修复、复测和审查。

## 2. 两种输入

### `matt_spec_only`

必须提供领域语言/`CONTEXT.md`、Spec 和目标仓库。默认使用 `auto_detect`，Harness 自动选择以下实际模式：

- `none`：后端、CLI 或没有 UI 的任务。
- `reuse_existing`：复用仓库现有设计系统和组件。
- `auto_generate`：全新 UI 且没有设计基线；Harness 自动运行 `ui-ux-pro-max`。

### `matt_plus_uiux`

在 Matt 输入之外提供已完成的 UI 基线，`ui_mode` 固定为 `provided`。基线包含交接清单、UI Contract、tokens、组件规格和状态矩阵。

## 3. 自动流程

```text
Matt 领域语言 + 已批准 Spec
  -> Intake 校验与 UI 分类
  -> 按需 ui-ux-pro-max 生成基线 <-> 独立 UI 审查
  -> writing-plans 生成计划 <-> 独立 Plan 审查
  -> 执行准入
  -> Implementer -> Tester
  -> 测试失败：Debugger -> Tester 复测
  -> 测试通过：Reviewer
  -> 全量回归 -> 最终三轴审查
  -> 人工最终验收
```

UI 和 Plan 审查均最多3轮。Plan 通过后自动进入执行，不询问执行方式。

## 4. 人与 AI 的边界

人负责：确认 Matt Spec 与范围、解决实质产品/权威冲突、批准安全/凭证/不可逆/外部操作、最终体验验收，以及另行授权 merge、push、deploy 或发布。

AI 自主完成：UI 分类与必要基线、计划生成与返工、隔离 worktree 内任务提交、TDD、测试、调试、复测、审查、证据和验收包。

## 5. 启动

先运行 Intake 检查。Matt-only、无 UI 示例：

```powershell
powershell -ExecutionPolicy Bypass -File .\checks\intake-check.ps1 `
  -TargetRoot . `
  -DomainContextPath .\.scratch\feature\CONTEXT.md `
  -SpecPath .\.scratch\feature\spec.md `
  -InputProfile matt_spec_only `
  -UiMode auto_detect
```

通常无需人工选择 UI 模式。只有调用方已经明确知道结果时，才直接使用 `none`、`auto_generate`，或使用 `reuse_existing` 并传入 `-ExistingUiSources`。

Plan 自动生成和审查通过后运行执行准入：

```powershell
powershell -ExecutionPolicy Bypass -File .\checks\readiness-check.ps1 `
  -TargetRoot . `
  -SpecPath .\.scratch\feature\spec.md `
  -PlanPath .\docs\superpowers\plans\2026-08-18-feature.md `
  -PlanEvidencePath .\.harness\plan-evidence.md `
  -UiMode none
```

在 Codex App 中的一次性授权示例：

> 读取根目录 AGENTS.md、配置、工作流和 execution-input。从 Intake 开始自主执行；允许自动补齐必要 UI 基线、自动生成并审查 Implementation Plan、在隔离 worktree 自动提交。不得 merge、push、deploy 或发布；只在命中停止条件或最终验收时询问我。

## 6. 权威顺序

用户当前指令与安全边界 > 已批准 Spec/ADR > 提供或自动审查通过的 UI 基线 > 自动审查通过的 Implementation Plan > Harness 规则 > 原型/截图。

下游不得静默改写上游；ui-ux-pro-max 可选不代表全新 UI 可以没有设计权威。

## 7. 恢复与限制

`.harness/progress.md` 是恢复依据。中断后用 Git 历史核对账本，从第一个未闭合事件恢复，不重复已经通过审查的任务。

Harness 依赖 Codex App 当前任务及其多 Agent 能力，不在后台常驻；不持有生产凭证，也不自动执行 Git 集成或发布。

## 8. 自检

```powershell
powershell -ExecutionPolicy Bypass -File .\checks\validate-harness.ps1
```
