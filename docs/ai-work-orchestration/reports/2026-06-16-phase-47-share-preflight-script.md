# 阶段报告：Phase 47 Share Preflight Script

## 目标

把分享前的多步本地检查收敛成一个命令，降低会前操作成本。

## 已完成

- 新增 `scripts/share-preflight.sh`。
- 更新 `scripts/verify-toolchain.sh`，纳入 `share-preflight --help` smoke check。
- 更新 `docs/ai-work-orchestration/share/preflight-checklist.md`。
- 更新 `docs/ai-work-orchestration/share/README.md`。

## 一键命令

```bash
./scripts/share-preflight.sh \
  --case FUZ-554 \
  --pattern 'FUZ-554*' \
  --output-dir /tmp/fuz554-share-preflight
```

## 输出

```text
/tmp/fuz554-share-preflight/refresh-report.md
/tmp/fuz554-share-preflight/verification-report.md
/tmp/fuz554-share-preflight/review-packet.md
/tmp/fuz554-share-preflight/share-preflight-summary.md
```

## 验证结果

已执行一键预检：

- refresh report 生成成功。
- verification report 包含 `Strict Evidence Gate` 和 `State Metadata Gate`。
- review packet 包含 `Remote Write Done`、`Suggested State`、`Next Actor`。
- summary report 生成成功。

已执行工具链校验：

```bash
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*' --strict --state-gate
```

结果：通过。

## 边界

- 只写 `/tmp` 报告和本地 `runs/` state/metadata artifact。
- 不写 Multica。
- 不改变 issue status。
- 不提交刷新生成的 run evidence。
