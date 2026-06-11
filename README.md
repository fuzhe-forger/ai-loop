# AI Loop

AI Loop is a local-first control loop that puts AI coding agents inside a deterministic engineering pipeline.

The MVP scope is intentionally narrow:

- local repository
- `git worktree` workspace model
- `codex exec` later as the agent executor
- deterministic verification commands
- retry loop
- auditable artifacts
- patch delivery only

## Current milestone

This repository is bootstrapping itself. The first implemented slice is:

- `ai-loop init`
- `ai-loop run --dry-run`
- `ai-loop status <run-id>`

## Quick start

```bash
./bin/ai-loop init
./bin/ai-loop run --repo . --task tasks/bootstrap-ai-loop.md --dry-run
```

