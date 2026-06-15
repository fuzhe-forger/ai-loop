# 阶段报告：Phase 10 工具链自检试点

## 目标

为已经沉淀的本地 helper scripts 增加一个总验证入口，确保后续团队复用前可以快速检查工具链是否可用。

## 任务

新增 `scripts/verify-toolchain.sh`，串联验证：

- `multica-loop.sh --policy-help`
- `evidence-checklist.sh`
- `evidence-index.sh`
- `review-packet.sh`
- 各脚本 `bash -n`

## 已完成

- 支持 `--case`、`--pattern`、`--output`。
- 生成本地 verification report。
- 在案例执行指南中加入工具链自检用法。

## 风险边界

- 只读取本地脚本和 `runs/` 目录。
- 只在显式 `--output` 时写本地文件。
- 不读取 Multica issue。
- 不写 Multica comment/status。
- 不 push、不 commit、不创建 MR。

## 验证结果

本阶段验证命令均已通过：

```bash
bash -n scripts/verify-toolchain.sh
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*'
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*' --output runs/FUZ-554-toolchain-verify-pilot/verification-report.md
test -s runs/FUZ-554-toolchain-verify-pilot/verification-report.md
```

同时验证无匹配 pattern 会返回非零退出，避免误报工具链可用。

## 结论

工具链自检试点成立。`verify-toolchain.sh` 可以作为复用本地 helper scripts 前的 smoke check 入口。
