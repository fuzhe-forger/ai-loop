# FUZ-564 Multica 信息治理方案：结论优先与链接化证据体系（v0.1）

## 1. 核心结论

1. Multica 信息治理的核心不是减少信息，而是把信息分成“人类默认阅读层”和“证据追溯层”。
2. 所有人类可见输出默认采用：**核心结论 3-5 条 + 证据链接 + 风险/待确认 + 下一步**。
3. Multica issue、comment、Loop handoff、Obsidian 卡片应使用同一套摘要模型，避免每个渠道各说各话。
4. 外部产物（飞书、Wiki、MR、Grafana、报告）只在 Multica 中保留标题、URL、状态、摘要和本地 evidence 路径，不粘贴大段正文。
5. Obsidian 承接历史和全文证据，Multica 承接任务事实与当前状态，Loop 承接协同过程。

## 2. 问题定义

当前智能体协同会产生大量信息：

- Multica issue 描述和评论。
- Loop task、run summary、stage report、review packet。
- 智能体 handoff 消息。
- 飞书文档、Wiki、会议纪要。
- 代码 diff、测试日志、Grafana 链接。
- Obsidian 自动生成页。

这些信息完整但不适合人类直接阅读。主要问题：

| 问题 | 表现 | 后果 |
|---|---|---|
| 信息过长 | 回复/issue/comment 粘贴大段过程 | 用户难以抓重点 |
| 证据分散 | 文档、日志、run、issue 到处都是 | 难以复核 |
| 状态不一致 | 飞书有新链接但 issue 未回写 | 任务事实源失真 |
| 模板不统一 | 每个智能体输出结构不同 | 调度成本高 |
| 历史堆积 | 日报/巡检/自检长期堆在 issue | 当前任务噪声大 |

## 3. 信息分层模型

### 3.1 L0：核心结论层

面向人类默认展示。限制 3-5 条，每条一行。

必须回答：

- 现在结论是什么？
- 是否需要用户决策？
- 风险/阻塞是什么？
- 下一步做什么？

### 3.2 L1：任务状态层

承载在 Multica issue 描述或最新 comment。

字段：

- 当前状态。
- 目标。
- 范围。
- 已完成。
- 待确认。
- 下一步。
- 外部产物链接。

### 3.3 L2：证据索引层

只放链接和路径，不放全文。

包括：

- 飞书/Wiki URL。
- Loop run path。
- review packet path。
- test report path。
- Obsidian generated card path。
- code diff / MR 链接。
- Grafana dashboard URL。

### 3.4 L3：原始证据层

保留完整原文、日志、报告、文档。默认不展示给人类，只在需要复核时进入。

存放位置：

- `runs/<run-id>/`
- Obsidian `99-generated/`
- 飞书文档。
- 代码仓库。
- 日志系统。

## 4. Multica Issue 模板

建议 issue 描述统一采用：

```markdown
## 核心结论

- 结论 1
- 结论 2
- 结论 3

## 当前状态

- Status: in_progress / blocked / in_review / done
- Owner:
- Next action:
- Decision needed: yes/no

## 背景

简要说明任务来源和目标，不超过 5 行。

## 范围

### 本期包含
- ...

### 本期不包含
- ...

## Evidence Links

| 类型 | 标题 | 链接/路径 | 状态 |
|---|---|---|---|
| 飞书 | 技术方案 | URL | 已写入 |
| Loop | intake gate | path | passed |
| Obsidian | 知识卡片 | path | generated |

## 待确认

- [ ] 问题 1
- [ ] 问题 2

## 下一步

1. ...
2. ...
```

## 5. Multica Comment 模板

每条 comment 不粘贴大段全文，默认结构：

```markdown
## 核心结论

- ...
- ...
- ...

## 证据链接

- 本地方案：`path`
- 飞书文档：URL
- 验证报告：`path`

## 风险/待确认

- ...

## 下一步

- 建议动作：...
- 需要用户确认：是/否
```

限制：

- 核心结论最多 5 条。
- 单条 comment 正文建议不超过 80 行。
- 超过 80 行必须转为文档或 evidence 文件，再用链接引用。

## 6. Loop Handoff 摘要规则

handoff 面向下一个智能体，必须最小充分。

```yaml
issue: FUZ-xxx
run_id: FUZ-xxx-...
from_role: execution_agent
to_role: reviewer
loop_state: review_ready
summary:
  - 核心结论 1
  - 核心结论 2
evidence:
  - path: runs/<run>/summary.md
    type: summary
  - path: runs/<run>/review-packet.md
    type: review_packet
risk:
  - 风险项
next_action: review evidence and decide approve/request_changes
side_effects: none
```

要求：

- `summary` 不超过 5 条。
- `evidence` 必须是路径/链接。
- `next_action` 必须是可执行动作。
- 不能把完整日志粘进 handoff。

## 7. Obsidian 聚合视图设计

### 7.1 自动生成区

继续使用：

