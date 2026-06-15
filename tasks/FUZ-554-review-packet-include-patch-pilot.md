# FUZ-554-O Review Packet Include Patch Summary

## 背景

`FUZ-554` 已完成 patch summary 与 scope check。下一步把 patch summary 纳入 human review packet，让复核者不用在多个证据文件之间来回跳转。

## 目标

为 `scripts/review-packet.sh` 增加 `--include-patch-summary <file>`，在复核包中引用本地 patch summary，并摘出关键范围信息。

## Scope

允许修改：

- `scripts/review-packet.sh`
- `docs/ai-work-orchestration/05-case-playbook.md`
- `docs/ai-work-orchestration/reports/2026-06-15-phase-18-review-packet-include-patch.md`
- `runs/FUZ-554-review-packet-include-patch-pilot/`
- `tasks/FUZ-554-review-packet-include-patch-pilot.md`

## Out of scope

- 不读取 Multica issue
- 不修改 Multica status
- 不 push、不 commit、不创建 MR
- 不访问生产系统

## 验收标准

- `review-packet.sh` 支持 `--include-patch-summary <file>`。
- 传入缺失或空文件时返回非零退出。
- 生成的 review packet 包含 `Patch Summary` 区块。
- `Patch Summary` 区块包含 source、base、changed files、tracked/untracked files、scope check status。
- 原有不传 patch summary 的用法保持可用。

## 验证命令

```bash
bash -n scripts/review-packet.sh
./scripts/review-packet.sh --case FUZ-554 --pattern 'FUZ-554*' --include-patch-summary runs/FUZ-554-patch-scope-check-pilot/patch-summary-pass.md --output runs/FUZ-554-review-packet-include-patch-pilot/review-packet.md
rg -n "Patch Summary|patch-summary-pass.md|Scope check status: PASSED" runs/FUZ-554-review-packet-include-patch-pilot/review-packet.md
if ./scripts/review-packet.sh --case FUZ-554 --pattern 'FUZ-554*' --include-patch-summary runs/FUZ-554-review-packet-include-patch-pilot/missing.md >/tmp/review-packet-missing.out 2>/tmp/review-packet-missing.err; then exit 1; else true; fi
./scripts/review-packet.sh --case FUZ-554 --pattern 'FUZ-554*' --output /tmp/review-packet-no-patch.md
```
