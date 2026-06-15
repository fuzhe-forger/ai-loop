# 阶段报告：Phase 21 Evidence Index Stable Ordering

## 目标

提升 `evidence-index.sh` 输出的可复核性，让团队成员能判断索引生成时间、匹配范围和 run 表排序来源。

## 任务

为 `scripts/evidence-index.sh` 生成的 Markdown 增加 `Metadata` 区块，包含生成时间、pattern 和排序说明，同时保持原有 run 表与 review notes 不变。

## 已完成

- 新增 `Generated at` 字段，使用 UTC ISO-like 时间格式。
- 新增 `Pattern` 字段，明确索引覆盖的 `runs/<pattern>`。
- 新增 `Ordering` 字段，说明 run 表来自 shell glob expansion order under `runs/` with nullglob enabled。
- 保持原有 `Runs` 表和 `Review Notes`。
- 新增 Phase 21 本地证据包 `runs/FUZ-554-evidence-index-stable-ordering-pilot/`。

## 风险边界

- 只读取本地 `runs/` 目录。
- 只在显式 `--output` 时写本地报告。
- 不读取 Multica issue。
- 不自动写 Multica comment/status。
- 不 push、不 commit、不创建 MR。

## 验证结果

本阶段本地验证通过：

- `bash -n scripts/evidence-index.sh`：PASSED
- evidence index 生成与 metadata 检查：PASSED
- `bash -n scripts/verify-toolchain.sh`：PASSED
- `verify-toolchain --strict`：PASSED

## 结论

Evidence index 的可读性和可复核性已增强。该阶段让多 run 证据索引更适合进入团队分享和人工复核流程。
