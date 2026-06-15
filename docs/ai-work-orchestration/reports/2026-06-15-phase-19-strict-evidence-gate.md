# 阶段报告：Phase 19 Strict Evidence Gate

## 目标

把案例级证据完整性检查从人工观察升级为可执行 gate，为后续分享和交付前复核提供更稳定的质量线。

## 任务

为 `scripts/verify-toolchain.sh` 增加 `--strict`，要求匹配到的每个 run 都包含 core evidence：`summary.md`、`stage-report.md`、`multica-comment.md`。

## 已完成

- 支持 `--strict` 参数。
- strict 模式在报告中输出 `Strict Evidence Gate` 表格。
- 所有 run 具备 core evidence 时返回 0。
- 任一 run 缺 core evidence 时返回非零。
- 保持原有非 strict smoke check 行为可用。

## 风险边界

- 只读取本地脚本和本地 `runs/` 证据目录。
- 只在显式 `--output` 时写本地报告。
- 不读取 Multica issue。
- 不写 Multica status。
- 不 push、不 commit、不创建 MR。

## 验证结果

本阶段验证均已通过：

- `bash -n scripts/verify-toolchain.sh`：PASSED
- `verify-toolchain --strict` 正向用例：PASSED
- strict 负向缺证据用例返回非零：PASSED
- 非 strict smoke check 兼容：PASSED

## 结论

Strict Evidence Gate 让 `FUZ-554` 从“能生成证据”推进到“证据完整性可被工具拒绝”，适合作为后续真实任务进入分享/复核前的本地准入线。
