# 本地运行总规约：Multica × Loop × Obsidian

## 目标

把 AI 工作编排系统真正用于本地日常工作，并把三条规则设为默认口径：

1. **所有任务必须上 Multica 追踪**。
2. **所有智能体必须按 Loop 方式协同和沟通**。
3. **所有工作必须沉淀到 Obsidian，形成知识库和系统自进化输入**。

## 默认运行原则

- **Multica 是任务事实源**：没有 Multica issue 的工作，不进入正式 Loop 执行。
- **Loop 是协作协议**：所有 agent 输出必须带状态、证据、下一角色和副作用说明。
- **Obsidian 是知识沉淀层**：每次执行完成后同步 run、文档、经验、项目记忆。
- **人类是最终决策者**：AI 可以建议、执行、复核，但远端副作用需要人控门禁。

## 任务入口规则

### 必须满足

每个正式任务必须具备：

- Multica issue ID，例如 `FUZ-554`。
- 本地 task 文件，例如 `tasks/FUZ-554-xxx.md`。
- 明确目标、范围、验收标准。
- 明确 side effects 策略。
- 明确验证命令或验证方式。

### 不允许

- 只有聊天描述，没有 Multica issue。
- 只有本地 task，没有远端追踪。
- 直接让 agent 执行远端副作用。
- 没有 evidence 就声明完成。

## 标准执行流程

```text
Multica Issue
  -> loop-intake-gate
  -> task.md
  -> classify-task
  -> recommend-memory
  -> generate-plan
  -> ai-loop dry-run / run
  -> collect-evidence
  -> evaluate-state
  -> metadata-draft
  -> route-actor
  -> review-packet
  -> writeback-gate
  -> human decision
  -> optional Multica writeback
  -> obsidian-sync
  -> memory / self-evolution
```

## Multica 追踪规则

### Intake Gate

所有任务先过 intake gate：

```bash
./scripts/loop-intake-gate.sh \
  --issue FUZ-554 \
  --task tasks/FUZ-554-example.md \
  --repo /path/to/repo
```

Gate 检查：

- issue ID 格式正确。
- task 文件存在。
- task 文件引用同一个 issue ID。
- task 文件包含目标、验收、边界。
- repo 可访问。
- 可选：远端 Multica issue 存在。

### 远端写入

- 创建 issue、写 comment、改 status、写 metadata 都属于远端副作用。
- 默认只生成草稿和 gate report。
- 用户明确授权后才执行。

## Loop 协同规则

### 每个智能体消息必须包含

```yaml
issue: FUZ-xxx
run_id: FUZ-xxx-...
from_actor: 顾实
from_role: execution_agent
to_actor: 裴衡
to_role: reviewer
loop_state: evidence_ready
message_type: handoff
side_effects: none
evidence:
  - runs/<run>/summary.md
  - runs/<run>/stage-report.md
  - runs/<run>/review-packet.md
next_action: review evidence and decide approve/request_changes
```

### 角色职责

| 角色 | 名称 | 职责 | 默认可做 |
|---|---|---|---|
| `scheduler` | 黑墙 | 调度、分派、升级 | 分派、追踪、提醒 |
| `execution_agent` | 顾实 | 执行任务 | 本地执行、生成 evidence |
| `reviewer` | 裴衡 | 复核验收 | review packet、status 建议 |
| `tester` | 测真 | 验证测试 | 测试报告、风险提示 |
| `scribe` | 简辞 | 记录沉淀 | logbook、memory、Obsidian |
| `human` | 人类 | 最终决策 | 批准回写、关闭 issue |

### 协同边界

- 执行者不能自己批准完成。
- reviewer 不能绕过 evidence。
- scheduler 不能直接改 done。
- scribe 只能沉淀，不改变事实。
- human 可以覆盖建议，但需要记录原因。

## Obsidian 沉淀规则

### 自动生成区

所有自动生成内容写入：

```text
/mnt/d/JAVA/knowledge/tiandao/99-generated/
```

不覆盖人工维护区。

### 每次执行后沉淀

必须同步：

- Multica 项目和 issue 快照。
- Agent/runtime/autopilot 状态。
- ai-loop 文档索引。
- run evidence 页面。
- 项目记忆 `memory/`。
- CodeGraph 仓库卡片。

### 自进化输入

每个完成的 run 都应该尝试生成：

- experience draft。
- memory recommendation。
- missing constraint / pitfall 提醒。
- best-practice 更新建议。

## 日常同步

推荐每日执行：

```bash
cd /home/user/JAVA/ai/ai-loop
./scripts/daily-ops-sync.sh
```

已安装 crontab：

```cron
10 9 * * * /bin/bash /home/user/JAVA/ai/ai-loop/scripts/daily-ops-sync.sh >> /mnt/d/JAVA/logs/ai-loop/daily-ops-sync.cron.log 2>&1
```

## 完成定义

一个任务只有同时满足以下条件，才算完成：

- Multica 有追踪记录。
- 本地有 run evidence。
- strict gate 通过。
- state gate 通过。
- review packet 已复核。
- 远端副作用已通过 writeback gate。
- Obsidian 已同步或有明确待同步记录。
- 经验已进入 memory，或明确说明无需沉淀。

## 当前状态

- FUZ-554 已完成 Phase A-G。
- 黑墙已迁移到 Codex runtime。
- daily ops sync 已配置为本地 crontab。
- Obsidian 自动生成区已建立。
- 下一步是把上述规约设为所有新任务默认入口。

---

**状态**：本地默认运行规约  
**生成时间**：2026-06-16
