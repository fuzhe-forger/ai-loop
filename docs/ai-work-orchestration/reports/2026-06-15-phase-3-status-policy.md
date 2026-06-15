# 阶段报告：Phase 3 状态策略精炼

## 目标

把 Multica 状态同步从简单的 `PASSED -> in_review` 升级为可解释、可审计、可分享的策略映射机制。

## 背景

Phase 1 已打通 Multica issue 到 ai-loop dry-run 的本地闭环。Phase 2 已验证显式 comment/status 远端写入能力。但直接把 dry-run 的 `PASSED` 视为业务完成存在风险：它只能说明编排链路可用，不能说明业务任务已经实现。

因此 Phase 3 的重点是把“状态变化”从执行结果中解耦出来，引入策略层。

## 已实现

`scripts/multica-loop.sh` 新增并验证三种状态策略：

- `conservative`：默认策略，dry-run 通过后仍映射为 `todo`。
- `validation`：用于验证桥接工具自身，dry-run 通过后可映射为 `in_review`。
- `no-status`：强制不产生状态写入目标，映射为 `none`。

同时，stage report 增加了以下证据字段：

- `Status policy`
- `Mapped status`
- `Mapping reason`
- `Comment written`
- `Status written`
- `Write error log`

## 验证结果

本轮以 `FUZ-553` 为样例执行只读回归，未写入 Multica comment，未修改 Multica 状态。

| Run ID | Policy | Loop Result | Mapped Status | Remote Write |
|---|---|---|---|---|
| `FUZ-553-policy-v2-conservative` | `conservative` | `PASSED` | `todo` | 否 |
| `FUZ-553-policy-v2-validation` | `validation` | `PASSED` | `in_review` | 否 |
| `FUZ-553-policy-v2-no-status` | `no-status` | `PASSED` | `none` | 否 |

## 设计结论

- `ai-loop` 的运行状态是事实，不直接等同于 Multica 的业务状态。
- Multica 状态应由“运行事实 + 策略 + 显式授权”共同决定。
- 默认策略必须保护看板，不把 dry-run 成功误判为业务完成。
- 每次执行都需要留下可分享的 `stage-report.md`，作为团队复盘入口。

## 风险边界

本阶段仍然保持以下边界：

- 默认不写 Multica comment。
- 默认不改 Multica status。
- 不批量处理 issue。
- 不 push、不 commit、不创建 MR。
- 不访问生产系统。

## 下一步

建议进入 `FUZ-554`：选择一个真实但低风险的本地 Loop 任务，跑通从 Multica 项目工作项到 ai-loop 执行证据，再到人工复盘文档的完整案例。
