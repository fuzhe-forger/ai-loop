# 阶段报告：Phase 35 Loop State Machine

## 目标

把 Multica Loop 从“证据标准”继续推进到“状态推进规则”，明确 issue 如何从输入走到复核、回写、完成或阻塞。

## 已完成

- 新增 `docs/ai-work-orchestration/11-loop-state-machine.md`。
- 定义 `intake`、`clarify`、`planned`、`dry_run_ready`、`run_ready`、`running`、`evidence_ready`、`review_ready`、`writeback_ready`、`done`、`blocked`、`escalated`。
- 明确每个关键流转的门禁。
- 明确异常流转和循环升级规则。
- 明确状态机输入来自 issue metadata、evidence metadata、policy metadata。

## 关键结论

状态机的核心不是自动完成任务，而是：

- 根据 evidence 判断下一步。
- 把副作用留在明确授权之后。
- 让 blocked 和 escalated 成为一等状态。
- 让 reviewer 和人类决策点可见。

## 下一步

工程上优先补一个本地状态判断脚本：

```text
run evidence -> evaluate-state -> suggested state + next actor + reason
```

它先只输出建议，不自动写 Multica。
