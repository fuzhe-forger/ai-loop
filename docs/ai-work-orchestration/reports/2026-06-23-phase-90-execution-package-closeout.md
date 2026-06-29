# Phase 90: Execution Package Closeout

## Goal

Reduce token waste and execution detours by standardizing the start and finish of a Loop task.

## Problem

Recent work repeatedly rediscovered the same questions: is the task brief clear, which side effects are allowed, should a phase report be created, which verification commands should run, and whether `share-preflight` polluted canonical evidence. These checks were correct but too manual.

## Changes

- Added `scripts/loop-execution-preflight.sh` to generate a local execution checklist before coding or writeback.
- Added `scripts/loop-closeout.sh` to run the standard local closeout sequence: execution preflight, strict toolchain verification, persisted share-preflight, evidence checklist, and evidence index.
- Added both scripts to `verify-toolchain` smoke checks.
- Updated the local operating protocol so formal tasks start with execution preflight and finish with closeout before Obsidian sync.
- Added execution preflight and closeout summary to evidence collection, checklist, index, and Obsidian generated run pages.

## Side Effect Policy

- The new scripts are local-only and perform no Feishu, Multica, Git remote, deploy, or Obsidian writes.
- Feishu and Multica can be marked as allowed in the preflight checklist when the user grants permission, but actual writes still require local drafts/evidence and readback.
- Obsidian generated sync remains a separate step covered by standing approval.

## Verification

```bash
bash -n scripts/loop-execution-preflight.sh scripts/loop-closeout.sh scripts/verify-toolchain.sh
./scripts/loop-execution-preflight.sh --issue FUZ-554 --task tasks/FUZ-554.md --repo . --run-id FUZ-554-real-multica-loop-gated-20260622-142303 --allow-feishu-write --allow-multica-write --phase-report auto
./scripts/loop-closeout.sh --issue FUZ-554 --task tasks/FUZ-554.md --repo . --run-id FUZ-554-real-multica-loop-gated-20260622-142303 --allow-feishu-write --allow-multica-write
./scripts/verify-toolchain.sh --case FUZ-554 --pattern FUZ-554-real-multica-loop-gated-20260622-142303 --strict --state-gate --output runs/FUZ-554-real-multica-loop-gated-20260622-142303/verification-report.md
```
