# Loop Handoff 摘要模板

用于智能体之间交接，确保下一角色拿到最小充分信息。

```yaml
issue: FUZ-xxx
run_id: FUZ-xxx-...
from_actor: 顾实
from_role: execution_agent
to_actor: 裴衡
to_role: reviewer
loop_state: review_ready
message_type: handoff
side_effects: none
summary:
  - 核心结论 1
  - 核心结论 2
  - 核心结论 3
risk:
  - 风险项 1
evidence:
  - type: task
    path: tasks/FUZ-xxx.md
  - type: summary
    path: runs/<run>/summary.md
  - type: review_packet
    path: runs/<run>/review-packet.md
next_action: review evidence and decide approve/request_changes
```

## 使用规则

- `summary` 最多 5 条。
- `evidence` 必须是路径或链接，不粘贴完整日志。
- `next_action` 必须是可执行动作。
- 如果存在远端副作用，必须在 `side_effects` 中说明并等待授权。
