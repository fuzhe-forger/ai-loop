# 阶段报告：Phase 50 Agent Crew Routing

## 目标

把状态机输出的抽象 `next_actor` 映射到具体机组角色，并让 metadata draft 和 review packet 都能看到建议具体角色。

## 已完成

- 新增 `scripts/route-actor.sh`。
- 更新 `docs/ai-work-orchestration/12-issue-metadata-contract.md`，新增 `assigned_actor` 字段。
- 更新 `scripts/metadata-draft.sh`，输出 `assigned_actor`。
- 更新 `scripts/review-packet.sh`，新增 `Assigned Actor` 列。
- 更新 `scripts/verify-toolchain.sh`，纳入 `route-actor` smoke check。

## 映射示例

| next_actor | assigned_actor |
|---|---|
| `execution_agent` | 顾实 |
| `reviewer` | 裴衡 |
| `human` | 人类 |
| `scheduler` | 黑墙 |
| `tester` | 测真 |
| `scribe` | 简辞 |

## 验证结果

已执行：

```bash
./scripts/route-actor.sh --next-actor reviewer
./scripts/metadata-draft.sh --issue FUZ-554 --run-id FUZ-554-scope-split-review
./scripts/share-preflight.sh --case FUZ-554 --pattern 'FUZ-554*'
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*' --strict --state-gate
```

结果：

- `reviewer -> 裴衡`。
- `FUZ-554-scope-split-review` 在 review packet 中显示 `Assigned Actor=裴衡`。
- `FUZ-554-toolchain-verify-pilot` 在 review packet 中显示 `Assigned Actor=人类`。
- strict + state gate 通过。

## 结论

Multica Loop 现在能从 run evidence 推导到：

```text
suggested state -> next_actor -> assigned_actor
```

这让“下一步谁处理”从口头判断变成可生成、可复核的本地 evidence。

## 下一步

- 把 `assigned_actor` 写入 `metadata-draft.json` 后批量刷新现有 run。
- 在分享材料中补一页“机组路由”。
