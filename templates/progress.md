# Harness Progress Ledger

> Append-only. Never delete or rewrite prior events. Git history and this ledger are the recovery authority.

## Run Identity

- Feature ID:
- Input profile:
- UI mode:
- Approved Spec:
- Auto-generated plan:
- Plan review result:
- Target repository:
- Worktree:
- Branch:
- Base commit:
- Started at:
- Current state: `READY_FOR_INTAKE`

## Task Index

| Task | Status | Base | Commit | Test report | Review report |
|---|---|---|---|---|---|

## Event Ledger

Append events using this exact shape:

```yaml
- event_id: EVT-0001
  occurred_at: 2026-08-18T00:00:00+08:00
  task_id: TASK-001
  from_state: EXECUTING
  event: TASK_DISPATCHED
  to_state: TASK_IMPLEMENTING
  actor: orchestrator
  base_commit: null
  resulting_commit: null
  evidence: []
  next_action: wait_for_implementer
```

## Recovery Check

- [ ] Ledger identity matches the approved Spec and generated plan.
- [ ] Recorded commits exist in `git log`.
- [ ] Completed and approved tasks are not re-dispatched.
- [ ] An unfinished fix/review round resumes at its next step.
- [ ] Current state has exactly one valid next transition.
