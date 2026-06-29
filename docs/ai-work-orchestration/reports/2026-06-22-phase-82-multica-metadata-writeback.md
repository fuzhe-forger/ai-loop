# Phase 82：Multica metadata 受控写回

## Summary

用户审批后，对 `FUZ-554` 执行受控 metadata 写回，仅写入单个 KV：`pipeline_status=done`。本阶段不修改 issue status，不写 reviewer/assignee/priority 等人工字段。

## Scope

- Issue: `FUZ-554`
- Run ID: `FUZ-554-real-multica-loop-gated-20260622-142303`
- Workspace: `1b8c6816-e27e-4b59-b31c-9b05acc454f4`
- Remote side effect: Multica issue metadata KV write
- Key written: `pipeline_status`
- Value written: `done`
- Approved by: `傅喆`

## Gate

Metadata writeback gate passed before write:

- `core_evidence=PASSED`
- `strict_gate=PASSED`
- `state_gate=PASSED`
- `draft_exists=PASSED`
- `no_secrets=PASSED`
- `metadata_format=PASSED`
- `human_approval=PASSED:傅喆`

Gate artifact: `runs/FUZ-554-real-multica-loop-gated-20260622-142303/writeback-gate-metadata.json`

## Commands

```bash
./scripts/writeback-gate.sh --issue FUZ-554 --run-id FUZ-554-real-multica-loop-gated-20260622-142303 --type metadata --approved-by "傅喆" --output runs/FUZ-554-real-multica-loop-gated-20260622-142303/writeback-gate-metadata.json
MULTICA_WORKSPACE_ID=1b8c6816-e27e-4b59-b31c-9b05acc454f4 multica issue metadata set FUZ-554 --key pipeline_status --value done --type string --output json
MULTICA_WORKSPACE_ID=1b8c6816-e27e-4b59-b31c-9b05acc454f4 multica issue metadata get FUZ-554 --key pipeline_status --output json
MULTICA_WORKSPACE_ID=1b8c6816-e27e-4b59-b31c-9b05acc454f4 multica issue metadata list FUZ-554 --output json
```

## Verification

- Before metadata: `{}`
- Write result: `{ "pipeline_status": "done" }`
- Readback: `"done"`
- After metadata: `{ "pipeline_status": "done" }`
- Local state remains: `done`
- Remote write completed: `YES`

## Artifacts

- Before: `runs/FUZ-554-real-multica-loop-gated-20260622-142303/multica-metadata-before.json`
- Write result: `runs/FUZ-554-real-multica-loop-gated-20260622-142303/multica-metadata-write-result.json`
- Readback: `runs/FUZ-554-real-multica-loop-gated-20260622-142303/multica-metadata-get-pipeline-status.json`
- After: `runs/FUZ-554-real-multica-loop-gated-20260622-142303/multica-metadata-after.json`
- Writeback summary: `runs/FUZ-554-real-multica-loop-gated-20260622-142303/writeback-summary.md`

## Side Effects

- Multica metadata write: completed for `pipeline_status` only.
- Multica issue status: not changed.
- Multica comment: not changed in this phase.
- Feishu writes: none.
- Obsidian generated sync: not performed in this phase.
- Git commit/push: none.

## Next Decision

如果需要让 Obsidian generated 也展示 metadata writeback 结果，需要单独审批执行：

```bash
DRY_RUN=false ./scripts/obsidian-sync.sh
```
