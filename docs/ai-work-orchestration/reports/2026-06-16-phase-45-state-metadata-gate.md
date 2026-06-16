# 阶段报告：Phase 45 State Metadata Gate

## 目标

在不改变 core `--strict` 口径的前提下，新增独立 `--state-gate`，用于检查每个 run 是否具备状态判断和 metadata 草稿 evidence。

## 已完成

- 更新 `scripts/verify-toolchain.sh`。
- 新增参数 `--state-gate`。
- 报告中新增 `State Metadata Gate` 表。
- 失败时返回非零退出码。
- `refresh-run-evidence` smoke 改为 `--help`，避免 verify 时自动补齐 artifact 掩盖缺失。

## Gate 口径

`--state-gate` 要求每个匹配 run 具备：

- `state-evaluation.json`
- `state-evaluation.md`
- `metadata-draft.json`
- `metadata-draft.md`

## 与 strict 的关系

- `--strict`：检查 core evidence，即 `summary.md`、`stage-report.md`、`multica-comment.md`。
- `--state-gate`：检查状态和 metadata evidence。
- 两者互不替代，可以单独使用，也可以组合使用。

推荐正式复核命令：

```bash
./scripts/verify-toolchain.sh \
  --case FUZ-554 \
  --pattern 'FUZ-554*' \
  --strict \
  --state-gate
```

## 验证结果

已验证：

- FUZ-554 现有 22 个 run 在 `--strict --state-gate` 下通过。
- 临时缺 metadata 的负向 run 会失败。
- 负向报告显示缺少 `metadata-draft.json`、`metadata-draft.md`。

## 结论

工具链现在有两层 gate：

1. core evidence gate：证明 AI 工作有基本交付凭证。
2. state metadata gate：证明 run 已进入状态机和工作记忆链路。

这让分享前和复核前的本地检查更接近 Multica Loop 的最终治理模型。
