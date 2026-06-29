# Phase 75：Obsidian 展示 Gate Policy Exception

## 目的

让 Obsidian generated run 索引和 run 详情页展示 `gate-policy-check` 与 `gate-policy-exception`，方便人类复盘时看到策略失败是否有结构化人工例外。

## 结论

- `scripts/obsidian-sync.sh` 的 Loop run 索引新增：
  - `Gate Policy`
  - `Gate Exception`
- `scripts/obsidian-sync.sh` 的 run 详情页新增 `## Gate Policy` 区块，展示：
  - Policy result
  - Task type
  - Exception status
  - Exception approved by
  - Exception expires
- 本阶段只验证 fake vault，不写真实 Obsidian vault。

## 产物

- `scripts/obsidian-sync.sh`
- `docs/ai-work-orchestration/README.md`
- `docs/ai-work-orchestration/23-design-output-governance.md`

## 验证

已完成 fake vault 本地验证：

```bash
rm -rf /tmp/obsidian-phase75-vault && mkdir -p /tmp/obsidian-phase75-vault
DRY_RUN=false VAULT_PATH=/tmp/obsidian-phase75-vault ./scripts/obsidian-sync.sh
rg 'Gate Policy|Gate Exception|ACTIVE fixture-human' /tmp/obsidian-phase75-vault/99-generated
```

验证结果：

- `/tmp/obsidian-phase75-vault/99-generated/loop/runs-index.md` 已展示 `Gate Policy` 和 `Gate Exception` 列。
- `phase-70-gate-policy-fail-sample` 在索引中展示 `FAILED feature` 和 `ACTIVE fixture-human`。
- `/tmp/obsidian-phase75-vault/99-generated/loop/runs/phase-70-gate-policy-fail-sample.md` 已展示 `## Gate Policy` 区块，包含 `Policy result=FAILED`、`Task type=feature`、`Exception status=ACTIVE`、`Exception approved by=fixture-human`。
- 未写入真实 Obsidian vault。

## 副作用

- Network access: false
- Remote writes: false
- Multica writes: false
- Feishu writes: false
- Real Obsidian writes: false
- Fake vault local writes: `/tmp/obsidian-phase75-vault/99-generated`

## 需要审批的下一步

如果要写入真实 Obsidian vault，需要用户显式批准：

```bash
DRY_RUN=false ./scripts/obsidian-sync.sh
```
