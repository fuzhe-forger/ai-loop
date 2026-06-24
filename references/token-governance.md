# Sinan Token Governance Reference

## Purpose

This reference is the reusable entry point for token governance in Sinan / Loop work.

Use it when a task is long-running, multi-agent, evidence-heavy, or when the user explicitly asks to control context growth. The goal is not to be terse at all costs; the goal is to preserve accuracy, approval safety, and evidence while reducing repeated context, copied artifacts, and stale history pollution.

Canonical full policy: `docs/ai-work-orchestration/29-token-efficiency.md`.

## Start-of-Loop Checklist

Before executing a non-trivial Loop, record the token plan in the in-window Loop framing:

- Context source: which artifact or files will be used as the starting point.
- Read strategy: index/headings/search first, then targeted reads.
- Large-file rule: files over 12KB are not read in full unless justified.
- Evidence rule: cite paths and summaries; do not paste full logs/readbacks.
- Handoff rule: if context grows or phase changes, write `summary.md` or `handoff.md` before continuing.
- Compression trigger: if old chat logs, repeated evidence, or irrelevant history enter context, stop and compress into an artifact.

## During-Loop Rules

- Prefer `rg`, headings, file sizes, and summaries before opening detailed content.
- Use evidence paths over copied text.
- Summarize readback/fetch/json/log outputs before loading details.
- Keep progress updates to: status, evidence path, next action.
- Do not compress approval-critical details: side effects, irreversible operations, risk, rollback, production/deployment targets, permissions, or delete/reset commands.
- Do not alter commands, stack traces, code, error messages, file paths, identifiers, or external IDs while compressing.

## Closeout Requirements

Every non-trivial Loop closeout should include a token section:

```markdown
## Token 使用复盘

- Context source:
- Large files read fully:
- Readback/log handling:
- Evidence references:
- Handoff path:
- Waste avoided:
- Next-loop minimum context:
```

If the Loop has a run directory, run:

```bash
scripts/token-efficiency-audit.sh --run-id <run-id> \
  --output runs/<run-id>/token-efficiency-audit.md \
  --json-output runs/<run-id>/token-efficiency-audit.json
```

For external run directories outside `ai-loop`, use:

```bash
scripts/token-efficiency-audit.sh --path <path-to-run-dir> \
  --output <path-to-run-dir>/token-efficiency-audit.md \
  --json-output <path-to-run-dir>/token-efficiency-audit.json
```

## Handoff Minimum Fields

A handoff should be short and restartable:

- Current goal and acceptance criteria.
- Completed work and evidence paths.
- Current repo state and branch if relevant.
- Approval/side-effect boundary.
- Next minimum slice.
- Files or artifacts not to reread.
- Canonical snapshots if multiple versions exist.

Template: `memory/templates/token-efficient-handoff-template.md`.

## Compression Triggers

Compress before continuing when any of these happen:

- User pastes long prior-chat logs.
- The same evidence is repeated across multiple messages.
- A readback/fetch/log artifact exceeds 12KB.
- The task phase shifts from exploration to implementation, or implementation to verification.
- A new agent/session should continue the task.
- Context includes stale assumptions that may pollute future reasoning.

## Policy Matrix

The machine-readable policy is `config/token-efficiency-policy.json`.
