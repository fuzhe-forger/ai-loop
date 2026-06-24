---
name: ponytail-cn
description: Minimal-coding and anti-overengineering workflow for implementation phases. Use when the user says Ponytail/马尾/最小实现/YAGNI/别过度设计/少写代码/复用优先, or when Sinan/Loop hands off a scoped coding slice after planning and wants the coding agent to implement the smallest safe change. Do not use for broad product planning, architecture exploration, security-critical design approval, or tasks where completeness is more important than minimality.
---

# Ponytail-CN

Apply the lazy-senior-dev ladder: be lazy about the solution, never lazy about understanding, safety, or validation.

## Core Rule

Write only what the task needs. Never cut validation, error handling, security, data-loss protection, accessibility, compatibility, or user-approved acceptance criteria.

## Before Editing

1. Confirm the scoped task and acceptance criteria.
2. Read the real flow touched by the change; do not guess.
3. Check existing code, helpers, config, tests, and conventions.
4. Stop and ask only if missing information could cause unsafe or broad changes.

## The Ladder

Before adding code, stop at the first rung that works:

1. Does this need to exist? If not, skip it.
2. Is it already in this codebase? Reuse it.
3. Does the standard library do it? Use it.
4. Does the platform/native feature do it? Use it.
5. Is an installed dependency already doing it? Use it.
6. Can a small local expression or function solve it? Use that.
7. Only then write the minimum new code that passes acceptance.

## Implementation Rules

- Prefer deleting or simplifying over adding.
- Prefer direct code over new abstractions.
- Prefer existing names, files, and patterns.
- Avoid new dependencies unless explicitly justified and approved.
- Avoid new frameworks, base classes, registries, factories, generic layers, or config systems unless the current code already requires them.
- Keep the diff business-scoped; do not fix unrelated issues.
- Add tests only when the repo already has an adjacent test pattern or the task is test-related.
- Validate with the narrowest useful command first, then broader checks when appropriate.

## Review Checklist

Before finalizing, check:

- What did I avoid building?
- Did I reuse something already present?
- Did I add any dependency or abstraction? If yes, why was it necessary?
- Is the diff smaller than the problem?
- Did I preserve safety, validation, compatibility, and accessibility?
- Is there evidence: test/build/lint/log, or a clear reason it was not run?

## Sinan / Loop Integration

For resumed or truncated Loop coding slices:

- Start from the latest `runs/<run-id>/summary.md` or handoff artifact.
- Do not reread large logs unless the summary says they are canonical.
- Implement one smallest verifiable slice.
- Write evidence paths and validation results back to the run summary.
- If the task expands, stop and return a smaller slice proposal.

## References

Read `references/minimal-coding-ladder.md` for the reusable policy and failure modes.
