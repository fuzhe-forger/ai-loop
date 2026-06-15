# 阶段报告：Phase 22 Review Packet Metadata

## 目标

让 human review packet 与 evidence index 使用一致的 metadata 口径，提升复核包在团队分享和人工复核中的可信度。

## 任务

为 `scripts/review-packet.sh` 生成的 Markdown 增加 `Metadata` 区块，包含生成时间、pattern 和排序说明，同时保持原有 scope、evidence index、patch summary 与 checklist 不变。

## 已完成

- 新增 `Generated at` 字段，使用 UTC ISO-like 时间格式。
- 新增 `Pattern` 字段，明确复核包覆盖的 `runs/<pattern>`。
- 新增 `Ordering` 字段，说明 run 表来自 shell glob expansion order under `runs/` with nullglob enabled。
- 保持原有 `Scope`、`Evidence Index`、`Patch Summary` 和 `Review Checklist`。
- 新增 Phase 22 本地证据包 `runs/FUZ-554-review-packet-metadata-pilot/`。

## 风险边界

- 只读取本地 `runs/` 与显式传入的本地 patch summary 文件。
- 只在显式 `--output` 时写本地报告。
- 不读取 Multica issue。
- 不自动写 Multica comment/status。
- 不 push、不 commit、不创建 MR。

## 验证结果

本阶段本地验证通过：

- `bash -n scripts/review-packet.sh`：PASSED
- review packet 生成与 metadata 检查：PASSED
- 带 patch summary 用法：PASSED
- 不带 patch summary 的兼容用法：PASSED
- `bash -n scripts/verify-toolchain.sh`：PASSED
- `verify-toolchain --strict`：PASSED

## 结论

Review packet metadata 已本地实现并验证通过，可作为团队复核入口的稳定字段。
