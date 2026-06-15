# 阶段报告：Phase 14 Patch Summary 接入工具链自检

## 目标

将 `patch-summary.sh` 纳入 `verify-toolchain.sh`，确保 patch 证据化能力也被工具链 smoke check 覆盖。

## 任务

更新 `verify-toolchain.sh`：

- `--list-checks` 输出包含 `patch-summary.sh`。
- 常规自检包含 `bash -n scripts/patch-summary.sh`。
- 常规自检包含 `patch-summary --help`，避免 clean tree 无 diff 时误失败。

## 风险边界

- 仅修改本地 helper script 和本地证据。
- 不读取 Multica issue。
- 不写 Multica status。
- 不 push、不 commit、不创建 MR。

## 验证结果

本阶段验证命令均已通过：

```bash
bash -n scripts/verify-toolchain.sh
./scripts/verify-toolchain.sh --list-checks | rg "patch-summary.sh"
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*' --output runs/FUZ-554-toolchain-patch-summary-pilot/verification-report.md
rg -n "patch-summary" runs/FUZ-554-toolchain-patch-summary-pilot/verification-report.md
```

## 结论

Patch Summary 已接入工具链自检。后续运行 `verify-toolchain.sh` 时会覆盖 patch 证据化脚本的语法和 help smoke check。
