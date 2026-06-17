# Obsidian 可读摘要卡模板

用于把 Multica/Loop/飞书/代码证据聚合为人类可读卡片。自动生成版本只能写入 `99-generated/`。

```markdown
---
type: readable_summary
issue: FUZ-xxx
source: multica + loop
status: auto-generated
---

# FUZ-xxx 任务摘要

## 一句话结论

...

## 核心结论

- ...
- ...
- ...

## 当前状态

- Status:
- Owner:
- Next action:
- Decision needed:

## Evidence Links

| 类型 | 链接/路径 | 说明 |
|---|---|---|
| Multica | FUZ-xxx | 任务事实源 |
| 飞书 | URL | 方案/会议/需求 |
| Loop | runs/... | 执行证据 |
| 代码 | path/MR | 代码变更 |
| Grafana | URL | 监控证据 |

## 待确认

- [ ] ...

## 历史记录

- yyyy-mm-dd：...
```

## 使用规则

- 自动生成卡片进入 `/mnt/d/JAVA/knowledge/tiandao/99-generated/`。
- 人工整理后的稳定知识再进入人工区。
- 卡片以索引为主，不承载全部原文。
