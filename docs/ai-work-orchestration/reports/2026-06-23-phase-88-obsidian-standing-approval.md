# Phase 88: Obsidian Standing Approval

## Goal

Promote the user's standing approval for Obsidian generated sync from an operation log note into the local approval-boundary policy.

## User Decision

The user stated: `执行 Obsidian 同步 以后不需要审批`.

## Changes

- `config/approval-boundary.json` now marks `obsidian-sync` as `requires_approval: false` with `decision_without_approval: proceed`.
- `verify-toolchain` now checks that `approval-boundary --action obsidian-sync` proceeds without an approver.
- `21-local-operating-protocol.md` documents the narrowed standing approval: Obsidian `99-generated/` sync may proceed, while Feishu, Multica writes, remote Git, deploy, tool installs, Codex config, and destructive operations still require separate approval.

## Guardrails

- The standing approval only covers `DRY_RUN=false ./scripts/obsidian-sync.sh` writing generated files under `/mnt/d/JAVA/knowledge/tiandao/99-generated` and local operation logs under `state/operations/`.
- It does not authorize Feishu writes, Multica comment/status/metadata writes, remote Git, deployment, tool installation, global Codex config changes, or destructive filesystem operations.
- Obsidian generated sync remains validated by the temp-vault guard in `verify-toolchain`.

## Verification

```bash
python3 -m json.tool config/approval-boundary.json
bash -n scripts/verify-toolchain.sh scripts/approval-boundary.sh
./scripts/approval-boundary.sh --action obsidian-sync --issue FUZ-554 --run-id FUZ-554-real-multica-loop-gated-20260622-142303
./scripts/verify-toolchain.sh --case FUZ-554 --pattern FUZ-554-real-multica-loop-gated-20260622-142303 --strict --state-gate --output runs/FUZ-554-real-multica-loop-gated-20260622-142303/verification-report.md
```
