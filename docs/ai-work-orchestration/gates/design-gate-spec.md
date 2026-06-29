# Design Gate Spec

## Purpose

`design-gate` prevents execution from starting when the solution is not reviewable, executable, or verifiable. It turns design from an implicit conversation into an explicit artifact with decisions, risks, validation, and side-effect boundaries.

This gate is local-only. It must not read remote systems or perform external writes.

## When To Run

Run before implementation or long-running execution when any of these are true:

- The task changes code, scripts, policy, routing, evidence, memory, writeback, or docs used by others.
- The task has more than one plausible solution path.
- The task may require approval, external systems, or rollback planning.
- The task is larger than a tiny local patch.

Documentation-only or inspection-only tasks may skip design if `gate-policy` allows it and the deliverable gate remains required.

## Required Signals

| Signal | Minimum Standard | Example Evidence |
|---|---|---|
| Background / problem | Why this design exists and what problem it solves. | Requirement gate report, issue, previous failure. |
| Goal / objective | What execution must achieve. | Desired behavior, artifact, or measurable outcome. |
| Scope / non-goal | Boundaries and exclusions are explicit. | Files, modules, no remote writes, no deploy. |
| Solution / architecture | Implementation approach is concrete enough to review. | Module changes, script behavior, data flow. |
| Dependencies / impact | Affected components and dependencies are named. | Scripts, configs, docs, Feishu/Multica adapters. |
| Risk / fallback / rollback | Failure modes and recovery plan are stated. | Revert files, dry-run, feature flag, skip writeback. |
| Acceptance / verification | How completion will be proven. | Test commands, gate reports, strict verification. |
| Open decisions | Human decisions and unknowns are listed. | Approval boundary, reviewer choice, field mapping. |
| Owner / reviewer | Responsible actor and review path are visible. | DRI, reviewer, human approval role. |
| Side-effect policy | External side effects are declared and gated. | Approval policy, dry-run first, readback requirement. |

## Result Semantics

| Result | Meaning | Next Step |
|---|---|---|
| PASSED | Design is ready for execution. | Execute the planned slice and collect evidence. |
| FAILED | Design is not executable or reviewable. | Fix design or ask for human decision. |
| WARN | Design is usable but has weak optional evidence. | Continue only if risk is acceptable and warnings are captured. |

## Strict Mode

`--strict` requires explicit evidence/source basis. Use it for risky tasks, cross-system work, policy changes, and anything that may later be reviewed or shared.

## Acceptance

The gate is acceptable when:

- It produces a report with result, score, required failures, warnings, and remote-write=false evidence.
- It blocks execution when solution, impact, verification, or side-effect policy is missing.
- It supports task-type policy through `gate-policy-check` rather than hardcoding every workflow.

## Command

```bash
./scripts/design-gate.sh \
  --input <design.md> \
  --issue <ISSUE-ID> \
  --strict \
  --output <run-or-task>/design-gate.md
```
