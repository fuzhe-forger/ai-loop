# 本地运行总规约：Multica × Loop × Obsidian

## 目标

把 AI 工作编排系统真正用于本地日常工作，并把三条规则设为默认口径：

1. **所有任务必须上 Multica 追踪**。
2. **所有智能体必须按 Loop 方式协同和沟通**。
3. **所有工作必须沉淀到 Obsidian，形成知识库和系统自进化输入**。
4. **所有任务开工前必须估时，收工后必须复盘真实用时**。
5. **所有正式 Loop 必须记录可信计时，并把估时偏差纳入复盘**。

## 默认运行原则

- **Multica 是任务事实源**：没有 Multica issue 的工作，不进入正式 Loop 执行。
- **Loop 是协作协议**：所有 agent 输出必须带状态、证据、下一角色和副作用说明。
- **Obsidian 是知识沉淀层**：每次执行完成后同步 run、文档、经验、项目记忆。
- **可信计时是执行校准层**：`loop-closeout` 默认记录 `started_at/completed_at`，`time-estimation-calibration` 只使用 timestamp 样本校准估时。
- **估时推荐前置化**：`loop-execution-preflight` 有 `run-id` 时优先读取该 run 的 `time-estimation-calibration.json`，用可信样本推荐值覆盖静态 timebox 默认值。
- **时间契约是窗口执行层**：聊天内任务也必须遵守 `25-execution-time-contract.md`，开工先估时，收工报告实际秒数/分钟和偏差。
- **人类是最终决策者**：AI 可以建议、执行、复核，但远端副作用需要人控门禁。

## 任务入口规则

正式执行前先参考 `docs/ai-work-orchestration/24-execution-governance-matrix.md`，统一判断任务是否清晰、是否需要 phase report、哪些副作用允许、哪些写回必须等待 closeout。

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
  -> loop-execution-preflight
  -> loop-intake-gate
  -> task.md
  -> classify-task
  -> recommend-memory
  -> requirement-gate
  -> generate-plan
  -> design-gate
  -> ai-loop dry-run / run
  -> collect-evidence
  -> deliverable-gate
  -> gate-policy-check
  -> evaluate-state
  -> metadata-draft
  -> route-actor
  -> review-packet
  -> writeback-gate
  -> human decision
  -> optional Multica writeback
  -> loop-closeout
  -> time-estimation-calibration
  -> obsidian-sync
  -> memory / self-evolution
```

## Multica 追踪规则

### 结论优先模板

所有新 issue、阶段性 comment、智能体 handoff、Obsidian 摘要卡默认使用以下模板：

- `docs/ai-work-orchestration/templates/multica-issue-summary-template.md`
- `docs/ai-work-orchestration/templates/multica-comment-summary-template.md`
- `docs/ai-work-orchestration/templates/loop-handoff-summary-template.md`
- `docs/ai-work-orchestration/templates/obsidian-readable-card-template.md`

人类默认阅读层必须先给 3-5 条核心结论；完整过程、日志、文档和代码证据必须通过链接或路径补充。

### Intake Gate

正式执行前先生成执行包 checklist，避免一上来直接开写：

```bash
./scripts/loop-execution-preflight.sh \
  --issue FUZ-554 \
  --task tasks/FUZ-554.md \
  --repo . \
  --run-id <run-id> \
  --task-type documentation \
  --allow-feishu-write \
  --allow-multica-write \
  --phase-report auto
```

Checklist 必须明确：目标、验收、边界、允许副作用、禁止副作用，以及是否需要 phase report。默认只允许本地文件、本地验证和 Obsidian generated sync；本轮如获得人类授权，才可把 Feishu / Multica 写入标记为允许。`--task-type` 可显式选择估时校准桶，避免文档切片被脚本关键词误判为 `local_script_patch`。

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

### Requirement Gate

所有 S2+ 任务进入方案设计前，先检查需求沟通是否充分：

```bash
./scripts/requirement-gate.sh \
  --input docs/ai-work-orchestration/23-design-output-governance.md \
  --strict
