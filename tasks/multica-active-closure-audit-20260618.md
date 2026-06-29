# Multica 活跃任务收口审计（2026-06-18）

## 原始需求

用户要求：`358任务目前情况如何` 后确认执行，并要求“剩余的任务也以此标准确认现状，loop 跑完给我一份报告”。

## 本轮标准

- 先核事实：以 Multica 远程 issue 状态、运行记录、评论、Obsidian 生成页、本地证据为准。
- 能阶段性收口就收口：环境/同步/报告/方案类任务，如目标已达成且剩余只是长期沉淀，应补总结并流转 done。
- 长期项不伪装完成：仍需持续建设的事项，保留 backlog / in_progress / blocked，并写清下一步或阻塞条件。
- 运行失败不等于业务失败：如果失败是 runtime `web_search` / OpenClaw parseable output 等基础设施噪音，应单独记录，不把业务倒退。
- 外部副作用：允许 Multica comment/status 写回；禁止 Git push/MR/部署/生产查询。

## 本轮目标

- 盘点当前所有非 done/cancelled issue。
- 对照 FUZ-358 标准做分类：可收口、保持推进、阻塞、长期 backlog。
- 对确定已完成/过期/阶段性完成的 issue 做远程流转。
- 对保留项给出明确下一步。
- 刷新 Obsidian 生成快照。
- 产出本地报告。

## 验收标准

- 有审计基线：活跃数量、按状态统计、issue 清单。
- 有流转清单：每个被改状态的 issue 说明原因。
- 有保留清单：未关闭 issue 的保留理由和下一步。
- 有同步证据：`daily-ops-sync.sh` 成功。
- 最终报告写入 ai-loop memory 或 reports 目录。
