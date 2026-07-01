# Sinan Context Pack Integration

## Purpose

Sinan uses a local code-understanding layer to reduce repeated repository reads across Loop stages. The layer is intentionally run-local and evidence-oriented: it produces Markdown artifacts that can be referenced by prompts, summaries, and handoffs.

This is not a standalone knowledge-graph product. It is a small integration boundary between Sinan Loop and local CodeGraph context.

## Artifacts

When graph context is requested, Sinan writes these artifacts under `runs/<run-id>/`:

- `graph-context.md` — CodeGraph status, tracked changed files, affected context, task excerpt, and usage rule.
- `context-pack.md` — stable handoff/evidence alias with the same local understanding contract.

The run metadata also records:

- `graph_context_path`
- `context_pack_path`
- `context_artifact_paths`

## Loop Usage

- **Plan** — use the changed and affected surface to choose the first inspection target.
- **Execute** — keep edits inside the affected surface unless evidence expands scope.
- **Verify** — start with focused validation derived from affected modules, then broaden only when needed.
- **Evidence** — preserve context artifacts in `run.json` and `summary.md` so later review does not depend on chat history.
- **Handoff** — `scripts/loop-handoff.sh` reads `context_artifact_paths` and includes existing context artifacts in its Evidence section.

## Safety Boundaries

- Graph context generation is local-only.
- It performs no remote writes, no deploys, and no external system writes.
- Untracked files are excluded from changed-file detection by default to avoid pulling unrelated scratch space into prompts.
- Handoff only accepts safe relative context artifact paths from `run.json`; absolute paths and parent traversal paths are ignored.

## Non-goals

- Do not replace CodeGraph.
- Do not build a separate dashboard or product surface.
- Do not upload repository context to external systems as part of this integration.
- Do not include broad untracked workspace content unless a future explicit `--include-untracked` option is approved.

## Validation

The integration is covered by:

- `tests/test_graph_context.py`
- `tests/test_runner_graph_context.py`
- `tests/test_loop_handoff_context_artifacts.sh`

A full local smoke should include:

```bash
python -m unittest tests.test_graph_context tests.test_runner_graph_context
tests/test_loop_handoff_context_artifacts.sh
python -m py_compile lib/ai_loop/*.py
./bin/ai-loop run --repo . --task tasks/bootstrap-ai-loop.md --dry-run --use-graph-context --run-id <run-id>
```