```

需求不清时生成澄清草稿：

```bash
./scripts/requirement-gate.sh \
  --input tasks/FUZ-xxx.md \
  --output runs/<run-id>/requirement-gate.md \
  --clarification-output runs/<run-id>/clarification.md
```

Gate 检查：

- 背景、用户、目标、范围和验收标准清晰。
- 约束、依赖、风险、优先级和时间要求明确。
- 副作用和外部写入策略明确。
- 严格模式要求有人类沟通或确认记录。

如果 requirement gate 失败，只能进入澄清阶段，并把 `clarification.md` 交给人类确认，不能直接进入方案设计或开发。

`needs_clarification` 状态下，`clarification.md` 属于正式 run evidence，必须出现在：

- `collect-evidence` 输出。
- `evidence-checklist`。
- `evidence-index`。
- `review-packet`。
- Obsidian generated run 页面。

State gate 规则：

- `requirement-gate.md` 失败且 `clarification.md`、`clarification-gate.md` 均存在且质量检查通过：状态进入 `needs_clarification`，下一角色是 `human`。
- `requirement-gate.md` 失败但 `clarification.md` 缺失：状态进入 `blocked`，下一角色是 `execution_agent` 补齐 evidence。
- `requirement-gate.md` 失败但 `clarification-gate.md` 缺失或未通过：状态进入 `blocked`，下一角色是 `execution_agent` 补齐质量 evidence。
- 非澄清场景下 `gate-policy-check.md/json` 结果为 `FAILED`：状态进入 `blocked`，下一角色是 `execution_agent` 修复 required gates 或记录人工例外。

交给人类前，建议运行：

```bash
./scripts/clarification-gate.sh --run-id <run-id> --strict
```

如果 `clarification-gate` 缺失或失败，先补齐澄清草稿，不要把不可回答的问题清单交给人类。

### Design Gate

所有 S2+ 任务进入执行前，先检查方案设计质量：

```bash
./scripts/design-gate.sh \
  --input docs/ai-work-orchestration/23-design-output-governance.md \
  --strict
```

Gate 检查：

- 背景、目标、范围和非目标清晰。
- 方案、依赖、影响和集成关系明确。
- 风险、回滚、降级和验证方式明确。
- 待决策问题、负责人和副作用策略明确。

### Deliverable Gate

所有准备交给人类复核、回写远端或沉淀到知识库的产出，先检查可读性和完整性：

```bash
./scripts/deliverable-gate.sh \
  --input docs/ai-work-orchestration/reports/2026-06-18-phase-60-design-output-governance.md
```

### 任务类型策略门禁

产出 gate 之后，按任务类型检查 required gates 和最低分：

```bash
./scripts/gate-policy-check.sh \
  --run-id <run-id> \
  --task-type feature \
  --output runs/<run-id>/gate-policy-check.md \
  --json-output runs/<run-id>/gate-policy-check.json
```

默认策略文件是 `config/gate-policy.json`。`feature`、`refactor`、`infrastructure` 和 `unknown` 会更严格地要求 `requirement`、`design`、`deliverable`；`documentation` 和 `test` 默认不强制 design gate，但如果 design gate 存在仍会按建议分数检查。`clarification-gate` 一旦存在，或 requirement gate 失败，就会升级为必检 gate。

Gate 检查：

- 目的、结论和核心结果清晰。
- evidence、产物路径和验证结果完整。
- 负责人、下一步和副作用 / 回写状态明确。




### Gate Policy 人工例外

当 `gate-policy-check` 失败但人类确认可以继续时，必须生成本地例外 evidence：

```bash
./scripts/gate-policy-exception.sh \
  --run-id <run-id> \
  --approved-by <human-name> \
  --reason '<why this exception is acceptable>' \
  --expires <YYYY-MM-DD>
