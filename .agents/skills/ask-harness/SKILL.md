---
name: ask-harness
description: Use when 模板项目中已有 Matt 领域语言、CONTEXT、Spec、PRD、设计产物或相关权威文件，需要在自主多 Agent 开发前完成引导式准备。
---

# Ask Harness

## 概述

把用户声明的 Matt 产物转化为经过验证的 Harness 交接输入。本技能随项目模板安装，负责引导用户完成必要决策、执行确定性准备，并在最终授权后继续担任 Orchestrator。

本 Harness 面向具备完整能力的多 Agent 开发环境。不要识别宿主、探测能力、添加适配器或设计降级执行模式。

## 交互语言

所有面向用户的对话、提问、Todo、进度、报告、阻断说明和下一步行动必须使用简体中文，并称呼用户为“怡哥”。状态码、事件名、JSON/YAML 字段、命令、路径、技能名称和代码标识保持原文；展示状态码时附中文解释。

## 必须执行的流程

先读取 [references/bootstrap-flow.md](references/bootstrap-flow.md)，然后维护可见 Todo。

1. 定位同时包含 `HARNESS.md`、`AGENTS.md` 和 `harness.config.yaml` 的项目根目录。
2. 运行 `checks/validate-harness.ps1`。克隆模板后 Harness 已经安装，不要要求用户复制文件或全局安装。
3. 只发现用户声明的 Matt 文件及其直接相关文件，并分类为正式权威、已批准决策、参考资料、历史证据或冲突。
4. 检查 Git，保留既有历史和用户改动。若尚未初始化 Git，先预览 `scripts/initialize-project.ps1`，获得授权后再应用。若 `origin` 仍指向 Harness 模板仓库，在产品提交前停止并请求用户决定产品仓库。
5. 审查语义就绪度。产品或权威冲突每次只请求一个用户决策；历史“通过”的测试不能作为当前证据。
6. 缺少实施关键技术设计时，**必须使用子技能：** `superpowers:brainstorming`。将确认后的结果记录为 ADR，不得开始编码。
7. 获得明确的基线提交授权，只提交获批的 Bootstrap 文件。
8. 生成 `execution_authorized: false` 的 `.harness/execution-input.json`，然后运行 `checks/bootstrap-check.ps1`。
9. 到达 `READY_FOR_START_CONFIRMATION` 时，只提出一个最终问题：是否开始自主执行。
10. 获得授权后，重新生成已授权输入，再次检查，读取 `roles/orchestrator.md`，并在同一根对话中继续。

可用工具能够完成操作时，不要要求用户复制文件、编写 JSON、运行准备命令或新开对话。

## 权限边界

Git 初始化、提交、技术基线确认和自主执行是相互独立的关口；前一个授权不代表后一个授权。merge、push、deploy、release、破坏性清理、凭证和外部副作用不在本技能权限内。

## 停止状态

遇到权威文件冲突、未解决的产品行为、无法隔离的脏 Git、模板仓库被用作产品远程仓库、缺少凭证、不可逆操作或确定性检查失败时，只返回一个结构化阻断项和一个问题。

只使用契约状态：权威或语义冲突为 `BLOCKED_INPUT_CONFLICT`，输入缺失为 `BLOCKED_INPUT`，Git 失败为 `BLOCKED_GIT`，不安全文件冲突为 `BLOCKED_COLLISION`。不得创造同义状态名。
