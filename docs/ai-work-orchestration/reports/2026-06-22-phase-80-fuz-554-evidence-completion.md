# Phase 80：FUZ-554 证据补齐闭环

## Summary

本阶段补齐 `FUZ-554-real-multica-loop-gated-20260622-142303` 的 requirement / deliverable evidence，并修复分类、澄清草稿和 strict gate 解析的本地证据问题。最终本地状态从 `needs_clarification` / `blocked` 收敛为 `done`。

## Scope

- Issue: `FUZ-554`
- Run ID: `FUZ-554-real-multica-loop-gated-20260622-142303`
- Task type: `documentation`
- Side effects: local files only
- Not performed: Multica status writeback, Multica metadata writeback, Feishu write, Obsidian generated sync, Git remote operation, deployment

## Changes

- `tasks/FUZ-554.md`：补齐背景、用户/干系人、范围、约束、依赖、风险、优先级与副作用策略。
- `scripts/multica-loop.sh`：stage report 模板新增 `Purpose`、`Owner / Actor`、`Next Action`，后续 run 的 deliverable gate 更容易通过。
- `scripts/classify-task.sh`：将 `复盘`、`案例`、`报告`、`记录`、`evidence`、`summary`、`草稿` 纳入 documentation 分类关键词。
- `scripts/requirement-gate.sh`：需求已通过时不再生成过期 clarification draft，并移除旧 clarification 输出。
- `scripts/collect-evidence.sh`：兼容 `verification-report.md` 中表格形式的 `Strict Evidence Gate` 结果。
- 当前 run 证据：刷新 `requirement-gate.md`、`deliverable-gate.md`、`gate-policy-check.*`、`verification-report.md`、`state-evaluation.*`、`metadata-draft.*`、`evidence.*`、`review-packet.md`、`multica-comment.md`。

## Final Gate Results

- Requirement gate: `PASSED 100/100`
- Deliverable gate: `PASSED 100/100`
- Gate policy: `PASSED`
- Classification: `documentation`
- Strict evidence gate: `PASSED`
- State metadata gate: `PASSED`
- Pipeline status: `done`
- Remote write completed: `true`

## Verification

```bash
./scripts/requirement-gate.sh --input tasks/FUZ-554.md --issue FUZ-554 --output runs/FUZ-554-real-multica-loop-gated-20260622-142303/requirement-gate.md --clarification-output runs/FUZ-554-real-multica-loop-gated-20260622-142303/clarification.md
./scripts/deliverable-gate.sh --run-id FUZ-554-real-multica-loop-gated-20260622-142303 --issue FUZ-554 --output runs/FUZ-554-real-multica-loop-gated-20260622-142303/deliverable-gate.md
./scripts/gate-policy-check.sh --issue FUZ-554 --run-id FUZ-554-real-multica-loop-gated-20260622-142303 --classification runs/FUZ-554-real-multica-loop-gated-20260622-142303/classification.json --output runs/FUZ-554-real-multica-loop-gated-20260622-142303/gate-policy-check.md --json-output runs/FUZ-554-real-multica-loop-gated-20260622-142303/gate-policy-check.json
./scripts/verify-toolchain.sh --case FUZ-554 --pattern FUZ-554-real-multica-loop-gated-20260622-142303 --strict --state-gate --output runs/FUZ-554-real-multica-loop-gated-20260622-142303/verification-report.md
./scripts/evaluate-state.sh --issue FUZ-554 --run-id FUZ-554-real-multica-loop-gated-20260622-142303 --write-run
./scripts/collect-evidence.sh --issue FUZ-554 --run-id FUZ-554-real-multica-loop-gated-20260622-142303 --output runs/FUZ-554-real-multica-loop-gated-20260622-142303/evidence.json --markdown runs/FUZ-554-real-multica-loop-gated-20260622-142303/evidence.md
./scripts/metadata-draft.sh --issue FUZ-554 --run-id FUZ-554-real-multica-loop-gated-20260622-142303 --output runs/FUZ-554-real-multica-loop-gated-20260622-142303/metadata-draft.json --markdown runs/FUZ-554-real-multica-loop-gated-20260622-142303/metadata-draft.md
python3 -m json.tool runs/FUZ-554-real-multica-loop-gated-20260622-142303/evidence.json
python3 -m json.tool runs/FUZ-554-real-multica-loop-gated-20260622-142303/metadata-draft.json
python3 -m json.tool runs/FUZ-554-real-multica-loop-gated-20260622-142303/gate-policy-check.json
```

Result: `PASSED`

## Current State

```json
{
  "state": "done",
  "gate_policy": "PASSED",
  "task_type": "documentation",
  "strict_gate": "PASSED",
  "requirement": "PASSED",
  "deliverable": "PASSED",
  "metadata_pipeline_status": "done",
  "metadata_strict_gate": "PASSED",
  "remote_write_completed": true
}
```

## Side Effects

- Local repo files: updated.
- Multica writes: none in this phase.
- Obsidian generated sync: not performed in this phase.
- Feishu writes: none.
- Git commit/push: none.

## Next Decision

如需让 Obsidian generated 展示最新 `done` 状态，需要单独审批执行：

```bash
DRY_RUN=false ./scripts/obsidian-sync.sh
```

如需把 `pipeline_status=done` 写回 Multica metadata，也需要单独审批，并先通过 metadata writeback gate。