```text
/mnt/d/JAVA/knowledge/tiandao/99-generated/
```

新增建议视图：

```text
99-generated/multica/readable-summaries.md
99-generated/multica/issues/FUZ-xxx.md
99-generated/loop/handoffs.md
99-generated/governance/external-links.md
```

### 7.2 人工沉淀区

人工整理后的稳定知识进入：

```text
04-项目知识/
05-流程规约/
06-复盘经验/
```

自动脚本不得写入人工区。

### 7.3 可读摘要卡

每个重点任务生成一张摘要卡：

```markdown
# FUZ-xxx 任务摘要

## 一句话结论

...

## 当前状态

...

## 决策点

...

## Evidence

- Multica: ...
- 飞书: ...
- Loop run: ...
- 代码: ...

## 历史记录

- yyyy-mm-dd: ...
```

## 8. 外部产物链接回写规则

任何外部产物一旦创建或确认采用，必须回写到对应 Multica issue。

外部产物包括：

- 飞书文档 / Wiki。
- MR / PR。
- Grafana 面板。
- 发布单。
- 测试报告。
- Obsidian 关键卡片。
- Loop run evidence。

回写最小字段：

| 字段 | 示例 |
|---|---|
| 产物名称 | MAF 品类建单技术方案 |
| URL/path | https://... / tasks/xxx.md |
| 状态 | draft / ready / approved / obsolete |
| 写入时间 | 2026-06-16 |
| 摘要 | 一句话说明用途 |

完成前检查：

- [ ] issue 描述或 comment 已包含最新链接。
- [ ] 本地 evidence 路径存在。
- [ ] 若飞书限流，已重试写入并读回验证。
- [ ] 若暂时无法回写，已标记“待回写 Multica”。

## 9. 归档策略

### 9.1 日报/巡检/自检

- Multica 只保留最近 7 天可读入口。
- 历史完整记录进入 Obsidian 自动生成区。
- 月度/周度只保留趋势摘要，不保留逐条日志。

### 9.2 已完成任务

- issue 保留核心结论和 evidence links。
- 大段过程迁移为 Obsidian/run evidence。
- `done` 前必须完成链接回写。

### 9.3 blocked 任务

blocked 任务必须展示：

- 阻塞原因。
- 需要谁提供什么。
- 最近一次推进时间。
- 解除阻塞后下一步。

## 10. 输出风格规范

默认回答结构：

```markdown
**核心结论**
- ...
- ...
- ...

**证据/链接**
- `FUZ-xxx`
- `path`
- URL

**待确认**
- ...

**下一步**
- ...
```

禁止：

- 一上来贴满日志。
- 用“已完成”但不给 evidence。
- 新建飞书后不回写 issue。
- 把 Obsidian 自动内容写入人工区。
- 大段复制源文档，应该链接化。

## 11. 试点建议

### 试点 1：FUZ-562

任务：MAF 品类建单政策接口配合方案。

改造点：

- issue 描述增加核心结论区。
- 飞书方案链接已经回写。
- 本地草案路径已回写。
- 后续 comment 使用“结论 + 链接 + 待确认”。

### 试点 2：FUZ-561

任务：svc_policy 非标准响应体治理。

改造点：

- blocked 状态需要突出“等待 Dubbo 接口清单”。
- 保留已生成技术方案链接。
- 待补充信息列表放在最前面。

## 12. 后续落地路线

### Phase 1：规约固化

- 更新 `21-local-operating-protocol.md`。
- 更新 `22-obsidian-self-evolution.md`。
- 更新 `LOOP_STATE_REFRESH_COMMANDS.md`。

### Phase 2：模板落地

- 增加 issue/comment/handoff 模板文件。
- 在 `loop-handoff.sh` 中强化摘要字段。
- 在 `review-packet.sh` 中增加人类可读摘要。

### Phase 3：Obsidian 聚合

- `obsidian-sync.sh` 生成 issue 摘要卡。
- 生成 external links 索引。
- 生成 blocked / waiting-human 列表。

### Phase 4：样例改造

- 改造 FUZ-562。
- 改造 FUZ-561。
- 根据效果调整模板。

## 13. 验收清单

- [ ] 方案文档存在并可读。
- [ ] 规约已写入“结论优先 + 链接补充”。
- [ ] Multica issue 模板完成。
- [ ] Multica comment 模板完成。
- [ ] Loop handoff 模板完成。
- [ ] Obsidian 聚合视图设计完成。
- [ ] FUZ-562 或 FUZ-561 至少一个样例完成改造。
- [ ] 若生成飞书文档，链接已回写 FUZ-564。

## 14. 本轮建议

本轮先不做远端写回。建议用户确认是否进入 Phase 1：更新本地规约和模板文件。确认后再执行：

1. 新增模板文件。
2. 更新本地规约。
3. 生成 Obsidian 摘要卡设计。
4. 可选：创建飞书方案文档并回写 FUZ-564。
