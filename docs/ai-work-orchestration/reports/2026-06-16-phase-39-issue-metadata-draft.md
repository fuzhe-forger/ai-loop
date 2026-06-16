# 阶段报告：Phase 39 Issue Metadata Draft

## 目标

把 Multica Loop 的 L1 工作记忆从设计推进到本地草稿：根据 run state evidence 生成 issue metadata JSON/Markdown，但不写 Multica。

## 已完成

- 新增 `docs/ai-work-orchestration/12-issue-metadata-contract.md`。
- 新增 `scripts/metadata-draft.sh`。
- 更新 `scripts/verify-toolchain.sh`，把 metadata draft 纳入 smoke checks。
- 更新总入口 `docs/ai-work-orchestration/README.md`。

## Metadata 字段

当前草稿包含：

- `pipeline_status`
- `review_verdict`
- `latest_run_id`
- `strict_gate`
- `blocked_reason`
- `next_actor`
- `state_reason`
- `updated_by`
- `updated_at`

## 用法

```bash
./scripts/metadata-draft.sh \
  --issue FUZ-554 \
  --run-id FUZ-554-scope-split-review \
  --output /tmp/fuz554-metadata.json \
  --markdown /tmp/fuz554-metadata.md
```

## 验证结果

已执行：

```bash
bash -n scripts/metadata-draft.sh
./scripts/metadata-draft.sh --issue FUZ-554 --run-id FUZ-554-scope-split-review
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*' --strict
```

结果：

- `FUZ-554-scope-split-review` 生成 `pipeline_status=review_ready`。
- `next_actor=reviewer`。
- `strict_gate=PASSED`。
- `remote_write=false`。
- strict toolchain 通过。

## 边界

- 只生成本地草稿。
- 不写 Multica issue metadata。
- 不改变 issue status。
- 不把 metadata 当 evidence；metadata 只是工作记忆摘要。

## 下一步

- 让 `multica-loop.sh` 在 comment draft 中引用 metadata 草稿路径。
- 后续再设计显式授权的 metadata 写回命令。
