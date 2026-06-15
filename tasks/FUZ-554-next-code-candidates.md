# FUZ-554-M2 下一真实代码任务候选池

## 背景

`FUZ-554` 已完成第一条低风险真实代码改动和 patch 证据化。下一步需要选择更接近代码开发的任务，但仍保持低风险和本地可验证。

## 目标

新增候选池文档，列出下一批真实代码任务候选，并推荐一个默认下一步。

## 交付物

- `docs/ai-work-orchestration/07-next-code-candidates.md`
- 更新 `docs/ai-work-orchestration/share/FUZ-554-one-page.md` 的证据状态
- `runs/FUZ-554-next-code-candidates/stage-report.md`
- `runs/FUZ-554-next-code-candidates/multica-comment.md`

## 验收标准

- 候选池至少包含 3 个候选任务
- 每个候选包含类型、风险、验证和价值
- 给出推荐下一步
- 分享稿证据状态与最新 refresh 快照一致
- 本地关键字验证通过

## 验证命令

```bash
test -s docs/ai-work-orchestration/07-next-code-candidates.md
rg -n "Patch summary|Review packet|Verify toolchain|推荐下一步|FUZ-554-N" docs/ai-work-orchestration/07-next-code-candidates.md
rg -n "13 个 run|11 个 run" docs/ai-work-orchestration/share/FUZ-554-one-page.md
```

## 安全边界

- 仅修改本地文档和本地证据
- 不读取 Multica issue
- 不修改 Multica status
- 不 push、不 commit、不创建 MR
