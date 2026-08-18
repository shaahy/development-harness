# Simulated Project

这个目录不包含生产应用。`scenario.json` 用确定性事件验证 Harness 的核心路由：

- Matt-only 输入可自动进入 UI 补齐或规划。
- UI 与 Plan 审查失败会自动返工。
- Plan 审查通过后不经过人工确认，直接进入执行准入。
- 测试失败必须交给 Debugger。
- 修复完成必须返回独立 Tester 复测。
- 测试通过才能进入独立 Reviewer。
- 调试达到3次必须触发架构断路器。
- 最终审查通过只能进入人工验收，不能自动发布。

运行根目录 `checks/validate-harness.ps1` 即可执行全部模拟场景。
