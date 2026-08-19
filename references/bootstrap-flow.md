# Ask Harness Bootstrap Flow

## Outcome

The root conversation moves from declared Matt artifacts to one of two truthful outcomes:

- `READY_FOR_START_CONFIRMATION`: every preparation and Intake gate passed, but execution is not authorized.
- A structured blocker with one decision question.

Use exact contract states. A semantic or authority contradiction is `BLOCKED_INPUT_CONFLICT`; do not invent synonym states.

After the user authorizes start, produce `READY_FOR_AUTONOMOUS_EXECUTION` and continue as Orchestrator in the same conversation.

## State Sequence

| State | Required evidence | Allowed next action |
|---|---|---|
| `DISCOVERING_INPUTS` | Project root and declared paths | Read and classify inputs |
| `INPUTS_MAPPED` | Authority table and conflicts | Ask one authority question or inspect installation |
| `HARNESS_PREVIEWED` | Installer dry-run JSON | Ask for scoped installation authorization |
| `HARNESS_INSTALLED` | `INSTALLED` or compatible existing files | Inspect Git |
| `GIT_PREVIEWED` | Repository state JSON | Ask for initialization/isolation decision |
| `TECHNICAL_DESIGN` | Missing decisions listed | Use `superpowers:brainstorming`; no code |
| `BASELINE_READY` | Approved Spec/ADR and clean baseline commit | Generate draft input |
| `INTAKE_CHECKING` | Draft input and deterministic checks | Repair one blocker or request final start |
| `READY_FOR_START_CONFIRMATION` | Bootstrap check PASS, authorization false | Ask one final question |
| `READY_FOR_AUTONOMOUS_EXECUTION` | Authorization true and repeated PASS | Load Orchestrator and continue |

## Input Classification

Use this exact authority table shape:

| File | Classification | Approval status | Binding scope | Conflict |
|---|---|---|---|---|

Classifications:

- `formal_authority`: approved Spec, ADR, UI Contract or equivalent.
- `approved_decision`: confirmed supporting decision record.
- `reference`: useful but non-binding material.
- `historical_evidence`: old implementation/test claims; never current PASS evidence.
- `conflict`: incompatible statements without a higher authority.

Do not infer approval from filenames, completeness, or confident language. Current explicit user decisions outrank stored documents and must be recorded.

## Installation

Locate the scripts relative to the loaded Skill directory.

1. Run `scripts/install-harness.ps1 -TargetRoot <project>` without `-Apply`.
2. If `BLOCKED_COLLISION`, do not copy anything. Report every path and ask how to merge the first material conflict.
3. If `READY_TO_INSTALL`, show the exact target and mutation scope, then ask authorization.
4. On approval rerun with `-Apply`; verify `INSTALLED`.

The installer never copies `.git`, never overwrites differing files, and preserves existing `.gitignore`/`.gitattributes` with warnings.

## Git and Baseline

Run `scripts/initialize-project.ps1` without `-Apply` first.

- No repository: ask before initialization, then apply.
- Existing dirty repository: do not stage, commit, stash, reset, or create a worktree until user changes are identified and safely isolated.
- Existing clean repository: preserve branch and history.

Before creating a baseline commit, report the exact staged-file whitelist and ask authorization. Never use broad staging when unrelated changes exist.

## Technical Readiness

Implementation-critical choices include platform/runtime, framework, process/module boundaries, persistence, migrations, security boundary, error recovery, build/launch contract, and verification strategy.

If these are absent or contradictory, use `superpowers:brainstorming`. Resolve one material decision at a time and write an ADR only after confirmation. UI details may remain `auto_detect`; product behavior may not.

## Input and Intake

Use `scripts/new-execution-input.ps1` only after Spec and technical design approval. The first run omits `-ExecutionAuthorized`.

Then run:

```powershell
checks/bootstrap-check.ps1 -TargetRoot <project> -ExecutionInputPath <project>/.harness/execution-input.json
```

Do not translate a failing result into PASS. Repair deterministic failures automatically when safe; semantic conflicts require the user.

## Final Handoff

At `READY_FOR_START_CONFIRMATION`, report:

- confirmed authorities;
- Harness installation status;
- Git branch and baseline commit;
- approved technical ADR;
- input path and UI mode;
- Intake result;
- remaining risks.

Ask only: `是否授权现在开始自主执行？`

If yes, rerun the input generator with `-ExecutionAuthorized`, rerun Bootstrap check, require `READY_FOR_AUTONOMOUS_EXECUTION`, load `roles/orchestrator.md`, create the execution Todo, and proceed. No new conversation and no pasted handoff prompt.

## Common Mistakes

| Mistake | Required correction |
|---|---|
| Giving the user copy/JSON/PowerShell instructions | Use the bundled scripts yourself |
| Treating Harness as a daemon or service | It is a conversation-level control harness |
| Asking several decisions together | Ask one material question, record it, resume |
| Treating old green tests as current proof | Mark historical and regenerate evidence |
| Marking Intake PASS with unresolved architecture | Use brainstorming and approved ADR first |
| Starting a new root task after Intake | Continue in the same root conversation |
| Inferring start authorization from installation approval | Ask the final execution question separately |
