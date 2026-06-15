# 阶段报告：Phase 12 低风险真实代码改动试点

## 目标

在代码改动准入门禁建立后，选择一个低风险真实脚本改动，验证从 patch 到 verification report、stage report、Multica comment 草稿的闭环。

## 任务

为 `scripts/verify-toolchain.sh` 增加 `--list-checks`，让使用者可以在不读取 `runs/` 的情况下查看工具链 smoke check 列表。

## 已完成

- `verify-toolchain.sh` 新增 `--list-checks` 参数。
- `--list-checks` 输出本地 smoke check 列表。
- 常规自检新增 `bash -n scripts/verify-toolchain.sh` 自校验项。

## 风险边界

- 仅修改本地 helper script、文档和证据。
- 不读取 Multica issue。
- 不写 Multica status。
- 不 push、不 commit、不创建 MR。
- 不访问生产系统。

## 验证结果

本阶段验证命令均已通过：

```bash
bash -n scripts/verify-toolchain.sh
./scripts/verify-toolchain.sh --list-checks
./scripts/verify-toolchain.sh --list-checks | rg "multica-loop.sh|evidence-checklist.sh|evidence-index.sh|review-packet.sh"
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*' --output runs/FUZ-554-real-code-list-checks-pilot/verification-report.md
test -s runs/FUZ-554-real-code-list-checks-pilot/verification-report.md
```

## 结论

低风险真实代码改动试点成立。`FUZ-554` 已从文档/脚本样板推进到真实 patch，并保留了验证报告和阶段证据。
