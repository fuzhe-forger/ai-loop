# FUZ-554-S Review Packet Metadata

## 背景

Phase 21 已为 `evidence-index.sh` 增加生成时间、pattern 和排序说明。`review-packet.sh` 作为 human review 入口，也应该具备同样的 metadata，方便复核者判断复核包的新旧、覆盖范围和排序来源。

## 目标

为 `scripts/review-packet.sh` 输出增加 `Metadata` 区块，包含生成时间、匹配 pattern 和排序说明，同时保持原有 scope、evidence index、patch summary 和 review checklist 行为不变。

## Scope

允许修改：

- `scripts/review-packet.sh`
- `docs/ai-work-orchestration/07-next-code-candidates.md`
- `docs/ai-work-orchestration/reports/2026-06-15-phase-22-review-packet-metadata.md`
- `runs/FUZ-554-review-packet-metadata-pilot/`
- `tasks/FUZ-554-review-packet-metadata-pilot.md`

## Out of scope

- 不读取 Multica issue
- 不修改 Multica status
- 不自动写 Multica comment
- 不 push、不 commit、不创建 MR
- 不访问生产系统

## 验收标准

- `review-packet.sh` 输出 `Metadata` 区块。
- Metadata 包含生成时间。
- Metadata 包含 pattern。
- Metadata 包含排序说明。
- 原有 `Scope`、`Evidence Index`、`Review Checklist` 继续保留。
- 带 `--include-patch-summary` 的用法继续可用。
- `verify-toolchain --strict` 对 `FUZ-554*` 通过。

## 验证命令

```bash
bash -n scripts/review-packet.sh
./scripts/review-packet.sh --case FUZ-554 --pattern 'FUZ-554*' --include-patch-summary runs/FUZ-554-patch-summary-pilot/patch-summary.md --output runs/FUZ-554-review-packet-metadata-pilot/review-packet.md
rg -n "Metadata|Generated at|Pattern: runs/FUZ-554\*|Ordering|Patch Summary|Review Checklist" runs/FUZ-554-review-packet-metadata-pilot/review-packet.md
bash -n scripts/verify-toolchain.sh
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*' --strict --output runs/FUZ-554-review-packet-metadata-pilot/verification-report.md
```
