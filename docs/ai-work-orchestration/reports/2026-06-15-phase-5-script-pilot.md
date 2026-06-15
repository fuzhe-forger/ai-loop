# 阶段报告：Phase 5 脚本型低风险试点

## 目标

在 `FUZ-554` 文档型试点之后，继续选择一个真实但低风险的脚本增强任务，验证这套机制能覆盖本地脚本改动。

## 任务

为 `scripts/multica-loop.sh` 增加 `--policy-help`，让使用者在不读取 Multica、不提供 issue/repo 参数的情况下理解状态策略。

## 已完成

- 新增 `--policy-help` 参数。
- 输出 `conservative`、`validation`、`no-status` 的语义。
- 输出 comment/status 远端写入边界。
- 在案例执行指南中加入本地自查命令。

## 验证

| 命令 | 结果 |
|---|---|
| `bash -n scripts/multica-loop.sh` | PASSED |
| `./scripts/multica-loop.sh --policy-help` | PASSED |
| `./scripts/multica-loop.sh --policy-help | rg "conservative|validation|no-status|--write-comment|--write-status"` | PASSED |

## 风险边界

- 不访问 Multica 网络。
- 不写 comment。
- 不改 status。
- 不 push、不 commit、不创建 MR。

## 结论

脚本型低风险试点成立。后续可以把更多“解释型、检查型、dry-run 型”能力优先作为真实试点，而不是直接进入高风险自动执行。
