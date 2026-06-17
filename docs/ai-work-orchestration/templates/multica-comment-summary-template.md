# Multica Comment 摘要模板

用于每次阶段性回写或汇报。默认不贴全文，只提供结论、证据和下一步。

```markdown
## 核心结论

- ...
- ...
- ...

## 证据链接

- Multica issue: FUZ-xxx
- 本地 task: `tasks/...md`
- 本地方案: `tasks/...plan.md`
- Loop run: `runs/.../summary.md`
- 飞书文档: URL
- Obsidian 卡片: `...`

## 风险/待确认

- ...

## 下一步

- 建议动作：...
- 需要用户确认：是/否
```

## 使用规则

- comment 正文建议不超过 80 行。
- 超过 80 行必须转为文档或 evidence 文件，再用链接引用。
- 不能用 comment 替代 evidence；comment 只是索引和摘要。
- 如果本轮产生外部产物，必须在 `证据链接` 中列出。
