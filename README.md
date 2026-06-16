# AI Loop

AI Loop is a local-first control loop that puts AI coding agents inside a deterministic engineering pipeline.

The MVP scope is intentionally narrow:

- local repository
- `git worktree` workspace model
- `codex exec` as the agent executor
- deterministic verification commands
- retry loop
- auditable artifacts
- patch delivery only

## Current milestone

This repository is bootstrapping itself. The implemented MVP slice supports:

- `ai-loop init`
- `ai-loop plan` for ambiguous tasks before implementation
- `ai-loop discover` for local pre-flight discovery and Loop memory review
- `ai-loop-async start/status/logs/wait/stop/list` for background Loop jobs
- `ai-loop run --dry-run`
- `ai-loop run` with local `git worktree`
- `codex exec` agent execution
- diff patch artifact generation
- safety checks for forbidden paths and diff size
- deterministic verify commands
- retry prompt generation up to `agent.max_iterations`
- cross-run local memory in `runs/index.jsonl` and `runs/LOOP_STATE.md`
- `ai-loop status <run-id>` and `ai-loop status --latest`

## Quick start

```bash
./bin/ai-loop init
./bin/ai-loop discover --repo .
./bin/ai-loop status --repo . --latest
./bin/ai-loop plan --repo . --task tasks/bootstrap-ai-loop.md --dry-run
./bin/ai-loop run --repo . --task tasks/bootstrap-ai-loop.md --dry-run
./bin/ai-loop-async start --repo . -- run --task tasks/bootstrap-ai-loop.md --dry-run
```

Run a real local loop after committing or stashing source changes:

```bash
./bin/ai-loop run --repo . --task tasks/bootstrap-ai-loop.md
```

The loop only uses local Git state. It does not push, create remotes, create merge requests, or deploy.

## Manual

See `docs/usage.md` for the local Loop planning stage, execution workflow, configuration, artifacts, statuses, and troubleshooting guide.

For chat-driven tasks, start with `docs/in-window-loop.md` before invoking the local CLI or external tools.
