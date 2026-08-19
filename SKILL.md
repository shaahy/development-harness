---
name: ask-harness
description: Use when a project contains Matt domain language, CONTEXT, Spec, PRD, design artifacts, or related authority files and the user wants guided preparation before autonomous multi-agent development.
---

# Ask Harness

## Overview

Turn user-declared Matt artifacts into a verified Harness handoff. Guide the user through decisions; perform deterministic preparation yourself; after final authorization, continue as Orchestrator in the same root conversation.

**Do not ask the user to copy files, write JSON, or run commands when the available tools can do it. Ask only for decisions or authority that tools cannot supply.**

## Required Flow

Read [references/bootstrap-flow.md](references/bootstrap-flow.md), then maintain a visible Todo.

1. Discover the project root and only the files the user declared or that are directly relevant.
2. Classify each input as formal authority, approved decision, reference, historical evidence, or conflict.
3. If Harness is absent, run `scripts/install-harness.ps1` without `-Apply`. Report exact scope/collisions and obtain authorization before rerunning with `-Apply`.
4. Inspect Git. Never overwrite, stage, commit, or mix existing user changes. If Git is absent, preview `scripts/initialize-project.ps1`, obtain authorization, then apply.
5. Audit semantic readiness. Product or authority conflicts require one user decision at a time. Historical “passed” tests are never current evidence.
6. When implementation-critical technical design is missing, **REQUIRED SUB-SKILL:** use `superpowers:brainstorming`. Record the approved result as an ADR; do not code.
7. Obtain an explicit baseline-commit authorization and commit only the approved bootstrap files.
8. Generate `.harness/execution-input.json` with `execution_authorized: false`, then run `checks/bootstrap-check.ps1`.
9. At `READY_FOR_START_CONFIRMATION`, ask exactly one final question: whether to begin autonomous execution.
10. On approval, regenerate the input with authorization, rerun the check, read `roles/orchestrator.md`, and continue in this same conversation. Do not merely print a prompt for another task.

## Permission Boundary

Installation, Git initialization, commits, technical-baseline approval, and autonomous execution are separate gates. Earlier approval never implies a later gate. Merge, push, deploy, release, destructive cleanup, credentials, and external side effects remain outside this skill.

## Stop States

Return one structured blocker and one question for: differing authority files, unresolved product behavior, dirty Git that cannot be isolated, unsafe collisions, missing credentials, irreversible actions, or failed deterministic checks.

Use only contract statuses: authority/semantic conflict is `BLOCKED_INPUT_CONFLICT`, missing inputs are `BLOCKED_INPUT`, Git failures are `BLOCKED_GIT`, and installer path collisions are `BLOCKED_COLLISION`. Do not invent synonymous state names.
