# 阶段报告：Phase 16 下一真实代码任务候选池

## 目标

在 `FUZ-554` 已完成真实 patch 和证据刷新后，整理下一批真实代码任务候选，避免继续推进时临时选题、扩大风险。

## 已完成

- 新增 `docs/ai-work-orchestration/07-next-code-candidates.md`。
- 更新 `FUZ-554` 一页式分享稿中的证据计数。
- 推荐下一任务：`FUZ-554-N Patch Scope Check`。

## 候选任务

- A：Patch summary 增加 `--check-scope`。
- B：Review packet 增加 `--include-patch-summary`。
- C：Evidence index 增加排序稳定性说明。
- D：Verify toolchain 增加 `--strict`。

## 推荐

优先选择 A，因为它直接承接代码改动准入门禁，并能把“是否超出 scope”工具化。

## 验证结果

本阶段验证命令均已通过：

```bash
test -s docs/ai-work-orchestration/07-next-code-candidates.md
rg -n "Patch summary|Review packet|Verify toolchain|推荐下一步|FUZ-554-N" docs/ai-work-orchestration/07-next-code-candidates.md
rg -n "13 个 run|11 个 run" docs/ai-work-orchestration/share/FUZ-554-one-page.md
```

## 结论

候选池已就绪。下一轮默认进入 `FUZ-554-N Patch Scope Check`，继续把代码改动准入门禁工具化。
