# Phase 85：Multica Loop metadata 写回集成

## Summary

本阶段把 Phase 84 的 `metadata-writeback.sh` 接入 `multica-loop.sh`，让后续 issue 可以通过同一个入口完成 dry-run、证据生成、comment/status/metadata 受控写回决策。默认仍然不写远端，metadata 写回必须显式传入 `--write-metadata --metadata-approved-by <who>`。

## Scope

- Local script integration only.
- No Multica writes in this phase.
- No Obsidian generated sync in this phase.
- No Feishu write, Git remote operation, or deployment.

## Changes

- `scripts/multica-loop.sh`
  - 新增 `--write-metadata`。
  - 新增 `--metadata-approved-by <who>`，缺失时直接退出 `2`，不会读取或写入远端 issue。
  - 新增 `--metadata-key <key>`，默认 `pipeline_status`。
  - 默认会调用 `metadata-writeback.sh` dry-run，生成本地 metadata writeback plan。
  - 只有显式 `--write-metadata` 时才调用 `metadata-writeback.sh --write`。
  - `stage-report.md` 和 `writeback-summary.md` 展示 metadata writeback report/json 路径。

- `scripts/verify-toolchain.sh`
  - 新增 `multica-loop metadata approval required` smoke，验证缺少审批时会拒绝执行。

- `docs/ai-work-orchestration/README.md`
  - 更新 `multica-loop.sh` 说明，标明 comment/status/metadata 都是显式受控写回。

## Verification

```bash
bash -n scripts/multica-loop.sh
./scripts/multica-loop.sh --help
./scripts/multica-loop.sh --issue FUZ-554 --repo . --write-metadata
./scripts/verify-toolchain.sh --case FUZ-554 --pattern FUZ-554-real-multica-loop-gated-20260622-142303 --strict --state-gate --output runs/FUZ-554-real-multica-loop-gated-20260622-142303/verification-report.md
./scripts/golden-path-check.sh --issue FUZ-554 --run-id FUZ-554-real-multica-loop-gated-20260622-142303 --output runs/FUZ-554-real-multica-loop-gated-20260622-142303/golden-path-check.md --json-output runs/FUZ-554-real-multica-loop-gated-20260622-142303/golden-path-check.json
```

Result: `PASSED`

Expected refusal:

- Command: `./scripts/multica-loop.sh --issue FUZ-554 --repo . --write-metadata`
- Exit: `2`
- Error: `--metadata-approved-by is required with --write-metadata`

## Golden Path

- Run: `FUZ-554-real-multica-loop-gated-20260622-142303`
- Golden path: `PASSED`
- Failed checks: `0`

## Side Effects

- Multica writes: none.
- Obsidian generated sync: none.
- Feishu writes: none.
- Git commit/push: none.

## Next Step

建议下一步把 `golden-path-check.sh` 接入 `share-preflight.sh`，作为分享/交付前的标准出口校验；随后再做 `writeback-summary.json`，减少 Markdown 解析。
