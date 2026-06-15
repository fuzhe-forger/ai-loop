# FUZ-554-N Patch Scope Check

## 背景

`FUZ-554` 已完成 patch summary 证据化。下一步把“改动是否在允许范围内”从纯人工判断推进到工具辅助判断。

## 目标

为 `scripts/patch-summary.sh` 增加 `--allow-prefix <path>`，支持多个允许路径前缀，并在 patch summary 中输出 `Scope Check` 结果。

## Scope

允许修改：

- `scripts/patch-summary.sh`
- `docs/ai-work-orchestration/reports/2026-06-15-phase-17-patch-scope-check.md`
- `runs/FUZ-554-patch-scope-check-pilot/`
- `tasks/FUZ-554-patch-scope-check-pilot.md`

## Out of scope

- 不访问 Multica issue
- 不修改 Multica status
- 不 push、不 commit、不创建 MR
- 不访问生产系统

## 验收标准

- 支持多个 `--allow-prefix`
- 输出 `Scope Check` 区块
- 所有文件在允许前缀内时显示 `PASSED`
- 有文件超出范围时显示 `FAILED` 并列出文件
- 默认不传 `--allow-prefix` 时显示 `NOT_CHECKED`
- invalid git ref 仍返回非零退出

## 验证命令

```bash
bash -n scripts/patch-summary.sh
./scripts/patch-summary.sh --base HEAD --allow-prefix docs/ --allow-prefix runs/ --allow-prefix scripts/ --allow-prefix tasks/ --allow-prefix README.md --allow-prefix lib/ --output runs/FUZ-554-patch-scope-check-pilot/patch-summary-pass.md
rg -n "Scope Check|Status: PASSED|Allow prefixes" runs/FUZ-554-patch-scope-check-pilot/patch-summary-pass.md
./scripts/patch-summary.sh --base HEAD --allow-prefix docs/ --output runs/FUZ-554-patch-scope-check-pilot/patch-summary-fail.md
rg -n "Status: FAILED|Out of scope files|scripts/patch-summary.sh" runs/FUZ-554-patch-scope-check-pilot/patch-summary-fail.md
./scripts/patch-summary.sh --base HEAD --output runs/FUZ-554-patch-scope-check-pilot/patch-summary-unchecked.md
rg -n "Status: NOT_CHECKED" runs/FUZ-554-patch-scope-check-pilot/patch-summary-unchecked.md
```
