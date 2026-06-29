# 阶段报告：Phase 61 Requirement Gate

## 目标

把 Phase H 从“方案设计与产出把控”前移到“需求沟通、方案设计与产出把控”，避免一片空白时 AI 直接进入方案设计或开发，减少返工和 token 消耗。

## 背景与问题

外部实践观点指出：需求调研和设计阶段在一开始一片空白时，必须先做需求沟通，不能直接开始写代码。这个观点与 `司南` 的治理方向一致：需求不清时，系统应该进入澄清，而不是进入设计或执行。

## 核心结论

- 新增需求沟通门禁：`scripts/requirement-gate.sh`。
- `requirement-gate` 支持 `--clarification-output`，可将失败项生成给人确认的 `clarification.md` 草稿。
- 更新 Phase H 文档：`docs/ai-work-orchestration/23-design-output-governance.md`。
- 更新标准流程：`requirement-gate -> generate-plan -> design-gate -> run -> deliverable-gate`。
- 更新 `README`、`north-star`、`local operating protocol`，把“需求先沟通”设为默认原则。
- `requirement-gate` 是 local-only，不读取 Multica，不产生远端副作用。

## 方案与设计

### requirement-gate

`requirement-gate` 检查需求草稿是否覆盖：

- 背景 / 问题 / 上下文。
- 用户 / 干系人 / 使用场景。
- 目标 / 期望结果。
- 范围 / 非目标 / 边界。
- 验收 / 成功标准。
- 约束 / 假设。
- 依赖 / 输入 / 上下游。
- 风险 / 待确认问题。
- 优先级 / 时间要求。
- 副作用 / 外部写入策略。

严格模式额外要求人工沟通或确认记录。

### 失败策略

如果 `requirement-gate` 失败，下一状态是 `needs_clarification`，默认不允许进入方案设计或开发。报告会输出 `Clarifying Questions`，用于下一轮需求沟通。

### clarification.md

当传入 `--clarification-output <file>` 时，脚本会生成澄清草稿，包含：

- 原需求路径、issue、gate 结果和下一状态。
- 需要人类确认的问题清单。
- 可直接补写的需求骨架。
- 重新运行 requirement gate 的下一步指引。

## 依赖与影响

- 依赖本地 `bash` 和 `rg`。
- 影响 `verify-toolchain.sh` 的本地 smoke check 清单。
- 不影响 Multica、飞书、Git remote、部署或生产系统。

## 风险与回滚

- 风险：关键词检查可能误判，早期需要通过真实任务继续调优。
- 降级：如果人类明确确认需求足够，可记录人工例外后进入设计。
- 回滚：删除 `scripts/requirement-gate.sh`，并从 README、north-star、local protocol、Phase H 文档中移除入口即可恢复。

## 验收与验证

验证命令：

```bash
bash -n scripts/requirement-gate.sh
./scripts/requirement-gate.sh --help
./scripts/requirement-gate.sh --input docs/ai-work-orchestration/23-design-output-governance.md --strict
./scripts/requirement-gate.sh --input /tmp/unclear-requirement.md --output /tmp/requirement-gate-unclear.md --clarification-output /tmp/clarification-unclear.md
./scripts/verify-toolchain.sh --list-checks
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*' --output /tmp/toolchain-phase-h.md
```

验证结果：

- `bash -n scripts/requirement-gate.sh`：PASSED。
- `requirement-gate --help`：PASSED。
- `requirement-gate` 检查 Phase H 规则文档：PASSED，score `100/100`，next state `ready_for_design`。
- `requirement-gate --clarification-output` 可以为模糊需求生成 `clarification.md` 草稿：PASSED。
- `design-gate` 检查 Phase H 规则文档：PASSED，score `100/100`。
- `deliverable-gate` 检查本阶段报告：PASSED，score `100/100`。
- `verify-toolchain.sh --list-checks` 已包含 `requirement-gate`、`design-gate`、`deliverable-gate`。
- `verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*'`：PASSED。

模糊需求校准：

- 用“帮我做一下这个系统，尽快。”作为输入时，`requirement-gate`：FAILED，score `9/100`，next state `needs_clarification`。
- 报告输出澄清问题，覆盖问题背景、用户场景、验收标准、依赖、风险、时间和副作用等关键缺口。
- `clarification.md` 已生成需求骨架，可直接交给人类补充确认；验证输出包含 Summary、Questions、Suggested Requirement Skeleton 和 Next Step。
- 这符合预期：需求不清时，系统只允许进入澄清阶段，不允许进入方案设计或开发。

Phase 61 follow-up：

- `clarification.md` 已接入 `collect-evidence.sh`，作为 run artifact 输出。
- `clarification.md` 已接入 `evidence-checklist.sh` 和 `evidence-index.sh`。
- `clarification.md` 已接入 `review-packet.sh`，reviewer 可以直接看到哪些 run 需要人类澄清。

## 负责人 / 角色

- Owner / DRI：傅喆。
- Actor：顾实。
- Reviewer：人工复核；后续可交给裴衡按 evidence 复核。

## 待决策 / 开放问题

- 是否把 `requirement-gate` 设为所有 S2+ 任务的硬性门禁。
- 是否为业务需求、技术需求、审计确认、故障排查设置不同需求检查权重。
- 是否将 `clarification.md` 接入 state gate，作为所有 `needs_clarification` 状态的必需 evidence。

## 副作用与回写状态

- Network access: false。
- Remote writes: false。
- Multica writeback: none。
- Feishu writeback: none。
- External side effect: none。

## 下一步

- 将 `clarification.md` 接入 state gate 和 Obsidian generated run 页面。
- 把 requirement/design/deliverable 三个 gate 的结果纳入 `review-packet.md`。
- 在真实 S2+ 任务中校准各类需求的检查权重。
