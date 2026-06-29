# Deliverable Gate Spec

## Purpose

`deliverable-gate` ensures anything handed to a human, reviewer, Multica, Feishu, Obsidian, or a future session has enough conclusion, evidence, verification, owner, next action, and side-effect state to be trusted.

This gate is local-only. It does not approve or perform remote writes.

## When To Run

Run before any of these actions:

- Final answer or handoff after a non-trivial task.
- Review packet generation.
- Multica or Feishu comment/status/writeback draft.
- Obsidian generated sync for a run summary.
- Team sharing, release notes, or case pack creation.

## Required Signals

| Signal | Minimum Standard | Example Evidence |
|---|---|---|
| Purpose / goal | What this deliverable is for. | Task objective, issue, audience. |
| Conclusion / result | The main answer or final status is visible first. | Done/blocked/needs review, key findings. |
| Evidence / artifacts | Paths, links, reports, diffs, or generated files are listed. | `runs/<id>/`, docs path, test output. |
| Verification | How the result was checked, or why it was not checked. | Commands, gate reports, manual inspection. |
| Owner / actor | Who executed, reviews, or owns next decision. | AI actor, DRI, reviewer, human approver. |
| Next action | Follow-up, blocker, or recommended next step is explicit. | Continue loop, approve writeback, rerun test. |
| Side-effect state | External writes and approvals are declared. | None, pending approval, written and read back. |

## Result Semantics

| Result | Meaning | Next Step |
|---|---|---|
| PASSED | Deliverable can be handed off or used for a writeback decision. | Continue to `gate-policy-check`, review, or writeback gate. |
| FAILED | Deliverable lacks evidence or decision-ready structure. | Add missing conclusion, evidence, verification, or side-effect state. |
| WARN | Non-critical evidence is weak. | Continue only if captured and acceptable. |

## Strict Run Mode

When `--run-id` and `--strict` are used, the run must include core evidence files required by the current local protocol. Missing core evidence should block handoff/writeback unless a structured human exception exists.

## Acceptance

The gate is acceptable when:

- It produces a report with result, score, checks, and remote-write=false evidence.
- It fails when verification, artifacts, or side-effect state are absent.
- It can evaluate either a standalone artifact or a standard `runs/<run-id>/` directory.

## Command

```bash
./scripts/deliverable-gate.sh \
  --input <artifact.md> \
  --issue <ISSUE-ID> \
  --output <run-or-task>/deliverable-gate.md
```

For standard runs:

```bash
./scripts/deliverable-gate.sh --run-id <run-id> --strict
```
