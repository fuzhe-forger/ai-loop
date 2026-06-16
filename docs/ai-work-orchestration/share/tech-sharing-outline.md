# 技术分享大纲：从 AI 编码助手到可治理的 AI 工作编排

## 分享定位

这次分享不是介绍一个脚本，也不是展示某个 Agent 多聪明，而是讲清楚一件事：

> 如何把 AI 放进一个可治理、可审计、可复盘、可持续进化的工程工作系统。

建议时长：20–30 分钟。

## 听众应该带走什么

- AI 工程化的关键不是“更自动”，而是“更可控”。
- Multica、ai-loop、黑墙/天道经验分别承担不同层次。
- Evidence 是 AI 工作能否进入团队协作的前提。
- 人类不是被替代，而是从执行者上移为目标、边界和验收的设计者。
- 这套方法可以从一个低风险 issue 开始复制。

## 0. 开场：先讲终局

核心句：

> 我们最终要做的是 AI 工程团队操作系统，而不是一组自动化脚本。

展示：`docs/ai-work-orchestration/09-north-star.md`

讲法：

- Multica 是任务事实源。
- ai-loop 是本地执行事实源。
- Multica Loop 是组织与治理层。
- Agent Network 是能力角色层。
- Artifacts & Memory 是知识沉淀层。

## 1. 问题：为什么单个 AI 助手不够

痛点：

- 聊天记录不可审计。
- “已完成”没有证据。
- 失败原因不结构化。
- 状态更新靠感觉。
- 经验散在不同窗口里。
- 团队成员无法复盘全过程。

转折：

> 所以我们不是要更会聊天的 AI，而是要能进入工程控制结构的 AI。

## 2. 原则：先治理，后自动化

五条原则：

- Local first：先本地隔离执行。
- Evidence first：先证据，再结论。
- Human in command：人控制目标、边界、验收和副作用。
- Explicit side effects：所有远端写入必须显式确认。
- Small loop before big loop：先单 issue，再多 agent 协作。

## 3. 架构：三层事实源

```text
Multica Issue
  -> Multica Loop policy / routing / memory
  -> ai-loop task / run / verify / evidence
  -> review packet / comment draft
  -> human-approved writeback
```

强调：

- Multica 记录任务事实。
- ai-loop 记录执行事实。
- Multica Loop 记录组织决策和记忆。

## 4. 案例：FUZ-554 如何从想法变成证据链

展示：`docs/ai-work-orchestration/share/FUZ-554-one-page.md`

讲法：

- 从 Multica issue 到本地 task。
- 从 dry-run 到 summary / stage report / comment draft。
- 从 patch summary 到 scope check。
- 从 review packet 到 strict evidence gate。
- 最后做 scope split，避免混合提交。

关键数字：

- `FUZ-554*` 本地 run：22 个。
- core evidence：22/22 完整。
- strict gate + state gate：通过。

## 5. 黑墙确认：天道不是代码，是编排经验

展示：FUZ-559 的结论摘要。

讲法：

- 不引入 LingTai 代码。
- “天道”是 Multica 智能体编排层经验。
- 可复用的是 A2A、循环保护、任务路由、metadata、任务确认规则。

落点：

> 我们不是复制别人的项目，而是把已有经验吸收进自研 Multica Loop。

## 6. 工具链：把口号变成门禁

核心工具：

- `scripts/multica-loop.sh`：issue 到本地 task/dry-run/comment draft。
- `scripts/collect-evidence.sh`：结构化 evidence JSON/Markdown。
- `scripts/patch-summary.sh`：改动范围和 scope check。
- `scripts/review-packet.sh`：人工复核入口。
- `scripts/verify-toolchain.sh --strict --state-gate`：core evidence + state metadata gate。
- `scripts/share-preflight.sh`：分享前一键预检。

强调：

> 工具不是主角，门禁才是主角。

## 7. 红线：哪些事情坚决不自动化

- 不自动 done。
- 不存 token / 密钥。
- 不默认写远端。
- 不直接访问生产。
- 不跨 workspace 泄露数据。
- 不允许无限循环。
- 不静默失败。

## 8. North Star 路线图

- Phase A：可审计单任务闭环。
- Phase B：结构化 evidence 标准。
- Phase C：Multica Loop 组织层。
- Phase D：项目记忆。
- Phase E：受控回写与多角色协作。
- Phase F：团队分享与复制。

## 9. 现场演示建议

演示不追求 live coding，避免不稳定。建议演示 artifacts：

1. 打开 `09-north-star.md`。
2. 打开 `FUZ-554-one-page.md`。
3. 运行 `collect-evidence`。
4. 打开生成的 `evidence.md`。
5. 运行 `share-preflight.sh` 或 `verify-toolchain --strict --state-gate`。
6. 展示 scope split report。

## 10. 结束语

> AI 进入工程体系，不是靠更大的模型，而是靠更清晰的控制结构。我们这套实践的价值，是让 AI 的每一步都能被看见、被验证、被接管、被复盘。
