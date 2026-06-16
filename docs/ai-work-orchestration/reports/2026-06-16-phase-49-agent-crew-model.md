# 阶段报告：Phase 49 Agent Crew Model

## 目标

把“机组”从口头概念沉淀为 Multica Loop 的 Agent Crew 能力角色模型，让状态机输出的 `next_actor` 能映射到具体角色。

## 已完成

- 新增 `docs/ai-work-orchestration/13-agent-crew-model.md`。
- 更新总入口 `docs/ai-work-orchestration/README.md`。

## 机组角色

当前定义六类角色：

- 黑墙：调度/总控。
- 顾实：工程执行。
- 裴衡：复核审查。
- 测真：验证测试。
- 简辞：表达沉淀。
- 人类：目标、边界、授权和最终决策。

## 核心内容

- `next_actor` 到具体角色的映射。
- 任务类型到默认角色的路由矩阵。
- A2A 最小消息格式。
- 顾实/裴衡、顾实/测真、黑墙/人类的循环保护阈值。
- 远端副作用和缺 evidence 的红线。

## 结论

Multica Loop 现在具备三层闭环：

```text
状态机：判断下一状态和 next_actor
机组模型：把 next_actor 映射到具体角色
evidence：约束每次流转必须可复核
```

## 下一步

- 增加本地 `route-actor` 脚本。
- 在 metadata draft 中增加 `assigned_actor` 草稿字段。
- 在 review packet 中显示建议具体角色。
