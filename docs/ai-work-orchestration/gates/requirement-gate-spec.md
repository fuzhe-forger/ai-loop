# Requirement Gate Spec

## Purpose

`requirement-gate` stops blank-slate or ambiguous requests from entering design or development before the task has enough structure to be understood, estimated, verified, and governed.

This gate is local-only. It must not read Multica, write Feishu, update remote Git, deploy, delete data, or perform any external side effect.

## When To Run

Run before solution design when any of these are true:

- The task starts from a user request, Multica issue, Feishu note, or informal chat message.
- The request changes behavior, process, policy, evidence, memory, writeback, or user-facing output.
- The task may require external side effects, long-running execution, or human approval.
- The AI would otherwise need to infer background, scope, acceptance, or constraints.

Skip only for tiny local inspection tasks that do not modify files and do not need a deliverable.

## Required Signals

| Signal | Minimum Standard | Example Evidence |
|---|---|---|
| Problem context | Current state, pain point, or triggering reason is stated. | Requirement draft, issue description, user message. |
| User / stakeholder / scenario | Affected user, reviewer, owner, or scenario is named. | Business actor, DRI, service owner. |
| Goal / outcome | Expected result is stated in human-verifiable terms. | Target behavior, decision, artifact, or status. |
| Scope / non-goal / boundary | What is in scope and out of scope is explicit. | File/module scope, no remote write, no deploy. |
| Acceptance criteria | Completion can be checked without guessing. | Commands, document sections, visible output, review checklist. |
| Constraints / assumptions | Time, permission, compatibility, data, or process limits are stated. | Approval policy, sandbox, deadline, dependency assumptions. |
| Dependencies / inputs | Upstream systems, files, people, data, or links are identified. | Repo path, Feishu URL, Multica issue, API docs. |
| Risks / open questions | Unknowns and decision points are visible. | Missing owner, unclear writeback target, unverified data. |
| Priority / timeline | Urgency, deadline, or ordering is clear enough to plan. | P0/P1/P2, deadline, next milestone. |
| Side-effect policy | External writes, deletes, deploys, installs, remote Git, and production access are declared. | Approval boundary, dry-run requirement, no-write statement. |

## Result Semantics

| Result | Meaning | Next Step |
|---|---|---|
| PASSED | Requirement has enough structure to enter design or execution planning. | Continue to `generate-plan` or `design-gate`. |
| FAILED | Required signals are missing or traceability is broken. | Ask clarification questions and do not design or execute. |
| WARN | Optional or quality signals are weak. | Continue only if risk is low and warnings are captured. |

## Strict Mode

`--strict` is required when the task has high ambiguity, external side effects, cross-team impact, or a long execution window. Strict mode also requires explicit human confirmation or communication evidence.

## Clarification Output

When the gate fails, the clarification draft must include:

- Why clarification is needed.
- Questions grouped by missing signal.
- A suggested requirement skeleton.
- Side-effect and approval questions when applicable.

## Acceptance

The gate is acceptable when:

- It produces a markdown report with result, score, checks, clarifying questions, and remote-write=false evidence.
- Failed requirements generate actionable questions instead of generic rejection.
- It can be rerun after the user updates the requirement draft.
- It remains local-only and deterministic.

## Command

```bash
./scripts/requirement-gate.sh \
  --input <requirement.md> \
  --issue <ISSUE-ID> \
  --output <run-or-task>/requirement-gate.md \
  --clarification-output <run-or-task>/clarification.md
```
