# Phase 87: Share Preflight Snapshot Guard

## Goal

Prevent local verification from mutating the canonical run evidence while still testing that `share-preflight --persist-to-run` can persist summary artifacts.

## Changes

- `verify-toolchain` now backs up `runs/<run-id>/share-preflight-summary.md/json` before the snapshot smoke test.
- The snapshot test still exercises `share-preflight --skip-verify --persist-to-run` and verifies the persisted files exist.
- A cleanup trap restores the original run summary artifacts after the smoke test, or removes them if they did not exist before the test.
- When canonical summary artifacts existed before the smoke test, the guard now compares their pre/post SHA-256 hashes after restore.
- The Obsidian temp-vault guard now verifies generated run pages include `## Share Preflight Summary`, `Golden path failed checks: 0`, and the approval boundary snapshot.
- The operation-log isolation check now blocks mirrored operation-log document bodies instead of broad documentation references to `state/operations`.
- The Obsidian temp-vault guard also verifies the generated docs index links the Phase 87 report and that the report body is mirrored under `loop/docs/reports/`.

## Why

The previous smoke test proved persistence but could overwrite a real run's final share-preflight summary with a verification-only `/tmp/verify-share-preflight-*` path. That made the smoke test useful but polluted handoff evidence. The guard keeps the test realistic while preserving canonical run artifacts.

## Verification

```bash
bash -n scripts/verify-toolchain.sh scripts/obsidian-sync.sh
./scripts/verify-toolchain.sh --case FUZ-554 --pattern FUZ-554-real-multica-loop-gated-20260622-142303 --strict --state-gate --output runs/FUZ-554-real-multica-loop-gated-20260622-142303/verification-report.md
```

## Side Effects

- Local repo files only.
- No Obsidian generated sync in this phase.
- No Feishu, Multica, remote Git, deployment, or production writes.
