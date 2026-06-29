# 司南执行治理矩阵 v0.2

## 目标

把 Loop 执行从“发现一个缺口补一个 guard”收敛为低成本、可持续运行的固定决策流程。

## 适用范围

- 本地 ai-loop / 司南工作流。
- Obsidian generated 同步。
- 已获授权的 Feishu / Multica 轻量写回。
- 不覆盖 Git remote、部署、生产访问、工具安装、全局 Codex 配置或破坏性操作。

## 执行前决策矩阵

| 问题 | 判断 | 动作 |
|---|---|---|
| 是否有明确 issue / task / repo / 验收？ | 否 | 只做澄清或补 task，不编码 |
| 是否是机制、策略或可复用能力变化？ | 是 | 允许写 1 篇 phase report |
| 是否只是一次同步、验证或日志记录？ | 是 | 只写 operation log，不写 phase report |
| 是否需要外部写入？ | 是 | 先生成本地草稿 / evidence，再写入并 readback |
| 是否涉及 Git remote / deploy / install / global config / destructive file op？ | 是 | 停止，单独审批 |
| 是否已通过 closeout？ | 否 | 不进入最终写回或 done 状态 |
| 是否已完成 Obsidian sync？ | 否 | 本地验证通过后自动 sync |

## Phase Report 规则

写 phase report 的条件：

- 新增或修改稳定机制。
- 修改审批、安全、写回、evidence、同步等治理策略。
- 形成可复用模板、脚本或协议。
- 改动需要后续 AI 或人类通过 Obsidian 复盘。

不写 phase report 的条件：

- 单次 Obsidian sync。
- 单次验证结果。
- 单次 operation log。
- 小的文案修正，除非影响审批或安全边界。
- 围绕同一机制的连续微调，应该合并到同一 phase report。

## Operation Log 规则

必须写 operation log：

- 产生外部写入：Obsidian、Feishu、Multica。
- 获得批量审批或 standing approval。
- 发现并修复 evidence 污染、审批边界错误、同步镜像错误。
- 本轮执行有可审计的关键决策。

可不写 operation log：

- 纯本地小修，且已有 phase report 记录。
- 重复验证，无新结论。
- 自动生成的中间产物。

## 写回策略

### Multica

允许写回类型：

- start plan comment：说明本轮目标、范围、允许副作用。
- progress comment：只在阶段性成果可复查时写，不超过 1 条。
- final summary comment：汇总最终结果、evidence、Obsidian 链接、后续事项。
- metadata：只写非破坏性字段，如 `pipeline_status`、`execution_package_status`、`last_evidence_path`、`last_obsidian_sync`。
- status：只有 closeout 和最终验证通过后才可改为 `done`。

写回要求：

- 写前有本地草稿。
- 写后保留 write result / readback evidence。
- 写回内容必须引用本地 evidence 或 Obsidian generated 路径。

### Feishu

允许写入：

- 明确目标文档或表格中的本轮总结。
- evidence 链接、状态、确认数量等指定字段。
- 追加或定点更新。

禁止写入：

- 无目标文档的探索性写入。
- 删除评论或大范围改正文档。
- 批量覆盖历史正文。

## Closeout 标准

一个正式任务在写最终总结或改 done 前必须满足：

- `loop-execution-preflight` 通过。
- `verify-toolchain --strict --state-gate` 通过。
- `share-preflight --persist-to-run` 完成。
- `evidence-checklist` 和 `evidence-index` 更新。
- Obsidian generated run 页面展示 Execution Preflight、Closeout Summary、Share Preflight Summary。
- 外部写入有 write result 或 readback evidence。

## Token 控制规则

- 同主题最多 1 篇 phase report，后续微调合并更新。
- 每轮最多 1 次长验证，除非失败需要修复。
- 工具输出只检查关键行，避免整页 dump。
- 先 acceptance checklist，再实现，避免边做边改目标。
- 能用 closeout 的场景不手工拼多条验证命令。
