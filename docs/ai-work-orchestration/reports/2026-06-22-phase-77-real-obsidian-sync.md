# Phase 77：真实 Obsidian 同步 FUZ-554 Dry-run Evidence

## 目的

在用户批准后，将真实 `FUZ-554` Multica dry-run 的本地 evidence 同步到真实 Obsidian generated 区，并验证 run 索引和 run 详情页展示正确。

## 结论

- 已执行真实 Obsidian generated 写入：`/mnt/d/JAVA/knowledge/tiandao/99-generated`。
- 新 run 已出现在索引：`/mnt/d/JAVA/knowledge/tiandao/99-generated/loop/runs-index.md`。
- 新 run 详情页已生成：`/mnt/d/JAVA/knowledge/tiandao/99-generated/loop/runs/FUZ-554-real-multica-loop-gated-20260622-142303.md`。
- 修复 `scripts/obsidian-sync.sh` 的 run 索引状态优先级：优先展示 `state-evaluation.json.to`，再回退到 `run.json.status`。
- 因此该 run 在索引中显示治理状态 `needs_clarification`，而不是底层 dry-run 状态 `PASSED`。

## 验证

已完成：

```bash
DRY_RUN=false ./scripts/obsidian-sync.sh
rg 'FUZ-554-real-multica-loop-gated-20260622-142303' /mnt/d/JAVA/knowledge/tiandao/99-generated/loop/runs-index.md
```

验证结果：

- 索引行显示：`needs_clarification`。
- Gate scores 显示：`R:FAILED 61/100 / D:MISSING / C:PASSED 100/100 / O:FAILED 72/100`。
- Gate policy 显示：`FAILED documentation`。
- Gate exception 显示：`MISSING`。

## 副作用

- Real Obsidian generated write: true，已由用户批准。
- Multica writes: false。
- Feishu writes: false。
- Git remote writes: false。
- Deployment: false。

## 下一审批点

如果继续推进，需要人类确认是否允许：

1. 将本次 dry-run comment 草稿写回 `FUZ-554`。
2. 对 `FUZ-554` 状态做任何更新。
3. 对 `needs_clarification` 的问题进行人工补充并生成新需求草稿。

默认不执行任何 Multica 写入。