```

例外会生成：

- `gate-policy-exception.json`
- `gate-policy-exception.md`

只有 `status=ACTIVE`、包含 `approved_by` 和 `reason` 的例外会让 `evaluate-state` 不再因 gate policy 失败而阻断。例外只影响本地状态建议，不批准远端 comment/status/metadata 回写。

### 单次 Multica Loop 收尾 evidence

`multica-loop.sh` 在 dry-run 后会生成本地 evidence，不会默认远端写入：

- `classification.json`
- `gate-policy-check.json` / `gate-policy-check.md`
- `state-evaluation.json` / `state-evaluation.md`
- `metadata-draft.json` / `metadata-draft.md`
- `multica-comment.md`
- `stage-report.md`
- `writeback-summary.md`

可用 `--task-type <type>` 覆盖分类结果，也可用 `--skip-gate-policy` 跳过策略生成。`--write-comment` 和 `--write-status` 仍是远端副作用，必须由人类显式审批。

### 批量刷新 run evidence

需要批量补齐 state、metadata 和 gate policy 时使用：

```bash
./scripts/refresh-run-evidence.sh \
  --pattern '<run-pattern>' \
  --issue <issue-id> \
  --task-type feature
```

默认会写入每个匹配 run 的：

- `state-evaluation.json` / `state-evaluation.md`
- `metadata-draft.json` / `metadata-draft.md`
- `gate-policy-check.json` / `gate-policy-check.md`

如果只想保留旧行为，可使用 `--skip-gate-policy`。如果希望策略失败阻断刷新命令，可使用 `--strict-gate-policy`。

### 远端写入

- 创建 issue、写 comment、改 status、写 metadata 都属于远端副作用。
- 默认只生成草稿和 gate report。
- 用户明确授权后才执行。

执行任何可能带副作用的动作前，先用 approval boundary 做本地判断：

```bash
./scripts/approval-boundary.sh --action obsidian-sync --issue FUZ-554 --run-id <run-id>
```

规则：

- 动作分类、审批要求和默认决策统一维护在 `config/approval-boundary.json`。
- `local-edit`、`verify`、`collect-evidence`、`share-preflight`、`golden-path-check` 默认可继续。
- `obsidian-sync` 已获得常驻授权，可直接写入 Obsidian `99-generated/` 并记录 `state/operations/` 操作日志。
- `tool-install`、`codex-config`、`multica-comment`、`multica-status`、`multica-metadata`、`feishu-write`、`git-remote`、`deploy` 仍必须停下等待明确审批。
- 未识别动作按需要审批处理。
- `approval-boundary` 只生成本地报告，不执行任何远端写入。
- `metadata-writeback.sh --write` 也必须先生成 `approval-boundary-metadata.*`，再进入 `writeback-gate` 和真实 Multica metadata 写入。
- `golden-path-check` 对已完成 comment/metadata 远端写回的 run，会要求存在对应 `approval-boundary-comment.*` / `approval-boundary-metadata.*` 证据。
- `review-packet` 会把已完成写回对应的 approval boundary 汇总到人工复核表，避免只看写回结果不看审批证据。
- `share-preflight-summary.md/json` 必须直接展示 golden path 结果、失败数和 approval boundary 快照，作为分享前的一页式出口和结构化 evidence。
- 分享候选 run 应使用 `share-preflight --persist-to-run`，把 `share-preflight-summary.md/json` 保存到 `runs/<run>/`，供 evidence、Obsidian 和后续 AI 交接召回。
- `verify-toolchain` 内部检查 `share-preflight` 时必须使用 `--skip-verify`，避免 share-preflight 与 verify-toolchain 互相递归。

### 外部产物链接回写

- 任何飞书文档、Wiki、MR、Grafana 面板、发布单、测试报告等外部产物，一旦创建或确认采用，必须回写到对应 Multica issue。
- 回写内容至少包含：产物名称、URL、本地草案或 evidence 路径、写入时间、当前状态。
- 若创建外部产物时发生限流、失败或只创建了空壳，必须在同一轮补写内容并验证，再回写 issue。
- 若暂时无法回写，必须在当前回复中明确标记 `待回写 Multica`，并说明阻塞原因。
- 完成前必须检查对应 issue 描述或 comment 中是否已包含最新外部产物链接。

### Closeout

本地实现完成后，优先用统一 closeout 入口收尾，减少重复命令和遗漏：

```bash
./scripts/loop-closeout.sh \
  --issue FUZ-554 \
  --task tasks/FUZ-554.md \
  --repo . \
  --run-id <run-id> \
  --allow-feishu-write \
  --allow-multica-write
