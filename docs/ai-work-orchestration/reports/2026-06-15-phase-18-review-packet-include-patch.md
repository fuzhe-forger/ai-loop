# 阶段报告：Phase 18 Review Packet Include Patch Summary

## 目标

把真实代码改动的 patch summary 纳入 human review packet，降低复核者理解改动范围和准入状态的成本。

## 任务

为 `scripts/review-packet.sh` 增加 `--include-patch-summary <file>`，在复核包中追加 `Patch Summary` 区块，并摘出关键本地字段。

## 已完成

- 支持可选 `--include-patch-summary` 参数。
- 对缺失或空 patch summary 文件返回非零退出。
- 在 review packet 中输出 patch summary source、base、changed files、tracked/untracked files、scope check status。
- 保持原有不带 patch summary 的 review packet 用法可用。
- 更新案例指南，补充真实代码改动场景下的复核包命令。

## 风险边界

- 只读取本地 `runs/` 与显式传入的本地 patch summary 文件。
- 只在显式 `--output` 时写本地文件。
- 不读取 Multica issue。
- 不写 Multica status。
- 不 push、不 commit、不创建 MR。

## 验证结果

本阶段验证均已通过：

- `bash -n scripts/review-packet.sh`：PASSED
- 带 patch summary 生成 review packet：PASSED
- 缺失 patch summary 负向用例返回非零：PASSED
- 不带 patch summary 的原有用法仍可生成：PASSED
- Toolchain verification：PASSED

## 结论

Review Packet Include Patch Summary 让真实代码改动证据进入人工复核入口，形成 `patch-summary -> review-packet -> Multica comment` 的本地优先闭环。
