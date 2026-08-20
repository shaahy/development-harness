# Ask Harness Bootstrap Flow

## Outcome

The root conversation moves from declared Matt artifacts to one of two truthful outcomes:

- `READY_FOR_START_CONFIRMATION`: project Harness, Git baseline, technical design, execution input, and Intake passed; execution is not authorized.
- A structured blocker with one decision question.

After start authorization, produce `READY_FOR_AUTONOMOUS_EXECUTION` and continue as Orchestrator in the same conversation.

## State Sequence

| State | Required evidence | Allowed next action |
|---|---|---|
| `VERIFYING_HARNESS` | Project-local Harness validation | Inspect declared inputs |
| `DISCOVERING_INPUTS` | Project root and declared paths | Read and classify inputs |
| `INPUTS_MAPPED` | Authority table and conflicts | Ask one authority question or inspect Git |
| `GIT_INSPECTED` | Repository, remote, branch, HEAD, dirty state | Resolve one Git blocker or continue |
| `TECHNICAL_DESIGN` | Missing decisions listed | Use `superpowers:brainstorming`; no code |
| `BASELINE_READY` | Approved Spec/ADR and clean baseline commit | Generate draft input |
| `INTAKE_CHECKING` | Draft input and deterministic checks | Repair one blocker or request final start |
| `READY_FOR_START_CONFIRMATION` | Bootstrap PASS, authorization false | Ask one final question |
| `READY_FOR_AUTONOMOUS_EXECUTION` | Authorization true and repeated PASS | Load Orchestrator and continue |

Use exact contract states. A semantic or authority contradiction is `BLOCKED_INPUT_CONFLICT`; Git or template-remote failures are `BLOCKED_GIT`.

## Project-Local Harness

The project template already contains the Harness. Locate the repository root by walking upward from this Skill until `HARNESS.md`, `AGENTS.md`, and `harness.config.yaml` are found, then run `checks/validate-harness.ps1`.

- Do not request global Skill installation.
- Do not copy the Harness into the same project again.
- Do not inspect or branch on host product names.
- Do not replace real multi-agent execution with a single-agent fallback.
- A validation failure is a real blocker; report the failed check and repair only safe deterministic drift.

## Input Classification

Use this exact authority table shape:

| File | Classification | Approval status | Binding scope | Conflict |
|---|---|---|---|---|

Classifications:

- `formal_authority`: approved Spec, ADR, UI Contract, or equivalent.
- `approved_decision`: confirmed supporting decision record.
- `reference`: useful but non-binding material.
- `historical_evidence`: old implementation or test claims; never current PASS evidence.
- `conflict`: incompatible statements without a higher authority.

Do not infer approval from filenames, completeness, or confident language. Current explicit user decisions outrank stored documents and must be recorded.

## Git and Template Remote

Inspect the repository before creating a baseline:

- Existing dirty repository: do not stage, commit, stash, reset, or create a worktree until user changes are identified and safely isolated.
- Existing clean repository: preserve branch and history.
- Missing repository: preview `scripts/initialize-project.ps1`; ask before applying.
- `origin` equals the `template_repository` recorded in `harness-source.yaml`: return `BLOCKED_GIT`. The user must create/select a product repository or explicitly keep the work local before product commits.
- Repository created through GitHub `Use this template`: preserve its product `origin`; no extra remote setup is required.

Before a baseline commit, report the exact staged-file whitelist and ask authorization. Never use broad staging when unrelated changes exist.

## Technical Readiness

Implementation-critical choices include platform/runtime, framework, process/module boundaries, persistence, migrations, security boundary, error recovery, build/launch contract, and verification strategy.

If absent or contradictory, use `superpowers:brainstorming`. Resolve one material decision at a time and write an ADR only after confirmation. UI details may remain `auto_detect`; product behavior may not.

## Input and Intake

Use `scripts/new-execution-input.ps1` only after Spec and technical-design approval. The first run omits `-ExecutionAuthorized`.

Then run:

```powershell
checks/bootstrap-check.ps1 -TargetRoot <project> -ExecutionInputPath <project>/.harness/execution-input.json
```

Do not translate a failing result into PASS. Repair deterministic failures automatically when safe; semantic conflicts require the user.

## Final Handoff

At `READY_FOR_START_CONFIRMATION`, report confirmed authorities, Harness version, Git branch and baseline commit, approved technical ADR, input path and UI mode, Intake result, and remaining risks.

Ask only: `是否授权现在开始自主执行？`

If yes, regenerate the input with `-ExecutionAuthorized`, rerun Bootstrap, require `READY_FOR_AUTONOMOUS_EXECUTION`, load `roles/orchestrator.md`, create the execution Todo, and proceed without a new conversation or pasted handoff prompt.

## Common Mistakes

| Mistake | Required correction |
|---|---|
| Reinstalling a Harness already present in the template | Validate the project-local Harness |
| Branching on host product names | Use the fixed multi-agent execution contract |
| Treating the template repository as the product remote | Stop with `BLOCKED_GIT` before product commits |
| Asking several decisions together | Ask one material question, record it, resume |
| Treating old green tests as current proof | Mark historical and regenerate evidence |
| Marking Intake PASS with unresolved architecture | Use brainstorming and an approved ADR first |
| Starting a new root task after Intake | Continue in the same root conversation |
