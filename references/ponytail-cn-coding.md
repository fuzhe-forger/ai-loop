# Ponytail-CN Coding Capability

## Purpose

`ponytail-cn` is the local minimal-coding capability for Sinan / Loop coding slices.

It is inspired by the public Ponytail project, but it is not installed as an external plugin and does not enable upstream hooks. Sinan uses a local Codex skill at `/home/user/.codex/skills/ponytail-cn` so the behavior remains inspectable, local-first, and compatible with existing gates.

## When To Use

Use `ponytail-cn` when a Loop has already produced a scoped coding task or when a long Loop is truncated and the next agent should continue implementation without expanding scope.

Good triggers:
- “后续 Loop 截断的编码由他来做”
- “最小实现”
- “不要过度设计”
- “复用现有代码”
- “小 diff 修复”
- “CR 里找可删/可简化的点”

Do not use it as the primary mode for:
- broad product planning
- ambiguous requirement discovery
- architecture north-star decisions
- security-critical approval decisions
- destructive/external side-effect operations

## Execution Contract

A Ponytail-CN coding slice must:

1. Start from the latest `summary.md` or handoff artifact.
2. Identify one smallest verifiable change.
3. Search existing code/helpers before writing new code.
4. Avoid new dependencies unless explicitly approved.
5. Avoid new abstractions unless the existing codebase already demands them.
6. Run narrow validation first; run broader validation when appropriate.
7. Write evidence paths and validation results back to the Loop run.
8. Stop and return to planning if the task expands beyond the slice.

## Safety Boundary

Minimal coding never means minimal safety.

Never remove or weaken:
- validation
- auth/security checks
- data-loss protection
- compatibility behavior
- error handling required by acceptance criteria
- accessibility requirements
- side-effect gates
- approval boundaries

## Handoff Template

```markdown
# Ponytail-CN Coding Handoff

## Scope

- One-sentence task:
- Acceptance:
- Files likely touched:

## Existing Evidence

- Latest summary:
- Relevant logs/tests:
- Files not to reread:

## Minimality Plan

- Reuse candidate:
- Standard/platform feature:
- New code needed:
- What not to build:

## Validation

- Narrow command:
- Broader command:
- Stop condition:
```

## Local Skill

- Skill path: `/home/user/.codex/skills/ponytail-cn/SKILL.md`
- Repository copy: `skills/ponytail-cn/SKILL.md`
- Policy reference: `/home/user/.codex/skills/ponytail-cn/references/minimal-coding-ladder.md`
