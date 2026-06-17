# FUZ-564 Phase 2 样例改造报告

## 核心结论

- 已将 `FUZ-561` 和 `FUZ-562` 改造成“核心结论 + Evidence Links + 待确认 + 下一步”的新模板结构。
- 两条 issue 均保留关键飞书链接、本地路径和代码仓库路径。
- 本轮产生远端副作用：更新 Multica issue 描述。
- 已验证模板结构和关键链接存在。

## 改造对象

| Issue | 状态 | 结果 |
|---|---|---|
| FUZ-561 | in_progress | 已模板化，保留非标准响应说明和技术方案链接 |
| FUZ-562 | in_progress | 已模板化，保留需求文档、会议纪要、飞书方案、本地方案、代码仓库路径 |

## 验证结果

- `FUZ-561` 包含：`## 核心结论`、`## 当前状态`、`## Evidence Links`、`## 待确认`、`## 下一步`。
- `FUZ-562` 包含：`## 核心结论`、`## 当前状态`、`## Evidence Links`、`## 待确认`、`## 下一步`。
- `FUZ-562` 已包含飞书方案链接：`https://mi.feishu.cn/wiki/FC53w6cJviMJfrkPL4WcfnadnMg`。

## 后续建议

- Phase 3 可让 `obsidian-sync.sh` 生成 issue 可读摘要卡。
- Phase 3 可生成 external links 索引。
- 后续所有新 issue 创建时直接套用 `templates/multica-issue-summary-template.md`。
