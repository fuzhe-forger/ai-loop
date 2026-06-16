# 阶段报告：Phase 59 Local Adoption Protocol

## 目标

将 AI 工作编排系统在本地真正使用起来，落实三条默认规则：

1. 所有任务均需要上 Multica 追踪。
2. 所有智能体均需要按照 Loop 的方式协同工作和沟通。
3. 所有工作需要沉淀到 Obsidian 作为知识库，并成为系统自进化输入。

## 已完成

### 1. 本地运行总规约

新增：`docs/ai-work-orchestration/21-local-operating-protocol.md`

定义：

- Multica 是任务事实源。
- Loop 是协作协议。
- Obsidian 是知识沉淀层。
- 人类是最终决策者。

标准流程：

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

### 2. Multica 追踪门禁

新增：`scripts/loop-intake-gate.sh`

检查：

- issue ID 格式正确。
- task 文件存在。
- task 文件引用同一个 issue ID。
- task 文件包含目标、验收、边界。
- repo 可访问且是 git worktree。
- 可选：远端 Multica issue 存在。

验证：

```bash
./scripts/loop-intake-gate.sh \
  --issue FUZ-554 \
  --task tasks/FUZ-554.md \
  --repo . \
  --output /tmp/loop-intake-gate.md
```

结果：PASSED。

### 3. 智能体 Loop 协同协议

新增：`scripts/loop-handoff.sh`

能力：

- 生成标准 handoff 消息。
- 自动映射角色到机组成员：顾实、裴衡、黑墙、测真、简辞、人类。
- 自动列出 run evidence。
- 标记状态、下一步动作和副作用。

验证：

```bash
./scripts/loop-handoff.sh \
  --issue FUZ-554 \
  --run-id FUZ-554-scope-split-review \
  --from-role execution_agent \
  --to-role reviewer \
  --state review_ready \
  --next-action 'review evidence and decide approve/request_changes'
```

结果：生成 顾实 → 裴衡 的标准 handoff。

### 4. Obsidian 知识沉淀与自进化

新增：`docs/ai-work-orchestration/22-obsidian-self-evolution.md`

纳入版本控制：

- `scripts/obsidian-sync.sh`
- `scripts/daily-ops-sync.sh`
- `state/multica-loop-obsidian-handoff.md`

能力：

- 同步 Multica 项目和 issue 快照。
- 同步 Agent/runtime/autopilot 状态。
- 同步 ai-loop 文档索引和 run evidence。
- 同步 CodeGraph 仓库卡片。
- 只写 Obsidian `99-generated/`，不覆盖人工区。

验证：

```bash
DRY_RUN=true ./scripts/obsidian-sync.sh
```

结果：PASSED。

生成预览：

- Multica 快照页
- Loop run 索引
- ai-loop 文档镜像（23 文档）
- CodeGraph 仓库卡片（25 个）
- Loop run 证据页（45 个）

## 当前系统默认口径

### 任务入口

正式任务没有 Multica issue，不进入 Loop。

### 智能体协同

智能体交接必须有：

- issue
- run_id
- from_actor / to_actor
- loop_state
- evidence
- next_action
- side_effects

### 知识沉淀

每次执行结束后：

- run evidence 进入 Obsidian。
- experience draft 进入人工复核。
- memory recommendation 用于下一次任务。
- 项目记忆持续更新。

## 边界

- 本阶段只做本地落地和 dry-run 验证。
- 未新建 Multica issue。
- 未写入 Multica comment/status/metadata。
- 未实际写入 Obsidian（只执行 `DRY_RUN=true`）。
- crontab 状态来自既有交接，未在本阶段修改。

## 结论

本地使用规约已经落地：所有新任务默认先进入 Multica 追踪，所有智能体交接使用 Loop handoff，所有执行完成后通过 Obsidian 同步沉淀到知识库。系统具备从任务、协同、证据、回写到知识自进化的本地闭环。
