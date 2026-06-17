# Multica Issue 摘要模板

用于创建或整理 Multica issue。目标是让人类先读核心结论，再通过链接追溯证据。

```markdown
## 核心结论

- 结论 1：一句话说明当前判断。
- 结论 2：一句话说明风险或收益。
- 结论 3：一句话说明下一步。

## 当前状态

- Status: backlog / in_progress / blocked / in_review / done
- Owner:
- Decision needed: yes/no
- Next action:

## 背景

不超过 5 行，说明任务来源、目标和上下文。

## 范围

### 本期包含
- ...

### 本期不包含
- ...

## Evidence Links

| 类型 | 标题 | 链接/路径 | 状态 |
|---|---|---|---|
| 飞书 | 技术方案 | URL | draft / ready / approved |
| Loop | intake gate | path | passed |
| Loop | plan | path | draft |
| Obsidian | 摘要卡 | path | generated |
| 代码 | diff/MR | URL/path | pending |

## 待确认

- [ ] 问题 1
- [ ] 问题 2

## 下一步

1. 可执行动作 1。
2. 可执行动作 2。
```

## 使用规则

- 核心结论最多 5 条。
- 大段上下文不要粘在 issue，放到飞书/本地文档/Obsidian 后链接。
- 新建或采用外部产物后，必须更新 `Evidence Links`。
- blocked issue 必须把“等待谁提供什么”放进核心结论和待确认。
