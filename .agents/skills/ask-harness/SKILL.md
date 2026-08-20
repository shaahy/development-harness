---
name: ask-harness
description: Use when a template-based project contains Matt domain language, CONTEXT, Spec, PRD, design artifacts, or related authority files and needs guided preparation before autonomous multi-agent development.
---

# Ask Harness

## Overview

Turn user-declared Matt artifacts into a verified Harness handoff. This skill is installed with the project template. Guide the user through decisions, perform deterministic preparation, and continue as Orchestrator after final authorization.

This Harness targets a fully capable multi-agent development environment. Do not identify the host, probe capabilities, add adapters, or design fallback execution modes.

## Required Flow

Read [references/bootstrap-flow.md](references/bootstrap-flow.md), then maintain a visible Todo.

1. Locate the project root containing `HARNESS.md`, `AGENTS.md`, and `harness.config.yaml`.
2. Run `checks/validate-harness.ps1`. A cloned template is already installed; do not ask the user to copy or globally install Harness files.
3. Discover only the Matt files declared by the user or directly relevant to them. Classify each as formal authority, approved decision, reference, historical evidence, or conflict.
4. Inspect Git. Preserve existing history and user changes. If Git is absent, preview `scripts/initialize-project.ps1`, obtain authorization, then apply. If `origin` still points to the Harness template repository, stop before product commits and request the product-repository decision.
5. Audit semantic readiness. Product or authority conflicts require one user decision at a time. Historical “passed” tests are never current evidence.
6. When implementation-critical technical design is missing, **REQUIRED SUB-SKILL:** use `superpowers:brainstorming`. Record the approved result as an ADR; do not code.
7. Obtain explicit baseline-commit authorization and commit only the approved bootstrap files.
8. Generate `.harness/execution-input.json` with `execution_authorized: false`, then run `checks/bootstrap-check.ps1`.
9. At `READY_FOR_START_CONFIRMATION`, ask exactly one final question: whether to begin autonomous execution.
10. On approval, regenerate the input with authorization, rerun the check, read `roles/orchestrator.md`, and continue in the same root conversation.

Do not ask the user to copy files, write JSON, run preparation commands, or open another conversation when the available tools can complete the action.

## Permission Boundary

Git initialization, commits, technical-baseline approval, and autonomous execution are separate gates. Earlier approval never implies a later gate. Merge, push, deploy, release, destructive cleanup, credentials, and external side effects remain outside this skill.

## Stop States

Return one structured blocker and one question for differing authority files, unresolved product behavior, dirty Git that cannot be isolated, a template repository used as the product remote, missing credentials, irreversible actions, or failed deterministic checks.

Use only contract statuses: authority or semantic conflict is `BLOCKED_INPUT_CONFLICT`, missing inputs are `BLOCKED_INPUT`, Git failures are `BLOCKED_GIT`, and unsafe file collisions are `BLOCKED_COLLISION`. Do not invent synonymous state names.
