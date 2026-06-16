# 阶段报告：Phase 51 Assigned Actor Gate

## 目标

让 `--state-gate` 不只检查 state/metadata 文件存在，还检查 metadata 是否包含具体机组角色 `assigned_actor`。

## 已完成

- 更新 `scripts/verify-toolchain.sh`。
- `--state-gate` 新增 `metadata.assigned_actor` 字段校验。
- 对 FUZ-554 现有 22 个 run 执行本地 evidence refresh。
- 重新执行 `share-preflight` 和 `verify-toolchain --strict --state-gate`。

## Gate 新口径

每个 run 必须具备：

- `state-evaluation.json`
- `state-evaluation.md`
- `metadata-draft.json`
- `metadata-draft.md`
- `metadata.assigned_actor`

## 验证结果

正向：

- FUZ-554 22 个 run 全部通过 `--strict --state-gate`。
- review packet 显示 `Assigned Actor`。
- 示例：`reviewer -> 裴衡`，`human -> 人类`。

负向：

- 构造缺少 `metadata.assigned_actor` 的临时 run。
- `--state-gate` 正确失败。
- 报告显示缺失 `metadata.assigned_actor`。

## 结论

状态门禁现在覆盖完整链路：

```text
state-evaluation -> metadata-draft -> assigned_actor -> review packet
```

这让“下一步谁处理”进入可验证 evidence，而不是只停留在建议文字。
