# FUZ-564 Multica 信息治理：结论优先与链接化证据体系

## Issue

- Multica issue: FUZ-564
- Project: AI 工作编排实践：Multica × ai-loop
- Status at intake: backlog
- Priority: high

## Goal

设计并落地 Multica 信息治理机制，把“智能体协同过程中产生的大量信息”转化为人类可快速阅读、可追溯、可沉淀的分层信息体系。

核心目标：

1. 用户默认看到 3-5 条核心结论，而不是大段过程。
2. 详细证据通过链接/路径补充，保留可复核性。
3. Multica issue/comment、Loop handoff、Obsidian 卡片形成一致的信息分层。
4. 新规则纳入本地 Loop 规约，成为后续任务默认执行口径。

## Scope

本期聚焦方案和模板，不直接做大规模代码实现。

包含：

- Multica issue 描述模板。
- Multica comment 模板。
- Loop handoff 摘要规则。
- Obsidian 信息分层设计。
- 外部产物链接回写策略。
- 旧日报/巡检/自检归档策略。
- 1-2 个现有 issue 的样例改造方案。

不包含：

- 不修改 Multica 服务端。
- 不改生产调度。
- 不批量重写历史 issue。
- 不创建飞书文档，除非用户单独确认。
- 不执行远端 writeback，除非用户单独确认。

## Acceptance Criteria

- 产出本地方案文档：`tasks/FUZ-564-multica-information-governance-plan.md`。
- 文档包含“结论优先 + 链接化证据”的信息结构规范。
- 文档包含 Multica issue/comment 模板和 Loop handoff 模板。
- 文档包含 Obsidian 聚合视图设计。
- 文档包含完成定义和回写检查清单。
- 给出可试点的 1-2 个现有 issue 样例。
- 若产生外部产物，链接必须回写 FUZ-564。

## Side Effects Policy

当前允许：

- 读取 Multica issue。
- 读取本地 ai-loop 规约和脚本。
- 写入本地 task/plan 文档。
- 运行本地 intake gate / shell 语法检查。

当前不允许，需用户再次确认：

- 写 Multica comment / status / metadata。
- 创建或更新飞书文档。
- 修改 crontab。
- 改生产或远端服务。
- 批量改历史 issue。

## Boundary / Risk / Side Effects

Boundary:

- 本轮只做本地规划和模板设计，不改 Multica 服务端，不批量改历史 issue。
- 本轮不创建飞书文档，不写 Multica comment，不改 issue status。
- 后续如需要远端写回，必须先列 side effects 并获得用户确认。

Risk:

- 摘要过短可能丢失关键上下文，需要保留 evidence 链接和回溯路径。
- 模板过重会增加智能体负担，需要保持最小必要字段。
- 自动内容如果写入 Obsidian 人工区会污染知识库，必须限制到 `99-generated/`。

Side effects:

- 当前仅写入本地文件：task 和 plan 草案。
- 当前不产生远端副作用。

## Verification

本轮验证：

```bash
./scripts/loop-intake-gate.sh \
  --issue FUZ-564 \
  --task tasks/FUZ-564-multica-information-governance.md \
  --repo . \
  --output /tmp/FUZ-564-intake-gate.md
```

方案完成后验证：

```bash
bash -n scripts/loop-intake-gate.sh
bash -n scripts/loop-handoff.sh
DRY_RUN=true ./scripts/obsidian-sync.sh
```

## Initial Notes

本课题是大系统治理的一部分：Multica 是任务事实源，Loop 是协作协议，Obsidian 是知识沉淀层。核心矛盾是“智能体生产的信息足够完整，但人类阅读负担过高”。治理方向不是减少 evidence，而是将 evidence 链接化、摘要化、分层化。
