# Multica 回写与状态同步策略

## 目标

状态同步的目标不是“自动推进看板”，而是把 ai-loop 的执行证据转成保守、可解释、可人工复核的 Multica 状态。

## 基本原则

- 默认不写远端。
- comment 和 status 分开授权。
- comment、status、metadata 是三类不同远端副作用，必须分别记录。
- dry-run 成功只代表编排链路通过，不代表业务任务完成。
- 真实 run 成功才有资格进入 `in_review`。
- 失败状态应尽量保留失败原因，方便下一轮决策。

## 远端副作用分类

| 类型 | 当前能力 | 默认行为 | 证据要求 |
|---|---|---|---|
| comment | `--write-comment` | 不写 | `multica-comment.md` + `writeback-summary.md` |
| status | `--write-status` | 不写 | 状态策略 + `stage-report.md` + `writeback-summary.md` |
| metadata | 暂不写远端 | 只生成草稿 | `metadata-draft.json/md` |

metadata 写回暂不实现。当前只允许生成本地草稿，后续必须单独设计显式授权命令和 writeback evidence。

## 状态映射

### dry-run 模式

| ai-loop 状态 | error_code | 建议 Multica 状态 | 原因 |
|---|---|---|---|
| PASSED | 空 | todo | dry-run 只证明编排链路可行 |
| FAILED | FAILED_CONFIG | blocked | 配置问题，需要人工处理 |
| FAILED | FAILED_WORKSPACE | blocked | 本地工作区不可用 |
| FAILED | 其他 | blocked | 无法继续执行 |

### real-run 模式

| ai-loop 状态 | error_code | 建议 Multica 状态 | 原因 |
|---|---|---|---|
| PASSED | 空 | in_review | 已有执行和验证证据，进入复核 |
| FAILED | FAILED_VERIFY | blocked | 验证失败，需要修复或人工判断 |
| FAILED | FAILED_SAFETY | blocked | 安全检查失败，必须人工介入 |
| FAILED | FAILED_AGENT_EXIT | blocked | Agent 执行失败 |
| FAILED | FAILED_WORKSPACE | blocked | worktree 或 repo 状态问题 |
| FAILED | FAILED_CONFIG | blocked | 配置不完整或错误 |
| FAILED | 其他 | blocked | 保守处理 |

## 策略模式

### conservative

默认策略。dry-run 成功保持 `todo`，真实 run 成功进入 `in_review`。

### validation

适用于验证桥接工具自身。dry-run 成功也可以进入 `in_review`。

### no-status

永不变更状态，只生成 comment。该策略下 wrapper 的 `Mapped status` 记录为 `none`，表示没有可执行的状态写入目标。

## Wrapper 产物约定

每次执行 `scripts/multica-loop.sh` 都应至少生成三类本地证据：

- `summary.md`：ai-loop 执行摘要，作为运行事实入口。
- `multica-comment.md`：可人工复核后写回 Multica 的 comment 草稿。
- `stage-report.md`：桥接阶段报告，记录状态映射、映射原因、远端写入请求和实际写入结果。
- `writeback-summary.md`：远端写入请求和结果摘要，即使没有实际写入也要记录。

`stage-report.md` 中的状态字段按以下语义理解：

- `Status policy`：本次采用的同步策略。
- `Mapped status`：如果允许写状态，本次会写入的目标状态；`none` 表示策略禁止状态写入。
- `Mapping reason`：为什么产生该状态映射。
- `Comment written` / `Status written`：是否实际发生远端写入。
- `Metadata written`：当前固定为 `false`，因为 metadata 远端写回尚未实现。
- `Write error log`：远端写入失败时保留的本地错误日志路径。

这让每次执行都能被分享、复盘和审计，而不需要依赖终端输出。

## 当前建议

- `FUZ-552` 属于工具链自身验证，可使用 `validation`。
- 普通业务 issue 默认必须使用 `conservative`。
- 批量队列未来默认使用 `no-status` 或 `conservative`，不能使用 `validation`。

## Standing Policy

2026-06-15 起，用户已明确授权：本项目后续阶段性 Multica 回写不再逐次请求审批。

适用范围：

- 有本地证据包和 `multica-comment.md` 草稿的 `FUZ-*` 阶段性 comment 回写。
- 基于已验证策略的 issue status 同步。
- 本地 metadata 草稿生成。
- 回写后必须保留 `writeback-summary.md` 和 `logbook.md` 记录。

不适用范围：

- `git push`、`git commit`、MR 创建或合并。
- Multica issue metadata 远端写入。
- 生产系统访问、部署、数据库写入、批量破坏性操作。
- 删除文件、清理大目录或不可逆操作。

这些动作仍需单独确认。

## 2026-06-15 回归结果

基于 `FUZ-553` 完成三种策略的只读回归，均未执行远端写入：

- `FUZ-553-policy-v2-conservative`：`PASSED + conservative -> todo`。
- `FUZ-553-policy-v2-validation`：`PASSED + validation -> in_review`。
- `FUZ-553-policy-v2-no-status`：`PASSED + no-status -> none`。

结论：状态策略已从“运行结果直接改看板”升级为“运行证据 + 策略映射 + 显式写入”。
