# 阶段报告：Phase 17 Patch Scope Check

## 目标

把 patch review 中的“是否超出允许范围”工具化，为真实代码改动准入门禁提供可执行辅助检查。

## 任务

为 `scripts/patch-summary.sh` 增加 `--allow-prefix <path>`，支持多个允许路径前缀，并输出 `Scope Check` 区块。

## 已完成

- 支持多个 `--allow-prefix`。
- 输出 `Scope Check`。
- 无 allow-prefix 时输出 `NOT_CHECKED`。
- 全部文件在允许前缀内时输出 `PASSED`。
- 存在超范围文件时输出 `FAILED` 并列出文件。

## 风险边界

- 只读取本地 git diff 和 untracked files。
- 只在显式 `--output` 时写本地文件。
- 不读取 Multica issue。
- 不写 Multica status。
- 不 push、不 commit、不创建 MR。

## 验证结果

本阶段验证均已通过：

- Scope check `PASSED` case：PASSED
- Scope check `FAILED` case：PASSED
- Scope check `NOT_CHECKED` case：PASSED
- Toolchain verification：PASSED

## 结论

Patch Scope Check 试点成立。后续真实代码改动可以通过 `--allow-prefix` 先做范围检查，再进入完整 diff 复核。
