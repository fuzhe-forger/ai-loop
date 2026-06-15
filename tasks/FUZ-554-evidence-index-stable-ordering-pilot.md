# FUZ-554-R Evidence Index Stable Ordering

## 背景

`FUZ-554` 已经形成多 run 证据链，`scripts/evidence-index.sh` 可以汇总每个 run 的 summary、stage report、comment draft 和 writeback 状态。但当前输出没有生成时间和排序说明，多人复核时不容易判断索引是否为最新版本，也不清楚 run 表顺序来自哪里。

## 目标

为 `scripts/evidence-index.sh` 的输出增加 metadata：生成时间、匹配 pattern 和排序说明，提升 evidence index 在团队分享和人工复核中的可信度。

## Scope

允许修改：

- `scripts/evidence-index.sh`
- `docs/ai-work-orchestration/07-next-code-candidates.md`
- `docs/ai-work-orchestration/reports/2026-06-15-phase-21-evidence-index-stable-ordering.md`
- `runs/FUZ-554-evidence-index-stable-ordering-pilot/`
- `tasks/FUZ-554-evidence-index-stable-ordering-pilot.md`

## Out of scope

- 不读取 Multica issue
- 不修改 Multica status
- 不自动写 Multica comment
- 不 push、不 commit、不创建 MR
- 不访问生产系统

## 验收标准

- `evidence-index.sh` 输出 `Metadata` 区块。
- Metadata 包含生成时间。
- Metadata 包含 pattern。
- Metadata 包含排序说明。
- 原有 `Runs` 表和 `Review Notes` 继续保留。
- `verify-toolchain --strict` 对 `FUZ-554*` 通过。

## 验证命令

```bash
bash -n scripts/evidence-index.sh
./scripts/evidence-index.sh --pattern 'FUZ-554*' --output runs/FUZ-554-evidence-index-stable-ordering-pilot/index.md
rg -n "Metadata|Generated at|Ordering|runs/FUZ-554\*|Review Notes" runs/FUZ-554-evidence-index-stable-ordering-pilot/index.md
bash -n scripts/verify-toolchain.sh
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*' --strict --output runs/FUZ-554-evidence-index-stable-ordering-pilot/verification-report.md
```
