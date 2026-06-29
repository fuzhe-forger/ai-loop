# Phase 84：黄金路径与 metadata 回写产品化

## Summary

本阶段把 FUZ-554 闭环中临场执行过的 metadata writeback 和 Obsidian/evidence 一致性校验沉淀为可复用脚本，避免后续 issue 依赖手工命令串联。

## Scope

- Productized local tooling only.
- No Multica writes in this phase.
- No Obsidian generated sync in this phase.
- No Feishu write, Git remote operation, or deployment.

## Changes

- `scripts/metadata-writeback.sh`
  - 默认 dry-run，只生成本地计划报告。
  - `--write` 才执行 Multica metadata KV 写入。
  - 只允许受控字段：`pipeline_status`、`latest_run_id`、`strict_gate`、`next_actor`、`assigned_actor`、`blocked_reason`。
  - 写前调用 `writeback-gate.sh --type metadata`。
  - 写后自动 readback/list，并更新 `writeback-summary.md`。
  - 不改 issue status、comment、assignee、priority、review verdict。

- `scripts/golden-path-check.sh`
  - 只读校验本地 evidence、gate policy、verification、writeback summary、metadata artifacts。
  - 默认校验 Obsidian generated 的 index/detail 一致性。
  - 支持 `--skip-obsidian` 用于纯本地 CI/smoke。

- `scripts/verify-toolchain.sh`
  - 纳入两个新脚本的语法检查、help 检查、metadata dry-run 和 golden-path 本地 smoke。

- `docs/ai-work-orchestration/README.md`
  - 关键脚本列表补充 metadata writeback 和 golden path check。

## Verification

```bash
bash -n scripts/metadata-writeback.sh
bash -n scripts/golden-path-check.sh
./scripts/metadata-writeback.sh --issue FUZ-554 --run-id FUZ-554-real-multica-loop-gated-20260622-142303 --output /tmp/FUZ-554-real-multica-loop-gated-20260622-142303-metadata-writeback-dry.md --json-output /tmp/FUZ-554-real-multica-loop-gated-20260622-142303-metadata-writeback-dry.json
./scripts/golden-path-check.sh --issue FUZ-554 --run-id FUZ-554-real-multica-loop-gated-20260622-142303 --output runs/FUZ-554-real-multica-loop-gated-20260622-142303/golden-path-check.md --json-output runs/FUZ-554-real-multica-loop-gated-20260622-142303/golden-path-check.json
./scripts/verify-toolchain.sh --case FUZ-554 --pattern FUZ-554-real-multica-loop-gated-20260622-142303 --strict --state-gate --output runs/FUZ-554-real-multica-loop-gated-20260622-142303/verification-report.md
```

Result: `PASSED`

## Golden Path Result

- Run: `FUZ-554-real-multica-loop-gated-20260622-142303`
- Golden path: `PASSED`
- Failed checks: `0`
- Local evidence: `PASSED`
- Writeback summary: `PASSED`
- Metadata artifacts: `PASSED`
- Obsidian generated: `PASSED`

## Next Step

建议下一步继续 P0：把 `metadata-writeback.sh --write` 接入 `multica-loop.sh` 的受控参数，但默认保持 dry-run / no-write。完成后再考虑将 golden path check 做成 share/preflight 的标准出口。
