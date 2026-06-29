# Phase 89: Approval Boundary Policy Wording

## Goal

Keep `approval-boundary` human-readable reports consistent with the standing approval policy for Obsidian generated sync.

## Problem

After Phase 88, `config/approval-boundary.json` correctly allowed `obsidian-sync` to proceed without a new approver. However, the Markdown report's generic Policy section still said Obsidian stopped for explicit human approval. That made the decision block correct but the policy explanation stale.

## Changes

- `scripts/approval-boundary.sh` now states that Obsidian generated sync has standing approval for `99-generated/` writes only.
- The same policy section now lists the remaining approval-required categories without including Obsidian.
- `verify-toolchain` asserts that the Obsidian approval-boundary report contains the standing-approval wording and no longer contains the stale `Obsidian, Multica` approval-required phrase.

## Guardrails

- This change does not expand the standing approval scope beyond Obsidian generated files and local operation logs.
- Feishu writes, Multica writes, remote Git, deployment, tool installs, Codex config changes, destructive filesystem operations, and unknown side effects still stop for approval.

## Verification

```bash
bash -n scripts/approval-boundary.sh scripts/verify-toolchain.sh
./scripts/approval-boundary.sh --action obsidian-sync --issue FUZ-554 --run-id FUZ-554-real-multica-loop-gated-20260622-142303
./scripts/verify-toolchain.sh --case FUZ-554 --pattern FUZ-554-real-multica-loop-gated-20260622-142303 --strict --state-gate --output runs/FUZ-554-real-multica-loop-gated-20260622-142303/verification-report.md
```
