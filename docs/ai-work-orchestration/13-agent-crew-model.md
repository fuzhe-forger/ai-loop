# Agent Crew 机组模型

## 定位

Agent Crew 是 Multica Loop 的能力角色层。

它不等于“多开几个模型”，而是把任务分成明确角色：谁调度、谁执行、谁复核、谁验证、谁沉淀表达。

## 目标

- 避免单 agent 黑盒执行。
- 让任务路由、复核、升级有规则。
- 让 `next_actor` 能从状态机字段落到具体角色。
- 让多角色协作仍然保持 evidence-first 和 human-in-command。

## 机组角色

| 角色 | 定位 | 主要职责 | 输入 | 输出 |
|---|---|---|---|---|
| 黑墙 | 调度/总控 | 判断任务类型、风险、是否追问、是否升级 | issue、metadata、历史记忆 | 路由决策、升级决策 |
| 顾实 | 工程执行 | 本地代码修改、脚本实现、文档落地、验证命令 | task、repo、验收标准 | patch、summary、verification |
| 裴衡 | 复核审查 | 基于 evidence 做 review，判断 approve/request changes | review packet、diff、state | review verdict、风险意见 |
| 测真 | 验证测试 | 补充测试、复现失败、确认验证口径 | verification report、命令、环境 | test result、blocked reason |
| 简辞 | 表达沉淀 | 把复杂过程整理成分享稿、报告、comment 草稿 | evidence、决策、上下文 | share docs、comment draft |
| 人类 | 目标/边界/最终决策 | 定目标、验收、授权远端副作用、最终批准 | 所有 evidence | approval、scope、policy |

## next_actor 映射

| `next_actor` | 默认角色 | 说明 |
|---|---|---|
| `execution_agent` | 顾实 | 需要补执行、补 artifact、补验证 |
| `reviewer` | 裴衡 | evidence 已够，进入复核 |
| `human` | 人类 | 需要授权、验收或最终判断 |
| `scheduler` | 黑墙 | 需要重新路由或升级 |
| `tester` | 测真 | 需要验证、复现或测试判断 |
| `scribe` | 简辞 | 需要沉淀、分享或表达整理 |

## 路由矩阵

| 任务类型 | 默认角色 | 需要复核 | 常见 evidence |
|---|---|---|---|
| 文档/分享 | 简辞 | 裴衡 | report、share docs、preflight |
| 脚本/MVP 工具 | 顾实 | 裴衡 + 测真 | patch summary、verification report |
| 状态/策略设计 | 黑墙 + 简辞 | 人类 | policy doc、state report |
| 测试失败/验证争议 | 测真 | 裴衡 | repro、test output |
| 任务不清/风险不清 | 黑墙 | 人类 | clarify questions、blocked reason |
| 远端写入 | 人类 | 黑墙 | writeback summary、policy decision |

## A2A 协议最小消息

角色之间传递任务时，最小消息应包含：

```json
{
  "issue": "FUZ-xxx",
  "run_id": "FUZ-xxx-...",
  "from_actor": "scheduler",
  "to_actor": "reviewer",
  "intent": "review evidence and decide next step",
  "evidence": [
    "runs/<run>/summary.md",
    "runs/<run>/stage-report.md",
    "runs/<run>/review-packet.md"
  ],
  "expected_output": "review_verdict",
  "side_effects_allowed": false
}
```

## 循环保护

| 循环 | 阈值 | 动作 |
|---|---|---|
| 顾实 ↔ 裴衡 | 2 轮 request changes | 升级黑墙重新拆分任务 |
| 顾实 ↔ 测真 | 2 轮验证失败 | 升级人类确认验收口径 |
| 黑墙 ↔ 人类 | 3 次仍不清楚 | 标记 `blocked` |
| 任意角色 | 缺 evidence | 返回 `execution_agent` 补证据 |

## 与状态机关系

状态机只输出抽象角色，例如 `reviewer`、`execution_agent`、`human`。

机组模型负责把抽象角色映射到具体 agent：

```text
review_ready + next_actor=reviewer -> 裴衡
blocked + missing_evidence -> 顾实
escalated -> 黑墙 / 人类
writeback_ready -> 人类
```

## 红线

- 机组不能绕过 human approval 执行远端副作用。
- 机组不能把 review verdict 当作业务完成。
- 机组不能在缺 evidence 时继续传递“已完成”。
- 机组不能无限循环；必须有阈值和升级。
- 机组不能共享 token、cookie、密钥或生产数据。

## MVP 落地

当前只做本地文档和 metadata 字段对齐：

1. `metadata-draft.json.next_actor` 输出抽象角色。
2. 机组模型定义抽象角色到具体角色的映射。
3. 后续再实现本地 `route-actor` 脚本。

## 下一步

- 增加 `route-actor` 本地脚本。
- 在 review packet 中显示建议具体角色。
- 在 metadata draft 中增加 `assigned_actor` 草稿字段。