```

Closeout 只执行本地 preflight、toolchain 验证、share-preflight、evidence checklist 和 evidence index；它不执行 Feishu、Multica、Git remote、deploy 或 Obsidian 写入。Obsidian sync 由常驻授权的 `obsidian-sync.sh` 在本地验证通过后单独执行。

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

## 输出压缩与长上下文节流

司南已接入 Caveman / Cavecrew 作为 Codex 全局 skill，用于长任务中的输出 token 控制。它只改变表达密度，不改变事实、证据、审批边界或验证标准。

默认使用规则：

- 用户明确说 `caveman mode`、`少废话`、`压缩输出`、`省 token` 时，启用 caveman 风格输出。
- 长 Loop、反复中间进展、子代理回传、代码定位类汇报，优先使用压缩表达，减少主上下文膨胀。
- 安全警告、不可逆操作确认、飞书/Multica/远端写回审批、代码、commit message、PR 文本、evidence 事实，不使用会造成歧义的压缩。
- `cavecrew` 只用于可独立委派且需要压缩回传的子任务；不替代司南的 preflight、gate、evidence 和 approval boundary。
- `caveman-compress` 会改写文件，必须先确认目标文件和备份策略；不能自动压缩未经审批的仓库记忆或人工文档。

安装与验证：

- 全局 skill 路径：`~/.agents/skills/caveman*` 和 `~/.agents/skills/cavecrew`。
- 可见性验证：`npx skills list --global -a codex --json`。
- 司南注册表：`config/sinan-capabilities.json` 的 `token_output_compression`。

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

### 同步操作日志

Obsidian 同步本身的审计记录必须写入 `state/operations/`，不能为了记录“刚执行过一次同步”而新建 `docs/ai-work-orchestration/reports/` 阶段报告。

规则：

- `reports/` 只记录实质性方案、机制、产出或决策变化。
- `state/operations/` 记录同步、巡检、脚本运行等本地操作审计。
- `state/operations/` 不作为 `obsidian-sync` 的镜像输入，避免“同步日志又需要同步”的递归审批循环。
- 如果同步后发现还需要补正式文档，先补文档，再把它并入下一批实质性同步，不单独为同步日志申请审批。

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
- requirement gate 已通过，或有人工例外记录。
- design gate 已通过，或有人工例外记录。
- deliverable gate 已通过，或有人工例外记录。
- review packet 已复核。
- 远端副作用已通过 writeback gate。
- 新建或采用的外部产物链接已回写到 Multica issue。
- Obsidian 已同步或有明确待同步记录。
- 经验已进入 memory，或明确说明无需沉淀。

## 当前状态

- FUZ-554 已完成 Phase A-G。
- Phase H 已接入需求沟通、方案设计与产出把控门禁。
- 黑墙已迁移到 Codex runtime。
- daily ops sync 已配置为本地 crontab。
- Obsidian 自动生成区已建立。
- 下一步是把 requirement gate / design gate / deliverable gate 纳入所有 S2+ 新任务默认入口。

---

**状态**：本地默认运行规约  
**生成时间**：2026-06-18
